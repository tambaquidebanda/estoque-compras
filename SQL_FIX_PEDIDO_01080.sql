-- ============================================================
-- Pedido #01080 (CRISTIANA RIBEIRO) - duas entregas no mesmo pedido (15/10/2026)
--
-- O #01080 recebeu a entrega de 24/08 (49 tortas, R$ 318,50 - paga por Pix
-- no financeiro, fica como esta) e, depois de refeito em 31/08, recebeu
-- tambem a entrega de 07/09 (60 tortas, R$ 390,00). A de 07/09 agora vai
-- pelo pedido novo #01804. Alem disso, em 24/08 os 13 doces entraram duas
-- vezes (celular 15:19 e computador 15:24 = os R$ 84,50).
--
-- Este SQL deixa o #01080 so com a entrega de 24/08:
--   - tira do Estoque da Loja o que entrou pelo 07/09 (25 choc, 25 doce,
--     10 abacaxi) - o #01804 vai lancar de novo quando for recebido;
--   - tira os 13 doces repetidos de 24/08;
--   - apaga os dois recebimentos a mais e devolve os itens ao de 24/08;
--   - conta do estoque volta a R$ 318,50 / venc. 15/09 (igual ao financeiro).
-- NAO mexe no financeiro.
--
-- IMPORTANTE: rodar no MESMO DIA em que o #01804 for recebido (antes ou
-- depois), para o saldo nao ficar 60 tortas a mais ou a menos de um dia
-- para o outro.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura: os 3 recebimentos do #01080
-- Esperado: 318.50 (24/08, 0 itens), 84.50 (24/08, 0 itens), 390.00 (05/09, 3 itens)
select r.id, r.data_receb, r.total_recebido, r.responsavel,
       (select count(*) from cmp_recebimento_itens i where i.recebimento_id = r.id) as itens
from cmp_recebimentos r
where r.pedido_num = '#01080'
order by r.criado_em;

-- PASSO 1b - so leitura: saldo das tortas no Estoque da Loja agora
select p.nome, s.saldo
from est_saldo_local s join est_produtos p on p.id = s.produto_id
where s.local = 'ESTOQUE_LOJA'
  and s.produto_id in ('15ea73e2-aa33-423c-99cd-e3beedad9303',   -- chocolate
                       '1a56bb8c-be15-4583-b936-a147f9899f21',   -- doce
                       'b458e948-16ed-4d78-acf6-b6104fcd3547')   -- abacaxi
order by p.nome;


-- PASSO 2 - estorno no Estoque da Loja (razao + saldo)
-- Esperado: UPDATE 3 (grava 4 linhas no razao e acerta o saldo de 3 tortas).
-- Trava: se ja tiver rodado (motivo 'Acerto #01080'), da UPDATE 0 e nada muda.
with novos as (
  insert into est_movimentacoes (produto_id, local, tipo, quantidade, custo_unit, origem, motivo)
  select v.pid::uuid, 'ESTOQUE_LOJA', 'recebimento', v.qtd, 6.5, 'estorno_recebimento', v.motivo
  from (values
    ('15ea73e2-aa33-423c-99cd-e3beedad9303', -25, 'Acerto #01080 - entrega de 07/09 vai pelo #01804'),
    ('1a56bb8c-be15-4583-b936-a147f9899f21', -25, 'Acerto #01080 - entrega de 07/09 vai pelo #01804'),
    ('b458e948-16ed-4d78-acf6-b6104fcd3547', -10, 'Acerto #01080 - entrega de 07/09 vai pelo #01804'),
    ('1a56bb8c-be15-4583-b936-a147f9899f21', -13, 'Acerto #01080 - 13 doces lancados 2x em 24/08')
  ) as v(pid, qtd, motivo)
  where not exists (select 1 from est_movimentacoes where motivo like 'Acerto #01080%')
  returning produto_id, quantidade
)
update est_saldo_local s
set saldo = s.saldo + t.delta, updated_at = now()
from (select produto_id, sum(quantidade) as delta from novos group by produto_id) t
where s.produto_id = t.produto_id and s.local = 'ESTOQUE_LOJA';


