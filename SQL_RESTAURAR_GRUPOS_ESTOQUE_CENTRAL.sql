-- Restaura os grupos do Estoque Central copiando a estrutura do Centro
-- Execute no Supabase SQL Editor
-- ATENÇÃO: isso vai substituir a estrutura do Estoque Central pela do Centro.
-- Depois use "Gerenciar Setores" para remover os setores que não se aplicam ao Estoque Central.

UPDATE inv_configuracoes
SET valor = jsonb_set(
  valor,
  '{Estoque Central}',
  (valor -> 'Centro')
)
WHERE chave = 'estrutura'
  AND valor ? 'Centro';

-- Se preferir restaurar TODAS as unidades a partir do Centro de uma vez:
-- (descomente abaixo e comente o UPDATE acima)
--
-- UPDATE inv_configuracoes
-- SET valor = jsonb_build_object(
--   'Centro',        valor -> 'Centro',
--   'Delivery P10',  valor -> 'Centro',
--   'Produção',      valor -> 'Centro',
--   'Estoque Central', valor -> 'Centro'
-- )
-- WHERE chave = 'estrutura'
--   AND valor ? 'Centro';
