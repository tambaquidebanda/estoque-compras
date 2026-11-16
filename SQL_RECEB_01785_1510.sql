-- =====================================================================
-- SQL_RECEB_01785_1510.sql  (16/11/2026)
--
-- #01785 ALBERTA CARLA SANTOS (pedido de 13/10) teve DUAS entregas:
--   15/10  19 MP PUDIM DE LEITE  x R$ 5,50 = R$ 104,50   <- some do sistema
--   19/10  16 BROWNIE + 12 CHEESECAKE        = R$ 252,00   <- está ok
--
-- O que apagou a 1ª: em 19/10 às 15:01 o "Devolver pedido ao estoque"
-- (login do Anderson) desfez o recebimento de 15/10, tirou os 19 pudins
-- do estoque e excluiu o lançamento de R$ 104,50 do financeiro. Depois o
-- pedido foi recebido de novo só com brownie + cheesecake, e o pudim ficou
-- "dispensado". A equipe confirmou em 16/11: foram duas entregas.
--
-- Este SQL refaz a entrega de 15/10 do jeito que o recebimento parcial
-- faz pela tela: UMA conta por pedido com a soma dos recebimentos, e o
-- lançamento do financeiro com o mesmo total.
--   * recebimento de 15/10 com 19 pudins (R$ 104,50), item com o MESMO id
--     que o estorno de 19/10 aponta (o razão fica amarrado);
--   * linha do pudim no pedido: dispensado -> recebido, 19 un.;
--   * conta a pagar do #01785: R$ 252,00 -> R$ 356,50;
--   * lançamento 78cf3bc7 (pendente, venc. 15/11): R$ 252,00 -> R$ 356,50.
--
-- NADA aqui mexe no estoque (est_movimentacoes / est_saldo_local): os
-- pudins de 15/10 já foram vendidos e as contagens acertaram o saldo.
-- O lançamento excluído de R$ 104,50 continua em lancamentos_excluidos
-- como histórico; não é restaurado (o valor entra no lançamento único).
--
-- Rode UM PASSO DE CADA VEZ. Se der "ASSERT failed", nada foi gravado:
-- me mande a mensagem.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Como está hoje.
-- Esperado:
--   recebimentos = 1 (19/10, 252,00)
--   conta        = 252,00 pendente, lançamento 78cf3bc7
--   lançamento   = 252,00 pendente, valor_pago 0
--   pudim        = dispensado, 12 un.
-- ---------------------------------------------------------------------
SELECT 'recebimento' AS o_que, r.data_receb::text AS data, r.total_recebido AS valor, r.responsavel AS obs
  FROM cmp_recebimentos r WHERE r.pedido_num = '#01785'
UNION ALL
SELECT 'conta', k.data_receb::text, k.valor, k.status || ' / lanc ' || coalesce(k.lancamento_id::text, '-')
  FROM cmp_contas_pagar k WHERE k.pedido_num = '#01785'
UNION ALL
SELECT 'lançamento', l.vencimento::text, l.valor, l.status || ' / pago ' || l.valor_pago
  FROM lancamentos l WHERE l.numero_pedido = '#01785'
UNION ALL
SELECT 'item ' || c.produto, c.status_receb, c.quantidade, c.custo_unit::text
  FROM cmp_compras c WHERE c.pedido_num = '#01785';


-- ---------------------------------------------------------------------
-- PASSO 2 - GRAVA A ENTREGA DE 15/10 E AJUSTA CONTA + LANÇAMENTO.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_movs0 int; v_saldo0 numeric; v_lanc0 int; v_n int; v_receb uuid;
  c_pudim  constant uuid := 'c606a41e-16bc-4b8a-8940-da1b8a0f024b';  -- linha MP PUDIM DE LEITE do #01785
  c_item   constant uuid := '62584d00-362f-4b37-915b-1c14f1198c9f';  -- id do item que o estorno de 19/10 aponta
  c_conta  constant uuid := 'dad136e1-0a58-44c9-95b3-694c93aa4cbb';  -- conta a pagar do #01785
  c_lanc   constant uuid := '78cf3bc7-1ed2-4878-a4c5-7e2b8c9d3e15';  -- lançamento do #01785
