-- ═══════════════════════════════════════════════════════════════
-- Baixa automática de estoque (iComanda) — tabelas de apoio do robô
-- Rodar UMA vez no SQL Editor do Supabase.
-- NÃO mexe em est_saldo_local nem est_movimentacoes — só cria apoio.
-- ═══════════════════════════════════════════════════════════════

-- 1) PREVIEW — o que o robô CALCULARIA baixar (modo dry-run). Auditável, não toca estoque.
create table if not exists pdv_baixa_preview (
  id             uuid primary key default gen_random_uuid(),
  data           date not null,
  ingrediente_id uuid references est_produtos(id) on delete cascade,
  ingrediente_nome text,
  quantidade     numeric not null default 0,   -- consumo em unidade de USO (positivo = quanto sairia)
  custo_unit     numeric default 0,
  valor          numeric default 0,
  fontes         integer default 0,            -- quantos produtos de venda contribuíram
  criado_em      timestamptz default now(),
  unique (data, ingrediente_id)
);
create index if not exists idx_pdv_baixa_preview_data on pdv_baixa_preview(data);

-- 2) CONTROLE — dias já processados (idempotência do modo apply: nunca baixa o mesmo dia 2×).
create table if not exists pdv_baixa_ctrl (
  data           date primary key,
  modo           text,                         -- 'dry' | 'apply'
  status         text,                         -- 'ok' | 'erro' | 'processando'
  itens_venda    integer default 0,
  insumos        integer default 0,
  valor          numeric default 0,
  detalhe        text,
  processado_em  timestamptz default now()
);

-- Como o robô usa:
--   modo dry   → grava só em pdv_baixa_preview (e loga em pdv_baixa_ctrl). Estoque intocado.
--   modo apply → grava em est_movimentacoes (tipo 'venda_pensera', origem 'pdv_icomanda')
--                e desconta est_saldo_local; pula dias já 'ok' no pdv_baixa_ctrl.
