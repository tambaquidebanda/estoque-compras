-- =====================================================================
-- SQL_DESFAZER_LIBERACAO_28SET.sql  (29/09/2026)
--
-- Desfaz a liberacao + recebimento feitos por engano em 28/09 entre
-- 23:00 e 23:06 (horario Manaus), pelo celular do Bar com o PIN do
-- Estoque (confirmado pelos Logs do Supabase).
--
-- QUAIS PEDIDOS VOLTAM (14 pedidos NORMAIS, da contagem de 28/09):
--   COZINHA: PED-2949 ESTIVAS, PED-2952 HORTIFRUTI, PED-2953 EMBALAGENS,
--            PED-2966 COMIDA FUNCIONARIO, PED-2972 CONGELADOS
--   BAR:     PED-2950 POLPAS, PED-2954 SOBREMESAS, PED-2955 SODA AMAZONENSE,
--            PED-2956 ESTIVAS, PED-2959 HORTIFRUTI, PED-2960 EMBALAGEM/DESCART.,
--            PED-2961 MATERIAL DE EXPEDIENTE, PED-2963 DESTILADOS,
--            PED-2965 NAO ALCOOLICAS
-- FICAM COMO ESTAO (liberacao da noite e normal para eles):
--   PED-2967 BAR ALCOOLICAS e as 6 emergencias
--   (PED-2951, 2971 Cozinha; PED-2964, 2968, 2969, 2970 Bar).
--   Para incluir ou tirar algum, edite as DUAS listas marcadas com >>> LISTA.
--
-- O QUE ACONTECE COM CADA PEDIDO DA LISTA:
--   1) Volta para PENDENTE (sem liberado/recebido, sem qtd liberada/recebida).
--      O estoque libera de novo pelo caminho normal, ajustando as quantidades
--      ao que realmente vai, e o setor confirma quando chegar.
--   2) Saldo do SETOR (Bar/Cozinha): tira de volta o que entrou as 23:06.
--      Se o item ja foi CONTADO no setor depois disso, nao mexe
--      (a contagem ja e a verdade).
--   3) Saldo do ESTOQUE DA LOJA: devolve o que saiu as 23:06.
--      Se o item ja foi CONTADO/AJUSTADO no Estoque da Loja depois disso
--      (o Ricardo contou varios grupos hoje de manha), nao mexe:
--      a contagem ja corrigiu. Hoje (29/09 13h): 35 itens nessa situacao.
--   4) Cada devolucao vira uma linha no razao (est_movimentacoes), com o
--      sinal contrario e o motivo "Estorno PED-xxxx ...". Nada e apagado.
--
-- E TAMBEM: PED-2937 (BAR ALCOOLICAS de 27/09) foi liberado no mesmo lote
-- e nunca recebido. Ele vira ENCERRADO (sem mexer em saldo), para ninguem
-- confirmar depois e tirar a mercadoria do estoque em dobro.
--
-- Ordem: PASSO 1 (so leitura) -> PASSO 2 (faz tudo numa transacao,
-- com backup) -> PASSO 3 (conferencia). Depois: F5 nas telas.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA. O que vai ser feito.
-- Esperado: 14 linhas, todas status 'recebido', total de 213 itens.
-- =====================================================================
WITH lista(num) AS (VALUES   -- >>> LISTA (igual a do PASSO 2)
  ('PED-2949'),('PED-2952'),('PED-2953'),('PED-2966'),('PED-2972'),
  ('PED-2950'),('PED-2954'),('PED-2955'),('PED-2956'),('PED-2959'),
  ('PED-2960'),('PED-2961'),('PED-2963'),('PED-2965')
),
itens AS (
  SELECT p.num_pedido, p.setor, p.status, i.id AS item_id, i.produto_id, i.qtd_recebida AS q,
         EXISTS (SELECT 1 FROM est_movimentacoes m
                  WHERE m.produto_id = i.produto_id AND m.local = 'ESTOQUE_LOJA'
                    AND m.tipo IN ('contagem','ajuste')
                    AND m.criado_em > '2026-09-29 03:07:00+00') AS loja_ja_contada,
         EXISTS (SELECT 1 FROM est_movimentacoes m
                  WHERE m.produto_id = i.produto_id AND m.local = p.setor
                    AND m.tipo IN ('contagem','ajuste')
                    AND m.criado_em > '2026-09-29 03:07:00+00') AS setor_ja_contado
  FROM pedidos_internos p
  JOIN lista l ON l.num = p.num_pedido
  LEFT JOIN pedidos_internos_itens i ON i.pedido_id = p.id
)
SELECT num_pedido, setor, status,
       count(item_id)                                             AS itens,
       count(*) FILTER (WHERE produto_id IS NOT NULL AND q > 0)   AS itens_com_qtd,
       count(*) FILTER (WHERE q > 0 AND NOT setor_ja_contado)     AS devolve_do_setor,
       count(*) FILTER (WHERE q > 0 AND NOT loja_ja_contada)      AS volta_pra_loja,
       count(*) FILTER (WHERE q > 0 AND loja_ja_contada)          AS loja_ja_recontada
