-- =====================================================================
-- SQL_AMBEV_NF88952.sql  (10/11/2026)
--
-- Sábado 31/10 a AMBEV entregou dois chopes de 200 L, cada um com nota de
-- R$ 2.660,79:
--   NF 88950 -> pedido #02016 (boleto R$ 2.662,34, pago e conciliado hoje)
--   NF 88952 -> entrou no estoque às 12:12 como parte do #02001 (350 L),
--               mas ficou sem lançamento no financeiro; o boleto de
--               R$ 2.660,79 foi pago hoje no banco.
-- O #02001 (350 L) chegou em duas notas: 200 L em 31/10 (NF 88952) e 150 L
-- em 03/11 (boleto R$ 1.995,59, já pago e conciliado).
--
-- Este SQL:
--   - #02016: data do recebimento 03/11 -> 31/10 (erro do acerto de hoje) e NF 88950 na conta;
--   - #02001: separa o recebimento em dois (31/10 200 L e 03/11 150 L), conta passa
--     a R$ 4.656,38 em 2 parcelas;
--   - cria o lançamento da NF 88952 (R$ 2.660,79) no #02001 como PENDENTE, vencimento
--     10/11, para a conciliação do extrato casar com o pagamento de hoje e dar a baixa
--     (assim não fica pago em dobro nem sem o vínculo do OFX).
-- NÃO mexe no estoque: os 350 L do #02001 e os 200 L do #02016 já estão certos
-- (o passo confere isso no fim e desfaz tudo se mudar).
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA.
-- Esperado: #02001 com 1 recebimento de 4655.59 (03/11) e 1 lançamento de 1995.59;
-- #02016 com 1 recebimento de 2660.79 (03/11) e 1 lançamento de 2662.34;
-- nenhum lançamento de 2660.79 da AMBEV com data de hoje.
-- ---------------------------------------------------------------------
SELECT r.pedido_num, r.data_receb, r.total_recebido, i.qtd_recebida, i.total_recebido AS total_item
FROM cmp_recebimentos r JOIN cmp_recebimento_itens i ON i.recebimento_id = r.id
WHERE r.pedido_num IN ('#02001', '#02016') ORDER BY r.pedido_num, r.data_receb;

SELECT numero_pedido, valor, status, vencimento, data_pagamento, ofx_id IS NOT NULL AS conciliado
FROM lancamentos WHERE numero_pedido IN ('#02001', '#02016') ORDER BY numero_pedido;

SELECT pedido_num, valor, parcelas, data_receb, nf_numero FROM cmp_contas_pagar
WHERE pedido_num IN ('#02001', '#02016');


-- ---------------------------------------------------------------------
-- PASSO 2 - GRAVA (tudo junto ou nada). Deve terminar com DO e COMMIT.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_movs0 int; v_saldo0 numeric; v_n int; v_receb uuid;
  c_rec01   uuid := '565e5bf9-4e91-4be6-9f7d-0b049db13d6f';  -- recebimento atual do #02001
  c_rec16   uuid := '805c8300-fc33-4faf-9226-ded9eac94e14';  -- recebimento do #02016
  c_conta01 uuid := '9a1e997e-0cfd-46c4-b66c-cedc7d78e9e7';
  c_conta16 uuid := '2117a322-c082-437b-9cf9-463001ef7747';
  c_lanc01  uuid := '5e98fce9-c134-4e46-aa40-09ad844b5efb';  -- 1995.59 pago (150 L)
  c_compra  uuid := 'a454a254-c2ed-41d9-b4a5-2a54febe671c';  -- linha do chopp do #02001
