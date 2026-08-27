-- ============================================================================
-- SEGUNDA LEVA: PEDIDOS PAGOS QUE CONTINUAM NA FILA DE RECEBIMENTO
--
-- Continuacao do SQL_LIMPEZA_RECEB_PRESOS.sql (rodado em 27/08/2026, 22 pedidos).
-- Estes nove ficaram de fora da primeira lista e sao o mesmo caso: a despesa ja
-- foi paga no financeiro e o pedido continua na aba Pendentes esperando receber.
--
-- Conferido um a um contra 'lancamentos' - que e' onde a propria tela procura
-- para pintar o selo "Enviado" (ela le lancamentos.numero_pedido direto, nao a
-- conta a pagar; por isso o selo aparece mesmo em pedido cuja conta local sumiu):
--
--   #00548  pago R$   320,00  em 20/07/2026
--   #00551  pago R$   244,20  em 20/07/2026
--   #00618  pago R$ 1.634,39  em 03/08/2026
--   #00696  pago R$ 2.720,44  em 07/08/2026
--   #00729  pago R$   250,00  em 03/08/2026
--   #00796  pago R$   593,41  em 05/08/2026
--   #00820  pago R$   243,00  em 07/08/2026
--   #00901  pago R$ 1.514,06  em 12/08/2026
--   #01010  pago R$   200,00  em 20/08/2026
--
-- O QUE ESTE SQL FAZ: marca os itens presos desses nove como 'dispensado'.
--   - NAO mexe em saldo (status_receb nao movimenta estoque).
--   - NAO mexe no financeiro (nao cria conta, nao cria lancamento, nao paga).
--   - NAO apaga linha nenhuma - o pedido continua no historico.
--
-- NAO ENTRA AQUI, de proposito:
--   #00340  antigo (02/07, R$ 4.180) mas NUNCA foi ao financeiro - nao ha
--           pagamento que justifique tira-lo da fila. Decisao do Wagner.
--   #01067, #01111  enviados, lancamento PENDENTE - ainda nao pagos.
--   #01118  em rascunho, esperando aprovacao.
--   #01079, #01080, #01081, #01106, #01122, #01123 a #01129  de 24 a 27/08,
--           fila normal de quem ainda vai receber.
--
-- Conferido em 27/08/2026: 9 pedidos, 37 itens, R$ 5.004,12.
--
-- Rode o PASSO 1 primeiro. Ele e' so leitura.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- PASSO 1 (leitura): exatamente o que o PASSO 2 vai marcar
--
-- Espere 37 linhas, todas com status_receb = 'pendente'.
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
        '#00548','#00551','#00618','#00696','#00729',
        '#00796','#00820','#00901','#01010')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
ORDER BY c.pedido_num, c.produto;


-- ---------------------------------------------------------------------------
-- PASSO 1B (leitura): o placar, para bater o numero antes de escrever
--
-- Espere: 9 pedidos, 37 itens, 5004.12.
-- ---------------------------------------------------------------------------
SELECT count(DISTINCT c.pedido_num)                        AS pedidos,
       count(*)                                            AS itens,
       round(sum(c.quantidade * c.custo_unit)::numeric, 2)  AS valor
FROM cmp_compras c
WHERE c.pedido_num IN (
        '#00548','#00551','#00618','#00696','#00729',
        '#00796','#00820','#00901','#01010')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado');


-- ---------------------------------------------------------------------------
-- PASSO 2 (ESCREVE): tira os nove da fila
--
-- O RETURNING mostra cada linha alterada. Guarde esse resultado antes de fechar
-- a aba - e' a unica copia de como estava.
--
-- Para desfazer: mesmo comando com  SET status_receb = 'pendente'  e a condicao
-- AND c.status_receb = 'dispensado'.
-- ---------------------------------------------------------------------------
UPDATE cmp_compras c
   SET status_receb = 'dispensado'
WHERE c.pedido_num IN (
        '#00548','#00551','#00618','#00696','#00729',
        '#00796','#00820','#00901','#01010')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
RETURNING c.pedido_num, c.data, c.fornecedor_nome, c.produto,
          c.quantidade, c.custo_unit, c.status_receb;


-- ---------------------------------------------------------------------------
-- PASSO 3 (leitura): confirmacao. Tem de voltar ZERO linhas.
-- ---------------------------------------------------------------------------
SELECT c.pedido_num, count(*) AS ainda_presos
FROM cmp_compras c
WHERE c.pedido_num IN (
        '#00548','#00551','#00618','#00696','#00729',
        '#00796','#00820','#00901','#01010')
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
GROUP BY c.pedido_num
ORDER BY c.pedido_num;


-- ============================================================================
-- EXTRA - PEDIDO #00340 CANCELADO (decidido pelo Wagner em 27/08/2026)
--
-- O #00340 (02/07, MS DA COSTA / PERFECT EMBALAGENS, 3 itens, R$ 4.180,00) e' o
-- fantasma de uma compra que foi refeita.
--
-- Historico levantado:
--   #00340  criado 02/07 por Carla Mota. 200 MC CAIXA DE FRANGO a 3,30 +
--           600 MC CAIXA DE PEIXE a 3,70 + 1.000 MC SACOLA ROTEROS a 1,30.
--           Nunca teve recebimento, conta a pagar, lancamento nem rascunho.
--   #00620  criado 31/07 por Wagner Souza, data retroativa 23/07. MESMOS tres
--           itens, MESMAS quantidades, MESMOS precos, MESMO total R$ 4.180,00.
--           Recebido e confirmado em 31/07 com os tres itens conferidos.
--           Pago no financeiro em 12/08/2026, R$ 4.180,00.
--
-- A mercadoria entrou uma vez so, sob o #00620. Por isso 'cancelado' e NAO
-- 'recebido': marcar recebido creditaria a carga inteira uma segunda vez.
--
-- 'cancelado' ja e' tratado como terminal em toda a tela (as consultas filtram
-- por NOT IN ('recebido','dispensado','cancelado')), mas nenhuma linha da base
-- usa esse valor ainda. Se houver CHECK constraint limitando os valores, este
-- UPDATE falha com erro claro e nada e' gravado - nesse caso use 'dispensado',
-- que tem o mesmo efeito na tela e ja e' usado em 427 linhas.
-- ============================================================================
UPDATE cmp_compras c
   SET status_receb = 'cancelado'
WHERE c.pedido_num = '#00340'
  AND c.status_receb NOT IN ('recebido','dispensado','cancelado')
RETURNING c.pedido_num, c.data, c.fornecedor_nome, c.produto,
          c.quantidade, c.custo_unit, c.status_receb;
