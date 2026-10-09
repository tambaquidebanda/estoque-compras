-- =====================================================================
-- SQL_PRODUCAO_VENDA_ORIGEM.sql   (08/10/2026)
--
-- De quais pratos veio o consumo de cada SA (pedido do Wagner, 08/10): na Meta
-- de Producao, passar o mouse no nome da SA mostra os pratos vendidos no periodo
-- e quanto de SA cada um consumiu.
--
--   prod_venda_sa_origem - uma linha por dia + unidade + SA + prato vendido
--       qtd_vendida : quantos pratos foram vendidos
--       qtd_sa      : quanto da SA esses pratos consumiram (pela ficha)
--
-- Gravada pelo mesmo robo da prod_venda_sa_dia (scripts/venda_sa_dia.py).
-- So cria tabela nova. Nada existente e alterado ou apagado.
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: zero linhas (a tabela ainda nao existe).
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public' AND table_name = 'prod_venda_sa_origem';


-- PASSO 2 - CRIA. Idempotente: rodar de novo nao apaga nada.
BEGIN;

CREATE TABLE IF NOT EXISTS prod_venda_sa_origem (
  data         date    NOT NULL,
  unidade      text    NOT NULL REFERENCES prod_unidades(unidade),
  sa_id        uuid    NOT NULL,
  prato_id     uuid    NOT NULL,
  prato_nome   text,
  qtd_vendida  numeric NOT NULL DEFAULT 0,
  qtd_sa       numeric NOT NULL DEFAULT 0,
  PRIMARY KEY (data, unidade, sa_id, prato_id)
);
CREATE INDEX IF NOT EXISTS prod_venda_sa_origem_data ON prod_venda_sa_origem (data);

ALTER TABLE prod_venda_sa_origem ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS prod_venda_sa_origem_ler ON prod_venda_sa_origem;
CREATE POLICY prod_venda_sa_origem_ler ON prod_venda_sa_origem FOR SELECT TO authenticated USING (true);

COMMIT;


-- PASSO 3 - CONFERENCIA (so leitura). Esperado: 1 linha, rls = true.
SELECT c.relname AS tabela, c.relrowsecurity AS rls
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relname = 'prod_venda_sa_origem';


-- DEPOIS DO PASSO 3: no GitHub, Actions > "Venda de SA por dia" > Run workflow
-- com dias = 40, para guardar os pratos das ultimas semanas.
