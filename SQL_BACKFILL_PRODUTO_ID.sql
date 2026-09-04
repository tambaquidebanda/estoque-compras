-- ============================================================================
-- BACKFILL do produto_id em pedidos/recebimentos antigos (casa por nome UMA vez)
-- ----------------------------------------------------------------------------
-- Rode DEPOIS de SQL_ADD_PRODUTO_ID.sql. Só preenche onde produto_id está NULL e
-- onde existe EXATAMENTE UM produto com aquele nome normalizado (evita atribuir
-- errado em nomes ambíguos). Nomes que não casarem ficam NULL e continuam no
-- fallback por nome do código. Seguro rodar mais de uma vez.
-- ============================================================================

-- 1) cmp_compras
WITH prod_norm AS (
  SELECT id, trim(lower(translate(nome,
    'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
    'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nn
  FROM est_produtos
),
uniq AS (
  SELECT nn, (array_agg(id))[1] AS id FROM prod_norm GROUP BY nn HAVING count(*) = 1
)
UPDATE cmp_compras c
SET produto_id = u.id
FROM uniq u
WHERE c.produto_id IS NULL
  AND trim(lower(translate(c.produto,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) = u.nn;

-- 2) cmp_recebimento_itens
WITH prod_norm AS (
  SELECT id, trim(lower(translate(nome,
    'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
    'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nn
  FROM est_produtos
),
uniq AS (
  SELECT nn, (array_agg(id))[1] AS id FROM prod_norm GROUP BY nn HAVING count(*) = 1
)
UPDATE cmp_recebimento_itens ri
SET produto_id = u.id
FROM uniq u
WHERE ri.produto_id IS NULL
  AND trim(lower(translate(ri.produto,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) = u.nn;

-- 3) Conferência: quantos ficaram sem vínculo (rode separado)
SELECT
  (SELECT count(*) FROM cmp_compras          WHERE produto_id IS NULL) AS compras_sem_id,
  (SELECT count(*) FROM cmp_recebimento_itens WHERE produto_id IS NULL) AS receb_itens_sem_id;
