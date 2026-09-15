-- ============================================================
-- SQL_FIX_ANO_0026.sql   (15/09/2026)
--
-- O pedido #01316 "sumiu" do Contas a Pagar sem ter sido excluido: o vencimento
-- foi gravado com ano 0026 em vez de 2026 (0026-09-15). O banco aceita a data e
-- ela nunca cai em filtro de periodo nenhum. Conferido: ele NAO esta em
-- lancamentos_excluidos.
--
-- Causa: o campo de vencimento do recebimento no CELULAR aceita qualquer ano.
-- Os dois pedidos abaixo foram recebidos pelo celular em 11/09/2026, 17:04 e 17:08.
--
-- Varredura completa feita (lancamentos, lancamentos_rascunho, cmp_contas_pagar,
-- cmp_recebimentos, cmp_compras): so estes 3 registros tem ano fora de 2020-2030.
--
--   lancamentos       #01316  1638.00  0026-09-15 -> 2026-09-15   (o que sumiu)
--   cmp_contas_pagar  #01316  1638.00  0026-09-15 -> 2026-09-15
--   cmp_contas_pagar  #01287   246.87  0026-09-09 -> 2026-09-09
--
-- O lancamento do #01287 (Comprador Externo) ja esta com data certa (2026-09-08)
-- e NAO e alterado. So o ano muda; dia e mes ficam como foram digitados.
-- ============================================================


-- ============================================================
-- PASSO 1 - SO LEITURA.
-- ============================================================
SELECT 'lancamentos' AS tabela, id, numero_pedido AS pedido, valor, vencimento, status
  FROM lancamentos
 WHERE id = 'f53fec7f-5bee-4ba4-ab9c-046e36e157ba'
UNION ALL
SELECT 'cmp_contas_pagar', id, pedido_num, valor, vencimento, status
  FROM cmp_contas_pagar
 WHERE id IN ('a0893293-ed9c-4712-949d-208884a86415', 'b4fade25-d9e0-47e4-bbbc-c1559895acb3');
-- Esperado: 3 linhas, todas com vencimento no ano 0026.


-- ============================================================
-- PASSO 2 - Backup.
-- ============================================================
DROP TABLE IF EXISTS bkp_ano0026_lanc;
CREATE TABLE bkp_ano0026_lanc AS
  SELECT * FROM lancamentos WHERE id = 'f53fec7f-5bee-4ba4-ab9c-046e36e157ba';
DROP TABLE IF EXISTS bkp_ano0026_conta;
CREATE TABLE bkp_ano0026_conta AS
  SELECT * FROM cmp_contas_pagar
   WHERE id IN ('a0893293-ed9c-4712-949d-208884a86415', 'b4fade25-d9e0-47e4-bbbc-c1559895acb3');
SELECT (SELECT count(*) FROM bkp_ano0026_lanc) AS lanc_1, (SELECT count(*) FROM bkp_ano0026_conta) AS contas_2;


-- ============================================================
-- PASSO 3 - Corrige o ano. Cada UPDATE so age se a data ainda for a errada.
-- ============================================================
UPDATE lancamentos
   SET vencimento = DATE '2026-09-15'
 WHERE id = 'f53fec7f-5bee-4ba4-ab9c-046e36e157ba'
   AND vencimento = DATE '0026-09-15';

UPDATE cmp_contas_pagar
   SET vencimento = DATE '2026-09-15'
 WHERE id = 'a0893293-ed9c-4712-949d-208884a86415'
   AND vencimento = DATE '0026-09-15';

UPDATE cmp_contas_pagar
   SET vencimento = DATE '2026-09-09'
 WHERE id = 'b4fade25-d9e0-47e4-bbbc-c1559895acb3'
   AND vencimento = DATE '0026-09-09';


-- ============================================================
-- PASSO 4 - Conferencia. Nenhum registro pode sobrar fora de 2020-2030.
-- ============================================================
SELECT
  (SELECT count(*) FROM lancamentos          WHERE vencimento < DATE '2020-01-01' OR vencimento > DATE '2030-12-31') AS lanc_fora,
  (SELECT count(*) FROM cmp_contas_pagar     WHERE vencimento < DATE '2020-01-01' OR vencimento > DATE '2030-12-31') AS contas_fora,
  (SELECT count(*) FROM lancamentos_rascunho WHERE vencimento < DATE '2020-01-01' OR vencimento > DATE '2030-12-31') AS rascunhos_fora;
-- Esperado: 0 | 0 | 0

SELECT numero_pedido, valor, vencimento, status
  FROM lancamentos WHERE id = 'f53fec7f-5bee-4ba4-ab9c-046e36e157ba';
-- Esperado: #01316 | 1638.00 | 2026-09-15 | pendente  -> volta a aparecer no Contas a Pagar

-- Para desfazer: bkp_ano0026_lanc e bkp_ano0026_conta.
