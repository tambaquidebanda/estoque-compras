-- ============================================================================
-- Quais produtos ficaram SEM produto_id? Separa "sem cadastro" x "duplicado".
-- Só-leitura. Rode no editor SQL do Supabase.
-- ============================================================================
WITH prod_norm AS (
  SELECT trim(lower(translate(nome,
    'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
    'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nn
  FROM est_produtos
),
matches AS (
  SELECT nn, count(*) AS n FROM prod_norm GROUP BY nn
),
faltando AS (
  SELECT DISTINCT c.produto,
    trim(lower(translate(c.produto,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nn
  FROM cmp_compras c
  WHERE c.produto_id IS NULL
)
SELECT
  f.produto AS nome_no_pedido,
  COALESCE(m.n, 0) AS qtd_cadastros_com_esse_nome,
  CASE
    WHEN COALESCE(m.n,0) = 0 THEN '❌ nenhum cadastro (fallback por nome)'
    WHEN m.n > 1            THEN '⚠️ DUPLICADO no cadastro — limpar'
    ELSE '（deveria ter casado — verificar）'
  END AS situacao
FROM faltando f
LEFT JOIN matches m ON m.nn = f.nn
ORDER BY situacao, f.produto;
