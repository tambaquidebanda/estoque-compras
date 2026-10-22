-- =====================================================================
-- SQL_FIX_TOTAL_RECEB_01518.sql  (22/10/2026)
--
-- O SQL_RECEBE_18_PAGOS somou no total do recebimento do #01518 o chopp
-- que veio por pontos da Ambev (item bonificado, 250 L, R$ 3.325).
-- No sistema, item bonificado nao entra no total recebido: o certo e
-- R$ 416,49 (Spaten + Stella), igual ao boleto pago.
-- Nao mexe em item, conta, financeiro nem saldo. So neste recebimento.
-- Os outros 17 pedidos daquele SQL nao tem item bonificado.
--
-- Rode um PASSO de cada vez.
-- =====================================================================

-- PASSO 1 - SO LEITURA. Esperado: total_recebido 3741.49, soma_sem_bonificado 416.49
SELECT r.pedido_num, r.total_recebido,
       (SELECT sum(i.total_recebido) FROM cmp_recebimento_itens i
         WHERE i.recebimento_id = r.id AND NOT coalesce(i.bonificado, false)) AS soma_sem_bonificado
FROM cmp_recebimentos r
WHERE r.id = 'ed4dcfb4-868f-459d-907c-3c1c4ec0d620';

-- PASSO 2 - CORRIGE. Deve responder "UPDATE 1" (rodar de novo nao faz nada).
UPDATE cmp_recebimentos
SET total_recebido = 416.49
WHERE id = 'ed4dcfb4-868f-459d-907c-3c1c4ec0d620'
  AND total_recebido = 3741.49;

-- PASSO 3 - CONFERENCIA. Esperado: total_recebido 416.49, valor_conta 416.49, valor_pago 416.49
SELECT r.pedido_num, r.total_recebido,
       (SELECT cp.valor FROM cmp_contas_pagar cp WHERE cp.pedido_num = r.pedido_num) AS valor_conta,
       (SELECT l.valor FROM lancamentos l WHERE l.numero_pedido = r.pedido_num) AS valor_pago
FROM cmp_recebimentos r
WHERE r.id = 'ed4dcfb4-868f-459d-907c-3c1c4ec0d620';
