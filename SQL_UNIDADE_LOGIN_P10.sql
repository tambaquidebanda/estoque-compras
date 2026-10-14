-- ============================================================
-- UNIDADE PELO LOGIN - celular do Delivery P10 (14/10/2026)
--
-- Marca o login "Delivery Parque 10" com unidade = Delivery P10.
-- Com isso o celular que entra com esse login abre direto no P10,
-- so mostra o botao do P10 e nao volta mais para o Centro.
-- Os outros logins (Loja Teatro, pessoais) nao mudam.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura: o login do P10 como esta hoje
-- Esperado: 1 linha, nome "Delivery Parque 10", sem "unidade".
select id, email, raw_user_meta_data
from auth.users
where id = '0988255c-03fc-4de9-a05f-12a0b23fe1f9';


-- PASSO 2 - marca a unidade (so mexe nesse login, e so se o e-mail bater)
-- Esperado: UPDATE 1
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || '{"unidade": "Delivery P10"}'::jsonb
where id = '0988255c-03fc-4de9-a05f-12a0b23fe1f9'
  and email = 'tdbdelivery.icomanda@gmail.com';


-- PASSO 3 - conferencia: quem tem unidade marcada
-- Esperado: 1 linha, tdbdelivery.icomanda@gmail.com, unidade = Delivery P10.
select email, raw_user_meta_data->>'nome' as nome, raw_user_meta_data->>'unidade' as unidade
from auth.users
where raw_user_meta_data ? 'unidade';


-- PARA DESFAZER (se precisar):
-- update auth.users
-- set raw_user_meta_data = raw_user_meta_data - 'unidade'
-- where id = '0988255c-03fc-4de9-a05f-12a0b23fe1f9';
