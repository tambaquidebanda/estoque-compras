-- RECALCULO DOS CUSTOS DAS FICHAS TECNICAS  --  21/08/2026
--
-- Regrava custo_total / custo_por_porcao das fichas ativas com o preco ATUAL dos ingredientes
-- e replica o custo por porcao em est_produtos.custo_comp - a mesma regra do botao Salvar
-- Ficha. Fichas aninhadas ja vem resolvidas em cadeia; os valores abaixo sao os finais.
--
-- Alcance: 153 fichas ativas e 153 produtos, de 550 fichas ativas. As demais ja
-- estao corretas e nao sao tocadas. Nao mexe em estoque, movimentacoes nem financeiro.
--
-- Independente da questao do recheio de pirarucu: usa as fichas exatamente como estao hoje.
-- Se a troca do recheio for confirmada depois, sai um SQL complementar so para o bolinho
-- e o pastel.
--
-- Para desfazer: SQL_ROLLBACK_RECALC_CUSTOS.sql restaura os valores exatos de antes.


-- ===== PASSO 1 - CONFERIR ANTES (so leitura) =====

select p.nome, f.custo_total as gravado_hoje, f.custo_por_porcao as porcao_hoje
  from est_fichas_tecnicas f
  join est_produtos p on p.id = f.produto_id
 where f.id in (
  '2163d212-84c3-41b7-9fbd-26761c3f08ad',
  'de49ab3d-fab9-491e-ac7c-64af14f317f5',
  'ed787dfa-512b-4075-baa7-4d7d5d19ba8a',
  '2f06e66e-2113-4b44-a4e4-861935c814a3',
  '597d2cd3-9e89-483a-826c-f6b490092cd1',
  '46ddbe86-bf93-43c4-a5d6-2062667fb109',
  '83350b6e-0aa8-4807-b898-676f00ade136',
  '91848eb5-f679-497e-bcbc-2ddc3a13677b',
  '8556bfbe-25d6-4250-927b-2ee37eaeb486',
  'bb697ec1-c6dc-469f-8c9b-f8f10308f1c7',
  'aa34600e-7e8f-4197-b687-2ede7fa5ec2b',
  '4036c2f2-06ca-4e9f-8548-b3d343ca5db0',
  '66469bc3-dde9-476f-a94c-3840e6d75e1f',
  '5c98aae0-f93c-4ba6-a274-321cc33ff038',
  'f7f0fe10-72a5-4c63-bb13-815830a8324e',
  '9197a987-c85c-4aed-b03d-c066558860d5',
  '0bbea0fc-795c-4fc9-b6ae-e285ab4ea882',
  '7765600f-e34f-48a3-be74-f0f71c84e5c3',
  'ecf74bb0-2cd8-48bf-a4da-099ff9b318c5',
  '8ad6fe65-451a-48a6-beb9-100fb8d74fdd',
  'ad9ba68a-efd5-44b9-848c-bb08a71c95fa',
  'b9dfbbc7-8837-47f1-875f-ab2b328744de',
  '1824af13-efb1-4a17-85e7-8428e94c42dd',
  '86ce8702-6463-4ded-a003-0aefe1ee5276',
  '4872b579-51ff-40d8-ae9b-9ca781e1fe7c',
  '391441c6-9bde-44dd-88fc-d5b2789bade7',
  '5e0e4c27-79bf-4d07-91da-e194db03f706',
  '7c687564-cce6-49c3-87ef-6b841635a394',
  '6458bd86-c78b-4484-b43c-77ec607b99f7',
  '811f9330-0dca-4f78-a35d-126e6714ec46',
  '72ccce50-1524-44ac-89a0-7ce28515905e',
  '3affeafa-8757-4a25-bba5-282ba82d636e',
  '66100322-5c3d-40f2-a5e1-8d61b87e9560',
  '658c746c-caa4-4059-aa44-7886148104ab',
  '6454af63-f292-46c4-ad51-bccd320f826c',
  'dfe45eef-a1db-4382-ba62-2340fc719549',
  '6e1431bb-03c8-4004-adb5-753984230e08',
  '37dba5c3-2f25-486a-aa3f-bfe27f59bae3',
  '08f68a87-34fd-44b0-bfc8-8721860c75c4',
  '0b3a5229-a440-4f90-8532-8e632e7ad0d7',
  '19d5119e-fa9f-4a14-bd49-a362b46cf6fc',
  '8dc9fb06-b47c-455a-a652-48a13d7cea74',
  '2bac4fd2-7f1f-43d6-bfbb-1e1f4e9ab804',
  'd9ff1c5d-b4f7-4bcc-aa5a-a0200ae50174',
  '521eaa8e-d30d-40e6-8808-cf782306d721',
  '86d18aaf-e7e9-4640-9a9e-f6869aa6b8dd',
  '50a10946-453b-4d05-b43d-625f10a8ef81',
  'e892145b-ad39-4e2a-88aa-56908f2735dc',
  '4e91f8d3-5ef3-45fd-9142-6c734185fef5',
  '4d2da16c-3038-4348-8528-5311779f3720',
  'dc3a1698-e0b2-4250-a681-7ed39683a6d2',
  '0996a77c-b796-4afa-aeb5-52609afd6c3e',
  '2170ffd1-96ab-427a-8fbb-816d3fde6c4c',
  '91dbdf98-d423-48df-b2e0-4b45aa59ecd0',
  '540dc2e0-90c0-4b24-9291-9ef8d4a80b68',
  '685f3e56-6c34-4b24-8aef-bbd9adff3695',
  '024b5981-b4e4-48a7-bd97-4e58919f69e2',
  '641f62c2-d3f2-4046-9016-ead417aebc0a',
  '5f818988-e63a-428e-963e-0b9c06386425',
  '6f01c97d-10bc-4b21-91d6-c203cdea96cd',
  'da022de3-f823-4db7-a481-db0a57b47bd7',
  'b8063108-7ed3-4793-b419-e3d9f8e16981',
  '55c0675b-2006-4cc6-bc29-ed02e7929caa',
  'b893c229-d904-4a89-b762-34e7ca29a6a2',
  '2d5c4f75-2c84-445e-bc70-67463db77da0',
  'cd1f2311-9e09-468c-9a7b-195c935936b8',
  'ef1c90f4-63cf-4d5b-97ea-33f33ecf2815',
  '766e40c6-8e71-441e-848d-19552e82c16b',
  'e3ca8ba6-0b66-4e62-8717-8996fe23ac90',
  '3dd429b6-a0fb-4bee-98b2-5868c235a234',
  '1b097c5a-61d0-4597-8a58-7834112d1940',
  'bc0b334c-d966-4670-9c49-7082b1e7d374',
  '405b2e32-9d5c-4d79-865a-12d01bfae945',
  '44707424-8440-490b-9680-726388d7a24c',
  '985de794-44ac-4cb0-9d3d-a422c08b1b68',
  'a3707c6d-80fb-4e1a-8652-0f64d9558f5c',
  '5a887413-4745-4062-9f04-072dad014caf',
  '27a89be6-5a86-4b21-8890-5c8e5ce3eb23',
  '3510e05c-4c00-4c0f-923e-eb68721ec7d9',
  '0e98f6a5-5759-41da-bf54-63e87a990553',
  '7b051100-e36f-45ff-8da8-d1fb4f0fcc0e',
  '932ae309-3e7c-44f3-83e5-247e5014bbb1',
  '53460a85-8fac-4b68-9909-f819f5ea6002',
  '2100819a-d60c-4f96-a727-ecb730c4fda0',
  '1277719f-db02-42bd-ab7a-3fb4e5728fe7',
  'a744134e-49d3-462e-82e4-983f896de912',
  'ab00e6fe-c235-4db5-a956-edb8ce075d18',
  '8678b13f-347b-4bec-b345-790ca04df24a',
  '8c138fd8-1284-4955-8c92-7df5403d12b0',
  '8272c108-bf5d-49ac-880e-59154e969e7b',
  '2ecfb442-fb59-420c-b4b0-6967d44a54d5',
  '017947f8-d7f5-4c05-bee9-a8daf1590bd2',
  'cfc9b1da-67d8-43ae-8cb7-cf47a0a9e665',
  'c79df7d1-f1ac-48d4-986b-74e86c6a224e',
  '1ef99a79-b79d-47f3-88dd-147e7f5ff8f0',
  '151ba4b7-440e-488d-a995-abd3090ec044',
  '43af53e5-72f6-421e-9072-bcb88490e22a',
  '2ff400b2-317e-4654-abd9-b30b59e43fec',
  'ae9c3cc9-bc73-4b92-8423-56a7e760fe76',
  'f90de740-cd9f-43b5-89c4-e15eb2917a0c',
  'fb04bb6e-8db5-4fee-a3f8-16b3dffc9306',
  '5dbb0fd2-8dec-4a3a-8e46-ac1537b0c78d',
  '4a02905b-369e-47eb-9cba-d4f49530074f',
  '686b5a5f-5b98-4823-9f82-b948e71daa3b',
  '733ead2b-e3d4-46fc-8425-c70f4660a1ae',
  'c43dff93-e69e-4262-a4e2-925161d2f3cd',
  '594d054c-d41e-4803-8a4d-e19c6d38139d',
  '85e5e0cf-d889-4121-91cc-3de338c14107',
  'd791e092-dc52-426d-9ddc-36f068cea583',
  '1b6e8262-28f6-4f1b-aafb-e6f5db23a89d',
  'a0f69644-698e-4d43-a82a-dbe3175d1d31',
  '53411947-82fe-4a08-a29f-0cb941f19b83',
  'd32d7065-4d5b-48bf-b4ce-a4031c90175b',
  'c4614256-ca97-44dd-9301-faf753690b62',
  '55f3d551-eb12-46ae-b748-98d8d92a4692',
  '07040e2b-d5cb-4b30-9137-979c5436c828',
  'd6f6a98f-daf4-42fe-8ea3-05b21cb8f075',
  'c6462c3e-edf3-48b1-81fa-4b636cd760a1',
  '722dbd82-3a89-4fb0-a3c2-ef87b4f65250',
  'fb6f5466-59ad-4150-81e1-2dcd79c9a4a4',
  'ded83f31-1ebd-4cfc-8d06-3952e897cdd0',
  'fd5e7770-591a-41eb-9e15-240efa92333d',
  '8b2ae538-5663-4408-8ec9-36cff17de62e',
  '16cf9357-341a-4aa5-bb1f-2e35512bb94b',
  '2e17107b-04b0-40e1-89a0-89ebde4466aa',
  'cd88c6db-f494-4fba-90a4-54642eafdde0',
  'a24e069b-d140-4b44-966e-1cfc9a9173cc',
  '9e848c20-fe61-442f-ab86-fd5f0caeba87',
  '26263253-478f-4089-8922-863d3d84fc4f',
  'b5eaed1b-3f30-4b05-adf8-99238dab5da7',
  'be99820f-3828-49ca-9014-ffd279a733d2',
  '96c7bcb6-3cfb-452d-bc17-90646d1ad987',
  '3f8f1599-b97b-4435-9238-198135c47e01',
  '0ef8ce84-38e0-48a8-8a6b-527ffdbfea54',
  'adb22ebe-b222-4bc1-a83d-98d1bd18930c',
  'ddc299fc-b5f1-40e5-9325-94b7c7abf955',
  '6d883bcb-c7e5-4b61-9da8-e8d7f188ba5f',
  '621f9c24-840b-477c-ba5c-a584d254aae6',
  'c7d42e66-6608-4b98-9806-e943ccb82fbe',
  '53818ca4-7db1-4f7a-83ac-4562cd1960cc',
  '3f59a5b1-07ef-4787-81a0-b2a726d5f3de',
  '2334393f-09de-44c8-af00-4741e2e4dce2',
  '79e1d61d-37b0-4f3d-92f1-ea1f0e054132',
  '4d75e282-547f-4387-98f8-eb4c930a83db',
  'd6e76e3b-7e8d-4607-8e2e-606bc4b4285e',
  'b0a731d2-c8a0-49f7-aefc-806307a5f66e',
  'b4f9f4cb-d7ee-4f66-bfe6-b111f4a49f8d',
  '65b51edf-2398-4309-96d2-e8c433f3d130',
  '425795cb-b6dc-4099-9805-39c737d7cdaf',
  '77209969-6016-40d0-b2ff-5663a8e84471',
  '06b2837a-84e5-4729-9205-2364c45799f0',
  'f6a31e11-a942-4f96-a535-a74c13a227d9',
  '634bb984-a03f-4548-bb41-52151017b3a5'
 )
 order by p.nome;

