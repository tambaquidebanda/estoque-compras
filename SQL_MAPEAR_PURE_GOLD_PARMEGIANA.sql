-- =====================================================================
-- SQL_MAPEAR_PURE_GOLD_PARMEGIANA.sql   (23/10/2026)
--
-- 3 itens do iComanda vendiam sem estar na pdv_map, entao a venda deles nao
-- gerava consumo de nada (baixa, meta de producao, planejamento de compras).
-- Medido de 25/09 a 21/10:
--
--   3128 STELLA PURE GOLD 600            Centro 389 un (R$ 10,4 mil)
--   3134 MARMITA FRANGO A PARMEGIANA     P10     47 un
--   3144 MARMITA FRANGO A PARMEGIANA TDB Centro  23 un
--
-- Aprovado pelo Wagner em 23/10/2026.
-- - Pure Gold 600: igual as outras cervejas (ex.: STELLA ARTOIS GOLD LN), cria o
--   produto de VENDA "STELLA PURE GOLD 600" com ficha 1:1 na MP STELLA PURE GOLD
--   600ML e mapeia para ele. Preco de venda R$ 26,90 (o do PDV).
-- - As duas marmitas: mapeia para MARMITA FRANGO A PARMEGIANA (ja tem ficha).
--
-- Nao mexe em saldo, pedido nem financeiro. Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA.
-- (a) os 3 itens NAO devem estar na pdv_map                 -> 0 linhas
-- (b) o produto de venda da Pure Gold 600 ainda nao existe  -> 0 linhas
-- (c) MP e marmita existem, ativos; a marmita tem ficha     -> 2 linhas
-- =====================================================================
SELECT icomanda_produto_id, icomanda_nome, status
  FROM pdv_map WHERE icomanda_produto_id IN (3128, 3134, 3144);

SELECT id, nome, tipo FROM est_produtos
 WHERE nome = 'STELLA PURE GOLD 600'
    OR id = '03b09ee3-db33-4637-85e8-b4949c82d4ab';

SELECT p.id, p.nome, p.tipo, p.ativo,
       EXISTS (SELECT 1 FROM est_fichas_tecnicas f WHERE f.produto_id = p.id AND f.ativo) AS tem_ficha
  FROM est_produtos p
 WHERE p.id IN ('b7a77f3f-5f05-4c98-bb0a-4ae6a7155c2f',    -- MP STELLA PURE GOLD 600ML
                '2680e403-e06b-4ae8-b0d1-f2f344e48e93');   -- MARMITA FRANGO A PARMEGIANA


-- =====================================================================
-- PASSO 2 - CRIA E MAPEIA (tudo ou nada; para se algo ja existir)
-- =====================================================================
BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM pdv_map WHERE icomanda_produto_id IN (3128, 3134, 3144);
  IF n > 0 THEN RAISE EXCEPTION 'Ja existem % desses itens na pdv_map. Nada foi alterado.', n; END IF;
  SELECT count(*) INTO n FROM est_produtos WHERE nome = 'STELLA PURE GOLD 600';
  IF n > 0 THEN RAISE EXCEPTION 'Ja existe o produto STELLA PURE GOLD 600. Nada foi alterado.'; END IF;

  -- produto de venda (mesmo molde da STELLA ARTOIS GOLD LN)
  INSERT INTO est_produtos (id, nome, tipo, categoria, unidade_comp, unidade_uso,
                            custo_comp, preco_venda, fator_conversao, perda, ativo)
  VALUES ('03b09ee3-db33-4637-85e8-b4949c82d4ab', 'STELLA PURE GOLD 600', 'VENDA', 'CERVEJAS',
          'UN', 'UN', 7.6212, 26.90, 1, 0, true);

  -- ficha 1:1 na MP
  INSERT INTO est_fichas_tecnicas (id, produto_id, rendimento, unidade_rendimento,
                                   custo_total, custo_por_porcao, ativo)
  VALUES ('0b33fa86-4bba-4af3-9d4f-b283aa422ac6', '03b09ee3-db33-4637-85e8-b4949c82d4ab',
          1, 'UN', 7.6212, 7.6212, true);

  INSERT INTO est_ficha_ingredientes (id, ficha_id, ingrediente_id, quantidade, unidade, perda, fator_conversao)
  VALUES ('d96a7ccf-0e56-4e31-acbd-5283fa70a0e4', '0b33fa86-4bba-4af3-9d4f-b283aa422ac6',
          'b7a77f3f-5f05-4c98-bb0a-4ae6a7155c2f', 1, 'UN', 0, 1);

  -- mapeamento do PDV
  INSERT INTO pdv_map (icomanda_produto_id, icomanda_nome, produto_id, status, fator, obs, setor)
  VALUES
    (3128, 'STELLA PURE GOLD 600',            '03b09ee3-db33-4637-85e8-b4949c82d4ab', 'mapeado', 1,
     'Vendia sem mapa; produto de venda criado com ficha 1:1 na MP (23/10/2026)', 'BAR'),
    (3134, 'MARMITA FRANGO A PARMEGIANA',     '2680e403-e06b-4ae8-b0d1-f2f344e48e93', 'mapeado', 1,
     'Vendia sem mapa (P10) (23/10/2026)', 'COZINHA'),
    (3144, 'MARMITA FRANGO A PARMEGIANA TDB', '2680e403-e06b-4ae8-b0d1-f2f344e48e93', 'mapeado', 1,
     'Vendia sem mapa (delivery do Centro) (23/10/2026)', 'DELIVERY');
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 3 THEN RAISE EXCEPTION 'Inseriu % linhas na pdv_map (esperado 3).', n; END IF;
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura).
-- Esperado: 3 linhas, status mapeado, tem_ficha = true nas 3.
-- =====================================================================
SELECT m.icomanda_produto_id, m.icomanda_nome, m.status, m.fator, p.nome AS produto,
       EXISTS (SELECT 1 FROM est_fichas_tecnicas f WHERE f.produto_id = p.id AND f.ativo) AS tem_ficha
  FROM pdv_map m JOIN est_produtos p ON p.id = m.produto_id
 WHERE m.icomanda_produto_id IN (3128, 3134, 3144)
 ORDER BY 1;

-- DEPOIS: no GitHub, Actions > "Venda de SA por dia (meta da Producao)" >
-- Run workflow com dias = 40, para regravar a venda com esses itens.
