-- =====================================================================
-- CORRIGE O HISTORICO: "500 NO LUGAR DE 0,5" NO PEDIDO INTERNO   (25/09/2026)
--
-- 14 itens de pedido interno RECEBIDOS com a quantidade em gramas (ou ml)
-- num campo de KG (ou litro). Casos claros, conferidos um a um:
--   mussarela 500 (3x) - alface 500 - alcool 70 500 (3x) - castanha lasca
--   100/100/200/300 - coco lasca 100/50 - banana 1.514
-- A trava que impede de novo ja esta no ar (commit 608b7ed).
--
-- COMO CORRIGE (neutro - o saldo de hoje NAO muda):
--   1. A linha do pedido no razao passa de 500 para 0,5 (saida do ESTOQUE_LOJA
--      e entrada no setor).
--   2. A PRIMEIRA contagem/ajuste seguinte do mesmo produto no mesmo lugar -
--      que foi quem "engoliu" o erro - recebe a diferenca de volta. Ex.: a
--      contagem da COZINHA de 16/09 tinha -500 (sumiu o fantasma); passa a -0,5.
--      Tudo o que vem depois fica igual. So some o fantasma entre o erro e a
--      contagem - que e o que suja os relatorios (Venda x Contagem, placar).
--   3. Onde NADA contou depois (o coco lasca de hoje, PED-2849), a correcao
--      mexe no saldo: BAR -49,95 e ESTOQUE_LOJA +49,95. Se o BAR contar antes
--      de rodar, a contagem vira o passo 2 e o saldo nao e tocado - o SQL acha
--      isso sozinho na hora.
--   4. O item do pedido (pedida/liberada/recebida) passa de 500 para 0,5.
--
-- 6 dos 14 sao de antes do razao existir (07/08): so o item e corrigido.
--
-- FORA DESTE SQL, de proposito (precisam de alguem que saiba o numero certo):
--   PED-1281 Queijo parmegiana 500 (setor costuma 18,5)
--   PED-1865 MP CEU DE BRIGADEIRO: pediu 6, liberou 0, recebeu 800
--   PED-1626 SA PASTEL MISTO 3 UNID: pediu 1, liberou/recebeu 301
--   PED-1708 SA COCO SECO 250G: pediu 3, liberou/recebeu 103
--   PED-2221 MP ALFACE BOLA: pediu 0,04, liberou/recebeu 20
--   PED-1527 e PED-2050 MC SACOLA BRANCA 8KG: 100 (setor costuma 1)
-- E os de habito de unidade, que nao sao digito errado: MP LARANJA do BAR
-- (7x, 20 a 100), MP POLPA GRAVIOLA (88 e 96), MC PAPEL TOALHA (41).
--
-- ATENCAO no alcool 70 do SALAO: a contagem de 20/09 tambem foi digitada em
-- ml (~900). Depois da correcao ela aparece como +898 - e e la mesmo que esta
-- o segundo erro. Nao corrijo contagem aqui.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SO LEITURA
-- ---------------------------------------------------------------------

-- 1a) Nao pode haver gatilho nessas tabelas (esperado: nenhuma linha).
SELECT event_object_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE event_object_table IN ('est_movimentacoes', 'pedidos_internos_itens', 'est_saldo_local');

