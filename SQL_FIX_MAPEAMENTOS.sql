-- Corrige os 2 nomes da estrutura que não casavam no cadastro, ajustando o MAPEAMENTO
-- para o produto real (ambos já existem em est_produtos). Cirúrgico: só troca/insere
-- essas 2 chaves; não mexe no resto. jsonb_set cria a chave se não existir.
UPDATE inv_configuracoes
SET valor = jsonb_set(
              jsonb_set(valor,
                        ARRAY['MP POLPA CUPUAÇU 1 KG'], '"MP POLPA DE CUPUAÇU 1KG"'::jsonb),
              ARRAY['MC EMBALAGEM G742'], '"MC EMBALAGEM G742 (MOLHEIRA)"'::jsonb)
WHERE chave = 'mapeamentos'
RETURNING valor -> 'MP POLPA CUPUAÇU 1 KG'  AS cupuacu_novo_alvo,
          valor -> 'MC EMBALAGEM G742'      AS g742_novo_alvo;
