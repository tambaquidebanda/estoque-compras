-- =====================================================================
-- SQL_RECEBE_02068.sql  (09/11/2026)
--
-- Pedido #02068 - AMBEV, 16 itens, R$ 4.694,69 (com acrescimo 468,48).
-- Em 04/11 o celular recebeu 11 itens (R$ 2.066,69 + acrescimo 468,48 =
-- R$ 2.535,17, que e o valor da nota). Em 05/11 16:44 alguem apertou
-- "Devolver": o recebimento e a conta sumiram, as cervejas sairam do
-- saldo e o pedido voltou cheio. As 16:48 alguem gerou a conta de novo
-- (R$ 2.535,17, sem recebimento), e o financeiro rejeitou.
--
-- Este SQL grava de volta o recebimento de 04/11, como o celular gravou:
-- 11 itens, com Stella Pure Gold 600 (24 de 96) e Bare lata (12 de 76)
-- parciais. Os itens recebidos inteiros viram 'recebido'; os parciais
-- ficam pendentes com o que faltou (72 e 64), igual ao celular faz.
-- A conta de R$ 2.535,17 que ja existe e amarrada a esse recebimento.
--
-- NAO mexe no saldo de estoque (nao grava em est_movimentacoes nem em
-- est_saldo_local): a contagem do Estoque da Loja de hoje (Ricardo,
-- 09:04-09:41) e o "Saldo inicial" do Estoque Delivery ja colocaram
-- essas cervejas de volta. Receber pelo celular somaria tudo de novo.
-- NAO manda nada ao financeiro: isso e o PASSO 4, pelo botao.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA.
-- Esperado: 16 itens, todos 'pendente'; 0 recebimentos; 1 conta de
-- 2535.17 sem lancamento; 0 rascunhos; 0 lancamentos.
-- ---------------------------------------------------------------------
SELECT produto, quantidade, custo_unit, total, status_receb
FROM cmp_compras WHERE pedido_num = '#02068' ORDER BY produto;

SELECT 'recebimentos' AS o_que, count(*)::text AS valor FROM cmp_recebimentos WHERE pedido_num = '#02068'
UNION ALL SELECT 'contas a pagar', count(*)::text FROM cmp_contas_pagar WHERE pedido_num = '#02068'
UNION ALL SELECT 'valor da conta', max(valor)::text FROM cmp_contas_pagar WHERE pedido_num = '#02068'
UNION ALL SELECT 'conta com lancamento', count(*)::text FROM cmp_contas_pagar WHERE pedido_num = '#02068' AND lancamento_id IS NOT NULL
UNION ALL SELECT 'rascunhos', count(*)::text FROM lancamentos_rascunho WHERE pedido_num = '#02068'
UNION ALL SELECT 'lancamentos', count(*)::text FROM lancamentos WHERE numero_pedido = '#02068';


-- ---------------------------------------------------------------------
-- PASSO 2 - GRAVA O RECEBIMENTO (tudo junto ou nada).
-- Qualquer conferencia que falhe para tudo com "ASSERT failed" e nada
-- e gravado. Rodar de novo depois de gravado tambem para (ja existe
-- recebimento). Deve terminar com DO e COMMIT.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_receb  uuid;
  v_conta  uuid;
  v_itens  numeric;
  v_n      int;
  v_movs0  int;
