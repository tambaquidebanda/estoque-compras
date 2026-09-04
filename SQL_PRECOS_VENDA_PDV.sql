-- ##########################################################################
-- ##  NAO RODE ESTE ARQUIVO. SUBSTITUIDO POR SQL_PRECOS_VENDA_PDV_V2.sql  ##
-- ##########################################################################
-- Guardado so como historico. Ele tem um defeito serio:
--
--   UPDATE ... FROM (VALUES ...) com a MESMA chave repetida nao da erro no
--   Postgres. Ele escolhe uma das linhas em silencio e ignora as outras.
--
-- Aqui 349 itens do PDV apontavam para 322 produtos: 24 produtos recebiam mais
-- de um preco candidato, 20 deles com valores diferentes. Resultado real ao
-- rodar: COCA COLA, AGUA COM GAS, BARE LT, TUCHAUA e 3 sucos ficaram com R$
-- 0,01, que era o preco do item de cortesia do mesmo produto.
--
-- A V2 resolve com regra de desempate explicita (descarta cortesia <= R$ 0,02,
-- depois vence o item mais vendido do PDV) e uma linha por produto.
-- ##########################################################################

-- ==========================================================================
-- PRECO DE VENDA: passa a vir do PDV (iComanda)
-- ==========================================================================
-- POR QUE
--   O preco_venda de est_produtos veio de uma importacao antiga que pegou o
--   campo errado: 106 dos 285 produtos com ficha estao com um valor que bate
--   com o CUSTO da propria ficha, e o resto e valor solto sem sentido
--   (MICHELOB a R$ 0,39, GUARANA ZERO a R$ 0,23).
--
-- DE ONDE VEM O NUMERO NOVO
--   Campo produto_preco_atual dos itens de venda do iComanda, coletado nos 30
--   dias de 04/08 a 02/09/2026. Conferido antes de usar:
--     - 380/380 produtos com UM UNICO preco no periodo (ninguem mudou de preco)
--     - 32 produtos vendidos nas duas lojas, ZERO com preco diferente entre elas
--     - o casamento e por pdv_map (icomanda_produto_id -> produto_id), nunca por
--       nome, e todos os 377 mapeamentos tem fator 1
--   Usei o preco de TABELA e nao o cobrado, porque o cobrado carrega desconto.
--
-- ESCOPO
--   PASSO 2: grava o preco em 349 produtos VENDA (todos ativos).
--   PASSO 3: zera preco_venda de tudo que nao e VENDA (MP, MC, SA, PPC, PPP, PPB).
--   NAO TOCA nos 185 produtos VENDA ativos que nao tem mapeamento no PDV -
--   sem venda registrada nao ha de onde tirar preco. Estao na planilha.
--
-- Rodar PASSO 1 primeiro. Ele nao altera nada.
-- ==========================================================================


-- --------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA: o retrato de hoje
-- --------------------------------------------------------------------------
SELECT tipo,
       count(*)                                      AS produtos,
       count(*) FILTER (WHERE coalesce(preco_venda,0) > 0) AS com_preco
  FROM est_produtos
 WHERE ativo = true
 GROUP BY tipo
 ORDER BY 1;
-- Esperado: VENDA 507 (422 com preco); os demais somam 897 produtos, 752 com preco.


