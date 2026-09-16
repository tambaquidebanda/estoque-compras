-- ============================================================================
-- SQL_PEDIDO_SOMBRA.sql   (15/09/2026)
--
-- Cria a tabela pdv_pedido_sombra: FASE 1 da baixa automatica.
--
-- O QUE E
-- Toda madrugada, depois do robo da baixa, o script scripts/pedido_sombra.py
-- calcula para cada item contado na noite anterior o pedido que o setor faria
-- SO PELA VENDA, e grava ao lado do pedido que saiu da contagem:
--
--   saldo do modelo = ancora + entradas no setor - consumo da venda
--   pedido sombra   = max(0, padrao - saldo do modelo)
--   pedido real     = max(0, padrao - contado)   (o que a contagem gerou)
--
-- Duas variantes por linha:
--   V1 - ancora = contagem da noite anterior  (termometro do dia)
--   V2 - ancora = contagem de 7 a 10 dias antes (simula a contagem SEMANAL da
--        fase 2; e este numero que libera um setor)
--
-- NAO E BAIXA. Nenhuma linha desta tabela cria pedido interno, mexe em saldo
-- ou no livro-razao. E medicao. O script, se esta tabela nao existir, avisa e
-- termina sem erro - medicao nao derruba operacao.
--
-- Regras decididas pelo Wagner em 15/09/2026:
--   "bate" = diferenca de ate 1 unidade (e o placar mostra tambem o exato).
--   Setor passa a fase 2: 14 noites, V2 com >= 85% do valor batendo em 10
--   delas, top 10 itens do setor dentro, excluidos <= 10% do valor.
-- Desenho: https://claude.ai/artifact/D5U2hMwNgxsSZvGTd2ny3y
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. A tabela ja existe?
-- ============================================================================
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'public' AND table_name = 'pdv_pedido_sombra';
-- zero linha = ainda nao existe, siga para o PASSO 2.


-- ============================================================================
-- PASSO 2 - CRIA. Idempotente: rodar de novo nao quebra nem apaga dado.
-- ============================================================================
CREATE TABLE IF NOT EXISTS pdv_pedido_sombra (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  noite               date        NOT NULL,   -- noite da contagem (dia de Manaus)
  setor               text        NOT NULL,
  grupo               text        NOT NULL,
  produto_id          uuid        NOT NULL,
  nome                text,
  -- o lado da contagem (o que aconteceu de verdade)
  contado             numeric,
  padrao              numeric,                -- o padrao gravado naquela contagem
  pedido_real         numeric,
  -- V1: ancora = contagem da noite anterior
  v1_ancora_data      date,
  v1_ancora_qtd       numeric,
  v1_entradas         numeric,
  v1_consumo          numeric,
  v1_saldo            numeric,
  v1_sombra           numeric,
  -- V2: ancora = contagem de 7 a 10 dias antes (simula contagem semanal)
  v2_ancora_data      date,
  v2_ancora_qtd       numeric,
  v2_entradas         numeric,
  v2_consumo          numeric,
  v2_saldo            numeric,
  v2_sombra           numeric,
  -- para valorizar a diferenca e separar o que nao e comparavel
  custo_unit          numeric,
  unidade_nao_curada  boolean     NOT NULL DEFAULT false,  -- fator_conversao <> 1
  dois_grupos         boolean     NOT NULL DEFAULT false,  -- item contado em 2 grupos na noite
  contado_zero        boolean     NOT NULL DEFAULT false,  -- linha em branco vira zero
  criado_em           timestamptz NOT NULL DEFAULT now()
);

-- uma linha por noite, setor, grupo e item: o script apaga a noite e regrava,
-- entao rodar de novo substitui em vez de acumular.
CREATE UNIQUE INDEX IF NOT EXISTS pdv_pedido_sombra_chave
  ON pdv_pedido_sombra (noite, setor, grupo, produto_id);

CREATE INDEX IF NOT EXISTS pdv_pedido_sombra_noite_setor
  ON pdv_pedido_sombra (noite, setor);

-- RLS no mesmo padrao das outras tabelas dos dois sistemas.
ALTER TABLE pdv_pedido_sombra ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pdv_pedido_sombra_all ON pdv_pedido_sombra;
CREATE POLICY pdv_pedido_sombra_all ON pdv_pedido_sombra
  FOR ALL USING (true) WITH CHECK (true);


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Deve listar 26 colunas.
-- ============================================================================
SELECT count(*) AS colunas
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'pdv_pedido_sombra';


-- ============================================================================
-- PASSO 4 - O PLACAR. Rode quando quiser ver como a sombra esta indo.
--
-- "bate" = diferenca de ate 1 unidade. Entram so os itens comparaveis: fora os
-- de unidade nao curada, os contados em dois grupos na mesma noite, os que
-- vieram zerados (linha em branco) e aqueles em que o SALDO DO MODELO ficou
-- NEGATIVO - nesses o modelo viu sair mais do que viu entrar, ou seja, perdeu
-- um lancamento, e comparar seria cobrar do setor um erro de registro.
-- V1 = ancora de ontem (termometro do dia).
-- V2 = ancora de 7 a 10 dias antes; e o V2 que decide se um setor passa.
-- ============================================================================
SELECT noite, setor,
       count(*)                                                            AS itens,
       round(100.0 * avg((abs(v1_sombra - pedido_real) <= 1)::int))        AS v1_itens_pct,
       round(100.0 * avg((abs(v1_sombra - pedido_real) < 0.0001)::int))    AS v1_exato_pct,
       round(100.0 * sum(CASE WHEN abs(v1_sombra - pedido_real) <= 1
                              THEN pedido_real * custo_unit ELSE 0 END)
                   / nullif(sum(pedido_real * custo_unit), 0))             AS v1_valor_pct,
       count(*) FILTER (WHERE v2_sombra IS NOT NULL)                       AS itens_v2,
       round(100.0 * avg((abs(v2_sombra - pedido_real) <= 1)::int)
             FILTER (WHERE v2_sombra IS NOT NULL))                         AS v2_itens_pct,
       round(100.0 * sum(CASE WHEN v2_sombra IS NOT NULL
                               AND abs(v2_sombra - pedido_real) <= 1
                              THEN pedido_real * custo_unit ELSE 0 END)
                   / nullif(sum(CASE WHEN v2_sombra IS NOT NULL
                                     THEN pedido_real * custo_unit ELSE 0 END), 0))
                                                                           AS v2_valor_pct
  FROM pdv_pedido_sombra
 WHERE NOT unidade_nao_curada AND NOT dois_grupos AND NOT contado_zero
   AND padrao > 0 AND v1_sombra IS NOT NULL AND v1_saldo >= 0
 GROUP BY noite, setor
 ORDER BY noite DESC, setor;


-- ============================================================================
-- PASSO 5 - ONDE A SOMBRA ERRA MAIS, em R$. E a fila de consertos: cada linha
-- do topo costuma ser um problema conhecido de processo, nao de calculo.
-- ============================================================================
SELECT noite, setor, nome,
       pedido_real, v1_sombra,
       round((abs(v1_sombra - pedido_real) * custo_unit)::numeric, 2) AS diferenca_rs,
       (v1_saldo < 0)                                                 AS falta_entrada
  FROM pdv_pedido_sombra
 WHERE NOT unidade_nao_curada AND NOT dois_grupos AND NOT contado_zero
   AND padrao > 0 AND v1_sombra IS NOT NULL
   AND abs(v1_sombra - pedido_real) > 1
 ORDER BY diferenca_rs DESC
 LIMIT 30;
