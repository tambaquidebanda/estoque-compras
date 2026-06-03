-- Cria tabela de grupos de produto
CREATE TABLE IF NOT EXISTS est_grupos_produto (
  id   SERIAL PRIMARY KEY,
  nome TEXT NOT NULL UNIQUE
);

-- Popula com os grupos já existentes em est_produtos
INSERT INTO est_grupos_produto (nome)
SELECT DISTINCT TRIM(categoria)
FROM est_produtos
WHERE categoria IS NOT NULL AND TRIM(categoria) <> ''
ON CONFLICT (nome) DO NOTHING;
