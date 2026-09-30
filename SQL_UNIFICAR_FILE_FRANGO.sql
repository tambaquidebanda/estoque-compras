-- ============================================================================
-- UNIFICAR "SA FILE DE FRANGO 100g" (30/09/2026)
--
-- Havia 2 cadastros com o MESMO nome:
--   FICA : 1f1ff3de-2bfd-4b41-a9ea-31893a7babaa  (codigo 2634, desde 01/06,
--          ingrediente das fichas FRANGO A PARMEGIANA e FRANGO A PARMEGIANA - TDB)
--   SAI  : 4bf0f28d-afd6-48b1-af1e-50e173b03b51  (criado em 09/07, nao e ingrediente de ficha nenhuma)
--
-- A tela escolhe o produto pelo nome, entao cada linha da lista caia num cadastro
-- diferente. Hoje isso ja errou: o saldo inicial do Estoque Central (30) entrou no
-- SAI e a transferencia PED-3003 tirou os 30 do FICA -> Central com -30 e +30.
--
-- O que este SQL faz (tudo numa transacao so):
--   1. backup em tabelas bkp_unif_frango_* (com RLS)
--   2. confere que o saldo ainda e o de 30/09 16h; se mudou, PARA sem mexer
--   3. saldo: soma os dois cadastros em cada lugar
--        CENTRAL  30 + (-30) = 0
--        ESTOQUE_LOJA  10 + 30 = 40
--        COZINHA  4 + 4 = 8  -> ajuste de -4 (o 4 do FICA e da contagem de 29/09;
--                 a contagem de 30/09 ja contou as duas linhas no SAI = 4)
--   4. historico (razao, contagens, pedidos, inventario valorado) passa para o FICA
--   5. apaga a ficha tecnica do SAI (copia da do FICA) e o cadastro SAI
--   6. lista das telas: tira a linha repetida (Centro e P10 Cozinha, Producao,
--      Estoque Central). O pedido padrao (10) continua o mesmo.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PASSO 1 (so leitura) - estado atual
-- ---------------------------------------------------------------------------
SELECT p.nome, p.id, s.local, s.saldo
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('1f1ff3de-2bfd-4b41-a9ea-31893a7babaa','4bf0f28d-afd6-48b1-af1e-50e173b03b51')
 ORDER BY s.local, p.id;

-- ---------------------------------------------------------------------------
-- PASSO 2 - unificacao
-- ---------------------------------------------------------------------------
BEGIN;

-- 2a) backup
CREATE TABLE bkp_unif_frango_prod  AS SELECT * FROM est_produtos      WHERE id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_saldo AS SELECT * FROM est_saldo_local   WHERE produto_id IN ('1f1ff3de-2bfd-4b41-a9ea-31893a7babaa','4bf0f28d-afd6-48b1-af1e-50e173b03b51');
CREATE TABLE bkp_unif_frango_mov   AS SELECT id FROM est_movimentacoes WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_inv   AS SELECT id FROM est_inventario_itens WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_ped   AS SELECT id FROM pedidos_internos_itens WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_val   AS SELECT id FROM est_inventario_valorado_itens WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_sombra AS SELECT * FROM pdv_pedido_sombra WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_ficha AS SELECT * FROM est_fichas_tecnicas WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_ingr  AS SELECT i.* FROM est_ficha_ingredientes i
  JOIN est_fichas_tecnicas f ON f.id = i.ficha_id WHERE f.produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
CREATE TABLE bkp_unif_frango_estrutura AS SELECT * FROM inv_configuracoes WHERE chave = 'estrutura';
ALTER TABLE bkp_unif_frango_prod      ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_saldo     ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_mov       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_inv       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_ped       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_val       ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_sombra    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_ficha     ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_ingr      ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_unif_frango_estrutura ENABLE ROW LEVEL SECURITY;

-- 2b) trava: o estado tem que ser o de 30/09 16h
DO $$
DECLARE esperado text := 'CENTRAL:-30|COZINHA:4|ESTOQUE_LOJA:30#CENTRAL:30|COZINHA:4|ESTOQUE_LOJA:10';
        atual text;
