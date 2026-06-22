-- ══════════════════════════════════════════════════════════════
-- Saldo do ESTOQUE DA LOJA
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS est_saldo (
  produto_id uuid PRIMARY KEY REFERENCES est_produtos(id),
  saldo      numeric NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
