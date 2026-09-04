-- Lista OUTRAS despesas de Comprador Externo que nasceram 'pago' pelo banco Caixa
-- (mesmo bug do #00679). Read-only. Revise antes de corrigir em lote.
-- Caixa (Dinheiro) = 5f8f152e-8ef7-47ad-8df3-b251f4225a1f

SELECT l.numero_pedido,
       l.descricao,
       l.valor,
       l.status,
       l.data_pagamento::text AS data_pagamento,
       l.vencimento::text     AS vencimento,
       b.nome                 AS banco_nome
FROM lancamentos l
LEFT JOIN bancos b ON b.id = l.banco_id
WHERE l.tipo = 'pagar'
  AND l.status = 'pago'
  AND l.descricao ILIKE '%Comprador Externo%'
  AND l.banco_id = '5f8f152e-8ef7-47ad-8df3-b251f4225a1f'
ORDER BY l.vencimento DESC;
