-- Historico do pedido 00650 (recebido 25/07) - investigar duplicacao de valor no recebimento mobile

-- A) RECEBIMENTOS gravados (a chave: se houver 2, houve duplicacao). Veja os horarios (criado_em).
SELECT id, pedido_num, data_receb, total_recebido, status, criado_em
FROM cmp_recebimentos
WHERE pedido_num ILIKE '%00650%'
ORDER BY criado_em;

-- B) Itens de cada recebimento (para ver se os dois sao identicos = toque duplo)
SELECT r.criado_em, ri.produto, ri.qtd_recebida, ri.valor_unitario, ri.total_recebido
FROM cmp_recebimento_itens ri
JOIN cmp_recebimentos r ON r.id = ri.recebimento_id
WHERE r.pedido_num ILIKE '%00650%'
ORDER BY r.criado_em, ri.produto;

-- C) Conta a pagar atual (valor = soma dos recebimentos)
SELECT pedido_num, valor, vencimento, status, lancamento_id, recebimento_id
FROM cmp_contas_pagar
WHERE pedido_num ILIKE '%00650%';

-- D) Pedido original
SELECT produto, quantidade, custo_unit, status_receb
FROM cmp_compras
WHERE pedido_num ILIKE '%00650%';

-- E) Financeiro (lancamento e/ou rascunho)
SELECT 'lancamento' AS fonte, valor::text AS valor, descricao AS ref
FROM lancamentos WHERE descricao ILIKE '%00650%' OR numero_pedido ILIKE '%00650%'
UNION ALL
SELECT 'rascunho', valor::text, pedido_num
FROM lancamentos_rascunho WHERE pedido_num ILIKE '%00650%';
