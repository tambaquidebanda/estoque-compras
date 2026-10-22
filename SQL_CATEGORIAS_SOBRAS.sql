-- =====================================================================
-- SQL_CATEGORIAS_SOBRAS.sql  (22/10/2026)
--
-- Complemento do SQL_CATEGORIAS_MP_MC_MU.sql: 6 produtos sem o prefixo
-- MP/MC/MU no nome ficaram nas categorias antigas.
--   QUEIJO RALADO, BOMBONS LACTA, milharina -> MC REFEICAO FUNCIONARIOS
--   CAIXA ORGANIZADORA C/ ABAS 16L, COPO VIDRO L. DRINK 345ML -> MU UTENSILIOS
--   AGUA COM GAS (item de venda) -> BEBIDAS NAO ALCOOLICAS (onde esta a
--   AGUA SEM GAS de venda)
-- Depois saem da lista de grupos as 3 categorias antigas que ficarem
-- vazias. A categoria antiga destes 6 ja esta em bkp_categoria_20261022.
-- Rode um PASSO de cada vez.
-- =====================================================================

-- PASSO 1 - SO LEITURA. Esperado: 6 linhas com a categoria antiga.
SELECT nome, tipo, categoria FROM est_produtos
WHERE id IN ('ef23aafe-f001-4d3b-9d5a-f7c93741bd52','9be9c271-2403-4b15-a88f-98b2d4b95834',
             '90115209-3697-4384-9da8-1d2968cc74a5','1de79ff8-56a6-462d-a818-75968b229909',
             'ea280b0d-33fe-4297-becb-6f323de762d5','cbec1c35-5d9b-415f-ac21-2fe64d4dd582')
ORDER BY nome;

-- PASSO 2 - APLICA. Esperado: UPDATE 3, UPDATE 2, UPDATE 1, DELETE 3.
BEGIN;

UPDATE est_produtos SET categoria = U&'MC REFEI\00C7\00C3O FUNCION\00C1RIOS'
WHERE id IN ('ef23aafe-f001-4d3b-9d5a-f7c93741bd52','9be9c271-2403-4b15-a88f-98b2d4b95834',
             '90115209-3697-4384-9da8-1d2968cc74a5')
  AND categoria = U&'MC REFEI\00C7\00C3O/CONSUMO FUNCIONARIOS';

UPDATE est_produtos SET categoria = U&'MU UTENS\00CDLIOS'
WHERE id IN ('1de79ff8-56a6-462d-a818-75968b229909','ea280b0d-33fe-4297-becb-6f323de762d5')
  AND categoria = 'MU UTENSILIOS';

UPDATE est_produtos SET categoria = 'BEBIDAS NAO ALCOOLICAS'
WHERE id = 'cbec1c35-5d9b-415f-ac21-2fe64d4dd582'
  AND categoria = 'MP AGUA BAR';

DELETE FROM est_grupos_produto g
WHERE g.nome IN (U&'MC REFEI\00C7\00C3O/CONSUMO FUNCIONARIOS', 'MU UTENSILIOS', 'MP AGUA BAR')
  AND NOT EXISTS (SELECT 1 FROM est_produtos p WHERE p.categoria = g.nome);

COMMIT;

-- PASSO 3 - CONFERENCIA. Esperado: 6 linhas com a categoria nova e
-- 0 grupos antigos sobrando.
SELECT nome, tipo, categoria FROM est_produtos
WHERE id IN ('ef23aafe-f001-4d3b-9d5a-f7c93741bd52','9be9c271-2403-4b15-a88f-98b2d4b95834',
             '90115209-3697-4384-9da8-1d2968cc74a5','1de79ff8-56a6-462d-a818-75968b229909',
             'ea280b0d-33fe-4297-becb-6f323de762d5','cbec1c35-5d9b-415f-ac21-2fe64d4dd582')
ORDER BY nome;

SELECT count(*) AS grupos_antigos_sobrando FROM est_grupos_produto
WHERE nome IN (U&'MC REFEI\00C7\00C3O/CONSUMO FUNCIONARIOS', 'MU UTENSILIOS', 'MP AGUA BAR');
