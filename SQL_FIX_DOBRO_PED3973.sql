-- ═══════════════════════════════════════════════════════════════════════════
-- PED-3973 (cozinha, sab 31/10/2026 23:26) baixou 19 itens DUAS VEZES do ESTOQUE_LOJA
--
-- O aparelho que liberou parou depois do 10o item da baixa. 18 s depois a cozinha
-- confirmou e a confirmacao cobrou da loja os 36 itens sem baixa ("liberado 0, chegou N").
-- As 23:45 o aparelho voltou e baixou de novo 19 deles. 291,5 unidades a mais.
--
-- Este SQL devolve ao ESTOQUE_LOJA a cobranca da confirmacao desses 19 itens, com uma
-- linha de 'ajuste' no razao (mesmo ref do item) e o saldo somado. A baixa da liberacao
-- (23:45) fica: ela e a marca de "saiu na liberacao" que o resto do sistema usa.
--
-- Pode rodar mais de uma vez: o item que ja tem o estorno nao entra de novo.
-- Conferido em 03/11 antes de escrever: ninguem contou nem ajustou esses itens na loja
-- depois de sabado 23:45 (se tivesse contado, a contagem ja teria corrigido o saldo).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) CONFERIR ANTES — deve listar 19 linhas, soma 291,5
WITH ped AS (SELECT id FROM pedidos_internos WHERE num_pedido = 'PED-3973'),
itens AS (SELECT i.id FROM pedidos_internos_itens i JOIN ped ON i.pedido_id = ped.id),
dobro AS (
  SELECT a.ref_id, a.produto_id, -a.quantidade AS devolver
  FROM est_movimentacoes a
  WHERE a.ref_id IN (SELECT id FROM itens)
    AND a.local = 'ESTOQUE_LOJA' AND a.tipo = 'ajuste'
    AND a.motivo LIKE 'Diferença na confirmação PED-3973: liberado 0,%'
    AND EXISTS (SELECT 1 FROM est_movimentacoes s
                WHERE s.ref_id = a.ref_id AND s.tipo = 'pedido_interno_saida' AND s.local = 'ESTOQUE_LOJA')
    AND NOT EXISTS (SELECT 1 FROM est_movimentacoes e
                    WHERE e.ref_id = a.ref_id AND e.motivo LIKE 'Estorno da baixa em dobro PED-3973%')
)
SELECT p.nome, d.devolver, s.saldo AS saldo_hoje, s.saldo + d.devolver AS saldo_depois
FROM dobro d
JOIN est_produtos p ON p.id = d.produto_id
LEFT JOIN est_saldo_local s ON s.produto_id = d.produto_id AND s.local = 'ESTOQUE_LOJA'
ORDER BY p.nome;

-- 2) CORRIGIR
BEGIN;

CREATE TEMP TABLE _dobro_3973 ON COMMIT DROP AS
WITH ped AS (SELECT id FROM pedidos_internos WHERE num_pedido = 'PED-3973'),
itens AS (SELECT i.id FROM pedidos_internos_itens i JOIN ped ON i.pedido_id = ped.id)
SELECT a.ref_id, a.produto_id, -a.quantidade AS devolver
FROM est_movimentacoes a
WHERE a.ref_id IN (SELECT id FROM itens)
  AND a.local = 'ESTOQUE_LOJA' AND a.tipo = 'ajuste'
  AND a.motivo LIKE 'Diferença na confirmação PED-3973: liberado 0,%'
  AND EXISTS (SELECT 1 FROM est_movimentacoes s
              WHERE s.ref_id = a.ref_id AND s.tipo = 'pedido_interno_saida' AND s.local = 'ESTOQUE_LOJA')
  AND NOT EXISTS (SELECT 1 FROM est_movimentacoes e
                  WHERE e.ref_id = a.ref_id AND e.motivo LIKE 'Estorno da baixa em dobro PED-3973%');

INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, ref_tabela, ref_id, responsavel, data)
SELECT produto_id, 'ESTOQUE_LOJA', 'ajuste', devolver,
       'Estorno da baixa em dobro PED-3973 (liberação parou no meio e voltou depois da confirmação)',
       'pedido_interno', 'pedidos_internos_itens', ref_id, 'SQL 03/11/2026', '2026-11-03'
FROM _dobro_3973;

UPDATE est_saldo_local s
SET saldo = s.saldo + d.devolver, updated_at = now()
FROM (SELECT produto_id, SUM(devolver) AS devolver FROM _dobro_3973 GROUP BY produto_id) d
WHERE s.produto_id = d.produto_id AND s.local = 'ESTOQUE_LOJA';

-- deve mostrar 19 itens e 291.5
SELECT COUNT(*) AS itens, SUM(devolver) AS unidades FROM _dobro_3973;

COMMIT;

-- 3) TRAVA NO BANCO — uma baixa de liberacao por item de pedido, nunca duas.
-- O codigo novo (liberacao e confirmacao) grava essa marca e, se ela ja existe, nao mexe
-- no saldo. Conferido em 03/11: nenhum item tem marca repetida (1.089 marcas).
CREATE UNIQUE INDEX IF NOT EXISTS est_mov_baixa_liberacao_unica
  ON est_movimentacoes (ref_id)
  WHERE tipo = 'pedido_interno_saida' AND ref_tabela = 'pedidos_internos_itens';
