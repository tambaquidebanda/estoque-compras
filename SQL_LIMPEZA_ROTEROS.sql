-- ==========================================================================
-- ISCA CROCANTE: grupo certo + fim da copia. Mais duas sobras de cadastro.
-- ==========================================================================
-- Contexto:
--
-- 1) ISCA CROCANTE DE PIRARUCU existe DUAS vezes:
--      bf052219  criado 01/06  mapeado no PDV (iComanda 1757)  369 vendas/mes
--                grupo CLUBE ROTEROS COZINHA  (rotulo velho, o certo e ENTRADAS)
--      34864693  criado 03/08  SEM mapeamento  0 vendas  sem preco
--                ficha IDENTICA a do outro, ingrediente por ingrediente
--    O de 03/08 e uma copia: alguem recadastrou para por no grupo certo sem
--    saber que ja existia. Fica o de junho (tem o mapeamento e o historico) e
--    a categoria dele passa a ser ENTRADAS.
--
-- 2) TAMBAQUI DE BANDA + COCA ZERO 1,5L + FAROFA DE BANANA (cd570359) ja esta
--    inativo, mas a FICHA dele continua ativa. Ficha ativa em produto inativo
--    segue aparecendo em varredura e em calculo de custo. Vai junto.
--    (O que vende e o irmao com a grafia BANADA, e esse nao se mexe.)
--
-- 3) PASSO 6 e OPCIONAL: dois cadastros sem uso nenhum que sobraram no grupo
--    CLUBE ROTEROS COZINHA. So rode se confirmar que sairam do cardapio.
--
-- INATIVA, NAO APAGA. Da para desfazer com um UPDATE.
-- Rodar o PASSO 1 primeiro; ele nao altera nada.
-- ==========================================================================


-- --------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA: o retrato antes de mexer
-- --------------------------------------------------------------------------
SELECT p.nome, p.categoria, p.ativo, p.preco_venda,
       (SELECT count(*) FROM pdv_map                m WHERE m.produto_id     = p.id AND m.status='mapeado') AS mapeado,
       (SELECT count(*) FROM est_saldo_local        x WHERE x.produto_id     = p.id) AS saldo,
       (SELECT count(*) FROM est_inventario_itens   x WHERE x.produto_id     = p.id) AS contagens,
       (SELECT count(*) FROM cmp_recebimento_itens  x WHERE x.produto_id     = p.id) AS recebimentos,
       (SELECT count(*) FROM est_movimentacoes      x WHERE x.produto_id     = p.id) AS movimentacoes,
       (SELECT count(*) FROM est_ficha_ingredientes x WHERE x.ingrediente_id = p.id) AS usado_em_fichas,
       (SELECT count(*) FROM est_fichas_tecnicas    f WHERE f.produto_id     = p.id AND f.ativo) AS fichas_ativas
  FROM est_produtos p
 WHERE p.id IN ('bf052219-d62d-4080-ab17-6b068b99c1f5'::uuid,   -- ISCA que vende  (FICA)
                '34864693-f1c2-4e09-b7b6-9a0c14e778b5'::uuid,   -- ISCA copia      (INATIVA)
                'cd570359-7147-480d-8a90-dd1b7cc75f8b'::uuid,   -- COMBO fantasma  (ja inativo)
                '9fbec401-7548-461d-9f3c-f0bf5afd4bbb'::uuid,   -- PICADINHO       (passo 6)
                'd838600d-de62-4b5b-a726-d5c524664f18'::uuid)   -- BOLINHO 10 UN   (passo 6)
 ORDER BY p.nome, p.categoria;
-- Esperado, 5 linhas:
--   ISCA (CLUBE ROTEROS COZINHA) . ativo=t  preco=54.90  mapeado=1  demais colunas 0, fichas_ativas=1
--   ISCA (ENTRADAS) .............. ativo=t  preco=0      mapeado=0  demais colunas 0, fichas_ativas=1
--   COMBO ........................ ativo=f  preco=0      mapeado=0  demais colunas 0, fichas_ativas=1
--   PICADINHO .................... ativo=t  preco=0      mapeado=0  demais colunas 0
--   BOLINHO 10 UN ................ ativo=t  preco=0      mapeado=0  demais colunas 0
-- Se QUALQUER coluna de vinculo vier diferente de 0 nas linhas a inativar, PARE e me avise.


