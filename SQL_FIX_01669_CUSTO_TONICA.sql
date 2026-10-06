-- =====================================================================
-- SQL_FIX_01669_CUSTO_TONICA.sql   (06/10/2026)
--
-- O QUE ACONTECEU
--   O pedido #01669 (36 PA de MP SCHWEPPES TONICA LATA) foi recebido no
--   celular com o total de R$ 6,00, o valor que o financeiro vai pagar,
--   e nao com os R$ 117,00 da compra (36 x 3,25). R$ 111,00 foram pagos
--   com o voucher da devolucao de 23/09.
--   O recebimento gravou o custo da lata como 0,1667 (6,00 / 36) e
--   espalhou esse custo para o cadastro e para 4 fichas:
--   SCHWEPPES TONICA LT, L AMOUR ROSE, LE MAGNIFIQUE, LA PASSION.
--
-- O QUE ESTE SQL FAZ (so o lado do custo; o dinheiro fica como esta)
--   - Volta o custo unitario da Tonica para 3,25 em 4 lugares:
--       cmp_recebimento_itens  (recebimento do #01669)
--       cmp_compras            (linha do #01669)
--       est_movimentacoes      (entrada das 36 latas no Estoque da Loja)
--       est_produtos.custo_comp
--   - NAO mexe em: total_recebido (6,00), cmp_contas_pagar (6,00),
--     lancamentos, quantidade, saldo.
--
-- DEPOIS DE RODAR
--   Abrir a aba Produtos no sistema (F5 antes): a sincronizacao automatica
--   recalcula as 4 fichas com o custo novo.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA. Confere o estado atual.
-- Esperado: as 4 linhas com custo 0,1667 (ou 0,1666...).
-- =====================================================================
SELECT 'recebimento_item' AS onde, ri.id::text, ri.valor_unitario AS custo, ri.total_recebido AS total
  FROM cmp_recebimento_itens ri
 WHERE ri.id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02'
UNION ALL
SELECT 'compra_linha', c.id::text, c.custo_unit, c.total
  FROM cmp_compras c
 WHERE c.id = '1818fd64-22b8-4344-8fc0-209cdb9b0a04'
UNION ALL
SELECT 'movimentacao', m.id::text, m.custo_unit, m.quantidade
  FROM est_movimentacoes m
 WHERE m.id = 'd1b32fd9-0065-4aa9-a068-c4f5ac2c45e4'
UNION ALL
SELECT 'produto', p.id::text, p.custo_comp, NULL
  FROM est_produtos p
 WHERE p.id = 'd30b8e5c-bbda-4525-90e9-77e716101087';

-- Gatilhos nessas tabelas (so para saber o que dispara no UPDATE)
SELECT event_object_table AS tabela, trigger_name, event_manipulation
  FROM information_schema.triggers
 WHERE event_object_table IN ('cmp_recebimento_itens','cmp_compras','est_movimentacoes','est_produtos')
 ORDER BY 1, 2;


-- =====================================================================
-- PASSO 2 - CORRECAO (tudo ou nada)
-- Guardas: so altera se o custo ainda estiver no valor errado (< 1,00).
-- Se alguma linha nao bater, o bloco para e nada e gravado.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS bkp_fix_01669_tonica_20261006 AS
SELECT 'cmp_recebimento_itens'::text AS tabela, id::text AS id, valor_unitario::numeric AS custo_antes, now() AS em
  FROM cmp_recebimento_itens WHERE id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02'
UNION ALL
SELECT 'cmp_compras', id::text, custo_unit::numeric, now()
  FROM cmp_compras WHERE id = '1818fd64-22b8-4344-8fc0-209cdb9b0a04'
UNION ALL
SELECT 'est_movimentacoes', id::text, custo_unit::numeric, now()
  FROM est_movimentacoes WHERE id = 'd1b32fd9-0065-4aa9-a068-c4f5ac2c45e4'
UNION ALL
SELECT 'est_produtos', id::text, custo_comp::numeric, now()
  FROM est_produtos WHERE id = 'd30b8e5c-bbda-4525-90e9-77e716101087';

ALTER TABLE bkp_fix_01669_tonica_20261006 ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM bkp_fix_01669_tonica_20261006;
  IF n <> 4 THEN RAISE EXCEPTION 'Backup com % linhas (esperado 4). Nada foi alterado.', n; END IF;

  UPDATE cmp_recebimento_itens SET valor_unitario = 3.25
   WHERE id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02' AND valor_unitario < 1;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'cmp_recebimento_itens: % linhas (esperado 1).', n; END IF;

  UPDATE cmp_compras SET custo_unit = 3.25
   WHERE id = '1818fd64-22b8-4344-8fc0-209cdb9b0a04' AND custo_unit < 1 AND quantidade = 36;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'cmp_compras: % linhas (esperado 1).', n; END IF;

  UPDATE est_movimentacoes SET custo_unit = 3.25
   WHERE id = 'd1b32fd9-0065-4aa9-a068-c4f5ac2c45e4' AND custo_unit < 1 AND quantidade = 36;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'est_movimentacoes: % linhas (esperado 1).', n; END IF;

  UPDATE est_produtos SET custo_comp = 3.25
   WHERE id = 'd30b8e5c-bbda-4525-90e9-77e716101087' AND custo_comp < 1;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'est_produtos: % linhas (esperado 1).', n; END IF;
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura)
-- Esperado: custo 3,25 nas 4 linhas; total_recebido continua 6,00;
-- conta a pagar continua 6,00.
-- =====================================================================
SELECT 'recebimento_item' AS onde, ri.valor_unitario AS custo, ri.total_recebido AS total
  FROM cmp_recebimento_itens ri WHERE ri.id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02'
UNION ALL
SELECT 'compra_linha', c.custo_unit, c.total
  FROM cmp_compras c WHERE c.id = '1818fd64-22b8-4344-8fc0-209cdb9b0a04'
UNION ALL
SELECT 'movimentacao', m.custo_unit, m.quantidade
  FROM est_movimentacoes m WHERE m.id = 'd1b32fd9-0065-4aa9-a068-c4f5ac2c45e4'
UNION ALL
SELECT 'produto', p.custo_comp, NULL
  FROM est_produtos p WHERE p.id = 'd30b8e5c-bbda-4525-90e9-77e716101087'
UNION ALL
SELECT 'conta_a_pagar (nao muda)', NULL, cp.valor
  FROM cmp_contas_pagar cp WHERE cp.pedido_num = '#01669';
