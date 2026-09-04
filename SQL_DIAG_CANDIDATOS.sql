-- Mostra os produtos JÁ cadastrados parecidos com os 2 nomes sem match,
-- para decidir se é caso de MAPEAR (já existe) ou CADASTRAR (não existe).
-- Só leitura.
SELECT id, nome, unidade_comp, custo_comp, ativo
FROM est_produtos
WHERE nome ILIKE '%cupua%'
   OR nome ILIKE '%G742%'
   OR nome ILIKE '%EMBALAGEM%'
ORDER BY nome;
