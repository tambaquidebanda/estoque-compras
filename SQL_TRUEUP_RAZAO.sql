-- ============================================================================
-- TRUE-UP DO LIVRO-RAZÃO (baseline pós-migração)
-- ----------------------------------------------------------------------------
-- POR QUÊ: a semente do razão (saldo_inicial do backfill) foi criada ANTES das
-- operações de hoje feitas na versão antiga do app (que mudavam o saldo mas não
-- gravavam no razão). Resultado: Σ(razão) ficou atrás do saldo real (snapshot).
-- Este script insere UM movimento de ajuste por (produto, local) para reconciliar:
--        novo ajuste = saldo_atual − Σ(razão atual)
-- Depois disso, Σ(razão) == est_saldo_local.saldo, e toda gravação futura
-- (recebimento/contagem/perda/etc, já migradas) mantém batendo.
--
-- QUANDO RODAR: uma vez, DEPOIS de confirmar que a migração está no ar e que os
-- testes reconciliam (é seguro re-rodar: só cria ajuste se ainda houver diferença).
-- Append-only: não apaga nada.
-- ============================================================================

-- 1) Prévia — quanto seria ajustado (rode antes para conferir; NÃO grava nada)
SELECT
  s.produto_id, s.local,
  s.saldo                              AS snapshot,
  COALESCE(m.total, 0)                 AS razao_atual,
  s.saldo - COALESCE(m.total, 0)       AS ajuste_a_lancar
FROM est_saldo_local s
LEFT JOIN (SELECT produto_id, local, SUM(quantidade) total FROM est_movimentacoes GROUP BY produto_id, local) m
  ON m.produto_id = s.produto_id AND m.local = s.local
WHERE ABS(s.saldo - COALESCE(m.total, 0)) > 0.001
ORDER BY ABS(s.saldo - COALESCE(m.total, 0)) DESC;

-- 2) Aplica o true-up (descomente para rodar depois de conferir a prévia acima)
-- INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, origem, motivo, data)
-- SELECT s.produto_id, s.local, 'ajuste',
--        s.saldo - COALESCE(m.total, 0),
--        'trueup_migracao',
--        'True-up pos-migracao (baseline do razao = saldo atual)',
--        CURRENT_DATE
-- FROM est_saldo_local s
-- LEFT JOIN (SELECT produto_id, local, SUM(quantidade) total FROM est_movimentacoes GROUP BY produto_id, local) m
--   ON m.produto_id = s.produto_id AND m.local = s.local
-- WHERE ABS(s.saldo - COALESCE(m.total, 0)) > 0.001;

-- 3) Conferência final (após rodar o passo 2) — deve retornar 0 linhas
-- SELECT s.produto_id, s.local, s.saldo - COALESCE(m.total,0) AS diferenca
-- FROM est_saldo_local s
-- LEFT JOIN (SELECT produto_id, local, SUM(quantidade) total FROM est_movimentacoes GROUP BY produto_id, local) m
--   ON m.produto_id = s.produto_id AND m.local = s.local
-- WHERE ABS(s.saldo - COALESCE(m.total,0)) > 0.001;
