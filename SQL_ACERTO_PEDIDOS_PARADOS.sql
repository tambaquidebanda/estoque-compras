-- =====================================================================
-- SQL_ACERTO_PEDIDOS_PARADOS.sql  (10/11/2026)
--
-- Fecha os pedidos parados no Recebimento com as respostas da equipe
-- (página "27 pedidos parados", respondida em 10/11). 25 pedidos aqui;
-- o #02003 já foi recebido pela tela hoje e o #01323 (100 tambaquis,
-- R$ 5.500) espera decisão: o Pescado não cobrou ele.
--
-- NADA aqui mexe no estoque: não grava em est_movimentacoes nem em
-- est_saldo_local (o saldo já está certo pelas contagens). Cada passo
-- confere isso no fim e, se algo mudar, desfaz tudo.
-- Também não cria nem altera lançamento no financeiro.
--
-- Rode UM PASSO DE CADA VEZ. Cada passo de gravação termina com COMMIT;
-- se der "ASSERT failed", nada daquele passo foi gravado: me mande a mensagem.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Como está cada pedido hoje.
-- Esperado: 25 linhas, todas com "pendentes" > 0 e sem lançamento novo.
-- ---------------------------------------------------------------------
SELECT c.pedido_num,
       min(c.fornecedor_nome) AS fornecedor,
       count(*) FILTER (WHERE c.status_receb = 'pendente') AS pendentes,
       count(*) FILTER (WHERE c.status_receb = 'recebido') AS recebidos,
       (SELECT count(*) FROM cmp_recebimentos r WHERE r.pedido_num = c.pedido_num) AS recebimentos,
       (SELECT count(*) FROM cmp_contas_pagar k WHERE k.pedido_num = c.pedido_num) AS contas
FROM cmp_compras c
WHERE c.pedido_num IN ('#01329','#01805','#01736','#01836','#01332','#01385','#01449','#01489','#02001','#02016','#02015','#02010','#01892','#01882','#01978','#01981','#01998','#02069','#01989','#01576','#01866','#02021','#01938','#01214','#01787')
GROUP BY c.pedido_num ORDER BY c.pedido_num;


-- ---------------------------------------------------------------------
-- PASSO 2 - DISPENSA O QUE NÃO VEM (13 linhas de 9 pedidos).
--   Fechar pedido (o resto é diferença de peso ou não foi entregue):
--     #01805 36 águas com gás (não entregue), #01836 farinha ovinha 5 kg
--     (os 17 kg recebidos já cobrem), #01332, #01385, #01449, #01489
--     (sobra de peso: o recebido e o pago já são o que veio).
--   Ninguém recebeu e NÃO chegou: #01576, #01866, #02021 (inteiros).
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_movs0 int; v_saldo0 numeric; v_lanc0 int; v_n int; v_receb uuid; v_tot numeric;
BEGIN
  CREATE TEMP TABLE _disp (pedido text, compra_id uuid PRIMARY KEY) ON COMMIT DROP;
  INSERT INTO _disp VALUES
    ('#01805', '4d04d1f9-e012-4874-9f46-fbbca7765c27'),  -- #01805 MP AGUA COM GÁS 36
    ('#01836', '53c3ae9f-2172-47b7-b02f-cb16e811c56f'),  -- #01836 MC FARINHA OVINHA FUNCIONARIO 5
    ('#01332', '733bba3a-9951-4cb6-8054-2dfda5163c35'),  -- #01332 MP PAO FRANCES PRODUÇÃO 0.584
    ('#01332', '7c6a0386-083c-4a56-91a7-1b78c9d4ef68'),  -- #01332 MP CEBOLA EM PO 0.344
    ('#01385', '2878423d-ac96-4b7d-bc6a-0dedcf4a2a4e'),  -- #01385 MC COXAO MOLE 0.358
    ('#01449', '7858c805-86ae-4d3a-a50b-3310d6f80995'),  -- #01449 MP FILÉ MIGNON INTEIRO 0.72
    ('#01489', '059a53ed-614c-4557-87dd-dc83bebf8b7b'),  -- #01489 MC PICADINHO CARNE - FUNCIONÁRIO 0.195
    ('#01576', 'a086f42e-0bd6-4ed0-aa3c-5c5e70442861'),  -- #01576 MP PUDIM DE LEITE 24
    ('#01866', 'b7e4768a-2ffe-4acb-aed9-da4df95b9114'),  -- #01866 MP PUDIM DE LEITE 12
    ('#01866', '57e6d884-8206-4661-bf02-82f1d057eccd'),  -- #01866 MP PETIT GATEAU C CALDA 21
    ('#02021', 'b72a4d95-2741-4742-be3d-eedc2b2e8e2d'),  -- #02021 MP SORVETE DE CREME 2
    ('#02021', '136c9134-522a-430c-8a3b-38eca054112f'),  -- #02021 MP PICOLE DE GRAVIOLA 2
    ('#02021', 'c834a096-e148-44d5-b604-b3366b4cbd52');  -- #02021 MP PICOLE DE ACAI 2
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo),0) INTO v_saldo0 FROM est_saldo_local;
  SELECT count(*) INTO v_lanc0 FROM lancamentos;
  SELECT count(*) INTO v_n FROM cmp_compras c JOIN _disp d ON d.compra_id = c.id
   WHERE c.pedido_num = d.pedido AND c.status_receb = 'pendente';
  ASSERT v_n = 13, format('esperava 13 itens pendentes desses pedidos, achei %s', v_n);
  UPDATE cmp_compras c SET status_receb = 'dispensado' FROM _disp d WHERE c.id = d.compra_id AND c.status_receb = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 13, format('dispensou %s, esperava 13', v_n);
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque (movimentos) - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo),0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
  ASSERT (SELECT count(*) FROM lancamentos) = v_lanc0, 'algo mexeu no financeiro - nada foi gravado';