BEGIN
  -- O que chegou em 04/11 (tirado do estorno do Devolver, item por item)
  CREATE TEMP TABLE _r02068 (compra_id uuid PRIMARY KEY, qtd numeric, local text) ON COMMIT DROP;
  INSERT INTO _r02068 VALUES
    ('92ba5bde-c37b-4b27-bf8e-36c609a6625a',   6, 'ESTOQUE DELIVERY'),  -- BARE DE 2 LITROS
    ('a82bb4b9-7923-4b99-b353-fb93d05372a3',  12, NULL),                -- BARE LATA (12 de 76)
    ('b02173a9-341e-445e-b3d0-c5eaacc4a74f',  12, NULL),                -- COLORADO RIBEIRAO LAGER
    ('07491c90-0418-4d0c-af50-73f3b1e86150',  48, NULL),                -- CORONA ZERO LN
    ('8bfa061a-2d20-4068-9171-cf896ef608a0',   6, 'ESTOQUE DELIVERY'),  -- GUARANA ANTARTICA ZERO 2 L
    ('4c41e1be-26fc-4022-ab59-127d633423e5',  24, NULL),                -- MICHELOB LN
    ('80290ccf-cdd2-445b-9e1a-0959855ebe1f', 168, NULL),                -- ORIGINAL 600ML
    ('5eac2d1f-e6aa-4d35-b5c6-97e1a9989839',  12, NULL),                -- PEPSI LATA
    ('c2dd7df9-edaa-4b62-9dd4-d5592708261e',  48, NULL),                -- STELLA ARTOIS PURE GOLD LN
    ('3cfbb10a-1d6f-46d1-8c66-b28125dc835a',  24, NULL),                -- STELLA PURE GOLD 600ML (24 de 96)
    ('22031931-b33d-424e-992e-3bf86419ba36',  24, NULL);                -- TONICA ANTARTICA 350ML

  -- Travas
  SELECT count(DISTINCT compra_id) INTO v_n FROM _r02068;
  ASSERT v_n = 11, 'esperava 11 itens distintos';
  SELECT count(*) INTO v_n FROM cmp_compras c JOIN _r02068 r ON r.compra_id = c.id
   WHERE c.pedido_num = '#02068' AND c.status_receb = 'pendente' AND c.quantidade >= r.qtd;
  ASSERT v_n = 11, 'algum item nao e do #02068, nao esta pendente ou tem menos que o recebido';
  SELECT count(*) INTO v_n FROM cmp_compras WHERE pedido_num = '#02068' AND status_receb = 'pendente';
  ASSERT v_n = 16, 'o pedido nao esta com os 16 itens pendentes';
  ASSERT NOT EXISTS (SELECT 1 FROM cmp_recebimentos WHERE pedido_num = '#02068'), 'ja existe recebimento do #02068';
  ASSERT NOT EXISTS (SELECT 1 FROM lancamentos_rascunho WHERE pedido_num = '#02068'), 'ja existe rascunho no financeiro';
  ASSERT NOT EXISTS (SELECT 1 FROM lancamentos WHERE numero_pedido = '#02068'), 'ja existe lancamento no financeiro';
  SELECT count(*), max(id::text)::uuid INTO v_n, v_conta FROM cmp_contas_pagar
   WHERE pedido_num = '#02068' AND lancamento_id IS NULL AND valor = 2535.17;
  ASSERT v_n = 1, 'esperava 1 conta de 2535.17 sem lancamento';
  ASSERT (SELECT count(*) FROM cmp_contas_pagar WHERE pedido_num = '#02068') = 1, 'mais de uma conta no #02068';

  SELECT sum(round((r.qtd * c.custo_unit)::numeric, 2)) INTO v_itens
    FROM _r02068 r JOIN cmp_compras c ON c.id = r.compra_id;
  ASSERT v_itens = 2066.69, format('soma dos itens deu %s, esperava 2066.69', v_itens);
  ASSERT (SELECT max(acrescimo) FROM cmp_compras WHERE pedido_num = '#02068') = 468.48, 'acrescimo nao e 468.48';

  SELECT count(*) INTO v_movs0 FROM est_movimentacoes;

  -- Cabecalho (status 'parcial', como o celular grava quando ha divergencia)
  INSERT INTO cmp_recebimentos
    (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  VALUES ('#02068', DATE '2026-11-04',
          'Ajuste SQL 09/11 (recebido em 04/11, desfeito pelo Devolver em 05/11)',
          'AMBEV', 'Naldo Souza', v_itens + 468.48, 'parcial', 'ESTOQUE_LOJA')
  RETURNING id INTO v_receb;

  -- Itens
  INSERT INTO cmp_recebimento_itens
    (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
  SELECT v_receb, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, r.qtd,
         c.custo_unit, round((r.qtd * c.custo_unit)::numeric, 2), (r.qtd <> c.quantidade), '',
         c.produto_id, false, r.local
  FROM _r02068 r JOIN cmp_compras c ON c.id = r.compra_id;

  -- Itens do pedido: inteiro vira 'recebido'; parcial fica pendente com o que faltou
  UPDATE cmp_compras c SET status_receb = 'recebido'
    FROM _r02068 r WHERE c.id = r.compra_id AND r.qtd = c.quantidade;
  UPDATE cmp_compras c SET quantidade = c.quantidade - r.qtd
    FROM _r02068 r WHERE c.id = r.compra_id AND r.qtd < c.quantidade;

  -- Conta que ja existe passa a apontar para o recebimento
  UPDATE cmp_contas_pagar SET recebimento_id = v_receb, data_receb = DATE '2026-11-04'
   WHERE id = v_conta;

  -- Conferencias finais
  SELECT count(*) INTO v_n FROM cmp_recebimento_itens WHERE recebimento_id = v_receb;
  ASSERT v_n = 11, 'nao gravou os 11 itens';
  ASSERT (SELECT total_recebido FROM cmp_recebimentos WHERE id = v_receb) = 2535.17, 'total do recebimento nao deu 2535.17';
  SELECT count(*) INTO v_n FROM cmp_compras WHERE pedido_num = '#02068' AND status_receb = 'recebido';
  ASSERT v_n = 9, format('esperava 9 itens recebidos, deu %s', v_n);
  SELECT count(*) INTO v_n FROM cmp_compras WHERE pedido_num = '#02068' AND status_receb = 'pendente';
  ASSERT v_n = 7, format('esperava 7 itens pendentes, deu %s', v_n);
  ASSERT (SELECT count(*) FROM est_movimentacoes) = v_movs0, 'algo mexeu no estoque - nada foi gravado';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA.
-- Esperado: 9 recebido; 7 pendente (Stella Artois 600 72, Spaten 120,
-- Corona LN 24, Soda 12, Guarana Zero lata 36, Stella Pure Gold 600 72,
-- Bare lata 64); 1 recebimento de 2535.17 com 11 itens; conta de
-- 2535.17 com recebimento.
-- ---------------------------------------------------------------------
SELECT produto, quantidade, status_receb FROM cmp_compras
WHERE pedido_num = '#02068' ORDER BY status_receb, produto;

SELECT r.data_receb, r.status, r.total_recebido, count(i.id) AS itens, sum(i.total_recebido) AS soma_itens
FROM cmp_recebimentos r JOIN cmp_recebimento_itens i ON i.recebimento_id = r.id
WHERE r.pedido_num = '#02068' GROUP BY r.id, r.data_receb, r.status, r.total_recebido;

SELECT valor, status, data_receb, (recebimento_id IS NOT NULL) AS tem_recebimento, lancamento_id
FROM cmp_contas_pagar WHERE pedido_num = '#02068';


-- ---------------------------------------------------------------------
-- PASSO 4 - NO SISTEMA (nao e SQL).
-- Aba Compras (computador) ou tela de Recebimento (celular): no #02068
-- apertar "Fechar Pedido". Os 7 pendentes viram nao entregues e o
-- pedido vai para Integracoes Pendentes com R$ 2.535,17.
-- =====================================================================
