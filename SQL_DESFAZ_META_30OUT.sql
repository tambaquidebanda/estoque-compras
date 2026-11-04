-- ═══════════════════════════════════════════════════════════════════════════
-- DESFAZ A APROVACAO DA META DE PRODUCAO DE SEXTA 30/10/2026 (04/11/2026)
--
-- O Wagner aprovou as metas do Centro (16:44) e do Delivery P10 (16:46) da semana
-- 30/10 a 05/11, mas a Producao ainda nao usa o sistema. A aprovacao criou sozinha
-- 8 pedidos de MP (transferencia para a Producao), que estao poluindo a lista:
--   Centro: PED-3909, 3910, 3911, 3912, 3913   (Estoque Central -> Producao)
--   P10:    PED-3914, 3915, 3916               (Delivery P10 -> Producao P10)
-- Conferido em 04/11: os 8 ainda estao PENDENTES (nada liberado nem recebido, nenhum
-- saldo mexeu) e a Producao nao registrou nada (prod_registros vazio na semana).
--
-- Faz o mesmo que o botao "Reabrir" da tela Meta da Semana, nas duas unidades:
--   a) os 8 pedidos viram 'cancelado' (so os que continuam pendentes);
--   b) as 2 metas voltam a 'rascunho' (os numeros ficam guardados, sem pedido nenhum).
-- Nao apaga nada. Pode rodar mais de uma vez.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) CONFERIR ANTES — deve listar 8 pedidos, todos 'pendente'
SELECT p.num_pedido, p.status, p.unidade_origem, p.local, p.data, m.unidade AS meta, m.status AS meta_status
FROM pedidos_internos p
JOIN prod_metas m ON m.id = p.prod_meta_id
WHERE m.semana_ini = '2026-10-30'
ORDER BY p.num_pedido;

-- 2) DESFAZER
BEGIN;

UPDATE pedidos_internos p
SET status = 'cancelado',
    obs = coalesce(p.obs || ' · ', '') || 'Cancelado por SQL em 04/11: meta da Produção de 30/10 aprovada antes de usar o sistema'
FROM prod_metas m
WHERE m.id = p.prod_meta_id
  AND m.semana_ini = '2026-10-30'
  AND p.status = 'pendente';

UPDATE prod_metas m
SET status = 'rascunho', aprovado_em = NULL, aprovado_por = NULL
WHERE m.semana_ini = '2026-10-30'
  AND m.status = 'aprovada'
  AND NOT EXISTS (SELECT 1 FROM prod_registros r
                  WHERE r.unidade = m.unidade AND r.data BETWEEN '2026-10-30' AND '2026-11-05');

-- deve mostrar 8 pedidos cancelados e 2 metas em rascunho
SELECT (SELECT COUNT(*) FROM pedidos_internos p JOIN prod_metas m ON m.id = p.prod_meta_id
        WHERE m.semana_ini = '2026-10-30' AND p.status = 'cancelado') AS pedidos_cancelados,
       (SELECT COUNT(*) FROM prod_metas WHERE semana_ini = '2026-10-30' AND status = 'rascunho') AS metas_rascunho;

COMMIT;
