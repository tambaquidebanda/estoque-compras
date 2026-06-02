-- ══════════════════════════════════════════════════════════════
-- DEMANDA SEMANAL — Execute no Supabase → SQL Editor
-- Adiciona campo de demanda semanal fixa em est_produtos
-- ══════════════════════════════════════════════════════════════

ALTER TABLE est_produtos ADD COLUMN IF NOT EXISTS vendas_medias decimal(10,3) DEFAULT 0;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
