-- =============================================================
-- Item bonificado: entra no estoque com custo real, mas NAO entra
-- na conta a pagar.
--
-- Caso de origem: bonus da Ambev por renovacao de contrato. O chopp
-- vem com nota zerada, mas o litro tem valor. Sem isso o custo do
-- produto ia a zero (ou a 0,0001) e contaminava as 38 fichas de chopp.
--
-- E por ITEM, nao por pedido: a mesma nota costuma trazer item
-- bonificado junto de item pago normalmente.
--
-- Rodar UMA vez. Nao altera nenhum dado existente (default false).
-- =============================================================

alter table cmp_compras
  add column if not exists bonificado boolean not null default false;

alter table cmp_recebimento_itens
  add column if not exists bonificado boolean not null default false;

create index if not exists idx_cmp_compras_bonificado
  on cmp_compras (bonificado) where bonificado;

-- Como funciona:
--   pedido      -> comprador marca o item se ja sabe que sera bonificado
--   recebimento -> editavel; e ali que a nota zerada confirma
--   estoque     -> entra normal, com quantidade e valor unitario reais
--   custo       -> atualiza normal e cascateia para as fichas
--   financeiro  -> o item bonificado NAO soma no total do recebimento,
--                  entao nao entra em cmp_contas_pagar nem em lancamentos
