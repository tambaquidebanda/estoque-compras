-- =====================================================================
-- SQL_PRODUCAO_OCORRENCIAS.sql   (08/10/2026)
--
-- Ocorrencias da Producao (pedido do Wagner, 08/10/2026): quando a meta do dia
-- nao e batida, ou a MP que sobrou na contagem do fim do dia nao bate com o que
-- o sistema esperava, a Producao diz o MOTIVO no tablet. Fica o historico para
-- Compras em Producao > Ocorrencias.
--
--   prod_ocorrencias  - uma linha por divergencia
--       tipo 'meta' : SA que ficou abaixo da meta (meta, feito)
--       tipo 'mp'   : MP contada no fim do dia diferente do sistema (esperado, contado)
--       tipo 'rendimento' : limpeza fora do rendimento da ficha (usado = MP que
--                     usou, esperado = limpo pela ficha, contado = limpo na balanca)
--   prod_fechamentos  - um "Fechar o dia" por dia e unidade
--
-- So cria tabelas novas. Nada existente e alterado ou apagado.
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: zero linhas (as tabelas ainda nao existem).
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public' AND table_name IN ('prod_ocorrencias', 'prod_fechamentos');


-- PASSO 2 - CRIA. Idempotente: rodar de novo nao apaga nada.
BEGIN;

CREATE TABLE IF NOT EXISTS prod_ocorrencias (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data          date NOT NULL,
  unidade       text NOT NULL REFERENCES prod_unidades(unidade),
  tipo          text NOT NULL,
  produto_id    uuid NOT NULL,
  meta_item_id  uuid,
  meta          numeric,
  usado         numeric,
  feito         numeric,
  esperado      numeric,
  contado       numeric,
  diferenca     numeric,
  motivo        text NOT NULL,
  obs           text,
  responsavel   text,
  criado_em     timestamptz NOT NULL DEFAULT now()
);
-- (se a tabela ja existia de uma versao anterior deste arquivo)
ALTER TABLE prod_ocorrencias ADD COLUMN IF NOT EXISTS usado numeric;
ALTER TABLE prod_ocorrencias DROP CONSTRAINT IF EXISTS prod_ocorrencias_tipo_check;
ALTER TABLE prod_ocorrencias ADD CONSTRAINT prod_ocorrencias_tipo_check CHECK (tipo IN ('meta', 'mp', 'rendimento'));
CREATE INDEX IF NOT EXISTS prod_ocorrencias_data ON prod_ocorrencias (data);
CREATE INDEX IF NOT EXISTS prod_ocorrencias_item ON prod_ocorrencias (meta_item_id) WHERE meta_item_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS prod_fechamentos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data         date NOT NULL,
  unidade      text NOT NULL REFERENCES prod_unidades(unidade),
  responsavel  text,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (data, unidade)
);

ALTER TABLE prod_ocorrencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_fechamentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS prod_ocorrencias_logado ON prod_ocorrencias;
CREATE POLICY prod_ocorrencias_logado ON prod_ocorrencias FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS prod_fechamentos_logado ON prod_fechamentos;
CREATE POLICY prod_fechamentos_logado ON prod_fechamentos FOR ALL TO authenticated USING (true) WITH CHECK (true);

COMMIT;


-- PASSO 3 - CONFERENCIA (so leitura). Esperado: 2 linhas, as duas com rls = true.
SELECT c.relname AS tabela, c.relrowsecurity AS rls
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relname IN ('prod_ocorrencias', 'prod_fechamentos');
