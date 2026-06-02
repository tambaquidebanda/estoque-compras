-- ══════════════════════════════════════════════════════════════
-- INVENTÁRIOS — Execute no Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS est_inventarios (
  id           uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  num_inv      text          NOT NULL,
  data         date          NOT NULL,
  local        text          NOT NULL DEFAULT 'Centro',
  responsavel  text,
  total_geral  decimal(12,2) DEFAULT 0,
  criado_em    timestamptz   DEFAULT now()
);

CREATE TABLE IF NOT EXISTS est_inventario_itens (
  id             uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  inventario_id  uuid          REFERENCES est_inventarios(id) ON DELETE CASCADE,
  produto_id     uuid          REFERENCES est_produtos(id),
  nome           text,
  estoque        decimal(10,3) DEFAULT 0,
  cozinha_bar    decimal(10,3) DEFAULT 0,
  outros         decimal(10,3) DEFAULT 0,
  total          decimal(10,3) DEFAULT 0,
  unidade        text          DEFAULT 'UN',
  valor_unitario decimal(10,4) DEFAULT 0,
  soma_total     decimal(12,2) DEFAULT 0
);

ALTER TABLE est_inventarios      ENABLE ROW LEVEL SECURITY;
ALTER TABLE est_inventario_itens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_only" ON est_inventarios
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "auth_only" ON est_inventario_itens
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_est_inv_data  ON est_inventarios (data DESC);
CREATE INDEX IF NOT EXISTS idx_est_inv_local ON est_inventarios (local);
CREATE INDEX IF NOT EXISTS idx_est_inv_itens ON est_inventario_itens (inventario_id);

GRANT ALL ON est_inventarios      TO authenticated;
GRANT ALL ON est_inventario_itens TO authenticated;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
