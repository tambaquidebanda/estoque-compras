-- =====================================================================
-- ESTRUTURA DO ESTOQUE CENTRAL E DA PRODUCAO          (25/09/2026)
--
-- O que faz: troca SO as chaves 'Estoque Central' e 'Producao' dentro de
-- inv_configuracoes.estrutura. Hoje as duas sao a copia da estrutura do
-- Centro (6 setores, 415 produtos), semeada em junho e nunca configurada.
-- Passam a ter a lista que o Wagner marcou com S na planilha
-- ESTRUTURA_CENTRAL_PRODUCAO.xlsx:
--
--   Estoque Central -> 1 setor ESTOQUE CENTRAL, 7 grupos, 141 produtos
--   Producao        -> 1 setor PRODUCAO,        5 grupos, 134 produtos
--
-- NAO toca: Centro, Delivery P10, nem nenhuma outra chave de
-- inv_configuracoes. jsonb_set cirurgico - nunca reset da estrutura inteira
-- (foi assim que se perderam produtos em jun/2026).
--
-- Todos os 275 nomes casaram 1 a 1 com est_produtos, ativos, sem nome
-- repetido. Acentos vao como \uXXXX (o arquivo e so ASCII); o jsonb decodifica.
--
-- DEPOIS DE RODAR: recarregar (F5) toda aba do sistema aberta no computador.
-- A tela grava a estrutura INTEIRA a partir do que carregou na memoria; uma
-- aba velha que salvar qualquer mudanca de estrutura desfaz este SQL.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA. Como esta hoje.
-- Esperado: 4 unidades, cada uma com 6 setores e 415 produtos.
-- ---------------------------------------------------------------------
SELECT u.unidade,
       (SELECT count(*) FROM jsonb_object_keys(u.v))                          AS setores,
       (SELECT count(*) FROM jsonb_each(u.v) s, jsonb_each(s.value) g,
                             jsonb_array_elements_text(g.value) p)             AS produtos,
       md5(u.v::text)                                                         AS impressao_digital
FROM inv_configuracoes c, jsonb_each(c.valor) AS u(unidade, v)
WHERE c.chave = 'estrutura'
ORDER BY 1;


-- ---------------------------------------------------------------------
-- PASSO 2 - BACKUP + TROCA (rodar este bloco inteiro de uma vez)
-- ---------------------------------------------------------------------
BEGIN;

CREATE TABLE IF NOT EXISTS inv_configuracoes_bkp_20260925 AS
SELECT * FROM inv_configuracoes WHERE chave = 'estrutura';

