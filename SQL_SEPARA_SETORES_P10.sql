-- ============================================================================
-- SEPARA OS SETORES DO DELIVERY P10 DOS SETORES DO CENTRO (20/10/2026)
--
-- Ate hoje a contagem e o pedido interno dos setores do P10 gravavam no saldo com o
-- nome do setor puro (COZINHA, CHURRASQUEIRA...). A Cozinha e a Churrasqueira do
-- Centro usam o MESMO nome, entao as duas lojas dividiam uma linha de saldo so e a
-- contagem de uma apagava a da outra. Em 20/10 o P10 contou a Cozinha as 16h e uns
-- 40 itens da Cozinha do Centro ficaram com o numero do P10.
--
-- O codigo novo (mesmo commit) grava o P10 em P10_COZINHA, P10_CHURRASQUEIRA,
-- P10_BEBIDAS... Este SQL arruma o que ja esta no banco:
--   PASSO 2: Bebidas, Sobremesas, Descartavel e Material de Limpeza so existem no P10.
--            O saldo deles muda de lugar inteiro (BEBIDAS -> P10_BEBIDAS...).
--   PASSO 3: Cozinha e Churrasqueira. Da linha do Centro sai tudo o que o P10 lancou
--            ali (contagens do P10 e pedidos do P10 recebidos) DEPOIS da ultima
--            contagem do Centro daquele item - a contagem do Centro zera o passado.
--            O P10 ganha o saldo da ultima contagem dele + pedidos recebidos depois.
--
-- O razao (est_movimentacoes) e so de acrescimo: nada e apagado nem renomeado. Cada
-- mudanca de saldo ganha a linha dela (ajuste / saldo_inicial, origem
-- 'separacao_p10'), e a soma do razao continua batendo com o saldo.
--
-- Rodar UM PASSO POR VEZ, na ordem. Rodar DEPOIS do Push e depois que o P10 terminou
-- a contagem do dia (celular com o codigo velho ainda grava em COZINHA).
-- Pode rodar antes ou depois da contagem do Centro: o que o Centro contar depois do
-- P10 ja zera o passado e o PASSO 3 nao desconta de novo.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Mostra o que vai mudar. Nao altera nada.
-- ============================================================================

-- 1a) Setores que so o P10 tem: saldo que muda de lugar
SELECT s.local AS de, 'P10_' || s.local AS para, count(*) AS itens, round(sum(s.saldo), 3) AS soma_saldo,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM est_saldo_local x
                                      WHERE x.produto_id = s.produto_id AND x.local = 'P10_' || s.local)) AS ja_tem_no_destino
FROM est_saldo_local s
WHERE s.local IN ('BEBIDAS', 'SOBREMESAS', 'DESCARTAVEL', 'MATERIAL DE LIMPEZA')
GROUP BY s.local ORDER BY s.local;

-- 1b) Cozinha e Churrasqueira: o que sai da linha do Centro e o que o P10 recebe
WITH inv_p10 AS (
  SELECT id, num_inv, setor, criado_em FROM est_inventarios
  WHERE local = 'Delivery P10' AND setor IN ('COZINHA', 'CHURRASQUEIRA')
),
ult_centro AS (
  SELECT c.setor, ci.produto_id, max(c.criado_em) AS ate
  FROM est_inventarios c JOIN est_inventario_itens ci ON ci.inventario_id = c.id
  WHERE c.local = 'Centro' AND c.setor IN ('COZINHA', 'CHURRASQUEIRA') AND ci.produto_id IS NOT NULL
    AND c.criado_em >= (SELECT min(criado_em) FROM inv_p10)
  GROUP BY 1, 2
),
d_p10 AS (            -- o que o P10 lancou na linha do Centro
  SELECT m.local, m.produto_id, m.quantidade, m.criado_em, 'contagem' AS tipo
  FROM est_movimentacoes m JOIN inv_p10 i
    ON i.num_inv = substring(m.motivo from 'INV-[0-9]+') AND i.setor = m.local
  WHERE m.tipo = 'contagem' AND m.local IN ('COZINHA', 'CHURRASQUEIRA')
  UNION ALL
  SELECT m.local, m.produto_id, m.quantidade, m.criado_em, 'pedido'
  FROM est_movimentacoes m
  WHERE m.tipo = 'pedido_interno_entrada' AND m.local IN ('COZINHA', 'CHURRASQUEIRA')
    AND m.criado_em >= (SELECT min(criado_em) FROM inv_p10)
    AND EXISTS (SELECT 1 FROM pedidos_internos p JOIN pedidos_internos_itens pi ON pi.pedido_id = p.id
                WHERE p.local = 'Delivery P10' AND p.setor = m.local AND p.status = 'recebido'
                  AND pi.produto_id = m.produto_id AND pi.qtd_recebida = m.quantidade
                  AND p.recebido_em BETWEEN m.criado_em - interval '30 minutes' AND m.criado_em + interval '30 minutes')
),
sai AS (
  SELECT d.local, d.produto_id, sum(d.quantidade) AS sai
  FROM d_p10 d LEFT JOIN ult_centro u ON u.setor = d.local AND u.produto_id = d.produto_id
  WHERE u.ate IS NULL OR d.criado_em > u.ate
  GROUP BY 1, 2 HAVING sum(d.quantidade) <> 0
)
SELECT 'CENTRO' AS lado, x.local, p.nome, s.saldo AS saldo_hoje, round(s.saldo - x.sai, 3) AS fica, round(x.sai, 3) AS sai_do_centro
FROM sai x JOIN est_produtos p ON p.id = x.produto_id
LEFT JOIN est_saldo_local s ON s.produto_id = x.produto_id AND s.local = x.local
ORDER BY x.local, p.nome;

