-- ============================================================================
-- CONFERÊNCIA: livro-razão (est_movimentacoes) × snapshot (est_saldo_local)
-- ----------------------------------------------------------------------------
-- Depois de testar recebimento / contagem / transferência / pedido interno /
-- ajuste com o time parado, rode este SQL. A invariante do F3 é:
--        Σ(movimentos do razão por produto+local)  ==  saldo do snapshot
-- (garantida pela abertura do backfill + toda gravação passar por movimentar/
--  registrarContagem). Se algo divergir, aparece aqui.
-- ============================================================================

-- 1) DIVERGÊNCIAS — idealmente retorna 0 linhas.
--    Tolerância de 0,001 p/ ruído de arredondamento.
SELECT
  s.produto_id,
  s.local,
  s.saldo                              AS snapshot,
  COALESCE(m.total_razao, 0)           AS razao,
  s.saldo - COALESCE(m.total_razao, 0) AS diferenca
FROM est_saldo_local s
LEFT JOIN (
  SELECT produto_id, local, SUM(quantidade) AS total_razao
  FROM est_movimentacoes
  GROUP BY produto_id, local
) m ON m.produto_id = s.produto_id AND m.local = s.local
WHERE ABS(s.saldo - COALESCE(m.total_razao, 0)) > 0.001
ORDER BY ABS(s.saldo - COALESCE(m.total_razao, 0)) DESC;

-- 2) Também confere o inverso: movimento no razão sem linha no snapshot
--    (produto+local que tem razão mas sumiu do saldo). Deve retornar 0.
SELECT
  m.produto_id, m.local, SUM(m.quantidade) AS razao_sem_snapshot
FROM est_movimentacoes m
LEFT JOIN est_saldo_local s ON s.produto_id = m.produto_id AND s.local = m.local
WHERE s.produto_id IS NULL
GROUP BY m.produto_id, m.local
HAVING ABS(SUM(m.quantidade)) > 0.001;

-- 3) Panorama dos movimentos gravados HOJE, por tipo — pra ver os testes caindo
--    no razão (recebimento, contagem, transferencia_*, pedido_interno_*, ajuste).
SELECT tipo, COUNT(*) AS qtd_movimentos, SUM(quantidade) AS soma_qtd
FROM est_movimentacoes
WHERE data = CURRENT_DATE
GROUP BY tipo
ORDER BY qtd_movimentos DESC;
