-- =====================================================================
-- SQL_PRODUCAO_META_V2.sql   (08/10/2026)
--
-- Meta da Producao com a conta nova (aprovada pelo Wagner em 08/10/2026):
-- o que a Producao faz de sexta a quinta so entra na venda na segunda.
--   Sobra na segunda = estoque de quinta - venda media de qui+sex+sab+dom
--   Meta             = venda media de seg a dom x (1 + margem) - sobra na segunda
--
-- Acrescenta UMA coluna, opcional, em prod_meta_itens: fim_semana (a venda
-- prevista de quinta a domingo), para a meta aprovada guardar esse numero.
-- Sem a coluna a tela funciona igual; so a meta aprovada mostra "-" nela.
-- Nada e apagado.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: zero linhas (a coluna ainda nao existe).
SELECT column_name FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'prod_meta_itens' AND column_name = 'fim_semana';


-- PASSO 2 - CRIA (idempotente)
BEGIN;
ALTER TABLE prod_meta_itens ADD COLUMN IF NOT EXISTS fim_semana numeric;
COMMIT;


-- PASSO 3 - CONFERENCIA. Esperado: 1 linha, numeric, YES.
SELECT column_name, data_type, is_nullable FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'prod_meta_itens' AND column_name = 'fim_semana';
