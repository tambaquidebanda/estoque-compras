-- ============================================================================
-- SQL_INSUMOS_PARA_SETOR.sql
--
-- Inclui na estrutura de CONTAGEM os insumos que o modelo consome mas que
-- nenhum setor contava - por isso o consumo era calculado e nao saia do estoque
-- de ninguem ("nao baixa" em toda rodada do robo).
--
-- Sao 28 insumos, definidos pelo Wagner em 01/09/2026 (planilhas
-- INSUMOS_SEM_SETOR e PROPOSTA_GRUPOS). O setor veio dele; o grupo foi proposta
-- minha corrigida por ele em 8 linhas.
--
-- FICARAM DE FORA, de proposito:
--   MP FILE MIGNON INTEIRO, MP FRANGO INTEIRO, MP MACAXEIRA, MP PIRARUCU
--   FRESCO, MP COCO SECO -> sao de PRODUCAO. A cozinha conta o SA, nao o MP.
--   Continuam sem baixar, e isso e a decisao correta.
--   MP MARGARINA DELINE 3KG -> ja inativada.
--
-- CIRURGICO: cada UPDATE acrescenta ao array de UM grupo de UMA unidade, e so
-- o que ainda nao esta la. Rodar de novo nao duplica. Nunca reset da estrutura.
--
-- ACENTOS: literais na forma U&'...' para o arquivo ficar ASCII sem estragar o
-- texto (Producao, NAO ALCOOLICAS, CACHACA...).
--
-- IMPORTANTE - O QUE ESTE SQL FAZ, E O QUE NAO FAZ (mudou em 01/09/2026)
-- Desde o commit bd07472 o robo descobre o setor de cada insumo olhando ONDE O
-- PRODUTO FOI CONTADO (est_inventario_itens, por produto_id), e nao mais a
-- estrutura da tela. Entao:
--
--   este SQL faz o item APARECER na tela de contagem do setor certo;
--   o setor so passa a valer para a baixa DEPOIS que o time contar o item.
--
-- Ou seja: rode hoje, o time conta a noite, e amanha o insumo comeca a baixar
-- sozinho. Nao espere o numero mudar na hora - ele muda na proxima contagem.
--
-- Dois da lista precisam de um passo a mais, porque estao em
-- inv_configuracoes['excluidos'] e por isso nao aparecem na TELA:
--   PPC TUCUPI REDUZIDO   (ja esta na estrutura de COZINHA/ESTIVAS)
--   MP BUDWEISER ZERO LN
-- Para eles a inclusao aqui nao basta: e preciso tirar da lista de excluidos
-- pela tela de Contagem, senao continuam invisiveis para quem conta.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Quantos itens cada grupo tem hoje.
-- ============================================================================
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo,
       jsonb_array_length(grupo.value) AS itens
FROM inv_configuracoes c,
     jsonb_each(c.valor) unid, jsonb_each(unid.value) setor, jsonb_each(setor.value) grupo
WHERE c.chave = 'estrutura'
  AND (setor.key, grupo.key) IN (('BAR', 'DESTILADOS'), ('BAR', 'EMBALAGEMDESCAR'), ('BAR', 'HORTIFRUTI'), ('BAR', U&'N\00c3O ALCOOLICAS'), ('BAR', 'SODA AMAZONENSE'), ('COZINHA', 'CONGELADOS'), ('COZINHA', 'EMBALAGENS'), ('COZINHA', 'ESTIVAS'), ('COZINHA', 'HORTIFRUTI'))
ORDER BY 2, 3, 1;


