-- ============================================================================
-- DIAGNÓSTICO: quando o saldo dos 7 produtos (pedidos 810/811) foi escrito?
-- Só-leitura. Mostra TODOS os locais de cada produto + updated_at (hora de Manaus).
-- Objetivo: ver se a linha ESTOQUE_LOJA=0 dos 4 que falharam foi
--   (a) nunca tocada pelo recebimento (updated_at antigo), ou
--   (b) escrita/zerada por uma CONTAGEM depois do recebimento.
-- ============================================================================
SELECT
  p.nome,
  sl.local,
  sl.saldo,
  (sl.updated_at AT TIME ZONE 'America/Manaus') AS atualizado_em_manaus
FROM est_saldo_local sl
JOIN est_produtos p ON p.id = sl.produto_id
WHERE sl.produto_id IN (
  'd0a9f6a1-e2b7-497c-936e-19b28e701428', -- MP BARE DE 2 LITROS   (entrou: 36)
  '6dcd1b75-04d4-4a1e-8dd1-ea2fd44eb53a', -- MP BARRIL CHOPP       (falhou: 0)
  '3dd9c8de-8def-45c4-a9c6-57ef9177b34d', -- MP GUARANA ZERO LATA  (entrou: 12)
  'eaf182df-75c9-4dfb-97f7-3b611a41e2d4', -- MP ORIGINAL 600ML     (falhou: 0)
  '537e973e-a1b8-45a6-91c9-479663b7323a', -- MP SODA LIMONADA LATA (falhou: 0)
  'b0feb3d5-8fac-41bf-a044-0ff657c8d619', -- MP SPATEN 600ml       (entrou: 12)
  '9965d4ec-4862-4925-95bf-fb6079e7e91f'  -- MP STELLA ARTOIS 600ML(falhou: 0)
)
ORDER BY p.nome, sl.local;

-- Referência: horário atual de Manaus (para comparar com os updated_at acima)
SELECT (now() AT TIME ZONE 'America/Manaus') AS agora_manaus;
