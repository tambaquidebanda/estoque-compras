-- =====================================================================
-- Pedidos da tarde de 19/10 do Delivery P10 voltam para PENDENTE
-- PED-3521, PED-3522, PED-3523, PED-3524, PED-3525
-- Liberados em 20/10 08:46-08:48 pela sessao do Estoque do Centro
-- (login Anderson Borges), junto com os pedidos do Centro. Por isso o
-- estoque do P10 so viu o de Bebidas. Liberar NAO mexe em saldo
-- (o saldo so anda quando o setor confirma), entao basta voltar o status.
-- Rode um passo de cada vez.
-- =====================================================================

-- PASSO 1 (so leitura): os 5 tem que estar 'liberado', sem recebido_em,
-- liberados pela sessao do Centro.
SELECT num_pedido, status, liberado_em, liberado_por, recebido_em
FROM pedidos_internos
WHERE num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525')
ORDER BY num_pedido;

-- PASSO 2: volta os itens (so dos pedidos que ainda estao como no PASSO 1)
UPDATE pedidos_internos_itens i
SET qtd_liberada = NULL
FROM pedidos_internos p
WHERE i.pedido_id = p.id
  AND p.num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525')
  AND p.status = 'liberado'
  AND p.recebido_em IS NULL
  AND p.liberado_por LIKE 'Anderson%'
  AND i.qtd_recebida IS NULL;
-- esperado: 43 linhas

-- PASSO 3: volta os pedidos
UPDATE pedidos_internos
SET status = 'pendente', liberado_em = NULL, liberado_por = NULL
WHERE num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525')
  AND status = 'liberado'
  AND recebido_em IS NULL
  AND liberado_por LIKE 'Anderson%';
-- esperado: 5 linhas

-- PASSO 4 (conferencia): os 5 'pendente' e nenhum item com qtd_liberada
SELECT p.num_pedido, p.status, p.liberado_por,
       count(i.id) AS itens,
       count(i.qtd_liberada) AS itens_com_liberada
FROM pedidos_internos p
JOIN pedidos_internos_itens i ON i.pedido_id = p.id
WHERE p.num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525')
GROUP BY p.num_pedido, p.status, p.liberado_por
ORDER BY p.num_pedido;
-- esperado: 5 linhas, status pendente, itens_com_liberada = 0
