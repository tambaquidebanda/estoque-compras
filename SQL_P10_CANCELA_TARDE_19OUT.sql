-- =====================================================================
-- Cancela os 6 pedidos da tarde de 19/10 do Delivery P10
-- PED-3521, 3522, 3523, 3524, 3525 (Flavia) e PED-3527 (Bebidas, Jessica)
-- O P10 comeca hoje (20/10) do zero. Igual ao botao Cancelar da tela:
-- so troca o status de 'pendente' para 'cancelado', nao mexe em saldo.
-- As contagens de 19/10 continuam gravadas. Rode um passo de cada vez.
-- =====================================================================

-- PASSO 1 (so leitura): os 6 tem que estar 'pendente', do Delivery P10
SELECT num_pedido, local, setor, obs, status, liberado_em, recebido_em
FROM pedidos_internos
WHERE num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525','PED-3527')
ORDER BY num_pedido;

-- PASSO 2: cancela (esperado: 6 linhas)
UPDATE pedidos_internos
SET status = 'cancelado'
WHERE num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525','PED-3527')
  AND local = 'Delivery P10'
  AND status = 'pendente';

-- PASSO 3 (conferencia): 6 linhas, todas 'cancelado'
SELECT num_pedido, status
FROM pedidos_internos
WHERE num_pedido IN ('PED-3521','PED-3522','PED-3523','PED-3524','PED-3525','PED-3527')
ORDER BY num_pedido;
