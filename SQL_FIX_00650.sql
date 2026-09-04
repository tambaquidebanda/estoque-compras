-- Correcao do pedido 00650 (recebimento duplicado - dupla confirmacao).
-- O FINANCEIRO ja esta correto (lancamento 2660.80) e NAO sera tocado.
-- Aqui so deixamos o ESTOQUE coerente: 200 un / recebido, sem recebimentos orfaos,
-- e com a conta a pagar LIGADA ao lancamento existente (nao cria nada novo no financeiro).

-- 1. Apaga os 2 recebimentos orfaos (ja estao sem itens)
DELETE FROM cmp_recebimento_itens WHERE recebimento_id IN (SELECT id FROM cmp_recebimentos WHERE pedido_num = '#00650');
DELETE FROM cmp_recebimentos WHERE pedido_num = '#00650';

-- 2. Acerta o pedido: 200 unidades, recebido
UPDATE cmp_compras
SET quantidade = 200, status_receb = 'recebido', custo_unit = 13.304
WHERE pedido_num = '#00650';

-- 3. Cria a conta a pagar (valor certo) ligada ao lancamento que ja existe
INSERT INTO cmp_contas_pagar (pedido_num, fornecedor, data_receb, vencimento, valor, status, lancamento_id)
SELECT '#00650', c.fornecedor_nome, DATE '2026-07-25',
       COALESCE((SELECT vencimento FROM lancamentos WHERE descricao ILIKE 'Pedido #00650%' LIMIT 1), DATE '2026-07-25'),
       2660.80, 'pendente',
       (SELECT id FROM lancamentos WHERE descricao ILIKE 'Pedido #00650%' LIMIT 1)
FROM cmp_compras c
WHERE c.pedido_num = '#00650'
LIMIT 1;

-- Verificacao final
SELECT 'compras (qtd/status)' AS item, quantidade::text AS valor, status_receb AS detalhe FROM cmp_compras WHERE pedido_num='#00650'
UNION ALL
SELECT 'recebimentos (qtd)', count(*)::text, '(deve ser 0)' FROM cmp_recebimentos WHERE pedido_num='#00650'
UNION ALL
SELECT 'conta a pagar (valor)', valor::text, status || CASE WHEN lancamento_id IS NULL THEN ' / SEM lanc' ELSE ' / ligada' END FROM cmp_contas_pagar WHERE pedido_num='#00650';
