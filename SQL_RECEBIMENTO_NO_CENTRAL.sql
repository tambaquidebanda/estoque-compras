-- ==============================================================
-- RECEBIMENTO NO ESTOQUE CENTRAL
--
-- Hoje todo recebimento credita o ESTOQUE_LOJA, chumbado no codigo
-- em 4 lugares. A nota do Estoque Central vem direto para la e vai
-- passar a ser recebida la tambem, entao o recebimento precisa
-- guardar ONDE entrou.
--
-- Nao basta decidir na hora de receber: o estorno
-- (devolverPedidoAoEstoque) tem de desfazer no MESMO lugar, senao
-- credita num lugar e debita no outro e nasce estoque fantasma nos
-- dois. Por isso o lugar fica gravado na linha do recebimento.
--
-- Esta mudanca e ADITIVA: uma coluna nova com default igual ao
-- comportamento de hoje. Nenhuma linha existente muda de valor e
-- nenhuma tela antiga quebra. Nao precisa de backup de tabela: o
-- desfazer e uma linha so, no fim do arquivo.
-- ==============================================================


-- ---------------------------------------------------------------
-- PASSO 1 - SO LEITURA. Confere o estado antes de mexer.
-- ---------------------------------------------------------------
SELECT
  count(*)                                             AS recebimentos_no_total,
  min(data_receb)                                      AS primeiro,
  max(data_receb)                                      AS ultimo,
  (SELECT count(*) FROM information_schema.columns
     WHERE table_name = 'cmp_recebimentos'
       AND column_name = 'local')                      AS coluna_local_ja_existe
FROM cmp_recebimentos;


-- ---------------------------------------------------------------
-- PASSO 2 - A COLUNA. Default = o que o sistema ja faz hoje.
-- ---------------------------------------------------------------
ALTER TABLE cmp_recebimentos
  ADD COLUMN IF NOT EXISTS local text NOT NULL DEFAULT 'ESTOQUE_LOJA';

COMMENT ON COLUMN cmp_recebimentos.local IS
  'Onde a mercadoria entrou no razao: ESTOQUE_LOJA (deposito da loja) ou CENTRAL (Estoque Central). O estorno le esta coluna para desfazer no mesmo lugar.';


-- ---------------------------------------------------------------
-- PASSO 3 - CONFERENCIA. Todo historico tem de continuar na loja.
-- ---------------------------------------------------------------
SELECT
  local,
  count(*)        AS recebimentos,
  min(data_receb) AS primeiro,
  max(data_receb) AS ultimo,
  CASE
    WHEN local = 'ESTOQUE_LOJA' THEN 'OK - historico preservado'
    ELSE 'ATENCAO - nenhuma linha antiga deveria estar aqui'
  END AS veredito
FROM cmp_recebimentos
GROUP BY local
ORDER BY recebimentos DESC;


-- ---------------------------------------------------------------
-- DESFAZER (so se precisar):
-- ALTER TABLE cmp_recebimentos DROP COLUMN local;
-- ---------------------------------------------------------------
