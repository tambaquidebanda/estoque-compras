-- =====================================================================
-- SQL_CANCELA_PENDENTES_SUBSTITUIDOS.sql  (09/11/2026)
--
-- A partir de hoje, quando o setor grava uma contagem, os pedidos
-- PENDENTES antigos do mesmo setor/grupo/unidade viram 'cancelado'
-- (a contagem mais nova e a que vale). Isto faz o mesmo com os 5 que
-- ja estao sobrando, todos do Delivery P10:
--
--   PED-4225 (06/11) e PED-4271 (07/11) COZINHA/CONGELADOS  -> vale o PED-4316
--   PED-4226 (06/11) DESCARTAVEL                             -> vale o PED-4317
--   PED-4269 (07/11) COZINHA/HORTIFRUTI                      -> vale o PED-4312
--   PED-4270 (07/11) CHURRASQUEIRA/PEIXES                    -> vale o PED-4318 (ja liberado)
--
-- Nenhum dos 5 foi liberado, entao nao mexe em saldo.
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: 5 linhas, todas 'pendente', sem liberacao.
SELECT num_pedido, data, local, setor, obs, status, liberado_em
FROM pedidos_internos
WHERE num_pedido IN ('PED-4225','PED-4226','PED-4269','PED-4270','PED-4271')
ORDER BY num_pedido;


-- PASSO 2 - CANCELA (tudo ou nada). Deve terminar com DO e COMMIT.
BEGIN;

DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM pedidos_internos
   WHERE id IN ('9b6189f5-ad8a-4e6b-80be-627d24eea2ea','a1272576-59e2-4d74-bbcb-d0ca0cd125b7',
                '7cfb502a-4b18-484e-aa27-d4df764849c4','f63f1cf6-a91e-47c8-ac18-0c4583d9b32d',
                '710d03d9-a0da-478d-a1a0-78df47e5bd0a')
     AND status = 'pendente' AND liberado_em IS NULL AND tipo = 'normal' AND local = 'Delivery P10';
  ASSERT v_n = 5, format('esperava 5 pendentes do P10, achei %s - alguem ja liberou ou cancelou', v_n);

  -- cada um tem mesmo um pedido mais novo do mesmo grupo
  SELECT count(*) INTO v_n FROM pedidos_internos a
   WHERE a.id IN ('9b6189f5-ad8a-4e6b-80be-627d24eea2ea','a1272576-59e2-4d74-bbcb-d0ca0cd125b7',
                  '7cfb502a-4b18-484e-aa27-d4df764849c4','f63f1cf6-a91e-47c8-ac18-0c4583d9b32d',
                  '710d03d9-a0da-478d-a1a0-78df47e5bd0a')
     AND EXISTS (SELECT 1 FROM pedidos_internos b
                  WHERE b.setor = a.setor AND b.obs = a.obs AND b.local = a.local
                    AND b.tipo = 'normal' AND b.status <> 'cancelado' AND b.criado_em > a.criado_em);
  ASSERT v_n = 5, 'algum deles nao tem pedido mais novo do mesmo grupo';

  UPDATE pedidos_internos SET status = 'cancelado'
   WHERE id IN ('9b6189f5-ad8a-4e6b-80be-627d24eea2ea','a1272576-59e2-4d74-bbcb-d0ca0cd125b7',
                '7cfb502a-4b18-484e-aa27-d4df764849c4','f63f1cf6-a91e-47c8-ac18-0c4583d9b32d',
                '710d03d9-a0da-478d-a1a0-78df47e5bd0a')
     AND status = 'pendente';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 5, format('cancelou %s, esperava 5', v_n);
END $$;

COMMIT;


-- PASSO 3 - CONFERENCIA. Esperado: os 5 'cancelado'; e no P10 so um
-- pedido aberto por grupo (CONGELADOS 4316, HORTIFRUTI 4312,
-- DESCARTAVEL 4317, PEIXES 4318).
SELECT num_pedido, status FROM pedidos_internos
WHERE num_pedido IN ('PED-4225','PED-4226','PED-4269','PED-4270','PED-4271')
ORDER BY num_pedido;

SELECT setor, obs, count(*) AS abertos, string_agg(num_pedido, ', ' ORDER BY num_pedido) AS pedidos
FROM pedidos_internos
WHERE local = 'Delivery P10' AND tipo = 'normal' AND status = 'pendente'
GROUP BY setor, obs ORDER BY setor, obs;
