-- =====================================================================
-- SQL_FIX_UNIDADE_LANC_P10.sql  (22/10/2026)
--
-- 6 lancamentos do financeiro de pedidos 100% do Delivery P10 que foram
-- criados com a unidade "Tambaqui de Banda Teatro". Total R$ 2.627,02.
--   #01293 318,92 | #01299 179,00 | #01376 512,14
--   #01428 480,00 | #01729 656,96 | #01806 480,00
--
-- Muda SO a coluna unidade_id. Nao mexe em valor, status, pagamento,
-- banco, plano de contas nem na conciliacao (ofx_id fica igual).
-- Nenhum dos 6 tem rateio.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA. Deve mostrar 6 linhas, todas com unidade
-- "Tambaqui de Banda Teatro", status pago e tem_rateio false.
-- ---------------------------------------------------------------------
SELECT l.numero_pedido, l.valor, l.status, l.data_pagamento,
       l.tem_rateio, u.nome AS unidade_atual
FROM lancamentos l
LEFT JOIN unidades u ON u.id = l.unidade_id
WHERE l.id IN (
  '550f4eea-2807-4d8d-a3d1-8f999e9501cd',  -- #01293
  '18cf0d9d-785d-4c44-9be5-76a2864a1d8a',  -- #01299
  'ec3a92ba-7332-45a4-b0fe-99bd2c0b7735',  -- #01376
  '526838b2-34be-46e3-9379-3fcbfd52b670',  -- #01428
  '38c4b864-ab9c-47f5-a306-dc7668b5e872',  -- #01729
  'e63157dd-125d-4db6-982a-70acf554f06b'   -- #01806
)
ORDER BY l.numero_pedido;


-- ---------------------------------------------------------------------
-- PASSO 2 - TROCA A UNIDADE para Delivery P10.
-- So mexe em quem ainda esta no Teatro e sem rateio. Se rodar de novo,
-- nao faz nada. Deve responder "UPDATE 6".
-- ---------------------------------------------------------------------
UPDATE lancamentos
SET unidade_id = '6696a0dc-71f9-4a98-bdb4-42d9dd989cb1'        -- Delivery P10
WHERE id IN (
  '550f4eea-2807-4d8d-a3d1-8f999e9501cd',
  '18cf0d9d-785d-4c44-9be5-76a2864a1d8a',
  'ec3a92ba-7332-45a4-b0fe-99bd2c0b7735',
  '526838b2-34be-46e3-9379-3fcbfd52b670',
  '38c4b864-ab9c-47f5-a306-dc7668b5e872',
  'e63157dd-125d-4db6-982a-70acf554f06b'
)
  AND unidade_id = 'e031eced-0652-4af0-ad2a-13b65a29f814'      -- Tambaqui de Banda Teatro
  AND tem_rateio IS NOT TRUE;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA. Deve mostrar 6 linhas com unidade
-- "Delivery P10", soma 2627.02, status e data_pagamento iguais ao PASSO 1.
-- ---------------------------------------------------------------------
SELECT l.numero_pedido, l.valor, l.status, l.data_pagamento,
       (l.ofx_id IS NOT NULL) AS conciliado, u.nome AS unidade
FROM lancamentos l
LEFT JOIN unidades u ON u.id = l.unidade_id
WHERE l.id IN (
  '550f4eea-2807-4d8d-a3d1-8f999e9501cd',
  '18cf0d9d-785d-4c44-9be5-76a2864a1d8a',
  'ec3a92ba-7332-45a4-b0fe-99bd2c0b7735',
  '526838b2-34be-46e3-9379-3fcbfd52b670',
  '38c4b864-ab9c-47f5-a306-dc7668b5e872',
  'e63157dd-125d-4db6-982a-70acf554f06b'
)
ORDER BY l.numero_pedido;

SELECT u.nome AS unidade, count(*) AS lancamentos, sum(l.valor) AS soma
FROM lancamentos l
LEFT JOIN unidades u ON u.id = l.unidade_id
WHERE l.id IN (
  '550f4eea-2807-4d8d-a3d1-8f999e9501cd',
  '18cf0d9d-785d-4c44-9be5-76a2864a1d8a',
  'ec3a92ba-7332-45a4-b0fe-99bd2c0b7735',
  '526838b2-34be-46e3-9379-3fcbfd52b670',
  '38c4b864-ab9c-47f5-a306-dc7668b5e872',
  'e63157dd-125d-4db6-982a-70acf554f06b'
)
GROUP BY u.nome;
