-- ============================================================================
-- SQL_MARGARINA_MEDALHOES.sql
--
-- Troca a MP MARGARINA DELINE 3KG pela MP MARGARINA nas 4 fichas de medalhao, e
-- inativa a Deline, que a casa nao compra mais.
--
-- O QUE ESTAVA ERRADO
-- As 4 fichas usavam "0,03 pote". O pote e de 3 kg, entao 0,03 pote = 90 g de
-- margarina por medalhao - o dobro da mediana das outras 12 fichas que usam
-- margarina (0,036 kg) e quase o mesmo que o PPC MOLHO PEIXE ASSADO inteiro.
--
-- O prato mais parecido, PORC LEGUMES SALTEADOS 250g, usa 0,03 KG = 30 g.
-- O numero 0,03 estava certo; a unidade e o produto e que nao.
-- Confirmado pelo Wagner em 01/09/2026: sao 0,03 kg mesmo.
--
-- EFEITO
--   custo por medalhao: R$ 1,50 -> R$ 0,32   (MP MARGARINA sai a R$ 10,79/kg:
--   R$ 161,90 a unidade de 15 kg)
--   o modelo para de consumir um produto que nao existe mais no estoque
--   (R$ 8,29/dia hoje)
--
-- Duas das quatro vendem: MEDALHAO DE FILE COM FRITAS (118/30d) e COM PURE
-- (40/30d). As de alcatra quase nao saem (1 e 0), mas vao junto por coerencia.
--
-- A unidade gravada passa de 'pote' para 'Kg', que e a forma mais usada na
-- tabela (888 linhas) e a que as outras fichas de margarina ja usam.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O antes.
-- ============================================================================
SELECT pf.nome AS ficha, i.quantidade, i.unidade, pi.nome AS ingrediente
FROM est_ficha_ingredientes i
JOIN est_fichas_tecnicas f ON f.id = i.ficha_id
JOIN est_produtos pf ON pf.id = f.produto_id
JOIN est_produtos pi ON pi.id = i.ingrediente_id
WHERE i.id IN ('247b6634-d8ef-4d72-9a94-200f019c00f5',   -- MEDALHAO DE ALCATRA COM FRITAS
               '282e9cac-c0ac-4fb8-b4c3-e71012c33cb5',   -- MEDALHAO DE ALCATRA COM PURE
               '09a63e95-338e-4d60-8a67-160860b1e076',   -- MEDALHAO DE FILE COM FRITAS
               '5939d7b3-2685-4e5e-a8ca-affef64fccd0')   -- MEDALHAO DE FILE COM PURE
ORDER BY pf.nome;
-- Esperado: as 4 com quantidade 0,03, unidade 'pote', ingrediente
-- MP MARGARINA DELINE 3KG.


-- ============================================================================
-- PASSO 2 - ESCREVE. Troca o ingrediente e a unidade. A quantidade nao muda.
-- ============================================================================
UPDATE est_ficha_ingredientes
   SET ingrediente_id = '16cd12c6-a9ea-428c-b1f5-78a021559445',   -- MP MARGARINA
       unidade = 'Kg'
 WHERE id IN ('247b6634-d8ef-4d72-9a94-200f019c00f5',
              '282e9cac-c0ac-4fb8-b4c3-e71012c33cb5',
              '09a63e95-338e-4d60-8a67-160860b1e076',
              '5939d7b3-2685-4e5e-a8ca-affef64fccd0')
   AND ingrediente_id = '20407e5c-4982-435f-a0c8-510d454fddf1';  -- so se ainda for a Deline
-- Deve dizer UPDATE 4.


-- ============================================================================
-- PASSO 3 - ESCREVE. Inativa a Deline.
--
-- Conferido antes: ela nao tem saldo em lugar nenhum, nao esta no pdv_map e nao
-- tem ficha propria. Depois do PASSO 2, nenhuma ficha a usa. Inativar nao apaga
-- nada - o historico continua e voltar e trocar false por true.
-- ============================================================================
UPDATE est_produtos
   SET ativo = false
 WHERE id = '20407e5c-4982-435f-a0c8-510d454fddf1'
   AND ativo = true
   AND NOT EXISTS (                       -- trava: se sobrou ficha usando, nao inativa
     SELECT 1 FROM est_ficha_ingredientes i
      JOIN est_fichas_tecnicas f ON f.id = i.ficha_id AND f.ativo
     WHERE i.ingrediente_id = '20407e5c-4982-435f-a0c8-510d454fddf1');
-- Deve dizer UPDATE 1. Se disser UPDATE 0, alguma ficha ativa ainda usa a
-- Deline - rode o PASSO 4 para ver qual.


-- ============================================================================
-- PASSO 4 - CONFERENCIA.
-- ============================================================================
SELECT pf.nome AS ficha, i.quantidade, i.unidade, pi.nome AS ingrediente,
       round((pi.custo_comp / NULLIF(pi.fator_conversao, 0))::numeric, 2) AS custo_kg,
       round((i.quantidade * pi.custo_comp / NULLIF(pi.fator_conversao, 0))::numeric, 2) AS custo_porcao
FROM est_ficha_ingredientes i
JOIN est_fichas_tecnicas f ON f.id = i.ficha_id
JOIN est_produtos pf ON pf.id = f.produto_id
JOIN est_produtos pi ON pi.id = i.ingrediente_id
WHERE pf.nome ILIKE 'MEDALHAO%'
  AND pi.nome ILIKE '%MARGARINA%'
ORDER BY pf.nome;
-- Esperado: 4 linhas, ingrediente MP MARGARINA, unidade Kg, custo_kg 10,79 e
-- custo_porcao 0,32.

SELECT nome, ativo FROM est_produtos WHERE nome ILIKE '%MARGARINA%' ORDER BY nome;
-- Esperado: MP MARGARINA ativo, MP MARGARINA DELINE 3KG inativa.
