-- =====================================================================
-- SQL_GOIABA_PAPEL_ARROZ.sql   (27/10/2026)
--
-- Dois negativos no ESTOQUE_LOJA que vieram do pedido interno do Bar
-- liberado em 26/10 (PED-3725 e PED-3726, "Ricardo · login Anderson").
--
-- POLPA DE GOIABA: o Bar pediu 4 na linha "MP POLPA GOIABA 1 KG" e foram
--   liberados 40 nessa linha. Os 40 eram os pacotinhos MP POLPA GOIABA
--   da compra #01966 (5 PC x 8 = 40 UN, chegou 26/10, recebida no sistema
--   so em 27/10 16:49). Resultado hoje:
--     MP POLPA GOIABA 1KG  BAR +40 (nao existe)   ESTOQUE_LOJA -40
--     MP POLPA GOIABA      BAR  46 (faltam os 40) ESTOQUE_LOJA +40 (ja foram pro Bar)
--   O SQL passa os 40 da linha errada para a certa: as duas linhas da
--   loja ficam 0 e o Bar fica com 0 de 1KG e 86 de pacotinho (a contagem
--   de polpas do Bar acerta o resto).
--
-- PAPEL DE ARROZ: nunca teve compra no sistema. A loja liberou 19 para o
--   Bar sem ter (ficou -19) e a contagem do Bar da noite ja tirou os 19
--   (o Bar contou 16). So falta zerar o -19 da loja.
--
-- Grava tudo no historico (est_movimentacoes). Nao mexe em pedido de
-- compra nem financeiro. Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA. Esperado (se ninguem mexeu desde 27/10 a tarde):
--   MP PAPEL DE ARROZ     BAR 16      ESTOQUE_LOJA -19
--   MP POLPA GOIABA       BAR 46      ESTOQUE_LOJA 40
--   MP POLPA GOIABA 1KG   BAR 40      ESTOQUE_LOJA -40
-- Se estiver diferente, PARE e me mande o resultado.
-- =====================================================================
SELECT p.nome, s.local, s.saldo, s.updated_at
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('0d50d73a-eb36-4335-aab0-c42f36a996d8',
                        '2b08a052-0668-4919-88eb-1a6b88a7f211',
                        '8c5deab4-b747-41ae-8ed8-42b66b21cb0a')
   AND s.local IN ('BAR', 'ESTOQUE_LOJA')
 ORDER BY p.nome, s.local;


-- =====================================================================
-- PASSO 2 - CORRIGE (tudo ou nada; para sozinho se o saldo mudou)
-- =====================================================================
BEGIN;

DO $$
DECLARE
  pac   constant uuid := '0d50d73a-eb36-4335-aab0-c42f36a996d8';   -- MP POLPA GOIABA (pacotinho)
  kg    constant uuid := '2b08a052-0668-4919-88eb-1a6b88a7f211';   -- MP POLPA GOIABA 1KG
  pap   constant uuid := '8c5deab4-b747-41ae-8ed8-42b66b21cb0a';   -- MP PAPEL DE ARROZ
  hoje  constant date := (now() AT TIME ZONE 'America/Manaus')::date;
  quem  constant text := 'SQL goiaba/papel de arroz';
  s_kg_bar numeric; s_kg_loja numeric; s_pac_loja numeric; s_pap_loja numeric;
BEGIN
  SELECT saldo INTO s_kg_bar   FROM est_saldo_local WHERE produto_id = kg  AND local = 'BAR';
  SELECT saldo INTO s_kg_loja  FROM est_saldo_local WHERE produto_id = kg  AND local = 'ESTOQUE_LOJA';
  SELECT saldo INTO s_pac_loja FROM est_saldo_local WHERE produto_id = pac AND local = 'ESTOQUE_LOJA';
  SELECT saldo INTO s_pap_loja FROM est_saldo_local WHERE produto_id = pap AND local = 'ESTOQUE_LOJA';
  IF s_kg_bar IS DISTINCT FROM 40 OR s_kg_loja IS DISTINCT FROM -40 OR s_pac_loja IS DISTINCT FROM 40 THEN
    RAISE EXCEPTION 'Saldo da goiaba mudou desde a analise (1KG bar %, 1KG loja %, pacotinho loja %). Nada foi alterado.',
      s_kg_bar, s_kg_loja, s_pac_loja;
  END IF;
  IF s_pap_loja IS DISTINCT FROM -19 THEN
    RAISE EXCEPTION 'Saldo do papel de arroz na loja mudou (%). Nada foi alterado.', s_pap_loja;
  END IF;

  INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data) VALUES
    (kg,  'BAR',          'ajuste', -40, 'PED-3725: 40 liberados na linha 1KG eram os pacotinhos (passa para MP POLPA GOIABA)', 'ajuste', quem, hoje),
    (kg,  'ESTOQUE_LOJA', 'ajuste',  40, 'PED-3725: desfaz a saida de 40 na linha 1KG (eram os pacotinhos)', 'ajuste', quem, hoje),
    (pac, 'ESTOQUE_LOJA', 'ajuste', -40, 'PED-3725: os 40 pacotinhos da compra #01966 foram para o Bar em 26/10', 'ajuste', quem, hoje),
    (pac, 'BAR',          'ajuste',  40, 'PED-3725: 40 pacotinhos entregues ao Bar em 26/10 (lancados na linha 1KG)', 'ajuste', quem, hoje),
    (pap, 'ESTOQUE_LOJA', 'ajuste',  19, 'PED-3726: loja liberou 19 sem ter (sem compra no sistema); Bar ja acertou na contagem', 'ajuste', quem, hoje);

  UPDATE est_saldo_local SET saldo = saldo - 40, updated_at = now() WHERE produto_id = kg  AND local = 'BAR';
  UPDATE est_saldo_local SET saldo = saldo + 40, updated_at = now() WHERE produto_id = kg  AND local = 'ESTOQUE_LOJA';
  UPDATE est_saldo_local SET saldo = saldo - 40, updated_at = now() WHERE produto_id = pac AND local = 'ESTOQUE_LOJA';
  INSERT INTO est_saldo_local (produto_id, local, saldo, updated_at) VALUES (pac, 'BAR', 40, now())
    ON CONFLICT (produto_id, local) DO UPDATE SET saldo = est_saldo_local.saldo + EXCLUDED.saldo, updated_at = now();
  UPDATE est_saldo_local SET saldo = saldo + 19, updated_at = now() WHERE produto_id = pap AND local = 'ESTOQUE_LOJA';
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura). Esperado:
--   MP PAPEL DE ARROZ     BAR 16      ESTOQUE_LOJA 0
--   MP POLPA GOIABA       BAR 86      ESTOQUE_LOJA 0
--   MP POLPA GOIABA 1KG   BAR 0       ESTOQUE_LOJA 0
-- =====================================================================
SELECT p.nome, s.local, s.saldo
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('0d50d73a-eb36-4335-aab0-c42f36a996d8',
                        '2b08a052-0668-4919-88eb-1a6b88a7f211',
                        '8c5deab4-b747-41ae-8ed8-42b66b21cb0a')
   AND s.local IN ('BAR', 'ESTOQUE_LOJA')
 ORDER BY p.nome, s.local;
