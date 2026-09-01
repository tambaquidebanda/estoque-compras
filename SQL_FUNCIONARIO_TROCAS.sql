-- ============================================================================
-- SQL_FUNCIONARIO_TROCAS.sql
--
-- Continua o SQL_FUNCIONARIO_BATATA.sql. Aponta o resto do grupo
-- COZINHA | COMIDA FUNCIONARIO para os cadastros de funcionario:
--
--     MP ACUCAR            ->  MC ACUCAR
--     MP POLPA MANGA 1KG   ->  MC POLPA MANGA 1KG
--     MP POLPA GOIABA 1KG  ->  MC POLPA GOIABA 1KG
--     MP KIT DE TAMBAQUI   ->  MC KIT DE TAMBAQUI      (PASSO 3)
--
-- POR QUE ISSO IMPORTA
-- O acucar e o caso urgente: ele esta em COZINHA | ESTIVAS e tambem em
-- COZINHA | COMIDA FUNCIONARIO. Como o saldo e por PRODUTO + SETOR, os dois
-- grupos gravam na MESMA linha e um apaga o outro. Na contagem de 01/09
-- ESTIVAS gravou 1 e COMIDA FUNCIONARIO gravou 0 por cima. Apontando para o
-- MC ACUCAR viram dois produtos, duas linhas, e o conflito acaba.
--
-- As polpas e o kit nao apagam contagem de ninguem (nao estao repetidos dentro
-- da COZINHA), mas hoje o consumo do funcionario sai do estoque do restaurante
-- e com o custo do restaurante. A troca poe cada coisa no seu lugar.
--
-- SOBRE OS ACENTOS
-- A estrutura guarda 'MP ACUCAR' sem acento e o cadastro tem 'MP ACUCAR' com
-- cedilha. Isso sempre funcionou porque o sistema tira acento antes de
-- comparar, entao 'MC ACUCAR' vai casar com o 'MC ACUCAR' do cadastro do mesmo
-- jeito. E a convencao que ja esta em uso ali.
--
-- FICA DE FORA: MP FEIJAO DE CORDA. Diferente dos outros, ele JA esta na
-- categoria "Comida Funcionario" - nao e produto do restaurante no lugar
-- errado. E existem dois candidatos com nomes parecidos e unidades
-- diferentes (MC FEIJAO DE CORDA em UN, MC FEIJAO PRAIA FUNCIONARIO em KG),
-- o que muda o que o time escreve na contagem. Precisa de decisao antes.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA.
-- ============================================================================

-- 1a) Os produtos de destino existem, estao ativos, e com que unidade.
SELECT nome, ativo, unidade_comp, custo_comp, categoria
FROM est_produtos
WHERE nome IN ('MC ACUCAR', 'MC POLPA MANGA 1KG', 'MC POLPA GOIABA 1KG', 'MC KIT DE TAMBAQUI')
   OR nome ILIKE 'MC A%CAR'   -- pega o 'MC ACUCAR' com cedilha e acento
ORDER BY nome;
-- Esperado: os quatro, ativos, categoria de funcionario.

-- 1b) Onde estao hoje os que vao sair.
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo, x AS nome
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor,
     jsonb_each(setor.value) AS grupo, jsonb_array_elements_text(grupo.value) x
WHERE c.chave = 'estrutura'
  AND x IN ('MP ACUCAR', 'MP POLPA MANGA 1KG', 'MP POLPA GOIABA 1KG', 'MP KIT DE TAMBAQUI')
ORDER BY 4, 1, 2, 3;
-- O acucar deve aparecer em 3 grupos por unidade (BAR|ESTIVAS, COZINHA|ESTIVAS
-- e COZINHA|COMIDA FUNCIONARIO). So o do funcionario e trocado.


-- ============================================================================
-- PASSO 2 - ESCREVE. Acucar e as duas polpas.
--
-- So dentro do grupo da COZINHA cujo nome contem FUNCION. O acucar das
-- ESTIVAS e do BAR nao e tocado, nem a polpa do BAR.
-- ============================================================================
DO $$
DECLARE
  u text; g text; caminho text[]; lista jsonb; par record;
