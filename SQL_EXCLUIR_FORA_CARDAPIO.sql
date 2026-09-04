-- ==========================================================================
-- TIRA DO CARDAPIO 9 PRODUTOS QUE NAO SAO MAIS VENDIDOS
-- ==========================================================================
-- Marcados como EXCLUIR por voce na planilha FICHAS_VARREDURA.xlsx.
--
-- INATIVA, NAO APAGA. Um DELETE em produto de sistema em producao quebra
-- qualquer historico que aponte para ele e nao tem volta. Inativar tira da
-- tela, some do inventario, para de aparecer nas varreduras, e da para
-- desfazer com um UPDATE. Se um dia quiser mesmo apagar, apaga depois de
-- ter certeza de que nenhum historico referencia.
--
-- CONFERIDO ANTES (todos os 9, um por um):
--   saldo em est_saldo_local ........ 0
--   linhas em est_inventario_itens .. 0
--   linhas em cmp_recebimento_itens . 0
--   linhas em est_movimentacoes ..... 0
--   usado como ingrediente de ficha . 0
--   mapeamento em pdv_map ........... nenhum
--   vendas nos ultimos 30 dias ...... 0
-- Nenhum deles tem vinculo com nada. Sao cadastros mortos.
--
-- Rodar PASSO 1 primeiro. Ele nao altera nada.
-- ==========================================================================


-- --------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA: confirma que continuam sem vinculo
-- --------------------------------------------------------------------------
WITH alvo(id) AS (VALUES
    ('45b2bec2-9f9d-4962-a4c9-bd1e87573d6b'::uuid),   -- GUARANA ANTARTICA ZERO 2LT
    ('3c1ee91d-6813-41c4-b07d-c7eaf4c435f6'::uuid),   -- GUARANA ANTARTICA ZERO 2LT
    ('895887c1-31be-4d90-901c-0a203c084eb4'::uuid),   -- PROMO BUD 4 UNIDS
    ('29197056-20ba-4631-a14c-729a98b77bb2'::uuid),   -- REAL CLASSICO
    ('665dd864-28b5-4475-bdb8-3394705c6459'::uuid),   -- REAL GOLD
    ('5934dc45-257c-4699-b7d5-aec36b1fd39a'::uuid),   -- SUCO DEL VALLE LARANJA
    ('b75e6844-3e9c-4dd2-b0b3-e7947ff91618'::uuid),   -- SUCO DEL VALLE MARACUJA
    ('9db32d96-ee50-4541-976e-bb106a804fe9'::uuid),   -- SUCO DEL VALLE PESSEGO
    ('0cf9336a-53c6-4566-873f-db00f4837a12'::uuid)   -- SUCO DEL VALLE UVA
)
SELECT p.nome, p.ativo,
       (SELECT count(*) FROM est_saldo_local        x WHERE x.produto_id    = p.id) AS saldo,
       (SELECT count(*) FROM est_inventario_itens   x WHERE x.produto_id    = p.id) AS contagens,
       (SELECT count(*) FROM cmp_recebimento_itens  x WHERE x.produto_id    = p.id) AS recebimentos,
       (SELECT count(*) FROM est_movimentacoes      x WHERE x.produto_id    = p.id) AS movimentacoes,
       (SELECT count(*) FROM est_ficha_ingredientes x WHERE x.ingrediente_id = p.id) AS usado_em_fichas,
       (SELECT count(*) FROM pdv_map                x WHERE x.produto_id    = p.id) AS no_pdv
  FROM est_produtos p JOIN alvo a ON a.id = p.id
 ORDER BY p.nome;
-- Esperado: 9 linhas, ativo = true, e TODAS as contagens em 0.
-- Se alguma vier diferente de 0, PARE e me avise.


-- --------------------------------------------------------------------------
-- PASSO 2 - INATIVA O PRODUTO
-- --------------------------------------------------------------------------
UPDATE est_produtos SET ativo = false
 WHERE id IN ('45b2bec2-9f9d-4962-a4c9-bd1e87573d6b'::uuid, '3c1ee91d-6813-41c4-b07d-c7eaf4c435f6'::uuid, '895887c1-31be-4d90-901c-0a203c084eb4'::uuid, '29197056-20ba-4631-a14c-729a98b77bb2'::uuid, '665dd864-28b5-4475-bdb8-3394705c6459'::uuid, '5934dc45-257c-4699-b7d5-aec36b1fd39a'::uuid, 'b75e6844-3e9c-4dd2-b0b3-e7947ff91618'::uuid, '9db32d96-ee50-4541-976e-bb106a804fe9'::uuid, '0cf9336a-53c6-4566-873f-db00f4837a12'::uuid);
-- Esperado: UPDATE 9


-- --------------------------------------------------------------------------
-- PASSO 3 - INATIVA A FICHA JUNTO
-- --------------------------------------------------------------------------
-- Ficha ativa em produto inativo continua aparecendo nas varreduras e no
-- calculo de custo. Vao juntas.
UPDATE est_fichas_tecnicas SET ativo = false
 WHERE produto_id IN ('45b2bec2-9f9d-4962-a4c9-bd1e87573d6b'::uuid, '3c1ee91d-6813-41c4-b07d-c7eaf4c435f6'::uuid, '895887c1-31be-4d90-901c-0a203c084eb4'::uuid, '29197056-20ba-4631-a14c-729a98b77bb2'::uuid, '665dd864-28b5-4475-bdb8-3394705c6459'::uuid, '5934dc45-257c-4699-b7d5-aec36b1fd39a'::uuid, 'b75e6844-3e9c-4dd2-b0b3-e7947ff91618'::uuid, '9db32d96-ee50-4541-976e-bb106a804fe9'::uuid, '0cf9336a-53c6-4566-873f-db00f4837a12'::uuid)
   AND ativo = true;
-- Esperado: ate 9 (so os que tinham ficha ativa).


-- --------------------------------------------------------------------------
-- PASSO 4 - CONFERE
-- --------------------------------------------------------------------------
SELECT p.nome, p.ativo AS produto_ativo,
       (SELECT count(*) FROM est_fichas_tecnicas f WHERE f.produto_id = p.id AND f.ativo) AS fichas_ativas
  FROM est_produtos p
 WHERE p.id IN ('45b2bec2-9f9d-4962-a4c9-bd1e87573d6b'::uuid, '3c1ee91d-6813-41c4-b07d-c7eaf4c435f6'::uuid, '895887c1-31be-4d90-901c-0a203c084eb4'::uuid, '29197056-20ba-4631-a14c-729a98b77bb2'::uuid, '665dd864-28b5-4475-bdb8-3394705c6459'::uuid, '5934dc45-257c-4699-b7d5-aec36b1fd39a'::uuid, 'b75e6844-3e9c-4dd2-b0b3-e7947ff91618'::uuid, '9db32d96-ee50-4541-976e-bb106a804fe9'::uuid, '0cf9336a-53c6-4566-873f-db00f4837a12'::uuid)
 ORDER BY p.nome;
-- Esperado: 9 linhas, produto_ativo = false, fichas_ativas = 0.
