-- Lista os produtos de venda/produção que AINDA NÃO têm ficha técnica ativa.
-- Tipos considerados: VENDA (Cardápio), PPB (Bar), PPC (Cozinha),
-- PPP (Produção) e SA (Semi-Acabado). Mostra o Grupo (categoria) para
-- facilitar a identificação e o preenchimento a partir do sistema antigo.
-- Só leitura. Rode no editor SQL do Supabase.
SELECT
  CASE p.tipo
    WHEN 'VENDA' THEN 'Cardápio (VENDA)'
    WHEN 'PPB'   THEN 'PPB - Bar'
    WHEN 'PPC'   THEN 'PPC - Cozinha'
    WHEN 'PPP'   THEN 'PPP - Produção'
    WHEN 'SA'    THEN 'SA - Semi-Acabado'
    ELSE p.tipo
  END                                   AS tipo,
  COALESCE(NULLIF(TRIM(p.categoria), ''), '(sem grupo)') AS grupo,
  p.nome                                AS produto,
  p.unidade_uso                         AS unid_uso,
  p.preco_venda                         AS preco_venda
FROM est_produtos p
WHERE p.ativo = true
  AND p.tipo IN ('VENDA', 'PPB', 'PPC', 'PPP', 'SA')
  AND NOT EXISTS (
        SELECT 1
        FROM est_fichas_tecnicas f
        WHERE f.produto_id = p.id
          AND f.ativo = true
      )
ORDER BY
  CASE p.tipo
    WHEN 'VENDA' THEN 1
    WHEN 'PPB'   THEN 2
    WHEN 'PPC'   THEN 3
    WHEN 'PPP'   THEN 4
    WHEN 'SA'    THEN 5
    ELSE 9
  END,
  grupo,
  p.nome;
