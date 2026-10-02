-- ============================================================================
-- DESFAZ A EXCLUSAO QUE VAZOU DO DELIVERY P10 PARA O CENTRO   (02/10/2026)
--
-- Excluir um produto da contagem gravava numa lista UNICA (inv_configuracoes
-- 'excluidos'), sem unidade. Os produtos excluidos no Delivery P10 sumiram
-- tambem do Centro. Achados: 26 nomes que estao na lista de excluidos mas foram
-- contados no Centro em 01/10 ou 02/10 (ou seja, foram excluidos depois).
--
-- Este SQL:
--   1. tira os 26 nomes de cada lista do Delivery P10 (estrutura do P10) - o P10
--      continua SEM eles, como voce deixou;
--   2. tira os 26 nomes da lista unica de excluidos - eles VOLTAM para o Centro.
-- Backup: bkp_excl_p10_config (estrutura e excluidos de antes), com RLS.
-- Depois de rodar: F5 nas telas de Contagem (computador e celular).
-- ============================================================================

-- PASSO 1 (so leitura): esperado excluidos=101, no P10=41, no Centro=35
BEGIN;
CREATE TEMP TABLE IF NOT EXISTS _n(nome text);
TRUNCATE _n;
INSERT INTO _n(nome) VALUES
  ('MC CAIXA DE PEIXE'),
  ('MC COPO DESCARTAVEL 300ML'),
  ('MC EMBALAGEM G742'),
  ('MC EMBALAGEM TRANSPARENTE 250G'),
  (U&'MP AGUA COM G\00c1S'),
  (U&'MP AGUA SEM G\00c1S'),
  ('MP ALFAVACA'),
  ('MP ALHO'),
  ('MP ALHO EM PO'),
  (U&'MP A\00c7AI'),
  ('MP BUDWEISER LN'),
  ('MP CEBOLA EM PO'),
  ('MP COMINHO EM PO'),
  (U&'MP FEIJ\00c3O CARIOCA'),
  ('MP LEITE LIQUIDO INTEGRAL'),
  ('MP MATRINXA'),
  ('MP PAPRICA DOCE'),
  ('MP PEPSI BLACK LATA'),
  ('MP PEPSI LATA'),
  ('MP SEMENTE DE URUCUM'),
  ('MP STELLA ARTOIS 600ML'),
  ('MP SUKITA LATA'),
  ('MP TAMBAQUI CASACA (2,3KG)'),
  ('MP VINHO TINTO SUAVE 750ML'),
  ('SA DADINHO DE TAPIOCA 6 UNID'),
  ('SA MACAXEIRA 300G');

SELECT (SELECT jsonb_array_length(valor) FROM inv_configuracoes WHERE chave='excluidos') AS excluidos,
       (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor->'Delivery P10') s, jsonb_each(s.value) g,
               jsonb_array_elements_text(g.value) e WHERE c.chave='estrutura' AND e IN (SELECT nome FROM _n)) AS no_p10,
       (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor->'Centro') s, jsonb_each(s.value) g,
               jsonb_array_elements_text(g.value) e WHERE c.chave='estrutura' AND e IN (SELECT nome FROM _n)) AS no_centro;

-- PASSO 2
CREATE TABLE bkp_excl_p10_config AS SELECT * FROM inv_configuracoes WHERE chave IN ('estrutura','excluidos');
ALTER TABLE bkp_excl_p10_config ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF (SELECT count(*) FROM _n) <> 26 OR (SELECT count(DISTINCT nome) FROM _n) <> 26 THEN
    RAISE EXCEPTION 'Lista de nomes com tamanho errado';
  END IF;
  IF (SELECT jsonb_array_length(valor) FROM inv_configuracoes WHERE chave='excluidos') <> 101 THEN
    RAISE EXCEPTION 'A lista de excluidos mudou desde a analise (alguem excluiu mais). Nada foi feito.';
  END IF;
END $$;

-- 2a) P10: tira os nomes de todas as listas do P10 (mantem a ordem do resto)
UPDATE inv_configuracoes c
   SET valor = jsonb_set(c.valor, ARRAY['Delivery P10'], (
         SELECT jsonb_object_agg(s.key, (
                  SELECT jsonb_object_agg(g.key, COALESCE((
                           SELECT jsonb_agg(e.v ORDER BY e.o)
                             FROM jsonb_array_elements(g.value) WITH ORDINALITY e(v, o)
                            WHERE (e.v #>> '{}') NOT IN (SELECT nome FROM _n)), '[]'::jsonb))
                    FROM jsonb_each(s.value) g))
           FROM jsonb_each(c.valor->'Delivery P10') s))
 WHERE c.chave = 'estrutura';

-- 2b) excluidos: tira os nomes (eles voltam para o Centro)
UPDATE inv_configuracoes
   SET valor = (SELECT COALESCE(jsonb_agg(e.v ORDER BY e.o), '[]'::jsonb)
                  FROM jsonb_array_elements(valor) WITH ORDINALITY e(v, o)
                 WHERE (e.v #>> '{}') NOT IN (SELECT nome FROM _n))
 WHERE chave = 'excluidos';

-- 2c) conferencia dentro da transacao
DO $$
DECLARE x int; p int; c int; gp int; gpa int;
BEGIN
  SELECT jsonb_array_length(valor) INTO x FROM inv_configuracoes WHERE chave='excluidos';
  SELECT count(*) INTO p FROM inv_configuracoes cc, jsonb_each(cc.valor->'Delivery P10') s, jsonb_each(s.value) g,
         jsonb_array_elements_text(g.value) e WHERE cc.chave='estrutura' AND e IN (SELECT nome FROM _n);
  SELECT count(*) INTO c FROM inv_configuracoes cc, jsonb_each(cc.valor->'Centro') s, jsonb_each(s.value) g,
         jsonb_array_elements_text(g.value) e WHERE cc.chave='estrutura' AND e IN (SELECT nome FROM _n);
  SELECT count(*) INTO gp  FROM inv_configuracoes cc, jsonb_each(cc.valor->'Delivery P10') s, jsonb_each(s.value) g WHERE cc.chave='estrutura';
  SELECT count(*) INTO gpa FROM bkp_excl_p10_config b, jsonb_each(b.valor->'Delivery P10') s, jsonb_each(s.value) g WHERE b.chave='estrutura';
  IF x <> 75 THEN RAISE EXCEPTION 'excluidos ficou com % (esperado 75)', x; END IF;
  IF p <> 0 THEN RAISE EXCEPTION 'ainda ha % nomes no P10', p; END IF;
  IF c <> 35 THEN RAISE EXCEPTION 'o Centro mudou: % (esperado 35)', c; END IF;
  IF gp <> gpa THEN RAISE EXCEPTION 'o P10 perdeu grupos: % de %', gp, gpa; END IF;
END $$;

COMMIT;

-- PASSO 3 (conferencia): esperado excluidos=75, no P10=0, no Centro=35
SELECT (SELECT jsonb_array_length(valor) FROM inv_configuracoes WHERE chave='excluidos') AS excluidos,
       (SELECT count(*) FROM inv_configuracoes c, jsonb_each(c.valor->'Delivery P10') s, jsonb_each(s.value) g,
               jsonb_array_elements_text(g.value) e WHERE c.chave='estrutura' AND e IN (SELECT nome FROM _n)) AS no_p10;
