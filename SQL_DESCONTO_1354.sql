-- ============================================================
-- SQL_DESCONTO_1354.sql
-- Pedido #01354 - o fornecedor deu 5% de desconto na nota e o
-- recebimento foi gravado com o preco CHEIO. Diferenca: R$ 166,76
-- (3.335,35 gravado x 3.168,59 do boleto).
--
-- Este script baixa 5% do custo unitario dos 15 itens em todos os
-- lugares em que o preco cheio ficou gravado:
--   cmp_compras.custo_unit          (o pedido)
--   cmp_recebimento_itens           (valor_unitario e total_recebido)
--   cmp_recebimentos.total_recebido (o total do recebimento)
--   est_movimentacoes.custo_unit    (o livro-razao do estoque)
--   est_produtos.custo_comp         (o ultimo preco de compra)
--
-- O centavo de arredondamento (R$ 0.47) foi colocado na FRIGIDEIRA
-- N50, que tem quantidade 1 - assim todo preco fica com 2 casas e a
-- soma bate exata em 3.168,59.
--
-- NAO mexe em saldo: a quantidade recebida esta certa, so o preco
-- estava. Nenhum dos 15 itens entra em ficha tecnica (conferido),
-- entao custo de prato nao muda.
--
-- Rodar junto com SQL_PARCELAS_1354.sql, que acerta a conta a pagar
-- e as 3 parcelas do boleto.
-- ============================================================

-- ------------------------------------------------------------
-- PASSO 1 - SO LEITURA: como esta hoje
-- Esperado: soma dos itens 3335.35 e total_recebido 3335.35.
-- ------------------------------------------------------------
SELECT 'pedido' AS onde, round(sum(quantidade * custo_unit), 2) AS soma
  FROM cmp_compras WHERE pedido_num = '#01354';

SELECT 'recebimento' AS onde, total_recebido
  FROM cmp_recebimentos WHERE pedido_num = '#01354';

SELECT 'razao' AS onde, round(sum(quantidade * custo_unit), 2) AS soma
  FROM est_movimentacoes
 WHERE id IN ('432d2fdd-c488-425b-be5b-0ab2e9419ba9', '3e7227e0-a48d-4b43-a3d1-d228408d79b8', '002ebc3b-8432-44be-b55d-988c37892c1b', '959a03c0-378e-407e-8091-96e77781d8ab', 'b42c3dd9-2011-4aa3-8dba-aef2b1a61e50', '172ffeaa-e1f3-4faf-9360-86ecb698702c', '603a4e67-1520-4837-83f1-306476922484', '82255e32-37db-4108-b6ac-5c9e44e47f4e', '936a1795-030f-4f52-a7f0-53c7c210cd39', '181bf011-64d8-47d9-ac5d-5b1a6b787d27', '6852fb56-692c-4399-b97d-4b79eb00c770', 'fac8b23c-73dd-46e4-9d62-ae7735fcd04e', 'affd1191-b76d-474e-8ade-32f146020471', 'ed2f166d-7fa8-4671-a50c-a0b956d9d0b0', '3a3264ff-22aa-4ad5-8e8a-82287d3c0609');


-- ------------------------------------------------------------
-- PASSO 2 - BACKUP do que vai mudar
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bkp_desconto_1354_compras AS
  SELECT * FROM cmp_compras WHERE pedido_num = '#01354';

CREATE TABLE IF NOT EXISTS bkp_desconto_1354_receb AS
  SELECT * FROM cmp_recebimento_itens
   WHERE recebimento_id = '672725fb-cc49-4c15-905a-a92e31ec8725';

CREATE TABLE IF NOT EXISTS bkp_desconto_1354_mov AS
  SELECT * FROM est_movimentacoes
   WHERE id IN ('432d2fdd-c488-425b-be5b-0ab2e9419ba9', '3e7227e0-a48d-4b43-a3d1-d228408d79b8', '002ebc3b-8432-44be-b55d-988c37892c1b', '959a03c0-378e-407e-8091-96e77781d8ab', 'b42c3dd9-2011-4aa3-8dba-aef2b1a61e50', '172ffeaa-e1f3-4faf-9360-86ecb698702c', '603a4e67-1520-4837-83f1-306476922484', '82255e32-37db-4108-b6ac-5c9e44e47f4e', '936a1795-030f-4f52-a7f0-53c7c210cd39', '181bf011-64d8-47d9-ac5d-5b1a6b787d27', '6852fb56-692c-4399-b97d-4b79eb00c770', 'fac8b23c-73dd-46e4-9d62-ae7735fcd04e', 'affd1191-b76d-474e-8ade-32f146020471', 'ed2f166d-7fa8-4671-a50c-a0b956d9d0b0', '3a3264ff-22aa-4ad5-8e8a-82287d3c0609');

