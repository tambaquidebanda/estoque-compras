-- ============================================================================
-- SQL_LIMPEZA_CONGELADOS.sql
--
-- Tira tres linhas mortas da tela de COZINHA / CONGELADOS e mata o estoque
-- fantasma que elas alimentavam.
--
-- O QUE ESTA ACONTECENDO
-- A tela mostra DUAS linhas para o mesmo item fisico. A linha velha vem da
-- `estrutura` e passa por um `mapeamento` que aponta para um cadastro morto.
-- A linha nova veio depois pelas `adicoes` e aponta para o cadastro certo:
--
--   linha velha (estrutura)              grava em              linha nova (adicoes)
--   ---------------------------------------------------------------------------
--   SA BOLINHO DE PIRARUCU 5 UN          produto INATIVO       SA BOLINHO DE PIRARUCU FRESCO 5 UNID
--   SA CAMARAO COM.CATUPIRY 4 UNID       produto INATIVO       SA CAMARAO COM CATUPIRY 6 UNID
--   SA PIRARUCU FRESCO DESFIADO 150g     LUGAR NENHUM          SA PIRARUCU SALMOURADO DESFIADO 150g
--
-- As tres novas foram contadas em 02/09/2026 e sao o que as fichas ativas usam.
--
-- NAO E O BUG DE ZERAR SALDO. As linhas velha e nova apontam para produto_id
-- DIFERENTE, entao cada uma escreve na sua propria linha de saldo. Ninguem
-- sobrescreve ninguem. O prejuizo e outro:
--
--   1. o time conta o mesmo bolinho duas vezes;
--   2. uma das contagens cai num cadastro inativo e fica presa la;
--   3. R$ 29.702,82 de estoque fantasma, parado desde 03/08/2026:
--
--        R$ 28.168,51   SA BOLINHO DE PIRARUCU 5 UNID    ESTOQUE_LOJA = 102
--        R$  1.380,81   SA BOLINHO DE PIRARUCU 5 UNID    COZINHA      = 5
--        R$     98,68   SA CAMARAO COM CATUPIRY 4 UNID   COZINHA      = 9
--        R$     54,82   SA CAMARAO COM CATUPIRY 4 UNID   ESTOQUE_LOJA = 5
--
--      Os R$ 28 mil sao custo errado tambem: esse cadastro esta com R$ 276,16
--      por unidade, e o bolinho fresco ativo custa R$ 3,36.
--
-- ISSO NAO TRAVA A BAIXA. E limpeza: tira ruido da tela e tira ficcao da
-- valorizacao do estoque.
--
-- POR QUE APAGAR A LINHA E NAO REAPONTAR O MAPEAMENTO
-- Porque o produto certo JA ESTA na tela, pelas adicoes. Reapontar criaria
-- duas linhas para o MESMO produto_id no MESMO setor - e ai sim viraria o bug
-- que zera saldo (a segunda linha sobrescreve a primeira).
--
-- ACENTOS: escritos como U&'...\00c3...' para o arquivo ficar ASCII puro.
--   \00c3 = A com til   ->  CAMARAO vira CAMARAO com til
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confirmar tudo antes de mexer.
-- ============================================================================

-- 1a) as tres linhas velhas e para onde cada uma aponta hoje
SELECT key AS linha_na_tela, value AS mapeada_para
FROM inv_configuracoes, jsonb_each_text(valor)
WHERE chave = 'mapeamentos'
  AND key IN ('SA BOLINHO DE PIRARUCU 5 UN',
              U&'SA CAMAR\00c3O COM.CATUPIRY 4 UNID',
              'SA PIRARUCU FRESCO DESFIADO 150g');
-- Esperado: 3 linhas.
--   SA BOLINHO DE PIRARUCU 5 UN       -> SA BOLINHO DE PIRARUCU 5 UNID
--   SA CAMARAO COM.CATUPIRY 4 UNID    -> SA CAMARAO COM CATUPIRY 4 UNID
--   SA PIRARUCU FRESCO DESFIADO 150g  -> SA PIRARUCU FRESCO DESF 150g

