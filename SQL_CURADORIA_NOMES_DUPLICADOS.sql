-- ============================================================================
-- SQL_CURADORIA_NOMES_DUPLICADOS.sql
--
-- O PROBLEMA
-- A tela de contagem NAO mostra o nome do cadastro: mostra o nome que esta em
-- inv_configuracoes['estrutura']. O nome do cadastro so e usado por baixo, via
-- inv_configuracoes['mapeamentos'], para achar o produto. Por isso "MP AZEITE"
-- aparece na tela sem existir no cadastro.
--
-- Quando DOIS nomes da estrutura caem no MESMO cadastro, o item aparece duas
-- vezes na contagem e os dois campos brigam pelo mesmo saldo.
--
-- Este arquivo faz a curadoria: cada item passa a ter UMA linha, com o nome do
-- cadastro. Nao mexe em saldo, nem em contagem, nem em historico - so na lista
-- de nomes que a tela monta.
--
-- ACENTOS: as regras da casa pedem SQL em ASCII puro, mas os dados tem acento
-- (Producao, MP LEITE EM PO). Por isso os literais com acento vao na forma
-- U&'...' com \00e7 no lugar do caractere - o texto que chega no banco e o
-- correto e o arquivo continua ASCII.
--
-- CIRURGICO: cada UPDATE reescreve UM array (uma unidade/setor/grupo),
-- filtrando UM nome e preservando a ordem dos outros. Nunca reset da estrutura.
--
-- FORA DAQUI
--   MP POLPA GRAVIOLA - nao e nome repetido, sao DOIS produtos de verdade
--   (pacote para o suco, 1 kg para o preparo do bar). Vai no arquivo
--   SQL_FIX_MAPEAMENTO_GRAVIOLA.sql.
--   Papel toalha Tork - ja esta certo, o mapeamento aponta para o interfolha
--   desde julho. Nao precisa de conserto.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confira quem some e quem fica em cada grupo.
-- ============================================================================
SELECT unid.key   AS unidade,
       setor.key  AS setor,
       grupo.key  AS grupo,
       jsonb_array_length(grupo.value) AS itens_no_grupo,
       grupo.value AS nomes
FROM inv_configuracoes c,
     jsonb_each(c.valor)      AS unid,
     jsonb_each(unid.value)   AS setor,
     jsonb_each(setor.value)  AS grupo
WHERE c.chave = 'estrutura'
  AND grupo.value @> to_jsonb('MP AZEITE'::text)
ORDER BY 1, 2, 3;

-- os mapeamentos que vao sair
SELECT c.valor -> 'MP AZEITE'                                   AS azeite,
       c.valor -> 'MP CAPSULA CHOCO CARAMEL'                    AS capsula,
       c.valor -> 'MP LEITE INTEGRAL C4'                        AS leite_c4,
       c.valor -> 'MP CONDENSADO LATA'                          AS condensado,
       c.valor -> U&'MP LEITE EM P\00d3'                         AS leite_po,
       c.valor -> 'MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA' AS bandeja,
       c.valor -> 'MC COPO LONG DRINK 300ML DESCARTAVEL'        AS copo
FROM inv_configuracoes c WHERE c.chave = 'mapeamentos';


