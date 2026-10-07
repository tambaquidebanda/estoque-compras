-- =====================================================================
-- SQL_PRODUCAO_FASE2.sql   (07/10/2026)
--
-- Liga o pedido de MP automatico a meta aprovada.
-- Acrescenta UMA coluna, opcional, em pedidos_internos: prod_meta_id.
-- Pedido antigo fica com ela vazia e continua igual. Nada e apagado.
--
-- Para que serve: ao aprovar a meta, o sistema cria o pedido de MP de cada dia
-- de producao (Producao pede ao Estoque Central / ao Estoque Delivery). Ao
-- reabrir a meta, ele precisa achar ESSES pedidos para cancelar os que ainda
-- nao sairam do estoque - e para nao reabrir se algum ja saiu.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: zero linhas (a coluna ainda nao existe).
SELECT column_name FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'pedidos_internos' AND column_name = 'prod_meta_id';


-- PASSO 2 - CRIA (idempotente)
BEGIN;
ALTER TABLE pedidos_internos ADD COLUMN IF NOT EXISTS prod_meta_id uuid;
CREATE INDEX IF NOT EXISTS pedidos_internos_prod_meta ON pedidos_internos (prod_meta_id) WHERE prod_meta_id IS NOT NULL;
COMMIT;


-- PASSO 3 - CONFERENCIA. Esperado: 1 linha, uuid, YES.
SELECT column_name, data_type, is_nullable FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'pedidos_internos' AND column_name = 'prod_meta_id';
