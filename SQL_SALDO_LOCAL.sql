-- ══════════════════════════════════════════════════════════════
-- Saldo por localização (ESTOQUE_LOJA + setores)
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS est_saldo_local (
  produto_id  uuid NOT NULL REFERENCES est_produtos(id),
  local       text NOT NULL,   -- 'ESTOQUE_LOJA' | 'CHURRASQUEIRA' | 'COZINHA' | etc.
  saldo       numeric NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (produto_id, local)
);