-- ============================================================================
-- PASSO 2 - ESCREVE. Rode os blocos abaixo (pode ser todos de uma vez).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- RENOMEIA (nao remove): MP LEITE EM PO  ->  MP LEITE EM PO INTEGRAL
-- Onde: BAR / ESTIVAS, nas 4 unidades
-- Este par nao colide dentro do setor: "MP LEITE EM PO" e do BAR e "MP LEITE EM PO INTEGRAL" e da
-- COZINHA. Os dois so se encontram na tela do ESTOQUE DA LOJA, que junta os
-- grupos de todos os setores. Remover tiraria o item do BAR; renomear
-- deixa o BAR contando, agora com o nome do cadastro, e a tela do Estoque
-- da Loja passa a ver um nome so.
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'BAR', 'ESTIVAS'],
       (SELECT jsonb_agg(CASE WHEN e = to_jsonb(U&'MP LEITE EM P\00d3'::text)
                              THEN to_jsonb(U&'MP LEITE EM P\00d3 INTEGRAL'::text) ELSE e END ORDER BY ord)
          FROM jsonb_array_elements(valor #> ARRAY['Centro', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS'],
       (SELECT jsonb_agg(CASE WHEN e = to_jsonb(U&'MP LEITE EM P\00d3'::text)
                              THEN to_jsonb(U&'MP LEITE EM P\00d3 INTEGRAL'::text) ELSE e END ORDER BY ord)
          FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'BAR', 'ESTIVAS'],
       (SELECT jsonb_agg(CASE WHEN e = to_jsonb(U&'MP LEITE EM P\00d3'::text)
                              THEN to_jsonb(U&'MP LEITE EM P\00d3 INTEGRAL'::text) ELSE e END ORDER BY ord)
          FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'BAR', 'ESTIVAS'],
       (SELECT jsonb_agg(CASE WHEN e = to_jsonb(U&'MP LEITE EM P\00d3'::text)
                              THEN to_jsonb(U&'MP LEITE EM P\00d3 INTEGRAL'::text) ELSE e END ORDER BY ord)
          FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - U&'MP LEITE EM P\00d3' WHERE chave = 'mapeamentos';

-- ---------------------------------------------------------------------------
-- Sai da tela: MP AZEITE
-- Fica na tela: MP OLEO COMPOSTO
-- Onde: CHURRASQUEIRA / ESTIVAS, nas 4 unidades
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'CHURRASQUEIRA', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Centro', 'CHURRASQUEIRA', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP AZEITE'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'CHURRASQUEIRA', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'CHURRASQUEIRA', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP AZEITE'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'CHURRASQUEIRA', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'CHURRASQUEIRA', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP AZEITE'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'CHURRASQUEIRA', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'CHURRASQUEIRA', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP AZEITE'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - 'MP AZEITE' WHERE chave = 'mapeamentos';

-- ---------------------------------------------------------------------------
-- Sai da tela: MP CAPSULA CHOCO CARAMEL
-- Fica na tela: MP CAPSULA CHOCOLATE COM CARAMELO
-- Onde: BAR / ESTIVAS, nas 4 unidades
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Centro', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CAPSULA CHOCO CARAMEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CAPSULA CHOCO CARAMEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CAPSULA CHOCO CARAMEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CAPSULA CHOCO CARAMEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - 'MP CAPSULA CHOCO CARAMEL' WHERE chave = 'mapeamentos';

-- ---------------------------------------------------------------------------
-- Sai da tela: MP LEITE INTEGRAL C4
-- Fica na tela: MP LEITE LIQUIDO INTEGRAL
-- Onde: BAR / ESTIVAS, nas 4 unidades
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Centro', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP LEITE INTEGRAL C4'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP LEITE INTEGRAL C4'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP LEITE INTEGRAL C4'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP LEITE INTEGRAL C4'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - 'MP LEITE INTEGRAL C4' WHERE chave = 'mapeamentos';

-- ---------------------------------------------------------------------------
-- Sai da tela: MP CONDENSADO LATA
-- Fica na tela: MP LEITE CONDENSADO
-- Onde: BAR / ESTIVAS, nas 4 unidades
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Centro', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CONDENSADO LATA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CONDENSADO LATA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CONDENSADO LATA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'BAR', 'ESTIVAS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'BAR', 'ESTIVAS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MP CONDENSADO LATA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - 'MP CONDENSADO LATA' WHERE chave = 'mapeamentos';

-- ---------------------------------------------------------------------------
-- Sai da tela: MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA
-- Fica na tela: MC BANDEJA DE ALUMINIO D6
-- Onde: COZINHA / EMBALAGENS, nas 4 unidades
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'COZINHA', 'EMBALAGENS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Centro', 'COZINHA', 'EMBALAGENS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'EMBALAGENS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'EMBALAGENS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'COZINHA', 'EMBALAGENS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'COZINHA', 'EMBALAGENS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'COZINHA', 'EMBALAGENS'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'COZINHA', 'EMBALAGENS']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - 'MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA' WHERE chave = 'mapeamentos';

-- ---------------------------------------------------------------------------
-- Sai da tela: MC COPO LONG DRINK 300ML DESCARTAVEL
-- Fica na tela: MC COPO DESCARTAVEL 300ML
-- Onde: BAR / EMBALAGEMDESCAR, nas 4 unidades
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Centro', 'BAR', 'EMBALAGEMDESCAR'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Centro', 'BAR', 'EMBALAGEMDESCAR']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC COPO LONG DRINK 300ML DESCARTAVEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'EMBALAGEMDESCAR'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'EMBALAGEMDESCAR']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC COPO LONG DRINK 300ML DESCARTAVEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Delivery P10', 'BAR', 'EMBALAGEMDESCAR'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Delivery P10', 'BAR', 'EMBALAGEMDESCAR']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC COPO LONG DRINK 300ML DESCARTAVEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = jsonb_set(valor, ARRAY['Estoque Central', 'BAR', 'EMBALAGEMDESCAR'],
       COALESCE((SELECT jsonb_agg(e ORDER BY ord)
                   FROM jsonb_array_elements(valor #> ARRAY['Estoque Central', 'BAR', 'EMBALAGEMDESCAR']) WITH ORDINALITY t(e, ord)
                  WHERE e <> to_jsonb('MC COPO LONG DRINK 300ML DESCARTAVEL'::text)), '[]'::jsonb))
 WHERE chave = 'estrutura';

UPDATE inv_configuracoes SET valor = valor - 'MC COPO LONG DRINK 300ML DESCARTAVEL' WHERE chave = 'mapeamentos';


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Todas as contagens devem voltar 0.
-- ============================================================================
SELECT 'ainda na estrutura' AS o_que, count(*) AS quantas
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor,
     jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura'
  AND (grupo.value @> to_jsonb('MP AZEITE'::text)
    OR grupo.value @> to_jsonb('MP CAPSULA CHOCO CARAMEL'::text)
    OR grupo.value @> to_jsonb('MP LEITE INTEGRAL C4'::text)
    OR grupo.value @> to_jsonb('MP CONDENSADO LATA'::text)
    OR grupo.value @> to_jsonb(U&'MP LEITE EM P\00d3'::text)
    OR grupo.value @> to_jsonb('MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA'::text)
    OR grupo.value @> to_jsonb('MC COPO LONG DRINK 300ML DESCARTAVEL'::text))
UNION ALL
SELECT 'ainda no mapeamento', count(*)
FROM inv_configuracoes c
WHERE c.chave = 'mapeamentos'
  AND (c.valor ? 'MP AZEITE'
    OR c.valor ? 'MP CAPSULA CHOCO CARAMEL'
    OR c.valor ? 'MP LEITE INTEGRAL C4'
    OR c.valor ? 'MP CONDENSADO LATA'
    OR c.valor ? U&'MP LEITE EM P\00d3'
    OR c.valor ? 'MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA'
    OR c.valor ? 'MC COPO LONG DRINK 300ML DESCARTAVEL');