-- --------------------------------------------------------------------------
-- PASSO 2 - GRAVA O PRECO DO PDV
-- --------------------------------------------------------------------------
UPDATE est_produtos p
   SET preco_venda = v.preco
  FROM (VALUES
    ('58fe9427-a3ce-4d80-bfa6-0ebc0efbbd6d'::uuid, 7.90),   -- AGUA SEM GAS                               era     0.00
    ('3364e0f1-6d9f-4310-8620-1733b9337531'::uuid, 7.90),   -- HAPPY HOUR CHOPP BRAHMA 300ML              era     0.09
    ('5339c8be-cb08-497c-a8c9-1ed0451169bd'::uuid, 159.90),   -- TAMBAQUI DE BANDA                          era   159.90
    ('5f86cc74-5d69-48db-9ce5-2b202be24ed2'::uuid, 15.90),   -- CHOPP BRAHMA 300 ML                        era     0.09
    ('b06ff934-25ed-48fe-b302-b4d3bb252b1f'::uuid, 9.90),   -- COCA COLA ZERO 350ML LT                    era     0.25
    ('ad3913ed-e4c5-4c2e-9978-0f76c77f172c'::uuid, 21.90),   -- ORIGINAL 600ML                             era     0.39
    ('b988be32-2f81-4de5-8a7c-9f347da6ff89'::uuid, 12.90),   -- HAPPY HOUR CHOPP BRAHMA 500ML              era     0.13
    ('cbec1c35-5d9b-415f-ac21-2fe64d4dd582'::uuid, 7.90),   -- AGUA COM GAS                               era     0.00
    ('14871721-87b6-43d1-987d-cd1ba2fd827f'::uuid, 109.90),   -- TAMBAQUI DE BANDA DL (2 PESSOAS)           era     0.00
    ('6bb749a3-6e6a-47f2-99fc-479a8c11e05f'::uuid, 25.90),   -- CHOPP BRAHMA 500 ML                        era     0.14
    ('1f51229e-ab01-42c0-84c8-1eade778f1f7'::uuid, 9.90),   -- COCA COLA 350ML LT                         era     0.25
    ('1e024f4a-93a7-4e4a-aea4-b3e5fc668545'::uuid, 9.90),   -- HAPPY HOUR CHOPP SUJO BRAHMA 300ML         era     0.28
    ('ba14ae45-0a2a-44d1-b8a0-4c005d798f11'::uuid, 14.90),   -- HAPPY HOUR CHOPP SUJO BRAHMA 500ML         era     0.52
    ('bf052219-d62d-4080-ab17-6b068b99c1f5'::uuid, 54.90),   -- ISCA CROCANTE DE PIRARUCU                  era    11.08
    ('1a1d732d-eded-4350-9b1f-2126c1bfc7a5'::uuid, 72.90),   -- COSTELA DE TAMBAQUI ASSADA - DELIVERY      era    16.85
    ('d9a9d949-6c84-4647-8fbe-311dcf9724b5'::uuid, 20.90),   -- CAIPIRINHA CACHACA TRADICIONAL             era     2.34
    ('6a03390c-6cb3-4139-91b5-08604e40028e'::uuid, 17.90),   -- CHOPP SUJO BRAHMA 300ML                    era     0.32
    ('31cf57be-6c5d-40d9-ab17-dee85f30d219'::uuid, 17.95),   -- BOLINHO DE TAMBAQUI 5 UN                   era     3.46
    ('f622b82c-7b7f-4451-9a1c-d20bf48f5658'::uuid, 39.90),   -- CABOCO ENROLADO                            era     0.00
    ('c8b220ed-a151-4a4a-9583-33d5399676a1'::uuid, 39.90),   -- EMPANADO DE PIRARUCU                       era    27.37
    ('a13761b4-9c9d-4155-a3b5-24fecb0c5ee9'::uuid, 29.90),   -- ESTROGONOFF DE FRANGO - TDB                era    23.23
    ('abac30d3-9f7e-4a53-8217-f656a603bdaa'::uuid, 15.90),   -- CAIPIRINHA HAPPY HOUR TRADICIONAL          era     2.34
    ('e8c76e6a-bf30-44c0-84b9-329a3c818e4a'::uuid, 39.90),   -- TACACA                                     era     9.77
    ('b2cd6c47-6fba-4720-ae04-92eed5d93875'::uuid, 29.90),   -- MARMITA DE FRANGO ASSADO NA BRASA          era    25.74
    ('4354ac6c-6668-4bc4-a03a-193fe5014b58'::uuid, 24.90),   -- STELLA ARTOIS 600ML                        era     0.00
    ('f2d44efd-1bc9-4371-aea6-e25da1a17cbc'::uuid, 22.90),   -- SPATEN 600ml                               era     0.49
    ('1364487f-9dcc-4886-873d-356c6f1b2f26'::uuid, 20.95),   -- BOLINHO DE PIRARUCU 5 UN                   era     0.37
    ('0f7a4523-75a5-4a7b-9d9b-0ff06fd2f40b'::uuid, 25.90),   -- HAPPY HOUR BOLINHO DE TAMBAQUI 10 UN       era     6.70
    ('8452b5e4-2351-4306-9309-251125bfb49d'::uuid, 36.90),   -- ACAI COM TAPIOCA 300ml                     era    11.84
    ('3efbbb4f-29d9-412e-85aa-cebafb2137dd'::uuid, 34.90),   -- DADINHO DE TAPIOCA                         era     3.74
    ('d83294a5-f4f4-4c18-b250-d731718f83de'::uuid, 69.90),   -- DELICIA DE PIRARUCU                        era    12.39
    ('d71d4c58-a322-463b-80ad-fb64080fd6e2'::uuid, 29.90),   -- PIRARUCU DESFIADO                          era    11.67
    ('51f8056c-7a45-4189-835f-06f4b685870d'::uuid, 18.90),   -- SUCO DE TAPEREBA                           era     5.05
    ('5917edfc-0e35-4199-87e1-674c4f9a9d5c'::uuid, 29.90),   -- ESTROGONOFF DE FRANGO                      era    23.23
    ('99794402-2a96-43a2-8d49-bd6424eff9a7'::uuid, 39.90),   -- TAMBAQUI PICADINHO                         era     6.58
    ('bebfde33-a985-42d9-a0e6-6eab341a3205'::uuid, 18.90),   -- SUCO DE MARACUJA                           era     3.91
    ('108b8ae6-2426-4bfa-985c-54644952e4a7'::uuid, 14.90),   -- SUCO DE LIMAO                              era     1.05
    ('88096781-d884-461a-b565-ce2129d63d41'::uuid, 9.90),   -- BARE 350ML LT                              era     0.28
    ('8f5b3fea-fd9a-41c3-a5ac-a33c6f2e66ea'::uuid, 39.90),   -- FRANGO A PARMEGIANA - TDB                  era    26.09
    ('97302e99-3e21-4ce6-934c-12e77d439f72'::uuid, 27.90),   -- CHOPP SUJO BRAHMA 500ml                    era     0.45
    ('6febbbd9-7c1e-4e8f-b44b-be41c89dee08'::uuid, 24.90),   -- BATATA FRITA                               era    17.60
    ('96a49ee1-284f-4624-8e5e-d82d4f75ee32'::uuid, 14.90),   -- PUDIM DE LEITE                             era     0.00
    ('84911890-665b-4628-84cc-e7512d4e159c'::uuid, 22.90),   -- FAROFA DE BANANA                           era    32.23
    ('1447281d-b246-466b-9168-d11bb484ce84'::uuid, 29.90),   -- MARMITA DE FRANGO ASSADO NA BRASA - TDB    era    24.98
    ('ccc6eeb1-a0a8-4150-a201-43acf520f652'::uuid, 24.90),   -- SUCO DE LARANJA                            era     7.20
    ('ff579e43-f7dc-4f17-9ae9-6df88a45efae'::uuid, 69.90),   -- CAMARAO COM CATUPIRY                       era    13.72
    ('e5ac85a0-5958-4127-963d-3d80f9f88c4a'::uuid, 49.90),   -- TACAQUI O NHOQUE                           era    11.35
    ('fa5a5621-6158-4723-909a-a0a68fffaf30'::uuid, 9.90),   -- GUARANA ANTARTICA ZERO 350ML LT            era     0.23
    ('f55d4fa0-45e3-4176-8318-023bf2527228'::uuid, 74.90),   -- PIRARUCU A PARMEGIANA                      era    13.43
    ('0a0044a1-3b61-471f-b96c-b493c8c707fb'::uuid, 79.90),   -- CAMARAO ALHO E OLEO                        era    20.97
    ('56d51b99-3f73-4ae0-9e9e-b4cfbe462e0d'::uuid, 24.90),   -- HAPPY HOUR DADINHO DE TAPIOCA              era     3.74
    ('875189ed-b32c-4379-ba12-3aae1d62a490'::uuid, 24.90),   -- SUCO DE CUPUACU                            era     5.28
    ('5ec46a1d-96cb-4c68-8d4b-f483439a70f5'::uuid, 21.90),   -- BATATA FRITA HAPPY HOUR                    era    52.80
    ('45a6d42f-a29e-476d-a1df-3aa8eeea4070'::uuid, 22.90),   -- HAPPY HOUR PASTEL DE QUEJO COALHO 6 UN     era     2.35
    ('c5b32690-96b4-47ab-9352-3ee5e5aef46f'::uuid, 12.90),   -- BANANA FRITA DESCONTO                      era     1.90
    ('c943c681-5c61-417a-a9dd-1a49308350d6'::uuid, 94.90),   -- MOQUECA CABOCA                             era    23.09
    ('6342893a-c34b-43b2-8421-c0b4050b31c6'::uuid, 52.90),   -- FRANGO ASSADO NA BRASA + 2 ACOMPANHAMENT   era    15.76
    ('754f9752-50ff-4956-9b34-c9e3c1ab95b6'::uuid, 239.90),   -- TAMBAQUI DE CASACA 3 PESSOAS               era     0.00
    ('5a2e7a20-533c-431d-8dc4-3e0e28d5a08b'::uuid, 29.90),   -- CABOCO ENROLADO (HAPPY HOUR)               era     0.00
    ('13222127-bd00-4f8d-8bd5-6d0602d7811d'::uuid, 15.90),   -- TORTA DE CUPUACU C/ CHOCOLATE              era     6.50
    ('78b944f4-db57-44ec-ace0-a3d10c7b42a4'::uuid, 23.90),   -- SUCO DE ABACAXI C/ HORTELA                 era     3.94
    ('e3ff86f4-af1b-4e7c-ba88-206478b99478'::uuid, 19.90),   -- COMPOTE-SE DE CUPUACU                      era     0.00
    ('1a1d732d-eded-4350-9b1f-2126c1bfc7a5'::uuid, 59.90),   -- COSTELA DE TAMBAQUI ASSADA - DELIVERY      era    16.85
    ('39b9301d-2734-426a-9a91-8e936545a647'::uuid, 26.90),   -- LEGUMES SALTEADOS                          era     4.95
    ('1d08f2ba-41b8-4934-9e56-98ee88153328'::uuid, 31.90),   -- MACAXEIRA FRITA                            era     4.95
    ('cc7399a7-2279-401f-8512-ebde5128d632'::uuid, 164.80),   -- 2 BANDAS DE TAMBAQUI                       era    65.69
    ('1295f860-4be8-4004-b621-4694a6a407d5'::uuid, 15.90),   -- STELLA ARTOIS GOLD LN                      era     0.00
    ('104d552e-7ee9-48ae-9861-5f8c6243611f'::uuid, 0.01),   -- TAMBAQUI PICADINHO CANTOR                  era     0.00
    ('d82d4a9c-8465-4c55-a9b4-914e85a84fd4'::uuid, 14.90),   -- LIMONADA SUICA                             era     1.44
    ('96ceafef-e6e7-478f-ab02-5e9c2a4f4acc'::uuid, 86.90),   -- MOQUECA DE PIRARUCU COM CAMARAO            era    18.65
    ('4a94403b-186f-45f3-ba82-d067b010be86'::uuid, 7.90),   -- EXPRESSO VIBRANTE                          era     0.00
    ('dba0f0b3-d220-4ca4-be38-fb1846cb9d4c'::uuid, 29.90),   -- CAIPIRU CACHACA DE JAMBU                   era    29.90
    ('1a1d732d-eded-4350-9b1f-2126c1bfc7a5'::uuid, 55.00),   -- COSTELA DE TAMBAQUI ASSADA - DELIVERY      era    16.85
    ('0e2fbbb6-615c-4e90-823f-4a72ba93d6fb'::uuid, 243.90),   -- MATRINXA DE CASACA                         era    63.26
    ('b9204a46-8cb2-497b-8380-fc1d5b0bfd64'::uuid, 20.90),   -- SODA GUARANA                               era     3.96
    ('5e4b4494-61f1-48fc-b444-7ecf679d8b66'::uuid, 98.90),   -- MEDALHAO DE FILE COM FRITAS                era    33.47
    ('dc14b0ed-5794-4c7d-9dbf-a14db3661d31'::uuid, 9.90),   -- GUARANA ANTARTICA 350 ML LT                era     0.23
    ('484fcb03-f42b-432d-8f04-84cc3969975b'::uuid, 89.90),   -- COSTELA DE TAMBAQUI NO TUCUPI COM JAMBU    era    20.28
    ('45fdb64b-b706-4a4e-a45a-6c11551015af'::uuid, 78.90),   -- PIRARUCU DE CASACA COM VATAPA              era    16.13
    ('f86e6b8c-a7c3-4d54-bc74-705d7b6e7130'::uuid, 1.50),   -- EMBALAGEM GRANDE                           era     0.00
    ('689beba1-512e-4011-b692-6962a2f7ddfe'::uuid, 15.90),   -- TORTA DE CUPUACU C/ CASTANHA               era     4.00
    ('7f328871-3011-4eee-ac00-b85c4216b399'::uuid, 15.90),   -- SUCO DE MANGA                              era     3.40
    ('c081b3a9-6a37-41e0-8667-a39538fa8402'::uuid, 32.90),   -- PASTEL DE QUEIJO COALHO 6 UN               era     4.69
    ('fbe6f312-a195-4188-814b-5b8940ad0a56'::uuid, 4.90),   -- MAIONESE DE ERVAS                          era    10.55
    ('5868ddc0-6d43-4ed5-9d37-01d7441428c5'::uuid, 18.90),   -- CORONA ZERO ALCOOL LN                      era     0.25
    ('97780c8b-e54f-4c89-bf4b-8722e77bf50e'::uuid, 25.90),   -- CAIPIRU HAPPY HOUR                         era     2.34
    ('99794402-2a96-43a2-8d49-bd6424eff9a7'::uuid, 44.90),   -- TAMBAQUI PICADINHO                         era     6.58
    ('874fc185-13ef-4bcb-b82a-4ec5e932d343'::uuid, 25.90),   -- SUCO DE GRAVIOLA                           era     5.68
    ('0615177f-86b9-412f-b5fa-63bf83b78f01'::uuid, 33.90),   -- PASTEL MISTO 6 UN                          era     7.54
    ('4b52f3e9-b462-4820-8f42-b1290652d325'::uuid, 0.01),   -- CHOPP BRAHMA 300 ML SUNSET                 era     0.09
    ('bf17e30b-4d71-4007-8785-7320375451ee'::uuid, 65.90),   -- SARDINHA FRITA 2 UN                        era    14.06
    ('7bce4722-c329-410b-a334-f1c6400a0109'::uuid, 46.90),   -- AMBUCU DE CANA                             era    46.90
    ('c6c91984-db6a-424e-abe4-c2ebd9ba7a78'::uuid, 27.90),   -- BOTACOCO                                   era     6.95
    ('7cbd9777-e75b-43d1-864a-0db92da94578'::uuid, 13.90),   -- BANANA FRITA                               era     1.90
    ('056829c8-58b1-4c9f-8fc2-0c6d83646551'::uuid, 22.90),   -- JAMBUCANA DOSE                             era    22.90
    ('cc4cba88-bffa-445c-bae5-5c913d2be5ba'::uuid, 22.90),   -- HAPPY HOUR PASTEL DE TAMBAQUI 6 UN         era     2.53
    ('bbc888a3-391b-4ef8-a1b4-1105c4847dc4'::uuid, 40.90),   -- JUMA                                       era    40.90
    ('8dc2812d-4b46-4682-9803-2475fb967460'::uuid, 39.90),   -- FRANGO A PARMEGIANA                        era    26.09
    ('3c4c648b-54c0-4a7c-bd6a-901fb864c647'::uuid, 66.90),   -- MOQUECA VEGETARIANA                        era    12.15
    ('2f15d655-eacf-45b0-bce4-2b4c3f2533f8'::uuid, 21.90),   -- MACAXEIRA FRITA HAPPY HOUR                 era     6.70
    ('2141471c-f351-4216-a973-47c429dcf6be'::uuid, 26.90),   -- SUCO DE LARANJA C/ ACEROLA                 era     6.52
    ('e501125d-43e5-4c5f-8cf7-4a28a454b38c'::uuid, 22.90),   -- CAIPIROSKA VODKA NACIONAL                  era    22.90
    ('959fc4a8-1628-42c3-a41d-3c843e0a62f4'::uuid, 63.90),   -- PIRARUCU EMPANADO COM FRITAS               era    27.37
    ('16a05c4c-b043-4b3e-8d0c-fd118c2ecbfd'::uuid, 32.90),   -- CHEESCAKE DE CHOCOLATE COM CUPUACU         era     0.00
    ('c1bbafdd-0212-4ede-ae96-c49a31e84893'::uuid, 29.90),   -- VATAPA                                     era     6.80
    ('a6aad8d9-19f5-413b-a4f5-b47be8a4647a'::uuid, 21.90),   -- SUCO DE ABACAXI                            era     3.49
    ('58f92701-a8e7-4a6d-b2eb-668c809deb58'::uuid, 40.90),   -- PASTEL DE CAMARAO CREMOSO 6 UNID           era     8.98
    ('7a48ab73-7a63-42d4-829d-471a90480cd0'::uuid, 14.90),   -- ARROZ                                      era     1.14
    ('3cd5917d-9135-4a5b-ad1d-67986c26c848'::uuid, 1.00),   -- EMBALAGEM PEQUENA                          era     0.00
    ('70292ede-9f55-4c1c-9878-b0ad0c4a4312'::uuid, 41.90),   -- VITORIA REGIA                              era    41.90
    ('5810c8f0-02c3-4e7c-9fd6-ead494d989c2'::uuid, 18.90),   -- CORONA LN                                  era     0.25
    ('31bd6816-303b-4cb7-8cc0-c6c717b5c54c'::uuid, 142.70),   -- TAMBAQUI DE BANDA + COCA ZERO 1,5L + FAR   era    32.23
    ('e458e8ab-03fb-4108-b127-82f2badc18b4'::uuid, 16.90),   -- SUCO DE ACEROLA                            era     3.88
    ('0c5cdfba-481e-4c3e-81f3-b54f074f63bc'::uuid, 15.90),   -- TORTA DE ABACAXI                           era     6.50
    ('57569af8-9ab2-4513-afbc-87770e0a3594'::uuid, 27.90),   -- PETIT GATEAU                               era     9.46
    ('d6c9055b-de67-4b0a-b23c-12a3f585badf'::uuid, 17.90),   -- CAIPIROSKA HAPPY HOUR TRADICIONAL          era     2.34
    ('b3dbea5a-c489-454f-b2c6-b28c1f28e2c4'::uuid, 20.90),   -- SODA TAPEREBA                              era     2.36
    ('7cbd9777-e75b-43d1-864a-0db92da94578'::uuid, 19.90),   -- BANANA FRITA                               era     1.90
    ('bfeca2d7-22d3-4f12-af89-1bf92473ae81'::uuid, 16.90),   -- VINAGRETE                                  era     1.42
    ('e2c2382e-9f4e-435f-98c9-d02644411af4'::uuid, 9.90),   -- SPRITE LT                                  era     0.20
    ('2ca72521-411c-4f68-8a44-503fe7cae09a'::uuid, 9.90),   -- SCHWEPPES CITRUS LT                        era     0.25
    ('3e4a141c-14c8-4592-8dcb-90e1857646d2'::uuid, 16.90),   -- BAIAO DE DOIS                              era     1.56
    ('a30b14fc-5f67-4c9c-a5b9-8e07808b011b'::uuid, 7.90),   -- EXPRESSO PLENO                             era     0.00
    ('f0c60ae1-77f4-40f7-8fe4-2b954fc3968d'::uuid, 34.90),   -- PASTEL DE PIRARUCU COM BANANA 6 UNID       era     6.20
    ('7cbd9777-e75b-43d1-864a-0db92da94578'::uuid, 12.90),   -- BANANA FRITA                               era     1.90
    ('d89d3ed5-8ef4-4dd3-8970-51c21029ad06'::uuid, 38.90),   -- CUNHANTA                                   era    38.90
    ('397124be-ef1f-4526-af70-b52647252fd0'::uuid, 7.90),   -- EXPRESSO ATENTO                            era     0.00
    ('dc98adea-c64c-4b8c-aa00-9c99d2f7dc40'::uuid, 29.90),   -- CHOCUCA                                    era    10.57
    ('b497841c-e625-4f01-8913-675ef9c19904'::uuid, 11.90),   -- GUARANA ANTARTICA ZERO 2L DELIVERY         era     7.13
    ('05857e44-d085-4727-a556-016d13f4ff0e'::uuid, 105.90),   -- MOQUECA DE TAMBAQUI COM CAMARAO            era    23.77
    ('07320b97-f58c-4c9f-825b-f12aa530a5ed'::uuid, 72.90),   -- COSTELA DE TAMBAQUI FRITA                  era    16.56
    ('34046a76-c937-4b0f-afab-d36afe7b004a'::uuid, 9.90),   -- FANTA LARANJA 350ML LT                     era     0.20
    ('20dc13c7-1da5-430c-8d10-f499f311c64d'::uuid, 27.90),   -- FRANGO A PASSARINHO - TDB                  era    23.57
    ('a3cc7c54-be4a-4b7a-b55d-8047e363c94f'::uuid, 15.90),   -- STELLA ARTOIS LN                           era     0.00
    ('009fa803-5a50-47e1-ac00-27172c9391f5'::uuid, 20.55),   -- PASTEL DE CAMARAO CREMOSO 3 UNID           era     4.49
    ('cbb8bde7-88c8-4bae-8286-3a3d691fd6ef'::uuid, 32.90),   -- CEU DE BRIGADEIRO                          era    13.00
    ('491d7a24-9f81-4523-a490-13e19fcf65e5'::uuid, 15.90),   -- SUCO DE CAJU                               era     3.40
    ('502486f2-dd9e-4199-8131-d749efa892bb'::uuid, 42.90),   -- ISCA DE FRANGO KIDS COM FRITAS             era    23.42
    ('01b306df-aa77-4ef3-9420-ccae7b377fb3'::uuid, 12.90),   -- PURE DE BATATA DELIVERY                    era    14.86
    ('8be9c75b-71aa-444e-8250-0b6200675bc7'::uuid, 14.90),   -- MICHELOB                                   era     0.39
    ('db091b8f-4a38-4ca6-a2c6-bd95d399437c'::uuid, 11.90),   -- GUARANA BARE 2L DELIVERY                   era     0.72
    ('f779c3a6-6467-4648-ac24-d16d37dd40b8'::uuid, 67.90),   -- SALADA CAESAR DE TAMBAQUI                  era    18.74
    ('a91a983d-e2e4-45ab-834f-f540616ba0b2'::uuid, 46.90),   -- BOTO COR DE ROSA                           era    46.90
    ('f9fc67d6-54fe-44e9-8caf-79185dafd9fd'::uuid, 28.90),   -- CAIPILE ABACAXI E ACAI CACHACA TRADICION   era     6.82
    ('d1ab5f65-99cb-4820-8547-6527097a724e'::uuid, 25.90),   -- VATAPA DELIVERY                            era     6.80
    ('32ec7148-97a1-46a3-9a5c-e68a1f0a50fa'::uuid, 45.90),   -- (DRINK) TOADA AMAZONICA                    era    45.90
    ('b7f3270e-5bf5-49dd-8fda-fc84a331c777'::uuid, 98.90),   -- MEDALHAO DE FILE COM PURE                  era    19.76
    ('64b40733-6790-4257-86b3-2617c86fbe93'::uuid, 14.90),   -- COCA COLA ZERO1,5L                         era     1.03
    ('9ad48383-33b8-4f51-bf8e-9c5a3dc7d606'::uuid, 3.00),   -- COPO SUJO                                  era     0.26
    ('2a03ce8e-2689-4a90-b834-e564a3ce27d8'::uuid, 16.90),   -- SUCO DE GOIABA                             era     3.40
    ('d83294a5-f4f4-4c18-b250-d731718f83de'::uuid, 49.90),   -- DELICIA DE PIRARUCU                        era    12.39
    ('d3b03199-2252-4514-8ef3-20b26cab69b0'::uuid, 57.90),   -- CANELA DE INDIA                            era    57.90
    ('64824aa6-4c90-419f-9f7b-f17dd333de75'::uuid, 0.01),   -- CAIPIRINHA CACHACA TRADICIONAL SUNSET      era     2.34
    ('015a47a8-7d66-4a55-9fcd-b2794e4c0e2a'::uuid, 23.90),   -- CAIPIRINHA CACHACA ESPECIAL                era    23.09
    ('234ad8d0-f327-4858-9b01-7004a935ba4e'::uuid, 9.90),   -- TUCHAUA LT                                 era     0.17
    ('59bc94e7-e387-4ddc-8fed-2e7791c5b138'::uuid, 20.90),   -- SODA MARACUJA                              era     2.35
    ('9aada3c6-0289-4eb9-bfed-aaf046cccccd'::uuid, 86.90),   -- CALDEIRADA DE TAMBAQUI 1 COSTELA COZIDA    era    19.10
    ('db091b8f-4a38-4ca6-a2c6-bd95d399437c'::uuid, 11.90),   -- GUARANA BARE 2L DELIVERY                   era     0.72
    ('74ac61e8-4a4b-4230-bb47-bc21252405d1'::uuid, 109.90),   -- TAMBAQUI DE BANDA + 2 REFRI LATA           era     0.00
    ('6e51dbf3-5e7d-4589-861d-33eba868470d'::uuid, 17.45),   -- PASTEL DE PIRARUCU COM BANANA 3 UNID       era     3.10
    ('c0b2f21c-afb1-42a5-a8bc-ca9cac9a4181'::uuid, 51.90),   -- IARA                                       era    51.90
    ('68f6d41e-c0c2-4edd-9941-7b4a3bf9a06a'::uuid, 16.45),   -- PASTEL DE QUEIJO COALHO 3UN                era     2.35
    ('df17874a-6093-457c-9962-acc2a8642a1e'::uuid, 22.90),   -- HAPPY HOUR CAIPILE LIMAO E GRAVIOLA TRAD   era     5.07
    ('49379e9c-52d5-45f4-a7d2-b425214b6645'::uuid, 28.90),   -- PETIT GANEAU                               era     6.04
    ('ac619e29-b412-4fd6-9504-faf106b81c91'::uuid, 61.90),   -- PIRARUCU DESCONFIADO                       era    10.67
    ('82c00db3-27f0-4aa0-a69f-3bd37bb88d48'::uuid, 9.90),   -- FANTA UVA LT                               era     0.20
    ('f69aa371-5635-4447-854d-61c4f84a63ca'::uuid, 48.90),   -- APEROL SPRITZ                              era     8.45
    ('37ad444b-d6ff-4d18-b9ce-eac00c3ab186'::uuid, 9.90),   -- MAIONESE DE BATATA 250g                    era     1.79
    ('69f197cd-8af0-4297-a19f-d5f63cf1496a'::uuid, 14.90),   -- SPATEN LN                                  era     0.00
    ('fdc1a5d3-bb35-43fa-baa5-3e10453a01b0'::uuid, 16.90),   -- CHOPP VERMELHOU 300ML                      era    16.90
    ('a476d2a4-e759-4a6a-aae7-8d7361179e4c'::uuid, 49.90),   -- PAJE TANQUERAY                             era    49.90
    ('17052414-e77c-48c2-9ae0-9291e2eb8b8b'::uuid, 50.90),   -- ISCA DE CARNE KIDS COM FRITAS              era     0.00
    ('12a5892c-1cf7-4727-adcc-3ceea5b9221c'::uuid, 58.90),   -- SALADA CAESAR DE PIRARUCU                  era    13.94
    ('e64a5fcb-4d17-4c78-a1e6-3e09df71081d'::uuid, 16.90),   -- CHOPP AZULOU 300ML                         era    16.90
    ('9cc24342-cb9d-48fd-8a29-0bddab940b78'::uuid, 99.90),   -- FRANGO 2 BANDAS (COMPLETO)                 era    31.02
    ('b9607aa5-95b1-48d5-a74c-2663eb31e58b'::uuid, 9.90),   -- ANTARTICA TONICA LT                        era     0.23
    ('84911890-665b-4628-84cc-e7512d4e159c'::uuid, 17.90),   -- FAROFA DE BANANA                           era    32.23
    ('11ed0a3d-5872-4942-99ec-f69c53e48d99'::uuid, 9.90),   -- SCHWEPPES TONICA LT                        era     0.25
    ('dc414eb6-a200-486f-9aff-c7020cff5c06'::uuid, 20.90),   -- SODA CUPUACU                               era     2.29
    ('a933a48b-3136-4414-bbbf-5d8364aedfd7'::uuid, 79.90),   -- GALINHA CAIPIRA COM ARROZ                  era    11.80
    ('62a3f2f8-31a0-4b40-aebb-852010d39652'::uuid, 9.90),   -- PEPSI LATA                                 era     0.00
    ('df22542e-ec4e-470d-9ec2-1b59b1d310ed'::uuid, 85.90),   -- ESCABECHE DE TAMBAQUI                      era    17.97
    ('bf9b3b0e-7d11-4a2a-b92c-ff6b5b15d8ab'::uuid, 33.90),   -- PASTEL DE TAMBAQUI 6 UN                    era     5.20
    ('dff91b00-7593-49ed-aa07-bbcf20eebb15'::uuid, 51.90),   -- ENCONTRO DAS AGUAS TANQUERAY               era    51.90
    ('f10452cc-977b-4ac1-974a-cdcb94934d57'::uuid, 42.90),   -- ISCA DE PIRARUCU KIDS COM FRITAS           era    24.59
    ('d41ae095-f3bb-4e04-9f51-87969cfe39ca'::uuid, 46.90),   -- UIRAPURU                                   era    46.90
    ('ad5910ff-1326-43e4-bf30-6138881b5853'::uuid, 56.90),   -- LA PASSION                                 era    56.90
    ('118aae56-666a-45c8-b049-31a41e4f2bf1'::uuid, 29.90),   -- PIRARUCU DESFIADO PROMOCAO                 era    11.67
    ('32ec7148-97a1-46a3-9a5c-e68a1f0a50fa'::uuid, 45.90),   -- (DRINK) TOADA AMAZONICA                    era    45.90
    ('bc2dca2a-db49-48b7-a13e-c3b5fb3f0179'::uuid, 13.90),   -- ORIGINAL LN                                era     0.00
    ('567c6b09-8ab5-4d60-a018-6b3fc9e230b0'::uuid, 14.95),   -- PIRARUCU DESFIADO 50% DESCONTO             era    10.17
    ('1f51229e-ab01-42c0-84c8-1eade778f1f7'::uuid, 0.01),   -- COCA COLA 350ML LT                         era     0.25
    ('fa44f094-1277-4f4c-88f2-9e872ee15b54'::uuid, 39.90),   -- CAIPIFRUTA VODKA NACIONAL MORANGO          era    39.90
    ('f5805d5e-7810-4400-9987-36765032cc26'::uuid, 99.90),   -- TAMBAQUI DE BANDA DL SIMPLES S/ GUARNICA   era     0.00
    ('1a28981d-1428-42c7-bd09-02e5d5ae93ee'::uuid, 0.01),   -- Suco de Manga Copo                         era     3.40
    ('41739d01-4e90-44c5-a85e-e7a55b03c8f9'::uuid, 14.90),   -- COCA COLA 1,5L DELIVERY                    era     1.03
    ('4255cf8a-a334-4d04-9d96-20f5708d40f4'::uuid, 14.90),   -- FAROFA                                     era     1.26
    ('927ca850-4bb8-4159-9ad3-5d73696e8c41'::uuid, 35.90),   -- (DRINK) TOADA AMAZONICA NAO ALCOOLICO      era    35.90
    ('9a8e73d8-60df-4bcc-a16f-86d8efa4ba75'::uuid, 48.90),   -- SANGRIA                                    era    48.90
    ('e266bca7-7f9c-4902-a718-160ae995eea2'::uuid, 160.90),   -- CALDEIRADA DE TAMBAQUI 2 COSTELA COZIDA    era    19.91
    ('8818ba16-428a-490a-9210-ea4d96d2c14e'::uuid, 20.90),   -- SODA LIMAO                                 era     2.10
    ('63833929-9383-46ad-b2a2-fca6a91c35de'::uuid, 63.90),   -- PIRARUCU EMPANADO COM PURE                 era    14.70
    ('f69aa371-5635-4447-854d-61c4f84a63ca'::uuid, 44.90),   -- APEROL SPRITZ                              era     8.45
    ('74f0fcea-cede-45db-bef4-da69c145d952'::uuid, 12.90),   -- FEIJAO 250g                                era     0.64
    ('767fbd17-2cd9-49b0-8b6a-c16039502c05'::uuid, 66.90),   -- SARDINHA ASSADA 2 UN                       era    14.38
    ('e458e8ab-03fb-4108-b127-82f2badc18b4'::uuid, 0.01),   -- SUCO DE ACEROLA                            era     3.88
    ('95835abd-bef2-4326-9ef6-25ed8d064ce1'::uuid, 32.90),   -- SALADA CAESAR REGIONAL                     era     6.24
    ('f55d4fa0-45e3-4176-8318-023bf2527228'::uuid, 59.90),   -- PIRARUCU A PARMEGIANA                      era    13.43
    ('f82c1e42-5b1d-487c-9c8c-70e6a2552242'::uuid, 20.90),   -- SODA MANGA                                 era     2.23
    ('49bfd5ab-6440-4bc4-af22-eb22a26e2de5'::uuid, 99.90),   -- TAMBAQUI DE BANDA CLIENTE FIEL             era    32.54
    ('54aa8a9d-03ea-46f4-b7f3-7465682d118d'::uuid, 2.00),   -- LIMAO E SAL                                era     0.40
    ('0a575d7e-e82c-4dcd-a0fc-6e960aaa2c0e'::uuid, 22.90),   -- SODA GARANTIDO                             era    22.90
    ('2556c302-5812-4c9c-b344-8f12c924d572'::uuid, 39.90),   -- CAIPIFRUTA VODKA NACIONAL MARACUJA         era    39.90
    ('2a03ce8e-2689-4a90-b834-e564a3ce27d8'::uuid, 0.01),   -- SUCO DE GOIABA                             era     3.40
    ('03440849-3833-4017-ab7b-1d8fdfb1520d'::uuid, 9.90),   -- PEPSI BLACK LATA                           era     0.00
    ('8594afca-13e8-4f57-ab52-06f03baff539'::uuid, 22.90),   -- SODA CAPRICHOSO                            era    22.90
    ('5f855f6d-273d-4dc2-96aa-2ab9bad874d6'::uuid, 17.90),   -- BANANA FRITA COM ACUCAR HAPPY HOUR         era     1.90
    ('f6fc3934-e30f-43f2-a3ad-8dd75ea4ffd3'::uuid, 27.90),   -- FRANGO A PASSARINHO                        era    23.57
    ('c16677ca-9fb2-47dd-ae83-6fedbf50a834'::uuid, 6.90),   -- MOLHO TARTARO                              era     1.59
    ('d7701761-c9b7-4f7e-9c07-2ad07dbabf66'::uuid, 61.90),   -- AMAZONIA EXOTICA                           era    61.90
    ('2b062a76-4d8b-4699-81f4-c1bbd24b7701'::uuid, 5.90),   -- CALDINHO DE TAMBAQUI                       era     0.60
    ('0028f78c-2c9b-44bc-8b20-8a2cdb28fa7c'::uuid, 16.95),   -- PASTEL DE TAMBAQUI 3UN                     era     2.53
    ('de80115f-4eea-46be-a4d3-202765e67dcd'::uuid, 14.90),   -- COCA COLA ZERO 1,5L DELIVERY               era     1.03
    ('d8d595f0-0cba-4e16-950f-1676bc768f9d'::uuid, 16.90),   -- PIRAO DE TAMBAQUI                          era     2.09
    ('d1ca345b-e23f-41b2-8fbf-8a9896becb20'::uuid, 78.90),   -- SALADA CAESAR DE CAMARAO                   era    16.71
    ('569fb75f-fe51-4c5e-ae1a-16a9c0f6a907'::uuid, 21.90),   -- (DRINK) CAIPIRINHA CAPRICHOSA - TRADICIO   era    21.90
    ('96a49ee1-284f-4624-8e5e-d82d4f75ee32'::uuid, 16.90),   -- PUDIM DE LEITE                             era     0.00
    ('6606ec72-8352-4e30-b16a-622522005ce7'::uuid, 14.90),   -- BUDWEISER LN                               era     0.00
    ('05d30c04-06b5-4748-8743-ad952ab5783c'::uuid, 21.90),   -- (DRINK) CAIPIRINHA GARANTIDA - TRADICION   era    21.90
    ('e60252ab-cbdf-4b7c-8e14-77e8cec4505b'::uuid, 56.90),   -- LE MAGNIFIQUE                              era    56.90
    ('0d7c8d6f-21a7-4719-9ebb-6d20b0e5c2cf'::uuid, 8.00),   -- BARE 1 LITRO                               era     0.00
    ('491d7a24-9f81-4523-a490-13e19fcf65e5'::uuid, 0.01),   -- SUCO DE CAJU                               era     3.40
    ('77ea4054-6ac7-48e6-95ee-98bb2ad1a167'::uuid, 0.01),   -- TAMBAQUI DE BANDA - GUIA                   era    32.54
    ('2916b2ec-8217-4b0a-8d54-675cc0d76ad9'::uuid, 20.90),   -- SODA GRAVIOLA                              era     2.80
    ('4747af85-a151-45f2-955a-e8f7b4985537'::uuid, 13.95),   -- PASTEL DE MISTO 3UN                        era     3.77
    ('58e52983-77e3-4674-b493-46fc8b6da9ea'::uuid, 8.90),   -- CAFE COM LEITE                             era     0.00
    ('366d6cf7-b21c-4f0d-badb-57a66f4f702f'::uuid, 20.90),   -- SODA ABACAXI                               era     3.35
    ('72b8a8b4-20ce-47e6-872c-4b2430038eb2'::uuid, 26.90),   -- PETIT GATEAU HAPPY HOUR                    era     6.70
    ('4a6cce29-10c2-4ae7-a793-f821faf4849f'::uuid, 6.90),   -- MAIONESE DE TUCUPI                         era     1.59
    ('57c4782e-1187-4b5a-87c0-15a1227e2791'::uuid, 42.90),   -- ISCA DE PIRARUCU KIDS COM PURE             era     9.80
    ('5c966278-68c8-4159-b77d-0ca09a0e27d2'::uuid, 38.90),   -- ARROZ DE TACACA                            era     8.11
    ('8b4c2dc3-e1a4-4733-bd18-08d36118aa10'::uuid, 0.01),   -- SUCO DE CAJU SUNSET                        era     3.40
    ('e434aeb8-b667-4864-af2f-f824058b87bf'::uuid, 0.01),   -- SUCO DE MANGA SUNSET                       era     3.40
    ('9ffa9fca-673e-467c-983c-54f8045df01f'::uuid, 12.90),   -- BAIAO DE DOIS 500g                         era     2.43
    ('57968009-df85-417d-a790-0326de6b5057'::uuid, 9.90),   -- ARROZ BRANCO DELIVERY                      era     0.87
    ('6e13264e-1ce1-4ec5-a444-e0c0afedbccf'::uuid, 47.90),   -- FRANGO DE BANDA (COMPLETO)                 era    15.76
    ('29b7644f-9e23-43ce-9330-a914b2273b7d'::uuid, 39.90),   -- CAIPIFRUTA VODKA NACIONAL DE ABACAXI       era    39.90
    ('96a49ee1-284f-4624-8e5e-d82d4f75ee32'::uuid, 17.90),   -- PUDIM DE LEITE                             era     0.00
    ('85e304e1-f793-4abc-ba2a-3173f8a47406'::uuid, 8.00),   -- ADIC DE SORVETE                            era     2.60
    ('41e952a0-5b24-412b-b2af-3e2b35329700'::uuid, 0.01),   -- SUCO DE GOIABA SUNSET                      era     3.40
    ('5cb50514-b325-4174-8b1f-3c279dabdf97'::uuid, 48.90),   -- (DRINK) FESTEJO VERMELHO                   era    48.90
    ('31374cfc-c38c-4981-ada0-8613dd958f6f'::uuid, 42.90),   -- ISCA DE FRANGO KIDS COM PURE               era     8.58
    ('8c58ba73-fee8-4b05-b29e-50a2607526fd'::uuid, 9.90),   -- SODA LIMONADA LATA                         era     0.00
    ('8d03e3bd-69cb-4e25-b93a-e931caf890b6'::uuid, 50.90),   -- ISCA DE CARNE KIDS COM PURE                era     0.00
    ('41338c00-4201-4456-9acf-455f6b0c97e5'::uuid, 18.90),   -- CHOPP VERMELHOU SUJO 300ML                 era    18.90
    ('8c58ba73-fee8-4b05-b29e-50a2607526fd'::uuid, 9.90),   -- SODA LIMONADA LATA                         era     0.00
    ('6f9e88ab-9745-461b-a7e1-a333b3140195'::uuid, 0.01),   -- COSTELA DE TAMBAQUI CANTOR Assado-cantor   era    15.08
    ('002efcd4-9a65-4ac5-b038-cee0ae5f6077'::uuid, 7.90),   -- MOLHO DE CUPUACU COM PIMENTA               era     1.57
    ('288c73d4-32e6-4f33-92f2-67fb3a14c6e8'::uuid, 229.90),   -- MATRINXA COM VINAGRETE                     era    61.72
    ('e69da76a-e1ab-4e31-904d-4f2e2308d5b8'::uuid, 28.90),   -- CAIPILE LIMAO E GRAVIOLA CACHACA TRADICI   era     5.07
    ('3f3eb352-d1b5-42f7-b9cb-4cd1bb0c9b53'::uuid, 8.90),   -- CAPUCCINO                                  era     0.00
    ('6febbbd9-7c1e-4e8f-b44b-be41c89dee08'::uuid, 13.90),   -- BATATA FRITA                               era    17.60
    ('fdaafd1d-fb8f-4824-9625-1db1b1f3df1c'::uuid, 15.90),   -- PORC LEGUMES SALTEADOS 250g                era     3.54
    ('e093b97e-d614-4e62-8bfe-e148277d9a6b'::uuid, 46.90),   -- (DRINK) EVOLUCAO ESTRELADA                 era    46.90
    ('38cac168-cce6-472c-b36b-fc9fbeca004e'::uuid, 24.90),   -- (DRINK) CAIPIRINHA CAPRICHOSA - ESPECIAL   era    24.90
    ('ef1718da-803c-43a7-8552-39c0cc69c618'::uuid, 29.90),   -- COLORADO RIBEIRAO 600ml                    era     0.91
    ('ecfbf591-aa3c-409d-8d1e-d4445552fbfe'::uuid, 76.90),   -- SARDINHA ASSADA NA FOLHA DA BANANEIRA 2    era    16.67
    ('865304f9-9225-4c26-8c6b-b680b5470879'::uuid, 0.01),   -- CHOPP AZULOU 300 ML SUNSET                 era     0.09
    ('26cbf768-1a96-44d0-b721-a9cb10af1a94'::uuid, 3.90),   -- ADC. LEITE COPO                            era     0.80
    ('c200198a-f403-48e5-a55b-c498c32b3364'::uuid, 38.90),   -- (DRINK) EVOLUCAO ESTRELADA NAO ALCOOLICO   era    38.90
    ('0531bac1-d393-410b-854d-bf96f7c03eff'::uuid, 20.90),   -- SODA GOIABA                                era     2.23
    ('76bad75f-13a0-4599-bd4e-2524605070cb'::uuid, 22.90),   -- ARROZ COM TUCUPI E JAMBU                   era     3.61
    ('f4d5a79b-a0c1-4949-89fa-500873dc94a7'::uuid, 8.90),   -- HAPPY HOUR CHOPP AZULOU 300ML              era     0.09
    ('9ff7e9c5-f5d6-4ccf-90d4-ef9437fd4aac'::uuid, 38.90),   -- (DRINK) FESTEJO VERMELHO NAO ALCOOLICO     era    38.90
    ('1f335a5f-28f8-4525-bdae-5ce8329f9081'::uuid, 16.90),   -- BANANA ASSADA                              era     1.90
    ('0a999981-0803-4dbf-8fea-6bfff0b6eb8e'::uuid, 20.90),   -- SODA ACEROLA                               era     2.35
    ('257842ba-6a35-403c-a848-2a61b7f1df90'::uuid, 38.90),   -- FAROFA DE CAMARAO                          era     8.15
    ('3b286354-3f13-43b6-b597-cb462fca2b8c'::uuid, 79.90),   -- GALINHA CAIPIRA COM MACARRAO               era    11.12
    ('ef649810-872c-4635-8329-3ba6344bc0aa'::uuid, 30.00),   -- MOLHO DE PIMENTA                           era     0.00
    ('338eee53-a9ac-4333-858a-f24f0b80853c'::uuid, 4.90),   -- OVO FRITO                                  era     1.03
    ('bacfdef1-f2a2-4f09-8fe0-2f2ea2d5dfb6'::uuid, 38.90),   -- (DRINK) TRIUNFO DO POVO - NAO ALCOOLICO    era    38.90
    ('927ca850-4bb8-4159-9ad3-5d73696e8c41'::uuid, 35.90),   -- (DRINK) TOADA AMAZONICA NAO ALCOOLICO      era    35.90
    ('8fe12461-e934-4140-807e-91e36a60c911'::uuid, 26.90),   -- CHOPP AZULOU 500ML                         era    26.90
    ('10b0e3ef-3e4c-4a8d-bf36-bfdf533cd5f3'::uuid, 0.01),   -- (DRINK) CAIPIRINHA CAPRICHOSA - SUNSET     era     0.00
    ('f1f58092-89a8-4221-8ef3-6e1134d14cf0'::uuid, 0.01),   -- (DRINK) CAIPIRINHA GARANTIDA - SUNSET      era     5.93
    ('acfcbbbf-3b50-409a-96a6-4e82cd0cb41a'::uuid, 27.90),   -- WHISKY BLACK LABEL DOSE                    era    27.90
    ('36193466-76c8-460f-832f-74ce7c5b4853'::uuid, 10.90),   -- CACHACA TRADICIONAL OURO DOSE              era    10.90
    ('f804539a-c312-4788-95ae-6e1182c9476f'::uuid, 8.90),   -- HAPPY HOUR CHOPP VERMELHOU 300ML           era     0.08
    ('6ea3c6e9-a905-4948-9b86-c8899ec3ff31'::uuid, 35.90),   -- CAIPIROSKA VODKA IMPORTADA                 era    35.90
    ('650477f5-671b-4c89-8e15-79f995bad490'::uuid, 28.90),   -- CHOPP AZULOU SUJO 500ML                    era    28.90
    ('9f230979-36a9-4885-9476-1ef49a61babe'::uuid, 0.01),   -- MOQUECA VEGETARIANA CANTOR                 era    12.75
    ('dfe061d2-e7cc-4a12-8b39-7d68ed6cfcdb'::uuid, 18.90),   -- PURE DE MACAXEIRA                          era     7.42
    ('3d9e3506-306a-4111-be4b-8abbe87e9fc6'::uuid, 35.90),   -- LICOR 43 DOSE                              era    35.90
    ('72d6cca6-2549-47fe-a2cd-8c52eca5502b'::uuid, 18.90),   -- SALADA DE FEIJAO DE PRAIA                  era     3.59
    ('c188aa47-59bc-40f3-8899-df14e47cf293'::uuid, 65.90),   -- L AMOUR ROSE                               era    65.90
    ('8c88efa8-08c6-41b4-a204-341bfa7c7eba'::uuid, 160.90),   -- CALDEIRADA DE TAMBAQUI 2 COSTELA ASSADA    era    20.19
    ('89d08432-a0d4-4fb0-b4e4-c81f356ab49f'::uuid, 64.90),   -- (DRINK) ISA A BELA GUERREIRA - TANQUERAY   era    64.90
    ('bce16254-ab4a-4179-9551-46c2ae6298a1'::uuid, 11.90),   -- VODKA NAC SMIRNOFF DOSE                    era    11.90
    ('bc0b5b98-7395-458b-96bc-c86c95581329'::uuid, 13.90),   -- HAPPY HOUR CHOPP VERMELHOU 500ML           era     0.13
    ('6d6cc63c-59da-45b5-ab5a-d627a7a0d48b'::uuid, 26.90),   -- CHOPP VERMELHOU 500ML                      era    26.90
    ('f6c21320-b579-4baa-813a-6d0c0373108f'::uuid, 40.90),   -- (DRINK) ISA A BELA GUERREIRA N ALCOOLICO   era    40.90
    ('ffe6e365-bdc9-458d-b560-954e0b1387fd'::uuid, 18.90),   -- CHOPP AZULOU SUJO 300ML                    era    18.90
    ('8552bf62-4eca-4830-8d6c-78918199accd'::uuid, 0.01),   -- CHOPP VERMELHOU 300 ML SUNSET              era     0.99
    ('56a24712-850b-4854-99a4-2d9d8e291299'::uuid, 9.90),   -- SUKITA LATA                                era     0.00
    ('b5aab639-31d3-4059-984b-8a6a78af9782'::uuid, 3.90),   -- OVO COZIDO                                 era     0.73
    ('b164134a-04c0-4f9d-b8c0-586ef916062b'::uuid, 12.90),   -- ARROZ 500g                                 era     1.38
    ('234ad8d0-f327-4858-9b01-7004a935ba4e'::uuid, 0.01),   -- TUCHAUA LT                                 era     0.17
    ('c615c471-0e1c-4b34-a1b4-93ced1803ffd'::uuid, 10.00),   -- CACHACA SAGATIBA DOSE                      era    10.00
    ('464a7a43-084c-4ce9-8e02-d56b6fc8cae2'::uuid, 8.90),   -- FAROFA 250g                                era     0.72
    ('a819b9d5-465e-451b-98f2-2431831c9ba7'::uuid, 86.90),   -- CALDEIRADA DE TAMBAQUI 1 COSTELA ASSADA    era    19.22
    ('e8a249a8-5af3-472f-9ca4-11d394648aca'::uuid, 17.90),   -- BATATA FRITA ACAO                          era     0.00
    ('752bcf26-55cf-4f4f-8ee0-6d46692d6371'::uuid, 9.90),   -- CACHACA TRADICIONAL PRATA DOSE             era     9.90
    ('d7d7fc43-a15a-419e-91ec-88b50737a1aa'::uuid, 54.90),   -- BOTO COR DE ROSA ESPECIAL                  era    56.90
    ('61d88830-911e-452b-b70d-f4f26e1653e5'::uuid, 12.90),   -- PURE 250g                                  era     9.73
    ('8194af17-9ecf-48d1-bbf9-cd235a5efafe'::uuid, 12.00),   -- AMBURANA DOSE                              era    12.00
    ('689beba1-512e-4011-b692-6962a2f7ddfe'::uuid, 19.90),   -- TORTA DE CUPUACU C/ CASTANHA               era     4.00
    ('88096781-d884-461a-b565-ce2129d63d41'::uuid, 0.01),   -- BARE 350ML LT                              era     0.28
    ('bdab70dd-4560-4159-aea1-61ace9d676f3'::uuid, 15.90),   -- HAPPY HOUR CHOPP SUJO AZULOU 500ML         era     0.50
    ('cbec1c35-5d9b-415f-ac21-2fe64d4dd582'::uuid, 0.01),   -- AGUA COM GAS                               era     0.00
    ('9e98af27-70fc-441e-8438-9c932ceead77'::uuid, 6.00),   -- CACHACA BRAZUKA DOSE                       era     6.00
    ('d64e5c2c-b0d1-4a76-a647-3c635f8b68fa'::uuid, 24.90),   -- (DRINK) CAIPIRINHA GARANTIDA - ESPECIAL    era    24.90
    ('daf49049-e71e-47b6-a22b-b9eb5204c879'::uuid, 36.90),   -- CAIPILE LIMAO E GRAVIOLA CACHACA ESPECIA   era    36.90
    ('0c5cdfba-481e-4c3e-81f3-b54f074f63bc'::uuid, 19.90),   -- TORTA DE ABACAXI                           era     6.50
    ('43cfc6e3-5bb3-4767-a2fa-d5604ad594d9'::uuid, 8.90),   -- PORC SALADA CRUA 250g                      era     2.00
    ('c0cc63e9-3bfa-450e-b493-e6630b22da88'::uuid, 15.90),   -- MACARRAO                                   era     2.88
    ('16fb8eed-5474-4027-be10-c527019f5673'::uuid, 15.90),   -- HAPPY HOUR CHOPP SUJO VERMELHOU 500ML      era     0.50
    ('2bd7358b-fbeb-4eee-86c3-9d8eda6a4226'::uuid, 64.90),   -- (DRINK) TRIUNFO DO POVO - TANQUERAY        era    64.90
    ('ba90f709-8953-4115-887d-0b61306b7f83'::uuid, 4.00),   -- CAIXA TAMBAQUI VIAGEM                      era     0.00
    ('eb7b4615-d86e-4929-8465-1bb3ca2d25af'::uuid, 6.90),   -- TUCUPI                                     era     1.72
    ('20c5f5dd-1a7d-4f4a-a850-e10af8ffc1e2'::uuid, 10.90),   -- JAMBU                                      era     0.70
    ('612e0cfe-17fd-4b27-8150-df18e67b340c'::uuid, 22.90),   -- WHISKY RED LABEL DOSE                      era    22.90
    ('8e0d44b7-2c02-4970-9df8-c92675de5551'::uuid, 59.90),   -- CAIPIFRUTA VODKA IMPORTADA ABACAXI         era    59.90
    ('f640ebf6-7888-4831-a481-3a08f903b7ae'::uuid, 13.90),   -- FARINHA OVINHA                             era     1.26
    ('56d6d1a9-4219-4d2d-965d-7e7400bd8a1d'::uuid, 76.90),   -- MEDALHAO DE ALCATRA COM FRITAS             era    32.17
    ('8ef53d30-bdb5-42ed-ae41-77b5ccc4cb7a'::uuid, 76.90),   -- MEDALHAO DE ALCATRA COM PURE               era    18.61
    ('065567f0-be08-430e-a829-0cbbcea46a63'::uuid, 14.90),   -- BUDWEISER LN ZERO ALCOOL                   era     0.00
    ('e3931b0f-4852-415b-b0d6-e8a3b6a92c13'::uuid, 94.90),   -- FRANGO 2 BANDAS (SIMPLES)                  era    24.57
    ('c1a4e07b-9f1e-4b3b-90cf-bd2977c34460'::uuid, 10.90),   -- HAPPY HOUR CHOPP SUJO AZULOU 300ML         era     0.28
    ('1dc6a5cc-873d-4cea-922c-1802c72c1e81'::uuid, 1.50),   -- LIMAO PORCAO                               era     0.32
    ('a05ca95b-ce42-4a72-aaa4-cf61392f9758'::uuid, 13.90),   -- HAPPY HOUR CHOPP AZULOU 500ML              era     0.13
    ('da1c0f63-e713-4d1c-a24e-c3957a9eb5bc'::uuid, 59.90),   -- CAIPIFRUTA VODKA IMPORTADA MORANGO         era    59.90
    ('13222127-bd00-4f8d-8bd5-6d0602d7811d'::uuid, 19.90),   -- TORTA DE CUPUACU C/ CHOCOLATE              era     6.50
    ('ac619e29-b412-4fd6-9504-faf106b81c91'::uuid, 45.90),   -- PIRARUCU DESCONFIADO                       era    10.67
    ('60e0a6f7-b306-4733-91f0-901f0c91ca19'::uuid, 21.90),   -- VODKA IMPRT ABSOLUT DOSE                   era     3.92
    ('faf9d7fb-5b3c-42ab-857c-9db603ceb0db'::uuid, 24.90),   -- ADIC CAMARAO FRESCO 5 UN                   era     4.92
    ('5d10bac0-2477-4c13-9293-b2efb0dcabdd'::uuid, 36.90),   -- CAIPILE ABACAXI E ACAI CACHACA ESPECIAL    era    28.90
    ('eb2ba4ac-cf7a-49af-b610-8b89bfe3485b'::uuid, 12.90),   -- FAROFA 500g                                era     1.16
    ('6f977792-d9d2-4eac-a4f0-93f74d52015b'::uuid, 0.01),   -- JARAQUI FRITO CANTOR                       era     7.42
    ('1b6ba8a8-6c95-4e05-a5a1-66b05e6a12ce'::uuid, 53.90)   -- PIRARUCU GRELHADO COM FRITAS               era    28.17
  ) AS v(id, preco)
 WHERE p.id = v.id;
