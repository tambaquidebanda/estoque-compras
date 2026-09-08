-- ============================================================================
-- CAIPILES TRADICIONAIS: volta para o cardapio (CAIPIDRINKS) e conserta o
-- picole trocado na ficha do abacaxi e acai.
-- Achado da checagem completa em 08/09/2026 (codigos C2 e D1). Decisao do
-- Wagner em 08/09: os dois tradicionais continuam sendo vendidos, entao o certo
-- e reativa-los e leva-los para o grupo CAIPIDRINKS, junto dos especiais.
--
-- ---------------------------------------------------------------------------
-- COISA 1 - A FICHA DO ABACAXI E ACAI DESCONTA O PICOLE ERRADO
--   Ela desconta MP PICOLE DE GRAVIOLA; o certo e MP PICOLE DE ACAI. O abacaxi
--   e a cachaca estao certos, so o picole esta trocado - tem cara de copia da
--   ficha do irmao de limao e graviola, que usa graviola com razao. A prova
--   esta na versao ESPECIAL do mesmo drink, que usa MP PICOLE DE ACAI.
--   Efeito hoje: a graviola sai do estoque sem ter sido usada e o acai nunca e
--   descontado.
--
-- COISA 2 - O CADASTRO DIZ UMA COISA E O PDV DIZ OUTRA
--   Os dois tradicionais estao com ativo=false e categoria CLUBE ROTEROS BAR,
--   um grupo aposentado. Mas o iComanda nunca parou de vende-los: os itens 1209
--   e 1212 fizeram 9 e 7 unidades nos 7 dias ate 07/09. A venda e que manda -
--   o drink e feito, o insumo sai. Entao eles voltam a ser o que sao: caipidrink
--   ativo.
--   Efeito colateral util: produto inativo nao aparece na tela de Produtos
--   (app.js:7910 carrega so ativos). Reativando, a ficha volta a ser editavel
--   pela interface e voce nao precisa de SQL na proxima vez.
--
-- Os caipiles ESPECIAIS ja estao ativos em CAIPIDRINKS e nao sao tocados aqui.
-- O HAPPY HOUR fica onde esta, no grupo dele.
--
-- Ao final, CAIPIDRINKS tera os quatro: 2 sabores x 2 cachacas.
--
-- COMO RODAR: um PASSO por vez, conferindo a saida antes de seguir.
-- Rodar o arquivo duas vezes nao faz estrago: os UPDATE tem guarda e o segundo
-- passe devolve UPDATE 0.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O estado antes de mexer.
-- ESPERADO na primeira consulta: 4 linhas, uma delas MP PICOLE DE GRAVIOLA 1.0
-- ESPERADO na segunda: os 2 tradicionais com ativo=f e CLUBE ROTEROS BAR,
--                      os 2 especiais com ativo=t e CAIPIDRINKS
-- ============================================================================
SELECT i.id AS linha_id, p.nome AS ingrediente, i.quantidade
  FROM est_ficha_ingredientes i
  JOIN est_produtos p ON p.id = i.ingrediente_id
 WHERE i.ficha_id = '5f818988-e63a-428e-963e-0b9c06386425'
 ORDER BY p.nome;

SELECT nome, categoria, ativo, preco_venda
  FROM est_produtos
 WHERE nome ILIKE '%CAIPILE%'
 ORDER BY nome;


-- ============================================================================
-- PASSO 2 - CONSERTA A FICHA. Troca graviola por acai.
-- Mexe em UMA linha, achada pelo id dela, e so se ela ainda for graviola.
-- ESPERADO: UPDATE 1
-- ============================================================================
UPDATE est_ficha_ingredientes
   SET ingrediente_id = 'd1138c62-686e-43ec-8981-f9f52d12df5a'  -- MP PICOLE DE ACAI
 WHERE id = 'd9c08065-7f4a-4553-bbb2-ff5f02d99329'              -- a linha do picole
   AND ingrediente_id = '26d6bf29-f42a-48aa-b77c-d386d24f4618'; -- so se ainda for GRAVIOLA


-- ============================================================================
-- PASSO 3 - REATIVA OS DOIS E LEVA PARA CAIPIDRINKS.
-- Pelos ids, nao pelo nome: um deles tem "LIMAO" com til e o outro nao, e
-- casar por nome aqui e pedir para errar.
-- ESPERADO: UPDATE 2
-- ============================================================================
UPDATE est_produtos
   SET ativo = true,
       categoria = 'CAIPIDRINKS'
 WHERE id IN ('f9fc67d6-54fe-44e9-8caf-79185dafd9fd',   -- ABACAXI E ACAI CACHACA TRADICIONAL
              'e69da76a-e1ab-4e31-904d-4f2e2308d5b8');  -- LIMAO E GRAVIOLA CACHACA TRADICIONAL


-- ============================================================================
-- PASSO 4 - CONFERE TUDO. So leitura.
--
-- ESPERADO na ficha, em ordem alfabetica:
--   MP CACHACA CABARE ............ 0.06
--   MP PICOLE DE ACAI ............ 1.0
--   PPB XAROPE DE ACUCAR ......... 0.025
--   SA ABACAXI EM CUBOS 150g ..... 0.5
--   (nenhuma linha de graviola)
--
-- ESPERADO nos produtos: os 4 caipiles em CAIPIDRINKS com ativo=t,
--   os dois tradicionais a 28.90 e os dois especiais a 36.90.
--   O HAPPY HOUR continua em HAPPY HOUR BAR E CHOPP - e o certo.
-- ============================================================================
SELECT p.nome AS ingrediente, i.quantidade
  FROM est_ficha_ingredientes i
  JOIN est_produtos p ON p.id = i.ingrediente_id
 WHERE i.ficha_id = '5f818988-e63a-428e-963e-0b9c06386425'
 ORDER BY p.nome;

SELECT nome, categoria, ativo, preco_venda
  FROM est_produtos
 WHERE nome ILIKE '%CAIPILE%'
 ORDER BY categoria, nome;
