-- ==========================================================================
-- PRECO DE VENDA - VERSAO CORRIGIDA (substitui o SQL_PRECOS_VENDA_PDV.sql)
-- ==========================================================================
-- O QUE ESTAVA ERRADO NA VERSAO ANTERIOR
--   349 itens do iComanda apontam para apenas 322 produtos nossos: 24 produtos
--   recebem mais de um item do PDV. A lista VALUES repetia o mesmo uuid com
--   precos diferentes e o Postgres escolheu um deles EM SILENCIO, sem erro.
--   Resultado: 20 produtos ficaram com preco de sorteio - entre eles COCA COLA,
--   AGUA COM GAS e 5 sucos, que cairam para R$ 0,01 porque existe um item de
--   cortesia no PDV com esse valor.
--
-- REGRA DE DESEMPATE AGORA
--   1. Descarta os itens de cortesia (preco <= R$ 0,02).
--   2. Entre os que sobram, vence o MAIS VENDIDO nos 30 dias (04/08 a 02/09/2026).
--   Os 24 conflitos estao na aba "Conflitos" de PRECOS_VENDA_PDV.xlsx com todos
--   os candidatos, para conferencia humana.
--
-- ESCOPO
--   PASSO 2: grava o preco em 322 produtos VENDA (um uuid por linha, sem repeticao).
--   PASSO 3: zera preco_venda de tudo que nao e VENDA.
--   PASSO 4: zera os 137 produtos VENDA que nao vendem no PDV - so fica com
--            preco quem tem venda registrada. Sem isso eles ficariam com o valor
--            da importacao antiga, que e lixo.
--
-- Rodar PASSO 1 primeiro. Ele nao altera nada.
-- ==========================================================================


-- --------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA
-- --------------------------------------------------------------------------
SELECT count(*) FILTER (WHERE tipo =  'VENDA' AND coalesce(preco_venda,0) > 0) AS venda_com_preco,
       count(*) FILTER (WHERE tipo =  'VENDA' AND coalesce(preco_venda,0) = 0) AS venda_sem_preco,
       count(*) FILTER (WHERE tipo <> 'VENDA' AND coalesce(preco_venda,0) > 0) AS outros_com_preco
  FROM est_produtos
 WHERE ativo = true;
-- Esperado agora: 459 / 48 / 0   (o estado deixado pelo SQL anterior)


