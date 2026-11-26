-- SQL_PRECIFICACAO_DETALHE.sql — despesa da Precificação aberta por conta do plano de contas
--
-- Para que serve: na aba Despesas da Precificação, clicar num grupo (Fixo, CMV, Variável...)
-- abre as contas que formam aquele número.
--
-- Cria UMA view nova, vw_precificacao_conta, só de leitura. Não mexe em tabela nenhuma e
-- não mexe na vw_precificacao_mensal do Financeiro.
-- Usa as MESMAS regras da vw_precificacao_mensal (versão de 25/11, PRECIFICACAO_AJUSTE_CARTAO):
--   competência = vencimento, lançamento com rateio entra pelas linhas do rateio,
--   conta classificada por plano_contas.grupo_precificacao,
--   lançamento sem unidade e todo imposto_venda são rateados pelo faturamento do mês.
-- Taxa de cartão, antecipação e comissão do iFood não têm conta no plano: não aparecem aqui
-- (a tela explica como o Financeiro calcula cada uma).
-- Se um dia o Financeiro mudar a regra da view dele e esta ficar diferente, a tela mostra a
-- diferença numa linha "sem detalhe", em vez de esconder.

-- ═══ PASSO 1 — CONFERIR (só leitura) ═══════════════════════════════════════════════
-- Mesmo corpo da view. Se este SELECT rodar, o PASSO 2 funciona.
WITH fat AS (
  SELECT date_trunc('month', f.data)::date AS mes,
         CASE f.unidade
           WHEN 'Tambaqui de Banda Loja Centro' THEN 'Centro'
           WHEN 'Tdb - Parque 10'               THEN 'P10'
         END AS unidade,
         sum(f.valor)::numeric AS faturamento
    FROM vw_faturamento_dia f
   WHERE f.unidade IN ('Tambaqui de Banda Loja Centro', 'Tdb - Parque 10')
   GROUP BY 1, 2
),
fat_mes AS (SELECT mes, sum(faturamento) AS total FROM fat GROUP BY 1),
linhas AS (
  SELECT date_trunc('month', l.vencimento)::date AS mes, l.unidade_id, l.plano_conta_id, l.valor
    FROM lancamentos l
   WHERE l.tipo = 'pagar' AND l.vencimento IS NOT NULL
     AND ( coalesce(l.tem_rateio, false) = false
           OR NOT EXISTS (SELECT 1 FROM rateio_itens r WHERE r.lancamento_id = l.id) )
  UNION ALL
  SELECT date_trunc('month', l.vencimento)::date, ri.unidade_id, ri.plano_conta_id, ri.valor
    FROM lancamentos l
    JOIN rateio_itens ri ON ri.lancamento_id = l.id
   WHERE l.tipo = 'pagar' AND l.vencimento IS NOT NULL
     AND coalesce(l.tem_rateio, false) = true
),
classificado AS (
  SELECT x.mes,
         CASE
           WHEN x.unidade_id = 'e031eced-0652-4af0-ad2a-13b65a29f814'::uuid THEN 'Centro'
           WHEN x.unidade_id = '6696a0dc-71f9-4a98-bdb4-42d9dd989cb1'::uuid THEN 'P10'
           WHEN x.unidade_id IS NULL                                        THEN NULL
           ELSE 'OUTRA'
         END AS unidade,
         pc.grupo_precificacao AS grupo,
         coalesce(pai.nome, pc.nome) AS subgrupo,
         pc.nome AS conta,
         x.valor
    FROM linhas x
    JOIN plano_contas pc ON pc.id = x.plano_conta_id
    LEFT JOIN plano_contas pai ON pai.id = pc.grupo_id
   WHERE pc.grupo_precificacao IS NOT NULL
),
direto AS (
  SELECT mes, unidade, grupo, subgrupo, conta, sum(valor) AS valor
    FROM classificado
   WHERE unidade IN ('Centro', 'P10') AND grupo <> 'imposto_venda'
   GROUP BY 1, 2, 3, 4, 5
),
sem_unidade AS (
  SELECT mes, grupo, subgrupo, conta, sum(valor) AS valor
    FROM classificado
   WHERE unidade IS NULL OR (unidade IN ('Centro', 'P10') AND grupo = 'imposto_venda')
   GROUP BY 1, 2, 3, 4
),
rateado AS (
  SELECT s.mes, m.unidade, s.grupo, s.subgrupo, s.conta,
         s.valor * m.faturamento / nullif(t.total, 0) AS valor
    FROM sem_unidade s
    JOIN fat m     ON m.mes = s.mes
    JOIN fat_mes t ON t.mes = s.mes
),
despesa AS (
  SELECT mes, unidade, grupo, subgrupo, conta, valor, 'lancamento'::text AS origem FROM direto
  UNION ALL
  SELECT mes, unidade, grupo, subgrupo, conta, valor, 'rateio_faturamento'::text FROM rateado
)
SELECT d.mes, d.unidade, d.grupo, d.subgrupo, d.conta,
       round(sum(d.valor)::numeric, 2)    AS valor,
       string_agg(DISTINCT d.origem, '+') AS origem
  FROM despesa d
  JOIN fat m ON m.mes = d.mes AND m.unidade = d.unidade
 GROUP BY 1, 2, 3, 4, 5
 ORDER BY 1 DESC, 2, 3, 6 DESC
 LIMIT 30;

