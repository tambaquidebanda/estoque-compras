-- =====================================================================
-- SQL_PRATO_DESCARTAVEL_CATEGORIA.sql   (26/10/2026)
--
-- O cadastro PRATO DESCARTAVEL ficou com a categoria antiga
-- 'Descartável/Embalagens'. Os outros descartaveis estao em
-- 'MC DESCARTÁVEIS/EMBALAGENS' desde 22/10. No Planejamento de compras
-- ele aparecia sozinho numa categoria a parte.
--
-- So troca a categoria deste produto. Nao mexe em saldo, pedido,
-- compra nem financeiro. Rode um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA.
-- (a) Esperado: 1 linha, PRATO DESCARTAVEL, Descartável/Embalagens.
-- (b) Esperado: a categoria nova existe (linhas > 0).
-- =====================================================================
SELECT id, nome, tipo, categoria, ativo
  FROM est_produtos
 WHERE id = '3a35ec36-0d5d-40d0-8134-50bc6fa08340';

SELECT categoria, count(*) AS produtos
  FROM est_produtos
 WHERE categoria = 'MC DESCARTÁVEIS/EMBALAGENS'
 GROUP BY categoria;


-- =====================================================================
-- PASSO 2 - CORRIGE (so mexe se ainda estiver na categoria antiga)
-- Esperado: UPDATE 1
-- =====================================================================
UPDATE est_produtos
   SET categoria = 'MC DESCARTÁVEIS/EMBALAGENS'
 WHERE id = '3a35ec36-0d5d-40d0-8134-50bc6fa08340'
   AND categoria = 'Descartável/Embalagens';


-- =====================================================================
-- PASSO 3 - CONFERENCIA (so leitura).
-- (a) Esperado: PRATO DESCARTAVEL com MC DESCARTÁVEIS/EMBALAGENS.
-- (b) Esperado: 0 produtos ativos de MP/MC na categoria antiga.
-- =====================================================================
SELECT nome, categoria
  FROM est_produtos
 WHERE id = '3a35ec36-0d5d-40d0-8134-50bc6fa08340';

SELECT count(*) AS ainda_na_antiga
  FROM est_produtos
 WHERE categoria = 'Descartável/Embalagens' AND ativo AND tipo IN ('MP', 'MC');

-- DEPOIS: F5 (ou Atualizar) no Planejamento.