END $$;

COMMIT;

-- ---------------------------------------------------------------------
-- PASSO 3 - FECHA RECEBENDO O RESTO: #01329 e #01736 (comprador externo).
-- O financeiro já pagou o pedido inteiro (R$ 227 e R$ 252), mas o
-- recebimento só tinha parte. Grava o resto como recebido e amarra a
-- conta ao lançamento pago (assim o botão "Enviar Financeiro" não aparece
-- e não nasce despesa em dobro).
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_movs0 int; v_saldo0 numeric; v_lanc0 int; v_n int; v_receb uuid; v_tot numeric;
BEGIN
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo),0) INTO v_saldo0 FROM est_saldo_local;
  SELECT count(*) INTO v_lanc0 FROM lancamentos;

  -- #01329: MP MEL DE ABELHA 1, MP BANANA CHIPS 7 (R$ 187.00) - pago no financeiro, falta só no recebimento
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01329' AND status_receb = 'pendente' AND id IN ('f64ed4f5-3251-4c28-a7d3-482c79d7a4f2','e2b8e1a9-89de-4702-be57-d427cb3a2036')) = 2, '#01329: itens não estão pendentes';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01329' AND status_receb = 'pendente') = 2, '#01329: tem outro item pendente';
  ASSERT (SELECT status FROM lancamentos WHERE id = '0e15a49d-0dc2-4777-a559-322ca0e67ca5') = 'pago' AND (SELECT valor FROM lancamentos WHERE id = '0e15a49d-0dc2-4777-a559-322ca0e67ca5') = 227.00, '#01329: lançamento pago de 227.00 não confere';
  ASSERT (SELECT lancamento_id FROM cmp_contas_pagar WHERE id = 'df2df8ec-6b79-4153-b6cc-37965dc98aad') IS NULL, '#01329: conta já tem lançamento';
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT 'f757aca8-3601-4784-9ba9-0d35f3e5d1e1', c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade, c.custo_unit,
         round((c.quantidade * c.custo_unit)::numeric, 2), false, 'Ajuste SQL 10/11: recebido, sem entrar no estoque', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.id IN ('f64ed4f5-3251-4c28-a7d3-482c79d7a4f2','e2b8e1a9-89de-4702-be57-d427cb3a2036');
  UPDATE cmp_compras SET status_receb = 'recebido' WHERE id IN ('f64ed4f5-3251-4c28-a7d3-482c79d7a4f2','e2b8e1a9-89de-4702-be57-d427cb3a2036');
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = 'f757aca8-3601-4784-9ba9-0d35f3e5d1e1';
  ASSERT v_tot = 227.00, format('#01329: recebimento deu %s, esperava 227.00', v_tot);
  UPDATE cmp_recebimentos SET total_recebido = v_tot WHERE id = 'f757aca8-3601-4784-9ba9-0d35f3e5d1e1';
  UPDATE cmp_contas_pagar SET valor = 227.00, lancamento_id = '0e15a49d-0dc2-4777-a559-322ca0e67ca5' WHERE id = 'df2df8ec-6b79-4153-b6cc-37965dc98aad';

  -- #01736: MP BANANA CHIPS 6, MP SEMENTE DE CUMARU 1 (R$ 135.00) - pago no financeiro, falta só no recebimento
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01736' AND status_receb = 'pendente' AND id IN ('1ec35545-64a0-4e92-8a6f-3b998935bdc9','015df9ae-04af-4c6e-85fa-70022f46b76a')) = 2, '#01736: itens não estão pendentes';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01736' AND status_receb = 'pendente') = 2, '#01736: tem outro item pendente';
  ASSERT (SELECT status FROM lancamentos WHERE id = '0e86cd2c-6f5f-46a3-a8fc-f0edbdcfc131') = 'pago' AND (SELECT valor FROM lancamentos WHERE id = '0e86cd2c-6f5f-46a3-a8fc-f0edbdcfc131') = 252.00, '#01736: lançamento pago de 252.00 não confere';
  ASSERT (SELECT lancamento_id FROM cmp_contas_pagar WHERE id = '81bf25db-931f-4366-aeae-11f608c1847f') IS NULL, '#01736: conta já tem lançamento';
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT '8868a5fc-ce64-4a39-8d3c-7f1de9240d71', c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade, c.custo_unit,
         round((c.quantidade * c.custo_unit)::numeric, 2), false, 'Ajuste SQL 10/11: recebido, sem entrar no estoque', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.id IN ('1ec35545-64a0-4e92-8a6f-3b998935bdc9','015df9ae-04af-4c6e-85fa-70022f46b76a');
  UPDATE cmp_compras SET status_receb = 'recebido' WHERE id IN ('1ec35545-64a0-4e92-8a6f-3b998935bdc9','015df9ae-04af-4c6e-85fa-70022f46b76a');
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = '8868a5fc-ce64-4a39-8d3c-7f1de9240d71';
  ASSERT v_tot = 252.00, format('#01736: recebimento deu %s, esperava 252.00', v_tot);
  UPDATE cmp_recebimentos SET total_recebido = v_tot WHERE id = '8868a5fc-ce64-4a39-8d3c-7f1de9240d71';
  UPDATE cmp_contas_pagar SET valor = 252.00, lancamento_id = '0e86cd2c-6f5f-46a3-a8fc-f0edbdcfc131' WHERE id = '81bf25db-931f-4366-aeae-11f608c1847f';
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque (movimentos) - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo),0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
  ASSERT (SELECT count(*) FROM lancamentos) = v_lanc0, 'algo mexeu no financeiro - nada foi gravado';
