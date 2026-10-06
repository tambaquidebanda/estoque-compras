-- =====================================================================
-- SQL_FIX_01669_VALOR_117.sql   (06/10/2026)
--
-- O QUE FAZ
--   Deixa o #01669 no estoque com o valor real da compra:
--   36 PA de MP SCHWEPPES TONICA LATA x 3,25 = R$ 117,00.
--   O recebimento tinha sido gravado com R$ 6,00 (o valor que o financeiro
--   paga, porque R$ 111,00 foram pagos com voucher), e por isso o
--   impresso mostrava 0,17 por lata.
--
--   Altera (so tabelas do estoque):
--     cmp_recebimento_itens.total_recebido  6,00 -> 117,00
--     cmp_recebimentos.total_recebido       6,00 -> 117,00
--     cmp_contas_pagar.valor                6,00 -> 117,00
--     cmp_compras.observacao                anota o voucher
--
--   NAO altera: lancamentos (a despesa no financeiro continua R$ 6,00),
--   quantidade, saldo, custo (ja esta 3,25 desde o SQL anterior).
--
--   A diferenca de R$ 111,00 entre estoque (117) e financeiro (6) e de
--   proposito: e o voucher. Fica explicada na observacao do pedido.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA. Esperado: os tres valores em 6,00.
-- =====================================================================
SELECT 'recebimento_item' AS onde, ri.total_recebido AS valor
  FROM cmp_recebimento_itens ri WHERE ri.id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02'
UNION ALL
SELECT 'recebimento', r.total_recebido
  FROM cmp_recebimentos r WHERE r.id = '7550b80e-57d7-4eee-b565-82d9b3e0e0bf'
UNION ALL
SELECT 'conta_a_pagar', cp.valor
  FROM cmp_contas_pagar cp WHERE cp.pedido_num = '#01669'
UNION ALL
SELECT 'lancamento (nao muda)', l.valor
  FROM lancamentos l WHERE l.numero_pedido = '#01669';


-- =====================================================================
-- PASSO 2 - CORRECAO (tudo ou nada; so altera o que ainda estiver em 6,00)
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS bkp_fix_01669_valor_20261006 AS
SELECT 'cmp_recebimento_itens'::text AS tabela, id::text AS id, total_recebido::numeric AS valor_antes, NULL::text AS obs_antes, now() AS em
  FROM cmp_recebimento_itens WHERE id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02'
UNION ALL
SELECT 'cmp_recebimentos', id::text, total_recebido::numeric, NULL, now()
  FROM cmp_recebimentos WHERE id = '7550b80e-57d7-4eee-b565-82d9b3e0e0bf'
UNION ALL
SELECT 'cmp_contas_pagar', id::text, valor::numeric, NULL, now()
  FROM cmp_contas_pagar WHERE pedido_num = '#01669'
UNION ALL
SELECT 'cmp_compras', id::text, total::numeric, observacao, now()
  FROM cmp_compras WHERE id = '1818fd64-22b8-4344-8fc0-209cdb9b0a04';

ALTER TABLE bkp_fix_01669_valor_20261006 ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM bkp_fix_01669_valor_20261006;
  IF n <> 4 THEN RAISE EXCEPTION 'Backup com % linhas (esperado 4). Nada foi alterado.', n; END IF;

  UPDATE cmp_recebimento_itens SET total_recebido = 117.00
   WHERE id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02' AND total_recebido = 6.00 AND qtd_recebida = 36;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'cmp_recebimento_itens: % linhas (esperado 1).', n; END IF;

  UPDATE cmp_recebimentos SET total_recebido = 117.00
   WHERE id = '7550b80e-57d7-4eee-b565-82d9b3e0e0bf' AND total_recebido = 6.00;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'cmp_recebimentos: % linhas (esperado 1).', n; END IF;

  UPDATE cmp_contas_pagar SET valor = 117.00
   WHERE pedido_num = '#01669' AND valor = 6.00;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'cmp_contas_pagar: % linhas (esperado 1).', n; END IF;

  UPDATE cmp_compras
     SET observacao = 'R$ 111,00 pagos com voucher da loja (devolucao de verdura congelada em 23/09, compra que nao passou pelo estoque). Financeiro paga R$ 6,00.'
   WHERE id = '1818fd64-22b8-4344-8fc0-209cdb9b0a04' AND observacao IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN RAISE EXCEPTION 'cmp_compras: % linhas (esperado 1).', n; END IF;
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura)
-- Esperado: 117,00 nos tres primeiros; lancamento continua 6,00.
-- =====================================================================
SELECT 'recebimento_item' AS onde, ri.total_recebido AS valor
  FROM cmp_recebimento_itens ri WHERE ri.id = 'df0d7cae-342e-4284-80e1-2ebb67a4dc02'
UNION ALL
SELECT 'recebimento', r.total_recebido
  FROM cmp_recebimentos r WHERE r.id = '7550b80e-57d7-4eee-b565-82d9b3e0e0bf'
UNION ALL
SELECT 'conta_a_pagar', cp.valor
  FROM cmp_contas_pagar cp WHERE cp.pedido_num = '#01669'
UNION ALL
SELECT 'lancamento (nao muda)', l.valor
  FROM lancamentos l WHERE l.numero_pedido = '#01669';
