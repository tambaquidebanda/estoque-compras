-- =====================================================================
-- IDADE FISICA DA LINHA DO RASCUNHO DO PEDIDO #01439
-- SOMENTE LEITURA. Nao altera, nao apaga, nao grava nada.
--
-- POR QUE ESTE TESTE
-- O financeiro diz que registrou a transferencia do #01439 na segunda,
-- 21/09, pela tela de Integracao. Se isso aconteceu, o sistema APAGOU o
-- rascunho naquele momento (e o ultimo passo dessa rotina). Entao a linha
-- que esta na tela hoje teria que ser uma linha NOVA, gravada depois.
-- Se nao aconteceu, a linha de hoje e a mesma de sexta, 18/09.
--
-- COMO ISSO E DECIDIDO
-- xmin e o numero da transacao que gravou a versao atual de cada linha.
-- Esse numero so cresce, nunca volta. Qualquer coisa que reescreva a
-- linha - apagar e criar de novo, ou so atualizar um campo - deixa um
-- xmin MAIOR que o das linhas gravadas antes dela.
--
-- COMO LER O RESULTADO (coluna ordem_de_gravacao)
--   #01439 ANTES dos rascunhos de 23/09 e 24/09
--     => a linha nao foi tocada desde antes de 23/09. Ninguem apagou e
--        recriou. A transferencia de segunda nao passou por aqui.
--   #01439 DEPOIS dos rascunhos de 23/09 e 24/09
--     => a linha foi regravada ha pouco. A versao do financeiro se
--        sustenta e eu procuro o rastro no lugar certo.
--
-- OBSERVACAO: se algum xmin vier com o valor 2, aquela linha foi
-- congelada pela limpeza automatica do banco e nao serve de comparacao.
-- =====================================================================

-- PASSO 1 - somente leitura
SELECT row_number() OVER (ORDER BY xmin::text::bigint) AS ordem_de_gravacao,
       pedido_num,
       valor,
       acrescimo,
       criado_em,
       xmin::text AS transacao_que_gravou
FROM   lancamentos_rascunho
ORDER  BY xmin::text::bigint;


-- PASSO 2 - opcional: a hora exata da gravacao, se o banco guardar isso.
-- Rode esta linha sozinha primeiro:
SHOW track_commit_timestamp;

-- Se a resposta acima for "on", rode tambem o de baixo (tire os dois
-- tracos do comeco das duas linhas). Se for "off", ignore: o PASSO 1
-- ja responde.
-- SELECT pedido_num, criado_em, pg_xact_commit_timestamp(xmin) AS gravado_em
-- FROM   lancamentos_rascunho WHERE pedido_num = '#01439';
