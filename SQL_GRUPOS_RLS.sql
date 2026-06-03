-- Política de leitura para todos os usuários autenticados e anon
CREATE POLICY "Leitura pública" ON est_grupos_produto
  FOR SELECT USING (true);

CREATE POLICY "Inserção autenticada" ON est_grupos_produto
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Exclusão autenticada" ON est_grupos_produto
  FOR DELETE USING (true);

-- Popula com os grupos já existentes em est_produtos (caso não tenha importado)
INSERT INTO est_grupos_produto (nome)
SELECT DISTINCT TRIM(categoria)
FROM est_produtos
WHERE categoria IS NOT NULL AND TRIM(categoria) <> ''
ON CONFLICT (nome) DO NOTHING;