CREATE TABLE IF NOT EXISTS bkp_desconto_1354_produtos AS
  SELECT id, nome, custo_comp FROM est_produtos
   WHERE id IN ('fafd36f9-e077-42e7-9a7f-132c6f0fc9fb', 'e683ce6a-86b8-42ec-a36d-92104cfaa705', '0a72d5d4-23cd-47d9-9933-526ef0b6ee65', 'cf80d118-f1cb-4cca-9e78-128f078124e3', '38346710-804d-491d-9304-90d3a7db074e', '16bf1373-c2e0-4075-8883-868495e42758', 'c0c4f840-5650-4ea8-8ac6-6e73417132f9', '63cdb3cd-fc88-4117-bc99-e20e2bd0d450', 'ac7dd98d-4e0d-4ca7-b5e6-00a180321f59', '443d3b2f-27e4-4ac9-bb11-3b2343ca7ceb', 'b12d613f-4c16-46ca-b635-9acffd433e78', 'bc564044-0c89-49ca-9f82-c50bace9f8b4', '579f2de4-70e3-4232-97bf-ce2c8e670ce8', 'd15d59e3-8eab-4f3a-a3e5-259351296fc5', '6830f8c9-50ea-4224-a2b9-e20f23e2cd9d');

SELECT (SELECT count(*) FROM bkp_desconto_1354_compras)  AS compras,
       (SELECT count(*) FROM bkp_desconto_1354_receb)    AS receb_itens,
       (SELECT count(*) FROM bkp_desconto_1354_mov)      AS movimentacoes,
       (SELECT count(*) FROM bkp_desconto_1354_produtos) AS produtos;
-- Esperado: 15, 15, 15, 15


-- ------------------------------------------------------------
-- PASSO 3 - novo custo unitario (preco cheio menos 5%)
--
--   PRODUTO                                  QTD    ANTES   DEPOIS    TOTAL
--   MU CANECA VIDRO CHOPP 340ML BISTROL        24    19.99    18.99   455.76
--   MU COLHER DE MESA                          50     7.99     7.59   379.50
--   MU GARFO MESA INOX                         50     7.99     7.59   379.50
--   MC COPO VIDRO L. DRINK 345ML AMERICANO     84     4.49     4.27   358.68
--   MU CONCHA TERRINA INOX                     10    34.99    33.24   332.40
--   MU COPO AMERICANO ROCKS 300ML              48     5.49     5.22   250.56
--   MU FRIGIDEIRA LINHA HOTEL N35               2   127.99   121.59   243.18
--   MU BANDEJA RED ARIENZO                      4    59.99    56.99   227.96
--   MU FRIGIDEIRA LINHA HOTEL N50               1   216.99   205.67   205.67
--   MU COPO AMERICANO 180ML (CALDINHO)         72     1.99     1.89   136.08
--   MU TACA VIDRO AGUA 490ML BARONE             6    14.99    14.24    85.44
--   MU COLHER SERVIR INOX                      10     3.99     3.79    37.90
--   MU TIGELA BOWL 16CM                         1    29.99    28.49    28.49
--   MU POTE PLAST RED 3,2L                      2    14.99    14.24    28.48
--   MU PINCEL SILICONE 28CM                     1    19.99    18.99    18.99
--   TOTAL                                                           3168.59
-- ------------------------------------------------------------
UPDATE cmp_compras c
   SET custo_unit = v.novo
  FROM (VALUES
    ('40c5589e-eb6e-4123-b212-134eae49f363'::uuid, 18.99),
    ('877c72d2-a07f-4d60-aaed-b1651bc1489f'::uuid, 7.59),
    ('b6558fc0-40bb-47cf-9c2c-5212e47e5536'::uuid, 7.59),
    ('d5abc61a-3f37-43b5-9bcd-c257ae18b18a'::uuid, 4.27),
    ('9ea22009-4408-4d2b-b230-ade9465aa28f'::uuid, 33.24),
    ('27d7eed6-6d66-4f6c-9de1-37b0826ca14c'::uuid, 5.22),
    ('598d4265-c225-463e-bf35-6c5dda90c35d'::uuid, 121.59),
    ('e359e2e5-ebc2-421e-8c11-ccfc2c6b9fde'::uuid, 56.99),
    ('35006edf-037d-44a5-acc2-82a49df8bdb2'::uuid, 205.67),
    ('4324b120-c401-4426-b463-b90cfc91a0cc'::uuid, 1.89),
    ('b1c0dd9e-771a-4f6a-bea2-65f7899d6897'::uuid, 14.24),
    ('d1762dc6-a23a-4245-bf11-630f81c3eafc'::uuid, 3.79),
    ('71961681-7211-4f7e-b192-29e24378e695'::uuid, 28.49),
    ('ec0bdd05-3bd7-4ad6-8c23-87794c904a6b'::uuid, 14.24),
    ('93877a33-7720-469c-8b49-b9e73b0327e1'::uuid, 18.99)
  ) AS v(id, novo)
 WHERE c.id = v.id;

