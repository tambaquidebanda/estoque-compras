-- Reseta a estrutura de todas as unidades para vazio
-- O sistema vai recriar tudo automaticamente ao recarregar a página
-- usando o código estático do app.js (grupos completos para todas as unidades)
-- Execute no Supabase SQL Editor e depois recarregue o sistema

UPDATE inv_configuracoes
SET valor = '{}'::jsonb
WHERE chave = 'estrutura';
