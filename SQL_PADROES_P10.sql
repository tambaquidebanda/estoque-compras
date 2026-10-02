-- ============================================================================
-- PEDIDO PADRAO DO DELIVERY P10 SEPARADO DO CENTRO   (02/10/2026)
--
-- O pedido padrao e guardado por "SETOR|GRUPO|PRODUTO". A Cozinha e a
-- Churrasqueira do P10 tem o mesmo nome das do Centro: mudar o padrao no P10
-- mudava no Centro (e vice-versa).
--
-- O codigo novo (Push depois deste SQL) le, no P10, "Delivery P10>SETOR|GRUPO|PRODUTO".
-- Este SQL COPIA o padrao de hoje da Cozinha e da Churrasqueira para essas chaves:
-- o P10 comeca com o mesmo padrao que usa hoje e, dai em diante, cada loja muda o seu.
-- Material de Limpeza, Bebidas, Descartavel e Estoque Delivery ja sao so do P10.
-- As chaves antigas ficam (o Centro usa). So acrescenta - nao apaga nada.
--
-- RODAR ANTES do Push. Rodar duas vezes nao duplica.
-- ============================================================================

-- PASSO 1 (so leitura): quantos padroes vao ser copiados (esperado 177: Cozinha 161 + Churrasqueira 16)
SELECT split_part(key, '|', 1) AS setor, count(*) AS produtos
  FROM inv_configuracoes, jsonb_each(valor)
 WHERE chave = 'padroes'
   AND split_part(key, '|', 1) IN ('COZINHA', 'CHURRASQUEIRA')
   AND position('>' in key) = 0
 GROUP BY 1 ORDER BY 1;

-- PASSO 2
BEGIN;
CREATE TABLE bkp_padroes_p10 AS SELECT * FROM inv_configuracoes WHERE chave = 'padroes';
ALTER TABLE bkp_padroes_p10 ENABLE ROW LEVEL SECURITY;

UPDATE inv_configuracoes
   SET valor = valor || COALESCE((
         SELECT jsonb_object_agg('Delivery P10>' || key, value)
           FROM jsonb_each(valor)
          WHERE split_part(key, '|', 1) IN ('COZINHA', 'CHURRASQUEIRA')
            AND position('>' in key) = 0
            AND NOT valor ? ('Delivery P10>' || key)), '{}'::jsonb)
 WHERE chave = 'padroes';

DO $$
BEGIN
  IF (SELECT count(*) FROM inv_configuracoes, jsonb_object_keys(valor) k
       WHERE chave = 'padroes' AND k LIKE 'Delivery P10>%')
  <> (SELECT count(*) FROM bkp_padroes_p10, jsonb_object_keys(valor) k
       WHERE split_part(k, '|', 1) IN ('COZINHA', 'CHURRASQUEIRA') AND position('>' in k) = 0) THEN
    RAISE EXCEPTION 'A copia nao bateu com o numero de padroes da Cozinha + Churrasqueira';
  END IF;
END $$;
COMMIT;

-- PASSO 3 (conferencia): padroes do P10 por setor
SELECT split_part(key, '|', 1) AS setor_p10, count(*) AS produtos
  FROM inv_configuracoes, jsonb_each(valor)
 WHERE chave = 'padroes' AND key LIKE 'Delivery P10>%'
 GROUP BY 1 ORDER BY 1;