UPDATE cmp_recebimento_itens r
   SET valor_unitario = v.novo,
       total_recebido = v.total
  FROM (VALUES
    ('078b3dae-8749-432c-ad2a-89d11d1786f3'::uuid, 18.99, 455.76),
    ('ccc13666-76e2-4747-87d3-e010b79a8849'::uuid, 7.59, 379.50),
    ('1fac6d67-7fe5-425f-b9e5-e2d0af17e77f'::uuid, 7.59, 379.50),
    ('69afc934-f9f4-4e43-882e-d0a3a210d671'::uuid, 4.27, 358.68),
    ('3a294a01-c72a-4494-81e2-89e2af0fee49'::uuid, 33.24, 332.40),
    ('476de19f-a5de-4822-a3e2-665febd5058c'::uuid, 5.22, 250.56),
    ('97ee7e9d-c940-44d7-a3da-cf60dacc6c33'::uuid, 121.59, 243.18),
    ('b73d8cef-581b-472a-98f3-5dd301a4dbd3'::uuid, 56.99, 227.96),
    ('ff270b19-2674-4d37-b016-7da44466096a'::uuid, 205.67, 205.67),
    ('9255e266-9b95-47e9-8ef8-8caaf60a35c5'::uuid, 1.89, 136.08),
    ('22d8dc15-a3fa-445f-8d59-c42f1148237c'::uuid, 14.24, 85.44),
    ('fe8799fe-0db5-4f7c-9c15-6260179e306c'::uuid, 3.79, 37.90),
    ('e2288136-064c-4646-a3dd-1d4201bb2309'::uuid, 28.49, 28.49),
    ('6973de2e-2206-4051-afcd-10ca564ebe3c'::uuid, 14.24, 28.48),
    ('a9a5f923-2d68-4867-a1d1-706a6b81237e'::uuid, 18.99, 18.99)
  ) AS v(id, novo, total)
 WHERE r.id = v.id;

UPDATE est_movimentacoes m
   SET custo_unit = v.novo
  FROM (VALUES
    ('432d2fdd-c488-425b-be5b-0ab2e9419ba9'::uuid, 18.99),
    ('3e7227e0-a48d-4b43-a3d1-d228408d79b8'::uuid, 7.59),
    ('002ebc3b-8432-44be-b55d-988c37892c1b'::uuid, 7.59),
    ('959a03c0-378e-407e-8091-96e77781d8ab'::uuid, 4.27),
    ('b42c3dd9-2011-4aa3-8dba-aef2b1a61e50'::uuid, 33.24),
    ('172ffeaa-e1f3-4faf-9360-86ecb698702c'::uuid, 5.22),
    ('603a4e67-1520-4837-83f1-306476922484'::uuid, 121.59),
    ('82255e32-37db-4108-b6ac-5c9e44e47f4e'::uuid, 56.99),
    ('936a1795-030f-4f52-a7f0-53c7c210cd39'::uuid, 205.67),
    ('181bf011-64d8-47d9-ac5d-5b1a6b787d27'::uuid, 1.89),
    ('6852fb56-692c-4399-b97d-4b79eb00c770'::uuid, 14.24),
    ('fac8b23c-73dd-46e4-9d62-ae7735fcd04e'::uuid, 3.79),
    ('affd1191-b76d-474e-8ade-32f146020471'::uuid, 28.49),
    ('ed2f166d-7fa8-4671-a50c-a0b956d9d0b0'::uuid, 14.24),
    ('3a3264ff-22aa-4ad5-8e8a-82287d3c0609'::uuid, 18.99)
  ) AS v(id, novo)
 WHERE m.id = v.id;

