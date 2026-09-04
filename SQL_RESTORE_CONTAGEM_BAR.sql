-- RESTAURA os itens que sumiram da contagem (BAR e COZINHA).
-- 1) Re-adiciona nos grupos certos (mescla com o que ja existe, conserta o BAR|ALCOOLICAS que estava null)
-- 2) Tira da lista de EXCLUIDOS so os 5 que devem voltar (mantem os demais que sao pra ficar excluidos)
-- BLOCO DO = UMA unica instrucao. Nao mexe em estrutura nem em financeiro.

DO $$
DECLARE
  a jsonb;
  e jsonb;
BEGIN
  SELECT valor INTO a FROM inv_configuracoes WHERE chave = 'adicoes';
  SELECT valor INTO e FROM inv_configuracoes WHERE chave = 'excluidos';
  IF a IS NULL THEN a := '{}'::jsonb; END IF;
  IF e IS NULL THEN e := '[]'::jsonb; END IF;

  -- BAR|ALCOOLICAS (estava null) -> substitui por lista real
  a := jsonb_set(a, ARRAY['BAR|ALCOOLICAS'],
        (CASE WHEN jsonb_typeof(a->'BAR|ALCOOLICAS')='array' THEN a->'BAR|ALCOOLICAS' ELSE '[]'::jsonb END)
        || '["MP SPATEN 600ml","MP STELLA ARTOIS 600ML","MP BUDWEISER LN","MP BRAHMA DUPLO MALTE 600ML","MP COLORADO RIBEIRÃO LAGER"]'::jsonb, true);

  -- BAR|NÃO ALCOOLICAS
  a := jsonb_set(a, ARRAY['BAR|NÃO ALCOOLICAS'],
        (CASE WHEN jsonb_typeof(a->'BAR|NÃO ALCOOLICAS')='array' THEN a->'BAR|NÃO ALCOOLICAS' ELSE '[]'::jsonb END)
        || '["MP GUARANA ANTARTICA LATA"]'::jsonb, true);

  -- BAR|DESTILADOS
  a := jsonb_set(a, ARRAY['BAR|DESTILADOS'],
        (CASE WHEN jsonb_typeof(a->'BAR|DESTILADOS')='array' THEN a->'BAR|DESTILADOS' ELSE '[]'::jsonb END)
        || '["MP XAROPE DE LARANJA"]'::jsonb, true);

  -- BAR|ESTIVAS
  a := jsonb_set(a, ARRAY['BAR|ESTIVAS'],
        (CASE WHEN jsonb_typeof(a->'BAR|ESTIVAS')='array' THEN a->'BAR|ESTIVAS' ELSE '[]'::jsonb END)
        || '["MP CORANTE AZUL","MP CORANTE VERMELHO","MP EMULSIFICANTE","MP MELADO DE CANA","MP MEL DE ABELHA","MP CANELA EM PO","MP LEITE CONDENSADO","MP CAPSULA DE GAS","MP BASTÃO DE GUARANA"]'::jsonb, true);

  -- COZINHA|CONGELADOS
  a := jsonb_set(a, ARRAY['COZINHA|CONGELADOS'],
        (CASE WHEN jsonb_typeof(a->'COZINHA|CONGELADOS')='array' THEN a->'COZINHA|CONGELADOS' ELSE '[]'::jsonb END)
        || '["MP COSTELA DE TAMBAQUI"]'::jsonb, true);

  UPDATE inv_configuracoes SET valor = a WHERE chave = 'adicoes';

  -- Remove da exclusao SO os 5 que devem voltar (todos os outros continuam excluidos)
  SELECT COALESCE(jsonb_agg(x), '[]'::jsonb) INTO e
    FROM jsonb_array_elements_text(e) AS t(x)
   WHERE x NOT IN (
     'MP SPATEN 600ML',
     'MP STELLA ARTOIS 600ML',
     'MP BUDWEISER LN',
     'MP GUARANA ANTARTICA LATA',
     'MP COSTELA DE TAMBAQUI'
   );
  UPDATE inv_configuracoes SET valor = e WHERE chave = 'excluidos';
END $$;
