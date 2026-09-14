-- ============================================================
-- SQL_PARCELAS_1354.sql
-- Pedido #01354 (VARIEDADES SALMO 91) - boleto em 3x.
-- O rascunho atual foi criado ANTES do parcelamento existir: uma linha
-- so, de R$ 3.335,35, vencendo 25/09. Este script troca por 3 parcelas.
--
-- Valores e datas informados pelo Wagner (boleto do fornecedor):
--   1/3  25/09/2026  R$ 1.056,19
--   2/3  10/10/2026  R$ 1.056,20
--   3/3  25/10/2026  R$ 1.056,20
--   total R$ 3.168,59
--
-- ATENCAO 1: rodar DEPOIS de SQL_PARCELAS_BOLETO.sql (usa as colunas
--            parcelas e parcela_intervalo).
-- ATENCAO 2: o total do boleto (3.168,59) e R$ 166,76 MENOR que a soma
--            dos itens recebidos (3.335,35). Este script acerta a conta
--            a pagar e o financeiro; o custo dos itens no estoque NAO e
--            tocado aqui - depende de saber a causa da diferenca.
-- ============================================================

-- ------------------------------------------------------------
-- PASSO 1 - SO LEITURA: como esta hoje
-- Esperado: 1 rascunho de 3335.35 venc 2026-09-25, e a conta a pagar
-- com valor 3335.35, status pendente, lancamento_id nulo.
-- Se aparecer lancamento (nao rascunho), PARE: ja foi aprovado no
-- financeiro e o acerto tem que ser feito la.
-- ------------------------------------------------------------
SELECT 'rascunho' AS onde, id, descricao, valor, acrescimo, vencimento, status
  FROM lancamentos_rascunho
 WHERE pedido_num = '#01354';

SELECT 'lancamento' AS onde, id, descricao, valor, vencimento, status
  FROM lancamentos
 WHERE numero_pedido = '#01354';

SELECT 'conta' AS onde, id, valor, vencimento, status, lancamento_id
  FROM cmp_contas_pagar
 WHERE pedido_num = '#01354';


-- ------------------------------------------------------------
-- PASSO 2 - BACKUP do rascunho atual (da para voltar atras)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bkp_rascunho_1354 AS
SELECT * FROM lancamentos_rascunho WHERE pedido_num = '#01354';

SELECT count(*) AS linhas_no_backup FROM bkp_rascunho_1354;


-- ------------------------------------------------------------
-- PASSO 3 - troca 1 rascunho por 3 parcelas
-- Copia todos os campos do rascunho atual e muda so descricao,
-- observacoes, valor e vencimento de cada parcela.
-- ------------------------------------------------------------
INSERT INTO lancamentos_rascunho
  (descricao, valor, acrescimo, desconto, vencimento, tipo, status,
   fornecedor_id, plano_conta_id, numero_pedido, observacoes,
   pedido_num, conta_id, tem_rateio, unidade_id)
SELECT
  r.descricao || ' (' || p.num || '/3)',
  p.valor,
  0, 0,
  p.venc,
  r.tipo, r.status,
  r.fornecedor_id, r.plano_conta_id, r.numero_pedido,
  coalesce(r.observacoes, 'Pedido #01354') || ' - Parcela ' || p.num || '/3',
  r.pedido_num, r.conta_id, r.tem_rateio, r.unidade_id
FROM lancamentos_rascunho r
CROSS JOIN (VALUES
    (1, 1056.19::numeric, DATE '2026-09-25'),
    (2, 1056.20::numeric, DATE '2026-10-10'),
    (3, 1056.20::numeric, DATE '2026-10-25')
  ) AS p(num, valor, venc)
WHERE r.pedido_num = '#01354'
  AND r.descricao NOT LIKE '%/3)';   -- so a partir da linha original

-- Apaga a linha antiga (a de 3.335,35, sem "(n/3)" na descricao)
DELETE FROM lancamentos_rascunho
 WHERE pedido_num = '#01354'
   AND descricao NOT LIKE '%/3)';


-- ------------------------------------------------------------
-- PASSO 4 - conta a pagar: total correto do boleto e 3 parcelas
-- ------------------------------------------------------------
UPDATE cmp_contas_pagar
   SET valor = 3168.59,
       vencimento = DATE '2026-09-25',
       parcelas = 3,
       parcela_intervalo = '15'
 WHERE pedido_num = '#01354';


-- ------------------------------------------------------------
-- PASSO 5 - CONFERE
-- Esperado: 3 rascunhos (1/3, 2/3, 3/3), soma 3168.59, vencendo
-- 25/09, 10/10 e 25/10; conta a pagar 3168.59 com parcelas = 3.
-- ------------------------------------------------------------
SELECT descricao, valor, vencimento, observacoes
  FROM lancamentos_rascunho
 WHERE pedido_num = '#01354'
 ORDER BY vencimento;

SELECT count(*) AS parcelas, sum(valor) AS soma
  FROM lancamentos_rascunho
 WHERE pedido_num = '#01354';

SELECT valor, vencimento, parcelas, parcela_intervalo
  FROM cmp_contas_pagar
 WHERE pedido_num = '#01354';