UPDATE inv_configuracoes
SET valor = jsonb_set(
              jsonb_set(valor, ARRAY['Estoque Central'], $central$
{
  "ESTOQUE CENTRAL": {
    "BEBIDAS": [
      "MP BARE 1 LITRO",
      "MP BARE DE 2 LITROS",
      "MP BARE LATA",
      "MP COCA COLA 1,5 L",
      "MP COCA COLA LATA",
      "MP COCA COLA ZERO 1,5L",
      "MP COCA COLA ZERO LATA",
      "MP FANTA LARANJA LATA",
      "MP GUARANA ANTARTICA ZERO 2 L",
      "MP GUARAN\u00c1 ANTARTICA ZERO LATA",
      "MP LARANJA DESIDRATADA",
      "MP LIM\u00c3O SICILIANO DESIDRATADO",
      "MP PEPSI BLACK LATA",
      "MP PEPSI LATA"
    ],
    "DESCARTAVEIS": [
      "MC ACUCAR SACH\u00ca",
      "MC ADO\u00c7ANTE SACH\u00ca",
      "MC BANDEJA DE ALUMINIO D5",
      "MC BANDEJA DE ALUMINIO D6",
      "MC BANDEJA DE ALUMINIO D7",
      "MC CAIXA DE PEIXE",
      "MC CREME CULINARIO 1.LT",
      "MC FITA DUREX 50X50",
      "MC GARRAFA 350ML",
      "MC GARRAFA 500ML",
      "MC GARRAFA DE 1 LITRO",
      "MC LUVA PLASTICA",
      "MC PAPEL FILME ROLO",
      "MC POTE RED 250ML",
      "MC POTE RED 500ML P FESTA",
      "MC POTE REDONDO C/ TAMPA PRAFESTA 750ML",
      "MC SACO 1 KG",
      "MC SACO 10KG",
      "MC SACO 2 KG",
      "MC SAL SACHE",
      "MC TOUCA SANFONADA",
      "MP POTE 1000ML",
      "MU MOLHEIRA"
    ],
    "ESTIVAS": [
      "MP ARROZ",
      "MP AZEITE DEND\u00ca 500ml",
      "MP AZEITONA VERDE SEM CARO\u00c7O 400G",
      "MP A\u00c7\u00daCAR",
      "MP EXTRATO DE TOMATE",
      "MP FARINHA BRANCA",
      "MP FARINHA OVINHA",
      "MP FARINHA PANKO",
      "MP FEIJ\u00c3O DE PRAIA",
      "MP KETCHUP",
      "MP LEITE EM PO INTEGRAL",
      "MP LEITE LIQUIDO INTEGRAL",
      "MP MARGARINA",
      "MP MASSA DE PUR\u00ca DE BATATA",
      "MP OLEO COMPOSTO",
      "MP OLEO DE SOJA",
      "MP OVO",
      "MP PIMENTA DO REINO EM GRAOS",
      "MP SAL GROSSO",
      "MP SAL REFINADO",
      "MP TRIGO S/ FERMENTO",
      "MP VINAGRE"
    ],
    "FRIOS E PROTEINAS": [
      "MP ACAI",
      "MP BANDA DE TAMBAQUI",
      "MP QUEIJO MUSSARELA FATIADO"
    ],
    "HORTIFRUTI E POLPAS": [
      "MP ABACAXI",
      "MP ALHO DESCASCADO",
      "MP BANANA PACOVA",
      "MP BATATA PORTUGUESA",
      "MP CEBOLA",
      "MP CENOURA",
      "MP COENTRO",
      "MP FOLHA DE BANANA",
      "MP GOMA",
      "MP LARANJA BAHIA",
      "MP LIMAO SICILIANO",
      "MP LIM\u00c3O",
      "MP PIMENTA DE CHEIRO",
      "MP PIMENTA MURUPI",
      "MP TOMATE",
      "MP TUCUPI"
    ],
    "MATERIAL DE LIMPEZA": [
      "MC ALCOOL LIQUIDO 70",
      "MC DETERGENTE NEUTRO 5 L",
      "MC PAPEL ROLO COZINHA TORK HANDTOWEL CENTERFEED",
      "MC SACO DE LIXO - 200LT",
      "MC SACO DE LIXO - 50LT"
    ],
    "SA CONGELADOS": [
      "SA ABACAXI EM CUBOS 150g",
      "SA BATATA 100g",
      "SA BOLINHO DE PIRARUCU FRESCO 5 UNID",
      "SA BOLINHO DE TAMBAQUI 5 UNID",
      "SA BOLO DE MACAXEIRA 1 UNID",
      "SA CABECA DE CAMARAO SECO 200g",
      "SA CAMARAO ALHO E OLEO 220g",
      "SA CAMARAO COM CATUPIRY 6 UNID",
      "SA CAMARAO FRESCO 5 UNID",
      "SA CAMARAO SECO G 50G",
      "SA CAMARAO SECO M 40G",
      "SA CASTANHA LASCA 50g (BAR)",
      "SA CASTANHA LASCA 50g (COZINHA)",
      "SA COCO LASCA 50g",
      "SA COCO SECO 250g",
      "SA COMPOTA DE CUPUACU 1kg (BAR)",
      "SA COMPOTA DE CUPUACU 1kg (COZINHA)",
      "SA COSTELA DE TAMBAQUI",
      "SA CROCANTE DE PIRARUCU 150g",
      "SA DADINHO DE TAPIOCA 6 UNID",
      "SA FILE DE FRANGO 100g",
      "SA FILE DE FRANGO 70g",
      "SA FILE DE PIRARUCU 120g",
      "SA FILE DE PIRARUCU 160g",
      "SA FILE MIGNON 200g",
      "SA FRANGO A PASSARINHO",
      "SA FRANGO DE BANDA",
      "SA ISCA DE FILE MIGNON 100g",
      "SA ISCA DE FRANGO 100g",
      "SA ISCA DE FRANGO 130g",
      "SA JARAQUI 1 UNID",
      "SA KIT MEIA GALINHA CAIPIRA",
      "SA KIT MOQUECA CABOCA",
      "SA KIT MOQUECA DE PIRARUCU",
      "SA KIT MOQUECA DE TAMBAQUI",
      "SA KIT TACAQUI NHOQUE",
      "SA KIT VATAPA",
      "SA MACAXEIRA 300g",
      "SA MACAXEIRA CRUA PURE 1kg",
      "SA MAIONESE AIOLI",
      "SA MAIONESE DE ERVAS",
      "SA MARMITA DE FRANGO",
      "SA MOLHO BBQ",
      "SA PASTEL DE CAMARAO CREMOSO 3 UNID",
      "SA PASTEL DE PIRARUCU COM BANANA 3 UNID",
      "SA PASTEL DE QUEIJO 3 UNID",
      "SA PASTEL MISTO 3 UNID",
      "SA PASTEL TAMBAQUI 3 UNID",
      "SA PICADINHO CALDINHO 200g",
      "SA PICADINHO DE TAMBAQUI 150g",
      "SA PIRARUCU DE CASACA",
      "SA PIRARUCU KIDS 100g",
      "SA PIRARUCU SALMOURADO DESFIADO 150g",
      "SA PIRARUCU SECO DESFIADO 100g",
      "SA QUEIJO COALHO 50g",
      "SA RECHEIO DE TAMBAQUI 1KG",
      "SA SARDINHA 2 UNID",
      "SA VERDURAS CONGELADAS 200g"
    ]
  }
}
$central$::jsonb, false),
              ARRAY['Produ' || chr(231) || chr(227) || 'o'], $producao$
{
  "PRODUCAO": {
    "ESTIVAS": [
      "MP ACUCAR MASCAVO",
      "MP ALHO EM PO",
      "MP A\u00c7\u00daCAR",
      "MP CEBOLA EM PO",
      "MP COMINHO EM PO",
      "MP CREME CULINARIO 1.LT",
      "MP FARINHA DE ROSCA",
      "MP FARINHA DE TAPIOCA",
      "MP FARINHA PANKO",
      "MP LEITE CONDENSADO",
      "MP LEITE LIQUIDO INTEGRAL",
      "MP MAIZENA",
      "MP MARGARINA",
      "MP MASSA DE PUR\u00ca DE BATATA",
      "MP OLEO COMPOSTO",
      "MP OLEO DE SOJA",
      "MP OREGANO",
      "MP OVO",
      "MP PAO FRANCES PRODU\u00c7\u00c3O",
      "MP PAPRICA DOCE",
      "MP PIMENTA DO REINO EM GRAOS",
      "MP SAL REFINADO",
      "MP TRIGO S/ FERMENTO",
      "MP VINAGRE"
    ],
    "FRIOS E PROTEINAS": [
      "MP BANDA DE TAMBAQUI",
      "MP BATATA CONGELADA",
      "MP CAMAR\u00c3O FRESCO S/CABE\u00c7A M",
      "MP CAMAR\u00c3O SECO G",
      "MP CAMAR\u00c3O SECO M",
      "MP CATUPIRY REQUEIJAO",
      "MP FIL\u00c9 MIGNON INTEIRO",
      "MP FRANGO A PASSARINHO",
      "MP FRANGO INTEIRO",
      "MP GALINHA CAIPIRA",
      "MP JARAQUI",
      "MP MASSA DE PASTEL 500GR",
      "MP PACU",
      "MP PEITO DE FRANGO",
      "MP PICADINHO DE PATINHO",
      "MP PICADINHO DE TAMBAQUI",
      "MP PIRARUCU FRESCO",
      "MP PIRARUCU SECO",
      "MP QUEIJO COALHO",
      "MP QUEIJO MUSSARELA BARRA",
      "MP QUEIJO PARMESAO TIPO 1",
      "MP SARDINHA",
      "MP TAMBAQUI DESCAMADO",
      "MP VERDURAS CONGELADAS"
    ],
    "HORTIFRUTI E POLPAS": [
      "MP ABACAXI",
      "MP ALHO DESCASCADO",
      "MP CASTANHA DO BRASIL",
      "MP CASTANHA TRITURADA",
      "MP CEBOLA",
      "MP COCO SECO",
      "MP COENTRO",
      "MP LIM\u00c3O",
      "MP MACAXEIRA",
      "MP PIMENTA DE CHEIRO",
      "MP POLPA DE CUPUA\u00c7U 1KG"
    ],
    "PPP PRODUCAO": [
      "PPP BASE DE PAO 200g",
      "PPP BOLO DE MACAXEIRA",
      "PPP CAMARAO ALHO E OLEO",
      "PPP CAMARAO SEM CASCA M",
      "PPP CREME RECHEIO DE PASTEL",
      "PPP FILE MIGNON ISCA",
      "PPP MAIONESE BASE",
      "PPP MASSA COZIDA DE TRIGO",
      "PPP PASTA DE ALHO",
      "PPP PASTA VERDE",
      "PPP PIRARUCU FRESCO LIMPO",
      "PPP RECHEIO CARNE PASTEL",
      "PPP RECHEIO DE PIRARUCU FRESCO 1,5KG",
      "PPP RECHEIO PASTEL DE CAMARAO CREMOSO",
      "PPP RUB DO FRANGO DE BANDA",
      "PPP TAMBAQUI COSTELA"
    ],
    "SA CONGELADOS": [
      "SA ABACAXI EM CUBOS 150g",
      "SA BATATA 100g",
      "SA BOLINHO DE PIRARUCU FRESCO 5 UNID",
      "SA BOLINHO DE TAMBAQUI 5 UNID",
      "SA BOLO DE MACAXEIRA 1 UNID",
      "SA CABECA DE CAMARAO SECO 200g",
      "SA CAMARAO ALHO E OLEO 220g",
      "SA CAMARAO COM CATUPIRY 6 UNID",
      "SA CAMARAO FRESCO 5 UNID",
      "SA CAMARAO SECO G 50G",
      "SA CAMARAO SECO M 40G",
      "SA CASTANHA LASCA 50g (BAR)",
      "SA CASTANHA LASCA 50g (COZINHA)",
      "SA COCO LASCA 50g",
      "SA COCO SECO 250g",
      "SA COMPOTA DE CUPUACU 1kg (BAR)",
      "SA COMPOTA DE CUPUACU 1kg (COZINHA)",
      "SA COSTELA DE TAMBAQUI",
      "SA CROCANTE DE PIRARUCU 150g",
      "SA DADINHO DE TAPIOCA 6 UNID",
      "SA FILE DE FRANGO 100g",
      "SA FILE DE FRANGO 70g",
      "SA FILE DE PIRARUCU 120g",
      "SA FILE DE PIRARUCU 160g",
      "SA FILE MIGNON 200g",
      "SA FRANGO A PASSARINHO",
      "SA FRANGO DE BANDA",
      "SA ISCA DE FILE MIGNON 100g",
      "SA ISCA DE FRANGO 100g",
      "SA ISCA DE FRANGO 130g",
      "SA JARAQUI 1 UNID",
      "SA KIT MEIA GALINHA CAIPIRA",
      "SA KIT MOQUECA CABOCA",
      "SA KIT MOQUECA DE PIRARUCU",
      "SA KIT MOQUECA DE TAMBAQUI",
      "SA KIT TACAQUI NHOQUE",
      "SA KIT VATAPA",
      "SA MACAXEIRA 300g",
      "SA MACAXEIRA CRUA PURE 1kg",
      "SA MAIONESE AIOLI",
      "SA MAIONESE DE ERVAS",
      "SA MARMITA DE FRANGO",
      "SA MOLHO BBQ",
      "SA PACU 1 UNID",
      "SA PASTEL DE CAMARAO CREMOSO 3 UNID",
      "SA PASTEL DE PIRARUCU COM BANANA 3 UNID",
      "SA PASTEL DE QUEIJO 3 UNID",
      "SA PASTEL MISTO 3 UNID",
      "SA PASTEL TAMBAQUI 3 UNID",
      "SA PICADINHO CALDINHO 200g",
      "SA PICADINHO DE TAMBAQUI 150g",
      "SA PIRARUCU DE CASACA",
      "SA PIRARUCU KIDS 100g",
      "SA PIRARUCU SALMOURADO DESFIADO 150g",
      "SA PIRARUCU SECO DESFIADO 100g",
      "SA QUEIJO COALHO 50g",
      "SA RECHEIO DE TAMBAQUI 1KG",
      "SA SARDINHA 2 UNID",
      "SA VERDURAS CONGELADAS 200g"
    ]
  }
}
$producao$::jsonb, false)
WHERE chave = 'estrutura'
  AND valor ? 'Estoque Central'
  AND valor ? ('Produ' || chr(231) || chr(227) || 'o');
