-- DIAGNOSTICO 679-B: qual banco e' o do lancamento, e se houve ADIANTAMENTO.
-- Read-only, UMA instrucao. Mostra o nome do banco (Caixa/Dinheiro?) e todas as
-- linhas de lancamentos ligadas ao 679 (despesa + eventual adiantamento).

SELECT l.id::text,
       l.descricao,
       l.observacoes,
       l.valor,
       l.tipo,
       l.status,
       l.data_pagamento::text  AS data_pagamento,
       l.vencimento::text      AS vencimento,
       l.numero_pedido,
       l.banco_id::text        AS banco_id,
       b.nome                  AS banco_nome
FROM lancamentos l
LEFT JOIN bancos b ON b.id = l.banco_id
WHERE l.numero_pedido = '#00679'
   OR l.descricao ILIKE '%#00679%'
   OR l.observacoes ILIKE '%#00679%'
ORDER BY l.tipo, l.vencimento;
