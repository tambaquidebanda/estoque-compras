-- ============================================================================
-- SQL_FIX_CONVERSAO_CONTAGEM.sql
--
-- O QUE ACONTECEU
-- O commit 6084219, no ar desde 28/08/2026 16:36, passou a multiplicar a
-- contagem pelo fator_conversao antes de gravar em est_saldo_local. A premissa
-- estava errada: o time ja conta na unidade de uso na maioria dos itens. Quem
-- contou 18 capsulas viu o saldo virar 180.
--
-- O codigo ja foi consertado (commit 77390f0 desliga a multiplicacao). Este
-- arquivo conserta o DADO que ficou para tras.
--
-- ALCANCE (medido em 31/08/2026)
--   48 linhas de est_saldo_local, em BAR, COZINHA e CHURRASQUEIRA
--   R$ 20.741,21 de estoque fantasma
--   So a CONTAGEM foi afetada. A liberacao de pedido interno NAO foi:
--   o time confirma pelo celular, e aquele trecho nao mudou. Conferi os 75
--   itens com fator != 1 liberados desde sexta - todos gravados crus.
--
-- COMO O VALOR CERTO FOI CALCULADO
--   saldo_certo = contagem_crua + movimentos posteriores aquela contagem
--   Cada linha foi confirmada por batimento: o saldo de hoje bate exatamente
--   com "contagem x fator + movimentos". Onde nao bateu, ficou de fora.
--
-- FORA DESTE ARQUIVO, DE PROPOSITO
--   MP POLPA GRAVIOLA / BAR: contou 61, saldo esta 0. Nao e o fator (daria
--   488) - e outro bug, achado na mesma varredura: o produto aparece DUAS
--   vezes na tela de contagem (a estrutura tem "MP POLPA GRAVIOLA" e "MP POLPA
--   GRAVIOLA 1 KG" apontando para o mesmo cadastro), o time preenche um campo
--   so, e a linha vazia vencia o dedup e apagava o saldo. Consertado no codigo
--   pelo commit 75440ab, que agora soma as duas linhas em vez de deixar a
--   ultima vencer. O saldo se acerta sozinho na proxima contagem depois do
--   Push - por isso nao entra neste arquivo.
--
-- ORDEM
--   1. Fazer o Push do conserto no codigo ANTES de rodar isto. Sem isso a
--      contagem desta noite estraga tudo de novo.
--   2. PASSO 1 (so leitura), conferir.
--   3. PASSO 2 (escreve), so depois.
--
-- A trava: o PASSO 2 so mexe na linha cujo saldo ainda esta no valor errado
-- que eu medi. Se o setor recontar antes de voce rodar, aquela linha e pulada
-- em vez de sobrescrever a contagem nova.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Nao muda nada. Rode e confira a coluna "situacao".
-- ============================================================================
WITH conserto (produto_id, local, saldo_errado, saldo_certo, insumo) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'BAR', 0.975, 1.3, 'MP APEROL 750 ML'),
  ('fb03cede-5c9a-4125-820f-f1aa5026e154'::uuid, 'BAR', 300, 2, 'MP BASTAO DE GUARANA'),
  ('5c26a2e3-845d-473c-90b2-64dc5071f2a3'::uuid, 'BAR', 1.125, 1.5, 'MP CACHACA JAMBUCANA'),
  ('bfc9ca37-dcaa-4dbe-8330-ed37ae164d1d'::uuid, 'BAR', 180, 18, 'MP CAPSULA CAFE COM LEITE'),
  ('17ecac7d-4415-4956-a0f7-1f6e82455836'::uuid, 'BAR', 140, 14, 'MP CAPSULA CAPUCCINO CLASSICO'),
  ('9dc25728-b2ec-43ee-b885-9457125e9681'::uuid, 'BAR', 370, 37, 'MP CAPSULA CHOCOLATE COM CARAMELO'),
  ('f165aa4d-66cb-432c-8371-e612e6b89f4d'::uuid, 'BAR', 190, 19, 'MP CAPSULA DE GAS'),
  ('5a9a3406-7c6c-4dca-a80f-c7d6b127abe3'::uuid, 'BAR', 130, 13, 'MP CAPSULA EXPRESSO ATENTO'),
  ('2ec412bc-7b74-4614-9562-386489751d64'::uuid, 'BAR', 200, 20, 'MP CAPSULA EXPRESSO PLENO'),
  ('aa4314ae-2e00-478d-b750-7f4f7f4a07ac'::uuid, 'BAR', 100, 10, 'MP CAPSULA EXPRESSO VIBRANTE'),
  ('dc0aa62f-89c0-42d9-9b31-8313c2a5579b'::uuid, 'BAR', 0.84, 1.2, 'MP COINTREAL'),
  ('32686236-7910-4474-baf7-e8aeca104e27'::uuid, 'BAR', 0.03, 3, 'MP CORANTE AZUL'),
  ('9f903985-4b7f-47db-8d29-ed2f3b82e110'::uuid, 'BAR', 0.05, 5, 'MP CORANTE VERMELHO'),
  ('11970412-9a4c-424c-a72f-c41ca6033ef9'::uuid, 'BAR', 0.33, 0.5, 'MP ESPUMANTE MOSCATEL'),
  ('77b4879a-fe61-4631-9e20-379f9f2d2f40'::uuid, 'BAR', 50, 0.5, 'MP LARANJA'),
  ('ff2788a6-aec3-4531-b766-da4f971e18f3'::uuid, 'BAR', 0.21, 0.3, 'MP LICOR 43'),
  ('4f8558a0-bcac-4957-ba19-cdc99bd10d8e'::uuid, 'BAR', 0.06, 0.3, 'MP MELADO DE CANA'),
  ('d1138c62-686e-43ec-8981-f9f52d12df5a'::uuid, 'BAR', 320, 16, 'MP PICOLE DE ACAI'),
  ('26d6bf29-f42a-48aa-b77c-d386d24f4618'::uuid, 'BAR', 260, 13, 'MP PICOLE DE GRAVIOLA'),
  ('1928e7f0-9eab-40fb-b34b-0b88cff9bddd'::uuid, 'BAR', 472, 59, 'MP POLPA ACEROLA'),
  ('e0123c84-7e17-436c-a019-41cec9f3a5f8'::uuid, 'BAR', 96, 12, 'MP POLPA DE CAJU'),
  ('ca9d3dd6-5e17-479d-babc-842dc7bc5b08'::uuid, 'BAR', 720, 90, 'MP POLPA DE CUPUACU'),
  ('67f3d51a-115d-40df-ae98-e522e73e709c'::uuid, 'BAR', 576, 72, 'MP POLPA TAPEREBA'),
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'BAR', 0.15, 0.2, 'MP RUM BACARDI'),
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'BAR', 0.28, 0.4, 'MP SAGATIBA PURA 700ML'),
  ('d6579a68-c30b-4ff0-960a-dc1d31391aad'::uuid, 'BAR', 4, 0.8, 'MP SORVETE DE CREME'),
  ('bce1e18f-f2c4-4c4b-b377-702bd2813bc6'::uuid, 'BAR', 4, 0.8, 'MP SORVETE DE TAPIOCA'),
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'BAR', 0.525, 0.7, 'MP TANQUERAY 750ML'),
  ('9a329d38-02b6-4aef-8eee-623f275e81d7'::uuid, 'CHURRASQUEIRA', 44, 22, 'MP BANDA DE TAMBAQUI'),
  ('95552a3c-df05-4ced-9657-f0a76b8cd0f2'::uuid, 'COZINHA', 1520, 35, 'MC BANDEJA DE ALUMINIO D5'),
  ('1f456f36-d1d9-4f2f-b669-3464c42b6e4d'::uuid, 'COZINHA', 920, 29, 'MC BANDEJA DE ALUMINIO D6'),
  ('cfa54d60-0285-4961-94c7-a279dd511683'::uuid, 'COZINHA', 920, 29, 'MC BANDEJA DE ALUMINIO D7'),
  ('c96248c5-1029-446b-a1a6-0a57e6c8bb1a'::uuid, 'COZINHA', 51, 1.5, 'MC LUVA PLASTICA'),
  ('285184ce-29ac-4f44-a3ea-2322b787a9f4'::uuid, 'COZINHA', 675, 27, 'MC POTE RED 145ML'),
  ('eb2baecb-a0f0-402f-b3b6-f0321af549e3'::uuid, 'COZINHA', 1200, 96, 'MC POTE RED 250ML'),
  ('b93952db-28bd-425b-8972-7cbd545239a5'::uuid, 'COZINHA', 450, 18, 'MC POTE RED 500ML P FESTA'),
  ('b9646f90-fbfc-4b78-9bad-b383d93dfc0f'::uuid, 'COZINHA', 400, 40, 'MC POTE REDONDO C/ TAMPA PRAFESTA 750ML'),
  ('861cda93-c9fb-48b7-abf7-4b9875a9b10b'::uuid, 'COZINHA', 1100, 44, 'MC POTE RETANGULAR 500 ML'),
  ('15e972d2-cdb7-42c9-96aa-ee25b2089707'::uuid, 'COZINHA', 1.2, 1, 'MP CREAM CHEESE'),
  ('de353c0a-2863-4801-8858-4e9e6d637542'::uuid, 'COZINHA', 40.5, 4.5, 'MP FARINHA BRANCA'),
  ('16cd12c6-a9ea-428c-b1f5-78a021559445'::uuid, 'COZINHA', 34, 6, 'MP MARGARINA'),
  ('666a5efb-db14-48fc-8729-543151ba3857'::uuid, 'COZINHA', 3, 0.5, 'MP MASSA DE PURE DE BATATA'),
  ('e562995b-d90a-4380-8089-5b2b1fc8d51f'::uuid, 'COZINHA', 3, 4, 'MP OLEO COMPOSTO'),
  ('c8d8cf5a-e02e-4677-a801-83da5d2b2de8'::uuid, 'COZINHA', 8.5, 9, 'MP OLEO DE SOJA'),
  ('e126f2de-4448-4333-940d-c4ae17fe6fab'::uuid, 'COZINHA', 150, 5, 'MP OVO'),
  ('46e57488-aa48-40f6-9031-786fbdfc6c13'::uuid, 'COZINHA', 50, 26, 'MP POTE 1000ML'),
  ('950cf358-170f-4b80-9bea-8da247a0ba5a'::uuid, 'COZINHA', 5, 1, 'MP SORVETE DE BAUNILHA'),
  ('a0ceec2b-a076-41fd-a0e5-0453d840c220'::uuid, 'COZINHA', 12000, 20, 'MU MOLHEIRA')
)
SELECT c.insumo,
       c.local,
       s.saldo         AS saldo_hoje,
       c.saldo_certo   AS vai_virar,
       CASE
         WHEN s.produto_id IS NULL          THEN 'linha nao existe mais'
         WHEN s.saldo = c.saldo_errado      THEN 'vai corrigir'
         WHEN s.saldo = c.saldo_certo       THEN 'ja esta certo - nada a fazer'
         ELSE                                    'MUDOU depois - sera pulada'
       END AS situacao
