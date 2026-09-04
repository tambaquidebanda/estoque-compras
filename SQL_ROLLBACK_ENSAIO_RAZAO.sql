-- ==========================================================================
-- DESFAZ UM ENSAIO DO MODO 'razao' (um dia)
-- ==========================================================================
-- Use ESTE, e nao o SQL_ROLLBACK_BAIXA_PDV.sql, quando a rodada foi em modo
-- 'razao'.
--
-- POR QUE SAO DIFERENTES
--   O modo 'apply' faz duas coisas: lanca no livro-razao E desconta o saldo.
--   O rollback dele tem um passo que DEVOLVE o saldo.
--   O modo 'razao' lanca no razao e NAO encosta no saldo.
--   Se voce rodar o rollback do apply em cima de um ensaio de razao, aquele
--   passo vai SOMAR ao saldo uma quantidade que nunca saiu - criando estoque
--   do nada, em todos os insumos do dia.
--
-- Aqui so apagamos o razao e liberamos o dia. Nada toca est_saldo_local.
--
-- TROQUE A DATA nos quatro passos. Ela aparece como '2026-09-03'.
-- ==========================================================================


-- --------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA: o que o ensaio lancou
-- --------------------------------------------------------------------------
SELECT m.local,
       count(*)                              AS insumos,
       round(sum(m.quantidade)::numeric, 3)  AS qtd_total,
       round(sum(m.valor_total)::numeric, 2) AS valor_total
  FROM est_movimentacoes m
 WHERE m.tipo   = 'venda_pensera'
   AND m.origem = 'pdv_icomanda'
   AND m.data   = '2026-09-03'
 GROUP BY m.local
 ORDER BY m.local;
-- ESPERADO: as linhas do ensaio que voce quer desfazer (uma por setor).
-- Confira se o total de insumos e o valor batem com o que a rodada gravou.
-- SE VIER ZERO LINHA: nao ha nada a desfazer (o ensaio nao rodou, ou ja foi
-- desfeito). Ai sim pare por aqui.


-- --------------------------------------------------------------------------
-- PASSO 2 - SO LEITURA: confirma que o saldo NAO foi tocado
-- --------------------------------------------------------------------------
-- Se o dia foi rodado em 'razao', o controle tem que dizer razao. Se disser
-- apply, PARE: o saldo foi descontado e o rollback certo e o outro arquivo.
SELECT data, modo, status, itens_venda, insumos, valor
  FROM pdv_baixa_ctrl
 WHERE data = '2026-09-03';
-- Esperado: uma linha com modo = 'razao'.


-- --------------------------------------------------------------------------
-- PASSO 3 - apaga os lancamentos do razao
-- --------------------------------------------------------------------------
DELETE FROM est_movimentacoes
 WHERE tipo   = 'venda_pensera'
   AND origem = 'pdv_icomanda'
   AND data   = '2026-09-03';
-- Esperado: DELETE com o mesmo numero de insumos somado no PASSO 1.


-- --------------------------------------------------------------------------
-- PASSO 4 - libera o dia para ser rodado de novo
-- --------------------------------------------------------------------------
DELETE FROM pdv_baixa_ctrl
 WHERE data = '2026-09-03'
   AND modo = 'razao';
-- Esperado: DELETE 1


-- --------------------------------------------------------------------------
-- PASSO 5 - CONFERE
-- --------------------------------------------------------------------------
SELECT 'lancamentos restantes' AS o_que,
       (SELECT count(*) FROM est_movimentacoes
         WHERE tipo='venda_pensera' AND origem='pdv_icomanda' AND data='2026-09-03')::text AS valor
UNION ALL
SELECT 'controle do dia',
       (SELECT count(*) FROM pdv_baixa_ctrl WHERE data='2026-09-03' AND modo='razao')::text;
-- Esperado: os dois em 0.
-- O pdv_preparo_dia do dia PODE ficar: ele nao e baixa nem razao, e o proprio
-- robo apaga e regrava esse dia na proxima vez que rodar.
