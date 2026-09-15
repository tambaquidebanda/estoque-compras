-- ============================================================
-- SQL_FICHA_COCA_CORONA.sql   (15/09/2026)
--
-- Duas fichas de VENDA baixam no insumo errado desde a importacao de 03/06/2026:
--   COCA COLA 350ML LT  baixa em MP COCA COLA ZERO LATA   (deveria: MP COCA COLA LATA)
--   CORONA LN           baixa em MP CORONA ZERO LN        (deveria: MP CORONA LN)
-- Efeito: a Zero leva a baixa das duas; a normal nunca sai do estoque pela venda.
-- Achado no levantamento de itens contados sem venda (14/09) e conferido de novo
-- em 15/09: continuam erradas. Aparecem no pedido sombra (Coca Zero: sombra 62
-- contra real 5 na noite de 13/09).
--
-- Troca SO o ingrediente de uma linha em cada ficha. Quantidade (1 UN), perda e
-- fator ficam iguais. Os custos dos dois pares sao praticamente iguais, entao o
-- custo das fichas quase nao muda.
--
-- Vale daqui para frente. O que o robo ja lancou no razao desde 08/09 continua
-- como foi (e medicao do paralelo, nao saldo).
-- ============================================================


-- ============================================================
-- PASSO 1 - SO LEITURA. Esperado: 2 linhas, cada uma apontando para o ZERO.
-- ============================================================
SELECT fi.id AS linha_id, pv.nome AS produto_venda, pi.nome AS baixa_hoje_em, fi.quantidade
  FROM est_ficha_ingredientes fi
  JOIN est_fichas_tecnicas ft ON ft.id = fi.ficha_id
  JOIN est_produtos pv ON pv.id = ft.produto_id
  JOIN est_produtos pi ON pi.id = fi.ingrediente_id
 WHERE fi.id IN ('20d6f277-2c9d-4a5f-8b8d-1707750b9676', '2423c6a2-f7cc-4a3d-8b95-54e3884d834c');


-- ============================================================
-- PASSO 2 - Backup.
-- ============================================================
DROP TABLE IF EXISTS bkp_ficha_coca_corona;
CREATE TABLE bkp_ficha_coca_corona AS
  SELECT * FROM est_ficha_ingredientes
   WHERE id IN ('20d6f277-2c9d-4a5f-8b8d-1707750b9676', '2423c6a2-f7cc-4a3d-8b95-54e3884d834c');
SELECT count(*) AS linhas_no_backup FROM bkp_ficha_coca_corona;   -- esperado: 2


-- ============================================================
-- PASSO 3 - Aponta cada ficha para o insumo certo.
-- Cada UPDATE so age se a linha ainda estiver no insumo errado.
-- ============================================================
UPDATE est_ficha_ingredientes
   SET ingrediente_id = 'bfc882fc-d327-4190-834b-751fbc619449'          -- MP COCA COLA LATA
 WHERE id = '20d6f277-2c9d-4a5f-8b8d-1707750b9676'                      -- ficha COCA COLA 350ML LT
   AND ingrediente_id = '10abad43-0d76-42a9-9dc1-831a1e1555ce';         -- ainda em MP COCA COLA ZERO LATA

UPDATE est_ficha_ingredientes
   SET ingrediente_id = '31a104c9-d0c2-48bd-9d16-d3973cee02bf'          -- MP CORONA LN
 WHERE id = '2423c6a2-f7cc-4a3d-8b95-54e3884d834c'                      -- ficha CORONA LN
   AND ingrediente_id = 'e8dfe8cb-c89b-4dbc-a686-098f979ed0e9';         -- ainda em MP CORONA ZERO LN


-- ============================================================
-- PASSO 4 - Conferencia. As 4 fichas do grupo, cada uma no seu insumo.
-- ============================================================
SELECT pv.nome AS produto_venda, pi.nome AS baixa_em, fi.quantidade
  FROM est_ficha_ingredientes fi
  JOIN est_fichas_tecnicas ft ON ft.id = fi.ficha_id AND ft.ativo
  JOIN est_produtos pv ON pv.id = ft.produto_id
  JOIN est_produtos pi ON pi.id = fi.ingrediente_id
 WHERE pv.nome IN ('COCA COLA 350ML LT', 'COCA COLA ZERO 350ML LT', 'CORONA LN', 'CORONA ZERO ALCOOL LN')
 ORDER BY pv.nome;
-- Esperado:
--   COCA COLA 350ML LT       -> MP COCA COLA LATA
--   COCA COLA ZERO 350ML LT  -> MP COCA COLA ZERO LATA
--   CORONA LN                -> MP CORONA LN
--   CORONA ZERO ALCOOL LN    -> MP CORONA ZERO LN

-- Para desfazer: bkp_ficha_coca_corona.
