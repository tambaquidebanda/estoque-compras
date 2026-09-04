-- ============================================================================
-- DIAGNÓSTICO: recebimentos que NÃO entraram no Saldo de Estoque
-- ----------------------------------------------------------------------------
-- Só-leitura. Rode no editor SQL do Supabase.
--
-- Contexto: no recebimento, o sistema soma a mercadoria no saldo (ESTOQUE_LOJA)
-- casando o NOME do item recebido (cmp_recebimento_itens.produto, texto livre)
-- com est_produtos.nome (normalizado: minúsculo, sem acento, sem espaço nas bordas).
-- cmp_compras/cmp_recebimento_itens NÃO guardam produto_id — então, se o nome
-- não bate exatamente, o saldo é pulado SEM aviso. Este script mostra os itens
-- que ficaram de fora.
-- ============================================================================

-- Normalização equivalente à do app (lower + remove acentos + trim).
WITH norm AS (
  SELECT
    ri.id,
    ri.recebimento_id,
    ri.produto,
    ri.qtd_recebida,
    r.data_receb,
    r.pedido_num,
    r.fornecedor,
    trim(lower(translate(ri.produto,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nome_norm
  FROM cmp_recebimento_itens ri
  JOIN cmp_recebimentos r ON r.id = ri.recebimento_id
  WHERE r.data_receb >= (CURRENT_DATE - INTERVAL '60 days')
    AND COALESCE(ri.qtd_recebida, 0) > 0
),
prod AS (
  SELECT
    p.id,
    p.nome,
    trim(lower(translate(p.nome,
      'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
      'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'))) AS nome_norm
  FROM est_produtos p
)
SELECT
  CASE WHEN pr.id IS NULL THEN '❌ SEM MATCH (não entrou no saldo)'
       ELSE '✅ casou' END                       AS situacao,
  n.data_receb,
  n.pedido_num,
  n.fornecedor,
  n.produto                                       AS nome_no_recebimento,
  pr.nome                                         AS nome_no_cadastro,
  n.qtd_recebida,
  sl.saldo                                        AS saldo_estoque_loja_atual
FROM norm n
LEFT JOIN prod pr ON pr.nome_norm = n.nome_norm
LEFT JOIN est_saldo_local sl
       ON sl.produto_id = pr.id AND sl.local = 'ESTOQUE_LOJA'
ORDER BY situacao, n.data_receb DESC, n.produto;

-- ----------------------------------------------------------------------------
-- Resumo rápido: quantos itens (e qtd) ficaram sem match nos últimos 60 dias
-- ----------------------------------------------------------------------------
-- Descomente para ver só o total:
--
-- WITH ... (repita os CTEs acima) ...
-- SELECT count(*) FILTER (WHERE pr.id IS NULL) AS itens_sem_match,
--        count(*)                              AS itens_total
-- FROM norm n LEFT JOIN prod pr ON pr.nome_norm = n.nome_norm;