END $$;

COMMIT;

-- ---------------------------------------------------------------------
-- PASSO 4 - OS 10 "RECEBIDO E DESFEITO" (a equipe respondeu "Confere").
-- Grava de volta o recebimento com o que entrou antes do Devolver
-- (tirado do estorno, item por item, na unidade de compra), amarra a
-- conta que já existe e dispensa o que não veio.
-- A conta e o lançamento ficam como estão (valor e pagamento).
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_movs0 int; v_saldo0 numeric; v_lanc0 int; v_n int; v_receb uuid; v_tot numeric;
BEGIN
  CREATE TEMP TABLE _r (pedido text, compra_id uuid PRIMARY KEY, qtd numeric) ON COMMIT DROP;
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo),0) INTO v_saldo0 FROM est_saldo_local;
  SELECT count(*) INTO v_lanc0 FROM lancamentos;

  -- #02001 AMBEV: 1 de 1 itens, R$ 4655.59 (conta R$ 1995.59); recebido em 03/11
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#02001'), '#02001: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#02001' AND status_receb = 'pendente') = 1, '#02001: não está com os 1 itens pendentes';
  INSERT INTO _r VALUES
    ('#02001', 'a454a254-c2ed-41d9-b4a5-2a54febe671c', 350);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02001', DATE '2026-11-03', 'Ajuste SQL 10/11 (recebido em 03/11, desfeito pelo Devolver; conferido pela equipe)',
          'AMBEV', 'Naldo Souza', 4655.59, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#02001';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#02001: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 4655.00, format('#02001: itens somam %s, esperava 4655.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-11-03' WHERE id = '9a1e997e-0cfd-46c4-b66c-cedc7d78e9e7' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#02001: conta não foi amarrada';

  -- #02016 AMBEV: 1 de 1 itens, R$ 2660.79 (conta R$ 2662.34); recebido em 03/11
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#02016'), '#02016: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#02016' AND status_receb = 'pendente') = 1, '#02016: não está com os 1 itens pendentes';
  INSERT INTO _r VALUES
    ('#02016', '3bbd0ecb-0d13-4cbf-b07c-5e3bb46df804', 200);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02016', DATE '2026-11-03', 'Ajuste SQL 10/11 (recebido em 03/11, desfeito pelo Devolver; conferido pela equipe)',
          'AMBEV', 'Naldo Souza', 2660.79, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#02016';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#02016: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 1830.28, format('#02016: itens somam %s, esperava 1830.28', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-11-03' WHERE id = '2117a322-c082-437b-9cf9-463001ef7747' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#02016: conta não foi amarrada';

  -- #02015 LE CHEF EMPORIO / CLIFF DOS : 1 de 1 itens, R$ 336.00 (conta R$ 336.00); recebido em 03/11
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#02015'), '#02015: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#02015' AND status_receb = 'pendente') = 1, '#02015: não está com os 1 itens pendentes';
  INSERT INTO _r VALUES
    ('#02015', '8cfc6ce6-6e72-4a61-8459-1c609d0af541', 12);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02015', DATE '2026-11-03', 'Ajuste SQL 10/11 (recebido em 03/11, desfeito pelo Devolver; conferido pela equipe)',
          'LE CHEF EMPORIO / CLIFF DOS SANTOS', 'Carla Mota', 336.00, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#02015';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#02015: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 336.00, format('#02015: itens somam %s, esperava 336.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-11-03' WHERE id = '9f2d92fc-4d51-460d-bb6b-b3ccdd1710a9' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#02015: conta não foi amarrada';

  -- #02010 SIDNEY / HORTIFRUTI ESTRELA : 11 de 12 itens, R$ 1427.00 (conta R$ 1427.00); recebido em 30/10
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#02010'), '#02010: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#02010' AND status_receb = 'pendente') = 12, '#02010: não está com os 12 itens pendentes';
  INSERT INTO _r VALUES
    ('#02010', 'adbd73a7-66a8-4f62-acca-6a99ef703591', 2),
    ('#02010', '3ca4db34-15eb-43dc-9720-96289b425b8c', 14),
    ('#02010', 'cd3feb87-ad2e-409a-a54b-b80dec3c7666', 7),
    ('#02010', '0deb0097-e881-43ef-999d-37321665a6f5', 2),
    ('#02010', 'ae08fa45-bdce-4865-ae55-aa1d1d181e53', 30),
    ('#02010', 'c4bd5fff-19e8-4a4f-b557-25735e27fb2e', 0.5),
    ('#02010', 'd54c2943-30d1-4afa-b088-fddd49f5c032', 2),
    ('#02010', 'ee6e7b98-9656-490e-9b85-7f91e5166df7', 1),
    ('#02010', '05abfa4f-2ad2-4807-bcc3-67ef9f7f62a9', 50),
    ('#02010', '595d3884-1f99-497f-b7ac-1e2490bdce4c', 0.1),
    ('#02010', 'bf7dde39-77ff-4ab2-b8ff-434d08c90be0', 4);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02010', DATE '2026-10-30', 'Ajuste SQL 10/11 (recebido em 30/10, desfeito pelo Devolver; conferido pela equipe)',
          'SIDNEY / HORTIFRUTI ESTRELA DE DAVI', 'Carla Mota', 1427.00, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#02010';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 11, format('#02010: gravou %s itens, esperava 11', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 1427.00, format('#02010: itens somam %s, esperava 1427.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-30' WHERE id = 'f0db8851-7e66-4797-b9a8-068fec1b79ba' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#02010: conta não foi amarrada';

  -- #01892 TAINA ROBERTA COELHO: 23 de 23 itens, R$ 1422.68 (conta R$ 1370.63); recebido em 23/10
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01892'), '#01892: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01892' AND status_receb = 'pendente') = 23, '#01892: não está com os 23 itens pendentes';
  INSERT INTO _r VALUES
    ('#01892', '9930f82b-58f1-47eb-b2d4-020b5e94331f', 1),
    ('#01892', '78f986ea-1746-4eb4-8868-82caffb190ea', 4),
    ('#01892', '647b237f-78aa-4565-9360-f3eb7a81e8e7', 3),
    ('#01892', '01337e04-e84e-4838-bef9-265226bea36f', 3),
    ('#01892', '989e8888-dc16-424f-8c46-8c5251cea60f', 6),
    ('#01892', 'e15d25b6-5dd4-4723-99a2-710044e65e6a', 6),
    ('#01892', 'beb4eaad-3d51-4fd9-a8f2-450af1b38ed8', 2),
    ('#01892', '2bfb9221-5867-4de8-99fb-e4be1ca06be8', 1),
    ('#01892', 'f90c76cb-834a-44a3-b682-563194f5cc87', 3),
    ('#01892', '89e6431d-98e1-4877-92a0-001e01e9ac25', 4),
    ('#01892', 'b53a70f8-b238-4afc-bb79-f88fbf34bc68', 15),
    ('#01892', '97fcfed9-f42a-4cb2-8360-9b2720445238', 6),
    ('#01892', '0f60593e-a615-40a4-bc26-45de900f1598', 8),
    ('#01892', 'a444bc69-4f64-47fe-8bd7-dd2437f3038f', 5),
    ('#01892', '4e44c373-2d09-4d07-9066-b03d03e4fbe4', 3),
    ('#01892', 'd5cb63a0-5a8b-4ddb-92c8-90e719e241e6', 4),
    ('#01892', '0e5c739c-fbcc-4f51-8fea-d7201aa3bb97', 2),
    ('#01892', 'ff119b48-c4fd-4fa8-9cc9-213f2a8be1df', 4),
    ('#01892', 'b88e2c33-7449-4741-be46-f3bb0388c32f', 1),
    ('#01892', '94fe329e-eb11-4453-b2c8-a3588164901c', 1),
    ('#01892', '9ea024bc-c569-42de-a9d0-a461548740a3', 3),
    ('#01892', '37d8b711-c0da-4841-bfe4-faadc3bbd84a', 2),
    ('#01892', '171359b1-5779-4397-8616-55207440af76', 1);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01892', DATE '2026-10-23', 'Ajuste SQL 10/11 (recebido em 23/10, desfeito pelo Devolver; conferido pela equipe)',
          'TAINA ROBERTA COELHO', 'Carla Mota', 1422.68, 'confirmado', 'ESTOQUE DELIVERY')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#01892';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 23, format('#01892: gravou %s itens, esperava 23', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 1422.68, format('#01892: itens somam %s, esperava 1422.68', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-23' WHERE id = 'f6633126-dfe0-4f9f-ab66-dfd5e5002936' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#01892: conta não foi amarrada';

  -- #01882 TAINA ROBERTA COELHO: 27 de 35 itens, R$ 3481.23 (conta R$ 4549.91); recebido em 22/10
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01882'), '#01882: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01882' AND status_receb = 'pendente') = 35, '#01882: não está com os 35 itens pendentes';
  INSERT INTO _r VALUES
    ('#01882', '6582db07-49d5-40ac-aeba-83350674c4bb', 6),
    ('#01882', 'ac2910e3-9977-480e-a0e7-20d8166cb5d2', 8),
    ('#01882', '863023ba-525e-4db1-a46c-f99715aa59dc', 2),
    ('#01882', '8f8b0e74-9198-49df-85e4-8dfa1566f8dc', 9),
    ('#01882', '168f1361-0d33-4397-8d84-66e3784a8cca', 6),
    ('#01882', '42f7eb04-804d-4135-9b60-d8753550740e', 6),
    ('#01882', '9de4fd9d-f2d2-4d0c-8bd6-aeb52504450b', 15),
    ('#01882', '1ce10d5f-da5b-48fe-8cc2-c8897ab99cd5', 30),
    ('#01882', '5505bc61-e7c0-4817-93d5-2cb2a3ef2947', 12),
    ('#01882', 'a4fa042e-d064-491a-874e-795461472407', 4),
    ('#01882', '6ff28715-e550-4aa6-8c8a-c1d4bc610022', 7),
    ('#01882', 'a6f1e706-d355-4309-a156-02d0c6c7f588', 1),
    ('#01882', '7577e37e-180b-475b-86ac-1e4a6687cd46', 12),
    ('#01882', '77d56635-03c2-4f52-9216-71a578929e47', 1),
    ('#01882', '475c5bec-194f-4c77-ad74-6f173ab9300f', 10),
    ('#01882', '58df8a73-8cb2-4c53-b16c-9af58f72f6fd', 1),
    ('#01882', 'b5a5e0aa-093f-470e-9912-3a66d83742d5', 10),
    ('#01882', '22066dc0-1cdd-449a-bb4c-0c6f5676aa11', 6),
    ('#01882', 'b2666be1-6db3-4fdd-858e-ca8281ef2fdb', 25),
    ('#01882', '4bdbc404-e416-440d-9818-55401770abb9', 6),
    ('#01882', 'a355b67a-cbff-4cac-9cce-17e134c7d6c8', 39),
    ('#01882', '39691157-1ddf-47a5-aed7-ff1ca747c792', 7),
    ('#01882', '0b9a77e3-a94e-4af9-a711-4285e4eda1c0', 3),
    ('#01882', '9032c3c5-7dab-4c53-9ed0-04d61b35fb64', 12),
    ('#01882', '9abf3c1d-2520-4fa2-ade2-d5249c9cf878', 1),
    ('#01882', 'b75d9bb2-ba73-4f81-8842-9cbb261eebf4', 6),
    ('#01882', '1c9ace3f-4565-4daa-a197-8b83931629ce', 3);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01882', DATE '2026-10-22', 'Ajuste SQL 10/11 (recebido em 22/10, desfeito pelo Devolver; conferido pela equipe)',
          'TAINA ROBERTA COELHO', 'Naldo Souza', 3481.23, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#01882';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 27, format('#01882: gravou %s itens, esperava 27', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 3481.23, format('#01882: itens somam %s, esperava 3481.23', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-22' WHERE id = '76e739d9-25c5-40bb-8455-d84e0419bd72' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#01882: conta não foi amarrada';

  -- #01978 ALBERTA CARLA SANTOS: 2 de 5 itens, R$ 324.00 (conta R$ 428.00); recebido em 29/10
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01978'), '#01978: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01978' AND status_receb = 'pendente') = 5, '#01978: não está com os 5 itens pendentes';
  INSERT INTO _r VALUES
    ('#01978', '571ccc05-96e7-499a-aa6d-4d86fac9b6d9', 12),
    ('#01978', 'ac721226-6e34-4052-a1f3-1e0871a04f68', 24);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01978', DATE '2026-10-29', 'Ajuste SQL 10/11 (recebido em 29/10, desfeito pelo Devolver; conferido pela equipe)',
          'ALBERTA CARLA SANTOS', 'Carla Mota', 324.00, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#01978';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 2, format('#01978: gravou %s itens, esperava 2', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 324.00, format('#01978: itens somam %s, esperava 324.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-29' WHERE id = 'b5a22625-de55-4b29-91c6-68bfaaa02f5c' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#01978: conta não foi amarrada';

  -- #01981 TOYA: 2 de 4 itens, R$ 407.01 (conta R$ 407.01); recebido em 31/10
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01981'), '#01981: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01981' AND status_receb = 'pendente') = 4, '#01981: não está com os 4 itens pendentes';
  INSERT INTO _r VALUES
    ('#01981', '82730c4d-5950-401e-828f-77a85b33ada7', 2),
    ('#01981', '40478f31-118a-4378-b700-3ccdf57bc895', 2);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01981', DATE '2026-10-31', 'Ajuste SQL 10/11 (recebido em 31/10, desfeito pelo Devolver; conferido pela equipe)',
          'TOYA', 'Carla Mota', 407.01, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#01981';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 2, format('#01981: gravou %s itens, esperava 2', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 388.00, format('#01981: itens somam %s, esperava 388.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-31' WHERE id = 'acbac37f-06da-4504-bbc2-1410fae69326' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#01981: conta não foi amarrada';

  -- #01998 AMBEV: 1 de 1 itens, R$ 3327.56 (conta R$ 3327.56); recebido em 30/10
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01998'), '#01998: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01998' AND status_receb = 'pendente') = 1, '#01998: não está com os 1 itens pendentes';
  INSERT INTO _r VALUES
    ('#01998', 'd1bce100-c6db-431a-9a1f-5e9153682421', 250);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01998', DATE '2026-10-30', 'Ajuste SQL 10/11 (recebido em 30/10, desfeito pelo Devolver; conferido pela equipe)',
          'AMBEV', 'Naldo Souza', 3327.56, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#01998';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#01998: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 3325.00, format('#01998: itens somam %s, esperava 3325.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-30' WHERE id = '41402730-dcb6-4206-8fe0-aa9298f8af39' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#01998: conta não foi amarrada';

  -- #02069 AMBEV: 1 de 1 itens, R$ 5323.15 (conta R$ 5323.15); recebido em 04/11
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#02069'), '#02069: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#02069' AND status_receb = 'pendente') = 1, '#02069: não está com os 1 itens pendentes';
  INSERT INTO _r VALUES
    ('#02069', 'b9ab2719-4247-47dd-9424-2e59218d5eb4', 400);
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02069', DATE '2026-11-04', 'Ajuste SQL 10/11 (recebido em 04/11, desfeito pelo Devolver; conferido pela equipe)',
          'AMBEV', 'Naldo Souza', 5323.15, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd, c.custo_unit,
         round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '', c.produto_id, false, NULL
    FROM _r r JOIN cmp_compras c ON c.id = r.compra_id AND c.pedido_num = r.pedido WHERE r.pedido = '#02069';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#02069: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 5320.00, format('#02069: itens somam %s, esperava 5320.00', v_tot);
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-11-04' WHERE id = '3bdbceab-be6e-4c32-965d-0bcdc505cb29' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#02069: conta não foi amarrada';

  -- Itens: chegou inteiro (ou a mais) = recebido com a quantidade que chegou; parte = fica o que faltou, dispensado;
  -- o que não chegou = dispensado (a equipe confirmou que só entrou isso)
  UPDATE cmp_compras c SET status_receb = 'dispensado', quantidade = c.quantidade - r.qtd
    FROM _r r WHERE c.id = r.compra_id AND r.qtd < c.quantidade;
  UPDATE cmp_compras c SET status_receb = 'recebido', quantidade = r.qtd
    FROM _r r WHERE c.id = r.compra_id AND r.qtd >= c.quantidade;
  UPDATE cmp_compras SET status_receb = 'dispensado'
   WHERE pedido_num IN ('#02001','#02016','#02015','#02010','#01892','#01882','#01978','#01981','#01998','#02069')
     AND status_receb = 'pendente' AND id NOT IN (SELECT compra_id FROM _r);
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_compras WHERE pedido_num IN ('#02001','#02016','#02015','#02010','#01892','#01882','#01978','#01981','#01998','#02069') AND status_receb = 'pendente'), 'sobrou item pendente';

  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque (movimentos) - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo),0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
  ASSERT (SELECT count(*) FROM lancamentos) = v_lanc0, 'algo mexeu no financeiro - nada foi gravado';
