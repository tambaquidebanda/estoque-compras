-- Nomes na ESTRUTURA que NAO casam com o cadastro E que NAO estao na lista de excluidos.
-- Ou seja: tira os fantasmas que voce ja excluiu e mostra so o que precisa de acao real
-- (os "quase iguais" que precisam ser renomeados/cadastrados para a baixa automatica).

WITH estr AS (
  SELECT DISTINCT s AS setor, g AS grupo, elem AS nome
  FROM inv_configuracoes ic
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(ic.valor)='object' THEN ic.valor ELSE '{}'::jsonb END) un(u, uval)
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(uval)='object' THEN uval ELSE '{}'::jsonb END) se(s, sval)
  CROSS JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(sval)='object' THEN sval ELSE '{}'::jsonb END) gr(g, arr)
  CROSS JOIN LATERAL jsonb_array_elements_text(CASE WHEN jsonb_typeof(arr)='array' THEN arr ELSE '[]'::jsonb END) elem
  WHERE ic.chave='estrutura'
),
en AS (
  SELECT setor, grupo, nome,
    btrim(translate(lower(nome),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn')) AS k
  FROM estr
),
prod AS (
  SELECT DISTINCT btrim(translate(lower(nome),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn')) AS k
  FROM est_produtos WHERE ativo IS NOT FALSE
),
map AS (
  SELECT btrim(translate(lower(kv.key),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn')) AS chave_k,
         btrim(translate(lower(kv.value),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn')) AS valor_k
  FROM inv_configuracoes, LATERAL jsonb_each_text(CASE WHEN jsonb_typeof(valor)='object' THEN valor ELSE '{}'::jsonb END) kv
  WHERE chave='mapeamentos'
),
excl AS (
  SELECT btrim(translate(lower(e),'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn')) AS k
  FROM inv_configuracoes, LATERAL jsonb_array_elements_text(CASE WHEN jsonb_typeof(valor)='array' THEN valor ELSE '[]'::jsonb END) e
  WHERE chave='excluidos'
)
SELECT DISTINCT en.setor, en.grupo, en.nome AS nome_na_estrutura
FROM en
WHERE NOT EXISTS (SELECT 1 FROM prod p WHERE p.k = en.k)
  AND NOT EXISTS (SELECT 1 FROM map m JOIN prod p ON p.k = m.valor_k WHERE m.chave_k = en.k)
  AND NOT EXISTS (SELECT 1 FROM excl x WHERE x.k = en.k)
ORDER BY en.setor, en.grupo, en.nome;
