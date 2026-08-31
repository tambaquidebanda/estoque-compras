-- ============================================================================
-- SQL_PREPARO_DIA.sql
--
-- Cria a tabela pdv_preparo_dia: quanto o modelo diz que a COZINHA PRODUZIU de
-- cada preparo por dia.
--
-- POR QUE ISTO EXISTE
-- O robo da baixa explode a ficha do prato ate o insumo folha. O preparo do
-- meio do caminho - o caldinho, a farofa, o xarope - so existe dentro da
-- recursao e some sem deixar rastro. So que ele e o melhor detector de ficha
-- errada que temos: a pergunta que ele levanta e "a cozinha faz 60 litros de
-- caldinho por dia?", e essa qualquer pessoa responde em dois segundos.
--
-- E, o que importa mais: NAO DEPENDE DE CONTAGEM. So venda x ficha. Funciona
-- exatamente onde a contagem esta ruim, que e o nosso maior problema hoje.
--
-- Foi assim que caiu o CALDINHO DE TAMBAQUI em 28/08/2026: 60,3 L/dia, 12 lotes
-- de 5 litros. A causa era CALDINHO - CORTESIA consumindo 1,0 de um preparo
-- medido em LITRO; o certo era 0,1. Um preparo corrigido mexe em todos os
-- ingredientes dele de uma vez - aquele carregava nove.
--
-- NAO E BAIXA. Nenhuma linha desta tabela mexe em saldo nem no livro-razao.
-- E medicao, e so isso. O robo grava nos tres modos, dry inclusive.
--
-- O robo ja esta preparado: se esta tabela nao existir, ele avisa e segue a
-- baixa normalmente. Medicao nao pode derrubar operacao.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. A tabela ja existe?
-- ============================================================================
SELECT table_name,
       (SELECT count(*) FROM information_schema.columns c
         WHERE c.table_name = t.table_name) AS colunas
FROM information_schema.tables t
WHERE t.table_schema = 'public'
  AND t.table_name = 'pdv_preparo_dia';
-- zero linha = ainda nao existe, siga para o PASSO 2.


-- ============================================================================
-- PASSO 2 - CRIA. Idempotente: rodar de novo nao quebra nem apaga dado.
-- ============================================================================
CREATE TABLE IF NOT EXISTS pdv_preparo_dia (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  data        date        NOT NULL,
  produto_id  uuid        NOT NULL,
  nome        text,                   -- nome do preparo na hora da medicao
  quantidade  numeric     NOT NULL,   -- na unidade de uso do preparo
  unidade     text,                   -- LT, KG, UN...
  rendimento  numeric,                -- quanto rende 1 lote, pela ficha
  lotes       numeric,                -- quantidade / rendimento
  modo        text,                   -- dry | razao | apply (quem gravou)
  criado_em   timestamptz NOT NULL DEFAULT now()
);

-- um preparo por dia: o robo apaga o dia e regrava, entao rodar de novo
-- substitui em vez de acumular.
CREATE UNIQUE INDEX IF NOT EXISTS pdv_preparo_dia_dia_produto
  ON pdv_preparo_dia (data, produto_id);

CREATE INDEX IF NOT EXISTS pdv_preparo_dia_data
  ON pdv_preparo_dia (data);

-- RLS no mesmo padrao das outras tabelas dos dois sistemas.
ALTER TABLE pdv_preparo_dia ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pdv_preparo_dia_all ON pdv_preparo_dia;
CREATE POLICY pdv_preparo_dia_all ON pdv_preparo_dia
  FOR ALL USING (true) WITH CHECK (true);


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Deve listar as 10 colunas.
-- ============================================================================
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'pdv_preparo_dia'
ORDER BY ordinal_position;


-- ============================================================================
-- PASSO 4 - depois de o robo rodar pelo menos uma vez, esta e a pergunta:
--           "a cozinha produz isso por dia?"
-- ============================================================================
-- SELECT nome,
--        unidade,
--        round(avg(quantidade), 2) AS por_dia,
--        round(avg(lotes), 2)      AS lotes_por_dia,
--        count(*)                  AS dias
-- FROM pdv_preparo_dia
-- WHERE data >= CURRENT_DATE - 21
-- GROUP BY nome, unidade
-- ORDER BY avg(lotes) DESC;
