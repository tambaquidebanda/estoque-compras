-- ==========================================================================
-- OVO COZIDO: apaga o saldo que uma contagem de junho criou por engano
-- ==========================================================================
-- O QUE ACONTECEU
--
-- Em junho a linha do ovo cru na tela de Contagem se chamava "OVO COZIDO",
-- dentro de COZINHA > HORTIFRUTI. Como o casamento da contagem e por NOME,
-- ela caiu no produto de VENDA chamado OVO COZIDO em vez de cair no MP OVO:
--
--    25/06  INV-0015  Luziane   COZINHA > HORTIFRUTI  "OVO COZIDO"  contou 0
--    26/06  INV-0034  Jessica   COZINHA > HORTIFRUTI  "OVO COZIDO"  contou 1
--    05/07  saldo gravado: COZINHA = 1,0
--    07/08  o backfill do livro-razao criou um saldo_inicial de 1,0 em cima
--
-- A tela ja foi corrigida: hoje a estrutura tem MP OVO em COZINHA>HORTIFRUTI,
-- e nao ha nenhum mapeamento de OVO em inv_configuracoes. So o saldo ficou.
--
-- POR QUE ISSO ATRAPALHA A BAIXA
--
-- O robo trata como CONTADO todo produto que tem LINHA em est_saldo_local -
-- com qualquer valor, inclusive zero (ver carregar() em baixa_estoque_pdv.py:
-- "CONTADOS = produtos que tem saldo cadastrado"). Em item contado a recursao
-- PARA: ele desconta o proprio item e nao abre a ficha. Resultado hoje:
--   - OVO COZIDO vende 4/mes e o robo tenta baixar "OVO COZIDO"
--   - como OVO COZIDO nao esta em setor nenhum da contagem, nao baixa NADA
--   - e o MP OVO, que e o que sai de verdade, nunca e descontado
--
-- Por isso ZERAR NAO RESOLVE: a linha precisa deixar de existir. Com ela fora,
-- o robo abre a ficha do OVO COZIDO e desconta 1,0 MP OVO por venda, que e o
-- comportamento correto.
--
-- Varri o sistema inteiro: e o UNICO produto nessa situacao (tem ficha, tem
-- saldo, vende, e o saldo faz o robo ignorar a ficha).
--
-- ATENCAO: o PASSO 3 e um DELETE e nao tem desfazer automatico. O PASSO 5
-- traz o comando para recriar a linha, caso precise voltar atras.
-- Rodar o PASSO 1 primeiro; ele nao altera nada.
-- ==========================================================================


-- --------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA: o retrato de agora
-- --------------------------------------------------------------------------
SELECT 'saldo'        AS o_que, s.local, s.saldo::text AS valor, s.updated_at::text AS quando
  FROM est_saldo_local s
 WHERE s.produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid
UNION ALL
SELECT 'movimentacao', m.local, m.tipo || ' ' || m.quantidade::text, m.data::text
  FROM est_movimentacoes m
 WHERE m.produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid
UNION ALL
SELECT 'ingrediente da ficha', '-', fi.quantidade::text || ' ' || p.nome, ''
  FROM est_ficha_ingredientes fi
  JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id AND f.ativo
  JOIN est_produtos p        ON p.id = fi.ingrediente_id
 WHERE f.produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid;
-- Esperado, 3 linhas:
--   saldo ................ COZINHA  1     2026-07-05
--   movimentacao ......... COZINHA  saldo_inicial 1   2026-08-07
--   ingrediente da ficha . -        1 MP OVO
-- Se o saldo vier diferente de 1, PARE e me avise: alguem mexeu depois.


-- --------------------------------------------------------------------------
-- PASSO 2 - lanca a saida no livro-razao ANTES de apagar
-- --------------------------------------------------------------------------
-- Sem isto o razao continuaria dizendo que existe 1 ovo cozido em estoque.
-- Mesmo formato dos ajustes de correcao que ja existem na tabela.
-- OBS: valor_total NAO entra aqui. E coluna GERADA pelo banco (calculada a
-- partir de custo_unit e quantidade); informar ela da erro 428C9.
INSERT INTO est_movimentacoes
       (produto_id, local, tipo, origem, motivo, quantidade, custo_unit, responsavel, data)
VALUES ('b5aab639-31d3-4059-984b-8a6a78af9782'::uuid, 'COZINHA', 'ajuste', 'correcao',
        'Correcao: contagem de junho caiu no produto de venda OVO COZIDO em vez do MP OVO (INV-0015 e INV-0034)',
        -1, NULL, 'sistema', CURRENT_DATE);
-- Esperado: INSERT 0 1


-- --------------------------------------------------------------------------
-- PASSO 3 - apaga a linha de saldo (e o que faz o robo abrir a ficha)
-- --------------------------------------------------------------------------
DELETE FROM est_saldo_local
 WHERE id = 'd9b8dab0-3445-459f-99c8-9188a431943b'::uuid
   AND produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid;
-- Esperado: DELETE 1
-- O id esta fixo de proposito: apaga esta linha e nenhuma outra.


-- --------------------------------------------------------------------------
-- PASSO 4 - CONFERE
-- --------------------------------------------------------------------------
SELECT (SELECT count(*) FROM est_saldo_local
         WHERE produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid)  AS linhas_de_saldo,
       (SELECT coalesce(sum(quantidade),0) FROM est_movimentacoes
         WHERE produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid)  AS razao_soma,
       (SELECT count(*) FROM est_saldo_local s
          JOIN est_produtos p ON p.id = s.produto_id
         WHERE upper(p.nome) = 'MP OVO')                                   AS saldo_do_mp_ovo;
-- Esperado: linhas_de_saldo = 0 | razao_soma = 0 | saldo_do_mp_ovo = 2
-- razao_soma 0 = o livro-razao fechou (entrou 1 em agosto, saiu 1 agora).
-- O MP OVO nao e tocado por este SQL: continua com as 2 linhas dele.


-- --------------------------------------------------------------------------
-- PASSO 5 - COMO VOLTAR ATRAS, se precisar
-- --------------------------------------------------------------------------
-- INSERT INTO est_saldo_local (id, produto_id, local, saldo, updated_at)
-- VALUES ('d9b8dab0-3445-459f-99c8-9188a431943b'::uuid,
--         'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid,
--         'COZINHA', 1.0, '2026-07-05T17:59:36.694055+00:00');
--
-- DELETE FROM est_movimentacoes
--  WHERE produto_id = 'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid
--    AND origem = 'correcao' AND data = CURRENT_DATE;
