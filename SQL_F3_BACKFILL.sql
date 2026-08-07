-- ============================================================================
-- F3 — BACKFILL (semente do livro-razão)
-- ----------------------------------------------------------------------------
-- DECISÃO REFINADA (ver observação): em vez de "replay" dos recebimentos antigos,
-- semeamos UM movimento de ABERTURA por (produto, local) = saldo atual real.
--
-- Por quê NÃO replay de recebimentos?  O est_saldo_local de hoje já é a verdade
-- (foi ajustado por contagens). Se eu reinserir só as ENTRADAS históricas
-- (recebimentos), sem as SAÍDAS que nunca foram registradas (consumo, perdas,
-- quebras), a soma do ledger ficaria MUITO acima do saldo real e nunca
-- reconciliaria. A abertura pelo saldo atual garante, desde o dia 1:
--        Σ(movimentos do ledger)  ==  est_saldo_local.saldo
-- e todo movimento futuro (recebimento, perda, contagem...) mantém isso batendo.
--
-- Rodar UMA vez, DEPOIS de criar a tabela (SQL_F3_EST_MOVIMENTACOES.sql) e ANTES
-- de migrar o app para movimentar(). Idempotente: reexecutar não duplica.
-- ============================================================================

INSERT INTO est_movimentacoes
  (produto_id, local, tipo, quantidade, custo_unit, motivo, origem, ref_tabela, ref_id, responsavel, data)
SELECT
  s.produto_id,
  s.local,
  'saldo_inicial',
  s.saldo,                                   -- quantidade de abertura = saldo atual
  p.custo_uso,                               -- custo unitário na unidade de uso (p/ valorização)
  'Abertura do livro-razão (saldo atual)',
  'backfill',
  'est_saldo_local',
  s.id,                                      -- ref_id = id do snapshot → idempotência
  'sistema',
  CURRENT_DATE
FROM est_saldo_local s
JOIN est_produtos p ON p.id = s.produto_id
WHERE s.saldo IS NOT NULL AND s.saldo <> 0
ON CONFLICT (ref_tabela, ref_id, local, tipo) DO NOTHING;

-- Verificação: o ledger deve reconciliar com o snapshot (diferença = 0 em toda linha)
SELECT
  s.produto_id, s.local, s.saldo AS snapshot,
  COALESCE(SUM(m.quantidade), 0) AS ledger,
  s.saldo - COALESCE(SUM(m.quantidade), 0) AS diferenca
FROM est_saldo_local s
LEFT JOIN est_movimentacoes m ON m.produto_id = s.produto_id AND m.local = s.local
GROUP BY s.produto_id, s.local, s.saldo
HAVING s.saldo - COALESCE(SUM(m.quantidade), 0) <> 0
ORDER BY diferenca DESC;
-- ^ Idealmente retorna 0 linhas. Se retornar, são produtos com saldo mas sem custo/ajuste.
