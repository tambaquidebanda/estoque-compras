-- =====================================================================
-- SQL_RECEBE_01806.sql  (22/10/2026)
--
-- Pedido #01806 - 3 FD MP FARINHA BRANCA, R$ 480, Delivery P10,
-- Mercadinho Goncalves. Chegou em 16/10 no Estoque da Loja do Teatro e
-- depois foi levado ao P10. No sistema alguem usou "Fechar pedido" sem
-- receber: o item ficou 'dispensado', sem recebimento e sem conta, e a
-- aba Compras mostra o pedido como pendente.
--
-- Este SQL registra o recebimento igual ao do #01647 (mesmo item, mesma
-- loja): recebimento no ESTOQUE DELIVERY em 16/10, item 3 FD, conta a
-- pagar ligada ao lancamento que o financeiro ja pagou e conciliou
-- (e63157dd..., agora na unidade Delivery P10), e o item vira 'recebido'.
--
-- NAO mexe no saldo de estoque (nao grava em est_movimentacoes nem em
-- est_saldo_local): o P10 ja lancou o saldo da farinha no ESTOQUE
-- DELIVERY por "Saldo inicial" em 16/10 (65 e depois 75), com os
-- fardos dentro. Somar +75 agora contaria a farinha duas vezes.
-- NAO cria lancamento no financeiro (ele ja existe).
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA.
-- Esperado: 1 linha em cmp_compras com status_receb 'dispensado';
-- 0 recebimentos; 0 contas; 1 lancamento pago na unidade Delivery P10.
-- ---------------------------------------------------------------------
SELECT pedido_num, produto, quantidade, unidade_med, total, unidade_uso, status_receb
FROM cmp_compras WHERE id = '74f3d7a0-f177-4761-b354-097a4d029a97';

SELECT 'recebimentos' AS o_que, count(*) FROM cmp_recebimentos WHERE pedido_num = '#01806'
UNION ALL
SELECT 'contas a pagar', count(*) FROM cmp_contas_pagar WHERE pedido_num = '#01806';

SELECT l.numero_pedido, l.valor, l.status, l.data_pagamento, u.nome AS unidade
FROM lancamentos l LEFT JOIN unidades u ON u.id = l.unidade_id
WHERE l.id = 'e63157dd-125d-4db6-982a-70acf554f06b';


-- ---------------------------------------------------------------------
-- PASSO 2 - REGISTRA O RECEBIMENTO (tudo junto ou nada).
-- So roda se o item ainda estiver 'dispensado' e o pedido nao tiver
-- recebimento nem conta. Se rodar de novo, nao faz nada.
-- Deve responder "UPDATE 1" (e depois COMMIT).
-- ---------------------------------------------------------------------
BEGIN;

WITH novo AS (
  INSERT INTO cmp_recebimentos
    (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
  SELECT c.pedido_num, DATE '2026-10-16',
         'Ajuste SQL 22/10 (chegou no Teatro, levado ao P10)',
         c.fornecedor_nome, c.comprador, c.total, 'confirmado', 'ESTOQUE DELIVERY'
  FROM cmp_compras c
  WHERE c.id = '74f3d7a0-f177-4761-b354-097a4d029a97'
    AND c.status_receb = 'dispensado'
    AND NOT EXISTS (SELECT 1 FROM cmp_recebimentos  WHERE pedido_num = '#01806')
    AND NOT EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = '#01806')
  RETURNING id
), item AS (
  INSERT INTO cmp_recebimento_itens
    (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
     valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado)
  SELECT novo.id, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade,
         c.custo_unit, c.total, false, '', c.produto_id, false
  FROM novo, cmp_compras c
  WHERE c.id = '74f3d7a0-f177-4761-b354-097a4d029a97'
  RETURNING id
), conta AS (
  INSERT INTO cmp_contas_pagar
    (pedido_num, recebimento_id, fornecedor, data_receb, vencimento, valor, status,
     lancamento_id, parcelas, parcela_intervalo)
  SELECT c.pedido_num, novo.id, c.fornecedor_nome, DATE '2026-10-16', DATE '2026-10-16',
         c.total, 'pendente', 'e63157dd-125d-4db6-982a-70acf554f06b', 1, 'mensal'
  FROM novo, cmp_compras c
  WHERE c.id = '74f3d7a0-f177-4761-b354-097a4d029a97'
  RETURNING id
)
UPDATE cmp_compras
SET status_receb = 'recebido'
WHERE id = '74f3d7a0-f177-4761-b354-097a4d029a97'
  AND status_receb = 'dispensado'
  AND EXISTS (SELECT 1 FROM novo)
  AND EXISTS (SELECT 1 FROM item)
  AND EXISTS (SELECT 1 FROM conta);

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA.
-- Esperado: item 'recebido'; 1 recebimento confirmado no ESTOQUE
-- DELIVERY de R$ 480 com 1 item de 3 FD; 1 conta de R$ 480 ligada ao
-- lancamento e63157dd...; 0 movimentos de estoque do #01806.
-- ---------------------------------------------------------------------
SELECT pedido_num, status_receb FROM cmp_compras
WHERE id = '74f3d7a0-f177-4761-b354-097a4d029a97';

SELECT r.pedido_num, r.data_receb, r.local, r.status, r.total_recebido,
       i.produto, i.qtd_recebida, i.unidade, i.total_recebido AS total_item
FROM cmp_recebimentos r
JOIN cmp_recebimento_itens i ON i.recebimento_id = r.id
WHERE r.pedido_num = '#01806';

SELECT pedido_num, valor, status, lancamento_id, (recebimento_id IS NOT NULL) AS tem_recebimento
FROM cmp_contas_pagar WHERE pedido_num = '#01806';

SELECT count(*) AS movimentos_estoque_01806
FROM est_movimentacoes m
JOIN cmp_recebimentos r ON r.id::text = m.ref_id::text
WHERE r.pedido_num = '#01806';
