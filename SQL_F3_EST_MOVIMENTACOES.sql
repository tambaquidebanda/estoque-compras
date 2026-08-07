-- ============================================================================
-- F3 — LIVRO-RAZÃO DE ESTOQUE (est_movimentacoes)
-- ----------------------------------------------------------------------------
-- Tabela append-only (nunca UPDATE/DELETE em produção) que registra TODO
-- movimento de estoque com sinal (+ entrada, − saída). O snapshot rápido
-- est_saldo_local continua existindo (leitura da tela de Saldo); o ledger é a
-- FONTE DE VERDADE auditável. Um ponto único de escrita (movimentar/registrarContagem)
-- grava aqui E atualiza o snapshot.
--
-- Serve: D3 (Perdas), D4 (Devoluções), D8 (Produtos sem giro), D10 (Acuracidade
-- de inventário) e a baixa automática do Pensêra.
--
-- Rodar UMA vez no SQL Editor do Supabase. Depois rodar o backfill (arquivo à parte).
-- ============================================================================

-- 1) Tabela ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS est_movimentacoes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produto_id   uuid NOT NULL REFERENCES est_produtos(id),
  local        text NOT NULL,                 -- ESTOQUE_LOJA, ESTOQUE_CENTRAL, setor, etc.
  tipo         text NOT NULL,                 -- ver CHECK abaixo
  quantidade   numeric NOT NULL,              -- COM SINAL: entrada + / saída −
  custo_unit   numeric,                       -- custo unitário na unidade de uso (decisão: gravar)
  valor_total  numeric GENERATED ALWAYS AS (quantidade * COALESCE(custo_unit, 0)) STORED,
  unidade_id   uuid,                           -- unidade de uso (opcional; sem FK p/ evitar acoplar)
  motivo       text,                           -- razão livre (perda/ajuste): "quebra", "vencido"...
  origem       text,                           -- subsistema que escreveu: recebimento, contagem...
  ref_tabela   text,                           -- tabela de origem (rastreio): cmp_recebimentos...
  ref_id       uuid,                           -- id da linha de origem (rastreio + idempotência)
  responsavel  text,
  data         date NOT NULL DEFAULT CURRENT_DATE,   -- data do negócio (não do INSERT)
  criado_em    timestamptz NOT NULL DEFAULT now()
);

-- 2) Tipos permitidos (mantém o ledger limpo; ajustar aqui se surgir novo fluxo)
ALTER TABLE est_movimentacoes DROP CONSTRAINT IF EXISTS est_mov_tipo_chk;
ALTER TABLE est_movimentacoes ADD CONSTRAINT est_mov_tipo_chk CHECK (tipo IN (
  'saldo_inicial',              -- semente do backfill (abertura)
  'recebimento',               -- + entrada por compra recebida
  'transferencia_saida',       -- − saída de um local
  'transferencia_entrada',     -- + entrada em outro local
  'pedido_interno_saida',      -- − saída do estoque para o setor
  'pedido_interno_entrada',    -- + entrada no setor
  'perda',                     -- − quebra/vencimento/descarte (D3)
  'devolucao',                 -- − devolução ao fornecedor (D4)
  'producao_consumo',          -- − insumo consumido na produção (ficha técnica)
  'producao_entrada',          -- + produto acabado/semi entra no estoque
  'venda_pensera',             -- − baixa automática por venda (integração Pensêra)
  'contagem',                  -- ± ajuste do inventário (delta = contado − esperado)
  'ajuste'                     -- ± correção manual
));

-- 3) Índices de leitura ------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_est_mov_prod_local ON est_movimentacoes (produto_id, local);
CREATE INDEX IF NOT EXISTS ix_est_mov_data       ON est_movimentacoes (data);
CREATE INDEX IF NOT EXISTS ix_est_mov_tipo       ON est_movimentacoes (tipo);
CREATE INDEX IF NOT EXISTS ix_est_mov_local_data ON est_movimentacoes (local, data);

-- 4) Idempotência: mesma linha de origem não gera movimento duplicado.
--    (transferência gera 2 movimentos do MESMO ref_id → por isso local+tipo entram na chave.
--     Movimentos sem ref_id — ajuste manual — não são restringidos: múltiplos NULL são OK.)
CREATE UNIQUE INDEX IF NOT EXISTS uq_est_mov_ref
  ON est_movimentacoes (ref_tabela, ref_id, local, tipo)
  WHERE ref_id IS NOT NULL;

-- 5) RLS: manter o mesmo padrão das demais tabelas do projeto (acesso via anon/service).
--    Se as outras tabelas est_* estiverem sem RLS, deixar sem. Se tiverem policy aberta,
--    replicar. (Confirmar no painel antes de habilitar para não travar o app.)

-- Verificação:
SELECT count(*) AS linhas FROM est_movimentacoes;
