-- Resumo do bug de colisao de produto_id, por setor (poucas linhas).
-- Mostra em quantas contagens houve colisao e quantos casos, por setor.
-- Read-only, UMA unica instrucao.

WITH col AS (
  SELECT i.setor, i.num_inv, ii.produto_id
  FROM est_inventarios i
  JOIN est_inventario_itens ii ON ii.inventario_id = i.id
  WHERE i.data >= CURRENT_DATE - 30
    AND ii.produto_id IS NOT NULL
  GROUP BY i.setor, i.num_inv, ii.produto_id
  HAVING COUNT(*) > 1
)
SELECT setor,
       COUNT(DISTINCT num_inv)   AS contagens_afetadas,
       COUNT(*)                  AS casos_de_colisao
FROM col
GROUP BY setor
ORDER BY casos_de_colisao DESC;
