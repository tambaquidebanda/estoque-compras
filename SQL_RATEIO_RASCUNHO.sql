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
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='rascunho_rateio_itens' AND policyname='acesso_total') THEN
    CREATE POLICY "acesso_total" ON rascunho_rateio_itens FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

-- Adiciona plano_conta_id (FK) em cmp_categorias para lookup direto por ID
ALTER TABLE cmp_categorias
  ADD COLUMN IF NOT EXISTS plano_conta_id uuid REFERENCES plano_contas(id) ON DELETE SET NULL;

-- Migra plano_conta_id nas categorias que já têm o nome do plano configurado
UPDATE cmp_categorias c
SET plano_conta_id = pc.id
FROM plano_contas pc
WHERE LOWER(TRIM(c.plano_conta)) = LOWER(TRIM(pc.nome))
  AND c.plano_conta_id IS NULL;

NOTIFY pgrst, 'reload schema';
