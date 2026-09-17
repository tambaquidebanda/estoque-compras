-- ============================================================================
-- DATA EM MANAUS - conserto do que ja esta gravado          (17/09/2026)
-- ============================================================================
--
-- O QUE ACONTECEU
-- A tela gravava a data com o relogio DO APARELHO, nao de Manaus. Na noite de
-- 15/09/2026, as 22h, o Kevin (BAR) gravou 15/09 e o Yefecson (CHURRASQUEIRA)
-- gravou 16/09 - mesma noite, um minuto de diferenca, celulares em fusos
-- diferentes. Foi por isso que a contagem da churrasqueira do dia 15 "sumiu":
-- ela esta arquivada no dia 16.
--
-- O codigo ja foi consertado (hojeLocal() agora usa America/Manaus, commit
-- desta mesma leva). Este arquivo conserta o que ficou para tras.
--
-- COMO O CONSERTO E FEITO
-- Linha a linha, cada registro recebe o dia do seu PROPRIO criado_em em Manaus.
-- NAO e um deslocamento de um dia no bloco inteiro: isso ja foi testado em
-- 09/09/2026 e PIOROU (quem estava certo passava a errar), porque o erro e
-- misturado - depende do aparelho de quem digitou.
--
-- O QUE ESTE ARQUIVO NAO TOCA, DE PROPOSITO
-- `est_movimentacoes.data` FICA COMO ESTA. Ali a diferenca entre `data` e o dia
-- do `criado_em` e quase toda LEGITIMA: o robo da baixa roda as 06h e grava o
-- movimento da venda com a data do DIA DA VENDA, de proposito. "Consertar"
-- aquilo pelo criado_em jogaria 1.702 movimentos de venda para o dia errado.
-- Quem precisa do dia certo ali (o pedido sombra) ja deriva pelo criado_em.
--
-- COMO RODAR
-- Um PASSO por vez, conferindo o resultado antes do proximo.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Quanto esta errado, e como.
-- ============================================================================

-- 1a) o tamanho do problema
SELECT 'est_inventarios' AS tabela,
       COUNT(*)                                                      AS linhas,
       COUNT(*) FILTER (WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date) AS erradas,
       ROUND(100.0 * COUNT(*) FILTER (WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date)
             / NULLIF(COUNT(*), 0), 1)                               AS pct
FROM est_inventarios
UNION ALL
SELECT 'pedidos_internos',
       COUNT(*),
       COUNT(*) FILTER (WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date),
       ROUND(100.0 * COUNT(*) FILTER (WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date)
             / NULLIF(COUNT(*), 0), 1)
FROM pedidos_internos;

-- 1b) a prova: a noite de 15/09/2026, lado a lado. Kevin certo, Yefecson errado,
--     um minuto de diferenca. E o retrato do erro inteiro.
SELECT num_inv, setor, grupo, responsavel,
       data                                              AS gravou_como,
       (criado_em AT TIME ZONE 'America/Manaus')::date    AS dia_real,
       to_char(criado_em AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI') AS hora_manaus,
       CASE WHEN data <> (criado_em AT TIME ZONE 'America/Manaus')::date
            THEN '<<< ERRADO' ELSE '' END                AS marca
FROM est_inventarios
WHERE criado_em >= '2026-09-15 20:00-04' AND criado_em < '2026-09-16 06:00-04'
ORDER BY criado_em;

-- 1c) de quem sao os aparelhos com o relogio errado (quem contar aqui precisa
--     acertar o fuso do celular, senao volta a acontecer)
SELECT responsavel,
       COUNT(*)                                                      AS contagens,
       COUNT(*) FILTER (WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date) AS erradas
FROM est_inventarios
WHERE criado_em >= '2026-08-01'
GROUP BY responsavel
HAVING COUNT(*) FILTER (WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date) > 0
ORDER BY erradas DESC;


-- ============================================================================
-- PASSO 2 - BACKUP. Nao pule.
-- ============================================================================

CREATE TABLE IF NOT EXISTS bkp_data_manaus_inv AS
SELECT id, data AS data_antiga, criado_em, now() AS salvo_em
FROM est_inventarios
WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date;

CREATE TABLE IF NOT EXISTS bkp_data_manaus_ped AS
SELECT id, data AS data_antiga, criado_em, now() AS salvo_em
FROM pedidos_internos
WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date;

-- confere que o backup tem o mesmo tanto que o PASSO 1 acusou
SELECT (SELECT COUNT(*) FROM bkp_data_manaus_inv) AS inventarios_salvos,
       (SELECT COUNT(*) FROM bkp_data_manaus_ped) AS pedidos_salvos;


-- ============================================================================
-- PASSO 3 - CONSERTO das contagens
-- ============================================================================

UPDATE est_inventarios
SET    data = (criado_em AT TIME ZONE 'America/Manaus')::date
WHERE  data <> (criado_em AT TIME ZONE 'America/Manaus')::date;


-- ============================================================================
-- PASSO 4 - CONSERTO dos pedidos internos
-- ============================================================================

UPDATE pedidos_internos
SET    data = (criado_em AT TIME ZONE 'America/Manaus')::date
WHERE  data <> (criado_em AT TIME ZONE 'America/Manaus')::date;


-- ============================================================================
-- PASSO 5 - CONFERENCIA. As duas colunas tem que voltar ZERO.
-- ============================================================================

SELECT (SELECT COUNT(*) FROM est_inventarios
        WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date) AS inventarios_ainda_errados,
       (SELECT COUNT(*) FROM pedidos_internos
        WHERE data <> (criado_em AT TIME ZONE 'America/Manaus')::date) AS pedidos_ainda_errados;

-- E a noite de 15/09 de novo: agora a CHURRASQUEIRA tem que aparecer no dia 15.
SELECT data, setor, COUNT(*) AS contagens
FROM est_inventarios
WHERE data IN ('2026-09-15', '2026-09-16') AND local = 'Centro'
GROUP BY data, setor
ORDER BY data, setor;


-- ============================================================================
-- VOLTAR ATRAS, se precisar
-- ============================================================================
-- UPDATE est_inventarios i SET data = b.data_antiga
--   FROM bkp_data_manaus_inv b WHERE b.id = i.id;
-- UPDATE pedidos_internos p SET data = b.data_antiga
--   FROM bkp_data_manaus_ped b WHERE b.id = p.id;
