-- Diagnostico: o que sobreviveu de Pedido Padrao no banco (chave 'padroes').
-- Mostra quantos produtos tem padrao configurado, agrupados por SETOR|GRUPO,
-- pra voce ver quais grupos ficaram vazios e so reentrar o que faltou.
-- UMA unica instrucao (read-only, nao altera nada).

WITH p AS (
  SELECT key AS chave_prod, value AS dias
  FROM inv_configuracoes, jsonb_each(valor)
  WHERE chave = 'padroes'
)
SELECT split_part(chave_prod, '|', 1) AS setor,
       split_part(chave_prod, '|', 2) AS grupo,
       COUNT(*)                       AS produtos_com_padrao
FROM p
GROUP BY 1, 2
ORDER BY 1, 2;
