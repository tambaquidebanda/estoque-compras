-- ============================================================================
-- D4 — DEVOLUÇÕES AO FORNECEDOR
-- ----------------------------------------------------------------------------
-- Registra a devolução de itens de um RECEBIMENTO ao fornecedor e acompanha a
-- SUBSTITUIÇÃO do produto (status pendente → substituido / cancelado).
-- SEM vínculo com o financeiro — a intenção é rastrear e cobrar a reposição.
--
-- A baixa de estoque NÃO é feita aqui: o app chama movimentar(tipo='devolucao')
-- e grava no livro-razão (est_movimentacoes). Estas tabelas são o DOCUMENTO.
--
-- Rodar UMA vez no SQL Editor do Supabase, ANTES de dar Push do app.
-- ============================================================================

-- 1) Cabeçalho do documento de devolução ------------------------------------
CREATE TABLE IF NOT EXISTS cmp_devolucoes (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fornecedor     text,                              -- nome (snapshot)
  fornecedor_id  uuid,                              -- link opcional p/ fornecedores
  recebimento_id uuid,                              -- recebimento de origem
  pedido_num     text,                              -- rastreio
  data           date NOT NULL DEFAULT CURRENT_DATE,
  motivo         text,                              -- avaria / vencido / qualidade...
  valor_total    numeric NOT NULL DEFAULT 0,        -- soma dos itens (base da cobrança)
  status         text NOT NULL DEFAULT 'pendente',  -- pendente | substituido | cancelado
  resolucao      text DEFAULT 'Substituição',       -- Substituição | Crédito | Reembolso
  data_resolucao date,
  nf_devolucao   text,
  responsavel    text,
  obs            text,
  criado_em      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cmp_devolucoes DROP CONSTRAINT IF EXISTS cmp_dev_status_chk;
ALTER TABLE cmp_devolucoes ADD CONSTRAINT cmp_dev_status_chk
  CHECK (status IN ('pendente','substituido','cancelado'));

-- 2) Itens devolvidos --------------------------------------------------------
CREATE TABLE IF NOT EXISTS cmp_devolucao_itens (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  devolucao_id        uuid NOT NULL REFERENCES cmp_devolucoes(id) ON DELETE CASCADE,
  produto_id          uuid,                          -- vínculo por código (F2)
  produto             text,                          -- nome (snapshot)
  local               text NOT NULL DEFAULT 'ESTOQUE_LOJA',  -- de onde sai o estoque
  unidade             text,
  quantidade          numeric NOT NULL,              -- positiva; o sinal (−) vai no razão
  valor_unitario      numeric,
  valor_total         numeric GENERATED ALWAYS AS (quantidade * COALESCE(valor_unitario,0)) STORED,
  recebimento_item_id uuid,                          -- item de origem (cmp_recebimento_itens)
  criado_em           timestamptz NOT NULL DEFAULT now()
);

-- 3) Índices -----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_cmp_dev_itens_dev ON cmp_devolucao_itens (devolucao_id);
CREATE INDEX IF NOT EXISTS ix_cmp_dev_forn      ON cmp_devolucoes (fornecedor);
CREATE INDEX IF NOT EXISTS ix_cmp_dev_status    ON cmp_devolucoes (status);
CREATE INDEX IF NOT EXISTS ix_cmp_dev_data      ON cmp_devolucoes (data);

-- Verificação:
SELECT count(*) AS devolucoes FROM cmp_devolucoes;