-- --------------------------------------------------------------------------
-- PASSO 2 - a ISCA que vende passa para o grupo ENTRADAS
-- --------------------------------------------------------------------------
UPDATE est_produtos
   SET categoria = 'ENTRADAS'
 WHERE id = 'bf052219-d62d-4080-ab17-6b068b99c1f5'::uuid;
-- Esperado: UPDATE 1


-- --------------------------------------------------------------------------
-- PASSO 3 - inativa a copia da ISCA
-- --------------------------------------------------------------------------
UPDATE est_produtos
   SET ativo = false
 WHERE id = '34864693-f1c2-4e09-b7b6-9a0c14e778b5'::uuid;
-- Esperado: UPDATE 1


-- --------------------------------------------------------------------------
-- PASSO 4 - inativa a ficha da copia da ISCA
-- --------------------------------------------------------------------------
UPDATE est_fichas_tecnicas
   SET ativo = false
 WHERE produto_id = '34864693-f1c2-4e09-b7b6-9a0c14e778b5'::uuid
   AND ativo = true;
-- Esperado: UPDATE 1


-- --------------------------------------------------------------------------
-- PASSO 5 - inativa a ficha orfa do combo Coca Zero (o produto ja esta inativo)
-- --------------------------------------------------------------------------
UPDATE est_fichas_tecnicas
   SET ativo = false
 WHERE produto_id = 'cd570359-7147-480d-8a90-dd1b7cc75f8b'::uuid
   AND ativo = true;
-- Esperado: UPDATE 1


-- --------------------------------------------------------------------------
-- PASSO 6 - OPCIONAL. So rode se confirmar que estes dois sairam do cardapio.
-- --------------------------------------------------------------------------
-- PICADINHO DE TAMBAQUI e BOLINHO DE TAMBAQUI 10 UN: nenhum dos dois tem
-- mapeamento, venda, saldo, contagem, recebimento ou movimentacao. Nao sao
-- copia de ninguem - o CALDINHO DE TAMBAQUI e outro prato, e o BOLINHO DE
-- 5 UN tem ficha propria. Sao itens que simplesmente pararam de ser vendidos.
-- Se ainda estiverem no cardapio, PULE este passo.
--
-- UPDATE est_produtos SET ativo = false
--  WHERE id IN ('9fbec401-7548-461d-9f3c-f0bf5afd4bbb'::uuid,
--               'd838600d-de62-4b5b-a726-d5c524664f18'::uuid);
--
-- UPDATE est_fichas_tecnicas SET ativo = false
--  WHERE produto_id IN ('9fbec401-7548-461d-9f3c-f0bf5afd4bbb'::uuid,
--                       'd838600d-de62-4b5b-a726-d5c524664f18'::uuid)
--    AND ativo = true;


-- --------------------------------------------------------------------------
-- PASSO 7 - CONFERE
-- --------------------------------------------------------------------------
SELECT p.nome, p.categoria, p.ativo,
       (SELECT count(*) FROM est_fichas_tecnicas f WHERE f.produto_id = p.id AND f.ativo) AS fichas_ativas
  FROM est_produtos p
 WHERE p.id IN ('bf052219-d62d-4080-ab17-6b068b99c1f5'::uuid,
                '34864693-f1c2-4e09-b7b6-9a0c14e778b5'::uuid,
                'cd570359-7147-480d-8a90-dd1b7cc75f8b'::uuid)
 ORDER BY p.nome, p.categoria;
-- Esperado:
--   ISCA ... ENTRADAS ................ ativo=t  fichas_ativas=1   <- a que vende
--   ISCA ... ENTRADAS ................ ativo=f  fichas_ativas=0   <- a copia
--   COMBO .. IFOOD ................... ativo=f  fichas_ativas=0
-- As duas ISCA ficam com categoria ENTRADAS, mas so uma fica ativa.


-- --------------------------------------------------------------------------
-- PASSO 8 - SO LEITURA: o que ainda restou no grupo CLUBE ROTEROS
-- --------------------------------------------------------------------------
SELECT categoria, nome, ativo
  FROM est_produtos
 WHERE upper(coalesce(categoria,'')) LIKE 'CLUBE ROTEROS%'
 ORDER BY categoria, nome;
-- Esperado SEM o passo 6: 4 linhas
--   CLUBE ROTEROS BAR ...... os 2 caipiles (ja inativos)
--   CLUBE ROTEROS COZINHA .. PICADINHO DE TAMBAQUI e BOLINHO DE TAMBAQUI 10 UN
-- Esperado COM o passo 6: as mesmas 4 linhas, mas todas com ativo=f.
-- Em nenhum dos casos sobra produto vendendo no grupo.
