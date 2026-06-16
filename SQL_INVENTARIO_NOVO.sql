-- Migração: novo layout de inventário por Setor → Grupo
-- Rodar no Supabase SQL Editor

ALTER TABLE est_inventarios
  ADD COLUMN IF NOT EXISTS grupo text;

ALTER TABLE est_inventario_itens
  ADD COLUMN IF NOT EXISTS pedido_padrao numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pedido       numeric DEFAULT 0;
