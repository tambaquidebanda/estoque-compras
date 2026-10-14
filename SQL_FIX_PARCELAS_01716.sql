-- ============================================================
-- Pedido #01716 (VARIEDADES SALMO 91) - parcelas do boleto (14/10/2026)
--
-- Boleto: 1a = 1.316,74 / 2a e 3a = 1.316,73 (total 3.950,20).
-- O sistema poe a sobra do centavo na ULTIMA parcela; gerou 1.316,73 /
-- 1.316,73 / 1.316,74. As 3 ainda sao rascunho (nao aprovadas no
-- financeiro), entao basta trocar o centavo entre a 1a e a 3a.
-- O total nao muda. O codigo ja foi corrigido para os proximos pedidos.
--
-- Rodar um passo de cada vez no SQL Editor do Supabase.
-- ============================================================


-- PASSO 1 - so leitura
-- Esperado: 3 linhas: (1/3) 1316.73 em 23/10, (2/3) 1316.73 em 07/11,
-- (3/3) 1316.74 em 22/11.
select id, descricao, valor, vencimento
from lancamentos_rascunho
where pedido_num = '#01716'
order by vencimento;


-- PASSO 2 - 1a parcela passa a 1.316,74
-- Esperado: UPDATE 1
update lancamentos_rascunho
set valor = 1316.74
where id = 'c3b3911d-a2c5-4406-b6f1-bb354e265476'
  and pedido_num = '#01716'
  and valor = 1316.73;


-- PASSO 3 - 3a parcela passa a 1.316,73
-- Esperado: UPDATE 1
update lancamentos_rascunho
set valor = 1316.73
where id = 'eb4fb026-1c0a-41dd-aad8-1f4197e837f8'
  and pedido_num = '#01716'
  and valor = 1316.74;


-- PASSO 4 - conferencia: rodar o PASSO 1 de novo.
-- Esperado: 1316.74 / 1316.73 / 1316.73, soma 3950.20.
