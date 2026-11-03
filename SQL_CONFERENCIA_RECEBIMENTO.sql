-- ═══════════════════════════════════════════════════════════════════════════
-- CONFERÊNCIA DO RECEBIMENTO SALVA ITEM A ITEM (03/11/2026)
--
-- #02004: a nota da Queiroz foi conferida na sexta 30/10 e nada ficou gravado — o
-- recebimento so vai ao banco no botao final; se a internet cai ali, a conferencia
-- some sem aviso e o pedido continua pendente. Na terca o Ricardo recebeu de novo.
--
-- Esta tabela guarda o item conferido (quantidade, preco, desconto, bonificado,
-- divergencia) NO MOMENTO em que quem recebe marca o ✓. Nao mexe em estoque nem em
-- financeiro: isso continua so no "Confirmar Recebimento". Desmarcar apaga a linha.
-- Ao confirmar, as linhas dos itens recebidos sao apagadas.
-- Uma linha por item do pedido (compra_id = cmp_compras.id).
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cmp_recebimento_conferencia (
  compra_id      uuid PRIMARY KEY,                  -- item do pedido (cmp_compras.id)
  pedido_num     text NOT NULL,
  qtd_recebida   numeric,
  valor_unitario numeric,                           -- preco digitado (antes do desconto)
  desconto       numeric NOT NULL DEFAULT 0,        -- R$ do item
  bonificado     boolean NOT NULL DEFAULT false,
  divergencia    boolean NOT NULL DEFAULT false,
  obs            text,
  conferido_por  text,
  conferido_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_cmp_receb_conf_pedido ON cmp_recebimento_conferencia (pedido_num);

-- Mesmo padrao de cmp_recebimentos / cmp_recebimento_itens (SQL_MIGRACAO_PEDIDOS.sql)
ALTER TABLE cmp_recebimento_conferencia ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'cmp_recebimento_conferencia' AND policyname = 'auth_only') THEN
    CREATE POLICY "auth_only" ON cmp_recebimento_conferencia FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;
GRANT ALL ON cmp_recebimento_conferencia TO authenticated;

-- Conferir: deve listar as 10 colunas
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'cmp_recebimento_conferencia' ORDER BY ordinal_position;