-- 1b) Os 14 itens como estao hoje. Esperado: 14 linhas, errado = recebida.
WITH fix(item_id, errado, certo) AS (VALUES
  ('f05e335c-6db5-4819-b82e-74e6984a02aa'::uuid, 500::numeric, 0.5::numeric),  -- PED-1443 2026-08-06 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('1c3b381e-b282-4c16-8ba2-25d997f4ffa0'::uuid, 500::numeric, 0.5::numeric),  -- PED-1532 2026-08-08 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('ca2b1eb6-0998-4315-9784-d9dcb3fe9a29'::uuid, 500::numeric, 0.5::numeric),  -- PED-2581 2026-09-14 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('0044d846-ffea-419f-9829-50543ff0ec91'::uuid, 500::numeric, 0.5::numeric),  -- PED-1737 2026-08-15 COZINHA  MP ALFACE BOLA: 500 -> 0.5
  ('47b49326-b0ea-47be-ae4b-6ae339cd66c3'::uuid, 500::numeric, 0.5::numeric),  -- PED-1405 2026-08-05 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('2bebb721-d35f-4a6c-b3e3-043586919da3'::uuid, 500::numeric, 0.5::numeric),  -- PED-1650 2026-08-12 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('e1567175-4505-4ae8-9963-65efbb5eb4a7'::uuid, 500::numeric, 0.5::numeric),  -- PED-2680 2026-09-18 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('2daa24d3-8847-48b9-bb4d-b23b910ad0e2'::uuid, 100::numeric, 0.1::numeric),  -- PED-0179 2026-06-29 BAR      SA CASTANHA LASCA 50g (BAR): 100 -> 0.1
  ('533ba403-5628-4a7e-81a9-8893fcccb4a1'::uuid, 100::numeric, 0.1::numeric),  -- PED-0180 2026-06-29 BAR      SA CASTANHA LASCA 50g (BAR): 100 -> 0.1
  ('95f2aee0-326a-498c-a20c-ed11b0ce459c'::uuid, 200::numeric, 0.2::numeric),  -- PED-1382 2026-08-04 BAR      SA CASTANHA LASCA 50g (BAR): 200 -> 0.2
  ('6179968d-4a4f-4ab6-8f08-a21db0d1e98a'::uuid, 300::numeric, 0.3::numeric),  -- PED-2626 2026-09-16 BAR      SA CASTANHA LASCA 50g (BAR): 300 -> 0.3
  ('599c1963-96be-451d-a466-f7e77a4d691d'::uuid, 100::numeric, 0.1::numeric),  -- PED-2626 2026-09-16 BAR      SA COCO LASCA 50g: 100 -> 0.1
  ('bf04c160-9adf-43bb-aa4a-dda2b0164333'::uuid, 50::numeric, 0.05::numeric),  -- PED-2849 2026-09-25 BAR      SA COCO LASCA 50g: 50 -> 0.05
  ('a116e88a-329d-4e71-9d92-c0b524772057'::uuid, 1514::numeric, 1.514::numeric)   -- PED-1696 2026-08-13 BAR      MP BANANA PACOVA: 1514 -> 1.514
)
SELECT p.num_pedido, p.data, p.setor, i.nome, i.qtd_pedida, i.qtd_liberada, i.qtd_recebida,
       f.errado, f.certo
FROM fix f
JOIN pedidos_internos_itens i ON i.id = f.item_id
JOIN pedidos_internos       p ON p.id = i.pedido_id
ORDER BY p.data;

-- 1c) O que muda no razao. Esperado: 18 linhas (os 8 de depois de 07/08,
--     cada um com a saida do ESTOQUE_LOJA e a entrada no setor).
--     abs_nova = como fica a contagem/ajuste que engoliu o erro.
WITH fix(item_id, errado, certo) AS (VALUES
  ('f05e335c-6db5-4819-b82e-74e6984a02aa'::uuid, 500::numeric, 0.5::numeric),  -- PED-1443 2026-08-06 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('1c3b381e-b282-4c16-8ba2-25d997f4ffa0'::uuid, 500::numeric, 0.5::numeric),  -- PED-1532 2026-08-08 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('ca2b1eb6-0998-4315-9784-d9dcb3fe9a29'::uuid, 500::numeric, 0.5::numeric),  -- PED-2581 2026-09-14 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('0044d846-ffea-419f-9829-50543ff0ec91'::uuid, 500::numeric, 0.5::numeric),  -- PED-1737 2026-08-15 COZINHA  MP ALFACE BOLA: 500 -> 0.5
  ('47b49326-b0ea-47be-ae4b-6ae339cd66c3'::uuid, 500::numeric, 0.5::numeric),  -- PED-1405 2026-08-05 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('2bebb721-d35f-4a6c-b3e3-043586919da3'::uuid, 500::numeric, 0.5::numeric),  -- PED-1650 2026-08-12 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('e1567175-4505-4ae8-9963-65efbb5eb4a7'::uuid, 500::numeric, 0.5::numeric),  -- PED-2680 2026-09-18 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('2daa24d3-8847-48b9-bb4d-b23b910ad0e2'::uuid, 100::numeric, 0.1::numeric),  -- PED-0179 2026-06-29 BAR      SA CASTANHA LASCA 50g (BAR): 100 -> 0.1
  ('533ba403-5628-4a7e-81a9-8893fcccb4a1'::uuid, 100::numeric, 0.1::numeric),  -- PED-0180 2026-06-29 BAR      SA CASTANHA LASCA 50g (BAR): 100 -> 0.1
  ('95f2aee0-326a-498c-a20c-ed11b0ce459c'::uuid, 200::numeric, 0.2::numeric),  -- PED-1382 2026-08-04 BAR      SA CASTANHA LASCA 50g (BAR): 200 -> 0.2
  ('6179968d-4a4f-4ab6-8f08-a21db0d1e98a'::uuid, 300::numeric, 0.3::numeric),  -- PED-2626 2026-09-16 BAR      SA CASTANHA LASCA 50g (BAR): 300 -> 0.3
  ('599c1963-96be-451d-a466-f7e77a4d691d'::uuid, 100::numeric, 0.1::numeric),  -- PED-2626 2026-09-16 BAR      SA COCO LASCA 50g: 100 -> 0.1
  ('bf04c160-9adf-43bb-aa4a-dda2b0164333'::uuid, 50::numeric, 0.05::numeric),  -- PED-2849 2026-09-25 BAR      SA COCO LASCA 50g: 50 -> 0.05
  ('a116e88a-329d-4e71-9d92-c0b524772057'::uuid, 1514::numeric, 1.514::numeric)   -- PED-1696 2026-08-13 BAR      MP BANANA PACOVA: 1514 -> 1.514
), x AS (
  SELECT f.item_id, i.produto_id, p.num_pedido, i.nome, m.id AS mov_id, m.local, m.tipo, m.criado_em,
         m.quantidade AS q_atual, sign(m.quantidade) * f.certo AS q_nova
  FROM fix f
  JOIN pedidos_internos_itens i ON i.id = f.item_id
  JOIN pedidos_internos       p ON p.id = i.pedido_id
  JOIN est_movimentacoes      m ON m.produto_id = i.produto_id
   AND m.tipo IN ('pedido_interno_saida', 'pedido_interno_entrada')
   AND abs(abs(m.quantidade) - f.errado) < 0.000001
   AND m.criado_em BETWEEN p.recebido_em - interval '3 minutes' AND p.recebido_em + interval '3 minutes'
)
SELECT x.num_pedido, x.nome, x.local, x.tipo, x.q_atual, x.q_nova,
       a.tipo AS devolve_em, a.criado_em AS quando, a.quantidade AS abs_atual,
       a.quantidade + (x.q_atual - x.q_nova) AS abs_nova,
       CASE WHEN a.id IS NULL THEN 'SEM CONTAGEM DEPOIS: mexe no saldo' ELSE '' END AS obs