WITH inv_p10 AS (
  SELECT id, num_inv, setor, criado_em FROM est_inventarios
  WHERE local = 'Delivery P10' AND setor IN ('COZINHA', 'CHURRASQUEIRA')
),
ult_p10 AS (          -- ultima contagem do P10 de cada item (repetido na mesma contagem: o maior)
  SELECT DISTINCT ON (i.setor, ii.produto_id) i.setor, ii.produto_id, coalesce(ii.estoque, 0) AS estoque, i.criado_em, i.num_inv
  FROM inv_p10 i JOIN est_inventario_itens ii ON ii.inventario_id = i.id
  WHERE ii.produto_id IS NOT NULL
  ORDER BY i.setor, ii.produto_id, i.criado_em DESC, ii.estoque DESC NULLS LAST
),
ped_depois AS (       -- pedido do P10 recebido depois da ultima contagem do P10
  SELECT u.setor, u.produto_id, coalesce(sum(pi.qtd_recebida), 0) AS qtd
  FROM ult_p10 u
  JOIN pedidos_internos p ON p.local = 'Delivery P10' AND p.setor = u.setor AND p.status = 'recebido' AND p.recebido_em > u.criado_em
  JOIN pedidos_internos_itens pi ON pi.pedido_id = p.id AND pi.produto_id = u.produto_id
  GROUP BY 1, 2
)
SELECT 'P10' AS lado, 'P10_' || u.setor AS local, p.nome, u.estoque AS contou, u.num_inv,
       coalesce(d.qtd, 0) AS pedido_depois, u.estoque + coalesce(d.qtd, 0) AS saldo_p10,
       EXISTS (SELECT 1 FROM est_saldo_local x WHERE x.produto_id = u.produto_id AND x.local = 'P10_' || u.setor) AS ja_tem
FROM ult_p10 u JOIN est_produtos p ON p.id = u.produto_id
LEFT JOIN ped_depois d ON d.setor = u.setor AND d.produto_id = u.produto_id
WHERE u.estoque + coalesce(d.qtd, 0) <> 0
ORDER BY 2, p.nome;


-- ============================================================================
-- PASSO 2 - Bebidas, Sobremesas, Descartavel, Material de Limpeza -> P10_
-- Rodar este bloco inteiro de uma vez. Rodar de novo nao faz nada (as linhas velhas
-- saem no fim).
-- ============================================================================
BEGIN;

-- sai do lugar velho
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
SELECT produto_id, local, 'ajuste', -saldo,
       'Separacao P10 (20/10): saldo foi para P10_' || local, 'separacao_p10', 'SQL separacao P10', (now() AT TIME ZONE 'America/Manaus')::date
FROM est_saldo_local
WHERE local IN ('BEBIDAS', 'SOBREMESAS', 'DESCARTAVEL', 'MATERIAL DE LIMPEZA') AND saldo <> 0;

