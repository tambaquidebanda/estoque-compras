-- Tabela de rascunhos de integração estoque → financeiro
-- Mesma estrutura de lancamentos, mas sem afetar dados reais.
-- Fluxo: Modo Teste envia aqui → financeiro mostra em "Integrações Pendentes" → admin aprova → vira lancamento real

CREATE TABLE IF NOT EXISTS lancamentos_rascunho (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Campos espelho de lancamentos
  descricao       text NOT NULL,
  valor           numeric NOT NULL,
  vencimento      date NOT NULL,
  tipo            text NOT NULL DEFAULT 'pagar',
  status          text NOT NULL DEFAULT 'pendente',
  fornecedor_id   uuid REFERENCES fornecedores(id) ON DELETE SET NULL,
  plano_conta_id  uuid REFERENCES plano_contas(id) ON DELETE SET NULL,
  numero_pedido   text,
  observacoes     text,
  acrescimo       numeric DEFAULT 0,
  desconto        numeric DEFAULT 0,
  -- Campos de rastreamento (origem no estoque)
  pedido_num      text,
  conta_id        uuid,   -- referência a cmp_contas_pagar
  criado_em       timestamptz DEFAULT now()
);

-- Permite leitura/escrita pelo anon (mesma política do resto do sistema)
ALTER TABLE lancamentos_rascunho ENABLE ROW LEVEL SECURITY;
CREATE POLICY "acesso_total_rascunho" ON lancamentos_rascunho FOR ALL USING (true) WITH CHECK (true);
