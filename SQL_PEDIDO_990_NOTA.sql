-- ============================================================
-- SQL_PEDIDO_990_NOTA.sql
-- Ajusta o pedido #00990 para bater com a FICHA DE PEDIDO 030/26 de
-- ALBERTA CARLA SANTOS DE AGUIAR, datada de 23/08/2026.
--
-- DEPOIS DE RODAR ISTO, RECEBA PELA TELA (nao por SQL):
--   Estoque > Recebimentos > #00990 > receber tudo, data 23/08/2026.
-- E a tela que credita o estoque, atualiza o ultimo preco de compra e gera a
-- conta a pagar / o rascunho no financeiro. Fazer isso por SQL na mao teria de
-- repetir tudo isso e sairia errado em algum ponto.
--
-- A NOTA (conferida item a item contra o cadastro - todos os precos ja batem):
--   Ceu de Brigadeiro                        8 x  13,00 = 104,00
--   Cheesecake de Chocolate com Cupuacu     12 x  13,00 = 156,00
--   Brownie                                 16 x   6,00 =  96,00
--   Petit Gateau                            26 x   7,00 = 182,00
--   Pudim de Leite                          41 x   5,50 = 225,50
--   VALOR TOTAL                                          763,50
--
-- POR QUE MUDAR A QUANTIDADE DO PEDIDO: hoje ela e 32/24/16/22/48 (sobra do
-- recebimento parcial que foi desfeito). Deixando o pedido igual a nota, o
-- recebimento entra 100%, sem divergencia e sem sobra para dispensar depois.
-- Se voce preferir manter o pedido original e receber parcial, PULE o PASSO 3
-- e receba digitando as quantidades da nota - a tela aceita, marca divergencia
-- e depois voce usa "Fechar Pedido" para dispensar o que nao veio.
--
-- O QUE TINHA DE ERRADO NO RECEBIMENTO ANTIGO: ele pegou certo o cheesecake
-- (12), o brownie (16) e o petit gateau (26) - o que faltou foi lancar o Ceu de
-- Brigadeiro (8) e o Pudim (41), e a data ficou 18/08 em vez de 23/08. Por isso
-- o financeiro recebeu 434,00 em vez de 763,50.
-- ============================================================


-- ============================================================
-- PASSO 1 - SO LEITURA. Estado atual do pedido.
-- ============================================================
SELECT produto, quantidade, custo_unit, status_receb,
       (quantidade * custo_unit) AS total_item
  FROM cmp_compras
 WHERE pedido_num = '#00990'
 ORDER BY produto;

SELECT SUM(quantidade * custo_unit) AS total_pedido_hoje
  FROM cmp_compras WHERE pedido_num = '#00990';
-- Esperado hoje: 5 itens 'pendente', total 1242.00


-- ============================================================
-- PASSO 2 - Backup.
-- ============================================================
DROP TABLE IF EXISTS bkp_990_nota;
CREATE TABLE bkp_990_nota AS SELECT * FROM cmp_compras WHERE pedido_num = '#00990';
SELECT count(*) AS linhas_no_backup FROM bkp_990_nota;   -- esperado: 5


-- ============================================================
-- PASSO 3 - Quantidades da nota. Os precos NAO mudam (ja conferem).
-- ============================================================
UPDATE cmp_compras c
   SET quantidade = v.qtd
  FROM (VALUES
    ('d9eb44b3-5f19-4ce8-baa4-74743efcebe1'::uuid,  8::numeric),  -- Ceu de Brigadeiro
    ('3e1d3253-98e5-4305-b3db-a64cfdbd069b'::uuid, 12::numeric),  -- Cheesecake c/ Cupuacu
    ('94c03c56-02f1-4588-aaf7-45cb44669414'::uuid, 16::numeric),  -- Brownie
    ('8e08669a-856a-4867-933d-cb6ff3f787d8'::uuid, 26::numeric),  -- Petit Gateau
    ('047f330e-d782-4976-9537-0877633fd8b7'::uuid, 41::numeric)   -- Pudim de Leite
  ) AS v(id, qtd)
 WHERE c.id = v.id;


-- ============================================================
-- PASSO 4 - Conferencia. Tem de fechar em 763.50, igual a nota.
-- ============================================================
SELECT produto, quantidade, custo_unit,
       (quantidade * custo_unit) AS total_item, status_receb
  FROM cmp_compras WHERE pedido_num = '#00990' ORDER BY produto;

SELECT SUM(quantidade * custo_unit) AS total_pedido,
       CASE WHEN SUM(quantidade * custo_unit) = 763.50
            THEN 'OK - bate com a nota'
            ELSE 'DIVERGENTE - conferir antes de receber' END AS conferencia
  FROM cmp_compras WHERE pedido_num = '#00990';

-- Agora receba pela tela com data 23/08/2026. O financeiro vai receber 763,50.
-- Para desfazer, bkp_990_nota tem o estado exato de antes.
