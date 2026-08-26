-- ============================================================================
-- PEDIDOS INTERNOS / CONTAGENS DUPLICADOS PELO TOQUE DUPLO
--
-- Causa (ja corrigida no codigo): o botao de enviar continuava clicavel enquanto
-- o envio estava no ar, e continuava clicavel depois que ele terminava. Cada toque
-- extra gravava um pedido inteiro de novo.
--
-- "Extra" aqui = linha que tem OUTRA linha anterior do mesmo setor / mesma data /
-- mesmo tipo / mesmo grupo criada ha menos de 3 segundos. Tres segundos e' longe
-- demais para ser um segundo pedido de verdade e perto demais para ser outra coisa
-- que nao o mesmo dedo no mesmo botao.
--
-- PASSO 1 e 2 sao SO LEITURA. O PASSO 3 apaga - leia o aviso antes.
-- ============================================================================


-- -- PASSO 1 (leitura): as rajadas de pedido, com os itens de cada linha ------
WITH extras AS (
  SELECT p.*,
         EXISTS (
           SELECT 1 FROM pedidos_internos a
           WHERE a.setor = p.setor AND a.data = p.data
             AND a.tipo  = p.tipo  AND COALESCE(a.obs,'') = COALESCE(p.obs,'')
             AND a.criado_em < p.criado_em
             AND p.criado_em - a.criado_em <= interval '3 seconds'
         ) AS eh_extra
  FROM pedidos_internos p
)
SELECT e.criado_em, e.num_pedido, e.setor, e.data, e.tipo, e.obs, e.status,
       CASE WHEN e.eh_extra THEN '>> EXTRA' ELSE 'primeira' END AS papel,
       (SELECT string_agg(i.nome || ' x' || i.qtd_pedida, ', ' ORDER BY i.nome)
          FROM pedidos_internos_itens i WHERE i.pedido_id = e.id) AS itens
FROM extras e
WHERE EXISTS (SELECT 1 FROM extras x
              WHERE x.setor = e.setor AND x.data = e.data AND x.tipo = e.tipo
                AND COALESCE(x.obs,'') = COALESCE(e.obs,'') AND x.eh_extra
                AND abs(EXTRACT(epoch FROM x.criado_em - e.criado_em)) <= 3)
ORDER BY e.criado_em DESC;


-- -- PASSO 2 (leitura): resumo por status ------------------------------------
-- 'recebido' e' o unico status que mexeu no saldo (baixou ESTOQUE_LOJA e subiu o
-- setor, duas vezes). Essas NAO devem ser apagadas aqui: apagar a linha nao desfaz
-- a movimentacao. O saldo se corrige sozinho na proxima contagem do setor e do
-- ESTOQUE_LOJA; o que fica torto e' o historico de consumo no est_movimentacoes.
WITH extras AS (
  SELECT p.id, p.status
  FROM pedidos_internos p
  WHERE EXISTS (
    SELECT 1 FROM pedidos_internos a
    WHERE a.setor = p.setor AND a.data = p.data
      AND a.tipo  = p.tipo  AND COALESCE(a.obs,'') = COALESCE(p.obs,'')
      AND a.criado_em < p.criado_em
      AND p.criado_em - a.criado_em <= interval '3 seconds'
  )
)
SELECT status, count(*) AS linhas_extras FROM extras GROUP BY status ORDER BY 2 DESC;


-- -- PASSO 3 (APAGA): so as extras que nunca mexeram no saldo ----------------
-- Rode SO depois de conferir o PASSO 1. Apaga apenas status cancelado / pendente /
-- liberado: nenhum desses movimentou estoque, entao sumir com a linha nao deixa
-- rastro torto. As de status 'recebido' ficam de proposito.
--
-- Tire o comentario das duas ultimas linhas para executar.
--
-- WITH extras AS (
--   SELECT p.id FROM pedidos_internos p
--   WHERE p.status IN ('cancelado','pendente','liberado')
--     AND EXISTS (
--       SELECT 1 FROM pedidos_internos a
--       WHERE a.setor = p.setor AND a.data = p.data
--         AND a.tipo  = p.tipo  AND COALESCE(a.obs,'') = COALESCE(p.obs,'')
--         AND a.criado_em < p.criado_em
--         AND p.criado_em - a.criado_em <= interval '3 seconds'
--     )
-- )
-- DELETE FROM pedidos_internos_itens WHERE pedido_id IN (SELECT id FROM extras);
-- DELETE FROM pedidos_internos       WHERE id       IN (SELECT id FROM extras);


-- -- PASSO 4 (leitura): as contagens duplicadas na mesma rajada --------------
-- Mesmo botao, mesmo dedo: o envio grava a contagem ANTES do pedido, entao o
-- est_inventarios duplicou junto. A contagem grava saldo absoluto (nao soma),
-- logo a segunda linha gravou o mesmo numero por cima - o saldo esta certo, o que
-- sobra e' a linha repetida no historico.
SELECT i.criado_em, i.num_inv, i.setor, i.grupo, i.data, i.total_geral
FROM est_inventarios i
WHERE EXISTS (
  SELECT 1 FROM est_inventarios a
  WHERE a.setor = i.setor AND a.grupo = i.grupo AND a.data = i.data
    AND a.criado_em < i.criado_em
    AND i.criado_em - a.criado_em <= interval '3 seconds'
)
ORDER BY i.criado_em DESC;
