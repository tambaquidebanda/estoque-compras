-- =====================================================================
-- SQL_ZERA_FANTASMA_PRODUCAO_LOJA.sql  (23/11/2026)
--
-- Resíduo de agosto/setembro no ESTOQUE_LOJA (Teatro): 25 matérias-primas da
-- PRODUÇÃO que foram recebidas no sistema como Estoque da Loja enquanto o
-- Estoque Central ainda não existia como local (até 29/09/2026). Fisicamente
-- iam para a Produção e eram usadas lá; no ESTOQUE_LOJA nunca houve saída
-- nem contagem, então o saldo só subiu. Desde outubro esses produtos são
-- recebidos no CENTRAL, que conta toda semana — o resíduo parou de crescer.
--
-- Critério da lista (conferido em 23/11):
--   saldo > 0 no ESTOQUE_LOJA, sem contagem/ajuste no ESTOQUE_LOJA de 24/10
--   a 23/11, última entrada no ESTOQUE_LOJA até 30/09, e todos os pedidos de
--   ago-set desse produto eram da Produção (nenhum do Estoque Loja).
--   Utensílio (MU FORMA REDONDA) ficou de fora: forma não é consumida.
-- Total: R$ 175.100,97 pelo custo do cadastro.
--
-- Este SQL zera só a linha do ESTOQUE_LOJA desses 25 produtos e grava o acerto
-- no razão (est_movimentacoes, tipo ajuste, quantidade = -saldo atual).
-- Não mexe no CENTRAL, nos setores nem em nenhum outro produto.
--
-- Rode UM PASSO DE CADA VEZ. Se der "ASSERT failed", nada foi gravado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Esperado: 25 linhas, todas com confere = true,
-- e soma do valor ≈ R$ 175.100,97.
-- ---------------------------------------------------------------------
WITH alvo(produto_id, saldo_esperado, nome) AS (VALUES
    ('e611a8be-2f94-4fb0-af69-3d891c97286d'::uuid, 768, 'MP TAMBAQUI DESCAMADO'),   -- R$ 49.152,00
    ('a004f322-f7dc-49c8-abb5-ff8c2bf45ac9'::uuid, 937.95, 'MP PIRARUCU FRESCO'),   -- R$ 32.828,25
    ('3feca21b-9fc6-40e0-9ac0-9e1c68dd7a9f'::uuid, 1046, 'MP FRANGO INTEIRO'),   -- R$ 25.104,00
    ('1ca161cb-0c30-48b4-a426-d98040c9b236'::uuid, 233, 'MP CAMARÃO FRESCO S/CABEÇA M'),   -- R$ 15.354,70
    ('f8dba607-28b7-4acc-8279-693780a8ac8d'::uuid, 488, 'MP BATATA CONGELADA'),   -- R$ 8.161,31
    ('d7136ffa-e5a6-4958-82da-043f7021b052'::uuid, 320, 'MP FILE DE PEITO DE FRANGO'),   -- R$ 6.928,00
    ('9a4c60cd-4395-4a81-9cb1-cd1132240c1a'::uuid, 69, 'MP CAMARÃO SECO G'),   -- R$ 5.382,00
    ('f34c6c55-11e5-4c63-8798-0c0c35f4f941'::uuid, 123.4, 'MP PIRARUCU SECO'),   -- R$ 4.936,00
    ('5a7cf940-32f8-4f6c-9b23-2b118ec118de'::uuid, 98.7334, 'MP QUEIJO COALHO'),   -- R$ 4.836,16
    ('154b715e-3617-43ea-ae97-b3af764227ed'::uuid, 60.987, 'MP FILÉ MIGNON INTEIRO'),   -- R$ 4.207,49
    ('6409e43c-7e0f-4a82-8ac2-346fd35e4be9'::uuid, 342, 'MP MASSA DE PASTEL 500GR'),   -- R$ 3.505,50
    ('5096dffc-220b-4c7a-9751-a850ca00a01f'::uuid, 612, 'MP SARDINHA'),   -- R$ 3.060,00
    ('a00cb779-b7c6-454c-a9fb-163bbc8f3313'::uuid, 280, 'MP PICADINHO DE TAMBAQUI'),   -- R$ 2.800,00
    ('072ba393-91f7-4062-bb05-46eab619f001'::uuid, 225, 'MP MACAXEIRA'),   -- R$ 2.475,00
    ('8d7c94de-3d11-4ac5-9b83-a811b492f003'::uuid, 24, 'MP CAMARÃO SECO M'),   -- R$ 1.440,00
    ('30363278-6f88-4895-9b02-aa987b078478'::uuid, 36, 'MP COCO SECO'),   -- R$ 1.440,00
    ('b6cf56c4-f6bd-4a8e-bca1-b120d7641c96'::uuid, 6, 'MP CASTANHA TRITURADA'),   -- R$ 660,00
    ('b8321e68-2b19-4f46-a72e-60bf99ce8798'::uuid, 46, 'MP GALINHA CAIPIRA'),   -- R$ 575,00
    ('07a9aa08-5b32-4564-804c-93c0b4a11027'::uuid, 37, 'MP VERDURAS CONGELADAS'),   -- R$ 521,37
    ('09a28466-4dcc-41b5-8808-50c86fd2532b'::uuid, 35.444, 'MP FARINHA DE ROSCA'),   -- R$ 495,86
    ('11f2b5fc-7f25-46e4-b6b0-19bf5648088f'::uuid, 60, 'MP JARAQUI'),   -- R$ 360,00
    ('7dc65585-5f70-4c19-bb24-6c8e29bf3c97'::uuid, 5.582, 'MP QUEIJO MUSSARELA BARRA'),   -- R$ 348,82
    ('6bfde5f1-0098-4d21-9aa0-2ed2153779e7'::uuid, 55.343, 'MP PAO FRANCES PRODUÇÃO'),   -- R$ 276,16
    ('a74fedf9-59ca-42b2-b6c0-986186c11cea'::uuid, 15, 'MP FRANGO A PASSARINHO'),   -- R$ 179,85
    ('0d660e99-fd1d-4639-9d54-e1f77bc7e12e'::uuid, 3, 'MP QUEIJO PARMESAO TIPO 1')   -- R$ 73,50
)
SELECT a.nome, p.nome AS nome_cadastro, s.saldo AS saldo_atual, a.saldo_esperado,
       (p.nome = a.nome AND abs(s.saldo - a.saldo_esperado) < 0.001) AS confere,
       round((s.saldo * p.custo_comp / coalesce(nullif(p.fator_conversao,0),1)
              / nullif(1 - coalesce(p.perda,0)/100.0, 0))::numeric, 2) AS valor
  FROM alvo a
  LEFT JOIN est_produtos   p ON p.id = a.produto_id
  LEFT JOIN est_saldo_local s ON s.produto_id = a.produto_id AND s.local = 'ESTOQUE_LOJA'
 ORDER BY valor DESC NULLS LAST;


