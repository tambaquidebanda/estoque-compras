-- ============================================================
-- DESFAZ o SQL_FIX_3380_UNIDADE.sql (14/10/2026)
--
-- A Flavia E do Delivery P10: as contagens dela de hoje estavam certas.
-- O fix passou INV-2477/2478/2479 e PED-3380 para 'Centro' e agora a
-- trava do celular barra a Flavia ("ja contou no Centro hoje").
-- Este SQL devolve as 4 linhas para 'Delivery P10'.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura
-- Esperado: 4 linhas com local = Centro; o pedido liberado e sem recebido_em.
select 'contagem' as tipo, num_inv as numero, local, setor, grupo, responsavel, null as status, null as recebido_em
from est_inventarios
where id in ('b36e0e79-b025-419d-8404-fb82f9ff3e38',
             'f969a7a3-30c3-4321-9ffc-c9f7e224da78',
             '8c4b5e21-f9c9-47ed-82dd-5815479be7ef')
union all
select 'pedido', num_pedido, local, setor, obs, responsavel, status, recebido_em::text
from pedidos_internos
where id = 'b0773f9c-1436-47e5-a40c-c5910a45d025';


-- PASSO 2 - devolve as 3 contagens para o P10
-- Esperado: UPDATE 3
update est_inventarios
set local = 'Delivery P10'
where id in ('b36e0e79-b025-419d-8404-fb82f9ff3e38',
             'f969a7a3-30c3-4321-9ffc-c9f7e224da78',
             '8c4b5e21-f9c9-47ed-82dd-5815479be7ef')
  and local = 'Centro';


-- PASSO 3 - devolve o pedido para o P10 (so se ainda nao foi recebido)
-- Esperado: UPDATE 1. Se der UPDATE 0, o pedido ja foi recebido: me avise.
update pedidos_internos
set local = 'Delivery P10'
where id = 'b0773f9c-1436-47e5-a40c-c5910a45d025'
  and local = 'Centro'
  and recebido_em is null;


-- PASSO 4 - conferencia: rodar o PASSO 1 de novo.
-- Esperado: as 4 linhas com local = Delivery P10.
