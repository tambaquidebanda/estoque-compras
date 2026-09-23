-- ============================================================================
-- TUDO EM LITRO - o bar passa a contar liquido em litro           (23/09/2026)
-- ============================================================================
--
-- A DECISAO
-- O bar vai medir a garrafa com a fita e digitar a leitura como decimal de LITRO:
-- 350 ml vira 0,350. Nao vamos para ML. Mudar a unidade de uso para ML obrigaria a
-- mexer, no mesmo instante, em cinco lugares (fator, 90 linhas de ficha, custo por
-- unidade de uso, padroes e historico); se um atrasasse, o erro seria de 1000x - e
-- 1000x nao e numero que alguem pega no olho.
--
-- O QUE ESTE ARQUIVO FAZ
-- So acerta o ROTULO. Padroniza `unidade_uso` em LT e o rotulo das linhas de ficha
-- em LT. Nada de conta muda: quem converte e o `fator_conversao`, e ele NAO E
-- TOCADO aqui. O objetivo e parar de mandar instrucao errada para quem conta.
--
-- O QUE ELE NAO FAZ, DE PROPOSITO
--   * nao mexe em fator_conversao - os que estao com fator 1 continuam esperando a fita
--   * nao mexe em padrao, contagem, saldo nem pedido
--   * nao mexe em custo_uso: a aba Produtos recalcula esse campo sozinha ao abrir,
--     e sobrescreveria qualquer UPDATE feito por SQL
--
-- FORA DA LISTA, PORQUE NAO SAO LIQUIDO
--   MP ABACAXI DESIDRATADO      uso KG - solido, e nem devia estar no grupo DESTILADOS
--   PPB POLPA MARACUJA 200G     pacote de 200 g - decidir a parte (provavel KG, fator 0,2)
--
-- COMO RODAR
-- Um PASSO por vez, conferindo o resultado antes do proximo.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O retrato de hoje.
-- ============================================================================

-- 1a) os liquidos do BAR e o rotulo que cada um carrega
SELECT nome, unidade_comp, unidade_uso, fator_conversao,
       CASE WHEN upper(coalesce(unidade_uso,'')) = 'LT' THEN '' ELSE '<<< vai virar LT' END AS marca
FROM est_produtos
WHERE id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
)
ORDER BY (upper(coalesce(unidade_uso,'')) = 'LT'), nome;

-- 1b) quantos rotulos diferentes as fichas usam para a mesma coisa
SELECT coalesce(unidade,'(vazio)') AS rotulo_na_ficha, COUNT(*) AS linhas
FROM est_ficha_ingredientes
WHERE ingrediente_id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
)
GROUP BY 1 ORDER BY 2 DESC;

-- 1c) quem ainda espera a fita: fator 1 quer dizer "o sistema assume 1 litro por
--     garrafa". Estes NAO sao consertados aqui - so o rotulo deles muda.
SELECT nome, unidade_comp, unidade_uso, fator_conversao
FROM est_produtos
WHERE id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
) AND fator_conversao = 1
ORDER BY nome;


-- ============================================================================
-- PASSO 2 - BACKUP. Nao pule.
-- ============================================================================

CREATE TABLE IF NOT EXISTS bkp_unid_litro_prod AS
SELECT id, nome, unidade_uso AS unidade_uso_antiga, fator_conversao AS fator_antigo, now() AS salvo_em
FROM est_produtos
WHERE id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
);

CREATE TABLE IF NOT EXISTS bkp_unid_litro_ficha AS
SELECT id, ficha_id, ingrediente_id, quantidade, unidade AS unidade_antiga, now() AS salvo_em
FROM est_ficha_ingredientes
WHERE ingrediente_id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
);

-- confere que o backup guardou tudo
SELECT (SELECT COUNT(*) FROM bkp_unid_litro_prod)  AS produtos_salvos,
       (SELECT COUNT(*) FROM bkp_unid_litro_ficha) AS linhas_de_ficha_salvas;


