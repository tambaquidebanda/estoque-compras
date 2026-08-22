-- ============================================================================
-- ROLLBACK DA BAIXA AUTOMATICA DO PDV (um dia)
--
-- Desfaz uma rodada do robo em modo apply: devolve o saldo, apaga o razao e
-- libera o dia para ser rodado de novo.
--
-- TROQUE A DATA nos QUATRO passos abaixo. Ela aparece como '2026-08-21'.
--
-- ORDEM IMPORTA: o passo 2 calcula quanto devolver A PARTIR do razao, entao o
-- razao so pode ser apagado no passo 3. Nao pule nem inverta.
--
-- Nota: est_saldo_local nao tem gatilho ligado a est_movimentacoes (o app grava
-- os dois separadamente). Apagar o razao NAO mexe no saldo sozinho.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA. O que existe hoje para esse dia.
-- Rode primeiro e confira. Se vier zero linha, nao ha nada a desfazer.
-- ----------------------------------------------------------------------------
SELECT
  m.local,
  count(*)                          AS insumos,
  round(sum(m.quantidade)::numeric, 3)  AS qtd_total,
  round(sum(m.valor_total)::numeric, 2) AS valor_total
FROM est_movimentacoes m
WHERE m.tipo   = 'venda_pensera'
  AND m.origem = 'pdv_icomanda'
  AND m.data   = '2026-08-21'
GROUP BY m.local
ORDER BY m.local;


-- ----------------------------------------------------------------------------
-- PASSO 2 - DEVOLVE O SALDO.
-- As quantidades no razao sao NEGATIVAS, entao subtrair a soma soma de volta.
-- ----------------------------------------------------------------------------
WITH baixado AS (
  SELECT produto_id, local, sum(quantidade) AS q
  FROM est_movimentacoes
  WHERE tipo   = 'venda_pensera'
    AND origem = 'pdv_icomanda'
    AND data   = '2026-08-21'
  GROUP BY produto_id, local
)
UPDATE est_saldo_local s
SET    saldo      = s.saldo - b.q,
       updated_at = now()
FROM   baixado b
WHERE  s.produto_id = b.produto_id
  AND  s.local      = b.local;


-- ----------------------------------------------------------------------------
-- PASSO 3 - APAGA O RAZAO DO DIA.
-- ----------------------------------------------------------------------------
DELETE FROM est_movimentacoes
WHERE tipo   = 'venda_pensera'
  AND origem = 'pdv_icomanda'
  AND data   = '2026-08-21';


-- ----------------------------------------------------------------------------
-- PASSO 4 - LIBERA O DIA PARA RODAR DE NOVO.
-- Apaga so o registro de apply; a linha do dry-run (preview) e recriada sozinha.
-- ----------------------------------------------------------------------------
DELETE FROM pdv_baixa_ctrl
WHERE data = '2026-08-21'
  AND modo = 'apply';


-- ----------------------------------------------------------------------------
-- PASSO 5 - CONFERENCIA. As tres devem vir vazias/zeradas.
-- ----------------------------------------------------------------------------
SELECT 'razao restante'  AS o_que, count(*)::text AS valor
FROM est_movimentacoes
WHERE tipo = 'venda_pensera' AND origem = 'pdv_icomanda' AND data = '2026-08-21'
UNION ALL
SELECT 'ctrl apply restante', count(*)::text
FROM pdv_baixa_ctrl WHERE data = '2026-08-21' AND modo = 'apply'
UNION ALL
SELECT 'saldos negativos nos setores', count(*)::text
FROM est_saldo_local WHERE saldo < 0 AND local <> 'ESTOQUE_LOJA';
