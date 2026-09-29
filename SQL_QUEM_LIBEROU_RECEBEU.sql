-- =====================================================================
-- SQL_QUEM_LIBEROU_RECEBEU.sql  (29/09/2026)
--
-- Grava QUEM liberou e QUEM recebeu cada pedido interno.
--
-- Por que: na noite de 28/09 os 21 pedidos da Cozinha e do Bar foram
-- liberados entre 23:00 e 23:02, sem nenhum item ajustado, e recebidos
-- ate 23:06. O sistema so guardava o HORARIO, nao o nome.
--
-- O que faz: cria 2 colunas de texto, vazias, em pedidos_internos:
--   liberado_por  -> nome de quem liberou
--   recebido_por  -> nome de quem recebeu
-- Nao altera nenhum pedido antigo (ficam vazias neles).
-- No celular a pessoa digita o nome; no computador vai o nome do login.
--
-- Ordem: rodar este SQL, depois o Push, depois F5 nas telas.
-- (Se o Push for antes, nao quebra nada: a tela so nao grava o nome
--  ate o SQL rodar e a tela ser recarregada.)
-- =====================================================================


-- PASSO 1 - CONFERENCIA (so leitura). Esperado: 0 linhas.
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'pedidos_internos'
  AND column_name IN ('liberado_por', 'recebido_por');


-- PASSO 2 - CRIA AS COLUNAS
ALTER TABLE public.pedidos_internos
  ADD COLUMN IF NOT EXISTS liberado_por text,
  ADD COLUMN IF NOT EXISTS recebido_por text;

-- faz a API enxergar as colunas novas na hora
NOTIFY pgrst, 'reload schema';


-- PASSO 3 - CONFERENCIA. Esperado: 2 linhas (liberado_por, recebido_por), tipo text.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'pedidos_internos'
  AND column_name IN ('liberado_por', 'recebido_por')
ORDER BY column_name;


-- DESFAZER (so se precisar):
-- ALTER TABLE public.pedidos_internos DROP COLUMN liberado_por, DROP COLUMN recebido_por;
