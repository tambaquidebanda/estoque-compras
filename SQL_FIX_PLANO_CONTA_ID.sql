-- ══════════════════════════════════════════════════════════════
-- DIAGNÓSTICO
-- ══════════════════════════════════════════════════════════════

-- 1. Categorias com plano_conta_id apontando para GRUPO (erro: deveria ser subcategoria)
SELECT c.nome AS categoria, c.plano_conta, pc.nome AS plano_nome, pc.grupo_id
FROM cmp_categorias c
JOIN plano_contas pc ON pc.id = c.plano_conta_id
WHERE pc.grupo_id IS NULL   -- grupo-pai, não subcategoria
ORDER BY c.nome;

-- 2. Categorias sem plano_conta_id mas com plano_conta preenchido
SELECT c.nome AS categoria, c.plano_conta
FROM cmp_categorias c
WHERE c.plano_conta_id IS NULL
  AND c.plano_conta IS NOT NULL
  AND c.plano_conta <> ''
ORDER BY c.nome;

-- 3. O que a migração conseguiria casar (subcategorias apenas)
SELECT c.nome AS categoria, c.plano_conta, pc.id, pc.nome AS plano_nome
FROM cmp_categorias c
JOIN plano_contas pc ON LOWER(TRIM(c.plano_conta)) = LOWER(TRIM(pc.nome))
WHERE c.plano_conta_id IS NULL
  AND pc.grupo_id IS NOT NULL   -- somente subcategorias
ORDER BY c.nome;

-- ══════════════════════════════════════════════════════════════
-- CORREÇÃO
-- ══════════════════════════════════════════════════════════════

-- 4. Zera plano_conta_id onde ele aponta para um grupo-pai (não é subcategoria)
--    Após isso, a migração abaixo tenta repreencher com a subcategoria correta.
UPDATE cmp_categorias c
SET plano_conta_id = NULL
FROM plano_contas pc
WHERE pc.id = c.plano_conta_id
  AND pc.grupo_id IS NULL;   -- era um grupo, não subcategoria

-- 5. Preenche plano_conta_id com a subcategoria cujo nome bate com plano_conta
UPDATE cmp_categorias c
SET plano_conta_id = pc.id
FROM plano_contas pc
WHERE LOWER(TRIM(c.plano_conta)) = LOWER(TRIM(pc.nome))
  AND c.plano_conta_id IS NULL
  AND pc.grupo_id IS NOT NULL;   -- garante que é subcategoria

-- ══════════════════════════════════════════════════════════════
-- VERIFICAÇÃO FINAL
-- ══════════════════════════════════════════════════════════════

-- 6. Categorias que ainda não têm subcategoria vinculada (precisam de ajuste manual)
SELECT c.nome AS categoria, c.plano_conta, c.plano_conta_id
FROM cmp_categorias c
WHERE (c.plano_conta_id IS NULL
   OR EXISTS (
       SELECT 1 FROM plano_contas pc
       WHERE pc.id = c.plano_conta_id AND pc.grupo_id IS NULL
   ))
  AND c.plano_conta IS NOT NULL
  AND c.plano_conta <> ''
ORDER BY c.nome;
-- Se ainda aparecer linhas: ir em Cadastros → Categorias → lápis e selecionar
-- a subcategoria correta manualmente (o dropdown agora mostra apenas subcategorias).