-- Esperado: 153 linhas.


-- ===== PASSO 2 - APLICAR (selecione do begin ao commit) =====

begin;

-- 2a) fichas
update est_fichas_tecnicas set custo_total = 20.4429, custo_por_porcao = 20.4429 where id = '2163d212-84c3-41b7-9fbd-26761c3f08ad';
update est_fichas_tecnicas set custo_total = 32.7127, custo_por_porcao = 32.7127 where id = 'de49ab3d-fab9-491e-ac7c-64af14f317f5';
update est_fichas_tecnicas set custo_total = 19.0165, custo_por_porcao = 19.0165 where id = 'ed787dfa-512b-4075-baa7-4d7d5d19ba8a';
update est_fichas_tecnicas set custo_total = 20.7489, custo_por_porcao = 46.1087 where id = '2f06e66e-2113-4b44-a4e4-861935c814a3';
update est_fichas_tecnicas set custo_total = 92.4313, custo_por_porcao = 92.4313 where id = '597d2cd3-9e89-483a-826c-f6b490092cd1';
update est_fichas_tecnicas set custo_total = 10.7435, custo_por_porcao = 10.7435 where id = '46ddbe86-bf93-43c4-a5d6-2062667fb109';
update est_fichas_tecnicas set custo_total = 9.6538, custo_por_porcao = 9.6538 where id = '83350b6e-0aa8-4807-b898-676f00ade136';
update est_fichas_tecnicas set custo_total = 1.249, custo_por_porcao = 12.49 where id = '91848eb5-f679-497e-bcbc-2ddc3a13677b';
update est_fichas_tecnicas set custo_total = 8.785, custo_por_porcao = 8.785 where id = '8556bfbe-25d6-4250-927b-2ee37eaeb486';
update est_fichas_tecnicas set custo_total = 11.1679, custo_por_porcao = 11.1679 where id = 'bb697ec1-c6dc-469f-8c9b-f8f10308f1c7';
update est_fichas_tecnicas set custo_total = 9.6838, custo_por_porcao = 9.6838 where id = 'aa34600e-7e8f-4197-b687-2ede7fa5ec2b';
update est_fichas_tecnicas set custo_total = 51.379, custo_por_porcao = 51.379 where id = '4036c2f2-06ca-4e9f-8548-b3d343ca5db0';
update est_fichas_tecnicas set custo_total = 19.3643, custo_por_porcao = 19.3643 where id = '66469bc3-dde9-476f-a94c-3840e6d75e1f';
update est_fichas_tecnicas set custo_total = 27.443, custo_por_porcao = 27.443 where id = '5c98aae0-f93c-4ba6-a274-321cc33ff038';
update est_fichas_tecnicas set custo_total = 10.8393, custo_por_porcao = 10.8393 where id = 'f7f0fe10-72a5-4c63-bb13-815830a8324e';
update est_fichas_tecnicas set custo_total = 12.4432, custo_por_porcao = 12.4432 where id = '9197a987-c85c-4aed-b03d-c066558860d5';
update est_fichas_tecnicas set custo_total = 13.363, custo_por_porcao = 13.363 where id = '0bbea0fc-795c-4fc9-b6ae-e285ab4ea882';
update est_fichas_tecnicas set custo_total = 21.1264, custo_por_porcao = 21.1264 where id = '7765600f-e34f-48a3-be74-f0f71c84e5c3';
update est_fichas_tecnicas set custo_total = 13.5279, custo_por_porcao = 13.5279 where id = 'ecf74bb0-2cd8-48bf-a4da-099ff9b318c5';
update est_fichas_tecnicas set custo_total = 6.4316, custo_por_porcao = 6.4316 where id = '8ad6fe65-451a-48a6-beb9-100fb8d74fdd';
update est_fichas_tecnicas set custo_total = 40.4833, custo_por_porcao = 40.4833 where id = 'ad9ba68a-efd5-44b9-848c-bb08a71c95fa';
update est_fichas_tecnicas set custo_total = 33.7459, custo_por_porcao = 33.7459 where id = 'b9dfbbc7-8837-47f1-875f-ab2b328744de';
update est_fichas_tecnicas set custo_total = 56.4203, custo_por_porcao = 56.4203 where id = '1824af13-efb1-4a17-85e7-8428e94c42dd';
update est_fichas_tecnicas set custo_total = 44.083, custo_por_porcao = 44.083 where id = '86ce8702-6463-4ded-a003-0aefe1ee5276';
update est_fichas_tecnicas set custo_total = 20.7597, custo_por_porcao = 41.5194 where id = '4872b579-51ff-40d8-ae9b-9ca781e1fe7c';
update est_fichas_tecnicas set custo_total = 4.5591, custo_por_porcao = 4.5591 where id = '391441c6-9bde-44dd-88fc-d5b2789bade7';
update est_fichas_tecnicas set custo_total = 52.0296, custo_por_porcao = 104.0592 where id = '5e0e4c27-79bf-4d07-91da-e194db03f706';
update est_fichas_tecnicas set custo_total = 8.5495, custo_por_porcao = 8.5495 where id = '7c687564-cce6-49c3-87ef-6b841635a394';
update est_fichas_tecnicas set custo_total = 6.2571, custo_por_porcao = 6.2571 where id = '6458bd86-c78b-4484-b43c-77ec607b99f7';
update est_fichas_tecnicas set custo_total = 17.49, custo_por_porcao = 34.98 where id = '811f9330-0dca-4f78-a35d-126e6714ec46';
update est_fichas_tecnicas set custo_total = 11.1322, custo_por_porcao = 11.1322 where id = '72ccce50-1524-44ac-89a0-7ce28515905e';
update est_fichas_tecnicas set custo_total = 20.9626, custo_por_porcao = 20.9626 where id = '3affeafa-8757-4a25-bba5-282ba82d636e';
update est_fichas_tecnicas set custo_total = 25.3807, custo_por_porcao = 25.3807 where id = '66100322-5c3d-40f2-a5e1-8d61b87e9560';
update est_fichas_tecnicas set custo_total = 9.4169, custo_por_porcao = 9.4169 where id = '658c746c-caa4-4059-aa44-7886148104ab';
update est_fichas_tecnicas set custo_total = 24.4485, custo_por_porcao = 27.165 where id = '6454af63-f292-46c4-ad51-bccd320f826c';
update est_fichas_tecnicas set custo_total = 16.5291, custo_por_porcao = 16.5291 where id = 'dfe45eef-a1db-4382-ba62-2340fc719549';
update est_fichas_tecnicas set custo_total = 5.0647, custo_por_porcao = 5.0647 where id = '6e1431bb-03c8-4004-adb5-753984230e08';
update est_fichas_tecnicas set custo_total = 3.8589, custo_por_porcao = 3.8589 where id = '37dba5c3-2f25-486a-aa3f-bfe27f59bae3';
update est_fichas_tecnicas set custo_total = 273.2576, custo_por_porcao = 273.2576 where id = '08f68a87-34fd-44b0-bfc8-8721860c75c4';
update est_fichas_tecnicas set custo_total = 12.1441, custo_por_porcao = 12.1441 where id = '0b3a5229-a440-4f90-8532-8e632e7ad0d7';
update est_fichas_tecnicas set custo_total = 11.0931, custo_por_porcao = 11.0931 where id = '19d5119e-fa9f-4a14-bd49-a362b46cf6fc';
update est_fichas_tecnicas set custo_total = 6.5364, custo_por_porcao = 6.5364 where id = '8dc9fb06-b47c-455a-a652-48a13d7cea74';
update est_fichas_tecnicas set custo_total = 8.8571, custo_por_porcao = 8.8571 where id = '2bac4fd2-7f1f-43d6-bfbb-1e1f4e9ab804';
update est_fichas_tecnicas set custo_total = 5.3998, custo_por_porcao = 5.3998 where id = 'd9ff1c5d-b4f7-4bcc-aa5a-a0200ae50174';
update est_fichas_tecnicas set custo_total = 4.3381, custo_por_porcao = 4.3381 where id = '521eaa8e-d30d-40e6-8808-cf782306d721';
update est_fichas_tecnicas set custo_total = 26.0874, custo_por_porcao = 26.0874 where id = '86d18aaf-e7e9-4640-9a9e-f6869aa6b8dd';
update est_fichas_tecnicas set custo_total = 3.7897, custo_por_porcao = 3.7897 where id = '50a10946-453b-4d05-b43d-625f10a8ef81';
update est_fichas_tecnicas set custo_total = 70.4562, custo_por_porcao = 70.4562 where id = 'e892145b-ad39-4e2a-88aa-56908f2735dc';
update est_fichas_tecnicas set custo_total = 6.0631, custo_por_porcao = 6.0631 where id = '4e91f8d3-5ef3-45fd-9142-6c734185fef5';
update est_fichas_tecnicas set custo_total = 3.7228, custo_por_porcao = 3.7228 where id = '4d2da16c-3038-4348-8528-5311779f3720';
update est_fichas_tecnicas set custo_total = 30.0159, custo_por_porcao = 30.0159 where id = 'dc3a1698-e0b2-4250-a681-7ed39683a6d2';
update est_fichas_tecnicas set custo_total = 3.0631, custo_por_porcao = 3.0631 where id = '0996a77c-b796-4afa-aeb5-52609afd6c3e';
update est_fichas_tecnicas set custo_total = 37.7723, custo_por_porcao = 37.7723 where id = '2170ffd1-96ab-427a-8fbb-816d3fde6c4c';
update est_fichas_tecnicas set custo_total = 22.3789, custo_por_porcao = 22.3789 where id = '91dbdf98-d423-48df-b2e0-4b45aa59ecd0';
update est_fichas_tecnicas set custo_total = 26.8222, custo_por_porcao = 26.8222 where id = '540dc2e0-90c0-4b24-9291-9ef8d4a80b68';
update est_fichas_tecnicas set custo_total = 12.3707, custo_por_porcao = 12.3707 where id = '685f3e56-6c34-4b24-8aef-bbd9adff3695';
update est_fichas_tecnicas set custo_total = 6.9927, custo_por_porcao = 6.9927 where id = '024b5981-b4e4-48a7-bd97-4e58919f69e2';
update est_fichas_tecnicas set custo_total = 6.2681, custo_por_porcao = 6.2681 where id = '641f62c2-d3f2-4046-9016-ead417aebc0a';
update est_fichas_tecnicas set custo_total = 7.2498, custo_por_porcao = 7.2498 where id = '5f818988-e63a-428e-963e-0b9c06386425';
update est_fichas_tecnicas set custo_total = 4.3816, custo_por_porcao = 4.3816 where id = '6f01c97d-10bc-4b21-91d6-c203cdea96cd';
update est_fichas_tecnicas set custo_total = 7.3422, custo_por_porcao = 7.3422 where id = 'da022de3-f823-4db7-a481-db0a57b47bd7';
update est_fichas_tecnicas set custo_total = 20.4429, custo_por_porcao = 20.4429 where id = 'b8063108-7ed3-4793-b419-e3d9f8e16981';
update est_fichas_tecnicas set custo_total = 4.9304, custo_por_porcao = 4.9304 where id = '55c0675b-2006-4cc6-bc29-ed02e7929caa';
update est_fichas_tecnicas set custo_total = 5.4248, custo_por_porcao = 5.4248 where id = 'b893c229-d904-4a89-b762-34e7ca29a6a2';
update est_fichas_tecnicas set custo_total = 24.1055, custo_por_porcao = 24.1055 where id = '2d5c4f75-2c84-445e-bc70-67463db77da0';
update est_fichas_tecnicas set custo_total = 8.9831, custo_por_porcao = 8.9831 where id = 'cd1f2311-9e09-468c-9a7b-195c935936b8';
update est_fichas_tecnicas set custo_total = 8.8779, custo_por_porcao = 8.8779 where id = 'ef1c90f4-63cf-4d5b-97ea-33f33ecf2815';
update est_fichas_tecnicas set custo_total = 7.4039, custo_por_porcao = 7.4039 where id = '766e40c6-8e71-441e-848d-19552e82c16b';
update est_fichas_tecnicas set custo_total = 75.8869, custo_por_porcao = 75.8869 where id = 'e3ca8ba6-0b66-4e62-8717-8996fe23ac90';
update est_fichas_tecnicas set custo_total = 8.6794, custo_por_porcao = 8.6794 where id = '3dd429b6-a0fb-4bee-98b2-5868c235a234';
update est_fichas_tecnicas set custo_total = 8.6903, custo_por_porcao = 8.6903 where id = '1b097c5a-61d0-4597-8a58-7834112d1940';
update est_fichas_tecnicas set custo_total = 6.1288, custo_por_porcao = 6.1288 where id = 'bc0b334c-d966-4670-9c49-7082b1e7d374';
update est_fichas_tecnicas set custo_total = 9.9763, custo_por_porcao = 9.9763 where id = '405b2e32-9d5c-4d79-865a-12d01bfae945';
update est_fichas_tecnicas set custo_total = 7.299, custo_por_porcao = 7.299 where id = '44707424-8440-490b-9680-726388d7a24c';
update est_fichas_tecnicas set custo_total = 7.0503, custo_por_porcao = 7.0503 where id = '985de794-44ac-4cb0-9d3d-a422c08b1b68';
update est_fichas_tecnicas set custo_total = 9.4257, custo_por_porcao = 9.4257 where id = 'a3707c6d-80fb-4e1a-8652-0f64d9558f5c';
update est_fichas_tecnicas set custo_total = 12.5065, custo_por_porcao = 12.5065 where id = '5a887413-4745-4062-9f04-072dad014caf';
update est_fichas_tecnicas set custo_total = 13.9267, custo_por_porcao = 13.9267 where id = '27a89be6-5a86-4b21-8890-5c8e5ce3eb23';
update est_fichas_tecnicas set custo_total = 39.9836, custo_por_porcao = 39.9836 where id = '3510e05c-4c00-4c0f-923e-eb68721ec7d9';
update est_fichas_tecnicas set custo_total = 5.4248, custo_por_porcao = 5.4248 where id = '0e98f6a5-5759-41da-bf54-63e87a990553';
update est_fichas_tecnicas set custo_total = 7.5274, custo_por_porcao = 7.5274 where id = '7b051100-e36f-45ff-8da8-d1fb4f0fcc0e';
update est_fichas_tecnicas set custo_total = 10.9964, custo_por_porcao = 10.9964 where id = '932ae309-3e7c-44f3-83e5-247e5014bbb1';
update est_fichas_tecnicas set custo_total = 14.9016, custo_por_porcao = 14.9016 where id = '53460a85-8fac-4b68-9909-f819f5ea6002';
update est_fichas_tecnicas set custo_total = 3.7637, custo_por_porcao = 3.7637 where id = '2100819a-d60c-4f96-a727-ecb730c4fda0';
update est_fichas_tecnicas set custo_total = 14.0101, custo_por_porcao = 14.0101 where id = '1277719f-db02-42bd-ab7a-3fb4e5728fe7';
update est_fichas_tecnicas set custo_total = 16.7791, custo_por_porcao = 16.7791 where id = 'a744134e-49d3-462e-82e4-983f896de912';
update est_fichas_tecnicas set custo_total = 5.4248, custo_por_porcao = 5.4248 where id = 'ab00e6fe-c235-4db5-a956-edb8ce075d18';
update est_fichas_tecnicas set custo_total = 0.9062, custo_por_porcao = 0.9062 where id = '8678b13f-347b-4bec-b345-790ca04df24a';
update est_fichas_tecnicas set custo_total = 0.6289, custo_por_porcao = 0.6289 where id = '8c138fd8-1284-4955-8c92-7df5403d12b0';
update est_fichas_tecnicas set custo_total = 9.7174, custo_por_porcao = 9.7174 where id = '8272c108-bf5d-49ac-880e-59154e969e7b';
update est_fichas_tecnicas set custo_total = 10.8393, custo_por_porcao = 10.8393 where id = '2ecfb442-fb59-420c-b4b0-6967d44a54d5';
update est_fichas_tecnicas set custo_total = 30.7897, custo_por_porcao = 30.7897 where id = '017947f8-d7f5-4c05-bee9-a8daf1590bd2';
update est_fichas_tecnicas set custo_total = 5.072, custo_por_porcao = 5.072 where id = 'cfc9b1da-67d8-43ae-8cb7-cf47a0a9e665';
update est_fichas_tecnicas set custo_total = 11.221, custo_por_porcao = 11.221 where id = 'c79df7d1-f1ac-48d4-986b-74e86c6a224e';
update est_fichas_tecnicas set custo_total = 11.156, custo_por_porcao = 11.156 where id = '1ef99a79-b79d-47f3-88dd-147e7f5ff8f0';
update est_fichas_tecnicas set custo_total = 149.6032, custo_por_porcao = 149.6032 where id = '151ba4b7-440e-488d-a995-abd3090ec044';
update est_fichas_tecnicas set custo_total = 18.2179, custo_por_porcao = 18.2179 where id = '43af53e5-72f6-421e-9072-bcb88490e22a';
update est_fichas_tecnicas set custo_total = 11.8904, custo_por_porcao = 11.8904 where id = '2ff400b2-317e-4654-abd9-b30b59e43fec';
update est_fichas_tecnicas set custo_total = 95.8428, custo_por_porcao = 95.8428 where id = 'ae9c3cc9-bc73-4b92-8423-56a7e760fe76';
update est_fichas_tecnicas set custo_total = 12.3303, custo_por_porcao = 12.3303 where id = 'f90de740-cd9f-43b5-89c4-e15eb2917a0c';
update est_fichas_tecnicas set custo_total = 154.5371, custo_por_porcao = 154.5371 where id = 'fb04bb6e-8db5-4fee-a3f8-16b3dffc9306';
update est_fichas_tecnicas set custo_total = 11.542, custo_por_porcao = 11.542 where id = '5dbb0fd2-8dec-4a3a-8e46-ac1537b0c78d';
update est_fichas_tecnicas set custo_total = 19.5631, custo_por_porcao = 19.5631 where id = '4a02905b-369e-47eb-9cba-d4f49530074f';
update est_fichas_tecnicas set custo_total = 219.9985, custo_por_porcao = 219.9985 where id = '686b5a5f-5b98-4823-9f82-b948e71daa3b';
update est_fichas_tecnicas set custo_total = 11.1094, custo_por_porcao = 11.1094 where id = '733ead2b-e3d4-46fc-8425-c70f4660a1ae';
update est_fichas_tecnicas set custo_total = 5.4248, custo_por_porcao = 5.4248 where id = 'c43dff93-e69e-4262-a4e2-925161d2f3cd';
update est_fichas_tecnicas set custo_total = 126.2575, custo_por_porcao = 126.2575 where id = '594d054c-d41e-4803-8a4d-e19c6d38139d';
update est_fichas_tecnicas set custo_total = 3.7637, custo_por_porcao = 3.7637 where id = '85e5e0cf-d889-4121-91cc-3de338c14107';
update est_fichas_tecnicas set custo_total = 10.7217, custo_por_porcao = 10.7217 where id = 'd791e092-dc52-426d-9ddc-36f068cea583';
update est_fichas_tecnicas set custo_total = 3.4905, custo_por_porcao = 3.4905 where id = '1b6e8262-28f6-4f1b-aafb-e6f5db23a89d';
update est_fichas_tecnicas set custo_total = 69.3028, custo_por_porcao = 8.1533 where id = 'a0f69644-698e-4d43-a82a-dbe3175d1d31';
update est_fichas_tecnicas set custo_total = 33.1896, custo_por_porcao = 33.1896 where id = '53411947-82fe-4a08-a29f-0cb941f19b83';
update est_fichas_tecnicas set custo_total = 12.8379, custo_por_porcao = 12.8379 where id = 'd32d7065-4d5b-48bf-b4ce-a4031c90175b';
update est_fichas_tecnicas set custo_total = 14.7793, custo_por_porcao = 14.7793 where id = 'c4614256-ca97-44dd-9301-faf753690b62';
update est_fichas_tecnicas set custo_total = 6.7696, custo_por_porcao = 6.7696 where id = '55f3d551-eb12-46ae-b748-98d8d92a4692';
update est_fichas_tecnicas set custo_total = 11.8904, custo_por_porcao = 11.8904 where id = '07040e2b-d5cb-4b30-9137-979c5436c828';
update est_fichas_tecnicas set custo_total = 13.368, custo_por_porcao = 13.368 where id = 'd6f6a98f-daf4-42fe-8ea3-05b21cb8f075';
update est_fichas_tecnicas set custo_total = 1.599, custo_por_porcao = 1.599 where id = 'c6462c3e-edf3-48b1-81fa-4b636cd760a1';
update est_fichas_tecnicas set custo_total = 28.5699, custo_por_porcao = 28.5699 where id = '722dbd82-3a89-4fb0-a3c2-ef87b4f65250';
update est_fichas_tecnicas set custo_total = 58.995, custo_por_porcao = 29.4975 where id = 'fb6f5466-59ad-4150-81e1-2dcd79c9a4a4';
update est_fichas_tecnicas set custo_total = 5.3862, custo_por_porcao = 5.3862 where id = 'ded83f31-1ebd-4cfc-8d06-3952e897cdd0';
update est_fichas_tecnicas set custo_total = 33.3461, custo_por_porcao = 33.3461 where id = 'fd5e7770-591a-41eb-9e15-240efa92333d';
update est_fichas_tecnicas set custo_total = 6.981, custo_por_porcao = 6.981 where id = '8b2ae538-5663-4408-8ec9-36cff17de62e';
update est_fichas_tecnicas set custo_total = 5.072, custo_por_porcao = 5.072 where id = '16cf9357-341a-4aa5-bb1f-2e35512bb94b';
update est_fichas_tecnicas set custo_total = 9.0, custo_por_porcao = 9.0 where id = '2e17107b-04b0-40e1-89a0-89ebde4466aa';
update est_fichas_tecnicas set custo_total = 35.0959, custo_por_porcao = 35.0959 where id = 'cd88c6db-f494-4fba-90a4-54642eafdde0';
update est_fichas_tecnicas set custo_total = 33.0599, custo_por_porcao = 33.0599 where id = 'a24e069b-d140-4b44-966e-1cfc9a9173cc';
update est_fichas_tecnicas set custo_total = 32.7127, custo_por_porcao = 32.7127 where id = '9e848c20-fe61-442f-ab86-fd5f0caeba87';
update est_fichas_tecnicas set custo_total = 5.8279, custo_por_porcao = 5.8279 where id = '26263253-478f-4089-8922-863d3d84fc4f';
update est_fichas_tecnicas set custo_total = 6.2571, custo_por_porcao = 6.2571 where id = 'b5eaed1b-3f30-4b05-adf8-99238dab5da7';
update est_fichas_tecnicas set custo_total = 13.6871, custo_por_porcao = 13.6871 where id = 'be99820f-3828-49ca-9014-ffd279a733d2';
update est_fichas_tecnicas set custo_total = 24.1341, custo_por_porcao = 24.1341 where id = '96c7bcb6-3cfb-452d-bc17-90646d1ad987';
update est_fichas_tecnicas set custo_total = 18.281, custo_por_porcao = 18.281 where id = '3f8f1599-b97b-4435-9238-198135c47e01';
update est_fichas_tecnicas set custo_total = 14.7231, custo_por_porcao = 14.7231 where id = '0ef8ce84-38e0-48a8-8a6b-527ffdbfea54';
update est_fichas_tecnicas set custo_total = 29.3218, custo_por_porcao = 29.3218 where id = 'adb22ebe-b222-4bc1-a83d-98d1bd18930c';
update est_fichas_tecnicas set custo_total = 3.5995, custo_por_porcao = 3.5995 where id = 'ddc299fc-b5f1-40e5-9325-94b7c7abf955';
update est_fichas_tecnicas set custo_total = 33.4644, custo_por_porcao = 33.4644 where id = '6d883bcb-c7e5-4b61-9da8-e8d7f188ba5f';
update est_fichas_tecnicas set custo_total = 4.8033, custo_por_porcao = 4.8033 where id = '621f9c24-840b-477c-ba5c-a584d254aae6';
update est_fichas_tecnicas set custo_total = 32.7127, custo_por_porcao = 32.7127 where id = 'c7d42e66-6608-4b98-9806-e943ccb82fbe';
update est_fichas_tecnicas set custo_total = 14.4968, custo_por_porcao = 14.4968 where id = '53818ca4-7db1-4f7a-83ac-4562cd1960cc';
update est_fichas_tecnicas set custo_total = 3.4905, custo_por_porcao = 3.4905 where id = '3f59a5b1-07ef-4787-81a0-b2a726d5f3de';
update est_fichas_tecnicas set custo_total = 4.645, custo_por_porcao = 4.645 where id = '2334393f-09de-44c8-af00-4741e2e4dce2';
update est_fichas_tecnicas set custo_total = 30.4936, custo_por_porcao = 30.4936 where id = '79e1d61d-37b0-4f3d-92f1-ea1f0e054132';
update est_fichas_tecnicas set custo_total = 6.9178, custo_por_porcao = 6.9178 where id = '4d75e282-547f-4387-98f8-eb4c930a83db';
update est_fichas_tecnicas set custo_total = 3.2564, custo_por_porcao = 3.2564 where id = 'd6e76e3b-7e8d-4607-8e2e-606bc4b4285e';
update est_fichas_tecnicas set custo_total = 29.6651, custo_por_porcao = 29.6651 where id = 'b0a731d2-c8a0-49f7-aefc-806307a5f66e';
update est_fichas_tecnicas set custo_total = 21.8279, custo_por_porcao = 21.8279 where id = 'b4f9f4cb-d7ee-4f66-bfe6-b111f4a49f8d';
update est_fichas_tecnicas set custo_total = 33.6719, custo_por_porcao = 33.6719 where id = '65b51edf-2398-4309-96d2-e8c433f3d130';
update est_fichas_tecnicas set custo_total = 5.3862, custo_por_porcao = 5.3862 where id = '425795cb-b6dc-4099-9805-39c737d7cdaf';
update est_fichas_tecnicas set custo_total = 28.1772, custo_por_porcao = 28.1772 where id = '77209969-6016-40d0-b2ff-5663a8e84471';
update est_fichas_tecnicas set custo_total = 5.3862, custo_por_porcao = 5.3862 where id = '06b2837a-84e5-4729-9205-2364c45799f0';
update est_fichas_tecnicas set custo_total = 1.4666, custo_por_porcao = 1.4666 where id = 'f6a31e11-a942-4f96-a535-a74c13a227d9';
update est_fichas_tecnicas set custo_total = 3.1495, custo_por_porcao = 3.1495 where id = '634bb984-a03f-4548-bb41-52151017b3a5';

