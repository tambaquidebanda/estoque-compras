-- ============================================================
-- SQL_PARCELAS_BOLETO.sql
-- Guarda em quantas vezes o pedido foi parcelado (boleto/cartao).
-- Padrao 1 = a vista. Pedido antigo nao muda de comportamento:
-- com parcelas = 1 o envio ao financeiro continua gerando 1 lancamento.
-- ============================================================

-- ------------------------------------------------------------
-- PASSO 1 - SO LEITURA: as colunas ja existem?
-- Esperado ANTES de rodar o PASSO 2: nenhuma linha.
-- ------------------------------------------------------------
SELECT table_name, column_name, data_type, column_default
  FROM information_schema.columns
 WHERE table_name IN ('cmp_compras', 'cmp_contas_pagar')
   AND column_name IN ('parcelas', 'parcela_intervalo')
 ORDER BY table_name, column_name;


-- ------------------------------------------------------------
-- PASSO 2 - CRIA AS COLUNAS (nao apaga nada, nao altera linha existente)
-- ------------------------------------------------------------
ALTER TABLE cmp_compras
  ADD COLUMN IF NOT EXISTS parcelas int NOT NULL DEFAULT 1;

ALTER TABLE cmp_contas_pagar
  ADD COLUMN IF NOT EXISTS parcelas int NOT NULL DEFAULT 1;

-- Como as parcelas se espacam: 'mensal' (mesmo dia do mes) ou numero de dias.
ALTER TABLE cmp_contas_pagar
  ADD COLUMN IF NOT EXISTS parcela_intervalo text NOT NULL DEFAULT 'mensal';


-- ------------------------------------------------------------
-- PASSO 3 - CONFERE
-- Esperado: 3 linhas no primeiro SELECT (parcelas em cmp_compras,
-- parcelas e parcela_intervalo em cmp_contas_pagar), todas com default.
-- No segundo: todo o historico com 1 parcela.
-- ------------------------------------------------------------
SELECT table_name, column_name, data_type, column_default
  FROM information_schema.columns
 WHERE table_name IN ('cmp_compras', 'cmp_contas_pagar')
   AND column_name IN ('parcelas', 'parcela_intervalo')
 ORDER BY table_name, column_name;

SELECT parcelas, count(*) AS linhas
  FROM cmp_compras
 GROUP BY parcelas
 ORDER BY parcelas;
