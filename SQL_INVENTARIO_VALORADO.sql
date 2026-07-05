-- Inventario Valorado (snapshot momentizado do estoque)
-- Rodar no Supabase SQL Editor. Nao afeta nenhuma tabela existente.

CREATE TABLE IF NOT EXISTS est_inventario_valorado (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data           date NOT NULL,
  base_custo     text NOT NULL DEFAULT 'ultimo_preco',
  responsavel    text,
  qtd_produtos   integer,
  total_valor    numeric(14,2) NOT NULL DEFAULT 0,
  valor_por_local jsonb NOT NULL DEFAULT '{}'::jsonb,
  criado_em      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS est_inventario_valorado_itens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventario_id uuid NOT NULL REFERENCES est_inventario_valorado(id) ON DELETE CASCADE,
  produto_id    uuid,
  nome          text,
  grupo         text,
  quantidade    numeric(14,3) NOT NULL DEFAULT 0,
  custo_unit    numeric(14,4) NOT NULL DEFAULT 0,
  valor         numeric(14,2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_inv_val_itens_inv ON est_inventario_valorado_itens(inventario_id);
CREATE INDEX IF NOT EXISTS idx_inv_val_data ON est_inventario_valorado(data DESC);
