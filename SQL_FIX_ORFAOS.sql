-- Alinha na estrutura de contagem os nomes que estavam diferentes do cadastro.
-- Troca cirurgica da string EXATA (entre aspas) em todas as unidades. Cast ::jsonb valida no fim.

-- 1) Polpa de Cupuacu 1KG
UPDATE inv_configuracoes
SET valor = replace(valor::text, '"MP POLPA CUPUAÇU 1 KG"', '"MP POLPA DE CUPUAÇU 1KG"')::jsonb
WHERE chave = 'estrutura' AND valor::text LIKE '%"MP POLPA CUPUAÇU 1 KG"%';

-- 2) Embalagem G742 (Molheira)
UPDATE inv_configuracoes
SET valor = replace(valor::text, '"MC EMBALAGEM G742"', '"MC EMBALAGEM G742 (MOLHEIRA)"')::jsonb
WHERE chave = 'estrutura' AND valor::text LIKE '%"MC EMBALAGEM G742"%';

-- Verificacao: nao deve mais aparecer POLPA CUPUACU 1 KG sem "DE", nem EMBALAGEM G742 sem (MOLHEIRA)
SELECT DISTINCT m[1] AS nome_apos_fix
FROM inv_configuracoes,
     LATERAL regexp_matches(valor::text, '"([^"]*(polpa[^"]*cupua|embalagem g742)[^"]*)"', 'gi') AS m
WHERE chave = 'estrutura';
