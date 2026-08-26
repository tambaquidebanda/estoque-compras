-- ============================================================================
-- PEDIDOS INTERNOS / CONTAGENS DUPLICADOS PELO TOQUE DUPLO
--
-- Causa (ja corrigida no codigo): o botao de enviar continuava clicavel enquanto
-- o envio estava no ar, e continuava clicavel depois que ele terminava. Cada toque
-- extra gravava um pedido inteiro de novo.
--
-- "Rajada" = duas ou mais linhas do mesmo setor / mesma data / mesmo tipo / mesmo
-- grupo gravadas com menos de 3 segundos entre uma e a seguinte. Tres segundos e'
-- longe demais para ser um segundo pedido de verdade e perto demais para ser
-- outra coisa que nao o mesmo dedo no mesmo botao.
--
-- ----------------------------------------------------------------------------
-- O QUE ESTE SQL APAGA: SO O QUE FOI CANCELADO. NADA MAIS.
--
-- 'cancelado' e' o unico status em que alguem olhou a tela e disse, com todas as
-- letras, que aquela linha nao vale. E' a unica linha que da para apagar sem
-- adivinhar.
--
-- Fica tudo o mais:
--   recebido  - ja movimentou saldo; apagar nao desfaz a movimentacao, so esconde.
--   liberado  - alguem do estoque preencheu as quantidades e liberou. E' trabalho
--               feito. Quando a rajada tem DUAS liberadas e nenhuma recebida, nao
--               ha como saber qual delas era a boa - entao ficam as duas.
--   pendente  - ainda em aberto.
--
-- Unica excecao: se a rajada INTEIRA foi cancelada, a mais antiga fica, para o
-- historico nao perder o registro de que aquele pedido existiu e foi cancelado.
-- ----------------------------------------------------------------------------
--
-- PASSO 1 e 2 sao SO LEITURA e usam exatamente a mesma regra do PASSO 3 - o que
-- aparecer marcado APAGA no PASSO 1 e' exatamente o que o PASSO 3 apaga.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- PASSO 1 (leitura): cada linha de cada rajada, com o veredito e os itens
--
-- Confira duas coisas:
--   1. os itens das linhas da mesma rajada sao iguais (e' o mesmo pedido repetido,
--      nao dois pedidos parecidos);
--   2. toda linha marcada APAGA tem status 'cancelado'. Se alguma nao tiver, PARE.
-- ---------------------------------------------------------------------------
WITH ilhas AS (
  SELECT p.*,
         CASE WHEN p.criado_em - lag(p.criado_em) OVER (
                    PARTITION BY p.setor, p.data, p.tipo, COALESCE(p.obs, '')
                    ORDER BY p.criado_em) <= interval '3 seconds'
              THEN 0 ELSE 1 END AS abre_rajada
  FROM pedidos_internos p
),
rajadas AS (
  SELECT i.*,
         sum(i.abre_rajada) OVER (
           PARTITION BY i.setor, i.data, i.tipo, COALESCE(i.obs, '')
           ORDER BY i.criado_em ROWS UNBOUNDED PRECEDING) AS rajada
  FROM ilhas i
),
julgado AS (
  SELECT r.*,
         count(*)                             OVER j AS n_rajada,
         bool_or(r.status <> 'cancelado')      OVER j AS tem_nao_cancelada,
         row_number() OVER (
           PARTITION BY r.setor, r.data, r.tipo, COALESCE(r.obs, ''), r.rajada, r.status
           ORDER BY r.criado_em)                      AS posto_no_status
  FROM rajadas r
  WINDOW j AS (PARTITION BY r.setor, r.data, r.tipo, COALESCE(r.obs, ''), r.rajada)
)
SELECT j.criado_em, j.num_pedido, j.setor, j.data, j.tipo, j.obs, j.status,
       CASE WHEN j.status = 'cancelado'
             AND (j.tem_nao_cancelada OR j.posto_no_status > 1)
            THEN 'APAGA' ELSE 'FICA' END AS veredito,
       (SELECT string_agg(i.nome || ' x' || i.qtd_pedida, ', ' ORDER BY i.nome)
          FROM pedidos_internos_itens i WHERE i.pedido_id = j.id) AS itens
FROM julgado j
WHERE j.n_rajada > 1
ORDER BY j.criado_em DESC;