-- --------------------------------------------------------------------------
-- PASSO 2 - GRAVA O PRECO DO PDV (sem uuid repetido)
-- --------------------------------------------------------------------------
UPDATE est_produtos p
   SET preco_venda = v.preco
  FROM (VALUES
    ('58fe9427-a3ce-4d80-bfa6-0ebc0efbbd6d'::uuid, 7.90),   -- AGUA SEM GAS                               1951 un/30d
    ('3364e0f1-6d9f-4310-8620-1733b9337531'::uuid, 7.90),   -- HAPPY HOUR CHOPP BRAHMA 300ML              1636 un/30d
    ('5339c8be-cb08-497c-a8c9-1ed0451169bd'::uuid, 159.90),   -- TAMBAQUI DE BANDA                          1576 un/30d
    ('5f86cc74-5d69-48db-9ce5-2b202be24ed2'::uuid, 15.90),   -- CHOPP BRAHMA 300 ML                        1496 un/30d
    ('b06ff934-25ed-48fe-b302-b4d3bb252b1f'::uuid, 9.90),   -- COCA COLA ZERO 350ML LT                    1211 un/30d
    ('ad3913ed-e4c5-4c2e-9978-0f76c77f172c'::uuid, 21.90),   -- ORIGINAL 600ML                             1181 un/30d
    ('b988be32-2f81-4de5-8a7c-9f347da6ff89'::uuid, 12.90),   -- HAPPY HOUR CHOPP BRAHMA 500ML              1079 un/30d
    ('cbec1c35-5d9b-415f-ac21-2fe64d4dd582'::uuid, 7.90),   -- AGUA COM GAS                               1020 un/30d
    ('14871721-87b6-43d1-987d-cd1ba2fd827f'::uuid, 109.90),   -- TAMBAQUI DE BANDA DL (2 PESSOAS)            941 un/30d
    ('6bb749a3-6e6a-47f2-99fc-479a8c11e05f'::uuid, 25.90),   -- CHOPP BRAHMA 500 ML                         916 un/30d
    ('1f51229e-ab01-42c0-84c8-1eade778f1f7'::uuid, 9.90),   -- COCA COLA 350ML LT                          872 un/30d
    ('1e024f4a-93a7-4e4a-aea4-b3e5fc668545'::uuid, 9.90),   -- HAPPY HOUR CHOPP SUJO BRAHMA 300ML          684 un/30d
    ('ba14ae45-0a2a-44d1-b8a0-4c005d798f11'::uuid, 14.90),   -- HAPPY HOUR CHOPP SUJO BRAHMA 500ML          489 un/30d
    ('bf052219-d62d-4080-ab17-6b068b99c1f5'::uuid, 54.90),   -- ISCA CROCANTE DE PIRARUCU                   478 un/30d
    ('1a1d732d-eded-4350-9b1f-2126c1bfc7a5'::uuid, 72.90),   -- COSTELA DE TAMBAQUI ASSADA - DELIVERY       475 un/30d
    ('d9a9d949-6c84-4647-8fbe-311dcf9724b5'::uuid, 20.90),   -- CAIPIRINHA CACHACA TRADICIONAL              440 un/30d
    ('6a03390c-6cb3-4139-91b5-08604e40028e'::uuid, 17.90),   -- CHOPP SUJO BRAHMA 300ML                     421 un/30d
    ('31cf57be-6c5d-40d9-ab17-dee85f30d219'::uuid, 17.95),   -- BOLINHO DE TAMBAQUI 5 UN                    367 un/30d
    ('f622b82c-7b7f-4451-9a1c-d20bf48f5658'::uuid, 39.90),   -- CABOCO ENROLADO                             362 un/30d
    ('c8b220ed-a151-4a4a-9583-33d5399676a1'::uuid, 39.90),   -- EMPANADO DE PIRARUCU                        356 un/30d
    ('a13761b4-9c9d-4155-a3b5-24fecb0c5ee9'::uuid, 29.90),   -- ESTROGONOFF DE FRANGO - TDB                 351 un/30d
    ('abac30d3-9f7e-4a53-8217-f656a603bdaa'::uuid, 15.90),   -- CAIPIRINHA HAPPY HOUR TRADICIONAL           346 un/30d
    ('e8c76e6a-bf30-44c0-84b9-329a3c818e4a'::uuid, 39.90),   -- TACACA                                      337 un/30d
    ('b2cd6c47-6fba-4720-ae04-92eed5d93875'::uuid, 29.90),   -- MARMITA DE FRANGO ASSADO NA BRASA           310 un/30d
    ('4354ac6c-6668-4bc4-a03a-193fe5014b58'::uuid, 24.90),   -- STELLA ARTOIS 600ML                         300 un/30d
    ('f2d44efd-1bc9-4371-aea6-e25da1a17cbc'::uuid, 22.90),   -- SPATEN 600ml                                292 un/30d
    ('1364487f-9dcc-4886-873d-356c6f1b2f26'::uuid, 20.95),   -- BOLINHO DE PIRARUCU 5 UN                    260 un/30d
    ('0f7a4523-75a5-4a7b-9d9b-0ff06fd2f40b'::uuid, 25.90),   -- HAPPY HOUR BOLINHO DE TAMBAQUI 10 UN        258 un/30d
    ('8452b5e4-2351-4306-9309-251125bfb49d'::uuid, 36.90),   -- ACAI COM TAPIOCA 300ml                      258 un/30d
    ('3efbbb4f-29d9-412e-85aa-cebafb2137dd'::uuid, 34.90),   -- DADINHO DE TAPIOCA                          253 un/30d
    ('d83294a5-f4f4-4c18-b250-d731718f83de'::uuid, 69.90),   -- DELICIA DE PIRARUCU                         248 un/30d
    ('d71d4c58-a322-463b-80ad-fb64080fd6e2'::uuid, 29.90),   -- PIRARUCU DESFIADO                           239 un/30d
    ('51f8056c-7a45-4189-835f-06f4b685870d'::uuid, 18.90),   -- SUCO DE TAPEREBA                            236 un/30d
    ('5917edfc-0e35-4199-87e1-674c4f9a9d5c'::uuid, 29.90),   -- ESTROGONOFF DE FRANGO                       234 un/30d
    ('99794402-2a96-43a2-8d49-bd6424eff9a7'::uuid, 39.90),   -- TAMBAQUI PICADINHO                          228 un/30d
    ('bebfde33-a985-42d9-a0e6-6eab341a3205'::uuid, 18.90),   -- SUCO DE MARACUJA                            222 un/30d
    ('108b8ae6-2426-4bfa-985c-54644952e4a7'::uuid, 14.90),   -- SUCO DE LIMAO                               208 un/30d
    ('88096781-d884-461a-b565-ce2129d63d41'::uuid, 9.90),   -- BARE 350ML LT                               205 un/30d
    ('8f5b3fea-fd9a-41c3-a5ac-a33c6f2e66ea'::uuid, 39.90),   -- FRANGO A PARMEGIANA - TDB                   204 un/30d
    ('97302e99-3e21-4ce6-934c-12e77d439f72'::uuid, 27.90),   -- CHOPP SUJO BRAHMA 500ml                     201 un/30d
    ('6febbbd9-7c1e-4e8f-b44b-be41c89dee08'::uuid, 24.90),   -- BATATA FRITA                                201 un/30d
    ('96a49ee1-284f-4624-8e5e-d82d4f75ee32'::uuid, 14.90),   -- PUDIM DE LEITE                              197 un/30d
    ('84911890-665b-4628-84cc-e7512d4e159c'::uuid, 22.90),   -- FAROFA DE BANANA                            193 un/30d
    ('1447281d-b246-466b-9168-d11bb484ce84'::uuid, 29.90),   -- MARMITA DE FRANGO ASSADO NA BRASA - TD      191 un/30d
    ('ccc6eeb1-a0a8-4150-a201-43acf520f652'::uuid, 24.90),   -- SUCO DE LARANJA                             188 un/30d
    ('ff579e43-f7dc-4f17-9ae9-6df88a45efae'::uuid, 69.90),   -- CAMARAO COM CATUPIRY                        186 un/30d
    ('e5ac85a0-5958-4127-963d-3d80f9f88c4a'::uuid, 49.90),   -- TACAQUI O NHOQUE                            183 un/30d
    ('fa5a5621-6158-4723-909a-a0a68fffaf30'::uuid, 9.90),   -- GUARANA ANTARTICA ZERO 350ML LT             182 un/30d
    ('f55d4fa0-45e3-4176-8318-023bf2527228'::uuid, 74.90),   -- PIRARUCU A PARMEGIANA                       182 un/30d
    ('0a0044a1-3b61-471f-b96c-b493c8c707fb'::uuid, 79.90),   -- CAMARAO ALHO E OLEO                         178 un/30d
    ('56d51b99-3f73-4ae0-9e9e-b4cfbe462e0d'::uuid, 24.90),   -- HAPPY HOUR DADINHO DE TAPIOCA               176 un/30d
    ('875189ed-b32c-4379-ba12-3aae1d62a490'::uuid, 24.90),   -- SUCO DE CUPUACU                             175 un/30d
    ('5ec46a1d-96cb-4c68-8d4b-f483439a70f5'::uuid, 21.90),   -- BATATA FRITA HAPPY HOUR                     169 un/30d
    ('45a6d42f-a29e-476d-a1df-3aa8eeea4070'::uuid, 22.90),   -- HAPPY HOUR PASTEL DE QUEJO COALHO 6 UN      168 un/30d
    ('c5b32690-96b4-47ab-9352-3ee5e5aef46f'::uuid, 12.90),   -- BANANA FRITA DESCONTO                       166 un/30d
    ('c943c681-5c61-417a-a9dd-1a49308350d6'::uuid, 94.90),   -- MOQUECA CABOCA                              165 un/30d
    ('6342893a-c34b-43b2-8421-c0b4050b31c6'::uuid, 52.90),   -- FRANGO ASSADO NA BRASA + 2 ACOMPANHAME      163 un/30d
    ('754f9752-50ff-4956-9b34-c9e3c1ab95b6'::uuid, 239.90),   -- TAMBAQUI DE CASACA 3 PESSOAS                158 un/30d
    ('5a2e7a20-533c-431d-8dc4-3e0e28d5a08b'::uuid, 29.90),   -- CABOCO ENROLADO (HAPPY HOUR)                153 un/30d
    ('13222127-bd00-4f8d-8bd5-6d0602d7811d'::uuid, 15.90),   -- TORTA DE CUPUACU C/ CHOCOLATE               147 un/30d
    ('78b944f4-db57-44ec-ace0-a3d10c7b42a4'::uuid, 23.90),   -- SUCO DE ABACAXI C/ HORTELA                  144 un/30d
    ('e3ff86f4-af1b-4e7c-ba88-206478b99478'::uuid, 19.90),   -- COMPOTE-SE DE CUPUACU                       143 un/30d
    ('39b9301d-2734-426a-9a91-8e936545a647'::uuid, 26.90),   -- LEGUMES SALTEADOS                           139 un/30d
    ('1d08f2ba-41b8-4934-9e56-98ee88153328'::uuid, 31.90),   -- MACAXEIRA FRITA                             132 un/30d
    ('cc7399a7-2279-401f-8512-ebde5128d632'::uuid, 164.80),   -- 2 BANDAS DE TAMBAQUI                        131 un/30d
    ('1295f860-4be8-4004-b621-4694a6a407d5'::uuid, 15.90),   -- STELLA ARTOIS GOLD LN                       128 un/30d
    ('104d552e-7ee9-48ae-9861-5f8c6243611f'::uuid, 0.01),   -- TAMBAQUI PICADINHO CANTOR                   124 un/30d
    ('d82d4a9c-8465-4c55-a9b4-914e85a84fd4'::uuid, 14.90),   -- LIMONADA SUICA                              124 un/30d
    ('96ceafef-e6e7-478f-ab02-5e9c2a4f4acc'::uuid, 86.90),   -- MOQUECA DE PIRARUCU COM CAMARAO             113 un/30d
    ('4a94403b-186f-45f3-ba82-d067b010be86'::uuid, 7.90),   -- EXPRESSO VIBRANTE                           112 un/30d
    ('dba0f0b3-d220-4ca4-be38-fb1846cb9d4c'::uuid, 29.90),   -- CAIPIRU CACHACA DE JAMBU                    112 un/30d
    ('0e2fbbb6-615c-4e90-823f-4a72ba93d6fb'::uuid, 243.90),   -- MATRINXA DE CASACA                          109 un/30d
    ('b9204a46-8cb2-497b-8380-fc1d5b0bfd64'::uuid, 20.90),   -- SODA GUARANA                                109 un/30d
    ('5e4b4494-61f1-48fc-b444-7ecf679d8b66'::uuid, 98.90),   -- MEDALHAO DE FILE COM FRITAS                 109 un/30d
    ('dc14b0ed-5794-4c7d-9dbf-a14db3661d31'::uuid, 9.90),   -- GUARANA ANTARTICA 350 ML LT                 108 un/30d
    ('484fcb03-f42b-432d-8f04-84cc3969975b'::uuid, 89.90),   -- COSTELA DE TAMBAQUI NO TUCUPI COM JAMB      107 un/30d
    ('45fdb64b-b706-4a4e-a45a-6c11551015af'::uuid, 78.90),   -- PIRARUCU DE CASACA COM VATAPA               107 un/30d
    ('f86e6b8c-a7c3-4d54-bc74-705d7b6e7130'::uuid, 1.50),   -- EMBALAGEM GRANDE                            106 un/30d
    ('689beba1-512e-4011-b692-6962a2f7ddfe'::uuid, 15.90),   -- TORTA DE CUPUACU C/ CASTANHA                105 un/30d
    ('7f328871-3011-4eee-ac00-b85c4216b399'::uuid, 15.90),   -- SUCO DE MANGA                               103 un/30d
    ('c081b3a9-6a37-41e0-8667-a39538fa8402'::uuid, 32.90),   -- PASTEL DE QUEIJO COALHO 6 UN                102 un/30d
    ('fbe6f312-a195-4188-814b-5b8940ad0a56'::uuid, 4.90),   -- MAIONESE DE ERVAS                           101 un/30d
    ('5868ddc0-6d43-4ed5-9d37-01d7441428c5'::uuid, 18.90),   -- CORONA ZERO ALCOOL LN                        99 un/30d
    ('97780c8b-e54f-4c89-bf4b-8722e77bf50e'::uuid, 25.90),   -- CAIPIRU HAPPY HOUR                           98 un/30d
    ('874fc185-13ef-4bcb-b82a-4ec5e932d343'::uuid, 25.90),   -- SUCO DE GRAVIOLA                             93 un/30d
    ('0615177f-86b9-412f-b5fa-63bf83b78f01'::uuid, 33.90),   -- PASTEL MISTO 6 UN                            88 un/30d
    ('4b52f3e9-b462-4820-8f42-b1290652d325'::uuid, 0.01),   -- CHOPP BRAHMA 300 ML SUNSET                   88 un/30d
    ('bf17e30b-4d71-4007-8785-7320375451ee'::uuid, 65.90),   -- SARDINHA FRITA 2 UN                          87 un/30d
    ('7bce4722-c329-410b-a334-f1c6400a0109'::uuid, 46.90),   -- AMBUCU DE CANA                               86 un/30d
    ('c6c91984-db6a-424e-abe4-c2ebd9ba7a78'::uuid, 27.90),   -- BOTACOCO                                     86 un/30d
    ('7cbd9777-e75b-43d1-864a-0db92da94578'::uuid, 13.90),   -- BANANA FRITA                                 85 un/30d
    ('056829c8-58b1-4c9f-8fc2-0c6d83646551'::uuid, 22.90),   -- JAMBUCANA DOSE                               84 un/30d
    ('cc4cba88-bffa-445c-bae5-5c913d2be5ba'::uuid, 22.90),   -- HAPPY HOUR PASTEL DE TAMBAQUI 6 UN           83 un/30d
    ('bbc888a3-391b-4ef8-a1b4-1105c4847dc4'::uuid, 40.90),   -- JUMA                                         79 un/30d
    ('8dc2812d-4b46-4682-9803-2475fb967460'::uuid, 39.90),   -- FRANGO A PARMEGIANA                          79 un/30d
    ('3c4c648b-54c0-4a7c-bd6a-901fb864c647'::uuid, 66.90),   -- MOQUECA VEGETARIANA                          78 un/30d
    ('2f15d655-eacf-45b0-bce4-2b4c3f2533f8'::uuid, 21.90),   -- MACAXEIRA FRITA HAPPY HOUR                   77 un/30d
    ('2141471c-f351-4216-a973-47c429dcf6be'::uuid, 26.90),   -- SUCO DE LARANJA C/ ACEROLA                   77 un/30d
    ('e501125d-43e5-4c5f-8cf7-4a28a454b38c'::uuid, 22.90),   -- CAIPIROSKA VODKA NACIONAL                    77 un/30d
    ('959fc4a8-1628-42c3-a41d-3c843e0a62f4'::uuid, 63.90),   -- PIRARUCU EMPANADO COM FRITAS                 77 un/30d
    ('16a05c4c-b043-4b3e-8d0c-fd118c2ecbfd'::uuid, 32.90),   -- CHEESCAKE DE CHOCOLATE COM CUPUACU           74 un/30d
    ('c1bbafdd-0212-4ede-ae96-c49a31e84893'::uuid, 29.90),   -- VATAPA                                       74 un/30d
    ('a6aad8d9-19f5-413b-a4f5-b47be8a4647a'::uuid, 21.90),   -- SUCO DE ABACAXI                              73 un/30d
    ('58f92701-a8e7-4a6d-b2eb-668c809deb58'::uuid, 40.90),   -- PASTEL DE CAMARAO CREMOSO 6 UNID             72 un/30d
    ('7a48ab73-7a63-42d4-829d-471a90480cd0'::uuid, 14.90),   -- ARROZ                                        72 un/30d
    ('3cd5917d-9135-4a5b-ad1d-67986c26c848'::uuid, 1.00),   -- EMBALAGEM PEQUENA                            72 un/30d
    ('70292ede-9f55-4c1c-9878-b0ad0c4a4312'::uuid, 41.90),   -- VITORIA REGIA                                66 un/30d
    ('5810c8f0-02c3-4e7c-9fd6-ead494d989c2'::uuid, 18.90),   -- CORONA LN                                    66 un/30d
    ('31bd6816-303b-4cb7-8cc0-c6c717b5c54c'::uuid, 142.70),   -- TAMBAQUI DE BANDA + COCA ZERO 1,5L + F       65 un/30d
    ('e458e8ab-03fb-4108-b127-82f2badc18b4'::uuid, 16.90),   -- SUCO DE ACEROLA                              64 un/30d
    ('0c5cdfba-481e-4c3e-81f3-b54f074f63bc'::uuid, 15.90),   -- TORTA DE ABACAXI                             61 un/30d
    ('57569af8-9ab2-4513-afbc-87770e0a3594'::uuid, 27.90),   -- PETIT GATEAU                                 61 un/30d
    ('d6c9055b-de67-4b0a-b23c-12a3f585badf'::uuid, 17.90),   -- CAIPIROSKA HAPPY HOUR TRADICIONAL            60 un/30d
    ('b3dbea5a-c489-454f-b2c6-b28c1f28e2c4'::uuid, 20.90),   -- SODA TAPEREBA                                60 un/30d
    ('bfeca2d7-22d3-4f12-af89-1bf92473ae81'::uuid, 16.90),   -- VINAGRETE                                    59 un/30d
    ('e2c2382e-9f4e-435f-98c9-d02644411af4'::uuid, 9.90),   -- SPRITE LT                                    58 un/30d
    ('2ca72521-411c-4f68-8a44-503fe7cae09a'::uuid, 9.90),   -- SCHWEPPES CITRUS LT                          58 un/30d
    ('3e4a141c-14c8-4592-8dcb-90e1857646d2'::uuid, 16.90),   -- BAIAO DE DOIS                                58 un/30d
    ('a30b14fc-5f67-4c9c-a5b9-8e07808b011b'::uuid, 7.90),   -- EXPRESSO PLENO                               57 un/30d
    ('f0c60ae1-77f4-40f7-8fe4-2b954fc3968d'::uuid, 34.90),   -- PASTEL DE PIRARUCU COM BANANA 6 UNID         56 un/30d
    ('d89d3ed5-8ef4-4dd3-8970-51c21029ad06'::uuid, 38.90),   -- CUNHANTA                                     55 un/30d
    ('397124be-ef1f-4526-af70-b52647252fd0'::uuid, 7.90),   -- EXPRESSO ATENTO                              54 un/30d
    ('dc98adea-c64c-4b8c-aa00-9c99d2f7dc40'::uuid, 29.90),   -- CHOCUCA                                      53 un/30d
    ('b497841c-e625-4f01-8913-675ef9c19904'::uuid, 11.90),   -- GUARANA ANTARTICA ZERO 2L DELIVERY           53 un/30d
    ('05857e44-d085-4727-a556-016d13f4ff0e'::uuid, 105.90),   -- MOQUECA DE TAMBAQUI COM CAMARAO              52 un/30d
    ('07320b97-f58c-4c9f-825b-f12aa530a5ed'::uuid, 72.90),   -- COSTELA DE TAMBAQUI FRITA                    51 un/30d
    ('34046a76-c937-4b0f-afab-d36afe7b004a'::uuid, 9.90),   -- FANTA LARANJA 350ML LT                       48 un/30d
    ('20dc13c7-1da5-430c-8d10-f499f311c64d'::uuid, 27.90),   -- FRANGO A PASSARINHO - TDB                    48 un/30d
    ('a3cc7c54-be4a-4b7a-b55d-8047e363c94f'::uuid, 15.90),   -- STELLA ARTOIS LN                             47 un/30d
    ('009fa803-5a50-47e1-ac00-27172c9391f5'::uuid, 20.55),   -- PASTEL DE CAMARAO CREMOSO 3 UNID             47 un/30d
    ('cbb8bde7-88c8-4bae-8286-3a3d691fd6ef'::uuid, 32.90),   -- CEU DE BRIGADEIRO                            46 un/30d
    ('491d7a24-9f81-4523-a490-13e19fcf65e5'::uuid, 15.90),   -- SUCO DE CAJU                                 46 un/30d
    ('502486f2-dd9e-4199-8131-d749efa892bb'::uuid, 42.90),   -- ISCA DE FRANGO KIDS COM FRITAS               46 un/30d
    ('01b306df-aa77-4ef3-9420-ccae7b377fb3'::uuid, 12.90),   -- PURE DE BATATA DELIVERY                      45 un/30d
    ('db091b8f-4a38-4ca6-a2c6-bd95d399437c'::uuid, 11.90),   -- GUARANA BARE 2L DELIVERY                     45 un/30d
    ('8be9c75b-71aa-444e-8250-0b6200675bc7'::uuid, 14.90),   -- MICHELOB                                     45 un/30d
    ('f779c3a6-6467-4648-ac24-d16d37dd40b8'::uuid, 67.90),   -- SALADA CAESAR DE TAMBAQUI                    44 un/30d
    ('a91a983d-e2e4-45ab-834f-f540616ba0b2'::uuid, 46.90),   -- BOTO COR DE ROSA                             44 un/30d
    ('f9fc67d6-54fe-44e9-8caf-79185dafd9fd'::uuid, 28.90),   -- CAIPILE ABACAXI E ACAI CACHACA TRADICI       44 un/30d
    ('d1ab5f65-99cb-4820-8547-6527097a724e'::uuid, 25.90),   -- VATAPA DELIVERY                              43 un/30d
    ('32ec7148-97a1-46a3-9a5c-e68a1f0a50fa'::uuid, 45.90),   -- (DRINK) TOADA AMAZONICA                      43 un/30d
    ('b7f3270e-5bf5-49dd-8fda-fc84a331c777'::uuid, 98.90),   -- MEDALHAO DE FILE COM PURE                    43 un/30d
    ('64b40733-6790-4257-86b3-2617c86fbe93'::uuid, 14.90),   -- COCA COLA ZERO1,5L                           42 un/30d
    ('9ad48383-33b8-4f51-bf8e-9c5a3dc7d606'::uuid, 3.00),   -- COPO SUJO                                    42 un/30d
    ('2a03ce8e-2689-4a90-b834-e564a3ce27d8'::uuid, 16.90),   -- SUCO DE GOIABA                               41 un/30d
    ('d3b03199-2252-4514-8ef3-20b26cab69b0'::uuid, 57.90),   -- CANELA DE INDIA                              41 un/30d
    ('64824aa6-4c90-419f-9f7b-f17dd333de75'::uuid, 0.01),   -- CAIPIRINHA CACHACA TRADICIONAL SUNSET        41 un/30d
    ('015a47a8-7d66-4a55-9fcd-b2794e4c0e2a'::uuid, 23.90),   -- CAIPIRINHA CACHACA ESPECIAL                  41 un/30d
    ('234ad8d0-f327-4858-9b01-7004a935ba4e'::uuid, 9.90),   -- TUCHAUA LT                                   40 un/30d
    ('59bc94e7-e387-4ddc-8fed-2e7791c5b138'::uuid, 20.90),   -- SODA MARACUJA                                40 un/30d
    ('9aada3c6-0289-4eb9-bfed-aaf046cccccd'::uuid, 86.90),   -- CALDEIRADA DE TAMBAQUI 1 COSTELA COZID       40 un/30d
    ('74ac61e8-4a4b-4230-bb47-bc21252405d1'::uuid, 109.90),   -- TAMBAQUI DE BANDA + 2 REFRI LATA             40 un/30d
    ('6e51dbf3-5e7d-4589-861d-33eba868470d'::uuid, 17.45),   -- PASTEL DE PIRARUCU COM BANANA 3 UNID         39 un/30d
    ('c0b2f21c-afb1-42a5-a8bc-ca9cac9a4181'::uuid, 51.90),   -- IARA                                         39 un/30d
    ('68f6d41e-c0c2-4edd-9941-7b4a3bf9a06a'::uuid, 16.45),   -- PASTEL DE QUEIJO COALHO 3UN                  39 un/30d
    ('df17874a-6093-457c-9962-acc2a8642a1e'::uuid, 22.90),   -- HAPPY HOUR CAIPILE LIMAO E GRAVIOLA TR       38 un/30d
    ('49379e9c-52d5-45f4-a7d2-b425214b6645'::uuid, 28.90),   -- PETIT GANEAU                                 38 un/30d
    ('ac619e29-b412-4fd6-9504-faf106b81c91'::uuid, 61.90),   -- PIRARUCU DESCONFIADO                         38 un/30d
    ('82c00db3-27f0-4aa0-a69f-3bd37bb88d48'::uuid, 9.90),   -- FANTA UVA LT                                 37 un/30d
    ('f69aa371-5635-4447-854d-61c4f84a63ca'::uuid, 48.90),   -- APEROL SPRITZ                                36 un/30d
    ('37ad444b-d6ff-4d18-b9ce-eac00c3ab186'::uuid, 9.90),   -- MAIONESE DE BATATA 250g                      36 un/30d
    ('69f197cd-8af0-4297-a19f-d5f63cf1496a'::uuid, 14.90),   -- SPATEN LN                                    35 un/30d
    ('fdc1a5d3-bb35-43fa-baa5-3e10453a01b0'::uuid, 16.90),   -- CHOPP VERMELHOU 300ML                        35 un/30d
    ('a476d2a4-e759-4a6a-aae7-8d7361179e4c'::uuid, 49.90),   -- PAJE TANQUERAY                               34 un/30d
    ('17052414-e77c-48c2-9ae0-9291e2eb8b8b'::uuid, 50.90),   -- ISCA DE CARNE KIDS COM FRITAS                34 un/30d
    ('12a5892c-1cf7-4727-adcc-3ceea5b9221c'::uuid, 58.90),   -- SALADA CAESAR DE PIRARUCU                    34 un/30d
    ('e64a5fcb-4d17-4c78-a1e6-3e09df71081d'::uuid, 16.90),   -- CHOPP AZULOU 300ML                           34 un/30d
    ('9cc24342-cb9d-48fd-8a29-0bddab940b78'::uuid, 99.90),   -- FRANGO 2 BANDAS (COMPLETO)                   34 un/30d
    ('b9607aa5-95b1-48d5-a74c-2663eb31e58b'::uuid, 9.90),   -- ANTARTICA TONICA LT                          32 un/30d
    ('11ed0a3d-5872-4942-99ec-f69c53e48d99'::uuid, 9.90),   -- SCHWEPPES TONICA LT                          31 un/30d
    ('dc414eb6-a200-486f-9aff-c7020cff5c06'::uuid, 20.90),   -- SODA CUPUACU                                 30 un/30d
    ('a933a48b-3136-4414-bbbf-5d8364aedfd7'::uuid, 79.90),   -- GALINHA CAIPIRA COM ARROZ                    30 un/30d
    ('62a3f2f8-31a0-4b40-aebb-852010d39652'::uuid, 9.90),   -- PEPSI LATA                                   30 un/30d
    ('df22542e-ec4e-470d-9ec2-1b59b1d310ed'::uuid, 85.90),   -- ESCABECHE DE TAMBAQUI                        29 un/30d
    ('bf9b3b0e-7d11-4a2a-b92c-ff6b5b15d8ab'::uuid, 33.90),   -- PASTEL DE TAMBAQUI 6 UN                      29 un/30d
    ('dff91b00-7593-49ed-aa07-bbcf20eebb15'::uuid, 51.90),   -- ENCONTRO DAS AGUAS TANQUERAY                 29 un/30d
    ('f10452cc-977b-4ac1-974a-cdcb94934d57'::uuid, 42.90),   -- ISCA DE PIRARUCU KIDS COM FRITAS             29 un/30d
    ('d41ae095-f3bb-4e04-9f51-87969cfe39ca'::uuid, 46.90),   -- UIRAPURU                                     28 un/30d
    ('ad5910ff-1326-43e4-bf30-6138881b5853'::uuid, 56.90),   -- LA PASSION                                   28 un/30d
    ('118aae56-666a-45c8-b049-31a41e4f2bf1'::uuid, 29.90),   -- PIRARUCU DESFIADO PROMOCAO                   28 un/30d
    ('bc2dca2a-db49-48b7-a13e-c3b5fb3f0179'::uuid, 13.90),   -- ORIGINAL LN                                  28 un/30d
    ('567c6b09-8ab5-4d60-a018-6b3fc9e230b0'::uuid, 14.95),   -- PIRARUCU DESFIADO 50% DESCONTO               27 un/30d
    ('fa44f094-1277-4f4c-88f2-9e872ee15b54'::uuid, 39.90),   -- CAIPIFRUTA VODKA NACIONAL MORANGO            27 un/30d
    ('f5805d5e-7810-4400-9987-36765032cc26'::uuid, 99.90),   -- TAMBAQUI DE BANDA DL SIMPLES S/ GUARNI       26 un/30d
    ('1a28981d-1428-42c7-bd09-02e5d5ae93ee'::uuid, 0.01),   -- Suco de Manga Copo                           25 un/30d
    ('41739d01-4e90-44c5-a85e-e7a55b03c8f9'::uuid, 14.90),   -- COCA COLA 1,5L DELIVERY                      25 un/30d
    ('4255cf8a-a334-4d04-9d96-20f5708d40f4'::uuid, 14.90),   -- FAROFA                                       25 un/30d
    ('927ca850-4bb8-4159-9ad3-5d73696e8c41'::uuid, 35.90),   -- (DRINK) TOADA AMAZONICA NAO ALCOOLICO        25 un/30d
    ('9a8e73d8-60df-4bcc-a16f-86d8efa4ba75'::uuid, 48.90),   -- SANGRIA                                      25 un/30d
    ('e266bca7-7f9c-4902-a718-160ae995eea2'::uuid, 160.90),   -- CALDEIRADA DE TAMBAQUI 2 COSTELA COZID       24 un/30d
    ('8818ba16-428a-490a-9210-ea4d96d2c14e'::uuid, 20.90),   -- SODA LIMAO                                   24 un/30d
    ('63833929-9383-46ad-b2a2-fca6a91c35de'::uuid, 63.90),   -- PIRARUCU EMPANADO COM PURE                   24 un/30d
    ('74f0fcea-cede-45db-bef4-da69c145d952'::uuid, 12.90),   -- FEIJAO 250g                                  23 un/30d
    ('767fbd17-2cd9-49b0-8b6a-c16039502c05'::uuid, 66.90),   -- SARDINHA ASSADA 2 UN                         23 un/30d
    ('95835abd-bef2-4326-9ef6-25ed8d064ce1'::uuid, 32.90),   -- SALADA CAESAR REGIONAL                       22 un/30d
    ('f82c1e42-5b1d-487c-9c8c-70e6a2552242'::uuid, 20.90),   -- SODA MANGA                                   22 un/30d
    ('49bfd5ab-6440-4bc4-af22-eb22a26e2de5'::uuid, 99.90),   -- TAMBAQUI DE BANDA CLIENTE FIEL               22 un/30d
    ('54aa8a9d-03ea-46f4-b7f3-7465682d118d'::uuid, 2.00),   -- LIMAO E SAL                                  21 un/30d
    ('0a575d7e-e82c-4dcd-a0fc-6e960aaa2c0e'::uuid, 22.90),   -- SODA GARANTIDO                               20 un/30d
    ('2556c302-5812-4c9c-b344-8f12c924d572'::uuid, 39.90),   -- CAIPIFRUTA VODKA NACIONAL MARACUJA           20 un/30d
    ('03440849-3833-4017-ab7b-1d8fdfb1520d'::uuid, 9.90),   -- PEPSI BLACK LATA                             19 un/30d
    ('8594afca-13e8-4f57-ab52-06f03baff539'::uuid, 22.90),   -- SODA CAPRICHOSO                              18 un/30d
    ('5f855f6d-273d-4dc2-96aa-2ab9bad874d6'::uuid, 17.90),   -- BANANA FRITA COM ACUCAR HAPPY HOUR           18 un/30d
    ('f6fc3934-e30f-43f2-a3ad-8dd75ea4ffd3'::uuid, 27.90),   -- FRANGO A PASSARINHO                          18 un/30d
    ('c16677ca-9fb2-47dd-ae83-6fedbf50a834'::uuid, 6.90),   -- MOLHO TARTARO                                17 un/30d
    ('d7701761-c9b7-4f7e-9c07-2ad07dbabf66'::uuid, 61.90),   -- AMAZONIA EXOTICA                             17 un/30d
    ('2b062a76-4d8b-4699-81f4-c1bbd24b7701'::uuid, 5.90),   -- CALDINHO DE TAMBAQUI                         17 un/30d
    ('0028f78c-2c9b-44bc-8b20-8a2cdb28fa7c'::uuid, 16.95),   -- PASTEL DE TAMBAQUI 3UN                       16 un/30d
    ('de80115f-4eea-46be-a4d3-202765e67dcd'::uuid, 14.90),   -- COCA COLA ZERO 1,5L DELIVERY                 16 un/30d
    ('d8d595f0-0cba-4e16-950f-1676bc768f9d'::uuid, 16.90),   -- PIRAO DE TAMBAQUI                            16 un/30d
    ('d1ca345b-e23f-41b2-8fbf-8a9896becb20'::uuid, 78.90),   -- SALADA CAESAR DE CAMARAO                     16 un/30d
    ('569fb75f-fe51-4c5e-ae1a-16a9c0f6a907'::uuid, 21.90),   -- (DRINK) CAIPIRINHA CAPRICHOSA - TRADIC       16 un/30d
    ('6606ec72-8352-4e30-b16a-622522005ce7'::uuid, 14.90),   -- BUDWEISER LN                                 15 un/30d
    ('05d30c04-06b5-4748-8743-ad952ab5783c'::uuid, 21.90),   -- (DRINK) CAIPIRINHA GARANTIDA - TRADICI       15 un/30d
    ('e60252ab-cbdf-4b7c-8e14-77e8cec4505b'::uuid, 56.90),   -- LE MAGNIFIQUE                                14 un/30d
    ('0d7c8d6f-21a7-4719-9ebb-6d20b0e5c2cf'::uuid, 8.00),   -- BARE 1 LITRO                                 14 un/30d
    ('77ea4054-6ac7-48e6-95ee-98bb2ad1a167'::uuid, 0.01),   -- TAMBAQUI DE BANDA - GUIA                     14 un/30d
    ('2916b2ec-8217-4b0a-8d54-675cc0d76ad9'::uuid, 20.90),   -- SODA GRAVIOLA                                14 un/30d
    ('4747af85-a151-45f2-955a-e8f7b4985537'::uuid, 13.95),   -- PASTEL DE MISTO 3UN                          14 un/30d
    ('58e52983-77e3-4674-b493-46fc8b6da9ea'::uuid, 8.90),   -- CAFE COM LEITE                               14 un/30d
    ('366d6cf7-b21c-4f0d-badb-57a66f4f702f'::uuid, 20.90),   -- SODA ABACAXI                                 13 un/30d
    ('72b8a8b4-20ce-47e6-872c-4b2430038eb2'::uuid, 26.90),   -- PETIT GATEAU HAPPY HOUR                      13 un/30d
    ('4a6cce29-10c2-4ae7-a793-f821faf4849f'::uuid, 6.90),   -- MAIONESE DE TUCUPI                           13 un/30d
    ('57c4782e-1187-4b5a-87c0-15a1227e2791'::uuid, 42.90),   -- ISCA DE PIRARUCU KIDS COM PURE               13 un/30d
    ('5c966278-68c8-4159-b77d-0ca09a0e27d2'::uuid, 38.90),   -- ARROZ DE TACACA                              13 un/30d
    ('8b4c2dc3-e1a4-4733-bd18-08d36118aa10'::uuid, 0.01),   -- SUCO DE CAJU SUNSET                          12 un/30d
    ('e434aeb8-b667-4864-af2f-f824058b87bf'::uuid, 0.01),   -- SUCO DE MANGA SUNSET                         12 un/30d
    ('9ffa9fca-673e-467c-983c-54f8045df01f'::uuid, 12.90),   -- BAIAO DE DOIS 500g                           12 un/30d
    ('57968009-df85-417d-a790-0326de6b5057'::uuid, 9.90),   -- ARROZ BRANCO DELIVERY                        12 un/30d
    ('6e13264e-1ce1-4ec5-a444-e0c0afedbccf'::uuid, 47.90),   -- FRANGO DE BANDA (COMPLETO)                   12 un/30d
    ('29b7644f-9e23-43ce-9330-a914b2273b7d'::uuid, 39.90),   -- CAIPIFRUTA VODKA NACIONAL DE ABACAXI         12 un/30d
    ('85e304e1-f793-4abc-ba2a-3173f8a47406'::uuid, 8.00),   -- ADIC DE SORVETE                              11 un/30d
    ('41e952a0-5b24-412b-b2af-3e2b35329700'::uuid, 0.01),   -- SUCO DE GOIABA SUNSET                        11 un/30d
    ('5cb50514-b325-4174-8b1f-3c279dabdf97'::uuid, 48.90),   -- (DRINK) FESTEJO VERMELHO                     11 un/30d
    ('31374cfc-c38c-4981-ada0-8613dd958f6f'::uuid, 42.90),   -- ISCA DE FRANGO KIDS COM PURE                 11 un/30d
    ('8c58ba73-fee8-4b05-b29e-50a2607526fd'::uuid, 9.90),   -- SODA LIMONADA LATA                           11 un/30d
    ('8d03e3bd-69cb-4e25-b93a-e931caf890b6'::uuid, 50.90),   -- ISCA DE CARNE KIDS COM PURE                  11 un/30d
    ('41338c00-4201-4456-9acf-455f6b0c97e5'::uuid, 18.90),   -- CHOPP VERMELHOU SUJO 300ML                   11 un/30d
    ('6f9e88ab-9745-461b-a7e1-a333b3140195'::uuid, 0.01),   -- COSTELA DE TAMBAQUI CANTOR Assado-cant       10 un/30d
    ('002efcd4-9a65-4ac5-b038-cee0ae5f6077'::uuid, 7.90),   -- MOLHO DE CUPUACU COM PIMENTA                 10 un/30d
    ('288c73d4-32e6-4f33-92f2-67fb3a14c6e8'::uuid, 229.90),   -- MATRINXA COM VINAGRETE                       10 un/30d
    ('e69da76a-e1ab-4e31-904d-4f2e2308d5b8'::uuid, 28.90),   -- CAIPILE LIMAO E GRAVIOLA CACHACA TRADI       10 un/30d
    ('3f3eb352-d1b5-42f7-b9cb-4cd1bb0c9b53'::uuid, 8.90),   -- CAPUCCINO                                    10 un/30d
    ('fdaafd1d-fb8f-4824-9625-1db1b1f3df1c'::uuid, 15.90),   -- PORC LEGUMES SALTEADOS 250g                  10 un/30d
    ('e093b97e-d614-4e62-8bfe-e148277d9a6b'::uuid, 46.90),   -- (DRINK) EVOLUCAO ESTRELADA                   10 un/30d
    ('38cac168-cce6-472c-b36b-fc9fbeca004e'::uuid, 24.90),   -- (DRINK) CAIPIRINHA CAPRICHOSA - ESPECI       10 un/30d
    ('ef1718da-803c-43a7-8552-39c0cc69c618'::uuid, 29.90),   -- COLORADO RIBEIRAO 600ml                      10 un/30d
    ('ecfbf591-aa3c-409d-8d1e-d4445552fbfe'::uuid, 76.90),   -- SARDINHA ASSADA NA FOLHA DA BANANEIRA         9 un/30d
    ('865304f9-9225-4c26-8c6b-b680b5470879'::uuid, 0.01),   -- CHOPP AZULOU 300 ML SUNSET                    9 un/30d
    ('26cbf768-1a96-44d0-b721-a9cb10af1a94'::uuid, 3.90),   -- ADC. LEITE COPO                               9 un/30d
    ('c200198a-f403-48e5-a55b-c498c32b3364'::uuid, 38.90),   -- (DRINK) EVOLUCAO ESTRELADA NAO ALCOOLI        9 un/30d
    ('0531bac1-d393-410b-854d-bf96f7c03eff'::uuid, 20.90),   -- SODA GOIABA                                   9 un/30d
    ('76bad75f-13a0-4599-bd4e-2524605070cb'::uuid, 22.90),   -- ARROZ COM TUCUPI E JAMBU                      9 un/30d
    ('f4d5a79b-a0c1-4949-89fa-500873dc94a7'::uuid, 8.90),   -- HAPPY HOUR CHOPP AZULOU 300ML                 8 un/30d
    ('9ff7e9c5-f5d6-4ccf-90d4-ef9437fd4aac'::uuid, 38.90),   -- (DRINK) FESTEJO VERMELHO NAO ALCOOLICO        8 un/30d
    ('1f335a5f-28f8-4525-bdae-5ce8329f9081'::uuid, 16.90),   -- BANANA ASSADA                                 8 un/30d
    ('0a999981-0803-4dbf-8fea-6bfff0b6eb8e'::uuid, 20.90),   -- SODA ACEROLA                                  8 un/30d
    ('257842ba-6a35-403c-a848-2a61b7f1df90'::uuid, 38.90),   -- FAROFA DE CAMARAO                             7 un/30d
    ('3b286354-3f13-43b6-b597-cb462fca2b8c'::uuid, 79.90),   -- GALINHA CAIPIRA COM MACARRAO                  7 un/30d
    ('ef649810-872c-4635-8329-3ba6344bc0aa'::uuid, 30.00),   -- MOLHO DE PIMENTA                              7 un/30d
    ('338eee53-a9ac-4333-858a-f24f0b80853c'::uuid, 4.90),   -- OVO FRITO                                     7 un/30d
    ('bacfdef1-f2a2-4f09-8fe0-2f2ea2d5dfb6'::uuid, 38.90),   -- (DRINK) TRIUNFO DO POVO - NAO ALCOOLIC        7 un/30d
    ('8fe12461-e934-4140-807e-91e36a60c911'::uuid, 26.90),   -- CHOPP AZULOU 500ML                            7 un/30d
    ('10b0e3ef-3e4c-4a8d-bf36-bfdf533cd5f3'::uuid, 0.01),   -- (DRINK) CAIPIRINHA CAPRICHOSA - SUNSET        7 un/30d
    ('f1f58092-89a8-4221-8ef3-6e1134d14cf0'::uuid, 0.01),   -- (DRINK) CAIPIRINHA GARANTIDA - SUNSET         7 un/30d
    ('acfcbbbf-3b50-409a-96a6-4e82cd0cb41a'::uuid, 27.90),   -- WHISKY BLACK LABEL DOSE                       7 un/30d
    ('36193466-76c8-460f-832f-74ce7c5b4853'::uuid, 10.90),   -- CACHACA TRADICIONAL OURO DOSE                 7 un/30d
    ('f804539a-c312-4788-95ae-6e1182c9476f'::uuid, 8.90),   -- HAPPY HOUR CHOPP VERMELHOU 300ML              6 un/30d
    ('6ea3c6e9-a905-4948-9b86-c8899ec3ff31'::uuid, 35.90),   -- CAIPIROSKA VODKA IMPORTADA                    6 un/30d
    ('650477f5-671b-4c89-8e15-79f995bad490'::uuid, 28.90),   -- CHOPP AZULOU SUJO 500ML                       6 un/30d
    ('9f230979-36a9-4885-9476-1ef49a61babe'::uuid, 0.01),   -- MOQUECA VEGETARIANA CANTOR                    6 un/30d
    ('dfe061d2-e7cc-4a12-8b39-7d68ed6cfcdb'::uuid, 18.90),   -- PURE DE MACAXEIRA                             6 un/30d
    ('3d9e3506-306a-4111-be4b-8abbe87e9fc6'::uuid, 35.90),   -- LICOR 43 DOSE                                 6 un/30d
    ('72d6cca6-2549-47fe-a2cd-8c52eca5502b'::uuid, 18.90),   -- SALADA DE FEIJAO DE PRAIA                     5 un/30d
    ('c188aa47-59bc-40f3-8899-df14e47cf293'::uuid, 65.90),   -- L AMOUR ROSE                                  5 un/30d
    ('8c88efa8-08c6-41b4-a204-341bfa7c7eba'::uuid, 160.90),   -- CALDEIRADA DE TAMBAQUI 2 COSTELA ASSAD        5 un/30d
    ('89d08432-a0d4-4fb0-b4e4-c81f356ab49f'::uuid, 64.90),   -- (DRINK) ISA A BELA GUERREIRA - TANQUER        5 un/30d
    ('bce16254-ab4a-4179-9551-46c2ae6298a1'::uuid, 11.90),   -- VODKA NAC SMIRNOFF DOSE                       5 un/30d
    ('bc0b5b98-7395-458b-96bc-c86c95581329'::uuid, 13.90),   -- HAPPY HOUR CHOPP VERMELHOU 500ML              5 un/30d
    ('6d6cc63c-59da-45b5-ab5a-d627a7a0d48b'::uuid, 26.90),   -- CHOPP VERMELHOU 500ML                         5 un/30d
    ('f6c21320-b579-4baa-813a-6d0c0373108f'::uuid, 40.90),   -- (DRINK) ISA A BELA GUERREIRA N ALCOOLI        5 un/30d
    ('ffe6e365-bdc9-458d-b560-954e0b1387fd'::uuid, 18.90),   -- CHOPP AZULOU SUJO 300ML                       5 un/30d
    ('8552bf62-4eca-4830-8d6c-78918199accd'::uuid, 0.01),   -- CHOPP VERMELHOU 300 ML SUNSET                 4 un/30d
    ('56a24712-850b-4854-99a4-2d9d8e291299'::uuid, 9.90),   -- SUKITA LATA                                   4 un/30d
    ('b5aab639-31d3-4059-984b-8a6a78af9782'::uuid, 3.90),   -- OVO COZIDO                                    4 un/30d
    ('b164134a-04c0-4f9d-b8c0-586ef916062b'::uuid, 12.90),   -- ARROZ 500g                                    4 un/30d
    ('c615c471-0e1c-4b34-a1b4-93ced1803ffd'::uuid, 10.00),   -- CACHACA SAGATIBA DOSE                         4 un/30d
    ('464a7a43-084c-4ce9-8e02-d56b6fc8cae2'::uuid, 8.90),   -- FAROFA 250g                                   4 un/30d
    ('a819b9d5-465e-451b-98f2-2431831c9ba7'::uuid, 86.90),   -- CALDEIRADA DE TAMBAQUI 1 COSTELA ASSAD        3 un/30d
    ('e8a249a8-5af3-472f-9ca4-11d394648aca'::uuid, 17.90),   -- BATATA FRITA ACAO                             3 un/30d
    ('752bcf26-55cf-4f4f-8ee0-6d46692d6371'::uuid, 9.90),   -- CACHACA TRADICIONAL PRATA DOSE                3 un/30d
    ('d7d7fc43-a15a-419e-91ec-88b50737a1aa'::uuid, 54.90),   -- BOTO COR DE ROSA ESPECIAL                     3 un/30d
    ('61d88830-911e-452b-b70d-f4f26e1653e5'::uuid, 12.90),   -- PURE 250g                                     3 un/30d
    ('8194af17-9ecf-48d1-bbf9-cd235a5efafe'::uuid, 12.00),   -- AMBURANA DOSE                                 3 un/30d
    ('bdab70dd-4560-4159-aea1-61ace9d676f3'::uuid, 15.90),   -- HAPPY HOUR CHOPP SUJO AZULOU 500ML            3 un/30d
    ('9e98af27-70fc-441e-8438-9c932ceead77'::uuid, 6.00),   -- CACHACA BRAZUKA DOSE                          3 un/30d
    ('d64e5c2c-b0d1-4a76-a647-3c635f8b68fa'::uuid, 24.90),   -- (DRINK) CAIPIRINHA GARANTIDA - ESPECIA        3 un/30d
    ('daf49049-e71e-47b6-a22b-b9eb5204c879'::uuid, 36.90),   -- CAIPILE LIMAO E GRAVIOLA CACHACA ESPEC        3 un/30d
    ('43cfc6e3-5bb3-4767-a2fa-d5604ad594d9'::uuid, 8.90),   -- PORC SALADA CRUA 250g                         2 un/30d
    ('c0cc63e9-3bfa-450e-b493-e6630b22da88'::uuid, 15.90),   -- MACARRAO                                      2 un/30d
    ('16fb8eed-5474-4027-be10-c527019f5673'::uuid, 15.90),   -- HAPPY HOUR CHOPP SUJO VERMELHOU 500ML         2 un/30d
    ('2bd7358b-fbeb-4eee-86c3-9d8eda6a4226'::uuid, 64.90),   -- (DRINK) TRIUNFO DO POVO - TANQUERAY           2 un/30d
    ('ba90f709-8953-4115-887d-0b61306b7f83'::uuid, 4.00),   -- CAIXA TAMBAQUI VIAGEM                         2 un/30d
    ('eb7b4615-d86e-4929-8465-1bb3ca2d25af'::uuid, 6.90),   -- TUCUPI                                        2 un/30d
    ('20c5f5dd-1a7d-4f4a-a850-e10af8ffc1e2'::uuid, 10.90),   -- JAMBU                                         2 un/30d
    ('612e0cfe-17fd-4b27-8150-df18e67b340c'::uuid, 22.90),   -- WHISKY RED LABEL DOSE                         2 un/30d
    ('8e0d44b7-2c02-4970-9df8-c92675de5551'::uuid, 59.90),   -- CAIPIFRUTA VODKA IMPORTADA ABACAXI            2 un/30d
    ('f640ebf6-7888-4831-a481-3a08f903b7ae'::uuid, 13.90),   -- FARINHA OVINHA                                2 un/30d
    ('56d6d1a9-4219-4d2d-965d-7e7400bd8a1d'::uuid, 76.90),   -- MEDALHAO DE ALCATRA COM FRITAS                1 un/30d
    ('8ef53d30-bdb5-42ed-ae41-77b5ccc4cb7a'::uuid, 76.90),   -- MEDALHAO DE ALCATRA COM PURE                  1 un/30d
    ('065567f0-be08-430e-a829-0cbbcea46a63'::uuid, 14.90),   -- BUDWEISER LN ZERO ALCOOL                      1 un/30d
    ('e3931b0f-4852-415b-b0d6-e8a3b6a92c13'::uuid, 94.90),   -- FRANGO 2 BANDAS (SIMPLES)                     1 un/30d
    ('c1a4e07b-9f1e-4b3b-90cf-bd2977c34460'::uuid, 10.90),   -- HAPPY HOUR CHOPP SUJO AZULOU 300ML            1 un/30d
    ('1dc6a5cc-873d-4cea-922c-1802c72c1e81'::uuid, 1.50),   -- LIMAO PORCAO                                  1 un/30d
    ('a05ca95b-ce42-4a72-aaa4-cf61392f9758'::uuid, 13.90),   -- HAPPY HOUR CHOPP AZULOU 500ML                 1 un/30d
    ('da1c0f63-e713-4d1c-a24e-c3957a9eb5bc'::uuid, 59.90),   -- CAIPIFRUTA VODKA IMPORTADA MORANGO            1 un/30d
    ('60e0a6f7-b306-4733-91f0-901f0c91ca19'::uuid, 21.90),   -- VODKA IMPRT ABSOLUT DOSE                      1 un/30d
    ('faf9d7fb-5b3c-42ab-857c-9db603ceb0db'::uuid, 24.90),   -- ADIC CAMARAO FRESCO 5 UN                      1 un/30d
    ('5d10bac0-2477-4c13-9293-b2efb0dcabdd'::uuid, 36.90),   -- CAIPILE ABACAXI E ACAI CACHACA ESPECIA        1 un/30d
    ('eb2ba4ac-cf7a-49af-b610-8b89bfe3485b'::uuid, 12.90),   -- FAROFA 500g                                   1 un/30d
    ('6f977792-d9d2-4eac-a4f0-93f74d52015b'::uuid, 0.01),   -- JARAQUI FRITO CANTOR                          0 un/30d
    ('1b6ba8a8-6c95-4e05-a5a1-66b05e6a12ce'::uuid, 53.90)   -- PIRARUCU GRELHADO COM FRITAS                  0 un/30d
  ) AS v(id, preco)
 WHERE p.id = v.id;
