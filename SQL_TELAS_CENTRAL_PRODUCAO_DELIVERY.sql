-- =====================================================================
-- TELAS DO ESTOQUE CENTRAL, DA PRODUCAO E DO ESTOQUE DO DELIVERY P10
--                                                        (28/09/2026)
--
-- Vem da planilha TELAS_CENTRAL_PRODUCAO_DELIVERY.xlsx, conferida pelo
-- Wagner, com as 4 pendencias resolvidas pela sugestao.
--
-- O que faz, dentro de inv_configuracoes:
--
-- 1) estrutura
--    'Estoque Central' -> setor ESTOQUE CENTRAL, 8 grupos, 193 produtos
--    'Producao'        -> setor PRODUCAO, a MESMA lista (a Producao recebe
--                         o MP do Central e devolve SA)
--    'Delivery P10'    -> GANHA o setor ESTOQUE DELIVERY, 10 grupos, 128 produtos.
--                         Os 6 setores de hoje (ASG, BAR, SALAO, COZINHA,
--                         DELIVERY, CHURRASQUEIRA) ficam como estao.
--
--    Central e Producao (grupo / produtos):
--     MATERIA PRIMA               27
--     HORTIFRUTI                  15
--     ESTIVAS                     26
--     SA CONGELADOS               59
--     PPP PRODUCAO                16
--     EMBALAGENS/DESCARTAVEIS     11
--     LIMPEZA                     15
--     COMIDA FUNCIONARIOS         24
--    Estoque do Delivery P10:
--     MATERIA PRIMA               10
--     PESCADOS                     2
--     HORTIFRUTI                  10
--     ESTIVAS                     24
--     BEBIDAS                     11
--     SOBREMESAS                   1
--     SA CONGELADOS               19
--     EMBALAGENS/DESCARTAVEIS     30
--     LIMPEZA                     18
--     CARVAO                       3
--
-- 2) ordem_grupos: a ordem dos grupos nos botoes (o jsonb nao guarda a
--    ordem das chaves, entao sem isto os grupos sairiam fora de ordem).
--
-- 3) adicoes: 5 produtos estao na lista 'excluidos', que vale para TODAS
--    as telas de todas as unidades (MP LEITE LIQUIDO INTEGRAL, MC CAIXA DE
--    PEIXE, MC AGULHA - FUNCIONARIO, MP PEPSI LATA, MP PEPSI BLACK LATA).
--    Pela estrutura eles nao apareceriam nas telas novas. A tela mostra
--    as 'adicoes' mesmo excluidas, e a chave e SETOR|GRUPO; os setores
--    ESTOQUE CENTRAL, PRODUCAO e ESTOQUE DELIVERY so existem nessas
--    unidades, entao isto nao muda nenhuma outra tela. A lista 'excluidos'
--    NAO e tocada.
--
-- NAO toca: Centro, os 6 setores do P10, mapeamentos, excluidos, padroes.
-- jsonb_set cirurgico - nunca reset da estrutura inteira.
-- Todos os nomes casam 1 a 1 com est_produtos ativos, sem repetido.
-- Acentos vao como \uXXXX (o arquivo e so ASCII); o jsonb decodifica.
-- Central e Producao ainda nao tem saldo nenhum, entao nada fica orfao.
--
-- DEPOIS DE RODAR: F5 em toda aba do sistema aberta, no computador E no
-- celular. A tela grava a estrutura INTEIRA a partir do que tem na
-- memoria; uma aba velha desfaz este SQL.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA. Como esta hoje.
-- Esperado:
--   Centro           6 setores  415 produtos
--   Delivery P10     6 setores  415 produtos
--   Estoque Central  1 setor    141 produtos
--   Producao         1 setor    134 produtos
-- e a segunda consulta: nada (nenhuma chave nova ja existe).
-- ---------------------------------------------------------------------
SELECT u.unidade,
       (SELECT count(*) FROM jsonb_object_keys(u.v))                          AS setores,
       (SELECT count(*) FROM jsonb_each(u.v) s, jsonb_each(s.value) g,
                             jsonb_array_elements_text(g.value) p)             AS produtos
FROM inv_configuracoes c, jsonb_each(c.valor) AS u(unidade, v)
WHERE c.chave = 'estrutura'
ORDER BY 1;

