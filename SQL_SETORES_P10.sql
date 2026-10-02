-- ============================================================================
-- DELIVERY P10: SETORES PROPRIOS   (02/10/2026)
--
-- Pedido do Wagner, so no Delivery P10 (o Centro nao muda):
--   - sai BAR e SALAO;
--   - ASG vira MATERIAL DE LIMPEZA;
--   - os grupos do DELIVERY (BEBIDAS e DESCARTAVEL) viram setores proprios;
--   - o setor DELIVERY sai.
-- Fica: CHURRASQUEIRA, COZINHA, MATERIAL DE LIMPEZA, BEBIDAS, DESCARTAVEL,
--       ESTOQUE DELIVERY.
--
-- As listas novas sao EXATAMENTE o que o P10 enxerga hoje nesses grupos (a lista
-- menos os excluidos, mais o que foi adicionado com "+"). Assim nada some e nada
-- aparece de novo. O pedido padrao vem junto (42 produtos) e os PINs tambem:
-- MATERIAL DE LIMPEZA nasce com o PIN do ASG; BEBIDAS e DESCARTAVEL com o do
-- DELIVERY (troque em PINs Mobile se quiser PIN proprio).
--
-- Backup: bkp_setores_p10_config (estrutura, padroes, pins e adicoes de antes), com RLS.
-- Depois de rodar: F5 no computador e nos celulares.
-- ============================================================================

-- PASSO 1 (so leitura): setores do P10 hoje (esperado 7)
SELECT jsonb_object_keys(valor->'Delivery P10') AS setor_p10 FROM inv_configuracoes WHERE chave = 'estrutura';

-- PASSO 2
BEGIN;
CREATE TABLE bkp_setores_p10_config AS SELECT * FROM inv_configuracoes WHERE chave IN ('estrutura','padroes','pins','adicoes');
ALTER TABLE bkp_setores_p10_config ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF (SELECT count(*) FROM inv_configuracoes c, jsonb_object_keys(c.valor->'Delivery P10') k WHERE c.chave='estrutura') <> 7
  OR NOT (SELECT (valor->'Delivery P10') ?& ARRAY['BAR','SALAO','ASG','DELIVERY'] FROM inv_configuracoes WHERE chave='estrutura')
  OR (SELECT (valor->'Delivery P10') ?| ARRAY['MATERIAL DE LIMPEZA','BEBIDAS','DESCARTAVEL'] FROM inv_configuracoes WHERE chave='estrutura') THEN
    RAISE EXCEPTION 'Os setores do P10 mudaram desde a analise. Nada foi feito.';
  END IF;
END $$;

-- 2a) estrutura: so o Delivery P10
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, ARRAY['Delivery P10'],
         ((valor->'Delivery P10') - 'BAR' - 'SALAO' - 'ASG' - 'DELIVERY') || '{"MATERIAL DE LIMPEZA": {"MATERIAL DE LIMPEZA": ["MC SACO DE LIXO - 50LT", "MC SACO DE LIXO - 200LT", "MC DETERGENTE NEUTRO 5 L", "MC PROTETOR DE ASSENTO SANITARIO", "MC DESINFETANTE CONCENTRADO", "MC AGUA SANITARIA", "MC ESPONJA COMUM", "MC SABONETE TORK ESPUMA 1000ML C/CHEIRO", "MC SABONETE BACTERICIDA", "MC LUVA DE LIMPEZA", "MC PAPEL HIGIENICO TORK SMART ONE", "MC PAPEL HIGIENICO FUNCIONARIO", "MC PAPEL TOALHA CLIENTE TORK", "MC PAPEL ROLO COZINHA TORK HANDTOWEL", "MC PAPEL TOLHA ROLO TORK ADV 4/250M FS", "MC ALCOOL EM GEL", "MC FIBRA PESADA", "MC X-12", "MC PEROXY 3000", "MC LIMPA ALUMINIO", "MC LIMPA VIDRO 5LT", "MC CLEARON", "MC PANO DE CH\u00c3O", "MC PERFEX WIPE", "MC MOP"]}, "BEBIDAS": {"BEBIDAS": ["MP GUARANA ANTARTICA LATA"]}, "DESCARTAVEL": {"DESCARTAVEL": ["MC GARFO REFEI\u00c7\u00c3O", "MC COLHER REFEI\u00c7\u00c3O DESCARTAVEIS", "MC FACA REFEI\u00c7\u00c3O", "MC PRATO DESCARTAVEL", "MC SACOLA BRANCA 8KG", "MC FITA DUREX 50X50"]}}'::jsonb)
 WHERE chave = 'estrutura';

