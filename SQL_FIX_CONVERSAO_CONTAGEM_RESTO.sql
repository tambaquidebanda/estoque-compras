-- ============================================================================
-- SQL_FIX_CONVERSAO_CONTAGEM_RESTO.sql
--
-- As 4 linhas que o SQL_FIX_CONVERSAO_CONTAGEM.sql nao conseguiu corrigir.
--
-- POR QUE ELAS FICARAM PARA TRAS
-- Erro meu na geracao do arquivo anterior: arredondei o valor ao escrever.
-- O banco guarda o saldo como numero de ponto flutuante, e o que esta la e
-- 0.9750000000000001 - nao 0.975. A trava do PASSO 2 comparava com "=", nao
-- bateu, e pulou a linha. A trava fez o que devia; o numero e que estava curto.
--
-- Aqui os valores vao com a precisao inteira, e a comparacao passa a ser por
-- tolerancia (diferenca menor que um milionesimo) em vez de igualdade exata,
-- que e como se compara ponto flutuante.
--
-- Sao as quatro garrafas do bar, todas com fator < 1:
--   MP APEROL 750 ML         0,975 -> 1,3
--   MP RUM BACARDI           0,15  -> 0,2
--   MP SAGATIBA PURA 700ML   0,28  -> 0,4
--   MP TANQUERAY 750ML       0,525 -> 0,7
--
-- Volta para o numero cru, igual as outras garrafas ja corrigidas (COINTREAL,
-- CACHACA JAMBUCANA, LICOR 43, ESPUMANTE MOSCATEL, MELADO DE CANA): enquanto
-- a unidade de cada item nao for curada uma a uma, o saldo guarda o numero
-- que o time digitou. E o comportamento que eles conhecem.
--
-- As outras 44 linhas ja foram corrigidas e nao sao tocadas aqui.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA.
-- ============================================================================
WITH conserto (produto_id, local, saldo_errado, saldo_certo, insumo) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'BAR', 0.9750000000000001, 1.3, 'MP APEROL 750 ML'),
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'BAR', 0.15000000000000002, 0.2, 'MP RUM BACARDI'),
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'BAR', 0.27999999999999997, 0.4, 'MP SAGATIBA PURA 700ML'),
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'BAR', 0.5249999999999999, 0.7, 'MP TANQUERAY 750ML')
)
SELECT c.insumo, c.local, s.saldo AS saldo_hoje, c.saldo_certo AS vai_virar,
       CASE
         WHEN s.produto_id IS NULL                          THEN 'linha nao existe'
         WHEN abs(s.saldo - c.saldo_errado) < 0.000001      THEN 'vai corrigir'
         WHEN abs(s.saldo - c.saldo_certo)  < 0.000001      THEN 'ja esta certo'
         ELSE                                                    'MUDOU depois - sera pulada'
       END AS situacao
FROM conserto c
LEFT JOIN est_saldo_local s ON s.produto_id = c.produto_id AND s.local = c.local
ORDER BY c.insumo;


-- ============================================================================
-- PASSO 2 - ESCREVE. Corrige o saldo e lanca o acerto no razao, junto.
-- ============================================================================
WITH conserto (produto_id, local, saldo_errado, saldo_certo, insumo) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'BAR', 0.9750000000000001, 1.3, 'MP APEROL 750 ML'),
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'BAR', 0.15000000000000002, 0.2, 'MP RUM BACARDI'),
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'BAR', 0.27999999999999997, 0.4, 'MP SAGATIBA PURA 700ML'),
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'BAR', 0.5249999999999999, 0.7, 'MP TANQUERAY 750ML')
),
upd AS (
  UPDATE est_saldo_local s
     SET saldo      = c.saldo_certo,
         updated_at = now()
    FROM conserto c
   WHERE s.produto_id = c.produto_id
     AND s.local      = c.local
     AND abs(s.saldo - c.saldo_errado) < 0.000001
  RETURNING s.produto_id, s.local, (c.saldo_certo - c.saldo_errado) AS delta
)
INSERT INTO est_movimentacoes
       (produto_id, local, tipo, quantidade, origem, motivo, responsavel, data)
SELECT produto_id, local, 'ajuste', delta, 'correcao',
       'Correcao: conversao de unidade indevida na contagem (commit 6084219)',
       'sistema', CURRENT_DATE
FROM upd
WHERE delta <> 0;


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Deve voltar zero linha.
-- ============================================================================
WITH conserto (produto_id, local, saldo_errado, saldo_certo, insumo) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'BAR', 0.9750000000000001, 1.3, 'MP APEROL 750 ML'),
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'BAR', 0.15000000000000002, 0.2, 'MP RUM BACARDI'),
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'BAR', 0.27999999999999997, 0.4, 'MP SAGATIBA PURA 700ML'),
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'BAR', 0.5249999999999999, 0.7, 'MP TANQUERAY 750ML')
)
SELECT c.insumo, c.local, s.saldo AS ainda_errado, c.saldo_certo
FROM conserto c
JOIN est_saldo_local s ON s.produto_id = c.produto_id AND s.local = c.local
WHERE abs(s.saldo - c.saldo_certo) > 0.000001
ORDER BY c.insumo;
