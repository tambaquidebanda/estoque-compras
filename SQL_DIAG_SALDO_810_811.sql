-- ============================================================================
-- DIAGNÓSTICO: pedidos #00810 e #00811 — por que alguns itens não entraram no saldo
-- Só-leitura. Rode no editor SQL do Supabase e me mande o resultado.
--
-- Teoria: produtos com NOME DUPLICADO em est_produtos. O recebimento grava o saldo
-- num produto_id, mas a tela de Saldo lê de OUTRO produto_id (o primeiro/ativo).
-- ============================================================================

-- Para cada produto cadastrado cujo nome bate com um item recebido nos pedidos
-- #00810/#00811, mostra TODOS os cadastros com aquele nome (duplicatas) e o saldo
-- ESTOQUE_LOJA de cada um. Se aparecer mais de uma linha por nome, é duplicata.
WITH alvo AS (
  SELECT DISTINCT
    trim(lower(translate(ri.produto,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nome_norm,
    ri.produto AS nome_no_recebimento,
    ri.qtd_recebida
  FROM cmp_recebimento_itens ri
  JOIN cmp_recebimentos r ON r.id = ri.recebimento_id
  WHERE r.pedido_num IN ('#00810','#00811','00810','00811')
),
prod AS (
  SELECT p.id, p.nome, p.ativo,
    trim(lower(translate(p.nome,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nome_norm
  FROM est_produtos p
)
SELECT
  a.nome_no_recebimento,
  a.qtd_recebida,
  pr.id            AS produto_id_cadastro,
  pr.nome          AS nome_cadastro,
  pr.ativo,
  sl.saldo         AS saldo_estoque_loja,
  count(*) OVER (PARTITION BY a.nome_norm) AS qtd_cadastros_com_esse_nome
FROM alvo a
JOIN prod pr ON pr.nome_norm = a.nome_norm
LEFT JOIN est_saldo_local sl ON sl.produto_id = pr.id AND sl.local = 'ESTOQUE_LOJA'
ORDER BY a.nome_no_recebimento, pr.ativo DESC, pr.id;
