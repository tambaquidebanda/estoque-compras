-- =====================================================================
-- SQL_ALBERTA_ENTREGA_0410.sql  (16/11/2026)
--
-- ALBERTA CARLA SANTOS entregou em 04/10 (Teatro):
--    8 MP CEU DE BRIGADEIRO               x R$ 13,00 = R$ 104,00
--   12 MP CHEESECAKE CHOCOLATE COM CUPUACU x R$ 13,00 = R$ 156,00
--                                                     = R$ 260,00
-- Essa entrega nunca foi recebida no sistema: nenhum recebimento, conta
-- ou lançamento (nem excluído). Os doces foram direto para o Bar (a
-- contagem do Bar da noite de 04/10 subiu +8 céu e +10 cheesecake sem
-- pedido interno). O pedido que previa esses itens (#01574) já foi pago
-- em 15/10 pelo que tinha sido recebido, então não dá para somar nele.
--
-- Este SQL faz tudo o que a tela faria, com o número de pedido seguinte:
--   * pedido novo (2 itens, Teatro, entrega 04/10) já como recebido;
--   * recebimento de 04/10, R$ 260,00;
--   * conta a pagar R$ 260,00, vencimento 15/11 (padrão da Alberta para
--     entrega de outubro, igual ao #01660 recebido em 07/10);
--   * rascunho em Integrações Pendentes para o financeiro APROVAR.
--
-- NADA aqui mexe no estoque: os doces já foram vendidos.
--
-- Rode UM PASSO DE CADA VEZ. Se der "ASSERT failed", nada foi gravado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Confere que essa entrega não existe em lugar
-- nenhum e mostra o número que o pedido vai receber.
-- Esperado: 0, 0, 0 e o próximo número.
-- ---------------------------------------------------------------------
SELECT 'pedidos da Alberta com entrega 04/10' AS o_que,
       (SELECT count(*) FROM cmp_compras WHERE fornecedor_id = 'e1541df9-d7bb-4666-966e-0f22ea8d3ca5' AND data_entrega = '2026-10-04')::text AS valor
UNION ALL
SELECT 'recebimentos da Alberta em 04/10',
       (SELECT count(*) FROM cmp_recebimentos WHERE fornecedor ILIKE '%ALBERTA%' AND data_receb = '2026-10-04')::text
UNION ALL
SELECT 'contas/lançamentos da Alberta de R$ 260,00',
       ((SELECT count(*) FROM cmp_contas_pagar WHERE fornecedor ILIKE '%ALBERTA%' AND valor = 260)
      + (SELECT count(*) FROM lancamentos WHERE fornecedor_id = 'e1541df9-d7bb-4666-966e-0f22ea8d3ca5' AND valor = 260))::text
UNION ALL
SELECT 'próximo número de pedido',
       '#' || lpad(((SELECT max(nullif(regexp_replace(split_part(pedido_num, '/', 1), '\D', '', 'g'), '')::int)
                       FROM cmp_compras WHERE pedido_num IS NOT NULL) + 1)::text, 5, '0');


-- ---------------------------------------------------------------------
-- PASSO 2 - GRAVA PEDIDO + RECEBIMENTO + CONTA + RASCUNHO DO FINANCEIRO.
-- No fim mostra (NOTICE) o número do pedido criado.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  c_forn   constant uuid := 'e1541df9-d7bb-4666-966e-0f22ea8d3ca5';   -- ALBERTA CARLA SANTOS
  c_ceu    constant uuid := 'f24ea38c-94d3-4ffb-b652-7a7e9d55d83e';   -- MP CEU DE BRIGADEIRO
  c_che    constant uuid := '590a30af-8cd6-4d49-9e87-f47a2982a956';   -- MP CHEESECAKE CHOCOLATE COM CUPUACU
  c_plano  constant uuid := '70597f67-caed-40c5-9f9d-ce4180cbf024';   -- plano Sobremesas (mesmo dos outros pedidos da Alberta)
  c_uni    constant uuid := 'e031eced-0652-4af0-ad2a-13b65a29f814';   -- unidade Tambaqui de Banda Teatro no financeiro
  v_ped text; v_ceu uuid; v_che uuid; v_receb uuid; v_conta uuid;
  v_movs0 int; v_saldo0 numeric; v_lanc0 int;
BEGIN
  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;
  SELECT coalesce(sum(saldo),0) INTO v_saldo0 FROM est_saldo_local;
  SELECT count(*) INTO v_lanc0 FROM lancamentos;

  -- Não roda duas vezes
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_compras WHERE fornecedor_id = c_forn AND data_entrega = '2026-10-04'),
         'já existe pedido da Alberta com entrega 04/10';
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE fornecedor ILIKE '%ALBERTA%' AND data_receb = '2026-10-04'),
         'já existe recebimento da Alberta em 04/10';
  ASSERT (SELECT count(*) FROM est_produtos WHERE id IN (c_ceu, c_che)) = 2, 'produtos não encontrados';

  -- Número: o seguinte ao maior pedido (o mesmo cálculo da tela)
  SELECT '#' || lpad((max(nullif(regexp_replace(split_part(pedido_num, '/', 1), '\D', '', 'g'), '')::int) + 1)::text, 5, '0')
    INTO v_ped FROM cmp_compras WHERE pedido_num IS NOT NULL;
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_compras WHERE pedido_num = v_ped), 'número de pedido já usado';

  -- 1) Pedido (já recebido)
  INSERT INTO cmp_compras (data, fornecedor_id, fornecedor_nome, produto, categoria, plano_conta, tipo_produto, unidade_med,
                           custo_unit, quantidade, comprador, unidade_uso, pedido_num, data_entrega, status_receb, acrescimo,
                           setor, forma_pagamento, produto_id, bonificado, parcelas)
  VALUES ('2026-11-16', c_forn, 'ALBERTA CARLA SANTOS', 'MP CEU DE BRIGADEIRO', 'Sobremesas', 'Sobremesas',
          'Tambaqui de Banda Teatro', 'UN', 13.00, 8, 'Ajuste SQL 16/11', 'Tambaqui de Banda Teatro', v_ped, '2026-10-04',
          'recebido', 0, 'Estoque Loja', 'Pix', c_ceu, false, 1)
  RETURNING id INTO v_ceu;
  INSERT INTO cmp_compras (data, fornecedor_id, fornecedor_nome, produto, categoria, plano_conta, tipo_produto, unidade_med,
                           custo_unit, quantidade, comprador, unidade_uso, pedido_num, data_entrega, status_receb, acrescimo,
                           setor, forma_pagamento, produto_id, bonificado, parcelas)
  VALUES ('2026-11-16', c_forn, 'ALBERTA CARLA SANTOS', 'MP CHEESECAKE CHOCOLATE COM CUPUACU', 'Sobremesas', 'Sobremesas',
          'Tambaqui de Banda Teatro', 'UN', 13.00, 12, 'Ajuste SQL 16/11', 'Tambaqui de Banda Teatro', v_ped, '2026-10-04',
          'recebido', 0, 'Estoque Loja', 'Pix', c_che, false, 1)
  RETURNING id INTO v_che;
  -- total: só grava se a coluna não for calculada pelo banco
  IF (SELECT is_generated FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'cmp_compras' AND column_name = 'total') = 'NEVER' THEN
    EXECUTE 'UPDATE cmp_compras SET total = quantidade * custo_unit WHERE pedido_num = $1' USING v_ped;
  END IF;

  -- 2) Recebimento de 04/10
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES (v_ped, '2026-10-04', 'Ajuste SQL 16/11 (entrega de 04/10 que foi direto ao Bar; sem entrar no estoque)',
          'ALBERTA CARLA SANTOS', 'Ajuste SQL 16/11', 260.00, 'confirmado', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
                                     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado)
  VALUES (v_receb, v_ceu, 'MP CEU DE BRIGADEIRO',               'Sobremesas', 'UN',  8,  8, 13.00, 104.00, false, '', c_ceu, false),
         (v_receb, v_che, 'MP CHEESECAKE CHOCOLATE COM CUPUACU', 'Sobremesas', 'UN', 12, 12, 13.00, 156.00, false, '', c_che, false);

  -- 3) Conta a pagar
  INSERT INTO cmp_contas_pagar (pedido_num, recebimento_id, fornecedor, data_receb, vencimento, valor, status, parcelas, parcela_intervalo)
  VALUES (v_ped, v_receb, 'ALBERTA CARLA SANTOS', '2026-10-04', '2026-11-15', 260.00, 'pendente', 1, 'mensal')
  RETURNING id INTO v_conta;

  -- 4) Rascunho em Integrações Pendentes (o financeiro aprova e vira lançamento)
  INSERT INTO lancamentos_rascunho (descricao, valor, vencimento, tipo, status, fornecedor_id, plano_conta_id, numero_pedido,
                                    observacoes, acrescimo, desconto, pedido_num, conta_id, tem_rateio, unidade_id)
  VALUES ('Pedido ' || v_ped || ' — ALBERTA CARLA SANTOS', 260.00, '2026-11-15', 'pagar', 'pendente', c_forn, c_plano, v_ped,
          'Pedido ' || v_ped || ' — entrega de 04/10 (lançada em 16/11)', 0, 0, v_ped, v_conta, false, c_uni);

  -- Conferências
  ASSERT (SELECT sum(total_recebido) FROM cmp_recebimento_itens WHERE recebimento_id = v_receb) = 260.00, 'itens não somam 260,00';
  ASSERT (SELECT count(*) FROM cmp_compras WHERE pedido_num = v_ped AND status_receb = 'recebido') = 2, 'pedido não ficou com 2 itens recebidos';
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque (movimentos) - nada foi gravado';
  ASSERT (SELECT coalesce(sum(saldo),0) FROM est_saldo_local) = v_saldo0, 'algo mexeu no saldo - nada foi gravado';
  ASSERT (SELECT count(*) FROM lancamentos) = v_lanc0, 'nasceu lançamento direto - nada foi gravado';

  RAISE NOTICE 'Pedido criado: %', v_ped;
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - SÓ LEITURA. Conferência.
-- Esperado: 2 itens recebidos, 1 recebimento 04/10 R$ 260, conta 260
-- pendente, rascunho 260 com vencimento 15/11.
-- ---------------------------------------------------------------------
WITH p AS (SELECT DISTINCT pedido_num FROM cmp_compras
            WHERE fornecedor_id = 'e1541df9-d7bb-4666-966e-0f22ea8d3ca5' AND data_entrega = '2026-10-04')
SELECT 'item ' || c.produto AS o_que, c.pedido_num, c.quantidade AS qtd, c.status_receb AS obs
  FROM cmp_compras c JOIN p USING (pedido_num)
UNION ALL
SELECT 'recebimento ' || r.data_receb, r.pedido_num, r.total_recebido, r.status FROM cmp_recebimentos r JOIN p USING (pedido_num)
UNION ALL
SELECT 'conta venc. ' || k.vencimento, k.pedido_num, k.valor, k.status FROM cmp_contas_pagar k JOIN p USING (pedido_num)
UNION ALL
SELECT 'rascunho venc. ' || x.vencimento, x.pedido_num, x.valor, x.status FROM lancamentos_rascunho x JOIN p USING (pedido_num);