FROM x
LEFT JOIN LATERAL (
  SELECT a.id, a.tipo, a.criado_em, a.quantidade
  FROM est_movimentacoes a
  WHERE a.produto_id = x.produto_id AND a.local = x.local
    AND a.tipo IN ('contagem', 'ajuste', 'saldo_inicial')     -- os que gravam saldo ABSOLUTO
    AND a.criado_em > x.criado_em
  ORDER BY a.criado_em LIMIT 1
) a ON true
ORDER BY x.criado_em, x.local;


-- ---------------------------------------------------------------------
-- PASSO 2 - BACKUP + CORRECAO (rodar este bloco inteiro de uma vez)
-- Se rodar duas vezes, o segundo para sozinho: as linhas ja nao tem 500.
-- ---------------------------------------------------------------------
BEGIN;

CREATE TEMP TABLE fix (item_id uuid PRIMARY KEY, errado numeric NOT NULL, certo numeric NOT NULL) ON COMMIT DROP;
INSERT INTO fix (item_id, errado, certo) VALUES
  ('f05e335c-6db5-4819-b82e-74e6984a02aa'::uuid, 500::numeric, 0.5::numeric),  -- PED-1443 2026-08-06 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('1c3b381e-b282-4c16-8ba2-25d997f4ffa0'::uuid, 500::numeric, 0.5::numeric),  -- PED-1532 2026-08-08 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('ca2b1eb6-0998-4315-9784-d9dcb3fe9a29'::uuid, 500::numeric, 0.5::numeric),  -- PED-2581 2026-09-14 COZINHA  MP QUEIJO MUSSARELA FATIADO: 500 -> 0.5
  ('0044d846-ffea-419f-9829-50543ff0ec91'::uuid, 500::numeric, 0.5::numeric),  -- PED-1737 2026-08-15 COZINHA  MP ALFACE BOLA: 500 -> 0.5
  ('47b49326-b0ea-47be-ae4b-6ae339cd66c3'::uuid, 500::numeric, 0.5::numeric),  -- PED-1405 2026-08-05 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('2bebb721-d35f-4a6c-b3e3-043586919da3'::uuid, 500::numeric, 0.5::numeric),  -- PED-1650 2026-08-12 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('e1567175-4505-4ae8-9963-65efbb5eb4a7'::uuid, 500::numeric, 0.5::numeric),  -- PED-2680 2026-09-18 SALAO    MC ALCOOL LIQUIDO 70: 500 -> 0.5
  ('2daa24d3-8847-48b9-bb4d-b23b910ad0e2'::uuid, 100::numeric, 0.1::numeric),  -- PED-0179 2026-06-29 BAR      SA CASTANHA LASCA 50g (BAR): 100 -> 0.1
  ('533ba403-5628-4a7e-81a9-8893fcccb4a1'::uuid, 100::numeric, 0.1::numeric),  -- PED-0180 2026-06-29 BAR      SA CASTANHA LASCA 50g (BAR): 100 -> 0.1
  ('95f2aee0-326a-498c-a20c-ed11b0ce459c'::uuid, 200::numeric, 0.2::numeric),  -- PED-1382 2026-08-04 BAR      SA CASTANHA LASCA 50g (BAR): 200 -> 0.2
  ('6179968d-4a4f-4ab6-8f08-a21db0d1e98a'::uuid, 300::numeric, 0.3::numeric),  -- PED-2626 2026-09-16 BAR      SA CASTANHA LASCA 50g (BAR): 300 -> 0.3
  ('599c1963-96be-451d-a466-f7e77a4d691d'::uuid, 100::numeric, 0.1::numeric),  -- PED-2626 2026-09-16 BAR      SA COCO LASCA 50g: 100 -> 0.1
  ('bf04c160-9adf-43bb-aa4a-dda2b0164333'::uuid, 50::numeric, 0.05::numeric),  -- PED-2849 2026-09-25 BAR      SA COCO LASCA 50g: 50 -> 0.05
  ('a116e88a-329d-4e71-9d92-c0b524772057'::uuid, 1514::numeric, 1.514::numeric)   -- PED-1696 2026-08-13 BAR      MP BANANA PACOVA: 1514 -> 1.514
