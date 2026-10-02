-- ============================================================================
-- DESFAZ A EXCLUSAO QUE VAZOU DO DELIVERY P10 PARA O CENTRO   (02/10/2026)
--
-- Excluir um produto da contagem gravava numa lista UNICA ('excluidos'), sem
-- unidade: o que o Wagner tirou do P10 sumiu tambem do Centro (e do Central,
-- da Producao e do Estoque Delivery, onde o nome aparece).
--
-- Os 6 produtos que o Wagner excluiu no P10 hoje:
--   CHURRASQUEIRA / PEIXES : MP TAMBAQUI CASACA (2,3KG), MP COSTELA DE TAMBAQUI, MP MATRINXA
--   COZINHA / CONGELADOS   : SA DADINHO DE TAPIOCA 6 UNID, SA MACAXEIRA 300G, MP ACAI
--     (dadinho ele lembrou; macaxeira e acai sao os 2 outros do grupo que o Centro
--      ainda contava em 01/10 - os demais excluidos do grupo sao antigos)
--
-- Este SQL:
--   1. tira os 6 SO desses dois grupos do Delivery P10 (o P10 fica como ele deixou);
--   2. tira os 6 da lista unica de excluidos: voltam para o Centro e para as
--      outras listas onde estavam.
-- Backup: bkp_excl_p10_config, com RLS. Depois: F5 nas telas de Contagem.
-- ============================================================================

-- PASSO 1 (so leitura): esperado excluidos=101, churrasqueira/peixes=4, cozinha/congelados=48
SELECT jsonb_array_length((SELECT valor FROM inv_configuracoes WHERE chave='excluidos')) AS excluidos,
       jsonb_array_length(valor #> ARRAY['Delivery P10','CHURRASQUEIRA','PEIXES']) AS p10_churrasq_peixes,
       jsonb_array_length(valor #> ARRAY['Delivery P10','COZINHA','CONGELADOS']) AS p10_cozinha_congelados
  FROM inv_configuracoes WHERE chave = 'estrutura';

-- PASSO 2
BEGIN;
CREATE TABLE bkp_excl_p10_config AS SELECT * FROM inv_configuracoes WHERE chave IN ('estrutura','excluidos');
ALTER TABLE bkp_excl_p10_config ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(valor) FROM inv_configuracoes WHERE chave='excluidos') <> 101 THEN
    RAISE EXCEPTION 'A lista de excluidos mudou desde a analise (alguem excluiu mais). Nada foi feito.';
  END IF;
END $$;

-- 2a) P10: tira so dos dois grupos que o Wagner mexeu
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['Delivery P10','CHURRASQUEIRA','PEIXES'],
         (SELECT COALESCE(jsonb_agg(e.v ORDER BY e.o), '[]'::jsonb)
            FROM jsonb_array_elements(valor #> ARRAY['Delivery P10','CHURRASQUEIRA','PEIXES']) WITH ORDINALITY e(v, o)
           WHERE (e.v #>> '{}') NOT IN ('MP TAMBAQUI CASACA (2,3KG)', 'MP COSTELA DE TAMBAQUI', 'MP MATRINXA')))
 WHERE chave = 'estrutura';
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['Delivery P10','COZINHA','CONGELADOS'],
         (SELECT COALESCE(jsonb_agg(e.v ORDER BY e.o), '[]'::jsonb)
            FROM jsonb_array_elements(valor #> ARRAY['Delivery P10','COZINHA','CONGELADOS']) WITH ORDINALITY e(v, o)
           WHERE (e.v #>> '{}') NOT IN ('SA DADINHO DE TAPIOCA 6 UNID', 'SA MACAXEIRA 300G', U&'MP A\00c7AI')))
 WHERE chave = 'estrutura';

-- 2b) excluidos: tira os 6 (voltam para o Centro)
UPDATE inv_configuracoes
   SET valor = (SELECT COALESCE(jsonb_agg(e.v ORDER BY e.o), '[]'::jsonb)
                  FROM jsonb_array_elements(valor) WITH ORDINALITY e(v, o)
                 WHERE (e.v #>> '{}') NOT IN ('MP TAMBAQUI CASACA (2,3KG)', 'MP COSTELA DE TAMBAQUI', 'MP MATRINXA', 'SA DADINHO DE TAPIOCA 6 UNID', 'SA MACAXEIRA 300G', U&'MP A\00c7AI'))
 WHERE chave = 'excluidos';

-- 2c) conferencia dentro da transacao
DO $$
BEGIN
  IF (SELECT jsonb_array_length(valor) FROM inv_configuracoes WHERE chave='excluidos') <> 95 THEN
    RAISE EXCEPTION 'excluidos nao ficou com 95';
  END IF;
  IF (SELECT jsonb_array_length(valor #> ARRAY['Delivery P10','CHURRASQUEIRA','PEIXES']) FROM inv_configuracoes WHERE chave='estrutura') <> 1
  OR (SELECT jsonb_array_length(valor #> ARRAY['Delivery P10','COZINHA','CONGELADOS']) FROM inv_configuracoes WHERE chave='estrutura') <> 45 THEN
    RAISE EXCEPTION 'os grupos do P10 nao ficaram com 3 a menos cada';
  END IF;
END $$;
COMMIT;

-- PASSO 3 (conferencia): esperado excluidos=95, churrasqueira/peixes=1, cozinha/congelados=45
SELECT jsonb_array_length((SELECT valor FROM inv_configuracoes WHERE chave='excluidos')) AS excluidos,
       jsonb_array_length(valor #> ARRAY['Delivery P10','CHURRASQUEIRA','PEIXES']) AS p10_churrasq_peixes,
       jsonb_array_length(valor #> ARRAY['Delivery P10','COZINHA','CONGELADOS']) AS p10_cozinha_congelados
  FROM inv_configuracoes WHERE chave = 'estrutura';