-- ---------------------------------------------------------------------------
-- PASSO 2 (leitura): o placar, para conferir o numero antes de apagar
--
-- Em 26/08/2026 este passo dava:
--     APAGA  cancelado  60      <- e' o unico APAGA que pode aparecer
--     FICA   recebido   53
--     FICA   liberado   45
--     FICA   cancelado  22
--     FICA   pendente    1
--
-- Se aparecer QUALQUER status diferente de 'cancelado' na linha APAGA, PARE: a
-- regra mudou e algo esta errado.
-- ---------------------------------------------------------------------------
WITH ilhas AS (
  SELECT p.*,
         CASE WHEN p.criado_em - lag(p.criado_em) OVER (
                    PARTITION BY p.setor, p.data, p.tipo, COALESCE(p.obs, '')
                    ORDER BY p.criado_em) <= interval '3 seconds'
              THEN 0 ELSE 1 END AS abre_rajada
  FROM pedidos_internos p
),
rajadas AS (
  SELECT i.*,
         sum(i.abre_rajada) OVER (
           PARTITION BY i.setor, i.data, i.tipo, COALESCE(i.obs, '')
           ORDER BY i.criado_em ROWS UNBOUNDED PRECEDING) AS rajada
  FROM ilhas i
),
julgado AS (
  SELECT r.*,
         count(*)                             OVER j AS n_rajada,
         bool_or(r.status <> 'cancelado')      OVER j AS tem_nao_cancelada,
         row_number() OVER (
           PARTITION BY r.setor, r.data, r.tipo, COALESCE(r.obs, ''), r.rajada, r.status
           ORDER BY r.criado_em)                      AS posto_no_status
  FROM rajadas r
  WINDOW j AS (PARTITION BY r.setor, r.data, r.tipo, COALESCE(r.obs, ''), r.rajada)
)
SELECT CASE WHEN j.status = 'cancelado'
             AND (j.tem_nao_cancelada OR j.posto_no_status > 1)
            THEN 'APAGA' ELSE 'FICA' END AS veredito,
       j.status, count(*) AS linhas
FROM julgado j
WHERE j.n_rajada > 1
GROUP BY 1, 2
ORDER BY 1, 3 DESC;


-- ---------------------------------------------------------------------------
-- PASSO 3 (APAGA): so depois de conferir o PASSO 1 e o PASSO 2
--
-- Apaga 60 linhas, todas com status 'cancelado'.
--
-- Os itens somem junto sozinhos: pedidos_internos_itens.pedido_id tem
-- ON DELETE CASCADE. Por isso e' um comando so.
--
-- O RETURNING mostra na tela exatamente quais linhas sairam - guarde esse
-- resultado antes de fechar a aba, e' a unica copia do que foi apagado.
--
-- Para executar: tire o "-- " do inicio de cada linha do bloco abaixo.
-- ---------------------------------------------------------------------------
-- WITH ilhas AS (
--   SELECT p.*,
--          CASE WHEN p.criado_em - lag(p.criado_em) OVER (
--                     PARTITION BY p.setor, p.data, p.tipo, COALESCE(p.obs, '')
--                     ORDER BY p.criado_em) <= interval '3 seconds'
--               THEN 0 ELSE 1 END AS abre_rajada
--   FROM pedidos_internos p
-- ),
-- rajadas AS (
--   SELECT i.*,
--          sum(i.abre_rajada) OVER (
--            PARTITION BY i.setor, i.data, i.tipo, COALESCE(i.obs, '')
--            ORDER BY i.criado_em ROWS UNBOUNDED PRECEDING) AS rajada
--   FROM ilhas i
-- ),
-- julgado AS (
--   SELECT r.*,
--          count(*)                        OVER j AS n_rajada,
--          bool_or(r.status <> 'cancelado') OVER j AS tem_nao_cancelada,
--          row_number() OVER (
--            PARTITION BY r.setor, r.data, r.tipo, COALESCE(r.obs, ''), r.rajada, r.status
--            ORDER BY r.criado_em)                 AS posto_no_status
--   FROM rajadas r
--   WINDOW j AS (PARTITION BY r.setor, r.data, r.tipo, COALESCE(r.obs, ''), r.rajada)
-- )
-- DELETE FROM pedidos_internos p
-- USING julgado j
-- WHERE p.id = j.id
--   AND j.n_rajada > 1
--   AND j.status = 'cancelado'
--   AND (j.tem_nao_cancelada OR j.posto_no_status > 1)
-- RETURNING p.criado_em, p.num_pedido, p.setor, p.data, p.tipo, p.obs, p.status;


-- ---------------------------------------------------------------------------
-- PASSO 4 (leitura): as contagens duplicadas na mesma rajada
--
-- Mesmo botao, mesmo dedo: o envio grava a contagem ANTES do pedido, entao o
-- est_inventarios duplicou junto. Aqui nao ha o que decidir: a contagem grava
-- saldo absoluto (nao soma), logo a segunda linha gravou o mesmo numero por cima.
-- O saldo esta certo - o que sobra e' a linha repetida no historico.
-- ---------------------------------------------------------------------------
SELECT i.criado_em, i.num_inv, i.setor, i.grupo, i.data, i.total_geral
FROM est_inventarios i
WHERE EXISTS (
  SELECT 1 FROM est_inventarios a
  WHERE a.setor = i.setor AND a.grupo = i.grupo AND a.data = i.data
    AND a.criado_em < i.criado_em
    AND i.criado_em - a.criado_em <= interval '3 seconds'
)
ORDER BY i.criado_em DESC;
