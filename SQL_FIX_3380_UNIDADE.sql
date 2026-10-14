-- ============================================================
-- PED-3380 e as contagens da Flavia de 14/10/2026: unidade errada
--
-- A Cozinha do CENTRO foi contada com o botao "Delivery P10" marcado
-- (14:22 a 14:58). Ficaram com local = 'Delivery P10':
--   INV-2477  COZINHA / ESTIVAS     14:22
--   INV-2478  COZINHA / HORTIFRUTI  14:32
--   INV-2479  COZINHA / ESTIVAS     14:58
--   PED-3380  COZINHA / HORTIFRUTI  (liberado pelo Manuel, ainda NAO recebido)
--
-- O SALDO ja caiu na linha certa (COZINHA, a mesma do Centro): nada a
-- acertar no saldo. Este SQL so troca a etiqueta para 'Centro'.
-- O importante e rodar ANTES de alguem receber o PED-3380: recebido como
-- P10 ele tiraria do Estoque Delivery em vez do Estoque da Loja.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura
-- Esperado: 3 contagens + 1 pedido, todos com local = Delivery P10,
-- e o pedido com status = liberado e recebido_em vazio.
select 'contagem' as tipo, num_inv as numero, local, setor, grupo, responsavel, null as status, null as recebido_em
from est_inventarios
where id in ('b36e0e79-b025-419d-8404-fb82f9ff3e38',
             'f969a7a3-30c3-4321-9ffc-c9f7e224da78',
             '8c4b5e21-f9c9-47ed-82dd-5815479be7ef')
union all
select 'pedido', num_pedido, local, setor, obs, responsavel, status, recebido_em::text
from pedidos_internos
where id = 'b0773f9c-1436-47e5-a40c-c5910a45d025';


-- PASSO 2 - troca a unidade das 3 contagens
-- Esperado: UPDATE 3
update est_inventarios
set local = 'Centro'
where id in ('b36e0e79-b025-419d-8404-fb82f9ff3e38',
             'f969a7a3-30c3-4321-9ffc-c9f7e224da78',
             '8c4b5e21-f9c9-47ed-82dd-5815479be7ef')
  and local = 'Delivery P10';


-- PASSO 3 - troca a unidade do pedido (so se ainda nao foi recebido)
-- Esperado: UPDATE 1. Se der UPDATE 0, o pedido ja foi recebido: me avise.
update pedidos_internos
set local = 'Centro'
where id = 'b0773f9c-1436-47e5-a40c-c5910a45d025'
  and local = 'Delivery P10'
  and recebido_em is null;


-- PASSO 4 - conferencia: rodar o PASSO 1 de novo.
-- Esperado: as 4 linhas com local = Centro.
