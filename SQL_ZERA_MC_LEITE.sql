-- =====================================================================
-- SQL_ZERA_MC_LEITE.sql  (19/11/2026)
--
-- MC LEITE LIQUIDO INTEGRAL (UN, refeição dos funcionários) ficou com
--   ESTOQUE_LOJA = -21  e  COZINHA = +21
-- desde 19/09: emergências da Cozinha (ago-set) lançadas neste cadastro,
-- enquanto o leite da prateleira é o MP LEITE LIQUIDO INTEGRAL (LI).
-- Só 3 unidades foram compradas neste cadastro (#00167, #00791).
--
-- Este SQL zera as duas linhas e grava o acerto no razão (est_movimentacoes),
-- para a soma do razão continuar igual ao saldo. Não mexe no MP LEITE.
--
-- Rode UM PASSO DE CADA VEZ. Se der "ASSERT failed", nada foi gravado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Esperado: ESTOQUE_LOJA -21 e COZINHA 21,
-- e a soma do razão igual (-21 / 21).
-- ---------------------------------------------------------------------
SELECT s.local, s.saldo,
       (SELECT coalesce(sum(m.quantidade), 0) FROM est_movimentacoes m
         WHERE m.produto_id = s.produto_id AND m.local = s.local) AS soma_razao
  FROM est_saldo_local s
 WHERE s.produto_id = 'e0ff27e7-3385-417b-b9f2-d07f9b5059f8'
 ORDER BY s.local;


-- ---------------------------------------------------------------------
-- PASSO 2 - ZERA O MC LEITE (ESTOQUE_LOJA +21, COZINHA -21).
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  c_prod constant uuid := 'e0ff27e7-3385-417b-b9f2-d07f9b5059f8';   -- MC LEITE LIQUIDO INTEGRAL
  c_mot  constant text := 'Ajuste SQL 19/11: zera MC LEITE (emergências de ago-set lançadas no cadastro errado; o leite é o MP)';
  v_n int;
BEGIN
  ASSERT (SELECT nome FROM est_produtos WHERE id = c_prod) = 'MC LEITE LIQUIDO INTEGRAL', 'produto não confere';
  ASSERT (SELECT saldo FROM est_saldo_local WHERE produto_id = c_prod AND local = 'ESTOQUE_LOJA') = -21,
         'ESTOQUE_LOJA não está em -21 - mudou desde 19/11, nada foi gravado';
  ASSERT (SELECT saldo FROM est_saldo_local WHERE produto_id = c_prod AND local = 'COZINHA') = 21,
         'COZINHA não está em 21 - mudou desde 19/11, nada foi gravado';
  ASSERT NOT EXISTS (SELECT 1 FROM est_movimentacoes WHERE produto_id = c_prod AND motivo = c_mot),
         'este acerto já foi gravado';

  UPDATE est_saldo_local SET saldo = 0, updated_at = now()
   WHERE produto_id = c_prod AND local IN ('ESTOQUE_LOJA', 'COZINHA');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 2, format('esperava 2 linhas de saldo, atualizou %s', v_n);

  INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
  VALUES (c_prod, 'ESTOQUE_LOJA', 'ajuste',  21, c_mot, 'ajuste_manual', 'Ajuste SQL 19/11', '2026-11-19'),
         (c_prod, 'COZINHA',      'ajuste', -21, c_mot, 'ajuste_manual', 'Ajuste SQL 19/11', '2026-11-19');

  ASSERT NOT EXISTS (SELECT 1 FROM est_saldo_local WHERE produto_id = c_prod AND saldo <> 0), 'sobrou saldo';
  ASSERT (SELECT coalesce(sum(quantidade), 0) FROM est_movimentacoes WHERE produto_id = c_prod AND local = 'ESTOQUE_LOJA') = 0,
         'razão do ESTOQUE_LOJA não fechou em 0';
  ASSERT (SELECT coalesce(sum(quantidade), 0) FROM est_movimentacoes WHERE produto_id = c_prod AND local = 'COZINHA') = 0,
         'razão da COZINHA não fechou em 0';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - SÓ LEITURA. Esperado: as duas linhas com saldo 0 e soma_razao 0.
-- ---------------------------------------------------------------------
SELECT s.local, s.saldo,
       (SELECT coalesce(sum(m.quantidade), 0) FROM est_movimentacoes m
         WHERE m.produto_id = s.produto_id AND m.local = s.local) AS soma_razao
  FROM est_saldo_local s
 WHERE s.produto_id = 'e0ff27e7-3385-417b-b9f2-d07f9b5059f8'
 ORDER BY s.local;