-- 2b) pedido padrao: copia para as chaves dos setores novos (as antigas ficam: o Centro usa)
UPDATE inv_configuracoes
   SET valor = valor || COALESCE((
         SELECT jsonb_object_agg(
                  CASE WHEN key LIKE 'ASG|MATERIAL DE LIMPEZA|%' THEN 'MATERIAL DE LIMPEZA|MATERIAL DE LIMPEZA|' || substr(key, length('ASG|MATERIAL DE LIMPEZA|') + 1)
                       WHEN key LIKE 'DELIVERY|BEBIDAS|%'        THEN 'BEBIDAS|BEBIDAS|'           || substr(key, length('DELIVERY|BEBIDAS|') + 1)
                       ELSE                                           'DESCARTAVEL|DESCARTAVEL|'   || substr(key, length('DELIVERY|DESCARTAVEL|') + 1) END,
                  value)
           FROM jsonb_each(valor)
          WHERE key LIKE 'ASG|MATERIAL DE LIMPEZA|%' OR key LIKE 'DELIVERY|BEBIDAS|%' OR key LIKE 'DELIVERY|DESCARTAVEL|%'), '{}'::jsonb)
 WHERE chave = 'padroes';

-- 2b2) o que foi adicionado com "+" nesses grupos vai para as chaves dos setores novos
--      (as chaves antigas ficam: o Centro usa)
UPDATE inv_configuracoes SET valor = valor || '{"BEBIDAS|BEBIDAS": ["MP BARE DE 2 LITROS", "MP BARE 1 LITRO", "MP COCA COLA 1,5 L", "MP COCA COLA LATA", "MP COCA COLA ZERO LATA", "MP COCA COLA ZERO 1,5L", "MP GUARANA ANTARTICA ZERO 2 L"], "DESCARTAVEL|DESCARTAVEL": ["MC SACOLA ROTEROS", "MC CAIXA DE PEIXE", "MC COLHER SOBREMESA - BRANCA", "MP PAPEL MANTEIGA", "MC LACRE ROTEROS", "MC SACO DE DINDIN GRANDE"]}'::jsonb WHERE chave = 'adicoes';

-- 2c) PINs: os setores novos nascem com o PIN de onde vieram (so se ainda nao tiverem)
UPDATE inv_configuracoes
   SET valor = valor
       || CASE WHEN valor ? 'ASG'      AND NOT valor ? 'MATERIAL DE LIMPEZA' THEN jsonb_build_object('MATERIAL DE LIMPEZA', valor->'ASG') ELSE '{}'::jsonb END
       || CASE WHEN valor ? 'DELIVERY' AND NOT valor ? 'BEBIDAS'             THEN jsonb_build_object('BEBIDAS', valor->'DELIVERY') ELSE '{}'::jsonb END
       || CASE WHEN valor ? 'DELIVERY' AND NOT valor ? 'DESCARTAVEL'         THEN jsonb_build_object('DESCARTAVEL', valor->'DELIVERY') ELSE '{}'::jsonb END
 WHERE chave = 'pins';

-- 2d) conferencia dentro da transacao
DO $$
BEGIN
  IF (SELECT count(*) FROM inv_configuracoes c, jsonb_object_keys(c.valor->'Delivery P10') k WHERE c.chave='estrutura') <> 6 THEN
    RAISE EXCEPTION 'O P10 nao ficou com 6 setores';
  END IF;
  IF (SELECT count(*) FROM inv_configuracoes c, jsonb_object_keys(c.valor->'Centro') k WHERE c.chave='estrutura')
  <> (SELECT count(*) FROM bkp_setores_p10_config b, jsonb_object_keys(b.valor->'Centro') k WHERE b.chave='estrutura') THEN
    RAISE EXCEPTION 'O Centro mudou - nao era para mexer';
  END IF;
  IF (SELECT count(*) FROM inv_configuracoes c, jsonb_object_keys(c.valor) k WHERE c.chave='padroes')
  <> (SELECT count(*) FROM bkp_setores_p10_config b, jsonb_object_keys(b.valor) k WHERE b.chave='padroes') + 42 THEN
    RAISE EXCEPTION 'Pedido padrao nao ficou com 42 chaves a mais';
  END IF;
END $$;
COMMIT;

-- PASSO 3 (conferencia): setores do P10 agora (esperado 6: BEBIDAS, CHURRASQUEIRA, COZINHA, DESCARTAVEL, ESTOQUE DELIVERY, MATERIAL DE LIMPEZA)
SELECT jsonb_object_keys(valor->'Delivery P10') AS setor_p10 FROM inv_configuracoes WHERE chave = 'estrutura';
