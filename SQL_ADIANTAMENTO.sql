-- Adiantamento: separa lançamento de adiantamento do lançamento final (NF)
-- Rodar no Supabase SQL Editor

ALTER TABLE cmp_contas_pagar
  ADD COLUMN IF NOT EXISTS adiantamento_lancamento_id uuid;