-- PASSO 3 - conta do estoque igual ao financeiro (R$ 318,50, venc. 15/09, entrega de 24/08)
-- Esperado: UPDATE 1
update cmp_contas_pagar
set valor = 318.50, vencimento = '2026-09-15', data_receb = '2026-08-24',
    recebimento_id = '38c0b383-f521-496c-adf4-0c05f2195649'
where id = 'befc9f01-7cfd-44b0-85c7-c6ecb1f06a67'
  and pedido_num = '#01080'
  and valor = 390;


-- PASSO 4 - apaga o recebimento de 07/09 (itens + cabecalho) e o de R$ 84,50
-- Esperado: DELETE 3 (itens) e depois DELETE 2 (cabecalhos)
delete from cmp_recebimento_itens
where recebimento_id = '9fee1f3b-cdf3-4db0-aa03-1da20ca443be';

delete from cmp_recebimentos
where id in ('9fee1f3b-cdf3-4db0-aa03-1da20ca443be',   -- 390,00 (07/09)
             'c8767ed2-848e-4a23-a238-fecf8ef182d7')   -- 84,50 (repetido)
  and pedido_num = '#01080';


-- PASSO 5 - devolve os itens ao recebimento de 24/08 (24 choc, 13 doce, 12 abacaxi)
-- Esperado: INSERT 0 3 (0 se ja tiver itens)
insert into cmp_recebimento_itens
  (recebimento_id, compra_id, produto, categoria, unidade, qtd_pedida, qtd_recebida,
   valor_unitario, total_recebido, divergencia, obs_divergencia, produto_id, bonificado)
select '38c0b383-f521-496c-adf4-0c05f2195649', v.compra_id::uuid, v.produto, 'Sobremesas', 'UN',
       v.qtd, v.qtd, 6.5, v.qtd * 6.5, false, '', v.pid::uuid, false
from (values
  ('183e2672-e113-4f4d-91b1-c2cacb8e4dc8', 'MP TORTA CUPUACU COM CHOCOLATE', 24, '15ea73e2-aa33-423c-99cd-e3beedad9303'),
  ('9c44db01-8100-47bb-9d4e-d8e5c6c82799', 'MP TORTA CUPUACU COM DOCE',      13, '1a56bb8c-be15-4583-b936-a147f9899f21'),
  ('cf9ea372-abc4-4e71-9f78-7c7fdf93247a', 'MP TORTA ABACAXI',               12, 'b458e948-16ed-4d78-acf6-b6104fcd3547')
) as v(compra_id, produto, qtd, pid)
where not exists (select 1 from cmp_recebimento_itens
                  where recebimento_id = '38c0b383-f521-496c-adf4-0c05f2195649');


-- PASSO 6 - linhas do pedido com o que veio em 24/08
-- Esperado: UPDATE 3
update cmp_compras c
set quantidade = v.qtd   -- o total e calculado sozinho pelo banco
from (values
  ('183e2672-e113-4f4d-91b1-c2cacb8e4dc8', 24),
  ('9c44db01-8100-47bb-9d4e-d8e5c6c82799', 13),
  ('cf9ea372-abc4-4e71-9f78-7c7fdf93247a', 12)
) as v(id, qtd)
where c.id = v.id::uuid and c.pedido_num = '#01080';


-- PASSO 7 - conferencia
-- Esperado: 1 recebimento (24/08, 318.50, 3 itens que somam 318.50) e a conta 318.50.
select r.data_receb, r.total_recebido,
       (select count(*) from cmp_recebimento_itens i where i.recebimento_id = r.id) as itens,
       (select sum(total_recebido) from cmp_recebimento_itens i where i.recebimento_id = r.id) as soma_itens,
       (select valor from cmp_contas_pagar where pedido_num = '#01080') as conta
from cmp_recebimentos r
where r.pedido_num = '#01080';
-- e rodar o PASSO 1b de novo: chocolate -25, doce -38, abacaxi -10 em relacao ao antes.