FROM conserto c
LEFT JOIN est_saldo_local s
       ON s.produto_id = c.produto_id AND s.local = c.local
ORDER BY situacao, c.local, c.insumo;


-- ============================================================================
-- PASSO 2 - ESCREVE. Corrige o saldo e lanca o acerto no livro-razao.
--
-- Os dois acontecem na mesma instrucao: ou vai tudo, ou nao vai nada.
-- O lancamento no razao e do tipo 'ajuste', para o razao continuar somando o
-- mesmo que o saldo. As contagens erradas ficam no historico como aconteceram
-- - o razao e append-only, nao se apaga passado nele.
-- ============================================================================
WITH conserto (produto_id, local, saldo_errado, saldo_certo, insumo) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'BAR', 0.975, 1.3, 'MP APEROL 750 ML'),
  ('fb03cede-5c9a-4125-820f-f1aa5026e154'::uuid, 'BAR', 300, 2, 'MP BASTAO DE GUARANA'),
  ('5c26a2e3-845d-473c-90b2-64dc5071f2a3'::uuid, 'BAR', 1.125, 1.5, 'MP CACHACA JAMBUCANA'),
  ('bfc9ca37-dcaa-4dbe-8330-ed37ae164d1d'::uuid, 'BAR', 180, 18, 'MP CAPSULA CAFE COM LEITE'),
  ('17ecac7d-4415-4956-a0f7-1f6e82455836'::uuid, 'BAR', 140, 14, 'MP CAPSULA CAPUCCINO CLASSICO'),
  ('9dc25728-b2ec-43ee-b885-9457125e9681'::uuid, 'BAR', 370, 37, 'MP CAPSULA CHOCOLATE COM CARAMELO'),
  ('f165aa4d-66cb-432c-8371-e612e6b89f4d'::uuid, 'BAR', 190, 19, 'MP CAPSULA DE GAS'),
  ('5a9a3406-7c6c-4dca-a80f-c7d6b127abe3'::uuid, 'BAR', 130, 13, 'MP CAPSULA EXPRESSO ATENTO'),
  ('2ec412bc-7b74-4614-9562-386489751d64'::uuid, 'BAR', 200, 20, 'MP CAPSULA EXPRESSO PLENO'),
  ('aa4314ae-2e00-478d-b750-7f4f7f4a07ac'::uuid, 'BAR', 100, 10, 'MP CAPSULA EXPRESSO VIBRANTE'),
  ('dc0aa62f-89c0-42d9-9b31-8313c2a5579b'::uuid, 'BAR', 0.84, 1.2, 'MP COINTREAL'),
  ('32686236-7910-4474-baf7-e8aeca104e27'::uuid, 'BAR', 0.03, 3, 'MP CORANTE AZUL'),
  ('9f903985-4b7f-47db-8d29-ed2f3b82e110'::uuid, 'BAR', 0.05, 5, 'MP CORANTE VERMELHO'),
  ('11970412-9a4c-424c-a72f-c41ca6033ef9'::uuid, 'BAR', 0.33, 0.5, 'MP ESPUMANTE MOSCATEL'),
  ('77b4879a-fe61-4631-9e20-379f9f2d2f40'::uuid, 'BAR', 50, 0.5, 'MP LARANJA'),
  ('ff2788a6-aec3-4531-b766-da4f971e18f3'::uuid, 'BAR', 0.21, 0.3, 'MP LICOR 43'),
  ('4f8558a0-bcac-4957-ba19-cdc99bd10d8e'::uuid, 'BAR', 0.06, 0.3, 'MP MELADO DE CANA'),
  ('d1138c62-686e-43ec-8981-f9f52d12df5a'::uuid, 'BAR', 320, 16, 'MP PICOLE DE ACAI'),
  ('26d6bf29-f42a-48aa-b77c-d386d24f4618'::uuid, 'BAR', 260, 13, 'MP PICOLE DE GRAVIOLA'),
  ('1928e7f0-9eab-40fb-b34b-0b88cff9bddd'::uuid, 'BAR', 472, 59, 'MP POLPA ACEROLA'),
  ('e0123c84-7e17-436c-a019-41cec9f3a5f8'::uuid, 'BAR', 96, 12, 'MP POLPA DE CAJU'),
  ('ca9d3dd6-5e17-479d-babc-842dc7bc5b08'::uuid, 'BAR', 720, 90, 'MP POLPA DE CUPUACU'),
  ('67f3d51a-115d-40df-ae98-e522e73e709c'::uuid, 'BAR', 576, 72, 'MP POLPA TAPEREBA'),
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'BAR', 0.15, 0.2, 'MP RUM BACARDI'),
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'BAR', 0.28, 0.4, 'MP SAGATIBA PURA 700ML'),
  ('d6579a68-c30b-4ff0-960a-dc1d31391aad'::uuid, 'BAR', 4, 0.8, 'MP SORVETE DE CREME'),
  ('bce1e18f-f2c4-4c4b-b377-702bd2813bc6'::uuid, 'BAR', 4, 0.8, 'MP SORVETE DE TAPIOCA'),
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'BAR', 0.525, 0.7, 'MP TANQUERAY 750ML'),
  ('9a329d38-02b6-4aef-8eee-623f275e81d7'::uuid, 'CHURRASQUEIRA', 44, 22, 'MP BANDA DE TAMBAQUI'),
  ('95552a3c-df05-4ced-9657-f0a76b8cd0f2'::uuid, 'COZINHA', 1520, 35, 'MC BANDEJA DE ALUMINIO D5'),
  ('1f456f36-d1d9-4f2f-b669-3464c42b6e4d'::uuid, 'COZINHA', 920, 29, 'MC BANDEJA DE ALUMINIO D6'),
  ('cfa54d60-0285-4961-94c7-a279dd511683'::uuid, 'COZINHA', 920, 29, 'MC BANDEJA DE ALUMINIO D7'),
  ('c96248c5-1029-446b-a1a6-0a57e6c8bb1a'::uuid, 'COZINHA', 51, 1.5, 'MC LUVA PLASTICA'),
  ('285184ce-29ac-4f44-a3ea-2322b787a9f4'::uuid, 'COZINHA', 675, 27, 'MC POTE RED 145ML'),
  ('eb2baecb-a0f0-402f-b3b6-f0321af549e3'::uuid, 'COZINHA', 1200, 96, 'MC POTE RED 250ML'),
  ('b93952db-28bd-425b-8972-7cbd545239a5'::uuid, 'COZINHA', 450, 18, 'MC POTE RED 500ML P FESTA'),
  ('b9646f90-fbfc-4b78-9bad-b383d93dfc0f'::uuid, 'COZINHA', 400, 40, 'MC POTE REDONDO C/ TAMPA PRAFESTA 750ML'),
  ('861cda93-c9fb-48b7-abf7-4b9875a9b10b'::uuid, 'COZINHA', 1100, 44, 'MC POTE RETANGULAR 500 ML'),
  ('15e972d2-cdb7-42c9-96aa-ee25b2089707'::uuid, 'COZINHA', 1.2, 1, 'MP CREAM CHEESE'),
  ('de353c0a-2863-4801-8858-4e9e6d637542'::uuid, 'COZINHA', 40.5, 4.5, 'MP FARINHA BRANCA'),
  ('16cd12c6-a9ea-428c-b1f5-78a021559445'::uuid, 'COZINHA', 34, 6, 'MP MARGARINA'),
  ('666a5efb-db14-48fc-8729-543151ba3857'::uuid, 'COZINHA', 3, 0.5, 'MP MASSA DE PURE DE BATATA'),
  ('e562995b-d90a-4380-8089-5b2b1fc8d51f'::uuid, 'COZINHA', 3, 4, 'MP OLEO COMPOSTO'),
  ('c8d8cf5a-e02e-4677-a801-83da5d2b2de8'::uuid, 'COZINHA', 8.5, 9, 'MP OLEO DE SOJA'),
  ('e126f2de-4448-4333-940d-c4ae17fe6fab'::uuid, 'COZINHA', 150, 5, 'MP OVO'),
  ('46e57488-aa48-40f6-9031-786fbdfc6c13'::uuid, 'COZINHA', 50, 26, 'MP POTE 1000ML'),
  ('950cf358-170f-4b80-9bea-8da247a0ba5a'::uuid, 'COZINHA', 5, 1, 'MP SORVETE DE BAUNILHA'),
  ('a0ceec2b-a076-41fd-a0e5-0453d840c220'::uuid, 'COZINHA', 12000, 20, 'MU MOLHEIRA')
),
upd AS (
  UPDATE est_saldo_local s
     SET saldo      = c.saldo_certo,
         updated_at = now()
    FROM conserto c
   WHERE s.produto_id = c.produto_id
     AND s.local      = c.local
     AND s.saldo      = c.saldo_errado
  RETURNING s.produto_id, s.local, (c.saldo_certo - c.saldo_errado) AS delta
)
INSERT INTO est_movimentacoes
       (produto_id, local, tipo, quantidade, origem, motivo, responsavel, data)
