-- Restaura os grupos de TODAS as unidades copiando a estrutura do Centro
-- Execute no Supabase SQL Editor
-- ATENÇÃO: isso substitui Delivery P10, Produção e Estoque Central pela estrutura do Centro.
-- Depois use "Gerenciar Setores" em cada unidade para remover setores que não se aplicam.

UPDATE inv_configuracoes
SET valor = jsonb_build_object(
  'Centro',          valor -> 'Centro',
  'Delivery P10',    valor -> 'Centro',
  'Produção',        valor -> 'Centro',
  'Estoque Central', valor -> 'Centro'
)
WHERE chave = 'estrutura'
  AND valor ? 'Centro';

-- Versão para restaurar só o Estoque Central (se as outras unidades já estiverem OK):
--
-- UPDATE inv_configuracoes
-- SET valor = jsonb_set(valor, '{Estoque Central}', (valor -> 'Centro'))
-- WHERE chave = 'estrutura' AND valor ? 'Centro';
