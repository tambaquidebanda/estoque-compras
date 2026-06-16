-- Corrige custo_unit em cmp_compras com o preço efetivamente recebido
-- (para pedidos recebidos antes do fix que passou a salvar o preço automaticamente)
-- Usa o recebimento mais recente de cada item como fonte de verdade

UPDATE cmp_compras c
SET custo_unit = (
  SELECT ri.valor_unitario
  FROM cmp_recebimento_itens ri
  JOIN cmp_recebimentos r ON ri.recebimento_id = r.id
  WHERE ri.compra_id = c.id
    AND ri.valor_unitario > 0
  ORDER BY r.criado_em DESC
  LIMIT 1
)
WHERE EXISTS (
  SELECT 1
  FROM cmp_recebimento_itens ri
  JOIN cmp_recebimentos r ON ri.recebimento_id = r.id
  WHERE ri.compra_id = c.id
    AND ri.valor_unitario > 0
    AND ri.valor_unitario <> c.custo_unit
);
