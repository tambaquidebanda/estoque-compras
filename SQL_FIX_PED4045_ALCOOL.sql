-- =====================================================================
-- SQL_FIX_PED4045_ALCOOL.sql  (10/11/2026)
--
-- PED-4045 (emergência do Salão, 02/11 23h): MC ALCOOL LIQUIDO 70 foi
-- pedido e liberado como 500 L. O certo era 5 L (Wagner, 10/11). Na
-- confirmação o Salão registrou 0,5 L e o sistema devolveu 499,5 L ao
-- Estoque da Loja; por isso o SALDO JÁ ESTÁ CERTO e não muda aqui.
--
-- Só acerta o histórico (o Planejamento lia 500 L de saída e mandava
-- comprar 33 galões):
--   item do pedido: pedido 500 -> 5, liberado 500 -> 5 (chegou 0,5 fica);
--   saída do Estoque da Loja: -500 -> -5;
--   devolução da confirmação: +499,5 -> +4,5 ("liberado 5, chegou 0,5").
-- A soma dos movimentos continua -0,5, igual ao que já está no saldo.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SÓ LEITURA.
-- Esperado: item 500 / 500 / 0.5; movimentos -500 (loja), +499.5 (loja) e +0.5 (Salão) = soma 0.
SELECT nome, qtd_pedida, qtd_liberada, qtd_recebida
FROM pedidos_internos_itens WHERE id = '1cfdeff4-14d4-4c45-a0bb-50258a07c3c9';

SELECT local, tipo, quantidade, motivo
FROM est_movimentacoes WHERE ref_id = '1cfdeff4-14d4-4c45-a0bb-50258a07c3c9'
ORDER BY criado_em;


-- PASSO 2 - CORRIGE (tudo ou nada). Deve terminar com DO e COMMIT.
BEGIN;

DO $$
DECLARE
  c_item uuid := '1cfdeff4-14d4-4c45-a0bb-50258a07c3c9';
  v_soma0 numeric; v_saldo0 numeric; v_n int;
BEGIN
  SELECT sum(quantidade) INTO v_soma0 FROM est_movimentacoes WHERE ref_id = c_item;
  SELECT coalesce(sum(saldo), 0) INTO v_saldo0 FROM est_saldo_local;
  ASSERT v_soma0 = 0, format('soma dos movimentos do item deu %s, esperava 0 (-500 +499.5 +0.5)', v_soma0);
  ASSERT (SELECT qtd_pedida FROM pedidos_internos_itens WHERE id = c_item) = 500, 'item não está com 500 pedido';

  UPDATE pedidos_internos_itens SET qtd_pedida = 5, qtd_liberada = 5 WHERE id = c_item AND qtd_liberada = 500;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, 'item não atualizado';

  UPDATE est_movimentacoes SET quantidade = -5
   WHERE ref_id = c_item AND tipo = 'pedido_interno_saida' AND local = 'ESTOQUE_LOJA' AND quantidade = -500;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, 'saída de -500 não encontrada';

  UPDATE est_movimentacoes SET quantidade = 4.5,
         motivo = 'Diferença na confirmação PED-4045: liberado 5, chegou 0,5 (corrigido 10/11: era 500)'
   WHERE ref_id = c_item AND tipo = 'ajuste' AND local = 'ESTOQUE_LOJA' AND quantidade = 499.5;
  GET DIAGNOSTICS v_n = ROW_COUNT; ASSERT v_n = 1, 'devolução de 499.5 não encontrada';

  ASSERT (SELECT sum(quantidade) FROM est_movimentacoes WHERE ref_id = c_item) = v_soma0, 'a soma dos movimentos mudou';
  ASSERT (SELECT coalesce(sum(saldo), 0) FROM est_saldo_local) = v_saldo0, 'o saldo mudou - nada foi gravado';
END $$;

COMMIT;


-- PASSO 3 - CONFERÊNCIA: rodar o PASSO 1 de novo.
-- Esperado: item 5 / 5 / 0.5; movimentos -5, +4.5 e +0.5 (Salão).
