-- =====================================================================
-- AMARRAR A CONTA A PAGAR DO #01439 NO LANCAMENTO QUE JA EXISTE
--
-- O QUE ACONTECEU
-- O recebimento de 23/09 criou a conta a pagar (R$ 1.909,44) e, dois
-- minutos depois, a despesa no financeiro ("Pedido #01439 - Comprador
-- Externo", Nubank, pendente, mesmo valor). O ultimo passo dessa rotina
-- e gravar o id da despesa em cmp_contas_pagar.lancamento_id, e esse
-- passo nao pegou. A conta ficou apontando para lugar nenhum.
--
-- O QUE ISSO CAUSA
-- Do lado do estoque o pedido parece que nunca foi ao financeiro. Antes
-- do conserto de hoje no app.js, finalizar o pedido de novo pelo desktop
-- criava uma SEGUNDA despesa de R$ 1.909,44.
--
-- O QUE ESTE SQL FAZ
-- Uma linha: grava o id da despesa que ja existe no campo de vinculo da
-- conta. Nao cria, nao apaga e nao muda valor de nada.
--
-- O QUE ELE NAO FAZ
-- Nao mexe no rascunho que esta em Integracoes Pendentes. Esse sai pelo
-- botao Rejeitar, na tela do financeiro.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SOMENTE LEITURA. Confira antes de rodar qualquer outra coisa.
-- Esperado: 1 linha de conta com lancamento_id vazio, e 1 linha de
-- lancamento com o mesmo valor (1909.44).
-- ---------------------------------------------------------------------
SELECT 'conta a pagar' AS o_que,
       id::text,
       valor,
       status,
       COALESCE(lancamento_id::text, '(vazio)')              AS lancamento_id,
       COALESCE(adiantamento_lancamento_id::text, '(vazio)') AS adiantamento_id,
       criado_em
FROM   cmp_contas_pagar
WHERE  pedido_num = '#01439'
UNION ALL
SELECT 'lancamento',
       id::text,
       valor,
       status,
       descricao,
       COALESCE(banco_id::text, '(sem banco)'),
       criado_em
FROM   lancamentos
WHERE  numero_pedido = '#01439'
ORDER  BY o_que;


-- ---------------------------------------------------------------------
-- PASSO 2 - BACKUP da linha antes de tocar nela.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bkp_vinculo_01439 AS
SELECT * FROM cmp_contas_pagar WHERE pedido_num = '#01439';

SELECT count(*) AS linhas_no_backup FROM bkp_vinculo_01439;
-- Esperado: 1


-- ---------------------------------------------------------------------
-- PASSO 3 - O CONSERTO.
-- Amarra a conta na despesa que ja existe. O WHERE tem tres protecoes:
-- so o pedido #01439, so se o vinculo estiver vazio, e o id da despesa
-- vem de uma subconsulta pelo proprio numero do pedido - assim, se
-- alguem apagar ou trocar a despesa antes de voce rodar isto, o UPDATE
-- nao encontra nada e nao grava nada errado.
-- ---------------------------------------------------------------------
UPDATE cmp_contas_pagar cp
SET    lancamento_id = (
         SELECT l.id
         FROM   lancamentos l
         WHERE  l.numero_pedido = '#01439'
         ORDER  BY l.vencimento
         LIMIT  1
       )
WHERE  cp.pedido_num    = '#01439'
  AND  cp.lancamento_id IS NULL
  AND  EXISTS (SELECT 1 FROM lancamentos l2 WHERE l2.numero_pedido = '#01439');
-- Esperado: UPDATE 1


-- ---------------------------------------------------------------------
-- PASSO 4 - CONFERENCIA. Rode e leia a coluna resultado.
-- ---------------------------------------------------------------------
SELECT cp.pedido_num,
       cp.valor        AS valor_da_conta,
       l.valor         AS valor_da_despesa,
       l.descricao     AS despesa,
       l.status        AS status_da_despesa,
       CASE
         WHEN cp.lancamento_id IS NULL             THEN 'FALHOU - a conta continua sem vinculo'
         WHEN l.id IS NULL                         THEN 'FALHOU - aponta para despesa que nao existe'
         WHEN round(cp.valor::numeric, 2)
              <> round(l.valor::numeric, 2)        THEN 'ATENCAO - vinculo feito, mas os valores nao batem'
         ELSE                                           'OK - conta amarrada na despesa certa'
       END AS resultado
FROM   cmp_contas_pagar cp
LEFT   JOIN lancamentos l ON l.id = cp.lancamento_id
WHERE  cp.pedido_num = '#01439';


-- ---------------------------------------------------------------------
-- SE PRECISAR DESFAZER
-- ---------------------------------------------------------------------
-- UPDATE cmp_contas_pagar cp
-- SET    lancamento_id = b.lancamento_id
-- FROM   bkp_vinculo_01439 b
-- WHERE  cp.id = b.id;