-- 1b) prova de que o destino de cada uma esta morto
SELECT p.nome, p.ativo, p.custo_comp,
       (SELECT string_agg(s.local || '=' || s.saldo, ' | ' ORDER BY s.local)
          FROM est_saldo_local s WHERE s.produto_id = p.id) AS saldo
FROM est_produtos p
WHERE p.nome IN ('SA BOLINHO DE PIRARUCU 5 UNID',
                 'SA CAMARAO COM CATUPIRY 4 UNID',
                 'SA PIRARUCU FRESCO DESF 150g');
-- Esperado: 2 linhas, as duas com ativo = false e saldo parado.
-- 'SA PIRARUCU FRESCO DESF 150g' NAO aparece - esse nem existe.

-- 1c) prova de que o produto CERTO ja esta na tela e sendo contado
SELECT p.nome, p.ativo,
       (SELECT string_agg(s.local || '=' || s.saldo || ' (' || s.updated_at::date || ')',
                          ' | ' ORDER BY s.local)
          FROM est_saldo_local s WHERE s.produto_id = p.id) AS saldo
FROM est_produtos p
WHERE p.nome IN ('SA BOLINHO DE PIRARUCU FRESCO 5 UNID',
                 'SA CAMARAO COM CATUPIRY 6 UNID',
                 'SA PIRARUCU SALMOURADO DESFIADO 150g')
ORDER BY p.nome;
-- Esperado: 3 linhas, todas ativas, todas com saldo de 02/09/2026.

-- 1d) e que eles estao nas adicoes de COZINHA|CONGELADOS
SELECT jsonb_pretty(valor -> 'COZINHA|CONGELADOS') AS adicoes_congelados
FROM inv_configuracoes WHERE chave = 'adicoes';
-- Esperado: a lista contem os tres nomes do 1c.

-- 1e) quantas vezes cada linha velha ja foi contada
SELECT i.nome,
       count(*)                                   AS linhas,
       count(i.produto_id)                        AS foram_para_um_produto,
       count(*) - count(i.produto_id)             AS foram_para_lugar_nenhum,
       max(v.data)                                AS ultima_vez
FROM est_inventario_itens i
LEFT JOIN est_inventarios v ON v.id = i.inventario_id
WHERE i.nome IN ('SA BOLINHO DE PIRARUCU 5 UN',
                 U&'SA CAMAR\00c3O COM.CATUPIRY 4 UNID',
                 'SA PIRARUCU FRESCO DESFIADO 150g')
GROUP BY i.nome ORDER BY i.nome;
-- So para ver o tamanho do desperdicio. Nao muda nada.


-- ============================================================================
-- PASSO 2 - ESCREVE. Tira as tres linhas da estrutura, nas 4 unidades.
--
-- Reconstroi so o array COZINHA/CONGELADOS de cada unidade, sem os tres nomes.
-- Cirurgico: jsonb_set num caminho especifico. Nao toca em outro setor, outro
-- grupo, nem em outra chave.
-- ============================================================================
DO $$
DECLARE
  u text;
  caminho text[];
  lista jsonb;
  fora  text[] := ARRAY['SA BOLINHO DE PIRARUCU 5 UN',
                        U&'SA CAMAR\00c3O COM.CATUPIRY 4 UNID',
                        'SA PIRARUCU FRESCO DESFIADO 150g'];