-- Esperado: UPDATE 1. Se der UPDATE 0, uma das chaves nao existe: ROLLBACK e me chame.

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA
-- Esperado:
--   Centro          6 setores  415 produtos  intacto = SIM
--   Delivery P10    6 setores  415 produtos  intacto = SIM
--   Estoque Central 1 setor    141 produtos  intacto = nao (trocado)
--   Producao        1 setor    134 produtos  intacto = nao (trocado)
-- ---------------------------------------------------------------------
SELECT u.unidade,
       (SELECT count(*) FROM jsonb_object_keys(u.v))                          AS setores,
       (SELECT count(*) FROM jsonb_each(u.v) s, jsonb_each(s.value) g,
                             jsonb_array_elements_text(g.value) p)             AS produtos,
       CASE WHEN u.v = b.valor -> u.unidade THEN 'SIM' ELSE 'nao (trocado)' END AS intacto
FROM inv_configuracoes c
CROSS JOIN LATERAL jsonb_each(c.valor) AS u(unidade, v)
CROSS JOIN inv_configuracoes_bkp_20260925 b
WHERE c.chave = 'estrutura'
ORDER BY 1;

-- Grupos novos, para bater o olho:
SELECT u.unidade, s.key AS setor, g.key AS grupo, jsonb_array_length(g.value) AS produtos
FROM inv_configuracoes c, jsonb_each(c.valor) u(unidade, v), jsonb_each(u.v) s, jsonb_each(s.value) g
WHERE c.chave = 'estrutura' AND u.unidade IN ('Estoque Central', 'Produ' || chr(231) || chr(227) || 'o')
ORDER BY 1, 3;


-- ---------------------------------------------------------------------
-- DESFAZER (so se precisar). Volta SO as duas chaves ao que era antes,
-- a partir do backup - nao mexe no Centro nem no P10.
-- ---------------------------------------------------------------------
-- UPDATE inv_configuracoes c
-- SET valor = jsonb_set(
--               jsonb_set(c.valor, ARRAY['Estoque Central'], b.valor -> 'Estoque Central', false),
--               ARRAY['Produ' || chr(231) || chr(227) || 'o'], b.valor -> ('Produ' || chr(231) || chr(227) || 'o'), false)
-- FROM inv_configuracoes_bkp_20260925 b
-- WHERE c.chave = 'estrutura';