-- ---------------------------------------------------------------------
-- PASSO 2 - ZERA O RESÍDUO (25 produtos, só no ESTOQUE_LOJA).
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  c_mot constant text := 'Ajuste SQL 23/11: zera resíduo da Produção recebido no Estoque da Loja em ago-set (antes do Estoque Central existir)';
  v_n int;
BEGIN
  CREATE TEMP TABLE _alvo(produto_id uuid PRIMARY KEY, saldo_esperado float8, nome text) ON COMMIT DROP;
  INSERT INTO _alvo VALUES
    ('e611a8be-2f94-4fb0-af69-3d891c97286d'::uuid, 768, 'MP TAMBAQUI DESCAMADO'),   -- R$ 49.152,00
    ('a004f322-f7dc-49c8-abb5-ff8c2bf45ac9'::uuid, 937.95, 'MP PIRARUCU FRESCO'),   -- R$ 32.828,25
    ('3feca21b-9fc6-40e0-9ac0-9e1c68dd7a9f'::uuid, 1046, 'MP FRANGO INTEIRO'),   -- R$ 25.104,00
    ('1ca161cb-0c30-48b4-a426-d98040c9b236'::uuid, 233, 'MP CAMARÃO FRESCO S/CABEÇA M'),   -- R$ 15.354,70
    ('f8dba607-28b7-4acc-8279-693780a8ac8d'::uuid, 488, 'MP BATATA CONGELADA'),   -- R$ 8.161,31
    ('d7136ffa-e5a6-4958-82da-043f7021b052'::uuid, 320, 'MP FILE DE PEITO DE FRANGO'),   -- R$ 6.928,00
    ('9a4c60cd-4395-4a81-9cb1-cd1132240c1a'::uuid, 69, 'MP CAMARÃO SECO G'),   -- R$ 5.382,00
    ('f34c6c55-11e5-4c63-8798-0c0c35f4f941'::uuid, 123.4, 'MP PIRARUCU SECO'),   -- R$ 4.936,00
    ('5a7cf940-32f8-4f6c-9b23-2b118ec118de'::uuid, 98.7334, 'MP QUEIJO COALHO'),   -- R$ 4.836,16
    ('154b715e-3617-43ea-ae97-b3af764227ed'::uuid, 60.987, 'MP FILÉ MIGNON INTEIRO'),   -- R$ 4.207,49
    ('6409e43c-7e0f-4a82-8ac2-346fd35e4be9'::uuid, 342, 'MP MASSA DE PASTEL 500GR'),   -- R$ 3.505,50
    ('5096dffc-220b-4c7a-9751-a850ca00a01f'::uuid, 612, 'MP SARDINHA'),   -- R$ 3.060,00
    ('a00cb779-b7c6-454c-a9fb-163bbc8f3313'::uuid, 280, 'MP PICADINHO DE TAMBAQUI'),   -- R$ 2.800,00
    ('072ba393-91f7-4062-bb05-46eab619f001'::uuid, 225, 'MP MACAXEIRA'),   -- R$ 2.475,00
    ('8d7c94de-3d11-4ac5-9b83-a811b492f003'::uuid, 24, 'MP CAMARÃO SECO M'),   -- R$ 1.440,00
    ('30363278-6f88-4895-9b02-aa987b078478'::uuid, 36, 'MP COCO SECO'),   -- R$ 1.440,00
    ('b6cf56c4-f6bd-4a8e-bca1-b120d7641c96'::uuid, 6, 'MP CASTANHA TRITURADA'),   -- R$ 660,00
    ('b8321e68-2b19-4f46-a72e-60bf99ce8798'::uuid, 46, 'MP GALINHA CAIPIRA'),   -- R$ 575,00
    ('07a9aa08-5b32-4564-804c-93c0b4a11027'::uuid, 37, 'MP VERDURAS CONGELADAS'),   -- R$ 521,37
    ('09a28466-4dcc-41b5-8808-50c86fd2532b'::uuid, 35.444, 'MP FARINHA DE ROSCA'),   -- R$ 495,86
    ('11f2b5fc-7f25-46e4-b6b0-19bf5648088f'::uuid, 60, 'MP JARAQUI'),   -- R$ 360,00
    ('7dc65585-5f70-4c19-bb24-6c8e29bf3c97'::uuid, 5.582, 'MP QUEIJO MUSSARELA BARRA'),   -- R$ 348,82
    ('6bfde5f1-0098-4d21-9aa0-2ed2153779e7'::uuid, 55.343, 'MP PAO FRANCES PRODUÇÃO'),   -- R$ 276,16
    ('a74fedf9-59ca-42b2-b6c0-986186c11cea'::uuid, 15, 'MP FRANGO A PASSARINHO'),   -- R$ 179,85
    ('0d660e99-fd1d-4639-9d54-e1f77bc7e12e'::uuid, 3, 'MP QUEIJO PARMESAO TIPO 1');   -- R$ 73,50

  ASSERT (SELECT count(*) FROM _alvo) = 25, 'lista não tem 25 produtos distintos';
  ASSERT NOT EXISTS (SELECT 1 FROM _alvo a LEFT JOIN est_produtos p ON p.id = a.produto_id
                      WHERE p.id IS NULL OR p.nome <> a.nome),
         'algum produto não confere com o cadastro (nome mudou?) - nada foi gravado';
  ASSERT NOT EXISTS (SELECT 1 FROM _alvo a LEFT JOIN est_saldo_local s
                        ON s.produto_id = a.produto_id AND s.local = 'ESTOQUE_LOJA'
                      WHERE s.id IS NULL OR abs(s.saldo - a.saldo_esperado) >= 0.001),
         'algum saldo do ESTOQUE_LOJA mudou desde 23/11 - rode o PASSO 1 e veja qual; nada foi gravado';
  ASSERT NOT EXISTS (SELECT 1 FROM est_movimentacoes WHERE motivo = c_mot),
         'este acerto já foi gravado';

  INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
  SELECT s.produto_id, 'ESTOQUE_LOJA', 'ajuste', -s.saldo, c_mot, 'ajuste_manual', 'Ajuste SQL 23/11', '2026-11-23'
    FROM est_saldo_local s JOIN _alvo a ON a.produto_id = s.produto_id
   WHERE s.local = 'ESTOQUE_LOJA';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 25, format('esperava 25 lançamentos no razão, gravou %s', v_n);

  UPDATE est_saldo_local s SET saldo = 0, updated_at = now()
    FROM _alvo a
   WHERE s.produto_id = a.produto_id AND s.local = 'ESTOQUE_LOJA';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 25, format('esperava 25 linhas de saldo, atualizou %s', v_n);

  ASSERT NOT EXISTS (SELECT 1 FROM est_saldo_local s JOIN _alvo a ON a.produto_id = s.produto_id
                      WHERE s.local = 'ESTOQUE_LOJA' AND s.saldo <> 0), 'sobrou saldo';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - SÓ LEITURA. Esperado: 25 produtos com saldo 0 no ESTOQUE_LOJA
-- e 25 lançamentos de ajuste no razão com o motivo deste acerto
-- (soma_qtd ≈ -5927,439, que é a soma dos 25 saldos zerados).
-- ---------------------------------------------------------------------
SELECT count(*) FILTER (WHERE s.saldo = 0) AS zerados,
       count(*)                            AS linhas
  FROM est_saldo_local s
 WHERE s.local = 'ESTOQUE_LOJA'
   AND s.produto_id IN (SELECT produto_id FROM est_movimentacoes
                         WHERE motivo LIKE 'Ajuste SQL 23/11: zera resíduo da Produção%');

SELECT count(*) AS lancamentos, round(sum(quantidade)::numeric, 3) AS soma_qtd
  FROM est_movimentacoes
 WHERE motivo LIKE 'Ajuste SQL 23/11: zera resíduo da Produção%';
