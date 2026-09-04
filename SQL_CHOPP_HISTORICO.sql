-- =============================================================
-- Chopp: restaurar o custo historico do periodo do bonus AMBEV
--
-- De 29/07 a 19/08 o barril foi lancado a 0,0001 (ou 0) porque a nota do
-- bonus vem zerada. Isso zerou o custo do produto e das 38 fichas de chopp.
-- O cadastro do produto ja foi corrigido (13,30/LT) e a cascata rodou.
-- Falta o HISTORICO, que nao se corrige sozinho.
--
-- Preco usado: 13.304 / litro. Vem das compras de julho, ANTES do bonus,
-- que foram pagas de verdade (#00695, #00650, #00617, #00598, #00569...).
--
-- O QUE ESTE SCRIPT NAO TOCA, DE PROPOSITO:
--   cmp_recebimentos.total_recebido  -> e o numero que virou conta a pagar
--   cmp_contas_pagar / lancamentos   -> o pagamento foi zero DE VERDADE.
--                                       O financeiro esta correto.
--   est_movimentacoes                -> decisao separada: mexer ali altera o
--                                       CMV de julho/agosto ja fechado.
-- =============================================================


-- PASSO 1: conferir antes. Rode so este SELECT.

select r.data_receb, r.pedido_num, i.qtd_recebida, i.valor_unitario, i.total_recebido
  from cmp_recebimento_itens i
  join cmp_recebimentos r on r.id = i.recebimento_id
 where i.produto ilike '%BARRIL CHOPP%'
   and coalesce(i.valor_unitario,0) < 0.01
 order by r.data_receb;

-- Esperado: 11 linhas, somando 2.000 litros.


-- PASSO 2: recebimentos. E a fonte do relatorio Custo Produto
-- (cmp_recebimento_itens.valor_unitario / total_recebido).

update cmp_recebimento_itens
   set valor_unitario = 13.304,
       total_recebido = qtd_recebida * 13.304,
       bonificado     = true
 where id in (
   '6e6f0c27-1ded-4f06-b161-3c8a4f0ec37a',  -- 2026-08-03 #00749 150 L
   '45e00d4c-c7e8-44be-a398-5118343b356d',  -- 2026-08-05 #00773 350 L
   '33fa38fe-d238-4105-91d5-7fb30510f6f8',  -- 2026-08-08 #00860 200 L
   '8306ff23-7bd8-4d87-aa15-c46f6a546be9',  -- 2026-08-11 #00862 150 L
   '7855abd3-d879-4900-958f-362885f9d6b7',  -- 2026-08-11 #00879 250 L
   'b4dfc6a2-cc8b-4c4d-8e4b-be33290f4ca3',  -- 2026-08-12 #00898 100 L
   '19282fa1-4e08-45e4-95fc-36f1d1db3302',  -- 2026-08-13 #00917 100 L
   '26dd7f9c-bc15-46e5-be3c-6699f6b0c240',  -- 2026-08-17 #00922 250 L
   'eafc24f4-ee0e-4a86-9f5a-b9f652607ea6',  -- 2026-08-18 #00996 150 L
   'b5bb8fbf-4fba-4318-a89e-fb70b565ef26',  -- 2026-08-19 #01017 150 L
   '83dab553-94b2-410b-bfea-d5a4fb80bc91'  -- 2026-08-19 #01019 150 L
 );


-- PASSO 3: pedidos de compra. Alimenta a tela de Compras e as analises.
-- Inclui pendentes e dispensados do mesmo periodo: marcados como bonificado,
-- os pendentes ja chegam no recebimento com o bonificado pre-marcado.

update cmp_compras
   set custo_unit = 13.304,
       bonificado = true
 where id in (
   '2abf3ab5-0c7f-46e7-a6a7-61f1352cb23e',  -- 2026-07-29 #00716 200 L  (pendente)
   '616a964a-d061-4939-b7a5-3aa435f88818',  -- 2026-07-30 #00741 150 L  (pendente)
   '1259abf3-c053-482a-8205-46af17082b54',  -- 2026-07-31 #00749 150 L  (recebido)
   'f357cf19-9614-40a0-9472-ede104cc2f56',  -- 2026-08-03 #00773 350 L  (recebido)
   'a31167c8-bb69-4211-bb2a-ae657cded234',  -- 2026-08-05 #00810 200 L  (pendente)
   '3ce9d61e-8d11-49cc-ba19-cdd355f94475',  -- 2026-08-06 #00821 150 L  (dispensado)
   '00a5721c-04ee-45d4-a6de-e2f9b82e3fe0',  -- 2026-08-07 #00860 200 L  (recebido)
   '82c3f02f-a5a0-4b9f-a297-d463e894fac0',  -- 2026-08-07 #00862 150 L  (recebido)
   '13ec8964-e3c6-4db6-a271-6e58f882b347',  -- 2026-08-10 #00879 250 L  (recebido)
   '27a2985b-17a4-4cca-a2b6-b6dd80a69914',  -- 2026-08-10 #00898 100 L  (recebido)
   '3e188299-dd3b-4ba6-aa71-0526322596f9',  -- 2026-08-12 #00917 100 L  (recebido)
   '9f7bc176-8d0e-4fa3-bd70-0f12fe4a7ee5',  -- 2026-08-13 #00922 250 L  (recebido)
   '6d9efb90-4608-460d-884d-ce1ef819b559',  -- 2026-08-14 #00962 150 L  (dispensado)
   '42ac50c8-5770-47ed-b33b-f71ccb461caa',  -- 2026-08-17 #01019 150 L  (recebido)
   '67313cf1-eff5-4145-bb72-93dfb5391eac',  -- 2026-08-17 #00996 150 L  (recebido)
   'f192d498-cbae-480b-9863-8fc44fd8afe9'  -- 2026-08-18 #01017 150 L  (recebido)
 );


-- PASSO 4: conferir depois. O SELECT do passo 1 deve voltar ZERO linhas.

select r.data_receb, r.pedido_num, i.qtd_recebida, i.valor_unitario,
       i.total_recebido, i.bonificado
  from cmp_recebimento_itens i
  join cmp_recebimentos r on r.id = i.recebimento_id
 where i.produto ilike '%BARRIL CHOPP%'
   and r.data_receb >= '2026-07-29'
 order by r.data_receb;

-- E o total a pagar dos pedidos NAO pode ter mudado:
select pedido_num, valor from cmp_contas_pagar
 where pedido_num in ('#00996','#01017','#01019') order by pedido_num;
-- Esperado: 523.25 / 428.23 / 0.00 - os mesmos de antes.
