-- ═══════════════════════════════════════════════════════════════════════════
-- PED-4029 (seg 02/11/2026 16:38) foi uma transferencia AO CONTRARIO
--
-- O Ricardo pediu ao Central o PED-4020 (bolinho, batata, file de frango, isca). O Central
-- lancou o envio como "Envio do Centro" (PED-4029: loja -> Central) e o Ricardo confirmou
-- a chegada dele no Central em 03/11 09:29. Depois o Central liberou o PED-4020 certo
-- (11:08) e a loja confirmou as 12:10. Foi UMA remessa so (confirmado pelo Wagner).
--
-- Este SQL:
--  a) desfaz o PED-4029: devolve a loja e tira do Central, com linhas de estorno no razao
--     (mesmo tipo, quantidade com sinal trocado, ref_tabela 'estorno_pedidos_internos_itens');
--     no Central so bolinho e batata — file de frango e isca foram acertados a mao no
--     Central as 11:40 ("Saldo inicial", zerou os dois), depois do PED-4029;
--  b) soma na loja os 67 bolinhos do PED-4020 que a trava de "ja contado no destino" nao
--     somou as 12:10. A trava pegou o estorno do PED-3973 (11:49, tipo ajuste) como se fosse
--     contagem. Linha igual a do botao "somar o que nao somou", para a tela reconhecer;
--  c) PED-4029 vira 'cancelado', com o motivo na observacao.
-- Pode rodar mais de uma vez: so age se o PED-4029 ainda estiver 'recebido'.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) CONFERIR ANTES
SELECT p.nome, s.local, s.saldo AS saldo_hoje,
       s.saldo + CASE
         WHEN s.local = 'ESTOQUE_LOJA' THEN v.loja + v.bolinho_4020
         ELSE v.central END AS saldo_depois
FROM (VALUES
  ('63b66bb0-1ab8-4d25-b80f-54156d5bad26'::uuid, 67, -67, 67),   -- SA BOLINHO DE TAMBAQUI 5 UNID
  ('97d60b41-adce-419a-b834-129c3c4e237a'::uuid, 60, -60,  0),   -- SA BATATA 100g
  ('6f4bab55-b7b4-4118-92c7-30492a885a84'::uuid, 20,   0,  0),   -- SA FILE DE FRANGO 70g
  ('17a27a31-60ac-44a4-9cb1-10c97d3c32c5'::uuid, 30,   0,  0)    -- SA ISCA DE FRANGO 130g
) AS v(produto_id, loja, central, bolinho_4020)
JOIN est_produtos p ON p.id = v.produto_id
JOIN est_saldo_local s ON s.produto_id = v.produto_id AND s.local IN ('ESTOQUE_LOJA', 'CENTRAL')
ORDER BY p.nome, s.local;
-- esperado: bolinho loja -207 -> -73 e central 50 -> -17; batata loja 112 -> 172 e
-- central 150 -> 90; file loja 20 -> 40; isca loja 20 -> 50 (central dos dois nao muda)

-- 2) CORRIGIR
BEGIN;

CREATE TEMP TABLE _mov_4029 ON COMMIT DROP AS
SELECT * FROM (VALUES
  -- a) estorno do PED-4029 na loja (saida ao contrario volta)
  ('63b66bb0-1ab8-4d25-b80f-54156d5bad26'::uuid, 'ESTOQUE_LOJA', 'transferencia_saida',    67::numeric, 'estorno_pedidos_internos_itens', 'b8ff8df3-0ef1-484c-ba4e-380c6a64df00'::uuid, 'Estorno PED-4029 (transferência lançada ao contrário; a remessa é o PED-4020)'),
  ('97d60b41-adce-419a-b834-129c3c4e237a'::uuid, 'ESTOQUE_LOJA', 'transferencia_saida',    60,          'estorno_pedidos_internos_itens', '8542579e-63e8-4fb3-bafc-6dded1b5ebfc'::uuid, 'Estorno PED-4029 (transferência lançada ao contrário; a remessa é o PED-4020)'),
  ('6f4bab55-b7b4-4118-92c7-30492a885a84'::uuid, 'ESTOQUE_LOJA', 'transferencia_saida',    20,          'estorno_pedidos_internos_itens', 'f8452788-44e3-484e-ba5d-8db2a4f4e4a6'::uuid, 'Estorno PED-4029 (transferência lançada ao contrário; a remessa é o PED-4020)'),
  ('17a27a31-60ac-44a4-9cb1-10c97d3c32c5'::uuid, 'ESTOQUE_LOJA', 'transferencia_saida',    30,          'estorno_pedidos_internos_itens', 'd315d372-c530-4d60-a210-9ad04a097fc1'::uuid, 'Estorno PED-4029 (transferência lançada ao contrário; a remessa é o PED-4020)'),
  -- a) estorno do PED-4029 no Central (so bolinho e batata)
  ('63b66bb0-1ab8-4d25-b80f-54156d5bad26'::uuid, 'CENTRAL',      'transferencia_entrada', -67,          'estorno_pedidos_internos_itens', 'b8ff8df3-0ef1-484c-ba4e-380c6a64df00'::uuid, 'Estorno PED-4029 (transferência lançada ao contrário; a remessa é o PED-4020)'),
  ('97d60b41-adce-419a-b834-129c3c4e237a'::uuid, 'CENTRAL',      'transferencia_entrada', -60,          'estorno_pedidos_internos_itens', '8542579e-63e8-4fb3-bafc-6dded1b5ebfc'::uuid, 'Estorno PED-4029 (transferência lançada ao contrário; a remessa é o PED-4020)'),
  -- b) bolinho do PED-4020 que nao somou na chegada
  ('63b66bb0-1ab8-4d25-b80f-54156d5bad26'::uuid, 'ESTOQUE_LOJA', 'transferencia_entrada',  67,          'pedidos_internos_itens',         '67c60f0a-d0d8-46c3-970d-83b71546f7c0'::uuid, 'Transferência PED-4020 ← Estoque Central · somado depois por SQL em 03/11 (a trava confundiu o estorno do PED-3973 com contagem)')
) AS t(produto_id, local, tipo, quantidade, ref_tabela, ref_id, motivo)
WHERE EXISTS (SELECT 1 FROM pedidos_internos WHERE num_pedido = 'PED-4029' AND status = 'recebido');

INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, ref_tabela, ref_id, responsavel, data)
SELECT produto_id, local, tipo, quantidade, motivo, 'transferencia', ref_tabela, ref_id, 'SQL 03/11/2026', '2026-11-03'
FROM _mov_4029;

UPDATE est_saldo_local s
SET saldo = s.saldo + m.q, updated_at = now()
FROM (SELECT produto_id, local, SUM(quantidade) AS q FROM _mov_4029 GROUP BY produto_id, local) m
WHERE s.produto_id = m.produto_id AND s.local = m.local;

UPDATE pedidos_internos
SET status = 'cancelado',
    obs = obs || ' · CANCELADO por SQL em 03/11: lançado ao contrário, a remessa é o PED-4020 (estornado na loja e no Central)'
WHERE num_pedido = 'PED-4029' AND status = 'recebido'
  AND EXISTS (SELECT 1 FROM _mov_4029);

UPDATE pedidos_internos
SET obs = obs || ' · bolinho somado depois por SQL em 03/11'
WHERE num_pedido = 'PED-4020'
  AND EXISTS (SELECT 1 FROM _mov_4029);

-- deve mostrar 7 linhas
SELECT COUNT(*) AS linhas FROM _mov_4029;

COMMIT;