-- ═══ PASSO 2 — CRIAR A VIEW ═══════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_precificacao_conta AS
WITH fat AS (
  SELECT date_trunc('month', f.data)::date AS mes,
         CASE f.unidade
           WHEN 'Tambaqui de Banda Loja Centro' THEN 'Centro'
           WHEN 'Tdb - Parque 10'               THEN 'P10'
         END AS unidade,
         sum(f.valor)::numeric AS faturamento
    FROM vw_faturamento_dia f
   WHERE f.unidade IN ('Tambaqui de Banda Loja Centro', 'Tdb - Parque 10')
   GROUP BY 1, 2
),
fat_mes AS (SELECT mes, sum(faturamento) AS total FROM fat GROUP BY 1),
linhas AS (
  SELECT date_trunc('month', l.vencimento)::date AS mes, l.unidade_id, l.plano_conta_id, l.valor
    FROM lancamentos l
   WHERE l.tipo = 'pagar' AND l.vencimento IS NOT NULL
     AND ( coalesce(l.tem_rateio, false) = false
           OR NOT EXISTS (SELECT 1 FROM rateio_itens r WHERE r.lancamento_id = l.id) )
  UNION ALL
  SELECT date_trunc('month', l.vencimento)::date, ri.unidade_id, ri.plano_conta_id, ri.valor
    FROM lancamentos l
    JOIN rateio_itens ri ON ri.lancamento_id = l.id
   WHERE l.tipo = 'pagar' AND l.vencimento IS NOT NULL
     AND coalesce(l.tem_rateio, false) = true
),
classificado AS (
  SELECT x.mes,
         CASE
           WHEN x.unidade_id = 'e031eced-0652-4af0-ad2a-13b65a29f814'::uuid THEN 'Centro'
           WHEN x.unidade_id = '6696a0dc-71f9-4a98-bdb4-42d9dd989cb1'::uuid THEN 'P10'
           WHEN x.unidade_id IS NULL                                        THEN NULL
           ELSE 'OUTRA'
         END AS unidade,
         pc.grupo_precificacao AS grupo,
         coalesce(pai.nome, pc.nome) AS subgrupo,
         pc.nome AS conta,
         x.valor
    FROM linhas x
    JOIN plano_contas pc ON pc.id = x.plano_conta_id
    LEFT JOIN plano_contas pai ON pai.id = pc.grupo_id
   WHERE pc.grupo_precificacao IS NOT NULL
),
direto AS (
  SELECT mes, unidade, grupo, subgrupo, conta, sum(valor) AS valor
    FROM classificado
   WHERE unidade IN ('Centro', 'P10') AND grupo <> 'imposto_venda'
   GROUP BY 1, 2, 3, 4, 5
),
sem_unidade AS (
  SELECT mes, grupo, subgrupo, conta, sum(valor) AS valor
    FROM classificado
   WHERE unidade IS NULL OR (unidade IN ('Centro', 'P10') AND grupo = 'imposto_venda')
   GROUP BY 1, 2, 3, 4
),
rateado AS (
  SELECT s.mes, m.unidade, s.grupo, s.subgrupo, s.conta,
         s.valor * m.faturamento / nullif(t.total, 0) AS valor
    FROM sem_unidade s
    JOIN fat m     ON m.mes = s.mes
    JOIN fat_mes t ON t.mes = s.mes
),
despesa AS (
  SELECT mes, unidade, grupo, subgrupo, conta, valor, 'lancamento'::text AS origem FROM direto
  UNION ALL
  SELECT mes, unidade, grupo, subgrupo, conta, valor, 'rateio_faturamento'::text FROM rateado
)
SELECT d.mes, d.unidade, d.grupo, d.subgrupo, d.conta,
       round(sum(d.valor)::numeric, 2)    AS valor,
       string_agg(DISTINCT d.origem, '+') AS origem
  FROM despesa d
  JOIN fat m ON m.mes = d.mes AND m.unidade = d.unidade
 GROUP BY 1, 2, 3, 4, 5;

-- Igual à view do Financeiro: o REVOKE vem antes (o Supabase dá acesso ao anon sozinho).
REVOKE SELECT ON vw_precificacao_conta FROM anon;
GRANT  SELECT ON vw_precificacao_conta TO authenticated;
NOTIFY pgrst, 'reload schema';

-- ═══ PASSO 3 — CONFERIR DEPOIS (só leitura) ═════════════════════════════════════════
-- A soma das contas tem que bater com o total do grupo na view do Financeiro.
-- Esperado: diferenca perto de zero (centavos de arredondamento) em todas as linhas.
SELECT g.mes, g.unidade, g.grupo, g.valor AS total_financeiro,
       coalesce(c.soma, 0) AS soma_das_contas,
       round(g.valor - coalesce(c.soma, 0), 2) AS diferenca
  FROM vw_precificacao_mensal g
  LEFT JOIN (SELECT mes, unidade, grupo, sum(valor) AS soma
               FROM vw_precificacao_conta GROUP BY 1, 2, 3) c
         ON c.mes = g.mes AND c.unidade = g.unidade AND c.grupo = g.grupo
 WHERE g.tipo = 'realizado'
   AND g.grupo NOT IN ('faturamento', 'pedidos', 'taxa_cartao', 'antecipacao_cartao', 'delivery_comissao')
 ORDER BY abs(g.valor - coalesce(c.soma, 0)) DESC, g.mes, g.unidade, g.grupo;
