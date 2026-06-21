-- ══════════════════════════════════════════════════════════════
-- PEDIDOS INTERNOS (setor → estoque)
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

-- Cabeçalho do pedido
CREATE TABLE IF NOT EXISTS pedidos_internos (
  id            uuid         DEFAULT gen_random_uuid() PRIMARY KEY,
  num_pedido    text         NOT NULL,
  data          date         NOT NULL DEFAULT CURRENT_DATE,
  dia_semana    text,                          -- 'seg','ter','qua','qui','sex','sab','dom','feriado'
  setor         text         NOT NULL,         -- 'CHURRASQUEIRA','COZINHA','BAR','SALAO','ASG','DELIVERY'
  local         text,                          -- 'Centro','P10'
  tipo          text         DEFAULT 'normal', -- 'normal' | 'emergencia'
  status        text         DEFAULT 'pendente', -- 'pendente' | 'liberado' | 'recebido' | 'cancelado'
  responsavel   text,
  obs           text,
  criado_em     timestamptz  DEFAULT now(),
  liberado_em   timestamptz,
  recebido_em   timestamptz
);

-- Itens do pedido
CREATE TABLE IF NOT EXISTS pedidos_internos_itens (
  id            uuid         DEFAULT gen_random_uuid() PRIMARY KEY,
  pedido_id     uuid         NOT NULL REFERENCES pedidos_internos(id) ON DELETE CASCADE,
  produto_id    uuid,                          -- FK para est_produtos (nullable)
  nome          text         NOT NULL,
  qtd_pedida    numeric      DEFAULT 0,
  qtd_liberada  numeric,
  qtd_recebida  numeric,
  obs_item      text
);

-- Índices úteis
CREATE INDEX IF NOT EXISTS idx_pedidos_internos_status  ON pedidos_internos(status);
CREATE INDEX IF NOT EXISTS idx_pedidos_internos_setor   ON pedidos_internos(setor);
CREATE INDEX IF NOT EXISTS idx_pedidos_internos_data    ON pedidos_internos(data);
CREATE INDEX IF NOT EXISTS idx_ped_itens_pedido_id      ON pedidos_internos_itens(pedido_id);
