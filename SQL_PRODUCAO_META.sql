-- =====================================================================
-- SQL_PRODUCAO_META.sql   (06/10/2026)
--
-- Base da META DE PRODUCAO (telas aprovadas pelo Wagner em 06/10/2026).
-- So cria tabelas novas e uma configuracao. NAO altera nenhuma tabela que ja
-- existe e NAO mexe em saldo, pedido ou financeiro.
--
--   prod_unidades       de onde sai a MP, onde a Producao guarda, para onde vai a
--                       SA pronta e quais estoques contam no "Tem", por unidade.
--                       E configuracao: trocar o destino do P10 para o Central
--                       depois e mudar uma linha aqui, sem reprogramar.
--   prod_venda_sa_dia   quanto de cada SA a venda consumiu por dia e por unidade
--                       (gravado pelo robo scripts/venda_sa_dia.py, de madrugada).
--   prod_metas          a meta da semana de cada unidade (rascunho / aprovada).
--   prod_meta_itens     uma linha por SA da meta.
--   prod_registros      limpeza (com rendimento real) e producao feitas no tablet.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA. Nenhuma das 5 tabelas deve existir ainda.
-- Esperado: zero linhas.
-- =====================================================================
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'public'
   AND table_name IN ('prod_unidades','prod_venda_sa_dia','prod_metas','prod_meta_itens','prod_registros');


-- =====================================================================
-- PASSO 2 - CRIA. Idempotente: rodar de novo nao apaga nada.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS prod_unidades (
  unidade         text PRIMARY KEY,         -- 'Centro' | 'Delivery P10'
  rotulo          text NOT NULL,            -- como aparece na tela
  unidade_pdv     text NOT NULL,            -- nome da loja no iComanda
  local_mp        text NOT NULL,            -- de onde a MP vem para a Producao
  local_producao  text NOT NULL,            -- saldo da Producao desta unidade
  local_destino   text NOT NULL,            -- para onde a SA pronta vai
  locais_tem      text[] NOT NULL,          -- estoques somados no "Tem" da meta
  ordem           int NOT NULL DEFAULT 0
);

INSERT INTO prod_unidades (unidade, rotulo, unidade_pdv, local_mp, local_producao, local_destino, locais_tem, ordem)
VALUES
  ('Centro',       'Centro',    'Tambaqui de Banda Loja Centro', 'CENTRAL',          'PRODUCAO',     'CENTRAL',
     ARRAY['ESTOQUE_LOJA','CENTRAL','PRODUCAO'], 1),
  ('Delivery P10', 'Parque 10', 'Tdb - Parque 10',               'ESTOQUE DELIVERY', 'PRODUCAO P10', 'ESTOQUE DELIVERY',
     ARRAY['ESTOQUE DELIVERY','PRODUCAO P10'], 2)
ON CONFLICT (unidade) DO NOTHING;

CREATE TABLE IF NOT EXISTS prod_venda_sa_dia (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data        date    NOT NULL,
  unidade     text    NOT NULL,             -- prod_unidades.unidade
  produto_id  uuid    NOT NULL,             -- a SA
  quantidade  numeric NOT NULL,             -- unidade de uso da SA
  criado_em   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prod_venda_sa_dia_uq ON prod_venda_sa_dia (data, unidade, produto_id);
CREATE INDEX IF NOT EXISTS prod_venda_sa_dia_data ON prod_venda_sa_dia (data);

CREATE TABLE IF NOT EXISTS prod_metas (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  unidade      text NOT NULL,
  semana_ini   date NOT NULL,               -- a sexta em que a producao comeca
  venda_ini    date NOT NULL,
  venda_fim    date NOT NULL,
  margem       numeric NOT NULL DEFAULT 0.25,
  status       text NOT NULL DEFAULT 'rascunho',   -- rascunho | aprovada
  criado_em    timestamptz NOT NULL DEFAULT now(),
  criado_por   text,
  aprovado_em  timestamptz,
  aprovado_por text
);
CREATE UNIQUE INDEX IF NOT EXISTS prod_metas_uq ON prod_metas (unidade, semana_ini);

CREATE TABLE IF NOT EXISTS prod_meta_itens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meta_id       uuid NOT NULL REFERENCES prod_metas(id) ON DELETE CASCADE,
  produto_id    uuid NOT NULL,
  vendeu        numeric NOT NULL DEFAULT 0,
  precisa       numeric NOT NULL DEFAULT 0,
  tem           numeric NOT NULL DEFAULT 0,
  meta          numeric NOT NULL DEFAULT 0,
  ajuste        numeric,
  meta_final    numeric NOT NULL DEFAULT 0,
  dia           date,
  dia_sugerido  date
);
CREATE UNIQUE INDEX IF NOT EXISTS prod_meta_itens_uq ON prod_meta_itens (meta_id, produto_id);

CREATE TABLE IF NOT EXISTS prod_registros (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  criado_em        timestamptz NOT NULL DEFAULT now(),
  data             date NOT NULL,
  unidade          text NOT NULL,
  tipo             text NOT NULL,           -- limpeza | producao
  produto_id       uuid NOT NULL,           -- o PPP (limpeza) ou a SA (producao)
  quantidade       numeric NOT NULL,        -- quanto saiu pronto
  mp_produto_id    uuid,                    -- limpeza: a MP usada
  mp_quantidade    numeric,                 -- limpeza: quanto de MP foi usado
  rendimento_ficha numeric,                 -- limpeza: o rendimento que a ficha diz
  meta_item_id     uuid,
  responsavel      text
);
CREATE INDEX IF NOT EXISTS prod_registros_data ON prod_registros (data, unidade);

-- RLS: quem esta logado le e grava; o robo usa a service key.
ALTER TABLE prod_unidades     ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_venda_sa_dia ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_metas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_meta_itens   ENABLE ROW LEVEL SECURITY;
ALTER TABLE prod_registros    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS prod_unidades_ler ON prod_unidades;
CREATE POLICY prod_unidades_ler ON prod_unidades FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS prod_venda_sa_dia_ler ON prod_venda_sa_dia;
CREATE POLICY prod_venda_sa_dia_ler ON prod_venda_sa_dia FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS prod_metas_logado ON prod_metas;
CREATE POLICY prod_metas_logado ON prod_metas FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS prod_meta_itens_logado ON prod_meta_itens;
CREATE POLICY prod_meta_itens_logado ON prod_meta_itens FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS prod_registros_logado ON prod_registros;
CREATE POLICY prod_registros_logado ON prod_registros FOR ALL TO authenticated USING (true) WITH CHECK (true);

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura)
-- Esperado: 5 tabelas; 2 linhas em prod_unidades (Centro e Delivery P10).
-- =====================================================================
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = 'public'
   AND table_name IN ('prod_unidades','prod_venda_sa_dia','prod_metas','prod_meta_itens','prod_registros')
 ORDER BY 1;

SELECT unidade, rotulo, local_mp, local_producao, local_destino, locais_tem FROM prod_unidades ORDER BY ordem;
