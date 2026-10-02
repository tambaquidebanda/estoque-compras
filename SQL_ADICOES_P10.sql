-- ============================================================================
-- ADICOES ("+") DO DELIVERY P10 SEPARADAS DO CENTRO   (02/10/2026)
--
-- A adicao ("+") era guardada so por "SETOR|GRUPO". A Cozinha e a Churrasqueira
-- do P10 tem o mesmo nome das do Centro: adicionar ou remover um produto
-- adicionado no P10 mexia tambem no Centro.
--
-- O codigo novo (Push depois deste SQL) le, no P10, a chave
-- "Delivery P10>SETOR|GRUPO". Este SQL COPIA as adicoes de hoje da Cozinha e da
-- Churrasqueira para essas chaves, para o P10 continuar vendo exatamente o que ve.
-- As chaves antigas ficam (o Centro usa). So acrescenta - nao apaga nada.
--
-- RODAR ANTES do Push. Se rodar duas vezes, nao duplica (so copia o que falta).
-- ============================================================================

-- PASSO 1 (so leitura): o que vai ser copiado (esperado 6 chaves, 19 produtos)
SELECT key AS chave_centro, 'Delivery P10>' || key AS chave_p10, jsonb_array_length(value) AS produtos
  FROM inv_configuracoes, jsonb_each(valor)
 WHERE chave = 'adicoes'
   AND split_part(key, '|', 1) IN ('COZINHA', 'CHURRASQUEIRA')
   AND position('>' in key) = 0
 ORDER BY 1;

-- PASSO 2
BEGIN;
CREATE TABLE bkp_adicoes_p10 AS SELECT * FROM inv_configuracoes WHERE chave = 'adicoes';
ALTER TABLE bkp_adicoes_p10 ENABLE ROW LEVEL SECURITY;

UPDATE inv_configuracoes
   SET valor = valor || COALESCE((
         SELECT jsonb_object_agg('Delivery P10>' || key, value)
           FROM jsonb_each(valor)
          WHERE split_part(key, '|', 1) IN ('COZINHA', 'CHURRASQUEIRA')
            AND position('>' in key) = 0
            AND NOT valor ? ('Delivery P10>' || key)), '{}'::jsonb)
 WHERE chave = 'adicoes';

DO $$
BEGIN
  IF (SELECT count(*) FROM inv_configuracoes, jsonb_object_keys(valor) k
       WHERE chave = 'adicoes' AND k LIKE 'Delivery P10>%') <> 6 THEN
    RAISE EXCEPTION 'Esperava 6 chaves do P10';
  END IF;
END $$;
COMMIT;

-- PASSO 3 (conferencia): 6 chaves do P10, 19 produtos
SELECT key, jsonb_array_length(value) AS produtos
  FROM inv_configuracoes, jsonb_each(valor)
 WHERE chave = 'adicoes' AND key LIKE 'Delivery P10>%'
 ORDER BY 1;
