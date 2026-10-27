-- =====================================================================
-- SQL_PENSERA_LEITURA.sql   (27/10/2026)
--
-- Acesso do Pensera (sistema do Mario) ao custo do cardapio.
--
-- Cria:
--   * a area "pensera" no banco, com 3 tabelas de leitura (views):
--       pensera.custo_cardapio     custo por item vendido, pelo id do iComanda
--       pensera.ficha_ingredientes composicao de todas as fichas ativas
--       pensera.produtos           cadastro com custo por unidade de uso
--   * o usuario pensera_leitura, que SO enxerga a area "pensera" e SO le.
--
-- As views sao calculadas na hora da consulta: o Mario ve sempre o custo
-- que o sistema tem naquele momento. Nao copia dado nenhum.
-- Nao mexe em saldo, pedido, compra, ficha nem financeiro.
-- Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA.
-- (a) Esperado: 0 e 0 (nada disso existe ainda).
-- (b) Esperado: mapeado 383, ignorar 44, pendente 26 (pode ter mudado
--     um pouco se alguem mexeu na tela de ligacao do PDV).
-- =====================================================================
SELECT (SELECT count(*) FROM pg_roles     WHERE rolname = 'pensera_leitura') AS usuario_ja_existe,
       (SELECT count(*) FROM pg_namespace WHERE nspname = 'pensera')         AS area_ja_existe;

SELECT status, count(*) FROM public.pdv_map GROUP BY status ORDER BY status;


-- =====================================================================
-- PASSO 2 - CRIA A AREA E AS 3 VIEWS (tudo ou nada)
-- =====================================================================
BEGIN;

CREATE SCHEMA pensera;
REVOKE ALL ON SCHEMA pensera FROM PUBLIC;
REVOKE ALL ON SCHEMA pensera FROM anon, authenticated;

-- Cadastro com o custo por unidade de uso, na MESMA conta que a ficha
-- tecnica usa (app.js, salvarFicha): custo / fator de conversao / (1 - perda).
-- Para produto com ficha (prato, SA, PPC), custo_comp = custo por porcao da ficha.
CREATE VIEW pensera.produtos AS
SELECT p.id                      AS produto_id,
       p.codigo,
       p.nome,
       p.tipo,
       p.categoria,
       p.ativo,
       p.unidade_comp            AS unidade_compra,
       p.unidade_uso,
       coalesce(nullif(p.fator_conversao, 0), 1)::numeric AS fator_conversao,
       coalesce(p.perda, 0)::numeric                      AS perda_percentual,
       coalesce(nullif(p.custo_comp, 0), p.custo_uso, 0)::numeric AS custo_compra,
       CASE WHEN coalesce(p.perda, 0) < 100 THEN
         round((coalesce(nullif(p.custo_comp, 0), p.custo_uso, 0)
                / coalesce(nullif(p.fator_conversao, 0), 1)
                / (1 - coalesce(p.perda, 0) / 100.0))::numeric, 6)
       ELSE 0 END                AS custo_por_unidade_uso,
       EXISTS (SELECT 1 FROM public.est_fichas_tecnicas f
                WHERE f.produto_id = p.id AND f.ativo) AS tem_ficha
  FROM public.est_produtos p;

-- Composicao de todas as fichas ativas, um nivel (o ingrediente pode ser
-- outra ficha: SA/PPC. Para descer, cruzar ingrediente_id com produto_id).
-- A soma de custo_na_ficha de uma ficha = custo_total_ficha.
CREATE VIEW pensera.ficha_ingredientes AS
SELECT f.id                       AS ficha_id,
       f.produto_id,
       pp.nome                    AS produto_nome,
       pp.tipo                    AS produto_tipo,
       f.rendimento::numeric      AS rendimento,
       f.unidade_rendimento,
       round(f.custo_total::numeric, 4)      AS custo_total_ficha,
       round(f.custo_por_porcao::numeric, 4) AS custo_por_porcao,
       i.ingrediente_id,
       pi.nome                    AS ingrediente_nome,
       pi.tipo                    AS ingrediente_tipo,
       i.quantidade::numeric      AS quantidade,
       i.unidade,
       pi.custo_por_unidade_uso,
       round((i.quantidade * coalesce(pi.custo_por_unidade_uso, 0))::numeric, 4) AS custo_na_ficha
  FROM public.est_fichas_tecnicas f
  JOIN public.est_ficha_ingredientes i ON i.ficha_id = f.id
  LEFT JOIN public.est_produtos pp ON pp.id = f.produto_id
  LEFT JOIN pensera.produtos    pi ON pi.produto_id = i.ingrediente_id
 WHERE f.ativo;

