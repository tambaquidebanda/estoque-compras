-- =====================================================================
-- SQL_VW_FATURAMENTO_DIA.sql  (10/11/2026)
--
-- O faturamento vem do iComanda: a tabela pdv_vendas (puxada pelo robô do
-- financeiro, uma linha por pagamento, ~10 mil por mês). O Dashboard, o BI
-- Compras e o CMV liam cmp_faturamento (lançamento manual), que está vazia,
-- e por isso mostravam faturamento R$ 0,00 e CMV "—".
--
-- Esta visão soma por dia e por unidade (umas 2 linhas por dia), para as
-- telas lerem leve. Não muda nada em pdv_vendas.
-- data_hora_local já é a hora de Manaus gravada como se fosse UTC: o dia
-- certo é o dela "em UTC". Cortesia (R$ 0,01) fica de fora.
--
-- Rodar ANTES do Push. Um bloco só.
-- =====================================================================

CREATE OR REPLACE VIEW vw_faturamento_dia AS
SELECT (data_hora_local AT TIME ZONE 'UTC')::date AS data,
       unidade_nome                               AS unidade,
       round(sum(valor_bruto)::numeric, 2)        AS valor,
       count(*)                                   AS pagamentos
FROM pdv_vendas
WHERE coalesce(forma_pagamento, '') <> 'cortesia'
GROUP BY 1, 2;

GRANT SELECT ON vw_faturamento_dia TO anon, authenticated;

-- Conferência: faturamento por mês e unidade.
-- Esperado (10/11): out/2026 Centro ~1.370 mil, P10 ~210 mil.
SELECT to_char(data, 'YYYY-MM') AS mes, unidade, sum(valor) AS faturamento
FROM vw_faturamento_dia GROUP BY 1, 2 ORDER BY 1, 2;
