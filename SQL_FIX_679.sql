-- FIX pedido #00679: despesa em DINHEIRO (Caixa) nasceu 'pago' por engano.
-- Volta para 'pendente' e limpa data_pagamento, pra entrar na fila de aprovacao
-- do financeiro (a pessoa retira o dinheiro e ai marca pago). Cirurgico: 1 linha por id.
-- cmp_contas_pagar do 679 ja esta 'pendente' — nao precisa mexer.

UPDATE lancamentos
   SET status = 'pendente',
       data_pagamento = NULL
 WHERE id = '60402f17-f3cc-4368-9cbf-de7919f90acb'
   AND status = 'pago'
RETURNING id, descricao, valor, status, data_pagamento, numero_pedido;
