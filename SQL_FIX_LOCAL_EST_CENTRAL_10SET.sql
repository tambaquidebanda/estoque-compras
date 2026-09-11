-- ============================================================================
-- SQL_FIX_LOCAL_EST_CENTRAL_10SET.sql
-- Noite de 10/09/2026: um celular estava com a unidade "Est. Central" marcada
-- na tela de contagem. SALAO, DELIVERY e ASG gravaram contagem e pedidos com
-- local = 'Estoque Central' em vez de 'Centro'. A lista de produtos das duas
-- unidades e igual e NENHUM movimento de saldo foi para 'Estoque Central' -
-- so a etiqueta esta errada. Corrige 3 contagens + 5 pedidos, pelos IDs.
-- O Estoque Central tem historico proprio (34 contagens, 63 pedidos antes de
-- 10/09): por isso o filtro e por ID, nunca por local.
-- ============================================================================

-- PASSO 1 - SO LEITURA. Deve mostrar 8 linhas, todas com local = 'Estoque Central'.
SELECT 'contagem' AS tipo, num_inv AS numero, setor, grupo AS detalhe, local, criado_em
  FROM est_inventarios
 WHERE id IN ('b59434f9-f9fb-40ad-a5c4-1e618b18fd85',   -- INV-1647 SALAO
              'f6de2db0-70e8-400a-bdc7-5c989f5a05d5',   -- INV-1648 DELIVERY
              '83e0e4cb-1a4b-42df-bc5c-3a8b24570b2e')   -- INV-1649 ASG
UNION ALL
SELECT 'pedido', num_pedido, setor, tipo || ' / ' || status, local, criado_em
  FROM pedidos_internos
 WHERE id IN ('7989bad9-9413-42b4-b470-f4323e8a112a',   -- PED-2466 SALAO emergencia
              '84cf19ba-b677-4682-a4e3-f436e69b8b69',   -- PED-2467 SALAO
              'a6a08674-a184-4597-847e-502724bd4aa6',   -- PED-2468 DELIVERY
              'dacc65f6-eb6e-499d-a35b-0bb3e4b0d54e',   -- PED-2469 ASG emergencia
              'c53ebec6-e727-40dc-a529-137a086d3150')   -- PED-2470 ASG
ORDER BY criado_em;

-- PASSO 2 - CORRECAO. Rode depois de conferir o PASSO 1.
-- Esperado: "UPDATE 3" e "UPDATE 5". Se vier outro numero, rode ROLLBACK; e me avise.
BEGIN;

UPDATE est_inventarios SET local = 'Centro'
 WHERE local = 'Estoque Central'
   AND id IN ('b59434f9-f9fb-40ad-a5c4-1e618b18fd85',
              'f6de2db0-70e8-400a-bdc7-5c989f5a05d5',
              '83e0e4cb-1a4b-42df-bc5c-3a8b24570b2e');

UPDATE pedidos_internos SET local = 'Centro'
 WHERE local = 'Estoque Central'
   AND id IN ('7989bad9-9413-42b4-b470-f4323e8a112a',
              '84cf19ba-b677-4682-a4e3-f436e69b8b69',
              'a6a08674-a184-4597-847e-502724bd4aa6',
              'dacc65f6-eb6e-499d-a35b-0bb3e4b0d54e',
              'c53ebec6-e727-40dc-a529-137a086d3150');

COMMIT;

-- PASSO 3 - CONFERENCIA: rode o PASSO 1 de novo; as 8 linhas devem vir com local = 'Centro'.
