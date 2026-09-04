-- Lista os nomes que estão na ESTRUTURA de contagem (unidade Centro) mas NÃO têm
-- produto correspondente em est_produtos (depois de aplicar o mapeamento e ignorar
-- os excluídos). Esses são os itens que aparecem com ⚠ e nunca baixam o estoque.
-- Só leitura. Rode no editor SQL do Supabase.
WITH
estr AS (SELECT valor FROM inv_configuracoes WHERE chave = 'estrutura'),
mape AS (SELECT COALESCE(valor, '{}'::jsonb) AS v FROM inv_configuracoes WHERE chave = 'mapeamentos'),
excl AS (SELECT COALESCE(valor, '[]'::jsonb) AS v FROM inv_configuracoes WHERE chave = 'excluidos'),
nomes AS (
  SELECT DISTINCT setor.key AS setor, grupo.key AS grupo, prod AS nome
  FROM estr,
       jsonb_each(estr.valor)        AS unidade,   -- unidade -> setores
       jsonb_each(unidade.value)     AS setor,      -- setor   -> grupos
       jsonb_each(setor.value)       AS grupo,      -- grupo   -> [produtos]
       jsonb_array_elements_text(grupo.value) AS prod
  WHERE unidade.key = 'Centro'
),
alvo AS (
  SELECT n.setor, n.grupo, n.nome,
         COALESCE((SELECT v ->> n.nome FROM mape), n.nome) AS nome_cadastro
  FROM nomes n
  WHERE NOT ((SELECT v FROM excl) ? n.nome)
)
SELECT a.setor, a.grupo, a.nome AS nome_na_estrutura, a.nome_cadastro AS nome_esperado_no_cadastro
FROM alvo a
LEFT JOIN est_produtos p
  ON lower(translate(trim(p.nome),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'))
   = lower(translate(trim(a.nome_cadastro),
        'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
        'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'))
WHERE p.id IS NULL
ORDER BY a.setor, a.grupo, nome_na_estrutura;
