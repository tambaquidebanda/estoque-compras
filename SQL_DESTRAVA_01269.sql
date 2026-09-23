-- ============================================================================
-- PEDIDO #01269 - destravar para o estoque receber de novo      (23/09/2026)
-- ============================================================================
--
-- O QUE ACONTECEU, pelo que o banco guarda
--   04/09  pedido criado, 15 itens, R$ 1.108,72 (preco de pedido)
--   08/09  recebido. O sistema gerou o lancamento "Adiantamento Pedido #01269 -
--          Cartao" de R$ 1.170,17 - ou seja, o recebimento mexeu em quantidade
--          ou preco e o total subiu R$ 61,45 em relacao ao pedido.
--   21/09  20:03  a Fabiola excluiu esse lancamento pelo botao Excluir do
--                 Contas a Pagar (fica registrado em lancamentos_excluidos).
--   21/09  ~20:05 alguem usou "Devolver ao Estoque": apagou a conta a pagar, o
--                 recebimento e seus itens, e estornou do estoque os 6 itens que
--                 tinham entrado (R$ 195,05 a menos no ESTOQUE_LOJA).
--   21/09  20:08  o pedido foi editado e salvo de novo. Salvar apaga e regrava as
--                 linhas - e elas voltaram com os precos ORIGINAIS de 04/09.
--                 Foi aqui que os R$ 1.170,17 se perderam.
--   depois  o pedido foi fechado: os 15 itens ficaram como 'dispensado'.
--
-- POR QUE O ESTOQUE NAO CONSEGUE MAIS MEXER
-- Item 'dispensado' nao aparece na tela de Recebimento (nem no celular nem no
-- desktop). O pedido existe, mas sumiu de onde o valor e digitado. E sobrou um
-- rascunho de R$ 1.108,72 preso em Integracoes Pendentes.
--
-- SOBRE OS R$ 1.212,44
-- Esse numero NAO existe em nenhuma tabela. O que o sistema registrou no
-- recebimento foi R$ 1.170,17. Por isso este arquivo NAO escreve valor nenhum:
-- ele so devolve o pedido para 'pendente' e limpa o rascunho. Quem poe o valor
-- certo e o estoque, recebendo com a nota na mao - e ai a conta a pagar e o
-- lancamento nascem com o valor de verdade.
--
-- ANTES DE RODAR: tente o botao "Devolver" na tela de Compras (desktop). Ele faz
-- exatamente isto. Este SQL e o plano B, para o caso de o botao nao funcionar.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confirmar que e seguro.
-- ============================================================================

-- 1a) os 15 itens e o status de cada um
SELECT produto, quantidade, unidade_med, custo_unit, total, status_receb
FROM cmp_compras
WHERE pedido_num = '#01269'
ORDER BY produto;

-- 1b) TEM QUE VOLTAR TUDO ZERO. Se vier qualquer coisa aqui, PARE: o pedido tem
--     recebimento ou conta viva e o caminho e o botao Devolver, nao este SQL.
SELECT (SELECT COUNT(*) FROM cmp_recebimentos  WHERE pedido_num = '#01269') AS recebimentos,
       (SELECT COUNT(*) FROM cmp_contas_pagar  WHERE pedido_num = '#01269') AS contas_a_pagar,
       (SELECT COUNT(*) FROM lancamentos       WHERE numero_pedido = '#01269') AS lancamentos_vivos;

-- 1c) o rascunho preso em Integracoes Pendentes
SELECT id, descricao, valor, vencimento, status
FROM lancamentos_rascunho
WHERE pedido_num = '#01269';


-- ============================================================================
-- PASSO 2 - BACKUP. Nao pule.
-- ============================================================================

CREATE TABLE IF NOT EXISTS bkp_destrava_01269 AS
SELECT id, produto, quantidade, custo_unit, total, status_receb, now() AS salvo_em
FROM cmp_compras
WHERE pedido_num = '#01269';

CREATE TABLE IF NOT EXISTS bkp_destrava_01269_rasc AS
SELECT *, now() AS salvo_em
FROM lancamentos_rascunho
WHERE pedido_num = '#01269';

SELECT (SELECT COUNT(*) FROM bkp_destrava_01269)      AS itens_salvos,
       (SELECT COUNT(*) FROM bkp_destrava_01269_rasc) AS rascunhos_salvos;


-- ============================================================================
-- PASSO 3 - Os itens voltam a ser recebiveis
-- ============================================================================

UPDATE cmp_compras
SET    status_receb = 'pendente'
WHERE  pedido_num = '#01269'
AND    status_receb = 'dispensado';


-- ============================================================================
-- PASSO 4 - Sai o rascunho velho de Integracoes Pendentes
-- ============================================================================
-- Ele carrega o valor errado (R$ 1.108,72). Um novo nasce quando o estoque
-- receber e enviar ao financeiro.

DELETE FROM lancamentos_rascunho
WHERE pedido_num = '#01269';


-- ============================================================================
-- PASSO 5 - CONFERENCIA
-- ============================================================================

-- 5a) 15 itens pendentes, nenhum dispensado
SELECT status_receb, COUNT(*) AS itens
FROM cmp_compras
WHERE pedido_num = '#01269'
GROUP BY 1;

-- 5b) nenhum rascunho sobrou
SELECT COUNT(*) AS rascunhos_restantes
FROM lancamentos_rascunho
WHERE pedido_num = '#01269';

-- 5c) as quantidades e precos NAO foram tocados: tem que voltar ZERO linhas
SELECT c.produto, b.quantidade AS qtd_antiga, c.quantidade, b.custo_unit AS custo_antigo, c.custo_unit
FROM cmp_compras c
JOIN bkp_destrava_01269 b ON b.id = c.id
WHERE c.quantidade IS DISTINCT FROM b.quantidade
   OR c.custo_unit IS DISTINCT FROM b.custo_unit;


-- ============================================================================
-- DEPOIS DE RODAR
-- ============================================================================
-- O pedido #01269 volta a aparecer na tela de Recebimento. O estoque recebe com
-- a nota na mao, ajustando quantidade e preco item a item ate fechar o valor
-- real. A conta a pagar e o lancamento do financeiro nascem desse recebimento,
-- ja com o valor certo - nao precisa mexer no financeiro a mao.
--
-- ATENCAO: o estoque do ESTOQUE_LOJA ja foi estornado em 21/09 (R$ 195,05 dos 6
-- itens que tinham entrado). Entao receber de novo credita do zero, sem dobrar.


-- ============================================================================
-- VOLTAR ATRAS, se precisar
-- ============================================================================
-- UPDATE cmp_compras c SET status_receb = b.status_receb
--   FROM bkp_destrava_01269 b WHERE b.id = c.id;
-- INSERT INTO lancamentos_rascunho SELECT (b).* FROM bkp_destrava_01269_rasc b;