;

CREATE TEMP TABLE fix_mov ON COMMIT DROP AS
  SELECT f.item_id, i.produto_id, p.num_pedido, i.nome, m.id AS mov_id, m.local, m.tipo, m.criado_em,
         m.quantidade AS q_atual, sign(m.quantidade) * f.certo AS q_nova
  FROM fix f
  JOIN pedidos_internos_itens i ON i.id = f.item_id
  JOIN pedidos_internos       p ON p.id = i.pedido_id
  JOIN est_movimentacoes      m ON m.produto_id = i.produto_id
   AND m.tipo IN ('pedido_interno_saida', 'pedido_interno_entrada')
   AND abs(abs(m.quantidade) - f.errado) < 0.000001
   AND m.criado_em BETWEEN p.recebido_em - interval '3 minutes' AND p.recebido_em + interval '3 minutes';

CREATE TEMP TABLE fix_abs ON COMMIT DROP AS
SELECT x.mov_id, x.produto_id, x.local, (x.q_atual - x.q_nova) AS diff, a.id AS abs_id
FROM fix_mov x
LEFT JOIN LATERAL (
  SELECT a.id, a.tipo, a.criado_em, a.quantidade
  FROM est_movimentacoes a
  WHERE a.produto_id = x.produto_id AND a.local = x.local
    AND a.tipo IN ('contagem', 'ajuste', 'saldo_inicial')     -- os que gravam saldo ABSOLUTO
    AND a.criado_em > x.criado_em
  ORDER BY a.criado_em LIMIT 1
) a ON true;

DO $chk$
BEGIN
  IF (SELECT count(*) FROM fix) <> 14 THEN
    RAISE EXCEPTION 'Esperava 14 itens, achou %. Nada foi alterado.', (SELECT count(*) FROM fix);
  END IF;
  IF (SELECT count(*) FROM fix_mov) <> 18 THEN
    RAISE EXCEPTION 'Esperava 18 linhas do razao, achou %. Nada foi alterado.', (SELECT count(*) FROM fix_mov);
  END IF;
END $chk$;

CREATE TABLE bkp_fix500_itens_20260925 AS
  SELECT i.* FROM pedidos_internos_itens i WHERE i.id IN (SELECT item_id FROM fix);
CREATE TABLE bkp_fix500_mov_20260925 AS
  SELECT m.* FROM est_movimentacoes m
  WHERE m.id IN (SELECT mov_id FROM fix_mov UNION SELECT abs_id FROM fix_abs WHERE abs_id IS NOT NULL);
