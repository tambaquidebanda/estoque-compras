-- Mesma analise do SQL_DIAG_PADROES_FALTANDO, mas UM PRODUTO POR LINHA,
-- com colunas em branco dos dias da semana (planilha de trabalho p/ Excel).
-- Exportar: rode e clique em "Download CSV" no resultado do Supabase -> abre no Excel.
-- Read-only, UMA unica instrucao.

WITH
estrut AS (
  SELECT DISTINCT
         setor.skey AS setor,
         grp.gkey   AS grupo,
         upper(trim(prod.pval #>> '{}')) AS produto
  FROM inv_configuracoes cfg
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(cfg.valor)='object' THEN cfg.valor ELSE '{}'::jsonb END) AS unidade(ukey, uval)
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(unidade.uval)='object' THEN unidade.uval ELSE '{}'::jsonb END) AS setor(skey, sval)
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(setor.sval)='object' THEN setor.sval ELSE '{}'::jsonb END) AS grp(gkey, gval)
  CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(grp.gval)='array' THEN grp.gval ELSE '[]'::jsonb END) AS prod(pval)
  WHERE cfg.chave='estrutura'
),
adic AS (
  SELECT DISTINCT
         split_part(a.key,'|',1) AS setor,
         split_part(a.key,'|',2) AS grupo,
         upper(trim(prod.pval #>> '{}')) AS produto
  FROM inv_configuracoes cfg
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(cfg.valor)='object' THEN cfg.valor ELSE '{}'::jsonb END) AS a(key, val)
  CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(a.val)='array' THEN a.val ELSE '[]'::jsonb END) AS prod(pval)
  WHERE cfg.chave='adicoes'
),
todos AS (
  SELECT setor, grupo, produto FROM estrut
  UNION
  SELECT setor, grupo, produto FROM adic
),
excl AS (
  SELECT upper(trim(e.val #>> '{}')) AS produto
  FROM inv_configuracoes cfg
  CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(cfg.valor)='array' THEN cfg.valor ELSE '[]'::jsonb END) AS e(val)
  WHERE cfg.chave='excluidos'
),
padr AS (
  SELECT split_part(p.key,'|',1) AS setor,
         split_part(p.key,'|',2) AS grupo,
         split_part(p.key,'|',3) AS produto
  FROM inv_configuracoes cfg
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(cfg.valor)='object' THEN cfg.valor ELSE '{}'::jsonb END) AS p(key, val)
  WHERE cfg.chave='padroes'
)
SELECT t.setor,
       t.grupo,
       t.produto,
       '' AS seg, '' AS ter, '' AS qua, '' AS qui,
       '' AS sex, '' AS sab, '' AS dom, '' AS feriado
FROM todos t
LEFT JOIN padr pd
       ON pd.setor=t.setor AND pd.grupo=t.grupo AND pd.produto=t.produto
WHERE pd.produto IS NULL
  AND t.produto <> ''
  AND t.setor <> 'ESTOQUE DA LOJA'
  AND t.produto NOT IN (SELECT produto FROM excl)
ORDER BY t.setor, t.grupo, t.produto;
