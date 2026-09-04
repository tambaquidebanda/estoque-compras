-- Diagnostico: quais 'locais' (ESTOQUE_LOJA + cada setor) estao alimentando o saldo,
-- quantos produtos tem saldo e quando foi a ultima atualizacao.
-- Setor que NAO aparecer aqui = nunca alimentou o saldo.
-- Setor com ultima_atualizacao antiga = parou de alimentar.
-- Read-only, UMA unica instrucao.

SELECT local,
       COUNT(*)                                                   AS produtos_com_saldo,
       COUNT(*) FILTER (WHERE saldo <> 0)                         AS com_saldo_nao_zero,
       MAX(updated_at)                                            AS ultima_atualizacao,
       COUNT(*) FILTER (WHERE updated_at::date = CURRENT_DATE)    AS atualizados_hoje,
       COUNT(*) FILTER (WHERE updated_at >= CURRENT_DATE - 7)     AS atualizados_7dias
FROM est_saldo_local
GROUP BY local
ORDER BY local;