BEGIN
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo),0) INTO v_saldo0 FROM est_saldo_local;
  SELECT count(*) INTO v_lanc0 FROM lancamentos;

  -- Conferências antes de gravar
  ASSERT (SELECT count(*) FROM cmp_recebimentos WHERE pedido_num = '#01785') = 1, '#01785 não tem exatamente 1 recebimento';
  ASSERT (SELECT sum(total_recebido) FROM cmp_recebimentos WHERE pedido_num = '#01785') = 252.00, 'recebimento atual não é 252,00';
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimento_itens WHERE id = c_item), 'o item de 15/10 já existe';
  ASSERT (SELECT count(*) FROM cmp_contas_pagar WHERE pedido_num = '#01785') = 1, '#01785 não tem exatamente 1 conta';
  ASSERT (SELECT valor FROM cmp_contas_pagar WHERE id = c_conta) = 252.00
     AND (SELECT lancamento_id FROM cmp_contas_pagar WHERE id = c_conta) = c_lanc, 'conta do #01785 não confere (252,00 / 78cf3bc7)';
  ASSERT (SELECT count(*) FROM lancamentos WHERE numero_pedido = '#01785') = 1, '#01785 não tem exatamente 1 lançamento';
  ASSERT (SELECT valor = 252.00 AND status = 'pendente' AND coalesce(valor_pago,0) = 0 AND NOT coalesce(tem_rateio,false)
            FROM lancamentos WHERE id = c_lanc), 'lançamento não está 252,00 pendente sem pagamento';
  ASSERT (SELECT status_receb FROM cmp_compras WHERE id = c_pudim AND pedido_num = '#01785') = 'dispensado', 'linha do pudim não está dispensada';

  -- 1) Recebimento de 15/10
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, criado_em, local)
  VALUES ('#01785', '2026-10-15',
          'Ajuste SQL 16/11 (entrega de 15/10 desfeita pelo Devolver em 19/10; sem entrar no estoque)',
          'ALBERTA CARLA SANTOS', 'Carla Mota', 104.50, 'confirmado', '2026-10-15 17:32:40+00', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;

  INSERT INTO cmp_recebimento_itens (id, recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
                                     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado)
  VALUES (c_item, v_receb, c_pudim, 'MP PUDIM DE LEITE', 'Sobremesas', 'UN', 12, 19,
          5.50, 104.50, true, 'Pedido 12, chegaram 19 (refeito por SQL em 16/11)',
          'aaea9345-7669-4fb4-bac1-7e1a5fde0af2', false);

  -- 2) Linha do pudim no pedido: recebida, com o que entrou
  UPDATE cmp_compras SET status_receb = 'recebido', quantidade = 19, custo_unit = 5.50 WHERE id = c_pudim;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, 'não atualizou a linha do pudim';
  IF (SELECT is_generated FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'cmp_compras' AND column_name = 'total') = 'NEVER' THEN
    EXECUTE 'UPDATE cmp_compras SET total = 104.50 WHERE id = $1' USING c_pudim;
  END IF;

  -- 3) Conta a pagar e lançamento: soma dos dois recebimentos
  UPDATE cmp_contas_pagar SET valor = 356.50 WHERE id = c_conta;
  UPDATE lancamentos      SET valor = 356.50 WHERE id = c_lanc;

  -- Conferências depois
  ASSERT (SELECT sum(total_recebido) FROM cmp_recebimentos WHERE pedido_num = '#01785') = 356.50, 'soma dos recebimentos não deu 356,50';
  ASSERT (SELECT valor FROM cmp_contas_pagar WHERE id = c_conta) = 356.50, 'conta não ficou 356,50';
  ASSERT (SELECT valor FROM lancamentos WHERE id = c_lanc) = 356.50, 'lançamento não ficou 356,50';
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque (movimentos) - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo),0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
  ASSERT (SELECT count(*) FROM lancamentos) = v_lanc0, 'nasceu ou sumiu lançamento - nada foi gravado';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - SÓ LEITURA. Conferência.
-- Esperado:
--   2 recebimentos: 15/10 104,50 e 19/10 252,00
--   conta 356,50 pendente / lançamento 356,50 pendente
--   pudim recebido 19 / brownie recebido 16 / cheesecake recebido 12 /
--   céu de brigadeiro dispensado
-- ---------------------------------------------------------------------
SELECT 'recebimento' AS o_que, r.data_receb::text AS data, r.total_recebido AS valor, r.responsavel AS obs
  FROM cmp_recebimentos r WHERE r.pedido_num = '#01785'
UNION ALL
SELECT 'conta', k.data_receb::text, k.valor, k.status || ' / lanc ' || coalesce(k.lancamento_id::text, '-')
  FROM cmp_contas_pagar k WHERE k.pedido_num = '#01785'
UNION ALL
SELECT 'lançamento', l.vencimento::text, l.valor, l.status || ' / pago ' || l.valor_pago
  FROM lancamentos l WHERE l.numero_pedido = '#01785'
UNION ALL
SELECT 'item ' || c.produto, c.status_receb, c.quantidade, c.custo_unit::text
  FROM cmp_compras c WHERE c.pedido_num = '#01785'
ORDER BY 1, 2;