CREATE TABLE bkp_fix500_saldo_20260925 AS
  SELECT s.* FROM est_saldo_local s
  JOIN (SELECT DISTINCT produto_id, local FROM fix_abs WHERE abs_id IS NULL) z
    ON z.produto_id = s.produto_id AND z.local = s.local;

-- 1) razao: a linha do pedido passa de 500 para 0,5
UPDATE est_movimentacoes m
SET quantidade = x.q_nova,
    motivo = coalesce(m.motivo, '') || ' [corrigido 25/09/2026: era ' || x.q_atual || ']'
FROM fix_mov x
WHERE m.id = x.mov_id;

-- 2) razao: a contagem/ajuste que engoliu o erro devolve a diferenca
UPDATE est_movimentacoes m
SET quantidade = m.quantidade + z.diff,
    motivo = coalesce(m.motivo, '') || ' [corrigido 25/09/2026: ' || z.diff || ' de pedido com 500 no lugar de 0,5]'
FROM (SELECT abs_id, sum(diff) AS diff FROM fix_abs WHERE abs_id IS NOT NULL GROUP BY abs_id) z
WHERE m.id = z.abs_id;

-- 3) saldo: so onde nada contou depois do erro
UPDATE est_saldo_local s
SET saldo = s.saldo - z.diff, updated_at = now()
FROM (SELECT produto_id, local, sum(diff) AS diff FROM fix_abs WHERE abs_id IS NULL GROUP BY produto_id, local) z
WHERE s.produto_id = z.produto_id AND s.local = z.local;

-- 4) o item do pedido
UPDATE pedidos_internos_itens i
SET qtd_pedida   = CASE WHEN abs(i.qtd_pedida   - f.errado) < 0.000001 THEN f.certo ELSE i.qtd_pedida   END,
    qtd_liberada = CASE WHEN abs(i.qtd_liberada - f.errado) < 0.000001 THEN f.certo ELSE i.qtd_liberada END,
    qtd_recebida = CASE WHEN abs(i.qtd_recebida - f.errado) < 0.000001 THEN f.certo ELSE i.qtd_recebida END
FROM fix f
WHERE i.id = f.item_id;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA
-- ---------------------------------------------------------------------

-- 3a) Itens: nenhum 500 sobrou. Esperado: 14 linhas, recebida = certo.
SELECT b.id, b.nome, b.qtd_recebida AS antes, i.qtd_recebida AS agora
FROM bkp_fix500_itens_20260925 b JOIN pedidos_internos_itens i ON i.id = b.id
ORDER BY b.nome;

-- 3b) Razao, por produto e lugar: a SOMA nao pode mudar onde houve contagem
--     depois (mudou = 0). So o coco lasca, se o BAR ainda nao tiver contado,
--     aparece com -49,95 (BAR) e +49,95 (ESTOQUE_LOJA) - igual ao 3c.
SELECT pr.nome, b.local, sum(b.quantidade) AS antes, sum(m.quantidade) AS agora,
       round(sum(m.quantidade) - sum(b.quantidade), 6) AS mudou
FROM bkp_fix500_mov_20260925 b
JOIN est_movimentacoes m ON m.id = b.id
JOIN est_produtos pr     ON pr.id = b.produto_id
GROUP BY pr.nome, b.local
ORDER BY pr.nome, b.local;

-- 3c) Saldo mexido (so onde nada contou depois). Pode vir vazio.
SELECT pr.nome, b.local, b.saldo AS antes, s.saldo AS agora
FROM bkp_fix500_saldo_20260925 b
JOIN est_saldo_local s ON s.produto_id = b.produto_id AND s.local = b.local
JOIN est_produtos pr   ON pr.id = b.produto_id;


-- ---------------------------------------------------------------------
-- DESFAZER (so logo depois de rodar - o saldo volta ao valor do backup)
-- ---------------------------------------------------------------------
-- BEGIN;
-- UPDATE est_movimentacoes m SET quantidade = b.quantidade, motivo = b.motivo
--   FROM bkp_fix500_mov_20260925 b WHERE m.id = b.id;
-- UPDATE pedidos_internos_itens i SET qtd_pedida = b.qtd_pedida, qtd_liberada = b.qtd_liberada, qtd_recebida = b.qtd_recebida
--   FROM bkp_fix500_itens_20260925 b WHERE i.id = b.id;
-- UPDATE est_saldo_local s SET saldo = b.saldo
--   FROM bkp_fix500_saldo_20260925 b WHERE s.produto_id = b.produto_id AND s.local = b.local;
-- COMMIT;
