-- =====================================================================
-- SQL_RECEBE_18_PAGOS.sql  (22/10/2026)
--
-- 18 pedidos pagos pelo financeiro que nunca tiveram recebimento no
-- estoque. A equipe confirmou na pagina "Pedidos Pagos sem Recebimento"
-- que a mercadoria de TODOS chegou.
--   7 de agosto fechados como 'dispensado' sem receber:
--     #00906 #01010 #01067 #01081 #01107 #01111 #01169
--   11 ainda 'pendente':
--     #01284 #01320 #01418 #01475 #01518 #01590 #01591
--     #01667 #01698 #01717 #01761
--
-- Para cada pedido, igual ao #01806 (SQL_RECEBE_01806.sql):
--   - cria o recebimento (data = data de entrega do pedido), com todos os
--     itens na quantidade pedida;
--   - cria a conta a pagar ligada ao lancamento que o financeiro ja pagou,
--     com o valor PAGO (para o estoque e o financeiro mostrarem o mesmo);
--   - marca os itens como 'recebido'.
--
-- NAO mexe no saldo de estoque (nada em est_movimentacoes nem em
-- est_saldo_local): a mercadoria chegou ha semanas e ja entrou no saldo
-- pelas contagens; os de agosto sao de antes do inventario geral de 11/09.
-- NAO cria nem altera lancamento no financeiro.
--
-- Local: Teatro -> ESTOQUE_LOJA; Delivery P10 -> ESTOQUE DELIVERY
-- (#01284 inteiro e o guarana zero do P10 dentro do #01717).
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA.
-- Esperado: 18 linhas; recebimentos 0; contas 0; lancamentos 1;
-- status so 'pendente' ou 'dispensado'.
-- ---------------------------------------------------------------------
WITH v(pedido_num) AS (VALUES
  ('#00906'),('#01010'),('#01067'),('#01081'),('#01107'),('#01111'),('#01169'),
  ('#01284'),('#01320'),('#01418'),('#01475'),('#01518'),('#01590'),('#01591'),
  ('#01667'),('#01698'),('#01717'),('#01761'))
SELECT v.pedido_num,
  (SELECT count(*) FROM cmp_recebimentos r WHERE r.pedido_num = v.pedido_num) AS recebimentos,
  (SELECT count(*) FROM cmp_contas_pagar c WHERE c.pedido_num = v.pedido_num) AS contas,
  (SELECT count(*) FROM lancamentos l WHERE l.numero_pedido = v.pedido_num) AS lancamentos,
  (SELECT string_agg(DISTINCT c.status_receb, ',') FROM cmp_compras c WHERE c.pedido_num = v.pedido_num) AS status,
  (SELECT count(*) FROM cmp_compras c WHERE c.pedido_num = v.pedido_num) AS itens,
  (SELECT sum(c.total) FROM cmp_compras c WHERE c.pedido_num = v.pedido_num) AS total_pedido,
  (SELECT max(l.valor) FROM lancamentos l WHERE l.numero_pedido = v.pedido_num) AS valor_pago
FROM v ORDER BY 1;


-- ---------------------------------------------------------------------
-- PASSO 2 - REGISTRA OS 18 RECEBIMENTOS (tudo junto ou nada).
-- Se algum pedido nao estiver no estado esperado (ja recebido, ja tem
-- conta, mais de um lancamento...), PARA com erro e nada e gravado.
-- Deve terminar em "UPDATE 96" (os 96 itens) e depois COMMIT.
-- ---------------------------------------------------------------------
BEGIN;

CREATE TEMP TABLE rec_alvo ON COMMIT DROP AS
SELECT v.pedido_num, v.data_receb::date AS data_receb, v.local,
       l.id AS lanc_id, l.valor AS valor_pago, l.vencimento,
       gen_random_uuid() AS rec_id
FROM (VALUES
  ('#00906','2026-08-11','ESTOQUE_LOJA'),
  ('#01010','2026-08-19','ESTOQUE_LOJA'),
  ('#01067','2026-08-24','ESTOQUE_LOJA'),
  ('#01081','2026-08-27','ESTOQUE_LOJA'),
  ('#01107','2026-08-26','ESTOQUE_LOJA'),
  ('#01111','2026-08-26','ESTOQUE_LOJA'),
  ('#01169','2026-08-31','ESTOQUE_LOJA'),
  ('#01284','2026-09-08','ESTOQUE DELIVERY'),
  ('#01320','2026-09-10','ESTOQUE_LOJA'),
  ('#01418','2026-09-21','ESTOQUE_LOJA'),
  ('#01475','2026-09-22','ESTOQUE_LOJA'),
  ('#01518','2026-09-26','ESTOQUE_LOJA'),
  ('#01590','2026-09-30','ESTOQUE_LOJA'),
  ('#01591','2026-10-02','ESTOQUE_LOJA'),
  ('#01667','2026-10-06','ESTOQUE_LOJA'),
  ('#01698','2026-10-08','ESTOQUE_LOJA'),
  ('#01717','2026-10-09','ESTOQUE_LOJA'),
  ('#01761','2026-10-13','ESTOQUE_LOJA')
) v(pedido_num, data_receb, local)
JOIN lancamentos l ON l.numero_pedido = v.pedido_num
WHERE NOT EXISTS (SELECT 1 FROM cmp_recebimentos r WHERE r.pedido_num = v.pedido_num)
  AND NOT EXISTS (SELECT 1 FROM cmp_contas_pagar c WHERE c.pedido_num = v.pedido_num)
  AND NOT EXISTS (SELECT 1 FROM cmp_compras c WHERE c.pedido_num = v.pedido_num
                    AND c.status_receb NOT IN ('pendente','dispensado'))
  AND (SELECT count(*) FROM lancamentos l2 WHERE l2.numero_pedido = v.pedido_num) = 1;

DO $$
BEGIN
  IF (SELECT count(*) FROM rec_alvo) <> 18 THEN
    RAISE EXCEPTION 'Esperava 18 pedidos prontos para receber, achei %. Nada foi gravado. Rode o PASSO 1 e me mande o resultado.',
      (SELECT count(*) FROM rec_alvo);
  END IF;
END $$;

INSERT INTO cmp_recebimentos
  (id, pedido_num, data_receb, responsavel, fornecedor, comprador, total_recebido, status, local)
SELECT a.rec_id, a.pedido_num, a.data_receb,
       'Ajuste SQL 22/10 (equipe confirmou que chegou)',
       c.fornecedor_nome, c.comprador, t.total, 'confirmado', a.local
FROM rec_alvo a
JOIN LATERAL (SELECT fornecedor_nome, comprador FROM cmp_compras
              WHERE pedido_num = a.pedido_num LIMIT 1) c ON true
JOIN LATERAL (SELECT sum(coalesce(total, 0)) AS total FROM cmp_compras
              WHERE pedido_num = a.pedido_num) t ON true;

INSERT INTO cmp_recebimento_itens
  (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
   valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado, local)
SELECT a.rec_id, c.id, c.produto, c.categoria, c.unidade_med, c.quantidade, c.quantidade,
       c.custo_unit, c.total, false, '', c.produto_id, coalesce(c.bonificado, false),
       CASE WHEN c.unidade_uso = 'Delivery P10' AND a.local <> 'ESTOQUE DELIVERY'
            THEN 'ESTOQUE DELIVERY' END
FROM rec_alvo a
JOIN cmp_compras c ON c.pedido_num = a.pedido_num;

INSERT INTO cmp_contas_pagar
  (pedido_num, recebimento_id, fornecedor, data_receb, vencimento, valor, status,
   lancamento_id, parcelas, parcela_intervalo)
SELECT a.pedido_num, a.rec_id, c.fornecedor_nome, a.data_receb, a.vencimento,
       a.valor_pago, 'pendente', a.lanc_id, 1, 'mensal'
FROM rec_alvo a
JOIN LATERAL (SELECT fornecedor_nome FROM cmp_compras
              WHERE pedido_num = a.pedido_num LIMIT 1) c ON true;

UPDATE cmp_compras c
SET status_receb = 'recebido'
FROM rec_alvo a
WHERE c.pedido_num = a.pedido_num
  AND c.status_receb IN ('pendente','dispensado');

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA.
-- Esperado: 18 linhas, cada uma com 1 recebimento, itens_receb igual a
-- itens, status 'recebido', 1 conta ligada ao lancamento, valor_conta
-- igual ao valor_pago. Na ultima consulta: 0 movimentos de estoque.
-- ---------------------------------------------------------------------
WITH v(pedido_num) AS (VALUES
  ('#00906'),('#01010'),('#01067'),('#01081'),('#01107'),('#01111'),('#01169'),
  ('#01284'),('#01320'),('#01418'),('#01475'),('#01518'),('#01590'),('#01591'),
  ('#01667'),('#01698'),('#01717'),('#01761'))
SELECT v.pedido_num,
  (SELECT count(*) FROM cmp_recebimentos r WHERE r.pedido_num = v.pedido_num) AS recebimentos,
  (SELECT string_agg(r.local, ',') FROM cmp_recebimentos r WHERE r.pedido_num = v.pedido_num) AS local,
  (SELECT count(*) FROM cmp_compras c WHERE c.pedido_num = v.pedido_num) AS itens,
  (SELECT count(*) FROM cmp_recebimento_itens i JOIN cmp_recebimentos r ON r.id = i.recebimento_id
     WHERE r.pedido_num = v.pedido_num) AS itens_receb,
  (SELECT string_agg(DISTINCT c.status_receb, ',') FROM cmp_compras c WHERE c.pedido_num = v.pedido_num) AS status,
  (SELECT count(*) FROM cmp_contas_pagar cp JOIN lancamentos l ON l.id = cp.lancamento_id
     WHERE cp.pedido_num = v.pedido_num) AS conta_ligada,
  (SELECT max(cp.valor) FROM cmp_contas_pagar cp WHERE cp.pedido_num = v.pedido_num) AS valor_conta,
  (SELECT max(l.valor) FROM lancamentos l WHERE l.numero_pedido = v.pedido_num) AS valor_pago
FROM v ORDER BY 1;

SELECT count(*) AS movimentos_estoque
FROM est_movimentacoes m
JOIN cmp_recebimentos r ON r.id::text = m.ref_id::text
WHERE r.responsavel = 'Ajuste SQL 22/10 (equipe confirmou que chegou)';