BEGIN
  SELECT (SELECT string_agg(local || ':' || saldo::numeric::text, '|' ORDER BY local) FROM est_saldo_local
           WHERE produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa')
      || '#' ||
         (SELECT string_agg(local || ':' || saldo::numeric::text, '|' ORDER BY local) FROM est_saldo_local
           WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51')
    INTO atual;
  atual := regexp_replace(atual, '\.0+(\||#|$)', '\1', 'g');
  IF atual IS DISTINCT FROM esperado THEN
    RAISE EXCEPTION 'Saldo mudou desde a analise. Esperado % / atual %', esperado, atual;
  END IF;
  IF EXISTS (SELECT 1 FROM cmp_compras WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51')
  OR EXISTS (SELECT 1 FROM cmp_recebimento_itens WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51')
  OR EXISTS (SELECT 1 FROM est_ficha_ingredientes WHERE ingrediente_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51') THEN
    RAISE EXCEPTION 'O cadastro que sai ganhou compra/recebimento/ficha depois da analise';
  END IF;
  IF (SELECT valor #>> '{Centro,COZINHA,CONGELADOS,32}' FROM inv_configuracoes WHERE chave='estrutura') IS DISTINCT FROM 'SA FILE DE FRANGO 100G'
  OR (SELECT valor #>> '{Delivery P10,COZINHA,CONGELADOS,32}' FROM inv_configuracoes WHERE chave='estrutura') IS DISTINCT FROM 'SA FILE DE FRANGO 100G'
  OR (SELECT valor #>> ARRAY[U&'Produ\00e7\00e3o','PRODUCAO','SA CONGELADOS','28'] FROM inv_configuracoes WHERE chave='estrutura') IS DISTINCT FROM 'SA FILE DE FRANGO 100g'
  OR (SELECT valor #>> '{Estoque Central,ESTOQUE CENTRAL,SA CONGELADOS,28}' FROM inv_configuracoes WHERE chave='estrutura') IS DISTINCT FROM 'SA FILE DE FRANGO 100g' THEN
    RAISE EXCEPTION 'A lista das telas mudou desde a analise (posicao da linha repetida)';
  END IF;
END $$;

-- 2c) saldo: soma os dois cadastros em cada lugar
UPDATE est_saldo_local a
   SET saldo = a.saldo + b.saldo, updated_at = now()
  FROM est_saldo_local b
 WHERE a.produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa'
   AND b.produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51'
   AND a.local = b.local;
DELETE FROM est_saldo_local WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';

-- 2d) historico passa para o cadastro que fica
UPDATE est_movimentacoes             SET produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa' WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
UPDATE est_inventario_itens          SET produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa' WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
UPDATE pedidos_internos_itens        SET produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa' WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
UPDATE est_inventario_valorado_itens SET produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa' WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
DELETE FROM pdv_pedido_sombra WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';   -- o robo refaz so com o que fica

-- 2e) Cozinha: tira o 4 antigo (contagem de 29/09) que ficou no cadastro que fica
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
VALUES ('1f1ff3de-2bfd-4b41-a9ea-31893a7babaa', 'COZINHA', 'ajuste', -4,
        'Unificacao do cadastro repetido SA FILE DE FRANGO 100g: a contagem de 30/09 ja contou as duas linhas (4)',
        'unificacao_frango', 'correcao 30/09', DATE '2026-09-30');
UPDATE est_saldo_local SET saldo = saldo - 4, updated_at = now()
 WHERE produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa' AND local = 'COZINHA';

-- 2f) ficha tecnica e cadastro repetidos
DELETE FROM est_ficha_ingredientes WHERE ficha_id IN
  (SELECT id FROM est_fichas_tecnicas WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51');
DELETE FROM est_fichas_tecnicas WHERE produto_id = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';
DELETE FROM est_produtos        WHERE id         = '4bf0f28d-afd6-48b1-af1e-50e173b03b51';

-- 2g) lista das telas: tira so a linha repetida (cirurgico, nada mais muda)
UPDATE inv_configuracoes
   SET valor = valor
       #- '{Centro,COZINHA,CONGELADOS,32}'
       #- '{Delivery P10,COZINHA,CONGELADOS,32}'
       #- ARRAY[U&'Produ\00e7\00e3o','PRODUCAO','SA CONGELADOS','28']
       #- '{Estoque Central,ESTOQUE CENTRAL,SA CONGELADOS,28}'
 WHERE chave = 'estrutura';

-- 2h) conferencia dentro da transacao
DO $$
DECLARE atual text; n int;
BEGIN
  SELECT string_agg(local || ':' || saldo::numeric::text, '|' ORDER BY local) INTO atual
    FROM est_saldo_local WHERE produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa';
  atual := regexp_replace(atual, '\.0+(\||$)', '\1', 'g');
  IF atual IS DISTINCT FROM 'CENTRAL:0|COZINHA:4|ESTOQUE_LOJA:40' THEN
    RAISE EXCEPTION 'Saldo final inesperado: %', atual;
  END IF;
  SELECT count(*) INTO n FROM est_produtos WHERE nome ILIKE 'SA FILE DE FRANGO 100%';
  IF n <> 1 THEN RAISE EXCEPTION 'Ainda ha % cadastros com o nome', n; END IF;
  SELECT count(*) INTO n
    FROM inv_configuracoes c,
         jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
         jsonb_array_elements_text(g.value) nome
   WHERE c.chave = 'estrutura' AND upper(nome) = 'SA FILE DE FRANGO 100G';
  IF n <> 5 THEN RAISE EXCEPTION 'Esperava 5 linhas na lista (1 por tela), achei %', n; END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- PASSO 3 (so leitura) - conferencia
-- ---------------------------------------------------------------------------
SELECT local, saldo FROM est_saldo_local
 WHERE produto_id = '1f1ff3de-2bfd-4b41-a9ea-31893a7babaa' ORDER BY local;