-- ============================================================================
-- PASSO 3 - O rotulo do produto vira LT
-- ============================================================================
-- So os 15 que ainda nao estao em LT. Um UPDATE por id, sem WHERE por nome.

UPDATE est_produtos
SET    unidade_uso = 'LT'
WHERE  id IN (
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL                     LI -> LT,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL                       UN -> LT,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL                       LI -> LT,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML                 UN -> LT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS       LI -> LT,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL     UN -> LT,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA                 UN -> LT,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI                 LI -> LT,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA                 LI -> LT,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU                 LI -> LT,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI                 LI -> LT,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA             LI -> LT,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA                  LI -> LT,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA                LI -> LT,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA                   LI -> LT
);


-- ============================================================================
-- PASSO 4 - O rotulo da ficha vira LT
-- ============================================================================
-- Hoje a mesma dose aparece escrita como LT, LI, Litro, Unidade e UN. O numero ja
-- esta em litro em todas (0,05 = 50 ml); quem le e que se perde.

UPDATE est_ficha_ingredientes
SET    unidade = 'LT'
WHERE  ingrediente_id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
)
AND    coalesce(unidade,'') <> 'LT';


-- ============================================================================
-- PASSO 5 - CONFERENCIA
-- ============================================================================

-- 5a) rotulo do produto: tem que voltar uma linha so, LT, com 42
SELECT unidade_uso, COUNT(*) AS produtos
FROM est_produtos
WHERE id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
)
GROUP BY 1;