SELECT produto_id, local, 'ajuste', delta, 'correcao',
       'Correcao: conversao de unidade indevida na contagem (commit 6084219)',
       'sistema', CURRENT_DATE
FROM upd
WHERE delta <> 0;


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Deve voltar zero linha.
-- ============================================================================
WITH conserto (produto_id, local, saldo_errado, saldo_certo, insumo) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'BAR', 0.975, 1.3, 'MP APEROL 750 ML'),
  ('fb03cede-5c9a-4125-820f-f1aa5026e154'::uuid, 'BAR', 300, 2, 'MP BASTAO DE GUARANA'),
  ('5c26a2e3-845d-473c-90b2-64dc5071f2a3'::uuid, 'BAR', 1.125, 1.5, 'MP CACHACA JAMBUCANA'),
  ('bfc9ca37-dcaa-4dbe-8330-ed37ae164d1d'::uuid, 'BAR', 180, 18, 'MP CAPSULA CAFE COM LEITE'),
  ('17ecac7d-4415-4956-a0f7-1f6e82455836'::uuid, 'BAR', 140, 14, 'MP CAPSULA CAPUCCINO CLASSICO'),
  ('9dc25728-b2ec-43ee-b885-9457125e9681'::uuid, 'BAR', 370, 37, 'MP CAPSULA CHOCOLATE COM CARAMELO'),
  ('f165aa4d-66cb-432c-8371-e612e6b89f4d'::uuid, 'BAR', 190, 19, 'MP CAPSULA DE GAS'),
  ('5a9a3406-7c6c-4dca-a80f-c7d6b127abe3'::uuid, 'BAR', 130, 13, 'MP CAPSULA EXPRESSO ATENTO'),
  ('2ec412bc-7b74-4614-9562-386489751d64'::uuid, 'BAR', 200, 20, 'MP CAPSULA EXPRESSO PLENO'),
  ('aa4314ae-2e00-478d-b750-7f4f7f4a07ac'::uuid, 'BAR', 100, 10, 'MP CAPSULA EXPRESSO VIBRANTE'),
  ('dc0aa62f-89c0-42d9-9b31-8313c2a5579b'::uuid, 'BAR', 0.84, 1.2, 'MP COINTREAL'),
  ('32686236-7910-4474-baf7-e8aeca104e27'::uuid, 'BAR', 0.03, 3, 'MP CORANTE AZUL'),
  ('9f903985-4b7f-47db-8d29-ed2f3b82e110'::uuid, 'BAR', 0.05, 5, 'MP CORANTE VERMELHO'),
  ('11970412-9a4c-424c-a72f-c41ca6033ef9'::uuid, 'BAR', 0.33, 0.5, 'MP ESPUMANTE MOSCATEL'),
  ('77b4879a-fe61-4631-9e20-379f9f2d2f40'::uuid, 'BAR', 50, 0.5, 'MP LARANJA'),
  ('ff2788a6-aec3-4531-b766-da4f971e18f3'::uuid, 'BAR', 0.21, 0.3, 'MP LICOR 43'),
  ('4f8558a0-bcac-4957-ba19-cdc99bd10d8e'::uuid, 'BAR', 0.06, 0.3, 'MP MELADO DE CANA'),
  ('d1138c62-686e-43ec-8981-f9f52d12df5a'::uuid, 'BAR', 320, 16, 'MP PICOLE DE ACAI'),
  ('26d6bf29-f42a-48aa-b77c-d386d24f4618'::uuid, 'BAR', 260, 13, 'MP PICOLE DE GRAVIOLA'),
  ('1928e7f0-9eab-40fb-b34b-0b88cff9bddd'::uuid, 'BAR', 472, 59, 'MP POLPA ACEROLA'),
  ('e0123c84-7e17-436c-a019-41cec9f3a5f8'::uuid, 'BAR', 96, 12, 'MP POLPA DE CAJU'),
  ('ca9d3dd6-5e17-479d-babc-842dc7bc5b08'::uuid, 'BAR', 720, 90, 'MP POLPA DE CUPUACU'),
  ('67f3d51a-115d-40df-ae98-e522e73e709c'::uuid, 'BAR', 576, 72, 'MP POLPA TAPEREBA'),
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'BAR', 0.15, 0.2, 'MP RUM BACARDI'),
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'BAR', 0.28, 0.4, 'MP SAGATIBA PURA 700ML'),
  ('d6579a68-c30b-4ff0-960a-dc1d31391aad'::uuid, 'BAR', 4, 0.8, 'MP SORVETE DE CREME'),
  ('bce1e18f-f2c4-4c4b-b377-702bd2813bc6'::uuid, 'BAR', 4, 0.8, 'MP SORVETE DE TAPIOCA'),
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'BAR', 0.525, 0.7, 'MP TANQUERAY 750ML'),
  ('9a329d38-02b6-4aef-8eee-623f275e81d7'::uuid, 'CHURRASQUEIRA', 44, 22, 'MP BANDA DE TAMBAQUI'),
  ('95552a3c-df05-4ced-9657-f0a76b8cd0f2'::uuid, 'COZINHA', 1520, 35, 'MC BANDEJA DE ALUMINIO D5'),
  ('1f456f36-d1d9-4f2f-b669-3464c42b6e4d'::uuid, 'COZINHA', 920, 29, 'MC BANDEJA DE ALUMINIO D6'),
  ('cfa54d60-0285-4961-94c7-a279dd511683'::uuid, 'COZINHA', 920, 29, 'MC BANDEJA DE ALUMINIO D7'),
  ('c96248c5-1029-446b-a1a6-0a57e6c8bb1a'::uuid, 'COZINHA', 51, 1.5, 'MC LUVA PLASTICA'),
  ('285184ce-29ac-4f44-a3ea-2322b787a9f4'::uuid, 'COZINHA', 675, 27, 'MC POTE RED 145ML'),
  ('eb2baecb-a0f0-402f-b3b6-f0321af549e3'::uuid, 'COZINHA', 1200, 96, 'MC POTE RED 250ML'),
  ('b93952db-28bd-425b-8972-7cbd545239a5'::uuid, 'COZINHA', 450, 18, 'MC POTE RED 500ML P FESTA'),
  ('b9646f90-fbfc-4b78-9bad-b383d93dfc0f'::uuid, 'COZINHA', 400, 40, 'MC POTE REDONDO C/ TAMPA PRAFESTA 750ML'),
  ('861cda93-c9fb-48b7-abf7-4b9875a9b10b'::uuid, 'COZINHA', 1100, 44, 'MC POTE RETANGULAR 500 ML'),
  ('15e972d2-cdb7-42c9-96aa-ee25b2089707'::uuid, 'COZINHA', 1.2, 1, 'MP CREAM CHEESE'),
  ('de353c0a-2863-4801-8858-4e9e6d637542'::uuid, 'COZINHA', 40.5, 4.5, 'MP FARINHA BRANCA'),
  ('16cd12c6-a9ea-428c-b1f5-78a021559445'::uuid, 'COZINHA', 34, 6, 'MP MARGARINA'),
  ('666a5efb-db14-48fc-8729-543151ba3857'::uuid, 'COZINHA', 3, 0.5, 'MP MASSA DE PURE DE BATATA'),
  ('e562995b-d90a-4380-8089-5b2b1fc8d51f'::uuid, 'COZINHA', 3, 4, 'MP OLEO COMPOSTO'),
  ('c8d8cf5a-e02e-4677-a801-83da5d2b2de8'::uuid, 'COZINHA', 8.5, 9, 'MP OLEO DE SOJA'),
  ('e126f2de-4448-4333-940d-c4ae17fe6fab'::uuid, 'COZINHA', 150, 5, 'MP OVO'),
  ('46e57488-aa48-40f6-9031-786fbdfc6c13'::uuid, 'COZINHA', 50, 26, 'MP POTE 1000ML'),
  ('950cf358-170f-4b80-9bea-8da247a0ba5a'::uuid, 'COZINHA', 5, 1, 'MP SORVETE DE BAUNILHA'),
  ('a0ceec2b-a076-41fd-a0e5-0453d840c220'::uuid, 'COZINHA', 12000, 20, 'MU MOLHEIRA')
)
SELECT c.insumo, c.local, s.saldo AS ainda_errado, c.saldo_certo
FROM conserto c
JOIN est_saldo_local s
  ON s.produto_id = c.produto_id AND s.local = c.local
WHERE s.saldo IS DISTINCT FROM c.saldo_certo
ORDER BY c.local, c.insumo;
