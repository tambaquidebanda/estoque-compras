-- Procura no cadastro os produtos parecidos com os 3 nomes orfaos da estrutura,
-- para eu ver a grafia exata e alinhar (ou saber se falta cadastrar).

SELECT nome, tipo, ativo
FROM est_produtos
WHERE nome ILIKE '%polpa%cupua%'
   OR nome ILIKE '%corona%'
   OR nome ILIKE '%embalagem%742%' OR nome ILIKE '%G742%' OR nome ILIKE '%G-742%' OR nome ILIKE '%G 742%'
ORDER BY nome;
