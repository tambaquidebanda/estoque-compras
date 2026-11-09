-- =====================================================================
-- SQL_CANCELA_LIBERADOS_OUT_P10.sql  (09/11/2026)
--
-- 12 pedidos internos do Delivery P10, feitos de 15 a 27/10, liberados
-- e nunca confirmados pelo setor:
--   PED-3408 3409 3410 3518 3581 3665 3695 3696 3697 3718 3720 3751
--
-- Todos foram liberados ANTES de 29/10 (commit b0f21f0). Pela regra da
-- epoca o saldo so andava na CONFIRMACAO; como nunca confirmaram, nenhum
-- deles mexeu no estoque (conferido: 0 movimento para os 12 pedidos e
-- seus 87 itens). Cancelar so limpa a lista - nao mexe em saldo.
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- PASSO 1 - SO LEITURA. Esperado: 12 linhas, todas 'liberado',
-- Delivery P10, sem recebido_em.
SELECT num_pedido, data, tipo, setor, obs, status, liberado_em, recebido_em
FROM pedidos_internos
WHERE num_pedido IN ('PED-3408','PED-3409','PED-3410','PED-3518','PED-3581','PED-3665',
                     'PED-3695','PED-3696','PED-3697','PED-3718','PED-3720','PED-3751')
ORDER BY num_pedido;


-- PASSO 2 - CANCELA (tudo ou nada). Deve terminar com DO e COMMIT.
BEGIN;

DO $$
DECLARE
  v_ids uuid[] := ARRAY[
    'be5639a6-31d8-4786-8831-518b42490c2a',  -- PED-3408
    '566b80db-d4b3-480c-8f3e-d378cf460943',  -- PED-3409
    'b9337737-b9d1-47db-9eac-d363c85310c1',  -- PED-3410
    '619f740d-eb31-4ece-821d-c582f6b2ac87',  -- PED-3518
    '8bdacd32-9f88-4230-8837-0af8727a5ad9',  -- PED-3581 (emergencia)
    'e46f4887-b867-4b6a-97d3-cfe02cc13b63',  -- PED-3665
    'd45773da-3761-4a1a-af0d-c147898d7635',  -- PED-3695
    'd7c8fb99-6a93-4c06-a119-5fce33c4fc10',  -- PED-3696
    'f52aca9a-da9c-4e12-b9ca-79a683d87487',  -- PED-3697
    'f6a1f538-044d-4889-8017-46f7dacbefd1',  -- PED-3718
    'bbf36344-2345-4d6e-aeb9-6e4f9cba1ea0',  -- PED-3720
    '385c8ea7-f5e5-4f22-9d47-eac1032d154c'   -- PED-3751
  ]::uuid[];
  v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM pedidos_internos
   WHERE id = ANY(v_ids) AND status = 'liberado' AND recebido_em IS NULL
     AND local = 'Delivery P10' AND liberado_em < TIMESTAMPTZ '2026-10-29 19:31:47+00';
  ASSERT v_n = 12, format('esperava 12 liberados do P10 antes de 29/10, achei %s - alguem ja confirmou ou cancelou', v_n);

  -- nenhum movimento de estoque ligado a esses pedidos ou aos itens
  SELECT count(*) INTO v_n FROM est_movimentacoes
   WHERE ref_id::text IN (SELECT id::text FROM pedidos_internos_itens WHERE pedido_id = ANY(v_ids)
                          UNION ALL SELECT unnest(v_ids)::text);
  ASSERT v_n = 0, format('%s movimentos de estoque ligados a esses pedidos - nao cancelar, me chame', v_n);

  UPDATE pedidos_internos SET status = 'cancelado'
   WHERE id = ANY(v_ids) AND status = 'liberado';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 12, format('cancelou %s, esperava 12', v_n);
END $$;

COMMIT;


-- PASSO 3 - CONFERENCIA. Esperado: os 12 'cancelado'; e no P10 so
-- sobram liberados de novembro (PED-4318 peixe e PED-4347 emergencia).
SELECT num_pedido, status FROM pedidos_internos
WHERE num_pedido IN ('PED-3408','PED-3409','PED-3410','PED-3518','PED-3581','PED-3665',
                     'PED-3695','PED-3696','PED-3697','PED-3718','PED-3720','PED-3751')
ORDER BY num_pedido;

SELECT num_pedido, data, tipo, setor, obs, liberado_em
FROM pedidos_internos
WHERE local = 'Delivery P10' AND status = 'liberado'
ORDER BY criado_em;
