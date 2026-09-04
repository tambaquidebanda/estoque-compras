-- Inspeciona a ORIGEM do custo/quantidade p/ agua e chopp nos ultimos 45 dias.
-- Quero ver, por item recebido: qtd_recebida, valor_unitario, total_recebido, unidade
-- e a data, pra descobrir em qual UNIDADE cada campo esta (compra x uso) e por que o
-- total veio em branco. Read-only, UMA unica instrucao.

SELECT r.data_receb,
       ri.produto,
       ri.unidade,
       ri.qtd_recebida,
       ri.valor_unitario,
       ri.total_recebido,
       (ri.qtd_recebida * ri.valor_unitario) AS calc_qtd_x_unit
FROM cmp_recebimento_itens ri
JOIN cmp_recebimentos r ON r.id = ri.recebimento_id
WHERE r.data_receb >= CURRENT_DATE - 45
  AND (
        ri.produto ILIKE '%agua com g%'
     OR ri.produto ILIKE '%barril%chopp%'
     OR ri.produto ILIKE '%chopp%brahma%'
  )
ORDER BY ri.produto, r.data_receb;
