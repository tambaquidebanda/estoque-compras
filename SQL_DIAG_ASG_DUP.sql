-- Confirma a suspeita: mesmo produto_id aparecendo MAIS DE UMA VEZ na mesma contagem.
-- Se aparecer linha aqui, o upsert de saldo (onConflict produto_id,local) quebra o batch
-- inteiro e o saldo do setor nao e gravado (silenciosamente, pois nao ha checagem de erro).
-- Read-only, UMA unica instrucao. (Olho em ASG e nos demais setores tambem.)

SELECT i.setor,
       i.num_inv,
       i.data,
       i.grupo,
       ii.produto_id,
       COUNT(*)                       AS vezes,
       string_agg(ii.nome, ' | ')     AS nomes_que_colidem
FROM est_inventarios i
JOIN est_inventario_itens ii ON ii.inventario_id = i.id
WHERE i.data >= CURRENT_DATE - 30
  AND ii.produto_id IS NOT NULL
GROUP BY i.setor, i.num_inv, i.data, i.grupo, ii.produto_id
HAVING COUNT(*) > 1
ORDER BY i.setor, i.data DESC;
