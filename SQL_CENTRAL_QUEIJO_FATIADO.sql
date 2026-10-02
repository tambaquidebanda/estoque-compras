-- ============================================================================
-- ESTOQUE CENTRAL: acrescenta "MP QUEIJO MUSSARELA FATIADO" na lista   (02/10/2026)
--
-- O pedido #01614 (queijo para o Centro e o P10) vai ser recebido no Central.
-- O queijo nao estava na lista de la: nao entrava na contagem do Central e, no
-- pedido de transferencia, so aparecia em "FORA DA LISTA".
-- Vai no grupo MATERIA PRIMA, ao lado do MP QUEIJO MUSSARELA BARRA.
--
-- Cirurgico: so ACRESCENTA um nome no fim de UM grupo. Nada mais muda.
-- Depois de rodar: F5 nas telas de Contagem/Transferencias.
-- ============================================================================

-- PASSO 1 (so leitura): o grupo hoje e se o queijo ja esta la (esperado: 27 / false)
SELECT jsonb_array_length(valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) AS itens_no_grupo,
       (valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) ? 'MP QUEIJO MUSSARELA FATIADO' AS ja_esta
  FROM inv_configuracoes WHERE chave = 'estrutura';

-- PASSO 2
UPDATE inv_configuracoes
   SET valor = jsonb_set(
         valor,
         ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA'],
         (valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) || '["MP QUEIJO MUSSARELA FATIADO"]'::jsonb)
 WHERE chave = 'estrutura'
   AND jsonb_typeof(valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) = 'array'
   AND NOT ((valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) ? 'MP QUEIJO MUSSARELA FATIADO');

-- PASSO 3 (conferencia): esperado 28 / true
SELECT jsonb_array_length(valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) AS itens_no_grupo,
       (valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL',U&'MAT\00c9RIA PRIMA']) ? 'MP QUEIJO MUSSARELA FATIADO' AS ja_esta
  FROM inv_configuracoes WHERE chave = 'estrutura';
