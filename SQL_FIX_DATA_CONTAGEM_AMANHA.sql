-- ============================================================
-- Contagens e pedidos internos com a data do DIA SEGUINTE (10/11/2026)
--
-- A noite da contagem saía gravada com a data de amanhã: o campo de data da tela
-- de contagem estava com o dia seguinte (trocado à mão ou tela antiga aberta).
-- Ex.: domingo 08/11 o Kevin contou o BAR às 22h e tudo ficou 09/11; na segunda o
-- Manuel contou certo, e o BAR ficou com duas contagens no dia 09/11 e nenhuma no 08/11.
-- De 17/09 a 10/11: 381 contagens, 381 pedidos internos e 5.871 movimentos do razão.
--
-- Este SQL põe em cada registro a data do dia em que foi CRIADO (relógio do servidor,
-- hora de Manaus). Só muda a coluna data: saldo, quantidades, itens e status ficam
-- como estão. Só mexe no que está exatamente 1 dia à frente do criado_em.
-- Fica de fora: transferência (tem data programada de propósito) e emergência.
-- O código já foi corrigido para as próximas (a tela não aceita data futura).
--
-- Rodar UM PASSO DE CADA VEZ no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - só leitura: quantos estão 1 dia à frente, por tabela
-- Esperado (contado em 10/11 à tarde): pedidos 381 · inventarios 381 ·
-- contagem 5277 · pedido_interno_saida 297 · pedido_interno_entrada 297.
-- Pode ter alguns a mais se alguém contou depois disso. Todos com dias_a_frente = 1.
select 'pedidos_internos' as tabela, tipo, count(*) as linhas,
       min(data::date - (criado_em at time zone 'America/Manaus')::date) as dias_a_frente
from pedidos_internos
where criado_em >= '2026-09-17' and tipo = 'normal'
  and data::date > (criado_em at time zone 'America/Manaus')::date
group by tipo
union all
select 'est_inventarios', '-', count(*), min(data::date - (criado_em at time zone 'America/Manaus')::date)
from est_inventarios
where criado_em >= '2026-09-17'
  and data::date > (criado_em at time zone 'America/Manaus')::date
union all
select 'est_movimentacoes', tipo, count(*), min(data::date - (criado_em at time zone 'America/Manaus')::date)
from est_movimentacoes
where criado_em >= '2026-09-17'
  and tipo in ('contagem', 'pedido_interno_saida', 'pedido_interno_entrada')
  and data::date > (criado_em at time zone 'America/Manaus')::date
group by tipo
order by 1, 2;


-- PASSO 2 - guarda a data antiga de cada linha (para desfazer, se precisar)
-- Esperado: SELECT com o total do PASSO 1 (cerca de 6.633 linhas).
create table bkp_data_amanha_20261110 as
select 'pedidos_internos'::text as tabela, id, data as data_antiga
from pedidos_internos
where criado_em >= '2026-09-17' and tipo = 'normal'
  and data::date = (criado_em at time zone 'America/Manaus')::date + 1
union all
select 'est_inventarios', id, data
from est_inventarios
where criado_em >= '2026-09-17'
  and data::date = (criado_em at time zone 'America/Manaus')::date + 1
union all
select 'est_movimentacoes', id, data
from est_movimentacoes
where criado_em >= '2026-09-17'
  and tipo in ('contagem', 'pedido_interno_saida', 'pedido_interno_entrada')
  and data::date = (criado_em at time zone 'America/Manaus')::date + 1;


-- PASSO 3 - corrige as datas (tudo ou nada)
-- Esperado: "DO" sem erro. Se algum ASSERT falhar, nada é alterado.
do $$
declare
  n_pi int; n_inv int; n_mov int; b_pi int; b_inv int; b_mov int; n_mais int;
begin
  select count(*) into b_pi  from bkp_data_amanha_20261110 where tabela = 'pedidos_internos';
  select count(*) into b_inv from bkp_data_amanha_20261110 where tabela = 'est_inventarios';
  select count(*) into b_mov from bkp_data_amanha_20261110 where tabela = 'est_movimentacoes';
  assert b_pi  between 381 and 450,  format('pedidos no backup fora do esperado: %s', b_pi);
  assert b_inv between 381 and 450,  format('inventarios no backup fora do esperado: %s', b_inv);
  assert b_mov between 5871 and 7000, format('movimentos no backup fora do esperado: %s', b_mov);

  -- nada com mais de 1 dia à frente nesses tipos (seria outro problema, não este)
  select count(*) into n_mais from est_inventarios
   where criado_em >= '2026-09-17' and data::date > (criado_em at time zone 'America/Manaus')::date + 1;
  assert n_mais = 0, format('inventarios com mais de 1 dia à frente: %s', n_mais);

  update pedidos_internos p set data = (p.criado_em at time zone 'America/Manaus')::date
    from bkp_data_amanha_20261110 b
   where b.tabela = 'pedidos_internos' and b.id = p.id and p.data = b.data_antiga;
  get diagnostics n_pi = row_count;
  assert n_pi = b_pi, format('pedidos atualizados %s, esperado %s', n_pi, b_pi);

  update est_inventarios i set data = (i.criado_em at time zone 'America/Manaus')::date
    from bkp_data_amanha_20261110 b
   where b.tabela = 'est_inventarios' and b.id = i.id and i.data = b.data_antiga;
  get diagnostics n_inv = row_count;
  assert n_inv = b_inv, format('inventarios atualizados %s, esperado %s', n_inv, b_inv);

  update est_movimentacoes m set data = (m.criado_em at time zone 'America/Manaus')::date
    from bkp_data_amanha_20261110 b
   where b.tabela = 'est_movimentacoes' and b.id = m.id and m.data = b.data_antiga;
  get diagnostics n_mov = row_count;
  assert n_mov = b_mov, format('movimentos atualizados %s, esperado %s', n_mov, b_mov);

  raise notice 'Corrigidos: % pedidos, % inventarios, % movimentos', n_pi, n_inv, n_mov;
end $$;


-- PASSO 4 - conferência: rodar o PASSO 1 de novo.
-- Esperado: nenhuma linha.
-- E o BAR do Centro: domingo 08/11 volta a ter a contagem do Kevin.
select data, responsavel, count(*) as grupos, min(to_char(criado_em at time zone 'America/Manaus', 'DD/MM HH24:MI')) as de,
       max(to_char(criado_em at time zone 'America/Manaus', 'DD/MM HH24:MI')) as ate
from est_inventarios
where setor = 'BAR' and local = 'Centro' and data between '2026-11-07' and '2026-11-10'
group by data, responsavel
order by data;


-- DESFAZER (só se precisar):
-- update pedidos_internos  p set data = b.data_antiga from bkp_data_amanha_20261110 b where b.tabela = 'pedidos_internos'  and b.id = p.id;
-- update est_inventarios   i set data = b.data_antiga from bkp_data_amanha_20261110 b where b.tabela = 'est_inventarios'   and b.id = i.id;
-- update est_movimentacoes m set data = b.data_antiga from bkp_data_amanha_20261110 b where b.tabela = 'est_movimentacoes' and b.id = m.id;
