-- =====================================================================
-- SQL_MAPEAR_COMBOS_REFRI.sql   (07/10/2026)
--
-- Os 3 combos "+ REFRI LATA" do iComanda nao estavam na pdv_map, entao a venda
-- deles nao gerava consumo de nada: nem na baixa do Centro, nem na venda de SA
-- da Meta de Producao (no P10 isso tirava ~80 Iscas e ~80 Batatas da meta em
-- 10 dias). Aprovado pelo Wagner em 07/10/2026: mapear cada combo para o PRATO
-- sem o refri, fator 1. O refri continua de fora (precisaria ficha propria).
--
--   3126 STROGONOFF DE FRANGO + REFRI LATA   -> ESTROGONOFF DE FRANGO
--   3125 PIRARUCU DESFIADO + REFRI LATA      -> PIRARUCU DESFIADO
--   3127 PICADINHO DE TAMBAQUI + REFRI LATA  -> TAMBAQUI PICADINHO
--
-- Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA.
-- (a) os combos NAO devem estar na pdv_map (zero linhas)
-- (b) os 3 pratos devem existir, ativos e com ficha ativa (3 linhas, tem_ficha = true)
-- =====================================================================
SELECT icomanda_produto_id, icomanda_nome, status, produto_id
  FROM pdv_map WHERE icomanda_produto_id IN (3125, 3126, 3127);

SELECT p.id, p.nome, p.ativo,
       EXISTS (SELECT 1 FROM est_fichas_tecnicas f WHERE f.produto_id = p.id AND f.ativo) AS tem_ficha
  FROM est_produtos p
 WHERE p.id IN ('5917edfc-0e35-4199-87e1-674c4f9a9d5c',
                'd71d4c58-a322-463b-80ad-fb64080fd6e2',
                '99794402-2a96-43a2-8d49-bd6424eff9a7');


-- =====================================================================
-- PASSO 2 - MAPEIA (tudo ou nada; nao mexe em combo que ja estiver na tabela)
-- =====================================================================
BEGIN;

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM pdv_map WHERE icomanda_produto_id IN (3125, 3126, 3127);
  IF n > 0 THEN RAISE EXCEPTION 'Ja existem % combos na pdv_map. Nada foi alterado.', n; END IF;

  INSERT INTO pdv_map (icomanda_produto_id, icomanda_nome, produto_id, status, fator, obs)
  VALUES
    (3126, 'STROGONOFF DE FRANGO + REFRI LATA',  '5917edfc-0e35-4199-87e1-674c4f9a9d5c', 'mapeado', 1,
     'Combo: mapeado para o prato sem o refri (07/10/2026)'),
    (3125, 'PIRARUCU DESFIADO + REFRI LATA',     'd71d4c58-a322-463b-80ad-fb64080fd6e2', 'mapeado', 1,
     'Combo: mapeado para o prato sem o refri (07/10/2026)'),
    (3127, 'PICADINHO DE TAMBAQUI + REFRI LATA', '99794402-2a96-43a2-8d49-bd6424eff9a7', 'mapeado', 1,
     'Combo: mapeado para o prato sem o refri (07/10/2026)');
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 3 THEN RAISE EXCEPTION 'Inseriu % linhas (esperado 3).', n; END IF;
END $$;

COMMIT;


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura). Esperado: 3 linhas, status mapeado.
-- =====================================================================
SELECT m.icomanda_produto_id, m.icomanda_nome, m.status, m.fator, p.nome AS prato
  FROM pdv_map m JOIN est_produtos p ON p.id = m.produto_id
 WHERE m.icomanda_produto_id IN (3125, 3126, 3127)
 ORDER BY 1;

-- DEPOIS: no GitHub, Actions > "Venda de SA por dia (meta da Producao)" >
-- Run workflow com dias = 40, para regravar a venda de SA com os combos.
