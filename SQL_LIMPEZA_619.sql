-- LIMPEZA do #00619: fisicamente so chegou 1 tambaqui (20un x 55 = 1.100).
-- As 3 linhas de tambaqui foram engano no pedido -> mantem 1 recebimento, apaga o resto
-- (2 duplicados + 4 fantasmas) e dispensa as demais linhas do pedido.
-- Valor real: 1.100,00. NAO toca no financeiro (nao aprovado).
-- BLOCO DO = UMA unica instrucao.

DO $$
DECLARE
  keep_id     uuid := '39df482a-74ef-45c4-85fb-9aa1ac2488cb';  -- 1 recebimento de tambaqui (1100)
  keep_compra uuid;
  novo_valor  numeric;
BEGIN
  -- linha (compra_id) do recebimento mantido
  SELECT compra_id INTO keep_compra
    FROM cmp_recebimento_itens WHERE recebimento_id = keep_id LIMIT 1;

  -- 0. repointa QUALQUER conta que aponte para um recebimento que sera apagado -> keep_id
  --    (mira pelo FK, nao pelo pedido_num, para pegar contas com pedido_num diferente/vazio)
  UPDATE cmp_contas_pagar SET recebimento_id = keep_id
   WHERE recebimento_id IN (
     SELECT id FROM cmp_recebimentos WHERE pedido_num = '#00619' AND id <> keep_id
   );
  -- 1. apaga itens dos recebimentos NAO mantidos
  DELETE FROM cmp_recebimento_itens
   WHERE recebimento_id IN (
     SELECT id FROM cmp_recebimentos WHERE pedido_num = '#00619' AND id <> keep_id
   );
  -- 2. apaga cabecalhos NAO mantidos (2 duplicados + 4 fantasmas)
  DELETE FROM cmp_recebimentos WHERE pedido_num = '#00619' AND id <> keep_id;
  -- 3. valor real = total do recebimento mantido (1100)
  SELECT COALESCE(SUM(total_recebido),0) INTO novo_valor
    FROM cmp_recebimentos WHERE pedido_num = '#00619';
  -- 4. conta a pagar (valor)
  UPDATE cmp_contas_pagar SET valor = novo_valor WHERE pedido_num = '#00619';
  -- 5. rascunho da integracao
  UPDATE lancamentos_rascunho
     SET valor = GREATEST(0, novo_valor - COALESCE(acrescimo,0)) WHERE pedido_num = '#00619';
  -- 6. a linha recebida fica 'recebido' com a qtd real; as demais linhas viram 'dispensado'
  UPDATE cmp_compras
     SET status_receb = 'recebido',
         quantidade = COALESCE((SELECT SUM(qtd_recebida) FROM cmp_recebimento_itens WHERE compra_id = keep_compra), quantidade)
   WHERE id = keep_compra;
  UPDATE cmp_compras
     SET status_receb = 'dispensado'
   WHERE pedido_num = '#00619' AND id <> keep_compra
     AND status_receb NOT IN ('dispensado','cancelado');
END $$;

-- Conferencia (rode separado depois):
-- SELECT (SELECT COUNT(*) FROM cmp_recebimentos WHERE pedido_num='#00619') AS n_receb,
--        (SELECT valor FROM cmp_contas_pagar WHERE pedido_num='#00619') AS valor_conta;
-- Esperado: n_receb = 1, valor_conta = 1100.00