-- Esperado: UPDATE 349


-- --------------------------------------------------------------------------
-- PASSO 3 - ZERA QUEM NAO E PRODUTO DE VENDA
-- --------------------------------------------------------------------------
UPDATE est_produtos
   SET preco_venda = 0
 WHERE tipo <> 'VENDA'
   AND coalesce(preco_venda, 0) <> 0;
-- Esperado: em torno de 759 linhas (o PASSO 1 diz o numero exato do momento).


-- --------------------------------------------------------------------------
-- PASSO 4 - CONFERE
-- --------------------------------------------------------------------------
-- 4a) Nenhum produto fora de VENDA pode ter preco.
SELECT count(*) AS nao_venda_com_preco
  FROM est_produtos
 WHERE tipo <> 'VENDA' AND coalesce(preco_venda,0) <> 0;
-- Esperado: 0

-- 4b) Quantos VENDA ativos ficaram com preco.
SELECT count(*) FILTER (WHERE coalesce(preco_venda,0) > 0) AS com_preco,
       count(*) FILTER (WHERE coalesce(preco_venda,0) = 0) AS sem_preco
  FROM est_produtos
 WHERE ativo = true AND tipo = 'VENDA';
-- Esperado: 349 com preco e 158 sem. Os 158 sao os que nunca venderam no PDV
-- nesses 30 dias (185 sem mapeamento, menos 27 que ja estavam zerados).

-- 4c) Sobrou algum preco de venda ABAIXO do custo? (nao e erro deste SQL,
--     mas agora da para enxergar - antes o preco era lixo e escondia isso.)
SELECT nome, preco_venda, custo_comp
  FROM est_produtos
 WHERE ativo = true AND tipo = 'VENDA'
   AND coalesce(preco_venda,0) > 0
   AND coalesce(custo_comp,0)  > coalesce(preco_venda,0)
 ORDER BY custo_comp - preco_venda DESC;
