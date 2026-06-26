-- Restaura a estrutura de setores/grupos de todas as unidades
-- Execute no Supabase SQL Editor e depois recarregue o sistema
-- Isso vai recriar Centro, Delivery P10, Produção com a estrutura base
-- Estoque Central ficará apenas com PRODUÇÃO e ALMOXARIFADO

UPDATE inv_configuracoes
SET valor = '{}'::jsonb
WHERE chave = 'estrutura';
