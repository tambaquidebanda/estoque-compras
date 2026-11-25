-- SQL_REVENDA_MARCADA.sql — marca no cadastro quais produtos são de REVENDA
--
-- O Wagner revisou produto a produto (25/11/2026) os grupos Cervejas, Doses, Bebidas não
-- alcoólicas, Chopp, Sucos, Café e Sobremesas bar.
-- Marcado = revenda (true). Listado e não marcado = NÃO é revenda (false), por decisão dele.
-- 91 viram revenda, 16 ficam como não revenda. Liga pelo id do produto (uuid).
-- Na Precificação, revenda usa preço mínimo = custo ÷ 0,40 (CMV alvo da Configuração).
-- Precisa do SQL_PRECIFICACAO.sql já rodado (coluna is_revenda).

-- ═══ PASSO 1 — CONFERIR (só leitura) ═══════════════════════════════════════════════
-- Mostra só o que MUDA. Produto que já está do jeito marcado não aparece.
WITH marcacao(produto_id, revenda) AS (VALUES
  ('cbec1c35-5d9b-415f-ac21-2fe64d4dd582'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · AGUA COM GAS
  ('58fe9427-a3ce-4d80-bfa6-0ebc0efbbd6d'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · AGUA SEM GAS
  ('b9607aa5-95b1-48d5-a74c-2663eb31e58b'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · ANTARTICA TONICA LT
  ('88096781-d884-461a-b565-ce2129d63d41'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · BARE 350ML LT
  ('1f51229e-ab01-42c0-84c8-1eade778f1f7'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · COCA COLA 350ML LT
  ('b06ff934-25ed-48fe-b302-b4d3bb252b1f'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · COCA COLA ZERO 350ML LT
  ('64b40733-6790-4257-86b3-2617c86fbe93'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · COCA COLA ZERO1,5L
  ('34046a76-c937-4b0f-afab-d36afe7b004a'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · FANTA LARANJA 350ML LT
  ('82c00db3-27f0-4aa0-a69f-3bd37bb88d48'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · FANTA UVA LT
  ('dc14b0ed-5794-4c7d-9dbf-a14db3661d31'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · GUARANA ANTARTICA 350 ML LT
  ('fa5a5621-6158-4723-909a-a0a68fffaf30'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · GUARANA ANTARTICA ZERO 350ML LT
  ('3b43e202-ce9b-49dc-9003-d01af87e249b'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · MONSTER
  ('00884416-1839-4705-adfc-dfb106510be9'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · PEPSI BLACK 1 L
  ('03440849-3833-4017-ab7b-1d8fdfb1520d'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · PEPSI BLACK LATA
  ('62a3f2f8-31a0-4b40-aebb-852010d39652'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · PEPSI LATA
  ('2ca72521-411c-4f68-8a44-503fe7cae09a'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SCHWEPPES CITRUS LT
  ('11ed0a3d-5872-4942-99ec-f69c53e48d99'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SCHWEPPES TONICA LT
  ('8c58ba73-fee8-4b05-b29e-50a2607526fd'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SODA LIMONADA LATA
  ('089300b3-1ace-46ae-beae-f69a68f0afc1'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SODA LT
  ('e2c2382e-9f4e-435f-98c9-d02644411af4'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SPRITE LT
  ('56a24712-850b-4854-99a4-2d9d8e291299'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SUKITA LATA
  ('6c10ab68-c003-42bf-9927-0d616433544c'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · TUCHAUA 1,5L
  ('58e52983-77e3-4674-b493-46fc8b6da9ea'::uuid, true), -- CAFE · CAFE COM LEITE
  ('1a61bc4d-b8e5-49f7-8f46-16aa13be0cea'::uuid, true), -- CAFE · CAFÉ CHOCOLATE E CARAMELO
  ('3f3eb352-d1b5-42f7-b9cb-4cd1bb0c9b53'::uuid, true), -- CAFE · CAPUCCINO
  ('397124be-ef1f-4526-af70-b52647252fd0'::uuid, true), -- CAFE · EXPRESSO ATENTO
  ('4a94403b-186f-45f3-ba82-d067b010be86'::uuid, true), -- CAFE · EXPRESSO VIBRANTE
  ('ef52dbef-cad0-4db7-9f6f-61c9aadf422f'::uuid, true), -- CERVEJAS · BOHEMIA 600ML
  ('860305dc-38c9-45eb-92d6-660070a57f57'::uuid, true), -- CERVEJAS · BRAHMA DUPLO MALTE 600ML
  ('6606ec72-8352-4e30-b16a-622522005ce7'::uuid, true), -- CERVEJAS · BUDWEISER LN
  ('065567f0-be08-430e-a829-0cbbcea46a63'::uuid, true), -- CERVEJAS · BUDWEISER LN ZERO ALCOOL
  ('1384001d-e5f2-463a-9397-2ccf245f6662'::uuid, true), -- CERVEJAS · BUDWEISSER 600ML
  ('ef1718da-803c-43a7-8552-39c0cc69c618'::uuid, true), -- CERVEJAS · COLORADO RIBEIRAO 600ml
  ('9ad48383-33b8-4f51-bf8e-9c5a3dc7d606'::uuid, true), -- CERVEJAS · COPO SUJO
  ('5810c8f0-02c3-4e7c-9fd6-ead494d989c2'::uuid, true), -- CERVEJAS · CORONA LN
  ('5868ddc0-6d43-4ed5-9d37-01d7441428c5'::uuid, true), -- CERVEJAS · CORONA ZERO ALCOOL LN
  ('8be9c75b-71aa-444e-8250-0b6200675bc7'::uuid, true), -- CERVEJAS · MICHELOB
  ('ad3913ed-e4c5-4c2e-9978-0f76c77f172c'::uuid, true), -- CERVEJAS · ORIGINAL 600ML
  ('bc2dca2a-db49-48b7-a13e-c3b5fb3f0179'::uuid, true), -- CERVEJAS · ORIGINAL LN
  ('f2d44efd-1bc9-4371-aea6-e25da1a17cbc'::uuid, true), -- CERVEJAS · SPATEN 600ml
  ('69f197cd-8af0-4297-a19f-d5f63cf1496a'::uuid, true), -- CERVEJAS · SPATEN LN
  ('4354ac6c-6668-4bc4-a03a-193fe5014b58'::uuid, true), -- CERVEJAS · STELLA ARTOIS 600ML
  ('1295f860-4be8-4004-b621-4694a6a407d5'::uuid, true), -- CERVEJAS · STELLA ARTOIS GOLD LN
  ('a3cc7c54-be4a-4b7a-b55d-8047e363c94f'::uuid, true), -- CERVEJAS · STELLA ARTOIS LN
  ('03b09ee3-db33-4637-85e8-b4949c82d4ab'::uuid, true), -- CERVEJAS · STELLA PURE GOLD 600
  ('3d700b7e-faa6-4968-9fe1-f8bbde3566b9'::uuid, true), -- CHOPP · AVALIA CHOPP 300ML
  ('45b90e7b-ee31-4a15-b97e-315791856075'::uuid, true), -- CHOPP · CAIPIRINHA TRADICIONAL EM DOBRO
  ('5f86cc74-5d69-48db-9ce5-2b202be24ed2'::uuid, true), -- CHOPP · CHOPP BRAHMA 300 ML
  ('6bb749a3-6e6a-47f2-99fc-479a8c11e05f'::uuid, true), -- CHOPP · CHOPP BRAHMA 500 ML
  ('d7f8ed83-790b-4fed-a16a-d71e1eba68ef'::uuid, true), -- CHOPP · CHOPP BRAHMA DOBRO 500 ML
  ('314224b0-9ec8-415f-aaa8-7db0c2e90da1'::uuid, true), -- CHOPP · CHOPP BRAHMA DOBRO AZULOU 500 ML
  ('61b41027-b9dc-477e-a3cb-b9f8ae1ae06a'::uuid, true), -- CHOPP · CHOPP BRAHMA DOBRO VERMELHOU 500 ML
  ('84aff6d1-d223-4e2d-aab1-372b68033136'::uuid, true), -- CHOPP · CHOPP BRAHMA SUJO 300 PROMOÇÃO
  ('efe672a7-4887-43a6-a8c4-df492c04158f'::uuid, true), -- CHOPP · CHOPP DOBRO 300 ML
  ('24cef1e3-2b78-4553-b3a2-1424a7058f23'::uuid, true), -- CHOPP · CHOPP DOBRO AZULOU 300 ML
  ('9eec3e77-e7ba-4323-85a6-daaade532b12'::uuid, true), -- CHOPP · CHOPP DOBRO VERMELHOU 300 ML
  ('6a03390c-6cb3-4139-91b5-08604e40028e'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA 300ML
  ('97302e99-3e21-4ce6-934c-12e77d439f72'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA 500ml
  ('08735dcd-15a1-4f00-9308-1475f4c74f5d'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA AZULOU CHOPP 500ml
  ('5ee8121c-91ba-4ff3-81be-968f2c8c71c4'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA DOBRO 500ml
  ('70399920-1cf5-4f02-9a4b-dfcb9fd608e3'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA VERMELHOU CHOPP 500ml
  ('6187d56c-c782-455e-bc5f-4d826ee04328'::uuid, true), -- CHOPP · CHOPP SUJO DOBRO 300ML
  ('71b5b019-37ba-4ac6-9f15-a03f80f6a49b'::uuid, true), -- CHOPP · CHOPP SUJO DOBRO AZULOU 300ML
  ('d3e74c2a-8c70-48b0-8df8-4baac269bb28'::uuid, true), -- CHOPP · CHOPP SUJO DOBRO VERMELHOU 300ML
  ('8194af17-9ecf-48d1-bbf9-cd235a5efafe'::uuid, true), -- DOSES · AMBURANA DOSE
  ('11f6ccd8-61af-45e7-936f-dbf1ae4e210e'::uuid, true), -- DOSES · APEROL DOSE
  ('c7b79f66-bb18-4303-a662-86f58460c031'::uuid, true), -- DOSES · BACARDI CARTA BRANCA DOSE
  ('c615c471-0e1c-4b34-a1b4-93ced1803ffd'::uuid, true), -- DOSES · CACHACA SAGATIBA DOSE
  ('36193466-76c8-460f-832f-74ce7c5b4853'::uuid, true), -- DOSES · CACHACA TRADICIONAL OURO DOSE
  ('752bcf26-55cf-4f4f-8ee0-6d46692d6371'::uuid, true), -- DOSES · CACHACA TRADICIONAL PRATA DOSE
  ('9e98af27-70fc-441e-8438-9c932ceead77'::uuid, true), -- DOSES · CACHAÇA BRAZUKA DOSE
  ('a2e191aa-7246-45f8-8d50-853b75d3fb4b'::uuid, true), -- DOSES · CACHAÇA INDIAZINHA
  ('42195135-0e93-453e-9c82-71743a6f98be'::uuid, true), -- DOSES · COINTREAU DOSE
  ('3d3cd111-b12f-42c1-a16c-4cbf21b68a76'::uuid, true), -- DOSES · GARRAFA DE SMIRNOFF
  ('0c7080d9-2085-47d6-8b9c-7086f9002597'::uuid, true), -- DOSES · GIN BEEFEATER DOSE
  ('9ca6a994-6c0a-4836-9b28-28c687bfa51a'::uuid, true), -- DOSES · GIN TANQUERAY DOSE
  ('056829c8-58b1-4c9f-8fc2-0c6d83646551'::uuid, true), -- DOSES · JAMBUCANA DOSE
  ('3d9e3506-306a-4111-be4b-8abbe87e9fc6'::uuid, true), -- DOSES · LICOR 43 DOSE
  ('60e0a6f7-b306-4733-91f0-901f0c91ca19'::uuid, true), -- DOSES · VODKA IMPRT ABSOLUT DOSE
  ('bce16254-ab4a-4179-9551-46c2ae6298a1'::uuid, true), -- DOSES · VODKA NAC SMIRNOFF DOSE
  ('acfcbbbf-3b50-409a-96a6-4e82cd0cb41a'::uuid, true), -- DOSES · WHISKY BLACK LABEL DOSE
  ('612e0cfe-17fd-4b27-8150-df18e67b340c'::uuid, true), -- DOSES · WHISKY RED LABEL DOSE
  ('cbb8bde7-88c8-4bae-8286-3a3d691fd6ef'::uuid, true), -- SOBREMESAS BAR · CEU DE BRIGADEIRO
  ('16a05c4c-b043-4b3e-8d0c-fd118c2ecbfd'::uuid, true), -- SOBREMESAS BAR · CHEESCAKE DE CHOCOLATE COM CUPUAÇU
  ('dc98adea-c64c-4b8c-aa00-9c99d2f7dc40'::uuid, true), -- SOBREMESAS BAR · CHOCUCA
  ('0e5f418f-1617-453c-8126-6ad16a542425'::uuid, true), -- SOBREMESAS BAR · PUDIM DE CUPUAÇU
  ('c6584841-46b0-4796-8cdd-9428e02668c8'::uuid, true), -- SOBREMESAS BAR · PUDIM DIET
  ('0c5cdfba-481e-4c3e-81f3-b54f074f63bc'::uuid, true), -- SOBREMESAS BAR · TORTA DE ABACAXI
  ('689beba1-512e-4011-b692-6962a2f7ddfe'::uuid, true), -- SOBREMESAS BAR · TORTA DE CUPUACU C/ CASTANHA
  ('13222127-bd00-4f8d-8bd5-6d0602d7811d'::uuid, true), -- SOBREMESAS BAR · TORTA DE CUPUACU C/ CHOCOLATE
  ('feb41c69-a28b-44f2-a9b3-9c0879f26ea1'::uuid, true), -- SOBREMESAS BAR · TORTA DE CUPUACU C/ DOCE
  ('0d51feb2-5a90-4488-959d-72f0bc2c9f44'::uuid, false), -- DOSES · XAROPE DE CUPUAÇU LITRO
  ('c6c91984-db6a-424e-abe4-c2ebd9ba7a78'::uuid, false), -- SOBREMESAS BAR · BOTACOCO
  ('e3ff86f4-af1b-4e7c-ba88-206478b99478'::uuid, false), -- SOBREMESAS BAR · COMPOTE-SE DE CUPUACU
  ('11d90212-7987-40d4-85e0-1427110065b7'::uuid, false), -- SOBREMESAS BAR · TORTA DE OVOMANTINE
  ('26cbf768-1a96-44d0-b721-a9cb10af1a94'::uuid, false), -- SUCOS · ADC. LEITE COPO
  ('d82d4a9c-8465-4c55-a9b4-914e85a84fd4'::uuid, false), -- SUCOS · LIMONADA SUICA
  ('a6aad8d9-19f5-413b-a4f5-b47be8a4647a'::uuid, false), -- SUCOS · SUCO DE ABACAXI
  ('78b944f4-db57-44ec-ace0-a3d10c7b42a4'::uuid, false), -- SUCOS · SUCO DE ABACAXI C/ HORTELA
  ('875189ed-b32c-4379-ba12-3aae1d62a490'::uuid, false), -- SUCOS · SUCO DE CUPUACU
  ('874fc185-13ef-4bcb-b82a-4ec5e932d343'::uuid, false), -- SUCOS · SUCO DE GRAVIOLA
  ('ccc6eeb1-a0a8-4150-a201-43acf520f652'::uuid, false), -- SUCOS · SUCO DE LARANJA
  ('2141471c-f351-4216-a973-47c429dcf6be'::uuid, false), -- SUCOS · SUCO DE LARANJA C/ ACEROLA
  ('108b8ae6-2426-4bfa-985c-54644952e4a7'::uuid, false), -- SUCOS · SUCO DE LIMAO
  ('7f328871-3011-4eee-ac00-b85c4216b399'::uuid, false), -- SUCOS · SUCO DE MANGA
  ('bebfde33-a985-42d9-a0e6-6eab341a3205'::uuid, false), -- SUCOS · SUCO DE MARACUJA
  ('51f8056c-7a45-4189-835f-06f4b685870d'::uuid, false) -- SUCOS · SUCO DE TAPEREBA
)
SELECT p.nome, p.is_revenda AS hoje, m.revenda AS vai_ficar
FROM marcacao m
JOIN est_produtos p ON p.id = m.produto_id
WHERE p.is_revenda IS DISTINCT FROM m.revenda
ORDER BY m.revenda DESC, p.nome;

-- ═══ PASSO 2 — GRAVAR ══════════════════════════════════════════════════════════════
WITH marcacao(produto_id, revenda) AS (VALUES
  ('cbec1c35-5d9b-415f-ac21-2fe64d4dd582'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · AGUA COM GAS
  ('58fe9427-a3ce-4d80-bfa6-0ebc0efbbd6d'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · AGUA SEM GAS
  ('b9607aa5-95b1-48d5-a74c-2663eb31e58b'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · ANTARTICA TONICA LT
  ('88096781-d884-461a-b565-ce2129d63d41'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · BARE 350ML LT
  ('1f51229e-ab01-42c0-84c8-1eade778f1f7'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · COCA COLA 350ML LT
  ('b06ff934-25ed-48fe-b302-b4d3bb252b1f'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · COCA COLA ZERO 350ML LT
  ('64b40733-6790-4257-86b3-2617c86fbe93'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · COCA COLA ZERO1,5L
  ('34046a76-c937-4b0f-afab-d36afe7b004a'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · FANTA LARANJA 350ML LT
  ('82c00db3-27f0-4aa0-a69f-3bd37bb88d48'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · FANTA UVA LT
  ('dc14b0ed-5794-4c7d-9dbf-a14db3661d31'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · GUARANA ANTARTICA 350 ML LT
  ('fa5a5621-6158-4723-909a-a0a68fffaf30'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · GUARANA ANTARTICA ZERO 350ML LT
  ('3b43e202-ce9b-49dc-9003-d01af87e249b'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · MONSTER
  ('00884416-1839-4705-adfc-dfb106510be9'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · PEPSI BLACK 1 L
  ('03440849-3833-4017-ab7b-1d8fdfb1520d'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · PEPSI BLACK LATA
  ('62a3f2f8-31a0-4b40-aebb-852010d39652'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · PEPSI LATA
  ('2ca72521-411c-4f68-8a44-503fe7cae09a'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SCHWEPPES CITRUS LT
  ('11ed0a3d-5872-4942-99ec-f69c53e48d99'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SCHWEPPES TONICA LT
  ('8c58ba73-fee8-4b05-b29e-50a2607526fd'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SODA LIMONADA LATA
  ('089300b3-1ace-46ae-beae-f69a68f0afc1'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SODA LT
  ('e2c2382e-9f4e-435f-98c9-d02644411af4'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SPRITE LT
  ('56a24712-850b-4854-99a4-2d9d8e291299'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · SUKITA LATA
  ('6c10ab68-c003-42bf-9927-0d616433544c'::uuid, true), -- BEBIDAS NAO ALCOOLICAS · TUCHAUA 1,5L
  ('58e52983-77e3-4674-b493-46fc8b6da9ea'::uuid, true), -- CAFE · CAFE COM LEITE
  ('1a61bc4d-b8e5-49f7-8f46-16aa13be0cea'::uuid, true), -- CAFE · CAFÉ CHOCOLATE E CARAMELO
  ('3f3eb352-d1b5-42f7-b9cb-4cd1bb0c9b53'::uuid, true), -- CAFE · CAPUCCINO
  ('397124be-ef1f-4526-af70-b52647252fd0'::uuid, true), -- CAFE · EXPRESSO ATENTO
  ('4a94403b-186f-45f3-ba82-d067b010be86'::uuid, true), -- CAFE · EXPRESSO VIBRANTE
  ('ef52dbef-cad0-4db7-9f6f-61c9aadf422f'::uuid, true), -- CERVEJAS · BOHEMIA 600ML
  ('860305dc-38c9-45eb-92d6-660070a57f57'::uuid, true), -- CERVEJAS · BRAHMA DUPLO MALTE 600ML
  ('6606ec72-8352-4e30-b16a-622522005ce7'::uuid, true), -- CERVEJAS · BUDWEISER LN
  ('065567f0-be08-430e-a829-0cbbcea46a63'::uuid, true), -- CERVEJAS · BUDWEISER LN ZERO ALCOOL
  ('1384001d-e5f2-463a-9397-2ccf245f6662'::uuid, true), -- CERVEJAS · BUDWEISSER 600ML
  ('ef1718da-803c-43a7-8552-39c0cc69c618'::uuid, true), -- CERVEJAS · COLORADO RIBEIRAO 600ml
  ('9ad48383-33b8-4f51-bf8e-9c5a3dc7d606'::uuid, true), -- CERVEJAS · COPO SUJO
  ('5810c8f0-02c3-4e7c-9fd6-ead494d989c2'::uuid, true), -- CERVEJAS · CORONA LN
  ('5868ddc0-6d43-4ed5-9d37-01d7441428c5'::uuid, true), -- CERVEJAS · CORONA ZERO ALCOOL LN
  ('8be9c75b-71aa-444e-8250-0b6200675bc7'::uuid, true), -- CERVEJAS · MICHELOB
  ('ad3913ed-e4c5-4c2e-9978-0f76c77f172c'::uuid, true), -- CERVEJAS · ORIGINAL 600ML
  ('bc2dca2a-db49-48b7-a13e-c3b5fb3f0179'::uuid, true), -- CERVEJAS · ORIGINAL LN
  ('f2d44efd-1bc9-4371-aea6-e25da1a17cbc'::uuid, true), -- CERVEJAS · SPATEN 600ml
  ('69f197cd-8af0-4297-a19f-d5f63cf1496a'::uuid, true), -- CERVEJAS · SPATEN LN
  ('4354ac6c-6668-4bc4-a03a-193fe5014b58'::uuid, true), -- CERVEJAS · STELLA ARTOIS 600ML
  ('1295f860-4be8-4004-b621-4694a6a407d5'::uuid, true), -- CERVEJAS · STELLA ARTOIS GOLD LN
  ('a3cc7c54-be4a-4b7a-b55d-8047e363c94f'::uuid, true), -- CERVEJAS · STELLA ARTOIS LN
  ('03b09ee3-db33-4637-85e8-b4949c82d4ab'::uuid, true), -- CERVEJAS · STELLA PURE GOLD 600
  ('3d700b7e-faa6-4968-9fe1-f8bbde3566b9'::uuid, true), -- CHOPP · AVALIA CHOPP 300ML
  ('45b90e7b-ee31-4a15-b97e-315791856075'::uuid, true), -- CHOPP · CAIPIRINHA TRADICIONAL EM DOBRO
  ('5f86cc74-5d69-48db-9ce5-2b202be24ed2'::uuid, true), -- CHOPP · CHOPP BRAHMA 300 ML
  ('6bb749a3-6e6a-47f2-99fc-479a8c11e05f'::uuid, true), -- CHOPP · CHOPP BRAHMA 500 ML
  ('d7f8ed83-790b-4fed-a16a-d71e1eba68ef'::uuid, true), -- CHOPP · CHOPP BRAHMA DOBRO 500 ML
  ('314224b0-9ec8-415f-aaa8-7db0c2e90da1'::uuid, true), -- CHOPP · CHOPP BRAHMA DOBRO AZULOU 500 ML
  ('61b41027-b9dc-477e-a3cb-b9f8ae1ae06a'::uuid, true), -- CHOPP · CHOPP BRAHMA DOBRO VERMELHOU 500 ML
  ('84aff6d1-d223-4e2d-aab1-372b68033136'::uuid, true), -- CHOPP · CHOPP BRAHMA SUJO 300 PROMOÇÃO
  ('efe672a7-4887-43a6-a8c4-df492c04158f'::uuid, true), -- CHOPP · CHOPP DOBRO 300 ML
  ('24cef1e3-2b78-4553-b3a2-1424a7058f23'::uuid, true), -- CHOPP · CHOPP DOBRO AZULOU 300 ML
  ('9eec3e77-e7ba-4323-85a6-daaade532b12'::uuid, true), -- CHOPP · CHOPP DOBRO VERMELHOU 300 ML
  ('6a03390c-6cb3-4139-91b5-08604e40028e'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA 300ML
  ('97302e99-3e21-4ce6-934c-12e77d439f72'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA 500ml
  ('08735dcd-15a1-4f00-9308-1475f4c74f5d'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA AZULOU CHOPP 500ml
  ('5ee8121c-91ba-4ff3-81be-968f2c8c71c4'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA DOBRO 500ml
  ('70399920-1cf5-4f02-9a4b-dfcb9fd608e3'::uuid, true), -- CHOPP · CHOPP SUJO BRAHMA VERMELHOU CHOPP 500ml
  ('6187d56c-c782-455e-bc5f-4d826ee04328'::uuid, true), -- CHOPP · CHOPP SUJO DOBRO 300ML
  ('71b5b019-37ba-4ac6-9f15-a03f80f6a49b'::uuid, true), -- CHOPP · CHOPP SUJO DOBRO AZULOU 300ML
  ('d3e74c2a-8c70-48b0-8df8-4baac269bb28'::uuid, true), -- CHOPP · CHOPP SUJO DOBRO VERMELHOU 300ML
  ('8194af17-9ecf-48d1-bbf9-cd235a5efafe'::uuid, true), -- DOSES · AMBURANA DOSE
  ('11f6ccd8-61af-45e7-936f-dbf1ae4e210e'::uuid, true), -- DOSES · APEROL DOSE
  ('c7b79f66-bb18-4303-a662-86f58460c031'::uuid, true), -- DOSES · BACARDI CARTA BRANCA DOSE
  ('c615c471-0e1c-4b34-a1b4-93ced1803ffd'::uuid, true), -- DOSES · CACHACA SAGATIBA DOSE
  ('36193466-76c8-460f-832f-74ce7c5b4853'::uuid, true), -- DOSES · CACHACA TRADICIONAL OURO DOSE
  ('752bcf26-55cf-4f4f-8ee0-6d46692d6371'::uuid, true), -- DOSES · CACHACA TRADICIONAL PRATA DOSE
  ('9e98af27-70fc-441e-8438-9c932ceead77'::uuid, true), -- DOSES · CACHAÇA BRAZUKA DOSE
  ('a2e191aa-7246-45f8-8d50-853b75d3fb4b'::uuid, true), -- DOSES · CACHAÇA INDIAZINHA
  ('42195135-0e93-453e-9c82-71743a6f98be'::uuid, true), -- DOSES · COINTREAU DOSE
  ('3d3cd111-b12f-42c1-a16c-4cbf21b68a76'::uuid, true), -- DOSES · GARRAFA DE SMIRNOFF
  ('0c7080d9-2085-47d6-8b9c-7086f9002597'::uuid, true), -- DOSES · GIN BEEFEATER DOSE
  ('9ca6a994-6c0a-4836-9b28-28c687bfa51a'::uuid, true), -- DOSES · GIN TANQUERAY DOSE
  ('056829c8-58b1-4c9f-8fc2-0c6d83646551'::uuid, true), -- DOSES · JAMBUCANA DOSE
  ('3d9e3506-306a-4111-be4b-8abbe87e9fc6'::uuid, true), -- DOSES · LICOR 43 DOSE
  ('60e0a6f7-b306-4733-91f0-901f0c91ca19'::uuid, true), -- DOSES · VODKA IMPRT ABSOLUT DOSE
  ('bce16254-ab4a-4179-9551-46c2ae6298a1'::uuid, true), -- DOSES · VODKA NAC SMIRNOFF DOSE
  ('acfcbbbf-3b50-409a-96a6-4e82cd0cb41a'::uuid, true), -- DOSES · WHISKY BLACK LABEL DOSE
  ('612e0cfe-17fd-4b27-8150-df18e67b340c'::uuid, true), -- DOSES · WHISKY RED LABEL DOSE
  ('cbb8bde7-88c8-4bae-8286-3a3d691fd6ef'::uuid, true), -- SOBREMESAS BAR · CEU DE BRIGADEIRO
  ('16a05c4c-b043-4b3e-8d0c-fd118c2ecbfd'::uuid, true), -- SOBREMESAS BAR · CHEESCAKE DE CHOCOLATE COM CUPUAÇU
  ('dc98adea-c64c-4b8c-aa00-9c99d2f7dc40'::uuid, true), -- SOBREMESAS BAR · CHOCUCA
  ('0e5f418f-1617-453c-8126-6ad16a542425'::uuid, true), -- SOBREMESAS BAR · PUDIM DE CUPUAÇU
  ('c6584841-46b0-4796-8cdd-9428e02668c8'::uuid, true), -- SOBREMESAS BAR · PUDIM DIET
  ('0c5cdfba-481e-4c3e-81f3-b54f074f63bc'::uuid, true), -- SOBREMESAS BAR · TORTA DE ABACAXI
  ('689beba1-512e-4011-b692-6962a2f7ddfe'::uuid, true), -- SOBREMESAS BAR · TORTA DE CUPUACU C/ CASTANHA
  ('13222127-bd00-4f8d-8bd5-6d0602d7811d'::uuid, true), -- SOBREMESAS BAR · TORTA DE CUPUACU C/ CHOCOLATE
  ('feb41c69-a28b-44f2-a9b3-9c0879f26ea1'::uuid, true), -- SOBREMESAS BAR · TORTA DE CUPUACU C/ DOCE
  ('0d51feb2-5a90-4488-959d-72f0bc2c9f44'::uuid, false), -- DOSES · XAROPE DE CUPUAÇU LITRO
  ('c6c91984-db6a-424e-abe4-c2ebd9ba7a78'::uuid, false), -- SOBREMESAS BAR · BOTACOCO
  ('e3ff86f4-af1b-4e7c-ba88-206478b99478'::uuid, false), -- SOBREMESAS BAR · COMPOTE-SE DE CUPUACU
  ('11d90212-7987-40d4-85e0-1427110065b7'::uuid, false), -- SOBREMESAS BAR · TORTA DE OVOMANTINE
  ('26cbf768-1a96-44d0-b721-a9cb10af1a94'::uuid, false), -- SUCOS · ADC. LEITE COPO
  ('d82d4a9c-8465-4c55-a9b4-914e85a84fd4'::uuid, false), -- SUCOS · LIMONADA SUICA
  ('a6aad8d9-19f5-413b-a4f5-b47be8a4647a'::uuid, false), -- SUCOS · SUCO DE ABACAXI
  ('78b944f4-db57-44ec-ace0-a3d10c7b42a4'::uuid, false), -- SUCOS · SUCO DE ABACAXI C/ HORTELA
  ('875189ed-b32c-4379-ba12-3aae1d62a490'::uuid, false), -- SUCOS · SUCO DE CUPUACU
  ('874fc185-13ef-4bcb-b82a-4ec5e932d343'::uuid, false), -- SUCOS · SUCO DE GRAVIOLA
  ('ccc6eeb1-a0a8-4150-a201-43acf520f652'::uuid, false), -- SUCOS · SUCO DE LARANJA
  ('2141471c-f351-4216-a973-47c429dcf6be'::uuid, false), -- SUCOS · SUCO DE LARANJA C/ ACEROLA
  ('108b8ae6-2426-4bfa-985c-54644952e4a7'::uuid, false), -- SUCOS · SUCO DE LIMAO
  ('7f328871-3011-4eee-ac00-b85c4216b399'::uuid, false), -- SUCOS · SUCO DE MANGA
  ('bebfde33-a985-42d9-a0e6-6eab341a3205'::uuid, false), -- SUCOS · SUCO DE MARACUJA
  ('51f8056c-7a45-4189-835f-06f4b685870d'::uuid, false) -- SUCOS · SUCO DE TAPEREBA
),
gravados AS (
  UPDATE est_produtos p
     SET is_revenda = m.revenda
    FROM marcacao m
   WHERE p.id = m.produto_id
     AND p.is_revenda IS DISTINCT FROM m.revenda
  RETURNING m.revenda
)
SELECT count(*) FILTER (WHERE revenda)     AS viraram_revenda,
       count(*) FILTER (WHERE NOT revenda) AS deixaram_de_ser
FROM gravados;
