-- Conferencia pos-limpeza: cada pedido deve ter 1 recebimento (com itens) e o valor certo.
-- Esperado:
--   #00560 -> 1 receb / valor 5420.00
--   #00561 -> 1 receb / valor 525.00
--   #00600 -> 1 receb / valor 2805.00
--   #00659 -> 1 receb / valor 1612.50
--   #00662 -> 1 receb / valor 217.92
--   #00666 -> 1 receb / valor 1104.00  (conta ainda NULL - precisa "Gerar Conta" no app)

SELECT p.pn AS pedido,
       (SELECT COUNT(*) FROM cmp_recebimentos r WHERE r.pedido_num = p.pn) AS n_receb,
       (SELECT COUNT(*) FROM cmp_recebimentos r WHERE r.pedido_num = p.pn
          AND NOT EXISTS (SELECT 1 FROM cmp_recebimento_itens ri WHERE ri.recebimento_id = r.id)) AS n_fantasmas,
       ROUND((SELECT SUM(r.total_recebido) FROM cmp_recebimentos r WHERE r.pedido_num = p.pn)::numeric,2) AS soma_receb,
       ROUND((SELECT SUM(valor) FROM cmp_contas_pagar cp WHERE cp.pedido_num = p.pn)::numeric,2) AS valor_conta,
       ROUND((SELECT SUM(COALESCE(valor,0)+COALESCE(acrescimo,0)) FROM lancamentos_rascunho lr WHERE lr.pedido_num = p.pn)::numeric,2) AS soma_rascunho
FROM (SELECT unnest(ARRAY['#00560','#00561','#00600','#00659','#00662','#00666']) AS pn) p
ORDER BY p.pn;
