-- Adiciona unidade_id em lancamentos_rascunho para integrar com financeiro
ALTER TABLE lancamentos_rascunho
  ADD COLUMN IF NOT EXISTS unidade_id uuid REFERENCES unidades(id) ON DELETE SET NULL;

NOTIFY pgrst, 'reload schema';
