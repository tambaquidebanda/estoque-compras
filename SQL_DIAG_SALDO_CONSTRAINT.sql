-- ============================================================================
-- DIAGNÓSTICO DECISIVO: por que o recebimento não atualiza o Saldo
-- ----------------------------------------------------------------------------
-- Só-leitura. Rode as 4 partes no editor SQL do Supabase e me mande o resultado.
--
-- Hipótese: est_saldo_local tem PK surrogate (id) e UNIQUE(produto_id,local).
-- O recebimento usa upsert SEM onConflict -> tenta INSERT -> viola o UNIQUE ->
-- erro 23505 engolido em silencio -> saldo NAO muda (so funciona p/ produto novo).
-- ============================================================================

-- 1) Qual é a PRIMARY KEY e as UNIQUE constraints de est_saldo_local?
--    Se a PK for "id" e existir uma UNIQUE (produto_id, local) separada,
--    a hipótese está CONFIRMADA.
SELECT
  con.conname                         AS constraint_name,
  con.contype                         AS tipo,   -- 'p' = primary key, 'u' = unique
  pg_get_constraintdef(con.oid)       AS definicao
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'est_saldo_local'
ORDER BY con.contype DESC;

-- 2) Existem linhas DUPLICADAS de (produto_id, local)?
--    Se houver duplicatas, o display mostra "a última que veio", não a soma —
--    outro sintoma do upsert quebrado.
SELECT produto_id, local, count(*) AS linhas, sum(saldo) AS soma_saldo
FROM est_saldo_local
GROUP BY produto_id, local
HAVING count(*) > 1
ORDER BY linhas DESC
LIMIT 50;

-- 3) TESTE DE REALIDADE: para produtos recebidos nos últimos 30 dias,
--    compara a QTD total recebida x o saldo atual em ESTOQUE_LOJA.
--    Se o saldo está MUITO abaixo do recebido (e o produto não foi recontado),
--    o recebimento não somou.
WITH rec AS (
  SELECT
    trim(lower(translate(ri.produto,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nome_norm,
    sum(ri.qtd_recebida) AS qtd_recebida_30d
  FROM cmp_recebimento_itens ri
  JOIN cmp_recebimentos r ON r.id = ri.recebimento_id
  WHERE r.data_receb >= (CURRENT_DATE - INTERVAL '30 days')
    AND COALESCE(ri.qtd_recebida,0) > 0
  GROUP BY 1
),
prod AS (
  SELECT p.id, p.nome,
    trim(lower(translate(p.nome,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nome_norm
  FROM est_produtos p
)
SELECT
  pr.nome,
  rec.qtd_recebida_30d,
  COALESCE(sl.saldo, 0) AS saldo_loja_atual,
  CASE WHEN COALESCE(sl.saldo,0) < rec.qtd_recebida_30d * 0.5
       THEN '⚠️ saldo bem abaixo do recebido' ELSE '' END AS alerta
FROM rec
JOIN prod pr ON pr.nome_norm = rec.nome_norm
LEFT JOIN est_saldo_local sl ON sl.produto_id = pr.id AND sl.local = 'ESTOQUE_LOJA'
ORDER BY rec.qtd_recebida_30d DESC
LIMIT 60;

-- 4) Quantas linhas ESTOQUE_LOJA existem no total (referência de tamanho).
SELECT count(*) AS linhas_estoque_loja
FROM est_saldo_local WHERE local = 'ESTOQUE_LOJA';
