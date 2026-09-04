-- Recria UM recebimento (25/07, 200 un = 2660.80) para o pedido 00650 e liga a conta a ele.
-- Um unico recebimento limpo, sem duplicar.

WITH nr AS (
  INSERT INTO cmp_recebimentos (pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status)
  SELECT '#00650', DATE '2026-07-25', c.comprador, c.fornecedor_nome, c.comprador, 2660.80, 'confirmado'
  FROM cmp_compras c WHERE c.pedido_num = '#00650' LIMIT 1
  RETURNING id
),
ni AS (
  INSERT INTO cmp_recebimento_itens (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida, valor_unitario, total_recebido, divergencia)
  SELECT nr.id, c.id, c.produto, c.categoria, c.unidade_med, 200, 200, 13.304, 2660.80, false
  FROM nr, cmp_compras c WHERE c.pedido_num = '#00650'
  RETURNING recebimento_id
)
UPDATE cmp_contas_pagar SET recebimento_id = (SELECT id FROM nr) WHERE pedido_num = '#00650';

-- Verificacao
SELECT r.data_receb, r.total_recebido, r.status, ri.produto, ri.qtd_recebida, ri.valor_unitario, ri.total_recebido AS item_total
FROM cmp_recebimentos r
LEFT JOIN cmp_recebimento_itens ri ON ri.recebimento_id = r.id
WHERE r.pedido_num = '#00650';
