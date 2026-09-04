-- Por setor (ultimos 30 dias): quantas contagens houve, quando foi a ultima,
-- quantos itens foram contados e quantos ficaram SEM produto_id (esses nao alimentam o saldo).
-- Cruza com o ultimo saldo gravado no setor, pra ver descompasso.
-- Read-only, UMA unica instrucao.

SELECT i.setor,
       COUNT(DISTINCT i.id)                                        AS contagens_30d,
       MAX(i.data)                                                 AS ultima_contagem,
       COUNT(ii.*)                                                 AS itens_contados,
       COUNT(ii.*) FILTER (WHERE ii.produto_id IS NULL)            AS itens_SEM_produto_id,
       COUNT(ii.*) FILTER (WHERE ii.produto_id IS NOT NULL)        AS itens_com_produto_id,
       (SELECT MAX(s.updated_at) FROM est_saldo_local s WHERE s.local = i.setor) AS saldo_ultima_atualizacao
FROM est_inventarios i
JOIN est_inventario_itens ii ON ii.inventario_id = i.id
WHERE i.data >= CURRENT_DATE - 30
GROUP BY i.setor
ORDER BY i.setor;