-- 5b) rotulo da ficha: tem que voltar uma linha so, LT
SELECT coalesce(unidade,'(vazio)') AS rotulo_na_ficha, COUNT(*) AS linhas
FROM est_ficha_ingredientes
WHERE ingrediente_id IN (
  '3954697a-df62-4656-b9aa-1d99f07da4d9'   -- MP APEROL 750 ML,
  '8e1285ee-a70a-46c0-a15e-3cb81b6f1d0b'   -- MP BLACK LABEL,
  '1eac7858-5712-4b8a-8ab0-6ce1c12d6866'   -- MP CACHACA AMBURANA,
  '6be0008d-6e8d-4420-a49f-917170bcd16a'   -- MP CACHACA BRAZUKA 700ML,
  '3fcba41c-bcd4-4e2e-8573-1a4b20e05689'   -- MP CACHACA CABARE,
  '58eb2e29-72dd-445b-9902-ce5f6cad228f'   -- MP CACHACA INFUSIONADA,
  '5c26a2e3-845d-473c-90b2-64dc5071f2a3'   -- MP CACHACA JAMBUCANA,
  '12fea814-c339-474b-957a-0e1550412a31'   -- MP CACHACA TRADICIONAL,
  'dc0aa62f-89c0-42d9-9b31-8313c2a5579b'   -- MP COINTREAL,
  '348f8e7e-917b-4d81-853f-cff3b5ac01a1'   -- MP CURACAU RED,
  '9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'   -- MP CURACAU BLUE,
  '11970412-9a4c-424c-a72f-c41ca6033ef9'   -- MP ESPUMANTE MOSCATEL,
  '99f1c496-17e0-4126-bb9a-3a5fe4b41b80'   -- MP GIN BEEFEATER PINK 995ml,
  'ff2788a6-aec3-4531-b766-da4f971e18f3'   -- MP LICOR 43,
  'b5238cbd-0f5f-4023-8938-589e28ee4f2b'   -- MP RED LABEL,
  'fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'   -- MP RUM BACARDI,
  '9dc31ac2-ff24-43bc-9307-7380022bbe0c'   -- MP SAGATIBA PURA 700ML,
  '7e63019e-5060-4052-85e8-32eaa003b24f'   -- MP TANQUERAY 750ML,
  'dbfc101a-ada5-4223-9acd-bd9c2524ae83'   -- MP TEQUILA PRATA,
  'af2e33ae-e844-469e-b8b3-aaf379809e7f'   -- MP VINHO CABERNET SAUVIGNON,
  '3c95a146-b5bd-4b21-88ea-403949ed2e5f'   -- MP VINHO TINTO SUAVE 750ML,
  '6c787110-677f-4491-8948-dec5bd28b417'   -- MP VODKA ABSOLUT,
  'ce74b177-5c8f-4b06-9bed-d516a2c87ed1'   -- MP VODKA KETEL ONE BOTANICAS,
  '983ccdb0-d68f-4211-8700-794adb5b2296'   -- MP VODKA SMIRNORFF,
  'c88c41db-2f97-4e5e-bb80-6c8babbb7834'   -- MP XAROPE DE GUARANA MAGISTRAL,
  '0221c68f-d582-4fc4-96c7-337c53c4eda5'   -- MP XAROPE DE LARANJA,
  '5055373c-2bbc-4ff2-9e6a-b70bf72e1b2c'   -- MP XAROPE DE MEL COM ESPECIARIAS,
  '82c72946-a920-4104-b7b8-c5426b0c5b48'   -- MP XAROPE DE MORANGO,
  'ab1d2041-541d-41d6-8ee9-5da0eef04aa4'   -- MP XAROPE GENGIBRE,
  '9e8acc72-05af-4460-a6b7-5155f9e0cc83'   -- MP XAROPE LIMAO SICILIANO,
  '633d98a4-c4f9-49c6-a72e-57a7ae186abd'   -- MP XAROPE MARACUJA,
  'b8107ccc-62b4-4f13-aa27-82e4b6e9857e'   -- MP YPIOCA OURO 965ML,
  '33c12d67-3fa2-428a-8d12-69067e5ffb36'   -- MP YPIOCA PRATA 965ML,
  'cd9c1f67-a39a-4e41-95f1-1215fae2681a'   -- PPB ESPUMA DE TAPEREBA,
  'b2b5470f-6abd-432a-901e-fa035422ce38'   -- PPB XAROPE ABACAXI,
  'c534cb78-069c-4f13-ba93-bb4c2d26a4d3'   -- PPB XAROPE ACEROLA,
  '2df211ef-bfbf-415f-88ac-65ac3c48b575'   -- PPB XAROPE CUPUACU,
  '1dc4d8ca-d3fa-4dba-a47f-a374d5a57a68'   -- PPB XAROPE DE ACAI,
  '430a038f-05cf-42aa-9748-41386ba43608'   -- PPB XAROPE DE MARACUJA,
  '858b6fee-0b40-4272-b9d9-a025a7b488aa'   -- PPB XAROPE GOIABA,
  '8a2a9349-1cd9-439c-8a38-0dd4eab1add5'   -- PPB XAROPE GRAVIOLA,
  '0dbd762e-963b-4fbd-aed2-300a0b991b2e'   -- PPB XAROPE MANGA
)
GROUP BY 1;

-- 5c) A PROVA QUE IMPORTA: nenhum fator mudou. Tem que voltar ZERO linhas.
--     Se voltar alguma, o rollback do fim e obrigatorio.
SELECT p.nome, b.fator_antigo, p.fator_conversao
FROM est_produtos p
JOIN bkp_unid_litro_prod b ON b.id = p.id
WHERE p.fator_conversao IS DISTINCT FROM b.fator_antigo;

-- 5d) e nenhuma dose de ficha mudou. Tem que voltar ZERO linhas.
SELECT i.id, i.quantidade, b.quantidade AS quantidade_antiga
FROM est_ficha_ingredientes i
JOIN bkp_unid_litro_ficha b ON b.id = i.id
WHERE i.quantidade IS DISTINCT FROM b.quantidade;


-- ============================================================================
-- VOLTAR ATRAS, se precisar
-- ============================================================================
-- UPDATE est_produtos p SET unidade_uso = b.unidade_uso_antiga
--   FROM bkp_unid_litro_prod b WHERE b.id = p.id;
-- UPDATE est_ficha_ingredientes i SET unidade = b.unidade_antiga
--   FROM bkp_unid_litro_ficha b WHERE b.id = i.id;
