-- ══════════════════════════════════════════════════════════════
-- MIGRAÇÃO: Campos de pedido e recebimento
-- Execute no Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════

-- Adiciona campos de pedido ao cmp_compras
ALTER TABLE cmp_compras ADD COLUMN IF NOT EXISTS pedido_num    text;
ALTER TABLE cmp_compras ADD COLUMN IF NOT EXISTS data_entrega  date;
ALTER TABLE cmp_compras ADD COLUMN IF NOT EXISTS status_receb  text DEFAULT 'pendente';

CREATE INDEX IF NOT EXISTS idx_cmp_pedido_num ON cmp_compras (pedido_num);

-- Tabela de recebimentos
CREATE TABLE IF NOT EXISTS cmp_recebimentos (
  id              uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  pedido_num      text          NOT NULL,
  data_receb      date          NOT NULL,
  responsavel     text,
  fornecedor      text,
  comprador       text,
  total_recebido  decimal(12,2) DEFAULT 0,
  status          text          DEFAULT 'confirmado',
  criado_em       timestamptz   DEFAULT now()
);

-- Itens de cada recebimento
CREATE TABLE IF NOT EXISTS cmp_recebimento_itens (
  id              uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  recebimento_id  uuid          REFERENCES cmp_recebimentos(id) ON DELETE CASCADE,
  compra_id       uuid          REFERENCES cmp_compras(id),
  produto         text,
  categoria       text,
  unidade         text          DEFAULT 'UN',
  qtd_pedida      decimal(10,3) DEFAULT 0,
  qtd_recebida    decimal(10,3) DEFAULT 0,
  valor_unitario  decimal(10,4) DEFAULT 0,
  total_recebido  decimal(12,2) DEFAULT 0,
  divergencia     boolean       DEFAULT false,
  obs_divergencia text
);

-- Contas a pagar geradas pelo recebimento
CREATE TABLE IF NOT EXISTS cmp_contas_pagar (
  id              uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  pedido_num      text,
  recebimento_id  uuid          REFERENCES cmp_recebimentos(id),
  fornecedor      text,
  data_receb      date,
  vencimento      date,
  valor           decimal(12,2) DEFAULT 0,
  status          text          DEFAULT 'pendente',
  data_pagamento  date,
  criado_em       timestamptz   DEFAULT now()
);

-- Segurança
ALTER TABLE cmp_recebimentos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE cmp_recebimento_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE cmp_contas_pagar      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_only" ON cmp_recebimentos
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_only" ON cmp_recebimento_itens
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_only" ON cmp_contas_pagar
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Índices
CREATE INDEX IF NOT EXISTS idx_cmp_receb_pedido ON cmp_recebimentos (pedido_num);
CREATE INDEX IF NOT EXISTS idx_cmp_receb_data   ON cmp_recebimentos (data_receb DESC);
CREATE INDEX IF NOT EXISTS idx_cmp_cp_status    ON cmp_contas_pagar (status);
CREATE INDEX IF NOT EXISTS idx_cmp_cp_venc      ON cmp_contas_pagar (vencimento);

-- Permissões
GRANT ALL ON cmp_recebimentos      TO authenticated;
GRANT ALL ON cmp_recebimento_itens TO authenticated;
GRANT ALL ON cmp_contas_pagar      TO authenticated;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