-- Esperado: UPDATE 322


-- --------------------------------------------------------------------------
-- PASSO 3 - ZERA QUEM NAO E PRODUTO DE VENDA
-- --------------------------------------------------------------------------
UPDATE est_produtos SET preco_venda = 0
 WHERE tipo <> 'VENDA' AND coalesce(preco_venda,0) <> 0;
-- Esperado: UPDATE 0 (o SQL anterior ja fez essa parte)


-- --------------------------------------------------------------------------
-- PASSO 4 - ZERA OS PRODUTOS DE VENDA QUE NAO VENDEM NO PDV
-- --------------------------------------------------------------------------
-- Ficam com preco apenas os que tem venda registrada no iComanda. Os demais
-- estavam com o valor da importacao antiga (ex.: GARRAFA DE SMIRNOFF R$ 120,90,
-- MANTEIGA DE CUPUACU R$ 63,76) - numeros sem lastro.
UPDATE est_produtos SET preco_venda = 0
 WHERE ativo = true
   AND tipo  = 'VENDA'
   AND coalesce(preco_venda,0) <> 0
   AND id NOT IN (
     '58fe9427-a3ce-4d80-bfa6-0ebc0efbbd6d'::uuid,
     '3364e0f1-6d9f-4310-8620-1733b9337531'::uuid,
     '5339c8be-cb08-497c-a8c9-1ed0451169bd'::uuid,
     '5f86cc74-5d69-48db-9ce5-2b202be24ed2'::uuid,
     'b06ff934-25ed-48fe-b302-b4d3bb252b1f'::uuid,
     'ad3913ed-e4c5-4c2e-9978-0f76c77f172c'::uuid,
     'b988be32-2f81-4de5-8a7c-9f347da6ff89'::uuid,
     'cbec1c35-5d9b-415f-ac21-2fe64d4dd582'::uuid,
     '14871721-87b6-43d1-987d-cd1ba2fd827f'::uuid,
     '6bb749a3-6e6a-47f2-99fc-479a8c11e05f'::uuid,
     '1f51229e-ab01-42c0-84c8-1eade778f1f7'::uuid,
     '1e024f4a-93a7-4e4a-aea4-b3e5fc668545'::uuid,
     'ba14ae45-0a2a-44d1-b8a0-4c005d798f11'::uuid,
     'bf052219-d62d-4080-ab17-6b068b99c1f5'::uuid,
     '1a1d732d-eded-4350-9b1f-2126c1bfc7a5'::uuid,
     'd9a9d949-6c84-4647-8fbe-311dcf9724b5'::uuid,
     '6a03390c-6cb3-4139-91b5-08604e40028e'::uuid,
     '31cf57be-6c5d-40d9-ab17-dee85f30d219'::uuid,
     'f622b82c-7b7f-4451-9a1c-d20bf48f5658'::uuid,
     'c8b220ed-a151-4a4a-9583-33d5399676a1'::uuid,
     'a13761b4-9c9d-4155-a3b5-24fecb0c5ee9'::uuid,
     'abac30d3-9f7e-4a53-8217-f656a603bdaa'::uuid,
     'e8c76e6a-bf30-44c0-84b9-329a3c818e4a'::uuid,
     'b2cd6c47-6fba-4720-ae04-92eed5d93875'::uuid,
     '4354ac6c-6668-4bc4-a03a-193fe5014b58'::uuid,
     'f2d44efd-1bc9-4371-aea6-e25da1a17cbc'::uuid,
     '1364487f-9dcc-4886-873d-356c6f1b2f26'::uuid,
     '0f7a4523-75a5-4a7b-9d9b-0ff06fd2f40b'::uuid,
     '8452b5e4-2351-4306-9309-251125bfb49d'::uuid,
     '3efbbb4f-29d9-412e-85aa-cebafb2137dd'::uuid,
     'd83294a5-f4f4-4c18-b250-d731718f83de'::uuid,
     'd71d4c58-a322-463b-80ad-fb64080fd6e2'::uuid,
     '51f8056c-7a45-4189-835f-06f4b685870d'::uuid,
     '5917edfc-0e35-4199-87e1-674c4f9a9d5c'::uuid,
     '99794402-2a96-43a2-8d49-bd6424eff9a7'::uuid,
     'bebfde33-a985-42d9-a0e6-6eab341a3205'::uuid,
     '108b8ae6-2426-4bfa-985c-54644952e4a7'::uuid,
     '88096781-d884-461a-b565-ce2129d63d41'::uuid,
     '8f5b3fea-fd9a-41c3-a5ac-a33c6f2e66ea'::uuid,
     '97302e99-3e21-4ce6-934c-12e77d439f72'::uuid,
     '6febbbd9-7c1e-4e8f-b44b-be41c89dee08'::uuid,
     '96a49ee1-284f-4624-8e5e-d82d4f75ee32'::uuid,
     '84911890-665b-4628-84cc-e7512d4e159c'::uuid,
     '1447281d-b246-466b-9168-d11bb484ce84'::uuid,
     'ccc6eeb1-a0a8-4150-a201-43acf520f652'::uuid,
     'ff579e43-f7dc-4f17-9ae9-6df88a45efae'::uuid,
     'e5ac85a0-5958-4127-963d-3d80f9f88c4a'::uuid,
     'fa5a5621-6158-4723-909a-a0a68fffaf30'::uuid,
     'f55d4fa0-45e3-4176-8318-023bf2527228'::uuid,
     '0a0044a1-3b61-471f-b96c-b493c8c707fb'::uuid,
     '56d51b99-3f73-4ae0-9e9e-b4cfbe462e0d'::uuid,
     '875189ed-b32c-4379-ba12-3aae1d62a490'::uuid,
     '5ec46a1d-96cb-4c68-8d4b-f483439a70f5'::uuid,
     '45a6d42f-a29e-476d-a1df-3aa8eeea4070'::uuid,
     'c5b32690-96b4-47ab-9352-3ee5e5aef46f'::uuid,
     'c943c681-5c61-417a-a9dd-1a49308350d6'::uuid,
     '6342893a-c34b-43b2-8421-c0b4050b31c6'::uuid,
     '754f9752-50ff-4956-9b34-c9e3c1ab95b6'::uuid,
     '5a2e7a20-533c-431d-8dc4-3e0e28d5a08b'::uuid,
     '13222127-bd00-4f8d-8bd5-6d0602d7811d'::uuid,
     '78b944f4-db57-44ec-ace0-a3d10c7b42a4'::uuid,
     'e3ff86f4-af1b-4e7c-ba88-206478b99478'::uuid,
     '39b9301d-2734-426a-9a91-8e936545a647'::uuid,
     '1d08f2ba-41b8-4934-9e56-98ee88153328'::uuid,
     'cc7399a7-2279-401f-8512-ebde5128d632'::uuid,
     '1295f860-4be8-4004-b621-4694a6a407d5'::uuid,
     '104d552e-7ee9-48ae-9861-5f8c6243611f'::uuid,
     'd82d4a9c-8465-4c55-a9b4-914e85a84fd4'::uuid,
     '96ceafef-e6e7-478f-ab02-5e9c2a4f4acc'::uuid,
     '4a94403b-186f-45f3-ba82-d067b010be86'::uuid,
     'dba0f0b3-d220-4ca4-be38-fb1846cb9d4c'::uuid,
     '0e2fbbb6-615c-4e90-823f-4a72ba93d6fb'::uuid,
     'b9204a46-8cb2-497b-8380-fc1d5b0bfd64'::uuid,
     '5e4b4494-61f1-48fc-b444-7ecf679d8b66'::uuid,
     'dc14b0ed-5794-4c7d-9dbf-a14db3661d31'::uuid,
     '484fcb03-f42b-432d-8f04-84cc3969975b'::uuid,
     '45fdb64b-b706-4a4e-a45a-6c11551015af'::uuid,
     'f86e6b8c-a7c3-4d54-bc74-705d7b6e7130'::uuid,
     '689beba1-512e-4011-b692-6962a2f7ddfe'::uuid,
     '7f328871-3011-4eee-ac00-b85c4216b399'::uuid,
     'c081b3a9-6a37-41e0-8667-a39538fa8402'::uuid,
     'fbe6f312-a195-4188-814b-5b8940ad0a56'::uuid,
     '5868ddc0-6d43-4ed5-9d37-01d7441428c5'::uuid,
     '97780c8b-e54f-4c89-bf4b-8722e77bf50e'::uuid,
     '874fc185-13ef-4bcb-b82a-4ec5e932d343'::uuid,
     '0615177f-86b9-412f-b5fa-63bf83b78f01'::uuid,
     '4b52f3e9-b462-4820-8f42-b1290652d325'::uuid,
     'bf17e30b-4d71-4007-8785-7320375451ee'::uuid,
     '7bce4722-c329-410b-a334-f1c6400a0109'::uuid,
     'c6c91984-db6a-424e-abe4-c2ebd9ba7a78'::uuid,
     '7cbd9777-e75b-43d1-864a-0db92da94578'::uuid,
     '056829c8-58b1-4c9f-8fc2-0c6d83646551'::uuid,
     'cc4cba88-bffa-445c-bae5-5c913d2be5ba'::uuid,
     'bbc888a3-391b-4ef8-a1b4-1105c4847dc4'::uuid,
     '8dc2812d-4b46-4682-9803-2475fb967460'::uuid,
     '3c4c648b-54c0-4a7c-bd6a-901fb864c647'::uuid,
     '2f15d655-eacf-45b0-bce4-2b4c3f2533f8'::uuid,
     '2141471c-f351-4216-a973-47c429dcf6be'::uuid,
     'e501125d-43e5-4c5f-8cf7-4a28a454b38c'::uuid,
     '959fc4a8-1628-42c3-a41d-3c843e0a62f4'::uuid,
     '16a05c4c-b043-4b3e-8d0c-fd118c2ecbfd'::uuid,
     'c1bbafdd-0212-4ede-ae96-c49a31e84893'::uuid,
     'a6aad8d9-19f5-413b-a4f5-b47be8a4647a'::uuid,
     '58f92701-a8e7-4a6d-b2eb-668c809deb58'::uuid,
     '7a48ab73-7a63-42d4-829d-471a90480cd0'::uuid,
     '3cd5917d-9135-4a5b-ad1d-67986c26c848'::uuid,
     '70292ede-9f55-4c1c-9878-b0ad0c4a4312'::uuid,
     '5810c8f0-02c3-4e7c-9fd6-ead494d989c2'::uuid,
     '31bd6816-303b-4cb7-8cc0-c6c717b5c54c'::uuid,
     'e458e8ab-03fb-4108-b127-82f2badc18b4'::uuid,
     '0c5cdfba-481e-4c3e-81f3-b54f074f63bc'::uuid,
     '57569af8-9ab2-4513-afbc-87770e0a3594'::uuid,
     'd6c9055b-de67-4b0a-b23c-12a3f585badf'::uuid,
     'b3dbea5a-c489-454f-b2c6-b28c1f28e2c4'::uuid,
     'bfeca2d7-22d3-4f12-af89-1bf92473ae81'::uuid,
     'e2c2382e-9f4e-435f-98c9-d02644411af4'::uuid,
     '2ca72521-411c-4f68-8a44-503fe7cae09a'::uuid,
     '3e4a141c-14c8-4592-8dcb-90e1857646d2'::uuid,
     'a30b14fc-5f67-4c9c-a5b9-8e07808b011b'::uuid,
     'f0c60ae1-77f4-40f7-8fe4-2b954fc3968d'::uuid,
     'd89d3ed5-8ef4-4dd3-8970-51c21029ad06'::uuid,
     '397124be-ef1f-4526-af70-b52647252fd0'::uuid,
     'dc98adea-c64c-4b8c-aa00-9c99d2f7dc40'::uuid,
     'b497841c-e625-4f01-8913-675ef9c19904'::uuid,
     '05857e44-d085-4727-a556-016d13f4ff0e'::uuid,
     '07320b97-f58c-4c9f-825b-f12aa530a5ed'::uuid,
     '34046a76-c937-4b0f-afab-d36afe7b004a'::uuid,
     '20dc13c7-1da5-430c-8d10-f499f311c64d'::uuid,
     'a3cc7c54-be4a-4b7a-b55d-8047e363c94f'::uuid,
     '009fa803-5a50-47e1-ac00-27172c9391f5'::uuid,
     'cbb8bde7-88c8-4bae-8286-3a3d691fd6ef'::uuid,
     '491d7a24-9f81-4523-a490-13e19fcf65e5'::uuid,
     '502486f2-dd9e-4199-8131-d749efa892bb'::uuid,
     '01b306df-aa77-4ef3-9420-ccae7b377fb3'::uuid,
     'db091b8f-4a38-4ca6-a2c6-bd95d399437c'::uuid,
     '8be9c75b-71aa-444e-8250-0b6200675bc7'::uuid,
     'f779c3a6-6467-4648-ac24-d16d37dd40b8'::uuid,
     'a91a983d-e2e4-45ab-834f-f540616ba0b2'::uuid,
     'f9fc67d6-54fe-44e9-8caf-79185dafd9fd'::uuid,
     'd1ab5f65-99cb-4820-8547-6527097a724e'::uuid,
     '32ec7148-97a1-46a3-9a5c-e68a1f0a50fa'::uuid,
     'b7f3270e-5bf5-49dd-8fda-fc84a331c777'::uuid,
     '64b40733-6790-4257-86b3-2617c86fbe93'::uuid,
     '9ad48383-33b8-4f51-bf8e-9c5a3dc7d606'::uuid,
     '2a03ce8e-2689-4a90-b834-e564a3ce27d8'::uuid,
     'd3b03199-2252-4514-8ef3-20b26cab69b0'::uuid,
     '64824aa6-4c90-419f-9f7b-f17dd333de75'::uuid,
     '015a47a8-7d66-4a55-9fcd-b2794e4c0e2a'::uuid,
     '234ad8d0-f327-4858-9b01-7004a935ba4e'::uuid,
     '59bc94e7-e387-4ddc-8fed-2e7791c5b138'::uuid,
     '9aada3c6-0289-4eb9-bfed-aaf046cccccd'::uuid,
     '74ac61e8-4a4b-4230-bb47-bc21252405d1'::uuid,
     '6e51dbf3-5e7d-4589-861d-33eba868470d'::uuid,
     'c0b2f21c-afb1-42a5-a8bc-ca9cac9a4181'::uuid,
     '68f6d41e-c0c2-4edd-9941-7b4a3bf9a06a'::uuid,
     'df17874a-6093-457c-9962-acc2a8642a1e'::uuid,
     '49379e9c-52d5-45f4-a7d2-b425214b6645'::uuid,
     'ac619e29-b412-4fd6-9504-faf106b81c91'::uuid,
     '82c00db3-27f0-4aa0-a69f-3bd37bb88d48'::uuid,
     'f69aa371-5635-4447-854d-61c4f84a63ca'::uuid,
     '37ad444b-d6ff-4d18-b9ce-eac00c3ab186'::uuid,
     '69f197cd-8af0-4297-a19f-d5f63cf1496a'::uuid,
     'fdc1a5d3-bb35-43fa-baa5-3e10453a01b0'::uuid,
     'a476d2a4-e759-4a6a-aae7-8d7361179e4c'::uuid,
     '17052414-e77c-48c2-9ae0-9291e2eb8b8b'::uuid,
     '12a5892c-1cf7-4727-adcc-3ceea5b9221c'::uuid,
     'e64a5fcb-4d17-4c78-a1e6-3e09df71081d'::uuid,
     '9cc24342-cb9d-48fd-8a29-0bddab940b78'::uuid,
     'b9607aa5-95b1-48d5-a74c-2663eb31e58b'::uuid,
     '11ed0a3d-5872-4942-99ec-f69c53e48d99'::uuid,
     'dc414eb6-a200-486f-9aff-c7020cff5c06'::uuid,
     'a933a48b-3136-4414-bbbf-5d8364aedfd7'::uuid,
     '62a3f2f8-31a0-4b40-aebb-852010d39652'::uuid,
     'df22542e-ec4e-470d-9ec2-1b59b1d310ed'::uuid,
     'bf9b3b0e-7d11-4a2a-b92c-ff6b5b15d8ab'::uuid,
     'dff91b00-7593-49ed-aa07-bbcf20eebb15'::uuid,
     'f10452cc-977b-4ac1-974a-cdcb94934d57'::uuid,
     'd41ae095-f3bb-4e04-9f51-87969cfe39ca'::uuid,
     'ad5910ff-1326-43e4-bf30-6138881b5853'::uuid,
     '118aae56-666a-45c8-b049-31a41e4f2bf1'::uuid,
     'bc2dca2a-db49-48b7-a13e-c3b5fb3f0179'::uuid,
     '567c6b09-8ab5-4d60-a018-6b3fc9e230b0'::uuid,
     'fa44f094-1277-4f4c-88f2-9e872ee15b54'::uuid,
     'f5805d5e-7810-4400-9987-36765032cc26'::uuid,
     '1a28981d-1428-42c7-bd09-02e5d5ae93ee'::uuid,
     '41739d01-4e90-44c5-a85e-e7a55b03c8f9'::uuid,
     '4255cf8a-a334-4d04-9d96-20f5708d40f4'::uuid,
     '927ca850-4bb8-4159-9ad3-5d73696e8c41'::uuid,
     '9a8e73d8-60df-4bcc-a16f-86d8efa4ba75'::uuid,
     'e266bca7-7f9c-4902-a718-160ae995eea2'::uuid,
     '8818ba16-428a-490a-9210-ea4d96d2c14e'::uuid,
     '63833929-9383-46ad-b2a2-fca6a91c35de'::uuid,
     '74f0fcea-cede-45db-bef4-da69c145d952'::uuid,
     '767fbd17-2cd9-49b0-8b6a-c16039502c05'::uuid,
     '95835abd-bef2-4326-9ef6-25ed8d064ce1'::uuid,
     'f82c1e42-5b1d-487c-9c8c-70e6a2552242'::uuid,
     '49bfd5ab-6440-4bc4-af22-eb22a26e2de5'::uuid,
     '54aa8a9d-03ea-46f4-b7f3-7465682d118d'::uuid,
     '0a575d7e-e82c-4dcd-a0fc-6e960aaa2c0e'::uuid,
     '2556c302-5812-4c9c-b344-8f12c924d572'::uuid,
     '03440849-3833-4017-ab7b-1d8fdfb1520d'::uuid,
     '8594afca-13e8-4f57-ab52-06f03baff539'::uuid,
     '5f855f6d-273d-4dc2-96aa-2ab9bad874d6'::uuid,
     'f6fc3934-e30f-43f2-a3ad-8dd75ea4ffd3'::uuid,
     'c16677ca-9fb2-47dd-ae83-6fedbf50a834'::uuid,
     'd7701761-c9b7-4f7e-9c07-2ad07dbabf66'::uuid,
     '2b062a76-4d8b-4699-81f4-c1bbd24b7701'::uuid,
     '0028f78c-2c9b-44bc-8b20-8a2cdb28fa7c'::uuid,
     'de80115f-4eea-46be-a4d3-202765e67dcd'::uuid,
     'd8d595f0-0cba-4e16-950f-1676bc768f9d'::uuid,
     'd1ca345b-e23f-41b2-8fbf-8a9896becb20'::uuid,
     '569fb75f-fe51-4c5e-ae1a-16a9c0f6a907'::uuid,
     '6606ec72-8352-4e30-b16a-622522005ce7'::uuid,
     '05d30c04-06b5-4748-8743-ad952ab5783c'::uuid,
     'e60252ab-cbdf-4b7c-8e14-77e8cec4505b'::uuid,
     '0d7c8d6f-21a7-4719-9ebb-6d20b0e5c2cf'::uuid,
     '77ea4054-6ac7-48e6-95ee-98bb2ad1a167'::uuid,
     '2916b2ec-8217-4b0a-8d54-675cc0d76ad9'::uuid,
     '4747af85-a151-45f2-955a-e8f7b4985537'::uuid,
     '58e52983-77e3-4674-b493-46fc8b6da9ea'::uuid,
     '366d6cf7-b21c-4f0d-badb-57a66f4f702f'::uuid,
     '72b8a8b4-20ce-47e6-872c-4b2430038eb2'::uuid,
     '4a6cce29-10c2-4ae7-a793-f821faf4849f'::uuid,
     '57c4782e-1187-4b5a-87c0-15a1227e2791'::uuid,
     '5c966278-68c8-4159-b77d-0ca09a0e27d2'::uuid,
     '8b4c2dc3-e1a4-4733-bd18-08d36118aa10'::uuid,
     'e434aeb8-b667-4864-af2f-f824058b87bf'::uuid,
     '9ffa9fca-673e-467c-983c-54f8045df01f'::uuid,
     '57968009-df85-417d-a790-0326de6b5057'::uuid,
     '6e13264e-1ce1-4ec5-a444-e0c0afedbccf'::uuid,
     '29b7644f-9e23-43ce-9330-a914b2273b7d'::uuid,
     '85e304e1-f793-4abc-ba2a-3173f8a47406'::uuid,
     '41e952a0-5b24-412b-b2af-3e2b35329700'::uuid,
     '5cb50514-b325-4174-8b1f-3c279dabdf97'::uuid,
     '31374cfc-c38c-4981-ada0-8613dd958f6f'::uuid,
     '8c58ba73-fee8-4b05-b29e-50a2607526fd'::uuid,
     '8d03e3bd-69cb-4e25-b93a-e931caf890b6'::uuid,
     '41338c00-4201-4456-9acf-455f6b0c97e5'::uuid,
     '6f9e88ab-9745-461b-a7e1-a333b3140195'::uuid,
     '002efcd4-9a65-4ac5-b038-cee0ae5f6077'::uuid,
     '288c73d4-32e6-4f33-92f2-67fb3a14c6e8'::uuid,
     'e69da76a-e1ab-4e31-904d-4f2e2308d5b8'::uuid,
     '3f3eb352-d1b5-42f7-b9cb-4cd1bb0c9b53'::uuid,
     'fdaafd1d-fb8f-4824-9625-1db1b1f3df1c'::uuid,
     'e093b97e-d614-4e62-8bfe-e148277d9a6b'::uuid,
     '38cac168-cce6-472c-b36b-fc9fbeca004e'::uuid,
     'ef1718da-803c-43a7-8552-39c0cc69c618'::uuid,
     'ecfbf591-aa3c-409d-8d1e-d4445552fbfe'::uuid,
     '865304f9-9225-4c26-8c6b-b680b5470879'::uuid,
     '26cbf768-1a96-44d0-b721-a9cb10af1a94'::uuid,
     'c200198a-f403-48e5-a55b-c498c32b3364'::uuid,
     '0531bac1-d393-410b-854d-bf96f7c03eff'::uuid,
     '76bad75f-13a0-4599-bd4e-2524605070cb'::uuid,
     'f4d5a79b-a0c1-4949-89fa-500873dc94a7'::uuid,
     '9ff7e9c5-f5d6-4ccf-90d4-ef9437fd4aac'::uuid,
     '1f335a5f-28f8-4525-bdae-5ce8329f9081'::uuid,
     '0a999981-0803-4dbf-8fea-6bfff0b6eb8e'::uuid,
     '257842ba-6a35-403c-a848-2a61b7f1df90'::uuid,
     '3b286354-3f13-43b6-b597-cb462fca2b8c'::uuid,
     'ef649810-872c-4635-8329-3ba6344bc0aa'::uuid,
     '338eee53-a9ac-4333-858a-f24f0b80853c'::uuid,
     'bacfdef1-f2a2-4f09-8fe0-2f2ea2d5dfb6'::uuid,
     '8fe12461-e934-4140-807e-91e36a60c911'::uuid,
     '10b0e3ef-3e4c-4a8d-bf36-bfdf533cd5f3'::uuid,
     'f1f58092-89a8-4221-8ef3-6e1134d14cf0'::uuid,
     'acfcbbbf-3b50-409a-96a6-4e82cd0cb41a'::uuid,
     '36193466-76c8-460f-832f-74ce7c5b4853'::uuid,
     'f804539a-c312-4788-95ae-6e1182c9476f'::uuid,
     '6ea3c6e9-a905-4948-9b86-c8899ec3ff31'::uuid,
     '650477f5-671b-4c89-8e15-79f995bad490'::uuid,
     '9f230979-36a9-4885-9476-1ef49a61babe'::uuid,
     'dfe061d2-e7cc-4a12-8b39-7d68ed6cfcdb'::uuid,
     '3d9e3506-306a-4111-be4b-8abbe87e9fc6'::uuid,
     '72d6cca6-2549-47fe-a2cd-8c52eca5502b'::uuid,
     'c188aa47-59bc-40f3-8899-df14e47cf293'::uuid,
     '8c88efa8-08c6-41b4-a204-341bfa7c7eba'::uuid,
     '89d08432-a0d4-4fb0-b4e4-c81f356ab49f'::uuid,
     'bce16254-ab4a-4179-9551-46c2ae6298a1'::uuid,
     'bc0b5b98-7395-458b-96bc-c86c95581329'::uuid,
     '6d6cc63c-59da-45b5-ab5a-d627a7a0d48b'::uuid,
     'f6c21320-b579-4baa-813a-6d0c0373108f'::uuid,
     'ffe6e365-bdc9-458d-b560-954e0b1387fd'::uuid,
     '8552bf62-4eca-4830-8d6c-78918199accd'::uuid,
     '56a24712-850b-4854-99a4-2d9d8e291299'::uuid,
     'b5aab639-31d3-4059-984b-8a6a78af9782'::uuid,
     'b164134a-04c0-4f9d-b8c0-586ef916062b'::uuid,
     'c615c471-0e1c-4b34-a1b4-93ced1803ffd'::uuid,
     '464a7a43-084c-4ce9-8e02-d56b6fc8cae2'::uuid,
     'a819b9d5-465e-451b-98f2-2431831c9ba7'::uuid,
     'e8a249a8-5af3-472f-9ca4-11d394648aca'::uuid,
     '752bcf26-55cf-4f4f-8ee0-6d46692d6371'::uuid,
     'd7d7fc43-a15a-419e-91ec-88b50737a1aa'::uuid,
     '61d88830-911e-452b-b70d-f4f26e1653e5'::uuid,
     '8194af17-9ecf-48d1-bbf9-cd235a5efafe'::uuid,
     'bdab70dd-4560-4159-aea1-61ace9d676f3'::uuid,
     '9e98af27-70fc-441e-8438-9c932ceead77'::uuid,
     'd64e5c2c-b0d1-4a76-a647-3c635f8b68fa'::uuid,
     'daf49049-e71e-47b6-a22b-b9eb5204c879'::uuid,
     '43cfc6e3-5bb3-4767-a2fa-d5604ad594d9'::uuid,
     'c0cc63e9-3bfa-450e-b493-e6630b22da88'::uuid,
     '16fb8eed-5474-4027-be10-c527019f5673'::uuid,
     '2bd7358b-fbeb-4eee-86c3-9d8eda6a4226'::uuid,
     'ba90f709-8953-4115-887d-0b61306b7f83'::uuid,
     'eb7b4615-d86e-4929-8465-1bb3ca2d25af'::uuid,
     '20c5f5dd-1a7d-4f4a-a850-e10af8ffc1e2'::uuid,
     '612e0cfe-17fd-4b27-8150-df18e67b340c'::uuid,
     '8e0d44b7-2c02-4970-9df8-c92675de5551'::uuid,
     'f640ebf6-7888-4831-a481-3a08f903b7ae'::uuid,
     '56d6d1a9-4219-4d2d-965d-7e7400bd8a1d'::uuid,
     '8ef53d30-bdb5-42ed-ae41-77b5ccc4cb7a'::uuid,
     '065567f0-be08-430e-a829-0cbbcea46a63'::uuid,
     'e3931b0f-4852-415b-b0d6-e8a3b6a92c13'::uuid,
     'c1a4e07b-9f1e-4b3b-90cf-bd2977c34460'::uuid,
     '1dc6a5cc-873d-4cea-922c-1802c72c1e81'::uuid,
     'a05ca95b-ce42-4a72-aaa4-cf61392f9758'::uuid,
     'da1c0f63-e713-4d1c-a24e-c3957a9eb5bc'::uuid,
     '60e0a6f7-b306-4733-91f0-901f0c91ca19'::uuid,
     'faf9d7fb-5b3c-42ab-857c-9db603ceb0db'::uuid,
     '5d10bac0-2477-4c13-9293-b2efb0dcabdd'::uuid,
     'eb2ba4ac-cf7a-49af-b610-8b89bfe3485b'::uuid,
     '6f977792-d9d2-4eac-a4f0-93f74d52015b'::uuid,
     '1b6ba8a8-6c95-4e05-a5a1-66b05e6a12ce'::uuid
   );