END $$;

COMMIT;

-- ---------------------------------------------------------------------
-- PASSO 5 - OS QUE NINGUÉM RECEBEU E CHEGARAM: #01989, #01214, #01938, #01787.
--   #01989 Taina: já pago como adiantamento (R$ 4.405,76): só amarra a conta.
--   #01214 feijão de praia: pago em dinheiro (R$ 55): conta já amarrada ao pagamento.
--   #01938 Bonna Vitta (R$ 339,96) e #01787 Alberta (R$ 66): ninguém pagou ainda;
--   a conta nasce pendente, vencimento 17/11 (ajuste ao enviar).
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_movs0 int; v_saldo0 numeric; v_lanc0 int; v_n int; v_receb uuid; v_tot numeric;
BEGIN
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo),0) INTO v_saldo0 FROM est_saldo_local;
  SELECT count(*) INTO v_lanc0 FROM lancamentos;

  -- #01989 TAINA ROBERTA COELHO (Tambaqui de Banda Teatro): 35 itens, R$ 4441.64
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01989'), '#01989: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01989' AND status_receb = 'pendente') = 35, '#01989: não está com os 35 itens pendentes';
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01989', DATE '2026-10-28', 'Ajuste SQL 10/11 (chegou, confirmado pela equipe; sem entrar no estoque)',
          'TAINA ROBERTA COELHO', 'Carla Mota', 4441.64, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade, c.custo_unit,
         round((c.quantidade * c.custo_unit)::numeric, 2), false, '', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.pedido_num = '#01989' AND c.status_receb = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 35, format('#01989: gravou %s itens, esperava 35', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 4441.64, format('#01989: itens somam %s, esperava 4441.64', v_tot);
  UPDATE cmp_compras SET status_receb = 'recebido' WHERE pedido_num = '#01989' AND status_receb = 'pendente';
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-10-28' WHERE id = 'ae4a9d26-f308-4c9c-8273-df372bf983a0' AND recebimento_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '#01989: conta não foi amarrada';

  -- #01214 COMPRADOR EXTERNO (Delivery P10): 1 itens, R$ 54.90
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01214'), '#01214: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01214' AND status_receb = 'pendente') = 1, '#01214: não está com os 1 itens pendentes';
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01214', DATE '2026-09-04', 'Ajuste SQL 10/11 (chegou, confirmado pela equipe; sem entrar no estoque)',
          'COMPRADOR EXTERNO', 'Carla Mota', 54.90, 'confirmado', 'ESTOQUE DELIVERY')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade, c.custo_unit,
         round((c.quantidade * c.custo_unit)::numeric, 2), false, '', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.pedido_num = '#01214' AND c.status_receb = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#01214: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 54.90, format('#01214: itens somam %s, esperava 54.90', v_tot);
  UPDATE cmp_compras SET status_receb = 'recebido' WHERE pedido_num = '#01214' AND status_receb = 'pendente';
  -- pago em dinheiro (lançamento com o nº da nota 000454918, não o do pedido): a conta nasce já amarrada a ele
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = '#01214'), '#01214: já tem conta';
  ASSERT (SELECT status FROM lancamentos WHERE id = '57849c8b-782f-4e65-904e-66ab1a2a70e4') = 'pago' AND (SELECT valor FROM lancamentos WHERE id = '57849c8b-782f-4e65-904e-66ab1a2a70e4') = 55.00, '#01214: lançamento pago não confere';
  INSERT INTO cmp_contas_pagar (pedido_num, recebimento_id, fornecedor, data_receb, vencimento, valor, status, lancamento_id, parcelas, parcela_intervalo)
  VALUES ('#01214', v_receb, 'COMPRADOR EXTERNO', DATE '2026-09-04', DATE '2026-09-11', 55.00, 'pendente', '57849c8b-782f-4e65-904e-66ab1a2a70e4', 1, 'mensal');

  -- #01938 BONNA VITTA (Tambaqui de Banda Teatro): 1 itens, R$ 339.96
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01938'), '#01938: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01938' AND status_receb = 'pendente') = 1, '#01938: não está com os 1 itens pendentes';
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01938', DATE '2026-10-26', 'Ajuste SQL 10/11 (chegou, confirmado pela equipe; sem entrar no estoque)',
          'BONNA VITTA', 'Naldo Souza', 339.96, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade, c.custo_unit,
         round((c.quantidade * c.custo_unit)::numeric, 2), false, '', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.pedido_num = '#01938' AND c.status_receb = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#01938: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 339.96, format('#01938: itens somam %s, esperava 339.96', v_tot);
  UPDATE cmp_compras SET status_receb = 'recebido' WHERE pedido_num = '#01938' AND status_receb = 'pendente';
  -- ninguém pagou ainda: a conta nasce pendente, sem lançamento (vai ao financeiro pelo botão, PASSO 7)
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = '#01938'), '#01938: já tem conta';
  ASSERT NOT EXISTS (SELECT 1 FROM lancamentos WHERE numero_pedido = '#01938' OR descricao ILIKE '%#01938%'), '#01938: já tem lançamento no financeiro';
  INSERT INTO cmp_contas_pagar (pedido_num, recebimento_id, fornecedor, data_receb, vencimento, valor, status, parcelas, parcela_intervalo)
  VALUES ('#01938', v_receb, 'BONNA VITTA', DATE '2026-10-26', DATE '2026-11-17', 339.96, 'pendente', 1, 'mensal');

  -- #01787 ALBERTA CARLA SANTOS (Delivery P10): 1 itens, R$ 66.00
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01787'), '#01787: já tem recebimento';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01787' AND status_receb = 'pendente') = 1, '#01787: não está com os 1 itens pendentes';
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#01787', DATE '2026-10-16', 'Ajuste SQL 10/11 (chegou, confirmado pela equipe; sem entrar no estoque)',
          'ALBERTA CARLA SANTOS', 'Carla Mota', 66.00, 'confirmado', 'ESTOQUE DELIVERY')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade, c.custo_unit,
         round((c.quantidade * c.custo_unit)::numeric, 2), false, '', c.produto_id, false, NULL
    FROM cmp_compras c WHERE c.pedido_num = '#01787' AND c.status_receb = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#01787: gravou %s itens, esperava 1', v_n);
  SELECT sum(total_recebido) INTO v_tot FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_tot = 66.00, format('#01787: itens somam %s, esperava 66.00', v_tot);
  UPDATE cmp_compras SET status_receb = 'recebido' WHERE pedido_num = '#01787' AND status_receb = 'pendente';
  -- ninguém pagou ainda: a conta nasce pendente, sem lançamento (vai ao financeiro pelo botão, PASSO 7)
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = '#01787'), '#01787: já tem conta';
  ASSERT NOT EXISTS (SELECT 1 FROM lancamentos WHERE numero_pedido = '#01787' OR descricao ILIKE '%#01787%'), '#01787: já tem lançamento no financeiro';
  INSERT INTO cmp_contas_pagar (pedido_num, recebimento_id, fornecedor, data_receb, vencimento, valor, status, parcelas, parcela_intervalo)
  VALUES ('#01787', v_receb, 'ALBERTA CARLA SANTOS', DATE '2026-10-16', DATE '2026-11-17', 66.00, 'pendente', 1, 'mensal');
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque (movimentos) - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo),0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
  ASSERT (SELECT count(*) FROM lancamentos) = v_lanc0, 'algo mexeu no financeiro - nada foi gravado';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 6 - CONFERÊNCIA. Rodar o PASSO 1 de novo.
