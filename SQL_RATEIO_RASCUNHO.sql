-- Suporte a rateio por plano de contas nos rascunhos de integração
-- Permite que um pedido com múltiplas categorias gere uma única conta a pagar
-- com rateio automático no financeiro.

-- 1. Marca o rascunho como "tem rateio"
ALTER TABLE lancamentos_rascunho
  ADD COLUMN IF NOT EXISTS tem_rateio boolean DEFAULT false;

-- 2. Itens de rateio vinculados ao rascunho (espelho de rateio_itens do financeiro)
CREATE TABLE IF NOT EXISTS rascunho_rateio_itens (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  rascunho_id    uuid        REFERENCES lancamentos_rascunho(id) ON DELETE CASCADE,
  plano_conta_id uuid        REFERENCES plano_contas(id)         ON DELETE SET NULL,
  valor          numeric     NOT NULL,
  descricao      text,
  criado_em      timestamptz DEFAULT now()
);

ALTER TABLE rascunho_rateio_itens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_total" ON rascunho_rateio_itens FOR ALL USING (true) WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
