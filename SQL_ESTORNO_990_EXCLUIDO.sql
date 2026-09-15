-- ============================================================
-- SQL_ESTORNO_990_EXCLUIDO.sql   (15/09/2026)
--
-- A nota 030/26 (ALBERTA, R$ 763,50) entrou TRES vezes no ESTOQUE_LOJA:
--   16:55  recebimento parcial do #00990 (celular)   cheesecake 12, brownie 16, petit 26
--   17:01  recebimento do #01392 (celular)           5 itens  <-- ESTE E O VALIDO
--   17:10  recebimento do #00990 (desktop)           5 itens
-- Depois o #00990 foi rejeitado no financeiro e excluido em Compras. Excluir o
-- pedido NAO tira do estoque o que os recebimentos creditaram, e o Rejeitar do
-- financeiro nao estorna saldo. Sobraram tambem 2 cabecalhos de recebimento
-- do #00990 sem nenhum item.
--
-- Este SQL:
--   - tira do ESTOQUE_LOJA so o que os dois recebimentos do #00990 creditaram
--     (o #01392 e o #01387 de hoje ficam intactos);
--   - grava cada estorno no razao (est_movimentacoes), com motivo;
--   - apaga os 2 cabecalhos orfaos do #00990.
-- Financeiro: NAO mexe. Ja esta certo (1 lancamento de 763,50 do #01392).
--
-- Seguro para rodar duas vezes: o PASSO 3 so age se o estorno ainda nao
-- estiver no razao.
-- ============================================================


-- ============================================================
-- PASSO 1 - SO LEITURA. Saldo de agora e saldo depois do estorno.
-- Conferido em 15/09 apos 17:13: 64 / 16 / 36 / 131 / 95.
-- Se algum numero de "saldo_hoje" estiver diferente, houve movimento novo
-- (venda, pedido interno, contagem) - o estorno continua certo, porque tira
-- a sobra e nao grava saldo fixo.
-- ============================================================
SELECT p.nome, s.saldo AS saldo_hoje, v.sobra, s.saldo - v.sobra AS saldo_depois
  FROM (VALUES
    ('f24ea38c-94d3-4ffb-b652-7a7e9d55d83e'::uuid,  8::numeric),  -- Ceu de Brigadeiro  16 -> 8
    ('590a30af-8cd6-4d49-9e87-f47a2982a956'::uuid, 24::numeric),  -- Cheesecake         36 -> 12
    ('195d8f65-7b5e-47d6-bdf9-3d70d0ad611b'::uuid, 32::numeric),  -- Brownie            64 -> 32
    ('6e3eafa1-8abe-45bc-a3db-07900b47ac56'::uuid, 52::numeric),  -- Petit Gateau      131 -> 79
    ('aaea9345-7669-4fb4-bac1-7e1a5fde0af2'::uuid, 41::numeric)   -- Pudim de Leite     95 -> 54
  ) AS v(produto_id, sobra)
  JOIN est_saldo_local s ON s.produto_id = v.produto_id AND s.local = 'ESTOQUE_LOJA'
  JOIN est_produtos    p ON p.id = v.produto_id
 ORDER BY p.nome;

SELECT id, criado_em, total_recebido,
       (SELECT count(*) FROM cmp_recebimento_itens i WHERE i.recebimento_id = r.id) AS itens
  FROM cmp_recebimentos r
 WHERE pedido_num = '#00990';
-- Esperado: 2 linhas (434.00 e 763.50), ambas com itens = 0.


-- ============================================================
-- PASSO 2 - Backup.
-- ============================================================
DROP TABLE IF EXISTS bkp_estorno_990_saldo;
CREATE TABLE bkp_estorno_990_saldo AS
  SELECT * FROM est_saldo_local
   WHERE local = 'ESTOQUE_LOJA'
     AND produto_id IN ('f24ea38c-94d3-4ffb-b652-7a7e9d55d83e','590a30af-8cd6-4d49-9e87-f47a2982a956',
                        '195d8f65-7b5e-47d6-bdf9-3d70d0ad611b','6e3eafa1-8abe-45bc-a3db-07900b47ac56',
                        'aaea9345-7669-4fb4-bac1-7e1a5fde0af2');
DROP TABLE IF EXISTS bkp_estorno_990_receb;
CREATE TABLE bkp_estorno_990_receb AS SELECT * FROM cmp_recebimentos WHERE pedido_num = '#00990';
SELECT (SELECT count(*) FROM bkp_estorno_990_saldo) AS saldos_5,
       (SELECT count(*) FROM bkp_estorno_990_receb) AS cabecalhos_2;


-- ============================================================
-- PASSO 3 - Estorno no saldo + razao, numa transacao so.
-- A trava NOT EXISTS impede estornar duas vezes.
-- ============================================================
BEGIN;

UPDATE est_saldo_local s
   SET saldo = s.saldo - v.sobra,
       updated_at = now()
  FROM (VALUES
    ('f24ea38c-94d3-4ffb-b652-7a7e9d55d83e'::uuid,  8::numeric),
    ('590a30af-8cd6-4d49-9e87-f47a2982a956'::uuid, 24::numeric),
    ('195d8f65-7b5e-47d6-bdf9-3d70d0ad611b'::uuid, 32::numeric),
    ('6e3eafa1-8abe-45bc-a3db-07900b47ac56'::uuid, 52::numeric),
    ('aaea9345-7669-4fb4-bac1-7e1a5fde0af2'::uuid, 41::numeric)
  ) AS v(produto_id, sobra)
 WHERE s.produto_id = v.produto_id
   AND s.local = 'ESTOQUE_LOJA'
   AND NOT EXISTS (SELECT 1 FROM est_movimentacoes m
                    WHERE m.origem = 'estorno_recebimento'
                      AND m.motivo LIKE 'Estorno dos recebimentos do #00990 excluido%');

INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, custo_unit, motivo, origem, data)
SELECT v.produto_id, 'ESTOQUE_LOJA', 'recebimento', -v.sobra, v.custo,
       'Estorno dos recebimentos do #00990 excluido - nota 030/26 ja entrou pelo #01392',
       'estorno_recebimento', DATE '2026-09-15'
  FROM (VALUES
    ('f24ea38c-94d3-4ffb-b652-7a7e9d55d83e'::uuid,  8::numeric, 13.0::numeric),
    ('590a30af-8cd6-4d49-9e87-f47a2982a956'::uuid, 24::numeric, 13.0::numeric),
    ('195d8f65-7b5e-47d6-bdf9-3d70d0ad611b'::uuid, 32::numeric,  6.0::numeric),
    ('6e3eafa1-8abe-45bc-a3db-07900b47ac56'::uuid, 52::numeric,  7.0::numeric),
    ('aaea9345-7669-4fb4-bac1-7e1a5fde0af2'::uuid, 41::numeric,  5.5::numeric)
  ) AS v(produto_id, sobra, custo)
 WHERE NOT EXISTS (SELECT 1 FROM est_movimentacoes m
                    WHERE m.origem = 'estorno_recebimento'
                      AND m.motivo LIKE 'Estorno dos recebimentos do #00990 excluido%');

COMMIT;


-- ============================================================
-- PASSO 4 - Apaga os 2 cabecalhos orfaos do #00990.
-- So apaga se continuarem sem item, sem conta e sem devolucao apontando.
-- ============================================================
DELETE FROM cmp_recebimentos r
 WHERE r.pedido_num = '#00990'
   AND NOT EXISTS (SELECT 1 FROM cmp_recebimento_itens i WHERE i.recebimento_id = r.id)
   AND NOT EXISTS (SELECT 1 FROM cmp_contas_pagar     c WHERE c.recebimento_id = r.id)
   AND NOT EXISTS (SELECT 1 FROM cmp_devolucoes       d WHERE d.recebimento_id = r.id);


-- ============================================================
-- PASSO 5 - Conferencia.
-- ============================================================
SELECT p.nome, s.saldo AS saldo_agora
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.local = 'ESTOQUE_LOJA'
   AND s.produto_id IN ('f24ea38c-94d3-4ffb-b652-7a7e9d55d83e','590a30af-8cd6-4d49-9e87-f47a2982a956',
                        '195d8f65-7b5e-47d6-bdf9-3d70d0ad611b','6e3eafa1-8abe-45bc-a3db-07900b47ac56',
                        'aaea9345-7669-4fb4-bac1-7e1a5fde0af2')
 ORDER BY p.nome;
-- Esperado (se nada mexeu desde 17:13):
--   MP BROWNIE DE CHOCOLATE 32 | MP CEU DE BRIGADEIRO 8 | MP CHEESECAKE ... 12
--   MP PETIT GATEAU C CALDA 79 | MP PUDIM DE LEITE 54

SELECT count(*) AS linhas_estorno_no_razao      -- esperado: 5
  FROM est_movimentacoes
 WHERE origem = 'estorno_recebimento'
   AND motivo LIKE 'Estorno dos recebimentos do #00990 excluido%';

SELECT count(*) AS cabecalhos_990_restantes     -- esperado: 0
  FROM cmp_recebimentos WHERE pedido_num = '#00990';

-- Para desfazer: bkp_estorno_990_saldo e bkp_estorno_990_receb.
