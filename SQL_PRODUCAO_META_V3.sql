-- =====================================================================
-- SQL_PRODUCAO_META_V3.sql   (08/10/2026)
--
-- Meta da Producao: "Cobrir ate" (pedido do Wagner, 08/10/2026). A meta cobre
-- a venda a partir da segunda em que a producao entra na venda, ate o domingo
-- (7 dias) ou ate a seg/ter/qua seguinte (8, 9 ou 10 dias; padrao 10).
-- Acrescenta UMA coluna opcional em prod_metas para guardar o que foi usado no
-- rascunho e na meta aprovada. Sem ela a tela funciona, so nao guarda.
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: zero linhas.
SELECT column_name FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'prod_metas' AND column_name = 'dias_cobertura';


-- PASSO 2 - CRIA (idempotente)
BEGIN;
ALTER TABLE prod_metas ADD COLUMN IF NOT EXISTS dias_cobertura integer;
COMMIT;


-- PASSO 3 - CONFERENCIA. Esperado: 1 linha, integer.
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'prod_metas' AND column_name = 'dias_cobertura';