-- Esperado: UPDATE 137


-- --------------------------------------------------------------------------
-- PASSO 5 - CONFERE
-- --------------------------------------------------------------------------
-- 5a) Retrato final.
SELECT count(*) FILTER (WHERE tipo =  'VENDA' AND coalesce(preco_venda,0) > 0) AS venda_com_preco,
       count(*) FILTER (WHERE tipo =  'VENDA' AND coalesce(preco_venda,0) = 0) AS venda_sem_preco,
       count(*) FILTER (WHERE tipo <> 'VENDA' AND coalesce(preco_venda,0) > 0) AS outros_com_preco
  FROM est_produtos
 WHERE ativo = true;
-- Esperado: 322 / 185 / 0

-- 5b) Nenhum preco de cortesia pode ter sobrado.
SELECT nome, preco_venda FROM est_produtos
 WHERE ativo = true AND tipo = 'VENDA'
   AND preco_venda > 0 AND preco_venda <= 0.02;
-- Esperado: nenhuma linha

-- 5c) Produtos vendendo ABAIXO do custo. Nao e erro deste SQL: o preco-lixo
--     escondia isso ate agora. Vale a cozinha olhar a ficha de cada um.
SELECT nome, preco_venda, custo_comp, custo_comp - preco_venda AS prejuizo_unit
  FROM est_produtos
 WHERE ativo = true AND tipo = 'VENDA'
   AND coalesce(preco_venda,0) > 0
   AND coalesce(custo_comp,0)  > coalesce(preco_venda,0)
 ORDER BY 4 DESC;
