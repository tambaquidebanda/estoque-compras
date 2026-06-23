-- ══════════════════════════════════════════════════════════════
-- Transferências entre unidades
-- Adiciona colunas em pedidos_internos para suportar transferências
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

ALTER TABLE pedidos_internos
  ADD COLUMN IF NOT EXISTS tipo text NOT NULL DEFAULT 'interno',
  ADD COLUMN IF NOT EXISTS unidade_origem text,
  ADD COLUMN IF NOT EXISTS origem text NOT NULL DEFAULT 'manual';

-- tipo: 'interno' (setor→estoque loja, existing) | 'transferencia' (estoque loja→estoque central)
-- unidade_origem: for transfers, who is sending (e.g. 'Estoque Central')
-- origem: 'manual' (staff created) | 'automatico' (future: ficha técnica engine)

COMMENT ON COLUMN pedidos_internos.origem IS 'manual = staff; automatico = ficha técnica engine (future)';
