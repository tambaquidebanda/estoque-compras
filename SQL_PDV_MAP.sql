-- ═══════════════════════════════════════════════════════════════
-- pdv_map — Mapeamento produto do PDV (iComanda) → produto/ficha do estoque
-- Base da baixa automática de estoque. Rodar UMA vez no SQL Editor do Supabase.
-- ═══════════════════════════════════════════════════════════════

create table if not exists pdv_map (
  id                  uuid primary key default gen_random_uuid(),
  icomanda_produto_id integer unique not null,          -- CHAVE: id interno do iComanda
  icomanda_nome       text,                             -- último nome visto no PDV (rótulo)
  produto_id          uuid references est_produtos(id) on delete set null,  -- alvo no estoque (a ficha é achada por este produto)
  status              text not null default 'pendente'
                        check (status in ('mapeado','ignorar','pendente')),
  fator               numeric not null default 1,       -- multiplicador de porção (ex.: "3 pessoas" = 3)
  qtd_30d             numeric default 0,                -- volume de venda nos últimos 30 dias (para priorizar)
  obs                 text,
  criado_em           timestamptz default now(),
  atualizado_em       timestamptz default now()
);

create index if not exists idx_pdv_map_status  on pdv_map(status);
create index if not exists idx_pdv_map_produto on pdv_map(produto_id);

-- Fluxo de uso (na tela "Mapeamento PDV → Estoque"):
--   1) "Sincronizar iComanda"  → puxa os produtos vendidos (30d) e insere os novos como 'pendente'.
--   2) "Auto-semear"           → casa por nome com produtos que já têm ficha (vira 'mapeado'),
--                                e marca modificadores/origem (BRA/EST/MAO, gelo, talheres, couvert) como 'ignorar'.
--   3) Curadoria manual        → ajusta os que sobraram pendentes.
-- Só baixa estoque o que estiver status='mapeado' E cujo produto_id tiver ficha técnica ativa.