FROM itens
GROUP BY num_pedido, setor, status
ORDER BY setor, num_pedido;

-- e o PED-2937 (esperado: status 'liberado', recebido_em vazio)
SELECT num_pedido, status, liberado_em, recebido_em FROM pedidos_internos WHERE num_pedido = 'PED-2937';


-- =====================================================================
-- PASSO 2 - FAZ TUDO (uma transacao: ou vai tudo, ou nada).
-- =====================================================================
BEGIN;

CREATE TEMP TABLE _lista(num text) ON COMMIT DROP;
INSERT INTO _lista VALUES   -- >>> LISTA (igual a do PASSO 1)
  ('PED-2949'),('PED-2952'),('PED-2953'),('PED-2966'),('PED-2972'),
  ('PED-2950'),('PED-2954'),('PED-2955'),('PED-2956'),('PED-2959'),
  ('PED-2960'),('PED-2961'),('PED-2963'),('PED-2965');

-- so pedidos que AINDA estao como recebidos naquele lote das 23h
CREATE TEMP TABLE _peds ON COMMIT DROP AS
SELECT p.* FROM pedidos_internos p JOIN _lista l ON l.num = p.num_pedido
 WHERE p.status = 'recebido'
   AND p.recebido_em BETWEEN '2026-09-29 03:03:00+00' AND '2026-09-29 03:07:00+00';

CREATE TEMP TABLE _alvo ON COMMIT DROP AS
SELECT p.num_pedido, p.setor, i.id AS item_id, i.produto_id, i.qtd_recebida AS q,
       EXISTS (SELECT 1 FROM est_movimentacoes m
                WHERE m.produto_id = i.produto_id AND m.local = 'ESTOQUE_LOJA'
                  AND m.tipo IN ('contagem','ajuste')
                  AND m.criado_em > '2026-09-29 03:07:00+00') AS loja_ja_contada,
       EXISTS (SELECT 1 FROM est_movimentacoes m
                WHERE m.produto_id = i.produto_id AND m.local = p.setor
                  AND m.tipo IN ('contagem','ajuste')
                  AND m.criado_em > '2026-09-29 03:07:00+00') AS setor_ja_contado
FROM _peds p JOIN pedidos_internos_itens i ON i.pedido_id = p.id
WHERE i.produto_id IS NOT NULL AND i.qtd_recebida > 0;

-- backups (ficam no banco; apagar daqui a alguns dias)
CREATE TABLE bkp_desfaz28_pedidos AS
  SELECT * FROM pedidos_internos WHERE id IN (SELECT id FROM _peds) OR num_pedido = 'PED-2937';
CREATE TABLE bkp_desfaz28_itens AS
  SELECT * FROM pedidos_internos_itens
   WHERE pedido_id IN (SELECT id FROM bkp_desfaz28_pedidos);
CREATE TABLE bkp_desfaz28_saldo AS
  SELECT s.* FROM est_saldo_local s
   WHERE (s.produto_id, s.local) IN (SELECT produto_id, setor FROM _alvo
                                     UNION SELECT produto_id, 'ESTOQUE_LOJA' FROM _alvo);

-- 2a) razao: estorno no SETOR (sinal contrario da entrada das 23:06)
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, ref_tabela, ref_id, responsavel, data)
SELECT produto_id, setor, 'pedido_interno_entrada', -q,
       'Estorno ' || num_pedido || ': liberado e recebido por engano em 28/09 23h (celular do Bar)',
       'estorno_28set', 'pedidos_internos_itens', item_id, 'correcao 29/09', DATE '2026-09-29'
FROM _alvo WHERE NOT setor_ja_contado;

-- 2b) razao: estorno no ESTOQUE DA LOJA (devolve a saida das 23:06)
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, ref_tabela, ref_id, responsavel, data)
SELECT produto_id, 'ESTOQUE_LOJA', 'pedido_interno_saida', q,
       'Estorno ' || num_pedido || ': liberado e recebido por engano em 28/09 23h (celular do Bar)',
       'estorno_28set', 'pedidos_internos_itens', item_id, 'correcao 29/09', DATE '2026-09-29'
FROM _alvo WHERE NOT loja_ja_contada;

-- 2c) saldo do setor
UPDATE est_saldo_local s
   SET saldo = s.saldo - a.q, updated_at = now()
  FROM (SELECT produto_id, setor, sum(q) AS q FROM _alvo WHERE NOT setor_ja_contado
         GROUP BY produto_id, setor) a
 WHERE s.produto_id = a.produto_id AND s.local = a.setor;

