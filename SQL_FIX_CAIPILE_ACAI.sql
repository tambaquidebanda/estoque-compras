-- ============================================================================
-- CAIPILE ABACAXI E ACAI TRADICIONAL: a ficha desconta o picole errado
-- Achado da checagem completa em 08/09/2026 (codigo C2)
--
-- O QUE ESTA ERRADO NA FICHA
--   O CAIPILE ABACAXI E ACAI CACHACA TRADICIONAL desconta MP PICOLE DE
--   GRAVIOLA. Devia descontar MP PICOLE DE ACAI. O abacaxi e a cachaca estao
--   certos; so o picole esta trocado - tem cara de copia da ficha do irmao de
--   limao e graviola, que usa graviola com razao.
--   A prova esta na versao ESPECIAL do mesmo drink (grupo CAIPIDRINKS), que
--   usa MP PICOLE DE ACAI.
--   Efeito hoje: a graviola some do estoque sem ter sido usada e o acai nunca
--   e descontado.
--
-- O QUE **NAO** ESTA ERRADO: O CADASTRO
--   Este produto e o CAIPILE LIMAO E GRAVIOLA TRADICIONAL estao com
--   ativo=false, e isso esta CORRETO: os dois sao do grupo CLUBE ROTEROS BAR,
--   que saiu do cardapio. Os caipiles do grupo CAIPIDRINKS continuam ativos,
--   como deve ser. Nao reative nada.
--
--   A divergencia esta do outro lado: o PDV ainda vende os itens icomanda 1209
--   e 1212 (9 e 7 unidades nos 7 dias ate 07/09). Enquanto eles estiverem no
--   cardapio do iComanda, o drink e feito de verdade, o insumo sai de verdade,
--   e o robo desconta de verdade - ele nao filtra est_produtos.ativo. Por isso
--   vale consertar a ficha mesmo com o produto inativo.
--
--   O conserto de fundo e no iComanda: tirar 1209 e 1212 do cardapio. Ai eles
--   param de vender sozinhos e a ficha vira irrelevante. Enquanto nao acontece,
--   o PASSO 2 impede que o paralelo comece medindo o picole errado.
--
-- POR QUE ISSO NAO APARECE NA TELA DE PRODUTOS
--   app.js:7910 carrega so produtos ativos. Como o cadastro esta inativo (e
--   certo que esteja), a ficha nao da para editar pela interface. Dai o SQL.
--
-- COMO RODAR: um PASSO por vez, conferindo a saida antes de seguir.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confere o estado antes de mexer.
-- ESPERADO: 4 linhas, uma delas MP PICOLE DE GRAVIOLA com quantidade 1.0.
-- ============================================================================
SELECT i.id AS linha_id, p.nome AS ingrediente, i.quantidade
  FROM est_ficha_ingredientes i
  JOIN est_produtos p ON p.id = i.ingrediente_id
 WHERE i.ficha_id = '5f818988-e63a-428e-963e-0b9c06386425'
 ORDER BY p.nome;


-- ============================================================================
-- PASSO 2 - O CONSERTO. Troca graviola por acai.
-- Mexe em UMA linha, achada pelo id dela, e so se ela ainda for graviola.
-- ESPERADO: UPDATE 1
-- ============================================================================
UPDATE est_ficha_ingredientes
   SET ingrediente_id = 'd1138c62-686e-43ec-8981-f9f52d12df5a'  -- MP PICOLE DE ACAI
 WHERE id = 'd9c08065-7f4a-4553-bbb2-ff5f02d99329'              -- a linha do picole
   AND ingrediente_id = '26d6bf29-f42a-48aa-b77c-d386d24f4618'; -- so se ainda for GRAVIOLA


-- ============================================================================
-- PASSO 3 - CONFERE. So leitura.
-- ESPERADO, nesta ordem alfabetica:
--   MP CACHACA CABARE ............ 0.06
--   MP PICOLE DE ACAI ............ 1.0
--   PPB XAROPE DE ACUCAR ......... 0.025
--   SA ABACAXI EM CUBOS 150g ..... 0.5
-- Nenhuma linha de graviola.
-- ============================================================================
SELECT p.nome AS ingrediente, i.quantidade
  FROM est_ficha_ingredientes i
  JOIN est_produtos p ON p.id = i.ingrediente_id
 WHERE i.ficha_id = '5f818988-e63a-428e-963e-0b9c06386425'
 ORDER BY p.nome;
