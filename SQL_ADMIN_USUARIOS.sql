-- ═══════════════════════════════════════════════════════════════
-- SQL_ADMIN_USUARIOS — marca quem é ADMINISTRADOR (pode gerenciar usuários)
--
-- A tela Usuários agora passa pela Edge Function "admin-usuarios", que só
-- atende quem tiver  app_metadata.admin = true.
-- app_metadata não pode ser alterado pelo próprio usuário no navegador
-- (diferente de user_metadata); só por aqui (SQL Editor) ou pela chave de serviço.
--
-- RODAR NO SQL EDITOR DO SUPABASE, ANTES de publicar o app.js novo.
-- Troque SEU_EMAIL_AQUI pelo e-mail do dono. O repositório é público:
-- NÃO salve o arquivo com o e-mail real.
-- ═══════════════════════════════════════════════════════════════

-- 1) Conferir antes: quem já é admin e se o e-mail existe
SELECT id, email, raw_app_meta_data->>'admin' AS admin
FROM auth.users
WHERE lower(email) = lower('SEU_EMAIL_AQUI')
   OR raw_app_meta_data->>'admin' = 'true';

-- 2) Marcar o dono como admin (mexe só na chave "admin"; provider/providers ficam)
UPDATE auth.users
SET raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"admin": true}'::jsonb
WHERE lower(email) = lower('SEU_EMAIL_AQUI');
-- esperado: UPDATE 1  (se der 0, o e-mail está diferente do cadastro)

-- 3) Conferir depois: deve aparecer só quem você quer como admin
SELECT id, email FROM auth.users WHERE raw_app_meta_data->>'admin' = 'true';

-- Vale na hora: a função lê a marca direto do cadastro a cada chamada
-- (não precisa sair e entrar de novo).

-- Para tirar o admin de alguém:
-- UPDATE auth.users SET raw_app_meta_data = raw_app_meta_data - 'admin'
-- WHERE lower(email) = lower('EMAIL_DA_PESSOA');
