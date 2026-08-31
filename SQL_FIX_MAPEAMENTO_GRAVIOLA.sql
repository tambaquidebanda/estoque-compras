-- ============================================================================
-- SQL_FIX_MAPEAMENTO_GRAVIOLA.sql
--
-- Nao e nome repetido: sao DOIS produtos de verdade.
--   MP POLPA GRAVIOLA        PC, fator 8   -> polpa de pacote, do suco
--   MP POLPA GRAVIOLA 1KG    KG, fator 1   -> a de 1 kg, do preparo do bar
--
-- A tela do BAR/POLPAS tem as duas linhas, certo. O errado esta no mapeamento:
-- "MP POLPA GRAVIOLA 1 KG" (com espaco antes do KG) aponta para o produto de
-- PACOTE. As duas linhas caiam no mesmo cadastro, brigavam pelo mesmo saldo, e
-- a linha de 1 kg - sempre 0 - apagava a contagem da de pacote. Foi assim que
-- a graviola contada 61 ficou com saldo 0 por cinco noites.
--
-- Aqui o mapeamento passa a apontar para o cadastro certo, o "MP POLPA
-- GRAVIOLA 1KG" (sem espaco), que ja existe. Nenhuma linha sai da tela.
--
-- DEPOIS DISTO: a de 1 kg comeca a ter saldo proprio, hoje zerado. O bar
-- precisa contar as duas na proxima contagem para as duas nascerem certas.
-- ============================================================================


-- PASSO 1 - SO LEITURA. Os dois cadastros existem?
SELECT id, nome, unidade_comp, unidade_uso, fator_conversao, ativo
FROM est_produtos
WHERE nome IN ('MP POLPA GRAVIOLA', 'MP POLPA GRAVIOLA 1KG')
ORDER BY nome;

-- para onde o mapeamento aponta hoje
SELECT valor -> 'MP POLPA GRAVIOLA 1 KG' AS aponta_hoje
FROM inv_configuracoes WHERE chave = 'mapeamentos';


-- PASSO 2 - ESCREVE. Aponta para o cadastro de 1 kg.
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['MP POLPA GRAVIOLA 1 KG'],
                         to_jsonb('MP POLPA GRAVIOLA 1KG'::text))
 WHERE chave = 'mapeamentos';


-- PASSO 3 - CONFERENCIA. Deve mostrar "MP POLPA GRAVIOLA 1KG".
SELECT valor -> 'MP POLPA GRAVIOLA 1 KG' AS aponta_agora
FROM inv_configuracoes WHERE chave = 'mapeamentos';
