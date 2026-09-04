-- Saldo atual do MP BARRIL CHOPP BRAHMA em cada local, com a data da ultima atualizacao.
-- Serve para decidir se o saldo ficou inflado (+200) pela entrada dupla, ou se ja foi recontado.

SELECT ep.nome, sl.local, sl.saldo, sl.updated_at
FROM est_saldo_local sl
JOIN est_produtos ep ON ep.id = sl.produto_id
WHERE ep.nome ILIKE '%BARRIL CHOPP BRAHMA%'
ORDER BY sl.local;
