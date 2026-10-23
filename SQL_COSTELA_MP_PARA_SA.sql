-- =====================================================================
-- SQL_COSTELA_MP_PARA_SA.sql   (23/10/2026)
--
-- A costela que sai da Producao e SA COSTELA DE TAMBAQUI. Na loja ela estava
-- sendo contada com o nome errado, MP COSTELA DE TAMBAQUI:
--   21/10 11:45  Central transfere 150 SA COSTELA para o Estoque da Loja
--   22/10 13:02  contagem INV-2701 (Anderson): SA = 0 e MP = 150
--   23/10 09:53  pedido interno da cozinha leva 15 "MP" -> sobra MP 135, SA 0
-- A meta de producao le a SA, entao enxergava 0 costela na loja.
--
-- A MP aparece na tela porque continua na lista da COZINHA / CONGELADOS do
-- Centro (o Estoque da Loja junta as listas dos setores). Ela saiu da
-- Churrasqueira e do P10, mas nunca saiu da Cozinha; a cozinha conta MP e SA
-- toda noite.
--
-- O que este SQL faz:
--   1) Estoque da Loja: todo o saldo da MP passa para a SA (razao + saldo).
--   2) Cozinha: idem (a contagem desta noite acerta o numero).
--   3) Tira MP COSTELA DE TAMBAQUI da lista Centro > COZINHA > CONGELADOS
--      (a SA continua la, pelas adicoes). Nada mais da estrutura e tocado.
-- Nao mexe em pedido, compra nem financeiro. Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA.
-- (a) saldos: esperado MP loja 135, SA loja 0, MP cozinha 23, SA cozinha 8
-- (b) MP na lista da cozinha do Centro -> true; SA tambem (adicoes) -> true
-- =====================================================================
SELECT p.nome, s.local, s.saldo, s.updated_at
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('426b20f7-d1ac-4123-a87a-135bec6b3270',   -- MP COSTELA DE TAMBAQUI
                        'b58a40c8-d4f0-4a2b-9418-87ae360cdf3d')   -- SA COSTELA DE TAMBAQUI
   AND s.local IN ('ESTOQUE_LOJA', 'COZINHA')
 ORDER BY s.local, p.nome;

SELECT (valor #> '{Centro,COZINHA,CONGELADOS}') ? 'MP COSTELA DE TAMBAQUI' AS mp_na_lista_cozinha,
       jsonb_array_length(valor #> '{Centro,COZINHA,CONGELADOS}') AS itens_no_grupo,
       (SELECT (a.valor -> 'COZINHA|CONGELADOS') ? 'SA COSTELA DE TAMBAQUI'
          FROM inv_configuracoes a WHERE a.chave = 'adicoes') AS sa_na_lista_cozinha
  FROM inv_configuracoes WHERE chave = 'estrutura';


-- =====================================================================
-- PASSO 2 - CORRIGE (tudo ou nada)
-- =====================================================================
BEGIN;

DO $$
DECLARE
  mp  constant uuid := '426b20f7-d1ac-4123-a87a-135bec6b3270';
  sa  constant uuid := 'b58a40c8-d4f0-4a2b-9418-87ae360cdf3d';
  loc text;
  q   numeric;
  n0  int;
  n1  int;
BEGIN
  FOREACH loc IN ARRAY ARRAY['ESTOQUE_LOJA', 'COZINHA'] LOOP
    SELECT saldo INTO q FROM est_saldo_local WHERE produto_id = mp AND local = loc;
    IF q IS NULL OR q = 0 THEN
      RAISE NOTICE '% : MP sem saldo, nada a passar', loc;
      CONTINUE;
    END IF;
    IF q < 0 THEN RAISE EXCEPTION '% : saldo da MP negativo (%). Nada foi alterado.', loc, q; END IF;

    INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
    VALUES (mp, loc, 'ajuste', -q,
            'Costela contada com nome de MP passa para SA COSTELA DE TAMBAQUI (23/10/2026)',
            'ajuste', 'SQL costela MP para SA', (now() AT TIME ZONE 'America/Manaus')::date),
           (sa, loc, 'ajuste', q,
            'Costela contada com nome de MP (MP COSTELA DE TAMBAQUI) entra na SA (23/10/2026)',
            'ajuste', 'SQL costela MP para SA', (now() AT TIME ZONE 'America/Manaus')::date);

    UPDATE est_saldo_local SET saldo = 0, updated_at = now()
     WHERE produto_id = mp AND local = loc;

    INSERT INTO est_saldo_local (produto_id, local, saldo, updated_at)
    VALUES (sa, loc, q, now())
    ON CONFLICT (produto_id, local) DO UPDATE
      SET saldo = est_saldo_local.saldo + EXCLUDED.saldo, updated_at = now();

    RAISE NOTICE '% : % passaram de MP para SA', loc, q;
  END LOOP;

  -- tira so a MP da lista Centro > COZINHA > CONGELADOS, mantendo a ordem
  SELECT jsonb_array_length(valor #> '{Centro,COZINHA,CONGELADOS}') INTO n0
    FROM inv_configuracoes WHERE chave = 'estrutura';

  UPDATE inv_configuracoes
     SET valor = jsonb_set(valor, '{Centro,COZINHA,CONGELADOS}',
           (SELECT coalesce(jsonb_agg(e ORDER BY i), '[]'::jsonb)
              FROM jsonb_array_elements(valor #> '{Centro,COZINHA,CONGELADOS}') WITH ORDINALITY AS t(e, i)
             WHERE e <> to_jsonb('MP COSTELA DE TAMBAQUI'::text)))
   WHERE chave = 'estrutura';

  SELECT jsonb_array_length(valor #> '{Centro,COZINHA,CONGELADOS}') INTO n1
    FROM inv_configuracoes WHERE chave = 'estrutura';
  IF n0 - n1 NOT IN (0, 1) THEN
    RAISE EXCEPTION 'A lista da cozinha perderia % itens (esperado 1). Nada foi alterado.', n0 - n1;
  END IF;
  RAISE NOTICE 'Lista COZINHA/CONGELADOS: % -> % itens', n0, n1;
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura).
-- Esperado: MP 0 na loja e na cozinha; SA loja 135, SA cozinha 31;
-- mp_na_lista_cozinha = false, sa_na_lista_cozinha = true.
-- =====================================================================
SELECT p.nome, s.local, s.saldo
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('426b20f7-d1ac-4123-a87a-135bec6b3270', 'b58a40c8-d4f0-4a2b-9418-87ae360cdf3d')
   AND s.local IN ('ESTOQUE_LOJA', 'COZINHA')
 ORDER BY s.local, p.nome;

SELECT (valor #> '{Centro,COZINHA,CONGELADOS}') ? 'MP COSTELA DE TAMBAQUI' AS mp_na_lista_cozinha,
       (SELECT (a.valor -> 'COZINHA|CONGELADOS') ? 'SA COSTELA DE TAMBAQUI'
          FROM inv_configuracoes a WHERE a.chave = 'adicoes') AS sa_na_lista_cozinha
  FROM inv_configuracoes WHERE chave = 'estrutura';

-- DEPOIS: F5 na tela de Contagem e na Meta de producao antes de gerar a meta.
