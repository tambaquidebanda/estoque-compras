-- ============================================================
-- Transferencias com a data da VESPERA (16/10/2026)
--
-- 5 transferencias criadas de manha nasceram com a data do dia anterior.
-- Entre elas as duas de hoje: PED-3435 (ja recebida) e PED-3436 (pendente
-- no Estoque Central). Este SQL poe em cada uma a data do dia em que foi
-- criada (relogio do servidor, hora de Manaus). So muda a coluna data:
-- saldo, itens e status ficam como estao.
-- O codigo ja foi corrigido para as proximas.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura
-- Esperado: 5 linhas, data_gravada = um dia antes de data_certa.
select num_pedido, status, data as data_gravada,
       (criado_em at time zone 'America/Manaus')::date as data_certa,
       to_char(criado_em at time zone 'America/Manaus', 'DD/MM HH24:MI') as criado
from pedidos_internos
where num_pedido in ('PED-3140', 'PED-3196', 'PED-3405', 'PED-3435', 'PED-3436')
  and tipo = 'transferencia'
order by criado_em;


-- PASSO 2 - corrige a data
-- Esperado: UPDATE 5
update pedidos_internos
set data = (criado_em at time zone 'America/Manaus')::date
where num_pedido in ('PED-3140', 'PED-3196', 'PED-3405', 'PED-3435', 'PED-3436')
  and tipo = 'transferencia'
  and data <> (criado_em at time zone 'America/Manaus')::date;


-- PASSO 3 - conferencia: rodar o PASSO 1 de novo.
-- Esperado: data_gravada = data_certa nas 5.