SELECT 'adicoes' AS onde, k FROM inv_configuracoes, jsonb_object_keys(valor) k
 WHERE chave = 'adicoes' AND split_part(k, '|', 1) IN ('ESTOQUE CENTRAL', 'PRODUCAO', 'ESTOQUE DELIVERY')
UNION ALL
SELECT 'estrutura P10', k FROM inv_configuracoes, jsonb_object_keys(valor -> 'Delivery P10') k
 WHERE chave = 'estrutura' AND k = 'ESTOQUE DELIVERY';


-- ---------------------------------------------------------------------
-- PASSO 2 - BACKUP + TROCA (rodar este bloco inteiro de uma vez)
-- ---------------------------------------------------------------------
BEGIN;

CREATE TABLE inv_configuracoes_bkp_20260928 AS
SELECT * FROM inv_configuracoes WHERE chave IN ('estrutura', 'ordem_grupos', 'adicoes');
-- Se der "already exists": este SQL ja rodou. ROLLBACK e me chame.

-- 1) estrutura
UPDATE inv_configuracoes
SET valor = jsonb_set(
              jsonb_set(
                jsonb_set(valor, ARRAY['Estoque Central'], $central$
{
  "ESTOQUE CENTRAL": {
    "MAT\u00c9RIA PRIMA": [
      "MP BATATA CONGELADA",
      "MP CAMAR\u00c3O FRESCO S/CABE\u00c7A M",
      "MP CAMAR\u00c3O SECO G",
      "MP CAMAR\u00c3O SECO M",
      "MP CATUPIRY REQUEIJAO",
      "MP FILE DE PEITO DE FRANGO",
      "MP FIL\u00c9 MIGNON INTEIRO",
      "MP FRANGO A PASSARINHO",
      "MP FRANGO INTEIRO",
      "MP GALINHA CAIPIRA",
      "MP JARAQUI",
      "MP KIT DE TAMBAQUI",
      "MP MACAXEIRA",
      "MP MASSA DE PASTEL 500GR",
      "MP PACU",
      "MP PICADINHO DE PATINHO",
      "MP PICADINHO DE TAMBAQUI",
      "MP PIRARUCU FRESCO",
      "MP PIRARUCU SECO",
      "MP POLPA DE CUPUA\u00c7U 1KG",
      "MP QUEIJO COALHO",
      "MP QUEIJO MUSSARELA BARRA",
      "MP QUEIJO PARMESAO TIPO 1",
      "MP SARDINHA",
      "MP TAMBAQUI DE BANDA (3KG)",
      "MP TAMBAQUI DESCAMADO",
      "MP VERDURAS CONGELADAS"
    ],
    "HORTIFRUTI": [
      "MP ABACAXI",
      "MP ALFAVACA",
      "MP ALHO DESCASCADO",
      "MP BANANA PACOVA",
      "MP CASTANHA TRITURADA",
      "MP CEBOLA",
      "MP CHICORIA",
      "MP COCO SECO",
      "MP COENTRO",
      "MP LARANJA BAHIA",
      "MP LIM\u00c3O",
      "MP LIMAO SICILIANO",
      "MP PIMENTA DE CHEIRO",
      "MP SEMENTE DE URUCUM",
      "MP TUCUPI"
    ],
    "ESTIVAS": [
      "MP A\u00c7\u00daCAR",
      "MP ACUCAR MASCAVO",
      "MP ALHO EM PO",
      "MP AZEITE EXTRA VIRGEM",
      "MP AZEITONA VERDE SEM CARO\u00c7O 400G",
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
    ],
    "PPP PRODU\u00c7\u00c3O": [
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
    "EMBALAGENS/DESCART\u00c1VEIS": [
      "MC COPO DESCART. 180ML",
      "MC FITA DUREX 50X50",
      "MC LUVA VINIL TAM G",
      "MC POTE RED 250ML",
      "MC SACO 1 KG",
      "MC SACO 10KG",
      "MC SACO 2 KG",
      "MC SACO DE DINDIN PEQUENO",
      "MC SACO DE LIXO - 200LT",
      "MC SACO DE LIXO - 50LT",
      "MC TOUCA SANFONADA"
    ],
    "LIMPEZA": [
      "MC ALCOOL EM GEL",
      "MC ALCOOL LIQUIDO 70",
      "MC CAPA FARDO",
      "MC CLEARON",
      "MC DESIN.HOSPITALAR",
      "MC DETERGENTE NEUTRO 5 L",
      "MC ESPONJA COMUM",
      "MC FIBRA PESADA",
      "MC LIMPA ALUMINIO",
      "MC LUVA DE LIMPEZA",
      "MC PANO DE CH\u00c3O",
      "MC PAPEL ROLO COZINHA TORK HANDTOWEL CENTERFEED",
      "MC PERFEX WIPE",
      "MC SABONETE BACTERICIDA",
      "MC X-12"
    ],
    "COMIDA FUNCION\u00c1RIOS": [
      "MC AGULHA - FUNCION\u00c1RIO",
      "MC ALFACE",
      "MC ARROZ - FUNCIONARIO",
      "MC BARE DE 2 LITROS",
      "MC BATATA PORTUGUESA ( FUNCIONARIO )",
      "MC CEBOLA FUNCIONARIO",
      "MC CENOURA ( FUNCIONARIO )",
      "MC COENTRO - FUNCION\u00c1RIO",
      "MC COXA S/ COXA - FUNCION\u00c1RIO",
      "MC COXAO MOLE",
      "MC FARINHA OVINHA FUNCIONARIO",
      "MC FEIJ\u00c3O PRETO",
      "MC FILE DE PEITO FUNCION\u00c1RIO",
      "MC KIT DE TAMBAQUI",
      "MC MAXIXI - FUNCION\u00c1RIO",
      "MC PEPINO",
      "MC PICADINHO CARNE - FUNCION\u00c1RIO",
      "MC POLPA ACEROLA 1KG",
      "MC POLPA CAJU 1KG",
      "MC POLPA GOIABA 1KG",
      "MC POLPA MANGA 1KG",
      "MC REPOLHO VERDE",
      "MC TOMATE ( FUNCIONARIO )",
      "MP ABOBORA"
    ]
  }
}
$central$::jsonb, false),
                ARRAY['Produ' || chr(231) || chr(227) || 'o'], $producao$
{
  "PRODUCAO": {
    "MAT\u00c9RIA PRIMA": [
      "MP BATATA CONGELADA",
      "MP CAMAR\u00c3O FRESCO S/CABE\u00c7A M",
      "MP CAMAR\u00c3O SECO G",
      "MP CAMAR\u00c3O SECO M",
      "MP CATUPIRY REQUEIJAO",
      "MP FILE DE PEITO DE FRANGO",
      "MP FIL\u00c9 MIGNON INTEIRO",
      "MP FRANGO A PASSARINHO",
      "MP FRANGO INTEIRO",
      "MP GALINHA CAIPIRA",
      "MP JARAQUI",
      "MP KIT DE TAMBAQUI",
      "MP MACAXEIRA",
      "MP MASSA DE PASTEL 500GR",
      "MP PACU",
      "MP PICADINHO DE PATINHO",
      "MP PICADINHO DE TAMBAQUI",
      "MP PIRARUCU FRESCO",
      "MP PIRARUCU SECO",
      "MP POLPA DE CUPUA\u00c7U 1KG",
      "MP QUEIJO COALHO",
      "MP QUEIJO MUSSARELA BARRA",
      "MP QUEIJO PARMESAO TIPO 1",
      "MP SARDINHA",
      "MP TAMBAQUI DE BANDA (3KG)",
      "MP TAMBAQUI DESCAMADO",
      "MP VERDURAS CONGELADAS"
    ],
    "HORTIFRUTI": [
      "MP ABACAXI",
      "MP ALFAVACA",
      "MP ALHO DESCASCADO",
      "MP BANANA PACOVA",
      "MP CASTANHA TRITURADA",
      "MP CEBOLA",
      "MP CHICORIA",
      "MP COCO SECO",
      "MP COENTRO",
      "MP LARANJA BAHIA",
      "MP LIM\u00c3O",
      "MP LIMAO SICILIANO",
      "MP PIMENTA DE CHEIRO",
      "MP SEMENTE DE URUCUM",
      "MP TUCUPI"
    ],
    "ESTIVAS": [
      "MP A\u00c7\u00daCAR",
      "MP ACUCAR MASCAVO",
      "MP ALHO EM PO",
      "MP AZEITE EXTRA VIRGEM",
      "MP AZEITONA VERDE SEM CARO\u00c7O 400G",
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
    ],
    "PPP PRODU\u00c7\u00c3O": [
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
    "EMBALAGENS/DESCART\u00c1VEIS": [
      "MC COPO DESCART. 180ML",
      "MC FITA DUREX 50X50",
      "MC LUVA VINIL TAM G",
      "MC POTE RED 250ML",
      "MC SACO 1 KG",
      "MC SACO 10KG",
      "MC SACO 2 KG",
      "MC SACO DE DINDIN PEQUENO",
      "MC SACO DE LIXO - 200LT",
      "MC SACO DE LIXO - 50LT",
      "MC TOUCA SANFONADA"
    ],
    "LIMPEZA": [
      "MC ALCOOL EM GEL",
      "MC ALCOOL LIQUIDO 70",
      "MC CAPA FARDO",
      "MC CLEARON",
      "MC DESIN.HOSPITALAR",
      "MC DETERGENTE NEUTRO 5 L",
      "MC ESPONJA COMUM",
      "MC FIBRA PESADA",
      "MC LIMPA ALUMINIO",
      "MC LUVA DE LIMPEZA",
      "MC PANO DE CH\u00c3O",
      "MC PAPEL ROLO COZINHA TORK HANDTOWEL CENTERFEED",
      "MC PERFEX WIPE",
      "MC SABONETE BACTERICIDA",
      "MC X-12"
    ],
    "COMIDA FUNCION\u00c1RIOS": [
      "MC AGULHA - FUNCION\u00c1RIO",
      "MC ALFACE",
      "MC ARROZ - FUNCIONARIO",
      "MC BARE DE 2 LITROS",
      "MC BATATA PORTUGUESA ( FUNCIONARIO )",
      "MC CEBOLA FUNCIONARIO",
      "MC CENOURA ( FUNCIONARIO )",
      "MC COENTRO - FUNCION\u00c1RIO",
      "MC COXA S/ COXA - FUNCION\u00c1RIO",
      "MC COXAO MOLE",
      "MC FARINHA OVINHA FUNCIONARIO",
      "MC FEIJ\u00c3O PRETO",
      "MC FILE DE PEITO FUNCION\u00c1RIO",
      "MC KIT DE TAMBAQUI",
      "MC MAXIXI - FUNCION\u00c1RIO",
      "MC PEPINO",
      "MC PICADINHO CARNE - FUNCION\u00c1RIO",
      "MC POLPA ACEROLA 1KG",
      "MC POLPA CAJU 1KG",
      "MC POLPA GOIABA 1KG",
      "MC POLPA MANGA 1KG",
      "MC REPOLHO VERDE",
      "MC TOMATE ( FUNCIONARIO )",
      "MP ABOBORA"
    ]
  }
}
$producao$::jsonb, false),
              ARRAY['Delivery P10', 'ESTOQUE DELIVERY'], $delivery$
{
  "MAT\u00c9RIA PRIMA": [
    "MP BATATA CONGELADA",
    "MP CAMAR\u00c3O SECO M",
    "MP COCO SECO",
    "MP MACAXEIRA",
    "MP PAO FRANCES PRODU\u00c7\u00c3O",
    "MP PICADINHO DE TAMBAQUI",
    "MP PIRARUCU FRESCO",
    "MP PIRARUCU SECO",
    "MP QUEIJO COALHO",
    "MP QUEIJO MUSSARELA FATIADO"
  ],
  "PESCADOS": [
    "MP MATRINXA",
    "MP TAMBAQUI DE BANDA (3KG)"
  ],
  "HORTIFRUTI": [
    "MP ALHO DESCASCADO",
    "MP BANANA PACOVA",
    "MP BATATA PORTUGUESA",
    "MP CEBOLA",
    "MP COENTRO",
    "MP LIM\u00c3O",
    "MP PIMENTA DE CHEIRO",
    "MP PIMENTA MURUPI",
    "MP SEMENTE DE URUCUM",
    "MP TOMATE"
  ],
  "ESTIVAS": [
    "MC SACO BOMBONS",
    "MP A\u00c7\u00daCAR",
    "MP ARROZ",
    "MP AZEITE DEND\u00ca 500ml",
    "MP AZEITE EXTRA VIRGEM",
    "MP BOMBONS",
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
  "BEBIDAS": [
    "MP BARE 1 LITRO",
    "MP BARE DE 2 LITROS",
    "MP COCA COLA 1,5 L",
    "MP COCA COLA LATA",
    "MP COCA COLA ZERO 1,5L",
    "MP COCA COLA ZERO LATA",
    "MP FANTA LARANJA LATA",
    "MP GUARANA ANTARTICA ZERO 2 L",
    "MP GUARAN\u00c1 ANTARTICA ZERO LATA",
    "MP PEPSI BLACK LATA",
    "MP PEPSI LATA"
  ],
  "SOBREMESAS": [
    "MP PUDIM DE LEITE"
  ],
  "SA CONGELADOS": [
    "SA BATATA 100g",
    "SA COCO SECO 250g",
    "SA COSTELA DE TAMBAQUI",
    "SA FILE DE FRANGO 100g",
    "SA FILE DE FRANGO 70g",
    "SA FILE DE PIRARUCU 120g",
    "SA FILE DE PIRARUCU 160g",
    "SA FRANGO DE BANDA",
    "SA KIT VATAPA",
    "SA MACAXEIRA CRUA PURE 1kg",
    "SA MAIONESE AIOLI",
    "SA MAIONESE DE ERVAS",
    "SA MARMITA DE FRANGO",
    "SA MOLHO BBQ",
    "SA PICADINHO DE TAMBAQUI 150g",
    "SA PIRARUCU KIDS 100g",
    "SA PIRARUCU SALMOURADO DESFIADO 150g",
    "SA PIRARUCU SECO DESFIADO 100g",
    "SA QUEIJO COALHO 50g"
  ],
  "EMBALAGENS/DESCART\u00c1VEIS": [
    "MC BANDEJA DE ALUMINIO D5",
    "MC BANDEJA DE ALUMINIO D6",
    "MC BANDEJA DE ALUMINIO D7",
    "MC BOBINA IMPRESSORA",
    "MC CAIXA DE PEIXE",
    "MC COLHER REFEI\u00c7\u00c3O DESCARTAVEIS",
    "MC COLHER SOBREMESA - BRANCA",
    "MC CREME CULINARIO 1.LT",
    "MC EMBALAGEM G742 (MOLHEIRA)",
    "MC FACA REFEI\u00c7\u00c3O",
    "MC FILME PVC 30x8x1200",
    "MC FITA DUREX 50X50",
    "MC GARFO REFEI\u00c7\u00c3O",
    "MC LUVA PLASTICA",
    "MC LUVA VINIL TAM G",
    "MC PAPEL FILME ROLO",
    "MC POTE RED 250ML",
    "MC POTE RED 500ML P FESTA",
    "MC POTE REDONDO C/ TAMPA PRAFESTA 750ML",
    "MC POTE RETANGULAR 500 ML",
    "MC PRATO DESCARTAVEL",
    "MC SACO 1 KG",
    "MC SACO 10KG",
    "MC SACO 2 KG",
    "MC SACO DE LIXO - 50LT",
    "MC SACOLA BRANCA - 8KG",
    "MC SACOLA ROTEROS",
    "MP PAPEL MANTEIGA",
    "MP POTE 1000ML",
    "MU ACENDEDOR"
  ],
  "LIMPEZA": [
    "MC AGUA SANITARIA",
    "MC ALCOOL EM GEL",
    "MC ALCOOL LIQUIDO 70",
    "MC CLEARON",
    "MC DETERGENTE NEUTRO 5 L",
    "MC ESPONJA COMUM",
    "MC FIBRA PESADA",
    "MC LUVA DE LIMPEZA",
    "MC PANO DE CH\u00c3O",
    "MC PAPEL HIGIENICO FUNCIONARIO",
    "MC PAPEL ROLO COZINHA TORK HANDTOWEL CENTERFEED",
    "MC PERFEX WIPE",
    "MC PEROXY 3000",
    "MC SACO DE LIXO - 200LT",
    "MC SANIT CLOR",
    "MC TOUCA SANFONADA",
    "MC X-12",
    "MP SEVEN LUMIN"
  ],
  "CARV\u00c3O": [
    "MC CARV\u00c3O",
    "MC CARV\u00c3O PRE ASSADO",
    "MC LENHA ASSADOR"
  ]
}
$delivery$::jsonb, true)
WHERE chave = 'estrutura'
  AND valor ? 'Estoque Central'
  AND valor ? ('Produ' || chr(231) || chr(227) || 'o')
  AND valor ? 'Delivery P10'
  AND NOT (valor -> 'Delivery P10') ? 'ESTOQUE DELIVERY';
-- Esperado: UPDATE 1.

-- 2) ordem dos grupos
UPDATE inv_configuracoes
SET valor = valor || jsonb_build_object(
      'Estoque Central', coalesce(valor -> 'Estoque Central', '{}'::jsonb)
                         || jsonb_build_object('ESTOQUE CENTRAL', $o1$[
  "MAT\u00c9RIA PRIMA",
  "HORTIFRUTI",
  "ESTIVAS",
  "SA CONGELADOS",
  "PPP PRODU\u00c7\u00c3O",
  "EMBALAGENS/DESCART\u00c1VEIS",
  "LIMPEZA",
  "COMIDA FUNCION\u00c1RIOS"
]$o1$::jsonb),
      'Produ' || chr(231) || chr(227) || 'o',  coalesce(valor -> ('Produ' || chr(231) || chr(227) || 'o'), '{}'::jsonb)
                         || jsonb_build_object('PRODUCAO', $o2$[
  "MAT\u00c9RIA PRIMA",
  "HORTIFRUTI",
  "ESTIVAS",
  "SA CONGELADOS",
  "PPP PRODU\u00c7\u00c3O",
  "EMBALAGENS/DESCART\u00c1VEIS",
  "LIMPEZA",
  "COMIDA FUNCION\u00c1RIOS"
]$o2$::jsonb),
      'Delivery P10',    coalesce(valor -> 'Delivery P10', '{}'::jsonb)
                         || jsonb_build_object('ESTOQUE DELIVERY', $o3$[
  "MAT\u00c9RIA PRIMA",
  "PESCADOS",
  "HORTIFRUTI",
  "ESTIVAS",
  "BEBIDAS",
  "SOBREMESAS",
  "SA CONGELADOS",
  "EMBALAGENS/DESCART\u00c1VEIS",
  "LIMPEZA",
  "CARV\u00c3O"
]$o3$::jsonb))
WHERE chave = 'ordem_grupos';
-- Esperado: UPDATE 1.

-- 3) adicoes (so chaves novas; as que existem nao mudam)
UPDATE inv_configuracoes
SET valor = valor || $ad$
{
  "ESTOQUE CENTRAL|ESTIVAS": [
    "MP LEITE LIQUIDO INTEGRAL"
  ],
  "ESTOQUE CENTRAL|COMIDA FUNCION\u00c1RIOS": [
    "MC AGULHA - FUNCION\u00c1RIO"
  ],
  "PRODUCAO|ESTIVAS": [
    "MP LEITE LIQUIDO INTEGRAL"
  ],
  "PRODUCAO|COMIDA FUNCION\u00c1RIOS": [
    "MC AGULHA - FUNCION\u00c1RIO"
  ],
  "ESTOQUE DELIVERY|ESTIVAS": [
    "MP LEITE LIQUIDO INTEGRAL"
  ],
  "ESTOQUE DELIVERY|BEBIDAS": [
    "MP PEPSI BLACK LATA",
    "MP PEPSI LATA"
  ],
  "ESTOQUE DELIVERY|EMBALAGENS/DESCART\u00c1VEIS": [
    "MC CAIXA DE PEIXE"
  ]
}
$ad$::jsonb
WHERE chave = 'adicoes';
-- Esperado: UPDATE 1.

DO $chk$
DECLARE n_cp int; n_pr int; n_dl int; n_ad int;
BEGIN
  SELECT count(*) INTO n_cp FROM inv_configuracoes c, jsonb_each(c.valor -> 'Estoque Central') s,
         jsonb_each(s.value) g, jsonb_array_elements_text(g.value) p WHERE c.chave = 'estrutura';
  SELECT count(*) INTO n_pr FROM inv_configuracoes c, jsonb_each(c.valor -> ('Produ' || chr(231) || chr(227) || 'o')) s,
         jsonb_each(s.value) g, jsonb_array_elements_text(g.value) p WHERE c.chave = 'estrutura';
  SELECT count(*) INTO n_dl FROM inv_configuracoes c, jsonb_each(c.valor -> 'Delivery P10' -> 'ESTOQUE DELIVERY') g,
         jsonb_array_elements_text(g.value) p WHERE c.chave = 'estrutura';
  SELECT count(*) INTO n_ad FROM inv_configuracoes c, jsonb_object_keys(c.valor) k
   WHERE c.chave = 'adicoes' AND split_part(k, '|', 1) IN ('ESTOQUE CENTRAL', 'PRODUCAO', 'ESTOQUE DELIVERY');
  IF n_cp <> 193 OR n_pr <> 193 OR n_dl <> 128 OR n_ad <> 7 THEN
    RAISE EXCEPTION 'Conta nao bateu: central %, producao %, delivery %, adicoes % (esperado 193, 193, 128, 7). Nada foi gravado.',
      n_cp, n_pr, n_dl, n_ad;
  END IF;
END $chk$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA
-- Esperado:
--   Centro           6 setores  415 produtos  intacto = SIM
--   Delivery P10     7 setores  543 produtos  os 6 de antes intactos = SIM
--   Estoque Central  1 setor    193 produtos  (trocado)
--   Producao         1 setor    193 produtos  (trocado)
-- ---------------------------------------------------------------------
SELECT u.unidade,
       (SELECT count(*) FROM jsonb_object_keys(u.v))                          AS setores,
       (SELECT count(*) FROM jsonb_each(u.v) s, jsonb_each(s.value) g,
                             jsonb_array_elements_text(g.value) p)             AS produtos,
       CASE WHEN (u.v - 'ESTOQUE DELIVERY') = (b.valor -> u.unidade) THEN 'SIM'
            ELSE 'nao (trocado)' END                                          AS intacto
FROM inv_configuracoes c
CROSS JOIN LATERAL jsonb_each(c.valor) AS u(unidade, v)
JOIN inv_configuracoes_bkp_20260928 b ON b.chave = 'estrutura'
WHERE c.chave = 'estrutura'
ORDER BY 1;

-- adicoes e ordem_grupos: tudo que existia continua igual (esperado: SIM, SIM)
SELECT c.chave,
       CASE WHEN NOT EXISTS (SELECT 1 FROM jsonb_each(b.valor) o
                             WHERE (c.valor -> o.key) IS DISTINCT FROM o.value
                               AND o.key NOT IN ('Estoque Central', 'Produ' || chr(231) || chr(227) || 'o', 'Delivery P10'))
            THEN 'SIM' ELSE 'NAO - me chame' END AS antigas_intactas
FROM inv_configuracoes c JOIN inv_configuracoes_bkp_20260928 b USING (chave)
WHERE c.chave IN ('adicoes', 'ordem_grupos');

-- Grupos novos, para bater o olho:
SELECT u.unidade, s.key AS setor, g.key AS grupo, jsonb_array_length(g.value) AS produtos
FROM inv_configuracoes c, jsonb_each(c.valor) u(unidade, v), jsonb_each(u.v) s, jsonb_each(s.value) g
WHERE c.chave = 'estrutura'
  AND (u.unidade IN ('Estoque Central', 'Produ' || chr(231) || chr(227) || 'o') OR s.key = 'ESTOQUE DELIVERY')
ORDER BY 1, 2, 3;


-- ---------------------------------------------------------------------
-- DESFAZER (so se precisar). Volta as tres chaves ao backup.
-- ATENCAO: desfaz tambem qualquer mudanca de estrutura feita pela tela
-- depois deste SQL.
-- ---------------------------------------------------------------------
-- UPDATE inv_configuracoes c SET valor = b.valor
--   FROM inv_configuracoes_bkp_20260928 b
--  WHERE c.chave = b.chave;
