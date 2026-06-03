-- Adiciona campo de categoria do plano de contas em est_produtos
ALTER TABLE est_produtos ADD COLUMN IF NOT EXISTS plano_cat text;
NOTIFY pgrst, 'reload schema';
