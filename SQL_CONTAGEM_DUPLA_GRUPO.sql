-- ============================================================================
-- SQL_CONTAGEM_DUPLA_GRUPO.sql
--
-- Tira duas mercadorias que estao em DOIS GRUPOS DO MESMO SETOR, e limpa um
-- bloco de nomes repetidos na lista de adicoes do BAR.
--
-- O PROBLEMA
-- O saldo e guardado por PRODUTO + SETOR. Grupo nao entra na chave: grupo e so
-- a divisao da tela para quem conta. Entao, quando a mesma mercadoria esta em
-- dois grupos do mesmo setor, cada grupo grava por cima do outro - e se o
-- segundo grupo nao foi preenchido, ele grava ZERO em cima de uma contagem boa.
--
-- Aconteceu duas vezes na contagem de 01/09:
--
--   MC COPO DESCART. 180ML  BAR      EMBALAGEMDESCAR=0,3 -> MAT. EXPEDIENTE=0
--   MP ACUCAR               COZINHA  ESTIVAS=1           -> COMIDA FUNC.=0
--
-- Some sem avisar: nao da erro, nao aparece em lugar nenhum, e o time que
-- contou certo nao tem como perceber.
--
-- O QUE ESTE ARQUIVO RESOLVE
--   1. MC COPO DESCART. 180ML  -> fica so em BAR | MATERIAL DE EXPEDIENTE
--   2. MP PIMENTA ROSA         -> fica so em BAR | HORTIFRUTI
--   3. limpa 9 nomes repetidos dentro de adicoes['BAR|ESTIVAS']
--
-- Nos dois casos o produto CONTINUA na estrutura, no grupo escolhido pelo
-- Wagner em 01/09. O que sai e a entrada extra da lista de adicoes.
--
-- O QUE ESTE ARQUIVO **NAO** RESOLVE, DE PROPOSITO
-- MP ACUCAR e MP BATATA PORTUGUESA estao em COZINHA | ESTIVAS (ou HORTIFRUTI)
-- e tambem em COZINHA | COMIDA FUNCIONARIO. Os dois vem da estrutura, e a
-- decisao ainda esta em aberto: contar num grupo so, ou transformar
-- COMIDA FUNCIONARIO em SETOR para ele ganhar linha propria de saldo.
-- Fica para um SQL separado.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Como as duas listas estao hoje.
-- ============================================================================

-- 1a) A lista de embalagens do bar (deve conter MC COPO DESCART. 180ML).
SELECT jsonb_pretty(valor -> 'BAR|EMBALAGEMDESCAR') AS embalagem_bar_hoje
FROM inv_configuracoes WHERE chave = 'adicoes';

-- 1b) A lista de estivas do bar: 26 nomes, sendo 9 repetidos.
SELECT jsonb_array_length(valor -> 'BAR|ESTIVAS')             AS nomes_hoje,
       (SELECT count(DISTINCT x) FROM jsonb_array_elements_text(valor -> 'BAR|ESTIVAS') x)
                                                              AS nomes_distintos
FROM inv_configuracoes WHERE chave = 'adicoes';
-- Esperado: 26 e 25. (25 distintos, e um deles sai no PASSO 3 -> ficam 24.)

-- 1c) Quais estao repetidos.
SELECT x AS nome, count(*) AS vezes
FROM inv_configuracoes, jsonb_array_elements_text(valor -> 'BAR|ESTIVAS') x
WHERE chave = 'adicoes'
GROUP BY x HAVING count(*) > 1
ORDER BY x;


-- ============================================================================
-- PASSO 2 - ESCREVE. Copo 180ml sai de BAR | EMBALAGEMDESCAR.
--
-- Ele continua na estrutura em BAR | MATERIAL DE EXPEDIENTE, escrito la como
-- "MC COPO DESCARTAVEL 180ML" (mesmo cadastro, outra grafia).
-- ============================================================================
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, '{BAR|EMBALAGEMDESCAR}',
         (SELECT COALESCE(jsonb_agg(x ORDER BY ord), '[]'::jsonb)
            FROM jsonb_array_elements(valor -> 'BAR|EMBALAGEMDESCAR')
                 WITH ORDINALITY AS t(x, ord)
           WHERE x <> '"MC COPO DESCART. 180ML"'::jsonb))
 WHERE chave = 'adicoes';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 3 - ESCREVE. Pimenta rosa sai de BAR | ESTIVAS, e os repetidos caem.
--
-- Uma passada so: tira a pimenta rosa e deixa cada nome uma vez, na ordem
-- em que aparecia (MIN(ord) preserva a posicao da primeira ocorrencia).
-- A pimenta rosa continua na estrutura em BAR | HORTIFRUTI.
-- ============================================================================
WITH itens AS (
  SELECT x AS nome, MIN(ord) AS ord
    FROM inv_configuracoes,
         jsonb_array_elements_text(valor -> 'BAR|ESTIVAS') WITH ORDINALITY AS t(x, ord)
   WHERE chave = 'adicoes'
     AND x <> 'MP PIMENTA ROSA'
   GROUP BY x
)
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, '{BAR|ESTIVAS}',
         (SELECT COALESCE(jsonb_agg(to_jsonb(nome) ORDER BY ord), '[]'::jsonb) FROM itens))
 WHERE chave = 'adicoes';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 4 - CONFERENCIA.
-- ============================================================================

-- 4a) 24 nomes, todos distintos, sem pimenta rosa.
SELECT jsonb_array_length(valor -> 'BAR|ESTIVAS') AS nomes_agora,
       (SELECT count(DISTINCT x) FROM jsonb_array_elements_text(valor -> 'BAR|ESTIVAS') x)
                                                  AS distintos_agora,
       (valor -> 'BAR|ESTIVAS') @> '["MP PIMENTA ROSA"]'::jsonb AS ainda_tem_pimenta
FROM inv_configuracoes WHERE chave = 'adicoes';
-- Esperado: 24, 24, false.

-- 4b) Copo 180ml fora das embalagens do bar.
SELECT (valor -> 'BAR|EMBALAGEMDESCAR') @> '["MC COPO DESCART. 180ML"]'::jsonb AS ainda_tem_copo
FROM inv_configuracoes WHERE chave = 'adicoes';
-- Esperado: false.

-- 4c) Nenhum outro grupo pode ter mudado de tamanho.
SELECT k AS setor_grupo, jsonb_array_length(v) AS nomes
FROM inv_configuracoes, jsonb_each(valor) AS t(k, v)
WHERE chave = 'adicoes'
ORDER BY k;


-- ============================================================================
-- DEPOIS DE RODAR
-- Na tela de Contagem, o copo 180ml deve aparecer so em MATERIAL DE
-- EXPEDIENTE e a pimenta rosa so em HORTIFRUTI. Se o time contar hoje e o
-- saldo dos dois parar de zerar, o mecanismo esta fechado.
--
-- Continua em aberto: MP ACUCAR e MP BATATA PORTUGUESA no COMIDA FUNCIONARIO.
-- ============================================================================