BEGIN
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo), 0) INTO v_saldo0 FROM est_saldo_local;

  -- Travas
  ASSERT (SELECT count(*) FROM cmp_recebimentos WHERE pedido_num = '#02001') = 1, '#02001 não tem exatamente 1 recebimento';
  ASSERT (SELECT total_recebido FROM cmp_recebimentos WHERE id = c_rec01) = 4655.59, '#02001: recebimento não é 4655.59';
  ASSERT (SELECT count(*) FROM cmp_recebimento_itens WHERE recebimento_id = c_rec01 AND compra_id = c_compra AND qtd_recebida = 350) = 1, '#02001: item de 350 L não confere';
  ASSERT (SELECT count(*) FROM lancamentos WHERE numero_pedido = '#02001') = 1, '#02001 já tem mais de um lançamento';
  ASSERT (SELECT valor FROM lancamentos WHERE id = c_lanc01) = 1995.59, '#02001: lançamento não é 1995.59';
  ASSERT (SELECT lancamento_id FROM cmp_contas_pagar WHERE id = c_conta01) = c_lanc01, '#02001: conta não aponta para o lançamento de 1995.59';
  ASSERT (SELECT data_receb FROM cmp_recebimentos WHERE id = c_rec16) = DATE '2026-11-03', '#02016: recebimento não está em 03/11';
  ASSERT NOT EXISTS (SELECT 1 FROM lancamentos WHERE fornecedor_id = '7152f6cb-b945-4655-b48f-bb526baab29d'
                       AND valor = 2660.79 AND criado_em > now() - interval '30 days'), 'já existe lançamento AMBEV de 2660.79 recente';

  -- #02016: data certa (31/10) e a nota
  UPDATE cmp_recebimentos SET data_receb = DATE '2026-10-31' WHERE id = c_rec16;
  UPDATE cmp_contas_pagar SET data_receb = DATE '2026-10-31', nf_numero = '88950' WHERE id = c_conta16;

  -- #02001: o recebimento atual vira o de 03/11 (150 L, R$ 1.995,00 + 0,59)
  UPDATE cmp_recebimento_itens SET qtd_recebida = 150, total_recebido = 1995.00, divergencia = true,
         obs_divergencia = 'Os outros 200 L chegaram em 31/10 (NF 88952)'
   WHERE recebimento_id = c_rec01 AND compra_id = c_compra;
  UPDATE cmp_recebimentos SET total_recebido = 1995.59, status = 'parcial', data_receb = DATE '2026-11-03',
         responsavel = 'Ajuste SQL 10/11 (150 L de 03/11; desfeito pelo Devolver, conferido pela equipe)'
   WHERE id = c_rec01;

  -- #02001: recebimento de 31/10 (200 L, NF 88952, R$ 2.660,00 + 0,79)
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02001', DATE '2026-10-31', 'Ajuste SQL 10/11 (NF 88952, 200 L de 31/10 12:12)',
          'AMBEV', 'Naldo Souza', 2660.79, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, 200, c.custo_unit, 2660.00, true,
         'NF 88952; os outros 150 L chegaram em 03/11', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.id = c_compra AND c.pedido_num = '#02001';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, 'não gravou o item de 31/10';

  -- Pedido e conta do #02001: 350 L × 13,30 = 4.655,00 + 1,38 das duas notas = 4.656,38, em 2 parcelas
  UPDATE cmp_compras SET acrescimo = 1.38 WHERE pedido_num = '#02001';
  UPDATE cmp_contas_pagar SET valor = 4656.38, parcelas = 2, data_receb = DATE '2026-10-31', nf_numero = '88952'
   WHERE id = c_conta01;

  -- Lançamento da NF 88952 (2ª parcela do #02001): PENDENTE, a conciliação do extrato dá a baixa
  INSERT INTO lancamentos (descricao, valor, vencimento, status, tipo, plano_conta_id, unidade_id, banco_id,
         observacoes, numero_pedido, fornecedor_id, tem_rateio, acrescimo, desconto, valor_pago)
  SELECT 'Pedido #02001 — AMBEV (2/2)', 2660.79, DATE '2026-11-10', 'pendente', 'pagar', plano_conta_id, unidade_id, banco_id,
         'Pedido #02001 — NF 88952 (200 L entregues em 31/10). Boleto pago no banco em 10/11: conciliar com o extrato.',
         '#02001', fornecedor_id, false, 0, 0, 0
    FROM lancamentos WHERE id = c_lanc01;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, 'não criou o lançamento da NF 88952';

  -- Conferências finais
  ASSERT (SELECT sum(total_recebido) FROM cmp_recebimentos WHERE pedido_num = '#02001') = 4656.38, '#02001: recebimentos não somam 4656.38';
  ASSERT (SELECT sum(qtd_recebida) FROM cmp_recebimento_itens i JOIN cmp_recebimentos r ON r.id = i.recebimento_id
           WHERE r.pedido_num = '#02001') = 350, '#02001: recebidos não somam 350 L';
  ASSERT (SELECT sum(valor) FROM lancamentos WHERE numero_pedido = '#02001') = 4656.38, '#02001: lançamentos não somam 4656.38';
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo), 0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERÊNCIA: rodar o PASSO 1 de novo.
-- Esperado: #02001 com 2 recebimentos (31/10 2660.79 com 200 L; 03/11 1995.59 com 150 L),
-- 2 lançamentos (1995.59 pago; 2660.79 pendente), conta 4656.38 em 2 parcelas, NF 88952;
-- #02016 com recebimento em 31/10 e NF 88950.
--
-- PASSO 4 - NO FINANCEIRO (não é SQL): na conciliação do extrato de hoje, casar o
-- pagamento de R$ 2.660,79 com o lançamento "Pedido #02001 — AMBEV (2/2)".
-- ---------------------------------------------------------------------
