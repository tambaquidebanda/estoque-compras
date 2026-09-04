-- Sincroniza o custo_comp de TODOS os produtos que tem ficha ativa com o
-- custo_por_porcao ja calculado e guardado na propria ficha.
-- Conserta produtos que ficaram zerados (ex: SA ISCA DE FRANGO 130g: 0 -> 1.3426).
-- So mexe onde diverge e onde a ficha tem valor > 0. Nao recalcula nada; copia o que ja existe.

UPDATE est_produtos p
SET custo_comp = f.custo_por_porcao
FROM est_fichas_tecnicas f
WHERE f.produto_id = p.id
  AND f.ativo = true
  AND f.custo_por_porcao > 0
  AND abs(coalesce(p.custo_comp, 0) - f.custo_por_porcao) > 0.005;

-- Verificacao: os ISCA DE FRANGO agora devem ter custo_comp = custo da ficha
SELECT p.nome, p.custo_comp, f.custo_por_porcao
FROM est_produtos p
JOIN est_fichas_tecnicas f ON f.produto_id = p.id AND f.ativo = true
WHERE p.nome ILIKE '%ISCA DE FRANGO%';
