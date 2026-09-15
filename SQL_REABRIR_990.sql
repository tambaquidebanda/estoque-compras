-- ============================================================
-- SQL_REABRIR_990.sql
-- Reabre o pedido #00990 (ALBERTA CARLA SANTOS, 17/08/2026) para edicao.
--
-- POR QUE ELE TRAVOU:
--  1) O lancamento no financeiro foi apagado, mas cmp_contas_pagar do #00990
--     continua existindo com lancamento_id preenchido (a2f207c6-...).
--     A tela de Compras considera "enviado ao financeiro" so por esse campo
--     estar preenchido -- nao confere se o lancamento ainda existe.
--     Resultado: botao Editar desabilitado.
--  2) Os 5 itens estao com status_receb = 'dispensado' (alguem usou
--     "Fechar Pedido"). Com isso o pedido nao e "recebido" nem "pendente",
--     e o botao Reabrir -- que e justamente quem libera a edicao -- nem
--     aparece, porque ele exige pedido recebido.
--
-- ESTOQUE: nada a desfazer. Nao existe est_movimentacoes desse recebimento
-- e os 3 itens recebidos ficaram com produto_id nulo, entao o saldo nunca
-- foi creditado por eles.
--
-- QUANTIDADES: o recebimento parcial de 18/08 SUBTRAIU o recebido do pedido.
-- Hoje cmp_compras guarda so o que sobrou. O PASSO 5 devolve a quantidade
-- ORIGINAL de cada item (a que estava no pedido antes do recebimento).
-- Se voce preferir manter o que esta la hoje, PULE o PASSO 5.
-- ============================================================


-- ============================================================
-- PASSO 1 - SO LEITURA. Confere o estado antes de mexer.
-- ============================================================
SELECT 'compras' AS tabela, id::text, produto, quantidade::text, custo_unit::text, status_receb
  FROM cmp_compras WHERE pedido_num = '#00990'
UNION ALL
SELECT 'recebimento', id::text, status, total_recebido::text, data_receb::text, responsavel
  FROM cmp_recebimentos WHERE pedido_num = '#00990'
UNION ALL
SELECT 'conta_pagar', id::text, status, valor::text, vencimento::text, COALESCE(lancamento_id::text,'(vazio)')
  FROM cmp_contas_pagar WHERE pedido_num = '#00990'
UNION ALL
SELECT 'lancamento', id::text, descricao, valor::text, status, vencimento::text
  FROM lancamentos WHERE numero_pedido = '#00990'
UNION ALL
SELECT 'rascunho', id::text, descricao, valor::text, status, vencimento::text
  FROM lancamentos_rascunho WHERE pedido_num = '#00990';

-- Esperado: 5 linhas 'compras' (todas dispensado), 1 'recebimento' (parcial,
-- 434.00), 1 'conta_pagar' (pendente, 434.00, com lancamento_id preenchido),
-- ZERO 'lancamento' e ZERO 'rascunho'.


-- ============================================================
-- PASSO 2 - Backup. Roda antes de qualquer delete.
-- ============================================================
DROP TABLE IF EXISTS bkp_990_compras;
DROP TABLE IF EXISTS bkp_990_receb;
DROP TABLE IF EXISTS bkp_990_receb_itens;
DROP TABLE IF EXISTS bkp_990_conta;

CREATE TABLE bkp_990_compras     AS SELECT * FROM cmp_compras       WHERE pedido_num = '#00990';
CREATE TABLE bkp_990_receb       AS SELECT * FROM cmp_recebimentos  WHERE pedido_num = '#00990';
CREATE TABLE bkp_990_receb_itens AS SELECT * FROM cmp_recebimento_itens
  WHERE recebimento_id IN (SELECT id FROM cmp_recebimentos WHERE pedido_num = '#00990');
CREATE TABLE bkp_990_conta       AS SELECT * FROM cmp_contas_pagar  WHERE pedido_num = '#00990';

SELECT (SELECT count(*) FROM bkp_990_compras)     AS compras,
       (SELECT count(*) FROM bkp_990_receb)       AS recebimentos,
       (SELECT count(*) FROM bkp_990_receb_itens) AS itens_receb,
       (SELECT count(*) FROM bkp_990_conta)       AS contas;
-- Esperado: 5 / 1 / 3 / 1


-- ============================================================
-- PASSO 3 - Remove a conta a pagar orfa.
-- A ORDEM IMPORTA: cmp_contas_pagar.recebimento_id e chave estrangeira
-- para cmp_recebimentos.id. A conta sai PRIMEIRO, senao o banco recusa
-- apagar o recebimento.
-- ============================================================
DELETE FROM cmp_contas_pagar WHERE pedido_num = '#00990';


-- ============================================================
-- PASSO 4 - Remove o recebimento parcial (itens e cabecalho).
-- ============================================================
DELETE FROM cmp_recebimento_itens
 WHERE recebimento_id IN (SELECT id FROM cmp_recebimentos WHERE pedido_num = '#00990');

DELETE FROM cmp_recebimentos WHERE pedido_num = '#00990';


-- ============================================================
-- PASSO 5 - Devolve os itens para pendente e restaura a quantidade
-- ORIGINAL do pedido.
--
-- Quantidade hoje  ->  quantidade original
--   CEU DE BRIGADEIRO      32 -> 32  (nunca recebido)
--   CHEESECAKE CUPUACU     24 -> 36  (recebeu 12)
--   BROWNIE DE CHOCOLATE   16 -> 32  (recebeu 16)
--   PETIT GATEAU C CALDA   22 -> 48  (recebeu 26)
--   PUDIM DE LEITE         48 -> 48  (nunca recebido)
--
-- Se preferir NAO restaurar as quantidades, troque este passo por:
--   UPDATE cmp_compras SET status_receb = 'pendente' WHERE pedido_num = '#00990';
-- ============================================================
UPDATE cmp_compras c
   SET status_receb = 'pendente',
       quantidade   = v.qtd
  FROM (VALUES
    ('d9eb44b3-5f19-4ce8-baa4-74743efcebe1'::uuid, 32::numeric),
    ('3e1d3253-98e5-4305-b3db-a64cfdbd069b'::uuid, 36::numeric),
    ('94c03c56-02f1-4588-aaf7-45cb44669414'::uuid, 32::numeric),
    ('8e08669a-856a-4867-933d-cb6ff3f787d8'::uuid, 48::numeric),
    ('047f330e-d782-4976-9537-0877633fd8b7'::uuid, 48::numeric)
  ) AS v(id, qtd)
 WHERE c.id = v.id;


-- ============================================================
-- PASSO 6 - Conferencia final.
-- ============================================================
SELECT produto, quantidade, custo_unit, status_receb,
       (quantidade * custo_unit) AS total_item
  FROM cmp_compras WHERE pedido_num = '#00990' ORDER BY produto;

SELECT (SELECT count(*) FROM cmp_recebimentos WHERE pedido_num = '#00990') AS recebimentos_restantes,
       (SELECT count(*) FROM cmp_contas_pagar WHERE pedido_num = '#00990') AS contas_restantes,
       (SELECT count(*) FROM lancamentos      WHERE numero_pedido = '#00990') AS lancamentos_restantes;
-- Esperado: 5 itens 'pendente', total 1676.00 (416 + 468 + 192 + 336 + 264),
-- e 0 / 0 / 0 na segunda linha.

-- Depois disso o #00990 volta para a fila de Recebimento e o botao Editar
-- em Compras fica liberado.

-- Para desfazer tudo, os backups do PASSO 2 tem o estado exato de antes.