-- ============================================================================
-- PASSO 2 - ESCREVE.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BAR / DESTILADOS  (7 insumo(s))
--   MP YPIOCA PRATA 965ML, MP CACHACA CABARE, MP CACHACA INFUSIONADA, MP XAROPE DE MEL COM ESPECIARIAS, MP CACHACA BRAZUKA 700ML, MP XAROPE MARACUJA, MP ABACAXI DESIDRATADO
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'BAR', 'DESTILADOS'],
       (c.valor #> ARRAY['Centro', 'BAR', 'DESTILADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP YPIOCA PRATA 965ML', U&'MP CACHA\00c7A CABAR\00c9', U&'MP CACHA\00c7A INFUSIONADA', 'MP XAROPE DE MEL COM ESPECIARIAS', U&'MP CACHA\00c7A BRAZUKA 700ML', 'MP XAROPE MARACUJA', 'MP ABACAXI DESIDRATADO']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'BAR', 'DESTILADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'DESTILADOS'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'DESTILADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP YPIOCA PRATA 965ML', U&'MP CACHA\00c7A CABAR\00c9', U&'MP CACHA\00c7A INFUSIONADA', 'MP XAROPE DE MEL COM ESPECIARIAS', U&'MP CACHA\00c7A BRAZUKA 700ML', 'MP XAROPE MARACUJA', 'MP ABACAXI DESIDRATADO']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'DESTILADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'BAR', 'DESTILADOS'],
       (c.valor #> ARRAY['Delivery P10', 'BAR', 'DESTILADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP YPIOCA PRATA 965ML', U&'MP CACHA\00c7A CABAR\00c9', U&'MP CACHA\00c7A INFUSIONADA', 'MP XAROPE DE MEL COM ESPECIARIAS', U&'MP CACHA\00c7A BRAZUKA 700ML', 'MP XAROPE MARACUJA', 'MP ABACAXI DESIDRATADO']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'BAR', 'DESTILADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'BAR', 'DESTILADOS'],
       (c.valor #> ARRAY['Estoque Central', 'BAR', 'DESTILADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP YPIOCA PRATA 965ML', U&'MP CACHA\00c7A CABAR\00c9', U&'MP CACHA\00c7A INFUSIONADA', 'MP XAROPE DE MEL COM ESPECIARIAS', U&'MP CACHA\00c7A BRAZUKA 700ML', 'MP XAROPE MARACUJA', 'MP ABACAXI DESIDRATADO']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'BAR', 'DESTILADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- BAR / EMBALAGEMDESCAR  (2 insumo(s))
--   MC ACESSORIO GARANTIDO, MC ACESSORIO CAPRICHOSO
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'BAR', 'EMBALAGEMDESCAR'],
       (c.valor #> ARRAY['Centro', 'BAR', 'EMBALAGEMDESCAR']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC ACESSORIO GARANTIDO', 'MC ACESSORIO CAPRICHOSO']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'BAR', 'EMBALAGEMDESCAR']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'EMBALAGEMDESCAR'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'EMBALAGEMDESCAR']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC ACESSORIO GARANTIDO', 'MC ACESSORIO CAPRICHOSO']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'EMBALAGEMDESCAR']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'BAR', 'EMBALAGEMDESCAR'],
       (c.valor #> ARRAY['Delivery P10', 'BAR', 'EMBALAGEMDESCAR']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC ACESSORIO GARANTIDO', 'MC ACESSORIO CAPRICHOSO']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'BAR', 'EMBALAGEMDESCAR']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'BAR', 'EMBALAGEMDESCAR'],
       (c.valor #> ARRAY['Estoque Central', 'BAR', 'EMBALAGEMDESCAR']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC ACESSORIO GARANTIDO', 'MC ACESSORIO CAPRICHOSO']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'BAR', 'EMBALAGEMDESCAR']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- BAR / HORTIFRUTI  (1 insumo(s))
--   MP CEREJA FRESCA
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'BAR', 'HORTIFRUTI'],
       (c.valor #> ARRAY['Centro', 'BAR', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEREJA FRESCA']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'BAR', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'HORTIFRUTI'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEREJA FRESCA']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'BAR', 'HORTIFRUTI'],
       (c.valor #> ARRAY['Delivery P10', 'BAR', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEREJA FRESCA']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'BAR', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'BAR', 'HORTIFRUTI'],
       (c.valor #> ARRAY['Estoque Central', 'BAR', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEREJA FRESCA']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'BAR', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- BAR / NAO ALCOOLICAS  (4 insumo(s))
--   MP RED BULL DE MELANCIA, SODA LT, MP SODA LATA, MP BUDWEISER ZERO LN
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'BAR', U&'N\00c3O ALCOOLICAS'],
       (c.valor #> ARRAY['Centro', 'BAR', U&'N\00c3O ALCOOLICAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP RED BULL DE MELANCIA', 'SODA LT', 'MP SODA LATA', 'MP BUDWEISER ZERO LN']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'BAR', U&'N\00c3O ALCOOLICAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', U&'N\00c3O ALCOOLICAS'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', U&'N\00c3O ALCOOLICAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP RED BULL DE MELANCIA', 'SODA LT', 'MP SODA LATA', 'MP BUDWEISER ZERO LN']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', U&'N\00c3O ALCOOLICAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'BAR', U&'N\00c3O ALCOOLICAS'],
       (c.valor #> ARRAY['Delivery P10', 'BAR', U&'N\00c3O ALCOOLICAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP RED BULL DE MELANCIA', 'SODA LT', 'MP SODA LATA', 'MP BUDWEISER ZERO LN']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'BAR', U&'N\00c3O ALCOOLICAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'BAR', U&'N\00c3O ALCOOLICAS'],
       (c.valor #> ARRAY['Estoque Central', 'BAR', U&'N\00c3O ALCOOLICAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP RED BULL DE MELANCIA', 'SODA LT', 'MP SODA LATA', 'MP BUDWEISER ZERO LN']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'BAR', U&'N\00c3O ALCOOLICAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- BAR / SODA AMAZONENSE  (2 insumo(s))
--   PPB POLPA MARACUJA 200G, PPB XAROPE DE ACAI
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'BAR', 'SODA AMAZONENSE'],
       (c.valor #> ARRAY['Centro', 'BAR', 'SODA AMAZONENSE']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['PPB POLPA MARACUJA 200G', U&'PPB XAROPE DE A\00c7AI']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'BAR', 'SODA AMAZONENSE']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'SODA AMAZONENSE'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'SODA AMAZONENSE']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['PPB POLPA MARACUJA 200G', U&'PPB XAROPE DE A\00c7AI']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'BAR', 'SODA AMAZONENSE']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'BAR', 'SODA AMAZONENSE'],
       (c.valor #> ARRAY['Delivery P10', 'BAR', 'SODA AMAZONENSE']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['PPB POLPA MARACUJA 200G', U&'PPB XAROPE DE A\00c7AI']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'BAR', 'SODA AMAZONENSE']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'BAR', 'SODA AMAZONENSE'],
       (c.valor #> ARRAY['Estoque Central', 'BAR', 'SODA AMAZONENSE']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['PPB POLPA MARACUJA 200G', U&'PPB XAROPE DE A\00c7AI']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'BAR', 'SODA AMAZONENSE']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- COZINHA / CONGELADOS  (2 insumo(s))
--   FOLHA DE BANANEIRA, SA ISCA DE PIRARUCU FRESCO 80G
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'COZINHA', 'CONGELADOS'],
       (c.valor #> ARRAY['Centro', 'COZINHA', 'CONGELADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['FOLHA DE BANANEIRA', 'SA ISCA DE PIRARUCU FRESCO 80G']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'COZINHA', 'CONGELADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'CONGELADOS'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'CONGELADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['FOLHA DE BANANEIRA', 'SA ISCA DE PIRARUCU FRESCO 80G']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'CONGELADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'COZINHA', 'CONGELADOS'],
       (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'CONGELADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['FOLHA DE BANANEIRA', 'SA ISCA DE PIRARUCU FRESCO 80G']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'CONGELADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'COZINHA', 'CONGELADOS'],
       (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'CONGELADOS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['FOLHA DE BANANEIRA', 'SA ISCA DE PIRARUCU FRESCO 80G']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'CONGELADOS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- COZINHA / EMBALAGENS  (1 insumo(s))
--   MC EMBALAGEM TRANSPARENTE 250G
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'COZINHA', 'EMBALAGENS'],
       (c.valor #> ARRAY['Centro', 'COZINHA', 'EMBALAGENS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC EMBALAGEM TRANSPARENTE 250G']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'COZINHA', 'EMBALAGENS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'EMBALAGENS'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'EMBALAGENS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC EMBALAGEM TRANSPARENTE 250G']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'EMBALAGENS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'COZINHA', 'EMBALAGENS'],
       (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'EMBALAGENS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC EMBALAGEM TRANSPARENTE 250G']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'EMBALAGENS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'COZINHA', 'EMBALAGENS'],
       (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'EMBALAGENS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MC EMBALAGEM TRANSPARENTE 250G']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'EMBALAGENS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- COZINHA / ESTIVAS  (7 insumo(s))
--   MP CEBOLA EM PO, MP ALHO EM PO, MP PAPRICA DOCE, MP COMINHO EM PO, PPC OLEO DE URUCUM, MP CREME CULINARIO 1.LT, MP FEIJAO CARIOCA
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'COZINHA', 'ESTIVAS'],
       (c.valor #> ARRAY['Centro', 'COZINHA', 'ESTIVAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEBOLA EM PO', 'MP ALHO EM PO', 'MP PAPRICA DOCE', 'MP COMINHO EM PO', 'PPC OLEO DE URUCUM', 'MP CREME CULINARIO 1.LT', U&'MP FEIJ\00c3O CARIOCA']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'COZINHA', 'ESTIVAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'ESTIVAS'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'ESTIVAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEBOLA EM PO', 'MP ALHO EM PO', 'MP PAPRICA DOCE', 'MP COMINHO EM PO', 'PPC OLEO DE URUCUM', 'MP CREME CULINARIO 1.LT', U&'MP FEIJ\00c3O CARIOCA']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'ESTIVAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'COZINHA', 'ESTIVAS'],
       (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'ESTIVAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEBOLA EM PO', 'MP ALHO EM PO', 'MP PAPRICA DOCE', 'MP COMINHO EM PO', 'PPC OLEO DE URUCUM', 'MP CREME CULINARIO 1.LT', U&'MP FEIJ\00c3O CARIOCA']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'ESTIVAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'COZINHA', 'ESTIVAS'],
       (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'ESTIVAS']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP CEBOLA EM PO', 'MP ALHO EM PO', 'MP PAPRICA DOCE', 'MP COMINHO EM PO', 'PPC OLEO DE URUCUM', 'MP CREME CULINARIO 1.LT', U&'MP FEIJ\00c3O CARIOCA']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'ESTIVAS']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';
-- ---------------------------------------------------------------------------
-- COZINHA / HORTIFRUTI  (2 insumo(s))
--   MP ALHO, MP ALFACE AMERICANA REGIONAL
-- ---------------------------------------------------------------------------
UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Centro', 'COZINHA', 'HORTIFRUTI'],
       (c.valor #> ARRAY['Centro', 'COZINHA', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP ALHO', 'MP ALFACE AMERICANA REGIONAL']) AS n
           WHERE NOT (c.valor #> ARRAY['Centro', 'COZINHA', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'HORTIFRUTI'],
       (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP ALHO', 'MP ALFACE AMERICANA REGIONAL']) AS n
           WHERE NOT (c.valor #> ARRAY[U&'Produ\00e7\00e3o', 'COZINHA', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Delivery P10', 'COZINHA', 'HORTIFRUTI'],
       (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP ALHO', 'MP ALFACE AMERICANA REGIONAL']) AS n
           WHERE NOT (c.valor #> ARRAY['Delivery P10', 'COZINHA', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';

UPDATE inv_configuracoes c SET valor = jsonb_set(c.valor, ARRAY['Estoque Central', 'COZINHA', 'HORTIFRUTI'],
       (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'HORTIFRUTI']) || COALESCE((
          SELECT jsonb_agg(to_jsonb(n))
            FROM unnest(ARRAY['MP ALHO', 'MP ALFACE AMERICANA REGIONAL']) AS n
           WHERE NOT (c.valor #> ARRAY['Estoque Central', 'COZINHA', 'HORTIFRUTI']) @> to_jsonb(n)), '[]'::jsonb))
 WHERE c.chave = 'estrutura';


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Cada grupo deve ter crescido o numero de insumos, e
-- igual nas 4 unidades.
-- ============================================================================
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo,
       jsonb_array_length(grupo.value) AS itens
FROM inv_configuracoes c,
     jsonb_each(c.valor) unid, jsonb_each(unid.value) setor, jsonb_each(setor.value) grupo
WHERE c.chave = 'estrutura'
  AND (setor.key, grupo.key) IN (('BAR', 'DESTILADOS'), ('BAR', 'EMBALAGEMDESCAR'), ('BAR', 'HORTIFRUTI'), ('BAR', U&'N\00c3O ALCOOLICAS'), ('BAR', 'SODA AMAZONENSE'), ('COZINHA', 'CONGELADOS'), ('COZINHA', 'EMBALAGENS'), ('COZINHA', 'ESTIVAS'), ('COZINHA', 'HORTIFRUTI'))
ORDER BY 2, 3, 1;