BEGIN
  FOR par IN SELECT * FROM (VALUES
        ('MP ACUCAR',           'MC ACUCAR'),
        ('MP POLPA MANGA 1KG',  'MC POLPA MANGA 1KG'),
        ('MP POLPA GOIABA 1KG', 'MC POLPA GOIABA 1KG')
      ) AS t(de, para)
  LOOP
    FOR u IN SELECT key FROM inv_configuracoes, jsonb_each(valor) WHERE chave = 'estrutura'
    LOOP
      FOR g IN SELECT key FROM inv_configuracoes,
                      jsonb_each(valor #> ARRAY[u, 'COZINHA'])
                WHERE chave = 'estrutura' AND key LIKE '%FUNCION%'
      LOOP
        caminho := ARRAY[u, 'COZINHA', g];
        SELECT valor #> caminho INTO lista FROM inv_configuracoes WHERE chave = 'estrutura';
        CONTINUE WHEN lista IS NULL OR NOT (lista @> to_jsonb(ARRAY[par.de]));

        UPDATE inv_configuracoes
           SET valor = jsonb_set(valor, caminho, (
                 SELECT jsonb_agg(CASE WHEN x = to_jsonb(par.de)
                                       THEN to_jsonb(par.para) ELSE x END ORDER BY ord)
                   FROM jsonb_array_elements(lista) WITH ORDINALITY AS t(x, ord)))
         WHERE chave = 'estrutura';

        RAISE NOTICE '% -> % em % / COZINHA / %', par.de, par.para, u, g;
      END LOOP;
    END LOOP;
  END LOOP;
END $$;
-- Esperado: 12 avisos NOTICE (3 produtos x 4 unidades).
-- Se o acucar nao aparecer nos avisos, e porque voce rodou o PASSO 3 antigo do
-- SQL_FUNCIONARIO_BATATA.sql, que o apagava. Me avise que eu devolvo.


-- ============================================================================
-- PASSO 3 - ESCREVE. O kit de tambaqui.
--
-- Confirmado pelo Wagner em 01/09: o kit da refeicao do funcionario e o
-- MC KIT DE TAMBAQUI, categoria MC REFEICAO/CONSUMO FUNCIONARIOS, KG na
-- compra e no uso, custo 35,00. Mesma unidade do MP que sai, entao o time
-- nao muda nada no que escreve na contagem.
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
      CONTINUE WHEN lista IS NULL OR NOT (lista @> '["MP KIT DE TAMBAQUI"]'::jsonb);

      UPDATE inv_configuracoes
         SET valor = jsonb_set(valor, caminho, (
               SELECT jsonb_agg(CASE WHEN x = '"MP KIT DE TAMBAQUI"'::jsonb
                                     THEN '"MC KIT DE TAMBAQUI"'::jsonb ELSE x END ORDER BY ord)
                 FROM jsonb_array_elements(lista) WITH ORDINALITY AS t(x, ord)))
       WHERE chave = 'estrutura';

      RAISE NOTICE 'kit trocado em % / COZINHA / %', u, g;
    END LOOP;
  END LOOP;
END $$;


-- ============================================================================
-- PASSO 4 - CONFERENCIA.
-- ============================================================================

-- 4a) O grupo do funcionario nao pode ter mais nenhum MP, tirando o feijao
--     de corda, que ficou de fora de proposito. Esperado: so ele.
SELECT unid.key AS unidade, x AS ainda_MP
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor,
     jsonb_each(setor.value) AS grupo, jsonb_array_elements_text(grupo.value) x
WHERE c.chave = 'estrutura' AND setor.key = 'COZINHA' AND grupo.key LIKE '%FUNCION%'
  AND x LIKE 'MP %'
ORDER BY 1, 2;

-- 4b) O acucar do restaurante continua nas estivas (BAR e COZINHA).
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor, jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura' AND grupo.value @> '["MP ACUCAR"]'::jsonb
ORDER BY 1, 2, 3;
-- Esperado: BAR|ESTIVAS e COZINHA|ESTIVAS em cada unidade. Nenhum FUNCION.

-- 4c) Tamanho do grupo intacto: 23 por unidade. Trocou, nao perdeu ninguem.
SELECT unid.key AS unidade, jsonb_array_length(grupo.value) AS nomes_no_grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor) AS unid, jsonb_each(unid.value) AS setor, jsonb_each(setor.value) AS grupo
WHERE c.chave = 'estrutura' AND setor.key = 'COZINHA' AND grupo.key LIKE '%FUNCION%'
ORDER BY 1;
