-- =====================================================================
-- SQL_PRODUCAO_REMARCAR.sql   (08/10/2026)
--
-- Meta que nao bateu no dia: a Producao escolhe no tablet QUANDO termina o
-- restante (outro dia da semana) ou "nao vai fazer" (pedido do Wagner, 08/10).
--
--   prod_meta_itens.dia_original  - o dia aprovado, guardado na 1a remarcacao
--                                   (o campo "dia" passa a ser o dia novo)
--   prod_meta_itens.encerrado_em  - "nao vai fazer": a SA sai de atrasada
--   prod_ocorrencias.acao         - 'remarcado' ou 'encerrado'
--   prod_ocorrencias.remarcado_para - o dia novo
--
-- So acrescenta colunas opcionais. Nada e apagado.
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: zero linhas (as colunas ainda nao existem).
SELECT table_name, column_name FROM information_schema.columns
 WHERE table_schema = 'public'
   AND ((table_name = 'prod_meta_itens' AND column_name IN ('dia_original', 'encerrado_em'))
     OR (table_name = 'prod_ocorrencias' AND column_name IN ('acao', 'remarcado_para')));


-- PASSO 2 - CRIA (idempotente)
BEGIN;
ALTER TABLE prod_meta_itens  ADD COLUMN IF NOT EXISTS dia_original   date;
ALTER TABLE prod_meta_itens  ADD COLUMN IF NOT EXISTS encerrado_em   timestamptz;
ALTER TABLE prod_ocorrencias ADD COLUMN IF NOT EXISTS acao           text;
ALTER TABLE prod_ocorrencias ADD COLUMN IF NOT EXISTS remarcado_para date;
COMMIT;


-- PASSO 3 - CONFERENCIA. Esperado: 4 linhas.
SELECT table_name, column_name, data_type FROM information_schema.columns
 WHERE table_schema = 'public'
   AND ((table_name = 'prod_meta_itens' AND column_name IN ('dia_original', 'encerrado_em'))
     OR (table_name = 'prod_ocorrencias' AND column_name IN ('acao', 'remarcado_para')))
 ORDER BY 1, 2;