-- 2b) custo_comp dos produtos que essas fichas produzem
update est_produtos set custo_comp = 24.1055 where id = '2bd7358b-fbeb-4eee-86c3-9d8eda6a4226';  -- (DRINK) TRIUNFO DO POVO - TANQUERAY
update est_produtos set custo_comp = 20.9626 where id = 'c770fa15-b00c-4f3c-87ea-b303a0f1d0a0';  -- (DRINK) TRIUNFO DO POVO - EURIDICY
update est_produtos set custo_comp = 9.9763 where id = '650477f5-671b-4c89-8e15-79f995bad490';  -- CHOPP AZULOU SUJO 500ML
update est_produtos set custo_comp = 7.0503 where id = 'ffe6e365-bdc9-458d-b560-954e0b1387fd';  -- CHOPP AZULOU SUJO 300ML
update est_produtos set custo_comp = 11.0931 where id = '5cb50514-b325-4174-8b1f-3c279dabdf97';  -- (DRINK) FESTEJO VERMELHO
update est_produtos set custo_comp = 4.3381 where id = '569fb75f-fe51-4c5e-ae1a-16a9c0f6a907';  -- (DRINK) CAIPIRINHA CAPRICHOSA - TRADICIONAL
update est_produtos set custo_comp = 26.8222 where id = '32ec7148-97a1-46a3-9a5c-e68a1f0a50fa';  -- (DRINK) TOADA AMAZONICA
update est_produtos set custo_comp = 6.5364 where id = '9ff7e9c5-f5d6-4ccf-90d4-ef9437fd4aac';  -- (DRINK) FESTEJO VERMELHO NAO ALCOOLICO
update est_produtos set custo_comp = 25.3807 where id = '927ca850-4bb8-4159-9ad3-5d73696e8c41';  -- (DRINK) TOADA AMAZONICA NAO ALCOOLICO
update est_produtos set custo_comp = 3.0631 where id = '05d30c04-06b5-4748-8743-ad952ab5783c';  -- (DRINK) CAIPIRINHA GARANTIDA - TRADICIONAL
update est_produtos set custo_comp = 30.0159 where id = '89d08432-a0d4-4fb0-b4e4-c81f356ab49f';  -- (DRINK) ISA A BELA GUERREIRA - TANQUERAY
update est_produtos set custo_comp = 33.4644 where id = 'e1e52f96-8adf-4263-afb6-3fc7a9c79710';  -- TAMBAQUI DE BANDA GUIA
update est_produtos set custo_comp = 4.3816 where id = 'fa44f094-1277-4f4c-88f2-9e872ee15b54';  -- CAIPIFRUTA VODKA NACIONAL MORANGO
update est_produtos set custo_comp = 9.4257 where id = '41338c00-4201-4456-9acf-455f6b0c97e5';  -- CHOPP VERMELHOU SUJO 300ML
update est_produtos set custo_comp = 4.9304 where id = 'dba0f0b3-d220-4ca4-be38-fb1846cb9d4c';  -- CAIPIRU CACHACA DE JAMBU
update est_produtos set custo_comp = 6.9927 where id = '5d10bac0-2477-4c13-9293-b2efb0dcabdd';  -- CAIPILE ABACAXI E ACAI CACHACA ESPECIAL
update est_produtos set custo_comp = 30.4936 where id = '104d552e-7ee9-48ae-9861-5f8c6243611f';  -- TAMBAQUI PICADINHO CANTOR
update est_produtos set custo_comp = 14.0101 where id = '9f230979-36a9-4885-9476-1ef49a61babe';  -- MOQUECA VEGETARIANA CANTOR
update est_produtos set custo_comp = 8.9831 where id = '8e0d44b7-2c02-4970-9df8-c92675de5551';  -- CAIPIFRUTA VODKA IMPORTADA ABACAXI
update est_produtos set custo_comp = 8.6794 where id = 'e7093984-3d3a-4eb3-8c2c-a08dac2d81f6';  -- CHOPP VERMELHOU SUJO 500ML
update est_produtos set custo_comp = 12.5065 where id = 'd6ad1a56-d8a2-4b38-af4f-45ecd92725ff';  -- PACU ASSADO CANTOR
update est_produtos set custo_comp = 33.6719 where id = '14871721-87b6-43d1-987d-cd1ba2fd827f';  -- TAMBAQUI DE BANDA DL (2 PESSOAS)
update est_produtos set custo_comp = 6.4316 where id = '29b7644f-9e23-43ce-9330-a914b2273b7d';  -- CAIPIFRUTA VODKA NACIONAL DE ABACAXI
update est_produtos set custo_comp = 4.645 where id = '612e0cfe-17fd-4b27-8150-df18e67b340c';  -- WHISKY RED LABEL DOSE
update est_produtos set custo_comp = 9.6538 where id = '08735dcd-15a1-4f00-9308-1475f4c74f5d';  -- CHOPP SUJO BRAHMA AZULOU CHOPP 500ml
update est_produtos set custo_comp = 24.1341 where id = 'c0b2f21c-afb1-42a5-a8bc-ca9cac9a4181';  -- IARA
update est_produtos set custo_comp = 6.257 where id = '5b7f6dad-f8c0-4e87-b8d8-553d5dc7542f';  -- TAMBAQUI PICADINHO + COCA ZERO LATA
update est_produtos set custo_comp = 10.8393 where id = 'bf052219-d62d-4080-ab17-6b068b99c1f5';  -- ISCA CROCANTE DE PIRARUCU
update est_produtos set custo_comp = 8.5495 where id = 'd89d3ed5-8ef4-4dd3-8970-51c21029ad06';  -- CUNHANTA
update est_produtos set custo_comp = 5.4248 where id = 'd838600d-de62-4b5b-a726-d5c524664f18';  -- BOLINHO DE TAMBAQUI 10 UN
update est_produtos set custo_comp = 7.2498 where id = 'f9fc67d6-54fe-44e9-8caf-79185dafd9fd';  -- CAIPILE ABACAXI E ACAI CACHACA TRADICIONAL
update est_produtos set custo_comp = 7.299 where id = '21e43167-22da-4a78-babb-3a5b9c14ef34';  -- CUNHANTA ESPECIAL
update est_produtos set custo_comp = 8.6903 where id = '70399920-1cf5-4f02-9a4b-dfcb9fd608e3';  -- CHOPP SUJO BRAHMA VERMELHOU CHOPP 500ml
update est_produtos set custo_comp = 7.3422 where id = 'a91a983d-e2e4-45ab-834f-f540616ba0b2';  -- BOTO COR DE ROSA
update est_produtos set custo_comp = 14.7793 where id = 'f55d4fa0-45e3-4176-8318-023bf2527228';  -- PIRARUCU A PARMEGIANA
update est_produtos set custo_comp = 8.8779 where id = 'd7d7fc43-a15a-419e-91ec-88b50737a1aa';  -- BOTO COR DE ROSA ESPECIAL
update est_produtos set custo_comp = 5.3998 where id = 'bf9b3b0e-7d11-4a2a-b92c-ff6b5b15d8ab';  -- PASTEL DE TAMBAQUI 6 UN
update est_produtos set custo_comp = 3.7637 where id = '6e51dbf3-5e7d-4589-861d-33eba868470d';  -- PASTEL DE PIRARUCU COM BANANA 3 UNID
update est_produtos set custo_comp = 3.4905 where id = '4747af85-a151-45f2-955a-e8f7b4985537';  -- PASTEL DE MISTO 3UN
update est_produtos set custo_comp = 9.6838 where id = 'e8c76e6a-bf30-44c0-84b9-329a3c818e4a';  -- TACACA
update est_produtos set custo_comp = 8.785 where id = 'd41ae095-f3bb-4e04-9f51-87969cfe39ca';  -- UIRAPURU
update est_produtos set custo_comp = 9.7174 where id = '58f92701-a8e7-4a6d-b2eb-668c809deb58';  -- PASTEL DE CAMARAO CREMOSO 6 UNID
update est_produtos set custo_comp = 11.1322 where id = 'e5ac85a0-5958-4127-963d-3d80f9f88c4a';  -- TACAQUI O NHOQUE
update est_produtos set custo_comp = 4.8033 where id = '70292ede-9f55-4c1c-9878-b0ad0c4a4312';  -- VITORIA REGIA
update est_produtos set custo_comp = 0.6289 where id = 'b5aab639-31d3-4059-984b-8a6a78af9782';  -- OVO COZIDO
update est_produtos set custo_comp = 7.5274 where id = 'f0c60ae1-77f4-40f7-8fe4-2b954fc3968d';  -- PASTEL DE PIRARUCU COM BANANA 6 UNID
update est_produtos set custo_comp = 3.7228 where id = '1364487f-9dcc-4886-873d-356c6f1b2f26';  -- BOLINHO DE PIRARUCU 5 UN
update est_produtos set custo_comp = 3.2564 where id = '72d6cca6-2549-47fe-a2cd-8c52eca5502b';  -- SALADA DE FEIJAO DE PRAIA
update est_produtos set custo_comp = 5.072 where id = 'd8d595f0-0cba-4e16-950f-1676bc768f9d';  -- PIRAO DE TAMBAQUI
update est_produtos set custo_comp = 5.072 where id = 'eeb8ea2a-50b6-416b-82a3-5112dc79df9d';  -- PIRAO DE GALINHA
update est_produtos set custo_comp = 5.4248 where id = '0f7a4523-75a5-4a7b-9d9b-0ff06fd2f40b';  -- HAPPY HOUR BOLINHO DE TAMBAQUI 10 UN
update est_produtos set custo_comp = 5.3862 where id = 'c1bbafdd-0212-4ede-ae96-c49a31e84893';  -- VATAPA
update est_produtos set custo_comp = 5.4248 where id = '2f15d655-eacf-45b0-bce4-2b4c3f2533f8';  -- MACAXEIRA FRITA HAPPY HOUR
update est_produtos set custo_comp = 5.4248 where id = '72b8a8b4-20ce-47e6-872c-4b2430038eb2';  -- PETIT GATEAU HAPPY HOUR
update est_produtos set custo_comp = 11.8903 where id = 'd71d4c58-a322-463b-80ad-fb64080fd6e2';  -- PIRARUCU DESFIADO
update est_produtos set custo_comp = 33.7459 where id = '49bfd5ab-6440-4bc4-af22-eb22a26e2de5';  -- TAMBAQUI DE BANDA CLIENTE FIEL
update est_produtos set custo_comp = 35.0959 where id = '75f19891-9442-41c1-9e94-3ad8d1c12f92';  -- TAMBAQUI DE BANDA + BANANA FRITA
update est_produtos set custo_comp = 32.7127 where id = '31bd6816-303b-4cb7-8cc0-c6c717b5c54c';  -- TAMBAQUI DE BANDA + COCA ZERO 1,5L + FAROFA DE BANADA
update est_produtos set custo_comp = 5.3862 where id = 'd1ab5f65-99cb-4820-8547-6527097a724e';  -- VATAPA DELIVERY
update est_produtos set custo_comp = 10.7217 where id = '567c6b09-8ab5-4d60-a018-6b3fc9e230b0';  -- PIRARUCU DESFIADO 50% DESCONTO
update est_produtos set custo_comp = 8.857 where id = 'ac619e29-b412-4fd6-9504-faf106b81c91';  -- PIRARUCU DESCONFIADO
update est_produtos set custo_comp = 29.3218 where id = 'f5805d5e-7810-4400-9987-36765032cc26';  -- TAMBAQUI DE BANDA DL SIMPLES S/ GUARNICAO
update est_produtos set custo_comp = 3.7897 where id = 'd64e5c2c-b0d1-4a76-a647-3c635f8b68fa';  -- (DRINK) CAIPIRINHA GARANTIDA - ESPECIAL
update est_produtos set custo_comp = 8.1533 where id = '2c1f942c-1411-427c-923a-0d16dec4983d';  -- PPC VINAGRETE
update est_produtos set custo_comp = 5.8279 where id = '95835abd-bef2-4326-9ef6-25ed8d064ce1';  -- SALADA CAESAR REGIONAL
update est_produtos set custo_comp = 7.4039 where id = '71b5b019-37ba-4ac6-9f15-a03f80f6a49b';  -- CHOPP SUJO DOBRO AZULOU 300ML
update est_produtos set custo_comp = 10.8393 where id = '34864693-f1c2-4e09-b7b6-9a0c14e778b5';  -- ISCA CROCANTE DE PIRARUCU
update est_produtos set custo_comp = 44.083 where id = '3eaedc70-d238-4f38-9764-91d8a757a8c2';  -- TAMBAQUI DE BANDA DL (3 PESSOAS)
update est_produtos set custo_comp = 26.0874 where id = '8276e167-4fe4-417f-924a-2112f3c21322';  -- (DRINK) ISA A BELA GUERREIRA - EURIDICY
update est_produtos set custo_comp = 16.7791 where id = 'bbc888a3-391b-4ef8-a1b4-1105c4847dc4';  -- JUMA
update est_produtos set custo_comp = 37.7723 where id = '8f71e78d-5060-494a-8d28-b51fc5da81d5';  -- TAMBAQUI DE BANDA DL (3 PESSOAS S GUARN)
update est_produtos set custo_comp = 6.1288 where id = 'd3e74c2a-8c70-48b0-8df8-4baac269bb28';  -- CHOPP SUJO DOBRO VERMELHOU 300ML
update est_produtos set custo_comp = 11.8904 where id = '118aae56-666a-45c8-b049-31a41e4f2bf1';  -- PIRARUCU DESFIADO PROMOCAO
update est_produtos set custo_comp = 6.2681 where id = 'da1c0f63-e713-4d1c-a24e-c3957a9eb5bc';  -- CAIPIFRUTA VODKA IMPORTADA MORANGO
update est_produtos set custo_comp = 6.9178 where id = '0a575d7e-e82c-4dcd-a0fc-6e960aaa2c0e';  -- SODA GARANTIDO
update est_produtos set custo_comp = 29.6651 where id = '3fb3beeb-244b-428f-aecb-b2c8d9b5da6d';  -- TAMBAQUI DE BANDA DL (2 PESSOAS S/ GUARN)
update est_produtos set custo_comp = 56.4203 where id = '754f9752-50ff-4956-9b34-c9e3c1ab95b6';  -- TAMBAQUI DE CASACA 3 PESSOAS
update est_produtos set custo_comp = 32.7127 where id = 'cd570359-7147-480d-8a90-dd1b7cc75f8b';  -- TAMBAQUI DE BANDA + COCA ZERO 1,5L + FAROFA DE BANANA
update est_produtos set custo_comp = 28.5699 where id = 'ac75e137-e741-458b-ae2c-b5092b5e67b3';  -- PPC CALDINHO DE TAMBAQUI
update est_produtos set custo_comp = 5.0647 where id = '38cac168-cce6-472c-b36b-fc9fbeca004e';  -- (DRINK) CAIPIRINHA CAPRICHOSA - ESPECIAL
update est_produtos set custo_comp = 104.0592 where id = '176473e6-acfd-499c-b182-698c184a2f7b';  -- PPB ESPUMA DE TUCUMA
update est_produtos set custo_comp = 13.363 where id = 'cd9c1f67-a39a-4e41-95f1-1215fae2681a';  -- PPB ESPUMA DE TAPEREBA
update est_produtos set custo_comp = 16.5291 where id = 'd6e187c5-3b9d-4749-8a71-b3f48da987af';  -- PPB ESPUMA DE PITAYA
update est_produtos set custo_comp = 46.1087 where id = 'fcba1126-f122-42f6-a814-76e4a09db2d0';  -- PPB CORDIAL DE PITAYA
update est_produtos set custo_comp = 41.5194 where id = 'ee7ebf94-bd33-43df-b810-ed16ce14ce92';  -- PPB ESPUMA DE LIMAO SICILIANO
update est_produtos set custo_comp = 34.98 where id = 'bdb66f5a-909b-4f25-8339-65d082c2676d';  -- PPB GELEIA DE PITAYA
update est_produtos set custo_comp = 14.7231 where id = '0d1b04b0-8c3f-4df8-b5f4-02cd087e8a60';  -- PPC RECHEIO DO CABOCO ENROLADO
update est_produtos set custo_comp = 19.0165 where id = '133a4694-c623-4ca1-9ac1-81a2a0d86786';  -- PPP MASSA COZIDA DE TRIGO
update est_produtos set custo_comp = 20.4429 where id = 'd19dec97-f858-426f-9fb0-078fc8a36004';  -- PPC PASTA VERDE
update est_produtos set custo_comp = 12.3707 where id = '56cfe8c7-0c0b-4047-99f6-59db9c51095e';  -- PPC PIRAO
update est_produtos set custo_comp = 27.165 where id = 'b2b5470f-6abd-432a-901e-fa035422ce38';  -- PPB XAROPE ABACAXI
update est_produtos set custo_comp = 9.4169 where id = '28f3b500-c5f1-44f8-8941-b2302b8bbf94';  -- PPC MOLHO DE PIMENTA ARTESANAL
update est_produtos set custo_comp = 33.3461 where id = 'd58c0a91-b645-4c30-96c7-2ae20b4f22c6';  -- PPP BOLO DE MACAXEIRA
update est_produtos set custo_comp = 40.4833 where id = '7d4be075-a191-4961-a07e-38ae47185992';  -- PPC MOLHO PEIXE ASSADO
update est_produtos set custo_comp = 149.6032 where id = 'c59f59ed-29c0-4246-9832-3d037a6d776c';  -- PPP RECHEIO DE PIRARUCU 1,5KG
update est_produtos set custo_comp = 27.443 where id = '058e0327-835e-4cce-ae87-f0b5d5170808';  -- PPC MOLHO TOMATE PARMEGIANA
update est_produtos set custo_comp = 92.4313 where id = 'a7934475-8361-4f73-a4a5-25217b9ead03';  -- PPP PIRARUCU SECO E FRESCO DESFIADO 1KG
update est_produtos set custo_comp = 29.4975 where id = 'd91fde2d-bc80-4d65-a421-8af00f2744ee';  -- PPC TUCUPI REDUZIDO
update est_produtos set custo_comp = 4.5591 where id = '2c17a40c-384a-42d9-8009-cc7c19fd41fd';  -- PPC MOLHO CUPUACU COM PIMENTA
update est_produtos set custo_comp = 219.9985 where id = 'a9e28ed3-d59b-41b6-bf06-d8d92f091a33';  -- PPC TUCUPI TEMPERADO
update est_produtos set custo_comp = 12.49 where id = '9abba87f-35f2-4d27-aef2-ef470d51dee1';  -- PPB PURE DE MORANGO
update est_produtos set custo_comp = 70.4562 where id = 'c7cc535e-a050-4a60-8c5f-7411c648d665';  -- PPP RECHEIO DE PIRARUCU FRESCO 1,5KG
update est_produtos set custo_comp = 19.5631 where id = '34f0d7f2-fb54-4e10-8fc5-e823f9ca1f1b';  -- PPC MAIONESE DE TUCUPI REDUZIDO
update est_produtos set custo_comp = 51.379 where id = '0aeb2d2f-4452-4814-b1fd-ed6f93c11a13';  -- PPP RECHEIO CARNE PASTEL
update est_produtos set custo_comp = 20.4429 where id = '32b251d7-0ece-46fc-9f69-17d7b6fac617';  -- PPP PASTA VERDE
update est_produtos set custo_comp = 10.9964 where id = 'e65ab5bc-a1ae-4c9f-b3c4-f10eb93452e0';  -- MOQUECA DE PIRARUCU DELIVERY
update est_produtos set custo_comp = 11.1679 where id = '474bbfa2-7d3c-4114-bfd7-4f86d3f540dc';  -- SA CAMARAO COM CATUPIRY 4 UNID
update est_produtos set custo_comp = 12.4432 where id = 'fdeacd31-1ff6-4967-8cad-a50c7bbe0537';  -- PIRARUCU GRELHADO COM PURE
update est_produtos set custo_comp = 39.9836 where id = '76f62d2a-128b-4f97-a4c6-05261b9e0080';  -- SA BOLO DE MACAXEIRA 1 UNID
update est_produtos set custo_comp = 13.9267 where id = '2bfecfce-8e7a-45d1-b5ae-566490ebf9c7';  -- PACU FRITO
update est_produtos set custo_comp = 13.368 where id = '45fdb64b-b706-4a4e-a45a-6c11551015af';  -- PIRARUCU DE CASACA COM VATAPA
update est_produtos set custo_comp = 11.542 where id = '959fc4a8-1628-42c3-a41d-3c843e0a62f4';  -- PIRARUCU EMPANADO COM FRITAS
update est_produtos set custo_comp = 13.6871 where id = 'bf17e30b-4d71-4007-8785-7320375451ee';  -- SARDINHA FRITA 2 UN
update est_produtos set custo_comp = 11.156 where id = '8bdd8d71-676e-4228-bf6e-e163573a2aca';  -- SA CAMARAO COM CATUPIRY 6 UNID
update est_produtos set custo_comp = 18.281 where id = 'ecfbf591-aa3c-409d-8d1e-d4445552fbfe';  -- SARDINHA ASSADA NA FOLHA DA BANANEIRA 2 UN
update est_produtos set custo_comp = 6.7696 where id = '9c0b38ac-32ab-4c33-848c-f70c3a89e70c';  -- PIRARUCU EMPANADO DELIVERY
update est_produtos set custo_comp = 6.2571 where id = '99794402-2a96-43a2-8d49-bd6424eff9a7';  -- TAMBAQUI PICADINHO
update est_produtos set custo_comp = 14.9016 where id = '9b542f89-77f2-436e-a583-26f25a9fa429';  -- PACU ASSADO
update est_produtos set custo_comp = 28.1772 where id = '484fcb03-f42b-432d-8f04-84cc3969975b';  -- COSTELA DE TAMBAQUI NO TUCUPI COM JAMBU
update est_produtos set custo_comp = 14.4968 where id = '767fbd17-2cd9-49b0-8b6a-c16039502c05';  -- SARDINHA ASSADA 2 UN
update est_produtos set custo_comp = 126.2575 where id = '63b66bb0-1ab8-4d25-b80f-54156d5bad26';  -- SA BOLINHO DE TAMBAQUI 5 UNID
update est_produtos set custo_comp = 9.0 where id = '03014f78-5ebf-4b58-85af-9d41924b64d7';  -- SA ABACAXI EM CUBOS 150g
update est_produtos set custo_comp = 11.221 where id = '63833929-9383-46ad-b2a2-fca6a91c35de';  -- PIRARUCU EMPANADO COM PURE
update est_produtos set custo_comp = 154.5371 where id = '091793ad-fbe9-46b2-ae0b-e2acc15b1f16';  -- SA BOLINHO DE PIRARUCU FRESCO 5 UNID
update est_produtos set custo_comp = 11.1094 where id = 'ec74983a-e975-495a-ae94-760e6e5ac5b9';  -- PIRARUCU DESFIADO DELIVERY
update est_produtos set custo_comp = 75.8869 where id = '9515db1e-a687-4467-8f63-155470d4eae1';  -- SA RECHEIO DE TAMBAQUI 1KG
update est_produtos set custo_comp = 3.4905 where id = '06d56d91-105c-49fa-9ad6-2a7792feea95';  -- SA PASTEL MISTO 3 UNID
update est_produtos set custo_comp = 33.1896 where id = 'f3d59c38-59c1-484f-816f-b2f933d6fcc4';  -- SA KIT TACAQUI NHOQUE
update est_produtos set custo_comp = 21.8279 where id = 'f779c3a6-6467-4648-ac24-d16d37dd40b8';  -- SALADA CAESAR DE TAMBAQUI
update est_produtos set custo_comp = 1.4666 where id = '366d6cf7-b21c-4f0d-badb-57a66f4f702f';  -- SODA ABACAXI
update est_produtos set custo_comp = 3.7637 where id = 'd3e7572b-8536-4389-aae7-e94bb060998b';  -- SA PASTEL DE PIRARUCU COM BANANA 3 UNID
update est_produtos set custo_comp = 10.7435 where id = 'eb2a1e2d-488e-45cc-8eae-b5fc8cb36ecd';  -- SA KIT MEIA GALINHA CAIPIRA
update est_produtos set custo_comp = 13.5279 where id = '12a5892c-1cf7-4727-adcc-3ceea5b9221c';  -- SALADA CAESAR DE PIRARUCU
update est_produtos set custo_comp = 22.3789 where id = 'f6c21320-b579-4baa-813a-6d0c0373108f';  -- (DRINK) ISA A BELA GUERREIRA N ALCOOLICO
update est_produtos set custo_comp = 3.1495 where id = 'a6aad8d9-19f5-413b-a4f5-b47be8a4647a';  -- SUCO DE ABACAXI
update est_produtos set custo_comp = 3.5995 where id = '78b944f4-db57-44ec-ace0-a3d10c7b42a4';  -- SUCO DE ABACAXI C/ HORTELA
update est_produtos set custo_comp = 0.9062 where id = '338eee53-a9ac-4333-858a-f24f0b80853c';  -- OVO FRITO
update est_produtos set custo_comp = 3.8589 where id = '10b0e3ef-3e4c-4a8d-bf36-bfdf533cd5f3';  -- (DRINK) CAIPIRINHA CAPRICHOSA - SUNSET
update est_produtos set custo_comp = 6.0631 where id = 'f1f58092-89a8-4221-8ef3-6e1134d14cf0';  -- (DRINK) CAIPIRINHA GARANTIDA - SUNSET
update est_produtos set custo_comp = 12.144 where id = '0135c99f-f910-4a71-9697-6d4ea9ef111c';  -- PIRARUCU DESFIADO DELIVERY 2
update est_produtos set custo_comp = 12.3303 where id = '1b6ba8a8-6c95-4e05-a5a1-66b05e6a12ce';  -- PIRARUCU GRELHADO COM FRITAS
update est_produtos set custo_comp = 1.599 where id = '43cfc6e3-5bb3-4767-a2fa-d5604ad594d9';  -- PORC SALADA CRUA 250g
update est_produtos set custo_comp = 6.981 where id = '0615177f-86b9-412f-b5fa-63bf83b78f01';  -- PASTEL MISTO 6 UN
update est_produtos set custo_comp = 18.2179 where id = '96ceafef-e6e7-478f-ab02-5e9c2a4f4acc';  -- MOQUECA DE PIRARUCU COM CAMARAO
update est_produtos set custo_comp = 19.3643 where id = 'da27655c-da2f-44be-9361-5871dd105f2b';  -- SA DADINHO DE TAPIOCA 6 UNID
update est_produtos set custo_comp = 5.3862 where id = '7a0b8985-c52e-4244-a71a-022ca5c8e0fd';  -- PPC VATAPA PORCAO
update est_produtos set custo_comp = 273.2576 where id = '382711ee-3ede-4733-bd79-7cec0690da26';  -- SA BOLINHO DE PIRARUCU 5 UNID
update est_produtos set custo_comp = 95.8428 where id = '39f1c8ed-3829-4775-bdd0-66578c37d77b';  -- PPP RECHEIO PASTEL DE CAMARAO CREMOSO
update est_produtos set custo_comp = 21.1264 where id = '75175a31-b965-4609-82e6-9d4f4e565a6b';  -- PPB ESPUMA DE CUPUACU
update est_produtos set custo_comp = 30.7897 where id = '686ba5e4-0411-4309-869c-ecdbd1203c1d';  -- PPC BAIAO DE DOIS
update est_produtos set custo_comp = 12.8379 where id = 'd1ca345b-e23f-41b2-8fbf-8a9896becb20';  -- SALADA CAESAR DE CAMARAO
update est_produtos set custo_comp = 32.7127 where id = '5339c8be-cb08-497c-a8c9-1ed0451169bd';  -- TAMBAQUI DE BANDA
update est_produtos set custo_comp = 33.0599 where id = '77ea4054-6ac7-48e6-95ee-98bb2ad1a167';  -- TAMBAQUI DE BANDA - GUIA

commit;


-- ===== PASSO 3 - CONFERIR DEPOIS =====

-- select p.nome, f.custo_total, f.custo_por_porcao, p.custo_comp
--   from est_fichas_tecnicas f join est_produtos p on p.id = f.produto_id
--  where p.nome like 'PPB ESPUMA%' or p.nome in ('IARA','MOQUECA DE PIRARUCU DELIVERY')
--  order by p.nome;
-- Esperado: ESPUMA DE CUPUACU 120.13 -> 21.13 | IARA 119.97 -> 24.13