-- 2d) saldo do estoque da loja
UPDATE est_saldo_local s
   SET saldo = s.saldo + a.q, updated_at = now()
  FROM (SELECT produto_id, sum(q) AS q FROM _alvo WHERE NOT loja_ja_contada
         GROUP BY produto_id) a
 WHERE s.produto_id = a.produto_id AND s.local = 'ESTOQUE_LOJA';

-- 2e) itens e pedidos voltam para PENDENTE
UPDATE pedidos_internos_itens
   SET qtd_liberada = NULL, qtd_recebida = NULL
 WHERE pedido_id IN (SELECT id FROM _peds);

UPDATE pedidos_internos
   SET status = 'pendente', liberado_em = NULL, recebido_em = NULL,
       liberado_por = NULL, recebido_por = NULL
 WHERE id IN (SELECT id FROM _peds);

-- 2f) PED-2937 (27/09, liberado no lote e nunca recebido) -> encerrado
UPDATE pedidos_internos SET status = 'encerrado'
 WHERE num_pedido = 'PED-2937' AND status = 'liberado' AND recebido_em IS NULL;

-- trava: se algo nao bater, desfaz tudo
DO $chk$
DECLARE n_ped int; n_mov int; n_alvo int; n_setor int; n_loja int;
BEGIN
  SELECT count(*) INTO n_ped FROM _peds;
  SELECT count(*) INTO n_alvo FROM _alvo;
  SELECT count(*) FILTER (WHERE NOT setor_ja_contado),
         count(*) FILTER (WHERE NOT loja_ja_contada) INTO n_setor, n_loja FROM _alvo;
  SELECT count(*) INTO n_mov FROM est_movimentacoes WHERE origem = 'estorno_28set';
  IF n_ped <> (SELECT count(*) FROM _lista) THEN
    RAISE EXCEPTION 'Esperava % pedidos recebidos no lote das 23h, achei %. Nada foi alterado.', (SELECT count(*) FROM _lista), n_ped;
  END IF;
  IF n_mov <> n_setor + n_loja THEN
    RAISE EXCEPTION 'Movimentos de estorno: esperava %, gravou %. Nada foi alterado.', n_setor + n_loja, n_mov;
  END IF;
  RAISE NOTICE 'OK: % pedidos voltaram para pendente, % itens; % estornos no setor, % no estoque da loja.', n_ped, n_alvo, n_setor, n_loja;
END
$chk$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA.
-- =====================================================================
-- 3a) Os 14 pedidos: esperado status 'pendente', sem liberado/recebido.
SELECT num_pedido, setor, obs, status, liberado_em, recebido_em
  FROM pedidos_internos
 WHERE id IN (SELECT id FROM bkp_desfaz28_pedidos)
 ORDER BY setor, num_pedido;
-- (o PED-2937 aparece como 'encerrado')

-- 3b) Estornos gravados no razao, por local.
SELECT local, tipo, count(*) AS linhas, sum(quantidade) AS soma
  FROM est_movimentacoes WHERE origem = 'estorno_28set'
 GROUP BY local, tipo ORDER BY local;

-- 3c) Saldo x razao: para cada produto/local mexido, a diferenca do saldo
--     (depois - antes) tem que ser igual a soma dos estornos. Esperado: 0 linhas.
SELECT b.produto_id, b.local, b.saldo AS antes, s.saldo AS depois,
       coalesce(e.soma, 0) AS estorno
  FROM bkp_desfaz28_saldo b
  JOIN est_saldo_local s ON s.produto_id = b.produto_id AND s.local = b.local
  LEFT JOIN (SELECT produto_id, local, sum(quantidade) AS soma
               FROM est_movimentacoes WHERE origem = 'estorno_28set'
              GROUP BY produto_id, local) e
         ON e.produto_id = b.produto_id AND e.local = b.local
 WHERE abs((s.saldo - b.saldo) - coalesce(e.soma, 0)) > 0.0001;


-- =====================================================================
-- DESFAZER ESTE SQL (so se precisar voltar ao estado de antes):
-- =====================================================================
-- BEGIN;
-- UPDATE est_saldo_local s SET saldo = b.saldo, updated_at = now()
--   FROM bkp_desfaz28_saldo b WHERE s.id = b.id;
-- DELETE FROM est_movimentacoes WHERE origem = 'estorno_28set';
-- UPDATE pedidos_internos_itens i SET qtd_liberada = b.qtd_liberada, qtd_recebida = b.qtd_recebida
--   FROM bkp_desfaz28_itens b WHERE i.id = b.id;
-- UPDATE pedidos_internos p SET status = b.status, liberado_em = b.liberado_em,
--        recebido_em = b.recebido_em, liberado_por = b.liberado_por, recebido_por = b.recebido_por
--   FROM bkp_desfaz28_pedidos b WHERE p.id = b.id;
-- COMMIT;
-- (atencao: se o estoque ja tiver liberado de novo algum desses pedidos,
--  NAO use o desfazer sem falar comigo antes)
