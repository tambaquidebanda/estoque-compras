-- ============================================================================
-- Vínculo por CÓDIGO (produto_id) no pedido de compra
-- ----------------------------------------------------------------------------
-- Adiciona produto_id em cmp_compras E cmp_recebimento_itens para casar
-- recebimento -> saldo por id (não mais por nome). Aditivo e seguro.
-- Rode no editor SQL do Supabase (tudo de uma vez).
-- ============================================================================

ALTER TABLE cmp_compras
  ADD COLUMN IF NOT EXISTS produto_id uuid REFERENCES est_produtos(id);

CREATE INDEX IF NOT EXISTS idx_cmp_compras_produto_id
  ON cmp_compras (produto_id);

ALTER TABLE cmp_recebimento_itens
  ADD COLUMN IF NOT EXISTS produto_id uuid REFERENCES est_produtos(id);

CREATE INDEX IF NOT EXISTS idx_cmp_recebimento_itens_produto_id
  ON cmp_recebimento_itens (produto_id);