UPDATE est_produtos p
   SET custo_comp = v.novo
  FROM (VALUES
    ('fafd36f9-e077-42e7-9a7f-132c6f0fc9fb'::uuid, 18.99),
    ('e683ce6a-86b8-42ec-a36d-92104cfaa705'::uuid, 7.59),
    ('0a72d5d4-23cd-47d9-9933-526ef0b6ee65'::uuid, 7.59),
    ('cf80d118-f1cb-4cca-9e78-128f078124e3'::uuid, 4.27),
    ('38346710-804d-491d-9304-90d3a7db074e'::uuid, 33.24),
    ('16bf1373-c2e0-4075-8883-868495e42758'::uuid, 5.22),
    ('c0c4f840-5650-4ea8-8ac6-6e73417132f9'::uuid, 121.59),
    ('63cdb3cd-fc88-4117-bc99-e20e2bd0d450'::uuid, 56.99),
    ('ac7dd98d-4e0d-4ca7-b5e6-00a180321f59'::uuid, 205.67),
    ('443d3b2f-27e4-4ac9-bb11-3b2343ca7ceb'::uuid, 1.89),
    ('b12d613f-4c16-46ca-b635-9acffd433e78'::uuid, 14.24),
    ('bc564044-0c89-49ca-9f82-c50bace9f8b4'::uuid, 3.79),
    ('579f2de4-70e3-4232-97bf-ce2c8e670ce8'::uuid, 28.49),
    ('d15d59e3-8eab-4f3a-a3e5-259351296fc5'::uuid, 14.24),
    ('6830f8c9-50ea-4224-a2b9-e20f23e2cd9d'::uuid, 18.99)
  ) AS v(id, novo)
 WHERE p.id = v.id;

UPDATE cmp_recebimentos
   SET total_recebido = 3168.59
 WHERE pedido_num = '#01354';


-- ------------------------------------------------------------
-- PASSO 4 - CONFERE
-- Esperado: as tres somas em 3168.59 e nenhum item fora.
-- ------------------------------------------------------------
SELECT 'pedido' AS onde, round(sum(quantidade * custo_unit), 2) AS soma
  FROM cmp_compras WHERE pedido_num = '#01354'
UNION ALL
SELECT 'recebimento_itens', round(sum(total_recebido), 2)
  FROM cmp_recebimento_itens
 WHERE recebimento_id = '672725fb-cc49-4c15-905a-a92e31ec8725'
UNION ALL
SELECT 'recebimento_total', total_recebido
  FROM cmp_recebimentos WHERE pedido_num = '#01354'
UNION ALL
SELECT 'razao', round(sum(quantidade * custo_unit), 2)
  FROM est_movimentacoes
 WHERE id IN ('432d2fdd-c488-425b-be5b-0ab2e9419ba9', '3e7227e0-a48d-4b43-a3d1-d228408d79b8', '002ebc3b-8432-44be-b55d-988c37892c1b', '959a03c0-378e-407e-8091-96e77781d8ab', 'b42c3dd9-2011-4aa3-8dba-aef2b1a61e50', '172ffeaa-e1f3-4faf-9360-86ecb698702c', '603a4e67-1520-4837-83f1-306476922484', '82255e32-37db-4108-b6ac-5c9e44e47f4e', '936a1795-030f-4f52-a7f0-53c7c210cd39', '181bf011-64d8-47d9-ac5d-5b1a6b787d27', '6852fb56-692c-4399-b97d-4b79eb00c770', 'fac8b23c-73dd-46e4-9d62-ae7735fcd04e', 'affd1191-b76d-474e-8ade-32f146020471', 'ed2f166d-7fa8-4671-a50c-a0b956d9d0b0', '3a3264ff-22aa-4ad5-8e8a-82287d3c0609');

-- O saldo NAO deve ter mudado (quantidade nunca foi tocada)
SELECT p.nome, s.saldo, p.custo_comp
  FROM est_saldo_local s
  JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('fafd36f9-e077-42e7-9a7f-132c6f0fc9fb', 'e683ce6a-86b8-42ec-a36d-92104cfaa705', '0a72d5d4-23cd-47d9-9933-526ef0b6ee65', 'cf80d118-f1cb-4cca-9e78-128f078124e3', '38346710-804d-491d-9304-90d3a7db074e', '16bf1373-c2e0-4075-8883-868495e42758', 'c0c4f840-5650-4ea8-8ac6-6e73417132f9', '63cdb3cd-fc88-4117-bc99-e20e2bd0d450', 'ac7dd98d-4e0d-4ca7-b5e6-00a180321f59', '443d3b2f-27e4-4ac9-bb11-3b2343ca7ceb', 'b12d613f-4c16-46ca-b635-9acffd433e78', 'bc564044-0c89-49ca-9f82-c50bace9f8b4', '579f2de4-70e3-4232-97bf-ce2c8e670ce8', 'd15d59e3-8eab-4f3a-a3e5-259351296fc5', '6830f8c9-50ea-4224-a2b9-e20f23e2cd9d')
   AND s.local = 'ESTOQUE_LOJA'
 ORDER BY p.nome;