-- entra no lugar novo (se o P10 ja contou no lugar novo, a contagem nova vale e o velho nao entra)
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
SELECT s.produto_id, 'P10_' || s.local, 'saldo_inicial', s.saldo,
       'Separacao P10 (20/10): saldo veio de ' || s.local, 'separacao_p10', 'SQL separacao P10', (now() AT TIME ZONE 'America/Manaus')::date
FROM est_saldo_local s
WHERE s.local IN ('BEBIDAS', 'SOBREMESAS', 'DESCARTAVEL', 'MATERIAL DE LIMPEZA') AND s.saldo <> 0
  AND NOT EXISTS (SELECT 1 FROM est_saldo_local x WHERE x.produto_id = s.produto_id AND x.local = 'P10_' || s.local);

INSERT INTO est_saldo_local (produto_id, local, saldo, updated_at)
SELECT s.produto_id, 'P10_' || s.local, s.saldo, now()
FROM est_saldo_local s
WHERE s.local IN ('BEBIDAS', 'SOBREMESAS', 'DESCARTAVEL', 'MATERIAL DE LIMPEZA') AND s.saldo <> 0
ON CONFLICT (produto_id, local) DO NOTHING;

DELETE FROM est_saldo_local WHERE local IN ('BEBIDAS', 'SOBREMESAS', 'DESCARTAVEL', 'MATERIAL DE LIMPEZA');

COMMIT;


-- ============================================================================
-- PASSO 3 - Cozinha e Churrasqueira: separa o P10 do Centro
-- Rodar este bloco inteiro de uma vez. Trava: se ja rodou (tem linha
-- 'separacao_p10' na COZINHA/CHURRASQUEIRA), nao faz nada.
-- ============================================================================
BEGIN;

CREATE TEMP TABLE sep_inv_p10 ON COMMIT DROP AS
SELECT id, num_inv, setor, criado_em FROM est_inventarios
WHERE local = 'Delivery P10' AND setor IN ('COZINHA', 'CHURRASQUEIRA');

CREATE TEMP TABLE sep_ja_rodou ON COMMIT DROP AS
SELECT EXISTS (SELECT 1 FROM est_movimentacoes
               WHERE origem = 'separacao_p10' AND local IN ('COZINHA', 'CHURRASQUEIRA')) AS sim;

-- o que sai da linha do Centro
CREATE TEMP TABLE sep_sai ON COMMIT DROP AS
WITH ult_centro AS (
  SELECT c.setor, ci.produto_id, max(c.criado_em) AS ate
  FROM est_inventarios c JOIN est_inventario_itens ci ON ci.inventario_id = c.id
  WHERE c.local = 'Centro' AND c.setor IN ('COZINHA', 'CHURRASQUEIRA') AND ci.produto_id IS NOT NULL
    AND c.criado_em >= (SELECT min(criado_em) FROM sep_inv_p10)
  GROUP BY 1, 2
),
d_p10 AS (
  SELECT m.local, m.produto_id, m.quantidade, m.criado_em
  FROM est_movimentacoes m JOIN sep_inv_p10 i
    ON i.num_inv = substring(m.motivo from 'INV-[0-9]+') AND i.setor = m.local
  WHERE m.tipo = 'contagem' AND m.local IN ('COZINHA', 'CHURRASQUEIRA')
  UNION ALL
  SELECT m.local, m.produto_id, m.quantidade, m.criado_em
  FROM est_movimentacoes m
  WHERE m.tipo = 'pedido_interno_entrada' AND m.local IN ('COZINHA', 'CHURRASQUEIRA')
    AND m.criado_em >= (SELECT min(criado_em) FROM sep_inv_p10)
    AND EXISTS (SELECT 1 FROM pedidos_internos p JOIN pedidos_internos_itens pi ON pi.pedido_id = p.id
                WHERE p.local = 'Delivery P10' AND p.setor = m.local AND p.status = 'recebido'
                  AND pi.produto_id = m.produto_id AND pi.qtd_recebida = m.quantidade
                  AND p.recebido_em BETWEEN m.criado_em - interval '30 minutes' AND m.criado_em + interval '30 minutes')
)
SELECT d.local, d.produto_id, sum(d.quantidade) AS sai
FROM d_p10 d LEFT JOIN ult_centro u ON u.setor = d.local AND u.produto_id = d.produto_id
WHERE (u.ate IS NULL OR d.criado_em > u.ate) AND NOT (SELECT sim FROM sep_ja_rodou)
GROUP BY 1, 2 HAVING sum(d.quantidade) <> 0;

