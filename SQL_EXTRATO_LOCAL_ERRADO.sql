-- =====================================================================
-- SQL_EXTRATO_LOCAL_ERRADO.sql   (26/10/2026)
--
-- MP EXTRATO DE TOMATE tem 6 num local escrito errado, 'ESTOQUE DA LOJA'
-- (com espacos), desde 03/08/2026. O local certo e 'ESTOQUE_LOJA'.
-- A tela de Saldo nao mostra esse local, mas o Planejamento de compras
-- e a Meta somam ele no "Tem agora".
--
-- O que este SQL faz: passa o saldo do local errado para o ESTOQUE_LOJA
-- (razao + saldo) e apaga a linha do local errado.
-- Nao mexe em pedido, compra nem financeiro. Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA.
-- Esperado: 1 linha, MP EXTRATO DE TOMATE, ESTOQUE DA LOJA, 6.
-- Se aparecer outro produto nesse local, PARE e me mande o resultado.
-- =====================================================================
SELECT p.nome, s.local, s.saldo, s.updated_at
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.local = 'ESTOQUE DA LOJA';

-- saldo atual no local certo (so para comparar no PASSO 3)
SELECT p.nome, s.local, s.saldo
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id = '2b20909f-505b-4b5b-92a5-0a0edc9be22d'
   AND s.local = 'ESTOQUE_LOJA';


-- =====================================================================
-- PASSO 2 - CORRIGE (tudo ou nada)
-- =====================================================================
BEGIN;

DO $$
DECLARE
  ext constant uuid := '2b20909f-505b-4b5b-92a5-0a0edc9be22d';   -- MP EXTRATO DE TOMATE
  q   numeric;
  n   int;
BEGIN
  SELECT count(*) INTO n FROM est_saldo_local WHERE local = 'ESTOQUE DA LOJA';
  IF n <> 1 THEN
    RAISE EXCEPTION 'Esperava 1 linha no local ESTOQUE DA LOJA e achei %. Nada foi alterado.', n;
  END IF;

  SELECT saldo INTO q FROM est_saldo_local WHERE produto_id = ext AND local = 'ESTOQUE DA LOJA';
  IF q IS NULL THEN
    RAISE EXCEPTION 'A linha do local errado nao e do extrato de tomate. Nada foi alterado.';
  END IF;

  IF q <> 0 THEN
    INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
    VALUES (ext, 'ESTOQUE DA LOJA', 'ajuste', -q,
            'Local escrito errado (ESTOQUE DA LOJA) passa para ESTOQUE_LOJA (26/10/2026)',
            'ajuste', 'SQL extrato local errado', (now() AT TIME ZONE 'America/Manaus')::date),
           (ext, 'ESTOQUE_LOJA', 'ajuste', q,
            'Saldo que estava no local escrito errado (ESTOQUE DA LOJA) (26/10/2026)',
            'ajuste', 'SQL extrato local errado', (now() AT TIME ZONE 'America/Manaus')::date);

    INSERT INTO est_saldo_local (produto_id, local, saldo, updated_at)
    VALUES (ext, 'ESTOQUE_LOJA', q, now())
    ON CONFLICT (produto_id, local) DO UPDATE
      SET saldo = est_saldo_local.saldo + EXCLUDED.saldo, updated_at = now();
  END IF;

  DELETE FROM est_saldo_local WHERE produto_id = ext AND local = 'ESTOQUE DA LOJA';

  RAISE NOTICE '% de extrato passaram para o ESTOQUE_LOJA', q;
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura).
-- Esperado: nenhuma linha no local errado; ESTOQUE_LOJA = valor do
-- PASSO 1 + 6.
-- =====================================================================
SELECT count(*) AS linhas_no_local_errado FROM est_saldo_local WHERE local = 'ESTOQUE DA LOJA';

SELECT p.nome, s.local, s.saldo
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id = '2b20909f-505b-4b5b-92a5-0a0edc9be22d'
   AND s.local = 'ESTOQUE_LOJA';