-- Um item por id do iComanda (o mesmo produto_id que vem na API do PDV).
-- Custo por unidade vendida = custo por porcao da ficha x fator da ligacao,
-- a mesma conta que o robo de baixa de estoque usa.
-- So "mapeado" tem custo: "ignorar" ja esta dentro da ficha do prato
-- (guarnicao, gelo, opcao de talher) ou nao e mercadoria (couvert, banheiro);
-- "pendente" ainda nao tem ficha.
CREATE VIEW pensera.custo_cardapio AS
SELECT m.icomanda_produto_id,
       m.icomanda_nome,
       m.setor,
       m.status                   AS situacao,
       m.produto_id,
       p.nome                     AS produto_nome,
       p.categoria,
       CASE WHEN m.status = 'mapeado'
            THEN round((f.custo_por_porcao * coalesce(m.fator, 1))::numeric, 4)
       END                        AS custo_por_unidade_vendida,
       coalesce(m.fator, 1)::numeric AS fator,
       f.ficha_id,
       m.obs                      AS observacao,
       m.atualizado_em            AS ligacao_atualizada_em
  FROM public.pdv_map m
  LEFT JOIN public.est_produtos p ON p.id = m.produto_id
  LEFT JOIN LATERAL (
         SELECT ft.id AS ficha_id, ft.custo_por_porcao
           FROM public.est_fichas_tecnicas ft
          WHERE ft.produto_id = m.produto_id AND ft.ativo
          ORDER BY ft.criado_em DESC
          LIMIT 1) f ON true;

COMMIT;


-- =====================================================================
-- PASSO 3 - CRIA O USUARIO DO PENSERA
--
-- Nao precisa editar nada: o proprio SQL sorteia a senha e mostra no
-- resultado, numa coluna "senha_do_mario". Copie e mande para o Mario
-- por mensagem particular. Ela nao fica gravada neste arquivo.
-- =====================================================================
BEGIN;

CREATE TEMP TABLE _pensera_senha AS
SELECT replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '') AS senha;

DO $$
BEGIN
  EXECUTE format('CREATE ROLE pensera_leitura LOGIN PASSWORD %L CONNECTION LIMIT 5',
                 (SELECT senha FROM _pensera_senha));
END $$;

-- Toda conexao dele ja comeca so-leitura, com limite de 2 minutos por consulta
-- e enxergando a area pensera sem precisar escrever "pensera." na frente.
ALTER ROLE pensera_leitura SET default_transaction_read_only = on;
ALTER ROLE pensera_leitura SET statement_timeout = '120s';
ALTER ROLE pensera_leitura SET search_path = pensera;

GRANT USAGE  ON SCHEMA pensera TO pensera_leitura;
GRANT SELECT ON ALL TABLES IN SCHEMA pensera TO pensera_leitura;
-- view nova criada depois nesta area ja nasce liberada para leitura
ALTER DEFAULT PRIVILEGES IN SCHEMA pensera GRANT SELECT ON TABLES TO pensera_leitura;

COMMIT;

-- a senha sorteada (copie a coluna senha_do_mario)
SELECT senha AS senha_do_mario FROM _pensera_senha;


-- =====================================================================
-- PASSO 4 - CONFERENCIA (so leitura).
-- (a) Esperado: mapeado com_custo = itens (383), ignorar/pendente com_custo 0.
-- (b) Esperado: fichas_que_nao_batem = 0 (ingredientes somam o custo da ficha;
--     ate 5 com diferenca de centavos e normal).
-- (c) Esperado: le_tabela_do_sistema = 0 e pode_gravar = 0.
--     As 3 views do pensera aparecem com pode_ler = true.
-- =====================================================================
SELECT situacao, count(*) AS itens,
       count(custo_por_unidade_vendida) AS com_custo,
       round(avg(custo_por_unidade_vendida), 2) AS custo_medio
  FROM pensera.custo_cardapio GROUP BY situacao ORDER BY situacao;

SELECT count(*) AS fichas_que_nao_batem
  FROM (SELECT ficha_id, max(custo_total_ficha) AS total, sum(custo_na_ficha) AS soma
          FROM pensera.ficha_ingredientes GROUP BY ficha_id) x
 WHERE abs(total - soma) > 0.05;

SELECT count(*) FILTER (WHERE n.nspname <> 'pensera'
                          AND has_table_privilege('pensera_leitura', c.oid, 'SELECT')) AS le_tabela_do_sistema,
       count(*) FILTER (WHERE has_table_privilege('pensera_leitura', c.oid, 'INSERT,UPDATE,DELETE,TRUNCATE')) AS pode_gravar
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.relkind IN ('r', 'v', 'm', 'p', 'f')
   AND n.nspname NOT IN ('pg_catalog', 'information_schema');

SELECT c.relname AS view, has_table_privilege('pensera_leitura', c.oid, 'SELECT') AS pode_ler
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'pensera' ORDER BY 1;


-- =====================================================================
-- SE PRECISAR CORTAR O ACESSO (nao rode agora)
-- Corta na hora: o usuario some e as conexoes abertas dele caem.
-- =====================================================================
-- SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'pensera_leitura';
-- REVOKE ALL ON ALL TABLES IN SCHEMA pensera FROM pensera_leitura;
-- REVOKE ALL ON SCHEMA pensera FROM pensera_leitura;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA pensera REVOKE SELECT ON TABLES FROM pensera_leitura;
-- DROP ROLE pensera_leitura;
-- (a area e as views podem ficar; para apagar tudo: DROP SCHEMA pensera CASCADE;)
--
-- TROCAR A SENHA (sorteia outra e mostra no resultado):
-- CREATE TEMP TABLE _nova AS SELECT replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','') AS senha;
-- DO $$ BEGIN EXECUTE format('ALTER ROLE pensera_leitura PASSWORD %L', (SELECT senha FROM _nova)); END $$;
-- SELECT senha AS senha_nova FROM _nova;
