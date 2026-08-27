-- ============================================================================
-- PEDIDOS PRESOS NA TELA DE RECEBIMENTO (aba Pendentes)
--
-- A aba Pendentes mostra todo item de cmp_compras cujo status_receb ainda nao
-- e' 'recebido', 'dispensado' nem 'cancelado'. Estes 22 pedidos ficaram la com
-- itens em 'pendente' mesmo depois de a mercadoria ter entrado e a despesa ter
-- sido paga no financeiro.
--
-- O QUE ESTE SQL FAZ: marca esses itens como 'dispensado'. So isso.
--   - NAO mexe em saldo (status_receb nao movimenta estoque; quem movimenta e'
--     a confirmacao do recebimento, que nao vai rodar aqui).
--   - NAO mexe no financeiro (nao cria conta, nao cria lancamento, nao paga).
--   - NAO apaga linha nenhuma - o pedido continua no historico, so sai da fila.
--
-- POR QUE 'dispensado' E NAO 'recebido': 'dispensado' e' o mesmo status que o
-- botao "Finalizar Pedido" da propria tela usa para fechar item que nao entrou.
-- Marcar como 'recebido' teria efeito colateral: 'recebido' alimenta a tela de
-- ajuste historico do comprador externo e o calculo de custo por recebimento,
-- e passaria a contar como entrada uma quantidade que nunca foi conferida.
--
-- A lista de pedidos esta escrita a mao, uma por uma. Nenhum outro pedido e'
-- tocado - inclusive os 26 que tambem estao na fila hoje mas NAO foram pedidos.
--
-- Conferido em 27/08/2026: 22 pedidos, 84 itens, R$ 37.510,88.
--
-- Rode o PASSO 1 primeiro. Ele e' so leitura.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- PASSO 1 (leitura): exatamente o que o PASSO 2 vai marcar
--
-- Espere 84 linhas. Confira que todo pedido listado e' um dos 22 que voce pediu.
-- ---------------------------------------------------------------------------
SELECT c.pedido_num,
       c.data,
       c.fornecedor_nome,
       c.produto,
       c.quantidade,
       c.custo_unit,
       round((c.quantidade * c.custo_unit)::numeric, 2) AS valor,
       c.status_receb
FROM cmp_compras c
WHERE c.pedido_num IN (
        '#00229','#00315','#00330','#00339','#00427','#00430','#00444',
        '#00539','#00547','#00592','#00607','#00681','#00692','#00709',
        '#00716','#00720','#00741','#00759','#00809','#00810','#00837',
        '#00900')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
ORDER BY c.pedido_num, c.produto;


-- ---------------------------------------------------------------------------
-- PASSO 1B (leitura): o placar, para bater o numero antes de escrever
--
-- Espere: 22 pedidos, 84 itens, 37510.88.
-- ---------------------------------------------------------------------------
SELECT count(DISTINCT c.pedido_num)                              AS pedidos,
       count(*)                                                  AS itens,
       round(sum(c.quantidade * c.custo_unit)::numeric, 2)        AS valor
FROM cmp_compras c
WHERE c.pedido_num IN (
        '#00229','#00315','#00330','#00339','#00427','#00430','#00444',
        '#00539','#00547','#00592','#00607','#00681','#00692','#00709',
        '#00716','#00720','#00741','#00759','#00809','#00810','#00837',
        '#00900')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado');


-- ---------------------------------------------------------------------------
-- PASSO 2 (ESCREVE): tira os 22 da fila
--
-- O RETURNING mostra na tela cada linha alterada. Guarde esse resultado antes
-- de fechar a aba - e' a unica copia de como estava.
--
-- Para desfazer, se precisar: e' o mesmo comando com
--   SET status_receb = 'pendente'
-- e a condicao   AND c.status_receb = 'dispensado'.
-- ---------------------------------------------------------------------------
UPDATE cmp_compras c
   SET status_receb = 'dispensado'
WHERE c.pedido_num IN (
        '#00229','#00315','#00330','#00339','#00427','#00430','#00444',
        '#00539','#00547','#00592','#00607','#00681','#00692','#00709',
        '#00716','#00720','#00741','#00759','#00809','#00810','#00837',
        '#00900')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
RETURNING c.pedido_num, c.data, c.fornecedor_nome, c.produto,
          c.quantidade, c.custo_unit, c.status_receb;


-- ---------------------------------------------------------------------------
-- PASSO 3 (leitura): confirmacao. Tem de voltar ZERO linhas.
-- ---------------------------------------------------------------------------
SELECT c.pedido_num, count(*) AS ainda_presos
FROM cmp_compras c
WHERE c.pedido_num IN (
        '#00229','#00315','#00330','#00339','#00427','#00430','#00444',
        '#00539','#00547','#00592','#00607','#00681','#00692','#00709',
        '#00716','#00720','#00741','#00759','#00809','#00810','#00837',
        '#00900')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
GROUP BY c.pedido_num
ORDER BY c.pedido_num;
