-- ============================================================================
-- G 0xx = GUIA DE TURISMO. Marcar como 'ignorar' no pdv_map.
--
-- O QUE SAO (confirmado pelo Wagner em 08/09/2026)
--   O garcom lanca "G 008", "G 042" etc. na comanda para registrar QUAL guia de
--   turismo trouxe aquele grupo. E controle de quem traz cliente, nao venda:
--   preco R$ 0,00 e nada sai do estoque. Mesma natureza de BRA / EST / MAO
--   (origem do cliente) e de GUIA, que ja estao como 'ignorar'.
--
--   Vem em serie numerada: no iComanda o id e sempre 3070 + o numero do nome
--   (G 008 = 3078, G 042 = 3112). Ou seja, foram cadastrados em bloco e vao
--   aparecer mais conforme novos guias entrarem.
--
--   Detalhe que nao e nosso: no PDV esses cadastros aparecem com custo de
--   R$ 0,60 porque ficaram com a ficha do caldinho pendurada - duplicacao de
--   cadastro la dentro. Nao afeta a nossa baixa, que ignora o item inteiro.
--   Vale limpar no iComanda quando der, para o relatorio de custo de la parar
--   de cobrar caldinho de registro de guia.
--
-- ALEM DESTE SQL: o app tambem foi ajustado (pdvEhModificador reconhece o
-- padrao "G" + numero). Assim o PROXIMO guia cadastrado ja nasce 'ignorar' na
-- semeadura, em vez de virar pendencia. Este arquivo resolve os que ja venderam.
--
-- COMO RODAR: um PASSO por vez, conferindo a saida antes de seguir.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Quem ja esta no pdv_map e quem nao esta.
-- ESPERADO: 4 linhas, todas com status 'pendente' e produto_id nulo
--           (3078 G 008, 3080 G 010, 3082 G 012, 3112 G 042).
--           Os outros dois - 3096 (G 026) e 3108 (G 038) - NAO aparecem:
--           eles ainda nao tem linha nenhuma. E o esperado, nao um erro.
-- ============================================================================
SELECT icomanda_produto_id, icomanda_nome, status, produto_id, qtd_30d
  FROM pdv_map
 WHERE icomanda_produto_id IN (3078, 3080, 3082, 3096, 3108, 3112)
 ORDER BY icomanda_produto_id;


-- ============================================================================
-- PASSO 2 - os quatro que ja tem linha viram 'ignorar'.
-- ESPERADO: UPDATE 4
-- ============================================================================
UPDATE pdv_map
   SET status = 'ignorar',
       produto_id = NULL,
       obs = 'guia de turismo: informativo, igual a BRA/EST/MAO (08/09/2026)',
       atualizado_em = now()
 WHERE icomanda_produto_id IN (3078, 3080, 3082, 3112)
   AND status <> 'ignorar';


-- ============================================================================
-- PASSO 3 - os dois que nao tem linha ganham uma, ja como 'ignorar'.
-- O WHERE NOT EXISTS evita duplicar se alguem tiver criado a linha no meio
-- tempo pela tela de curadoria.
-- ESPERADO: INSERT 0 2
-- ============================================================================
INSERT INTO pdv_map (id, icomanda_produto_id, icomanda_nome, produto_id, status, fator, obs)
SELECT gen_random_uuid(), v.id, v.nome, NULL, 'ignorar', 1,
       'guia de turismo: informativo, igual a BRA/EST/MAO (08/09/2026)'
  FROM (VALUES (3096, 'G 026'), (3108, 'G 038')) AS v(id, nome)
 WHERE NOT EXISTS (SELECT 1 FROM pdv_map m WHERE m.icomanda_produto_id = v.id);


-- ============================================================================
-- PASSO 4 - CONFERE. So leitura.
-- ESPERADO: as 6 linhas, todas status 'ignorar' e produto_id nulo.
-- ============================================================================
SELECT icomanda_produto_id, icomanda_nome, status, produto_id, obs
  FROM pdv_map
 WHERE icomanda_produto_id IN (3078, 3080, 3082, 3096, 3108, 3112)
 ORDER BY icomanda_produto_id;