-- o que o P10 recebe
CREATE TEMP TABLE sep_p10 ON COMMIT DROP AS
WITH ult_p10 AS (
  SELECT DISTINCT ON (i.setor, ii.produto_id) i.setor, ii.produto_id, coalesce(ii.estoque, 0) AS estoque, i.criado_em, i.num_inv
  FROM sep_inv_p10 i JOIN est_inventario_itens ii ON ii.inventario_id = i.id
  WHERE ii.produto_id IS NOT NULL
  ORDER BY i.setor, ii.produto_id, i.criado_em DESC, ii.estoque DESC NULLS LAST
),
ped_depois AS (
  SELECT u.setor, u.produto_id, coalesce(sum(pi.qtd_recebida), 0) AS qtd
  FROM ult_p10 u
  JOIN pedidos_internos p ON p.local = 'Delivery P10' AND p.setor = u.setor AND p.status = 'recebido' AND p.recebido_em > u.criado_em
  JOIN pedidos_internos_itens pi ON pi.pedido_id = p.id AND pi.produto_id = u.produto_id
  GROUP BY 1, 2
)
SELECT 'P10_' || u.setor AS local, u.produto_id, u.estoque + coalesce(d.qtd, 0) AS saldo, u.num_inv
FROM ult_p10 u LEFT JOIN ped_depois d ON d.setor = u.setor AND d.produto_id = u.produto_id
WHERE u.estoque + coalesce(d.qtd, 0) <> 0
  AND NOT EXISTS (SELECT 1 FROM est_saldo_local x WHERE x.produto_id = u.produto_id AND x.local = 'P10_' || u.setor)
  AND NOT (SELECT sim FROM sep_ja_rodou);

-- Centro: razao + saldo
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
SELECT produto_id, local, 'ajuste', -sai,
       'Separacao P10 (20/10): sai da ' || local || ' do Centro o que o P10 lancou aqui', 'separacao_p10', 'SQL separacao P10', (now() AT TIME ZONE 'America/Manaus')::date
FROM sep_sai;

UPDATE est_saldo_local s SET saldo = s.saldo - x.sai, updated_at = now()
FROM sep_sai x WHERE s.produto_id = x.produto_id AND s.local = x.local;

-- P10: razao + saldo
INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
SELECT produto_id, local, 'saldo_inicial', saldo,
       'Separacao P10 (20/10): ultima contagem do P10 (' || num_inv || ') + pedidos recebidos depois', 'separacao_p10', 'SQL separacao P10', (now() AT TIME ZONE 'America/Manaus')::date
FROM sep_p10;

INSERT INTO est_saldo_local (produto_id, local, saldo, updated_at)
SELECT produto_id, local, saldo, now() FROM sep_p10
ON CONFLICT (produto_id, local) DO NOTHING;

SELECT (SELECT sim FROM sep_ja_rodou) AS ja_tinha_rodado,
       (SELECT count(*) FROM sep_sai) AS itens_corrigidos_no_centro,
       (SELECT count(*) FROM sep_p10) AS itens_novos_no_p10;

COMMIT;


-- ============================================================================
-- PASSO 4 - CONFERENCIA (so leitura)
-- ============================================================================

-- 4a) Nao sobra nada nos lugares velhos do P10 (esperado: 0 linhas)
SELECT local, count(*) FROM est_saldo_local
WHERE local IN ('BEBIDAS', 'SOBREMESAS', 'DESCARTAVEL', 'MATERIAL DE LIMPEZA') GROUP BY local;

-- 4b) Saldo dos lugares do P10
SELECT local, count(*) AS itens, round(sum(saldo), 3) AS soma
FROM est_saldo_local WHERE local LIKE 'P10\_%' GROUP BY local ORDER BY local;

-- 4c) O razao bate com o saldo nos lugares do P10 (esperado: 0 linhas)
SELECT s.local, p.nome, s.saldo, r.soma_razao
FROM est_saldo_local s
JOIN est_produtos p ON p.id = s.produto_id
LEFT JOIN (SELECT produto_id, local, sum(quantidade) AS soma_razao FROM est_movimentacoes
           WHERE local LIKE 'P10\_%' GROUP BY 1, 2) r ON r.produto_id = s.produto_id AND r.local = s.local
WHERE s.local LIKE 'P10\_%' AND abs(s.saldo - coalesce(r.soma_razao, 0)) > 0.001;
