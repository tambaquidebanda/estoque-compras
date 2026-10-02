-- ============================================================================
-- SA FILE DE FRANGO 100g: tira de novo as linhas repetidas   (02/10/2026)
--
-- O SQL_UNIFICAR_FILE_FRANGO (30/09) deixou 1 linha por tela (5 no total). Entre
-- 30/09 e 02/10 uma tela aberta desde antes de 30/09 renomeou produtos e, ao
-- renomear, regravou TODAS as listas com a copia velha da memoria - as linhas
-- repetidas voltaram (9). Esse caminho foi fechado no d071e86 (renomear le do
-- banco + trava contra gravar lista velha).
--
-- Aqui: em cada uma das 4 listas com repeticao, fica a PRIMEIRA linha do frango
-- 100g e sai a repetida ("100G" ou "100g" de novo). Nada mais muda.
-- ============================================================================

-- PASSO 1 (so leitura): esperado 9
SELECT (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
               jsonb_array_elements_text(g.value) n
         WHERE c.chave = 'estrutura' AND upper(n) = 'SA FILE DE FRANGO 100G') AS linhas_frango_100g;

-- PASSO 2
BEGIN;
CREATE TABLE bkp_frango_dup2 AS SELECT * FROM inv_configuracoes WHERE chave = 'estrutura';
ALTER TABLE bkp_frango_dup2 ENABLE ROW LEVEL SECURITY;

UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['Centro','COZINHA','CONGELADOS'], (
         SELECT jsonb_agg(e.v ORDER BY e.o)
           FROM jsonb_array_elements(valor #> ARRAY['Centro','COZINHA','CONGELADOS']) WITH ORDINALITY e(v, o)
          WHERE upper(e.v #>> '{}') <> 'SA FILE DE FRANGO 100G'
             OR e.o = (SELECT min(o2) FROM jsonb_array_elements(valor #> ARRAY['Centro','COZINHA','CONGELADOS']) WITH ORDINALITY x(v2, o2)
                        WHERE upper(x.v2 #>> '{}') = 'SA FILE DE FRANGO 100G')))
 WHERE chave = 'estrutura';
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['Delivery P10','COZINHA','CONGELADOS'], (
         SELECT jsonb_agg(e.v ORDER BY e.o)
           FROM jsonb_array_elements(valor #> ARRAY['Delivery P10','COZINHA','CONGELADOS']) WITH ORDINALITY e(v, o)
          WHERE upper(e.v #>> '{}') <> 'SA FILE DE FRANGO 100G'
             OR e.o = (SELECT min(o2) FROM jsonb_array_elements(valor #> ARRAY['Delivery P10','COZINHA','CONGELADOS']) WITH ORDINALITY x(v2, o2)
                        WHERE upper(x.v2 #>> '{}') = 'SA FILE DE FRANGO 100G')))
 WHERE chave = 'estrutura';
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY[U&'Produ\00e7\00e3o','PRODUCAO','SA CONGELADOS'], (
         SELECT jsonb_agg(e.v ORDER BY e.o)
           FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o','PRODUCAO','SA CONGELADOS']) WITH ORDINALITY e(v, o)
          WHERE upper(e.v #>> '{}') <> 'SA FILE DE FRANGO 100G'
             OR e.o = (SELECT min(o2) FROM jsonb_array_elements(valor #> ARRAY[U&'Produ\00e7\00e3o','PRODUCAO','SA CONGELADOS']) WITH ORDINALITY x(v2, o2)
                        WHERE upper(x.v2 #>> '{}') = 'SA FILE DE FRANGO 100G')))
 WHERE chave = 'estrutura';
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['Estoque Central','ESTOQUE CENTRAL','SA CONGELADOS'], (
         SELECT jsonb_agg(e.v ORDER BY e.o)
           FROM jsonb_array_elements(valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL','SA CONGELADOS']) WITH ORDINALITY e(v, o)
          WHERE upper(e.v #>> '{}') <> 'SA FILE DE FRANGO 100G'
             OR e.o = (SELECT min(o2) FROM jsonb_array_elements(valor #> ARRAY['Estoque Central','ESTOQUE CENTRAL','SA CONGELADOS']) WITH ORDINALITY x(v2, o2)
                        WHERE upper(x.v2 #>> '{}') = 'SA FILE DE FRANGO 100G')))
 WHERE chave = 'estrutura';

DO $$
BEGIN
  IF (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
               jsonb_array_elements_text(g.value) n
         WHERE c.chave = 'estrutura' AND upper(n) = 'SA FILE DE FRANGO 100G') <> 5 THEN
    RAISE EXCEPTION 'Esperava 5 linhas do frango 100g (1 por tela)';
  END IF;
  IF (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
             jsonb_array_elements_text(g.value) n WHERE c.chave = 'estrutura')
   - (SELECT count(*) FROM bkp_frango_dup2 c, jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
             jsonb_array_elements_text(g.value) n) <> -4 THEN
    RAISE EXCEPTION 'Saiu mais (ou menos) do que as 4 linhas repetidas';
  END IF;
END $$;
COMMIT;

-- PASSO 3 (conferencia): esperado 5
SELECT (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
               jsonb_array_elements_text(g.value) n
         WHERE c.chave = 'estrutura' AND upper(n) = 'SA FILE DE FRANGO 100G') AS linhas_frango_100g;
