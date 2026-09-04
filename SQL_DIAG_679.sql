-- DIAGNOSTICO pedido #00679: onde ele aparece e com que status, em todas as tabelas.
-- Read-only, UMA unica instrucao (UNION ALL). Match EXATO em '#00679'.

SELECT * FROM (

  -- 1) O PEDIDO em si (itens de compra)
  SELECT '1_cmp_compras'        AS origem,
         c.pedido_num           AS pedido_num,
         c.id::text             AS id,
         c.produto              AS descricao,
         c.custo_unit           AS valor,
         c.status_receb         AS status,
         c.data::text           AS data,
         COALESCE(c.fornecedor_nome,'') || ' | forma_pgto=' || COALESCE(c.forma_pagamento,'') AS extra
  FROM cmp_compras c
  WHERE c.pedido_num = '#00679'

  UNION ALL

  -- 2) RECEBIMENTO (cabecalho)
  SELECT '2_cmp_recebimentos',
         r.pedido_num,
         r.id::text,
         COALESCE(r.fornecedor,''),
         r.total_recebido,
         r.status,
         r.data_receb::text,
         'responsavel=' || COALESCE(r.responsavel,'')
  FROM cmp_recebimentos r
  WHERE r.pedido_num = '#00679'

  UNION ALL

  -- 3) CONTA A PAGAR (ponte estoque->financeiro)
  SELECT '3_cmp_contas_pagar',
         cp.pedido_num,
         cp.id::text,
         COALESCE(cp.fornecedor,''),
         cp.valor,
         cp.status,
         COALESCE(cp.data_pagamento::text, cp.vencimento::text),
         'lancamento_id=' || COALESCE(cp.lancamento_id::text,'NULL')
           || ' | adiant_id=' || COALESCE(cp.adiantamento_lancamento_id::text,'NULL')
           || ' | data_pagto=' || COALESCE(cp.data_pagamento::text,'NULL')
  FROM cmp_contas_pagar cp
  WHERE cp.pedido_num = '#00679'

  UNION ALL

  -- 4) LANCAMENTO no FINANCEIRO (por numero_pedido)
  SELECT '4_lancamentos(num)',
         l.numero_pedido,
         l.id::text,
         COALESCE(l.descricao,''),
         l.valor,
         l.status,
         COALESCE(l.data_pagamento::text, l.vencimento::text),
         'tipo=' || COALESCE(l.tipo,'') || ' | banco_id=' || COALESCE(l.banco_id::text,'NULL')
           || ' | data_pagto=' || COALESCE(l.data_pagamento::text,'NULL')
  FROM lancamentos l
  WHERE l.numero_pedido = '#00679'

  UNION ALL

  -- 5) RASCUNHO de integracao (se existir, foi pela integracao em modo teste)
  SELECT '6_lancamentos_rascunho',
         lr.pedido_num,
         lr.id::text,
         COALESCE(lr.descricao,''),
         lr.valor,
         lr.status,
         COALESCE(lr.vencimento::text,''),
         'conta_id=' || COALESCE(lr.conta_id::text,'NULL')
  FROM lancamentos_rascunho lr
  WHERE lr.pedido_num = '#00679'

) t
ORDER BY origem, pedido_num;
