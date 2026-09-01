-- ============================================================================
-- SQL_FUNCIONARIO_BATATA.sql
--
-- No grupo COZINHA | COMIDA FUNCIONARIO, troca o produto do restaurante pelo
-- produto do funcionario:
--
--     MP BATATA PORTUGUESA  ->  MC BATATA PORTUGUESA ( FUNCIONARIO )
--
-- POR QUE
-- O saldo e guardado por PRODUTO + SETOR. Como a MP BATATA PORTUGUESA tambem
-- esta em COZINHA | HORTIFRUTI, os dois grupos gravam na MESMA linha de saldo e
-- um apaga o outro - e se o grupo salvo por ultimo estiver vazio, ele grava
-- ZERO em cima de uma contagem boa. Foi o que aconteceu com o MP ACUCAR na
-- contagem de 01/09 (ESTIVAS=1 -> COMIDA FUNCIONARIO=0).
--
-- Apontando para o cadastro proprio do funcionario, o conflito acaba: sao dois
-- produtos diferentes, logo duas linhas de saldo diferentes. Nao precisa criar
-- setor novo nem desempate no robo.
--
-- Wagner confirmou em 01/09 que o certo e o MC BATATA PORTUGUESA ( FUNCIONARIO ).
--
-- A estrutura e a mesma nas 4 unidades (Centro, Producao, Delivery P10,
-- Estoque Central). O bloco abaixo troca em TODAS, para nao criarem divergencia
-- entre si.
--
-- O acucar, as polpas e o kit de tambaqui estao no SQL_FUNCIONARIO_TROCAS.sql.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA.
-- ============================================================================

-- 1a) Confirma que o produto do funcionario existe e esta ativo.
SELECT id, nome, ativo, custo_comp
FROM est_produtos
WHERE nome IN ('MC BATATA PORTUGUESA ( FUNCIONARIO )', 'MP BATATA PORTUGUESA');

-- 1b) Onde a MP BATATA PORTUGUESA aparece hoje, unidade por unidade.
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor)     AS unid,
     jsonb_each(unid.value)  AS setor,
     jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura'
  AND grupo.value @> '["MP BATATA PORTUGUESA"]'::jsonb
ORDER BY 1, 2, 3;
-- Esperado: 8 linhas - HORTIFRUTI e COMIDA FUNCIONARIO, nas 4 unidades.


-- ============================================================================
-- PASSO 2 - ESCREVE. A troca, so no grupo do funcionario.
--
-- O laco procura, em cada unidade, os grupos da COZINHA cujo nome contem
-- FUNCION. Assim nao depende de acento no nome do grupo. O grupo HORTIFRUTI
-- nao e tocado: a batata do restaurante continua la.
-- ============================================================================
DO $$
DECLARE
  u text; g text; caminho text[]; lista jsonb;
BEGIN
  FOR u IN SELECT key FROM inv_configuracoes, jsonb_each(valor) WHERE chave = 'estrutura'
  LOOP
    FOR g IN SELECT key FROM inv_configuracoes,
                    jsonb_each(valor #> ARRAY[u, 'COZINHA'])
              WHERE chave = 'estrutura' AND key LIKE '%FUNCION%'
    LOOP
      caminho := ARRAY[u, 'COZINHA', g];
      SELECT valor #> caminho INTO lista FROM inv_configuracoes WHERE chave = 'estrutura';
      CONTINUE WHEN lista IS NULL OR NOT (lista @> '["MP BATATA PORTUGUESA"]'::jsonb);

      UPDATE inv_configuracoes
         SET valor = jsonb_set(valor, caminho, (
               SELECT jsonb_agg(CASE WHEN x = '"MP BATATA PORTUGUESA"'::jsonb
                                     THEN '"MC BATATA PORTUGUESA ( FUNCIONARIO )"'::jsonb
                                     ELSE x END ORDER BY ord)
                 FROM jsonb_array_elements(lista) WITH ORDINALITY AS t(x, ord)))
       WHERE chave = 'estrutura';

      RAISE NOTICE 'trocado em % / COZINHA / %', u, g;
    END LOOP;
  END LOOP;
END $$;
-- Deve mostrar 4 avisos NOTICE, um por unidade.


-- ============================================================================
-- PASSO 3 - REMOVIDO. NAO RODE NADA AQUI.
--
-- Aqui havia um passo opcional que APAGAVA o MP ACUCAR do grupo, porque eu
-- nao tinha achado cadastro de acucar de funcionario. Eu tinha procurado pelo
-- NOME (produtos com FUNCIONARIO escrito no nome) e o certo era procurar pela
-- CATEGORIA: existe sim o MC ACUCAR, categoria MC REFEICAO/CONSUMO
-- FUNCIONARIOS. O Wagner apontou em 01/09.
--
-- Entao o acucar tem o mesmo conserto da batata - troca, nao remocao - e ele
-- esta junto com as polpas no SQL_FUNCIONARIO_TROCAS.sql. Rode aquele.
-- ============================================================================


-- ============================================================================
-- PASSO 4 - CONFERENCIA.
-- ============================================================================

-- 4a) A batata do restaurante ficou so no HORTIFRUTI (4 linhas, uma por unidade).
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor, jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura' AND grupo.value @> '["MP BATATA PORTUGUESA"]'::jsonb
ORDER BY 1, 2, 3;

-- 4b) A batata do funcionario esta no grupo dela (4 linhas).
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor, jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura'
  AND grupo.value @> '["MC BATATA PORTUGUESA ( FUNCIONARIO )"]'::jsonb
ORDER BY 1, 2, 3;

-- 4c) O grupo continua com o mesmo tamanho - trocou, nao perdeu ninguem.
--     Esperado: 23 em cada unidade. A troca nao muda o tamanho do grupo.
SELECT unid.key AS unidade, jsonb_array_length(grupo.value) AS nomes_no_grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor, jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura' AND setor.key = 'COZINHA' AND grupo.key LIKE '%FUNCION%'
ORDER BY 1;


-- ============================================================================
-- AINDA MISTURADOS NO GRUPO DO FUNCIONARIO, sem decisao ainda
-- Estes quatro nao apagam contagem de ninguem (nao estao repetidos na COZINHA),
-- entao nao ha pressa - mas continuam descontando do estoque do restaurante:
--
--     MP ACUCAR, MP POLPA MANGA 1KG, MP POLPA GOIABA 1KG
--         -> tem gemeo e estao no SQL_FUNCIONARIO_TROCAS.sql
--     MP KIT DE TAMBAQUI  -> o Wagner esta confirmando
--     MP FEIJAO DE CORDA  -> ja esta na categoria Comida Funcionario; ver o
--                            outro arquivo antes de mexer
-- ============================================================================
