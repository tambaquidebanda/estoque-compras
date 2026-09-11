-- ============================================================================
-- SQL_ENCERRAR_PEDIDOS_ANTIGOS_11SET.sql
-- Encerra, SEM MEXER EM SALDO NENHUM, os pedidos internos que foram liberados
-- (entregues) antes do inventario do estoque de 11/09/2026 e nunca foram
-- confirmados pelo setor. Se algum setor confirmasse um deles depois do
-- inventario, o sistema tiraria a mercadoria do estoque pela segunda vez
-- (foi o que gerou metade dos 59 saldos negativos em 11/09 13:32-13:36).
-- Corte: liberados antes de 11/09/2026 14:00 (Manaus), inicio do inventario.
-- RODE DEPOIS QUE O INVENTARIO DO ESTOQUE TERMINAR.
-- ============================================================================

-- PASSO 0 - SO LEITURA. Regra do banco que limita os status. O esperado e vir VAZIO.
-- Se vier alguma linha falando de "status", PARE e me mande o resultado.
SELECT conname, pg_get_constraintdef(oid) AS regra
  FROM pg_constraint
 WHERE conrelid = 'pedidos_internos'::regclass AND contype = 'c';

-- PASSO 1 - SO LEITURA. Quantos pedidos vao ser encerrados, por setor.
-- Esperado: por volta de 545 no total (542 liberados antes de hoje + os de hoje de manha).
SELECT setor, count(*) AS pedidos, min(liberado_em) AS mais_antigo, max(liberado_em) AS mais_novo
  FROM pedidos_internos
 WHERE status = 'liberado'
   AND (liberado_em < timestamptz '2026-09-11 14:00:00-04' OR liberado_em IS NULL)
 GROUP BY setor
 ORDER BY pedidos DESC;

-- PASSO 2 - ENCERRA. Guarda antes a lista (para poder desfazer) e depois muda o status.
-- Esperado: "SELECT <n>" e depois "UPDATE <n>" com o MESMO numero do total do PASSO 1.
BEGIN;

CREATE TABLE bkp_pedidos_encerrados_11set AS
SELECT id, num_pedido, setor, liberado_em, now() AS encerrado_em
  FROM pedidos_internos
 WHERE status = 'liberado'
   AND (liberado_em < timestamptz '2026-09-11 14:00:00-04' OR liberado_em IS NULL);

UPDATE pedidos_internos SET status = 'encerrado'
 WHERE status = 'liberado'
   AND id IN (SELECT id FROM bkp_pedidos_encerrados_11set);

COMMIT;

-- PASSO 3 - CONFERENCIA. Deve vir 0.
SELECT count(*) AS ainda_liberados_antigos
  FROM pedidos_internos
 WHERE status = 'liberado'
   AND (liberado_em < timestamptz '2026-09-11 14:00:00-04' OR liberado_em IS NULL);

-- PARA DESFAZER (so se eu pedir):
-- UPDATE pedidos_internos SET status = 'liberado'
--  WHERE status = 'encerrado' AND id IN (SELECT id FROM bkp_pedidos_encerrados_11set);
