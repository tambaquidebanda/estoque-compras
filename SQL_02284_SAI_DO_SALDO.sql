-- =====================================================================
-- SQL_02284_SAI_DO_SALDO.sql  (16/11/2026)
--
-- #02284 ALBERTA CARLA SANTOS - Delivery P10, 19 MP PUDIM DE LEITE x R$ 5,50
-- (R$ 104,50), entrega de 15/10, vencimento 15/11.
-- O pedido foi criado hoje (Naldo) e recebido hoje (Wagner Souza) SÓ para
-- o financeiro ter a conta para pagar. Os pudins de 15/10 já foram vendidos,
-- mas o recebimento de hoje somou +19 no ESTOQUE DELIVERY (18 -> 37).
--
-- Este SQL tira esses 19 do saldo do ESTOQUE DELIVERY e grava a saída no
-- razão (est_movimentacoes), amarrada ao item do recebimento.
-- Pedido, recebimento, conta a pagar e rascunho do financeiro (R$ 104,50)
-- ficam como estão.
--
-- Rode UM PASSO DE CADA VEZ. Se der "ASSERT failed", nada foi gravado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Esperado: ESTOQUE DELIVERY = 37 e 1 entrada de +19
-- do recebimento de hoje.
-- ---------------------------------------------------------------------
SELECT 'saldo' AS o_que, s.local, s.saldo AS qtd, s.updated_at::text AS quando
  FROM est_saldo_local s
 WHERE s.produto_id = 'aaea9345-7669-4fb4-bac1-7e1a5fde0af2' AND s.local = 'ESTOQUE DELIVERY'
UNION ALL
SELECT 'movimento ' || m.tipo, m.local, m.quantidade, m.criado_em::text
  FROM est_movimentacoes m
 WHERE m.produto_id = 'aaea9345-7669-4fb4-bac1-7e1a5fde0af2' AND m.local = 'ESTOQUE DELIVERY'
   AND m.criado_em >= '2026-11-16';


-- ---------------------------------------------------------------------
-- PASSO 2 - TIRA OS 19 PUDINS DO ESTOQUE DELIVERY.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  c_prod  constant uuid := 'aaea9345-7669-4fb4-bac1-7e1a5fde0af2';   -- MP PUDIM DE LEITE
  c_mov   constant uuid := '9671c22b-d480-4fd4-86e5-a932dcb63030';   -- entrada +19 do recebimento de hoje
  c_item  constant uuid := 'f9ae12d2-79f5-4493-a68a-d47b99663fa1';   -- item do recebimento #02284
  v_saldo0 numeric; v_n int;
BEGIN
  ASSERT (SELECT quantidade = 19 AND local = 'ESTOQUE DELIVERY' AND produto_id = c_prod
            FROM est_movimentacoes WHERE id = c_mov), 'entrada de +19 do #02284 não confere';
  ASSERT (SELECT qtd_recebida FROM cmp_recebimento_itens WHERE id = c_item) = 19, 'item do recebimento #02284 não confere';
  ASSERT NOT EXISTS (SELECT 1 FROM est_movimentacoes WHERE ref_id = c_item), 'a saída do #02284 já foi gravada';

  SELECT saldo INTO v_saldo0 FROM est_saldo_local WHERE produto_id = c_prod AND local = 'ESTOQUE DELIVERY';
  ASSERT v_saldo0 >= 19, format('ESTOQUE DELIVERY tem %s pudins, menos que 19', v_saldo0);

  UPDATE est_saldo_local SET saldo = saldo - 19, updated_at = now()
   WHERE produto_id = c_prod AND local = 'ESTOQUE DELIVERY';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, 'não atualizou o saldo';

  INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, custo_unit, motivo, origem, ref_tabela, ref_id, responsavel)
  VALUES (c_prod, 'ESTOQUE DELIVERY', 'recebimento', -19, 5.50,
          'Pedido #02284 só para pagamento (entrega de 15/10 já vendida): sai do saldo',
          'estorno_recebimento', 'cmp_recebimento_itens', c_item, 'Ajuste SQL 16/11');

  ASSERT (SELECT saldo FROM est_saldo_local WHERE produto_id = c_prod AND local = 'ESTOQUE DELIVERY') = v_saldo0 - 19, 'saldo não baixou 19';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - SÓ LEITURA. Esperado: ESTOQUE DELIVERY = 18 (37 - 19), a
-- entrada +19 e a saída -19 de hoje.
-- ---------------------------------------------------------------------
SELECT 'saldo' AS o_que, s.local, s.saldo AS qtd, s.updated_at::text AS quando
  FROM est_saldo_local s
 WHERE s.produto_id = 'aaea9345-7669-4fb4-bac1-7e1a5fde0af2' AND s.local = 'ESTOQUE DELIVERY'
UNION ALL
SELECT 'movimento ' || m.tipo, m.local, m.quantidade, m.criado_em::text
  FROM est_movimentacoes m
 WHERE m.produto_id = 'aaea9345-7669-4fb4-bac1-7e1a5fde0af2' AND m.local = 'ESTOQUE DELIVERY'
   AND m.criado_em >= '2026-11-16';