-- Esperado: pendentes = 0 nos 25; recebimentos = 1 em todos, menos nos
-- 3 que não chegaram (#01576, #01866, #02021: 0 recebimentos, 0 contas).
-- E nenhum movimento de estoque com hora de agora:
-- ---------------------------------------------------------------------
SELECT count(*) AS movimentos_ultimos_15_min FROM est_movimentacoes
WHERE criado_em > now() - interval '15 minutes' AND tipo = 'recebimento';


-- ---------------------------------------------------------------------
-- PASSO 7 - NA TELA (não é SQL): mandar ao financeiro as 2 contas novas,
-- #01938 Bonna Vitta R$ 339,96 e #01787 Alberta R$ 66,00, pelo botão
-- "Enviar Financeiro" na aba Compras, com o vencimento certo do boleto/Pix.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- PASSO 8 - DISPENSA O #01323 (Pescado, 100 tambaquis do P10, R$ 5.500).
-- Decisão do Wagner em 10/11: o Pescado faturou #01000, #01260 e #01463
-- (100 tambaquis cada) e nunca este; o #01463, feito 10 dias depois para o
-- P10, foi recebido. Era o mesmo pedido refeito. Sem conta, sem lançamento.
-- Pode rodar a qualquer momento, antes ou depois dos outros passos.
-- Esperado: DO e COMMIT.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE v_n int; v_movs0 int;
BEGIN
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01323') = 1, '#01323: esperava 1 item';
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#01323'), '#01323: já tem recebimento';
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = '#01323'), '#01323: já tem conta';
  ASSERT NOT EXISTS (SELECT 1 FROM lancamentos WHERE numero_pedido = '#01323' OR descricao ILIKE '%#01323%'), '#01323: já tem lançamento';
  UPDATE cmp_compras SET status_receb = 'dispensado'
   WHERE id = '2d6d39db-b497-42c9-998d-64b4765c489d' AND pedido_num = '#01323' AND status_receb = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, format('#01323: dispensou %s, esperava 1', v_n);
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque - nada foi gravado';
END $$;

COMMIT;

-- Conferência: deve vir 'dispensado'.
SELECT pedido_num, produto, quantidade, status_receb FROM cmp_compras WHERE pedido_num = '#01323';
