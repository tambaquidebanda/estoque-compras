-- ============================================================
-- UNIDADE PELO LOGIN - Gisele Guimaraes no Delivery P10 (14/10/2026)
--
-- Desde 14/10 so conta/pede para o Delivery P10 quem tem o login marcado
-- com unidade = Delivery P10. O login do P10 ja foi marcado
-- (SQL_UNIDADE_LOGIN_P10.sql). Este marca o da Gisele: com ele o celular
-- abre direto no P10 e fica no P10, igual ao login do P10.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura: o login da Gisele como esta hoje
-- Esperado: 1 linha, nome "Gisele Guimaraes", sem "unidade".
select id, email, raw_user_meta_data
from auth.users
where id = 'd3e38e95-ec13-4ab3-a3cb-21edc98a874c';


-- PASSO 2 - marca a unidade (so esse login, e so se o e-mail bater)
-- Esperado: UPDATE 1
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || '{"unidade": "Delivery P10"}'::jsonb
where id = 'd3e38e95-ec13-4ab3-a3cb-21edc98a874c'
  and email = 'guimaraesalves2016@gmail.com';


-- PASSO 3 - conferencia: quem tem unidade marcada
-- Esperado: 2 linhas (Delivery Parque 10 e Gisele Guimaraes), unidade = Delivery P10.
select email, raw_user_meta_data->>'nome' as nome, raw_user_meta_data->>'unidade' as unidade
from auth.users
where raw_user_meta_data ? 'unidade';


-- PARA DESFAZER (se precisar):
-- update auth.users
-- set raw_user_meta_data = raw_user_meta_data - 'unidade'
-- where id = 'd3e38e95-ec13-4ab3-a3cb-21edc98a874c';