BEGIN
  FOR u IN SELECT key FROM inv_configuracoes, jsonb_each(valor) WHERE chave = 'estrutura'
  LOOP
    caminho := ARRAY[u, 'COZINHA', 'CONGELADOS'];
    SELECT valor #> caminho INTO lista FROM inv_configuracoes WHERE chave = 'estrutura';
    CONTINUE WHEN lista IS NULL;

    UPDATE inv_configuracoes
       SET valor = jsonb_set(valor, caminho, (
             SELECT COALESCE(jsonb_agg(x ORDER BY ord), '[]'::jsonb)
               FROM jsonb_array_elements(lista) WITH ORDINALITY AS t(x, ord)
              WHERE NOT (x #>> '{}' = ANY (fora))))
     WHERE chave = 'estrutura';

    RAISE NOTICE 'unidade % : COZINHA/CONGELADOS foi de % para % nomes',
      u, jsonb_array_length(lista),
      jsonb_array_length((SELECT valor #> caminho FROM inv_configuracoes WHERE chave = 'estrutura'));
  END LOOP;
END $$;
-- Esperado: 4 avisos, cada um dizendo que caiu 3 nomes.


-- ============================================================================
-- PASSO 3 - ESCREVE. Apaga os tres mapeamentos, que agora nao servem a nada.
--
-- O `-` com array remove varias chaves de uma vez e deixa as outras 51
-- intactas. Rodar de novo nao da erro.
-- ============================================================================
UPDATE inv_configuracoes
   SET valor = valor - ARRAY['SA BOLINHO DE PIRARUCU 5 UN',
                             U&'SA CAMAR\00c3O COM.CATUPIRY 4 UNID',
                             'SA PIRARUCU FRESCO DESFIADO 150g']
 WHERE chave = 'mapeamentos';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 4 - ESCREVE. Mata o saldo fantasma dos dois cadastros inativos.
--
-- So a linha de saldo. A contagem historica (est_inventario_itens) fica -
-- e registro do que foi contado de verdade, mesmo que no cadastro errado.
-- ============================================================================
DELETE FROM est_saldo_local
 WHERE produto_id IN (SELECT id FROM est_produtos
                       WHERE nome IN ('SA BOLINHO DE PIRARUCU 5 UNID',
                                      'SA CAMARAO COM CATUPIRY 4 UNID')
                         AND ativo = false);
-- Esperado: DELETE 4.


-- ============================================================================
-- PASSO 5 - CONFERENCIA.
-- ============================================================================

-- 5a) os tres mapeamentos sumiram
SELECT count(*) AS ainda_existem
FROM inv_configuracoes, jsonb_each_text(valor)
WHERE chave = 'mapeamentos'
  AND key IN ('SA BOLINHO DE PIRARUCU 5 UN',
              U&'SA CAMAR\00c3O COM.CATUPIRY 4 UNID',
              'SA PIRARUCU FRESCO DESFIADO 150g');
-- Esperado: 0

-- 5b) e o resto dos mapeamentos continua la
SELECT count(*) AS total_mapeamentos
FROM inv_configuracoes, jsonb_each_text(valor) WHERE chave = 'mapeamentos';
-- Esperado: 51  (eram 54, menos as 3)

-- 5c) as tres linhas sairam da tela nas 4 unidades
SELECT u.key AS unidade, count(*) AS linhas_velhas_restantes
FROM inv_configuracoes,
     jsonb_each(valor) AS u,
     jsonb_array_elements_text(u.value #> ARRAY['COZINHA','CONGELADOS']) AS t(x)
WHERE chave = 'estrutura'
  AND x IN ('SA BOLINHO DE PIRARUCU 5 UN',
            U&'SA CAMAR\00c3O COM.CATUPIRY 4 UNID',
            'SA PIRARUCU FRESCO DESFIADO 150g')
GROUP BY u.key;
-- Esperado: NENHUMA LINHA no resultado.

-- 5d) o estoque fantasma acabou
SELECT count(*) AS linhas, COALESCE(sum(s.saldo * p.custo_comp), 0) AS valor_fantasma
FROM est_saldo_local s
JOIN est_produtos p ON p.id = s.produto_id
WHERE p.ativo = false AND s.saldo <> 0;
-- Esperado: 0 e 0. (Eram 4 linhas e R$ 29.702,82.)

-- 5e) e os produtos CERTOS continuam na tela e com saldo
SELECT p.nome, p.ativo,
       (SELECT string_agg(s.local || '=' || s.saldo, ' | ' ORDER BY s.local)
          FROM est_saldo_local s WHERE s.produto_id = p.id) AS saldo
FROM est_produtos p
WHERE p.nome IN ('SA BOLINHO DE PIRARUCU FRESCO 5 UNID',
                 'SA CAMARAO COM CATUPIRY 6 UNID',
                 'SA PIRARUCU SALMOURADO DESFIADO 150g')
ORDER BY p.nome;
-- Esperado: os tres intactos, com o saldo de 02/09.
