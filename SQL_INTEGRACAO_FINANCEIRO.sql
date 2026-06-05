-- Integração Pedido de Compra → Financeiro (contas a pagar)
-- lancamento_id: referência ao registro gerado em lancamentos (financeiro)
--                quando preenchido = conta já foi enviada ao financeiro (bloqueia segunda geração)
-- nf_numero:     número da nota fiscal informado no momento da geração

ALTER TABLE cmp_contas_pagar
  ADD COLUMN IF NOT EXISTS lancamento_id uuid DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS nf_numero    text DEFAULT NULL;
