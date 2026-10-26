-- =====================================================================
-- PLANEJAMENTO DE COMPRAS (22/10/2026)
-- Cria prod_venda_item_dia: quanto de cada produto do cadastro a venda de
-- cada loja teve por dia (PDV mapeado x fator, SEM abrir a ficha). Quem grava
-- e o robo scripts/venda_sa_dia.py (o mesmo da Meta de Producao), de madrugada.
-- A tela Planejamento abre a ficha ate a MP na hora.
--
-- So cria tabela nova. Nao mexe em saldo, pedido, produto nem financeiro.
-- Rode um passo de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 (so leitura): a tabela ainda nao existe? Esperado: 0 linhas.
-- =====================================================================
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public' AND table_name = 'prod_venda_item_dia';


-- =====================================================================
-- PASSO 2: cria a tabela (pode rodar de novo sem problema)
-- =====================================================================
CREATE TABLE IF NOT EXISTS prod_venda_item_dia (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data        date    NOT NULL,
  unidade     text    NOT NULL,             -- prod_unidades.unidade
  produto_id  uuid    NOT NULL,             -- est_produtos.id (o que o PDV vendeu, ja mapeado)
  quantidade  numeric NOT NULL DEFAULT 0,   -- vendido x fator do mapa
  criado_em   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS prod_venda_item_dia_uq ON prod_venda_item_dia (data, unidade, produto_id);
CREATE INDEX IF NOT EXISTS prod_venda_item_dia_data ON prod_venda_item_dia (data);

ALTER TABLE prod_venda_item_dia ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS prod_venda_item_dia_ler ON prod_venda_item_dia;
CREATE POLICY prod_venda_item_dia_ler ON prod_venda_item_dia FOR SELECT TO authenticated USING (true);


-- =====================================================================
-- PASSO 3 (conferencia): a tabela existe e esta vazia. Esperado: 1 linha, 0.
-- Depois: GitHub > Actions > "Venda de SA por dia" > Run workflow, dias = 40.
-- =====================================================================
SELECT 'prod_venda_item_dia' AS tabela, count(*) AS linhas FROM prod_venda_item_dia;
