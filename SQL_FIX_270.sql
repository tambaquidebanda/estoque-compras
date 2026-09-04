-- ═══════════════════════════════════════════════════════════════
-- FIX pedido #00270 — referência órfã de lançamento
-- ═══════════════════════════════════════════════════════════════
-- Problema: cmp_contas_pagar do #00270 aponta para lancamento_id
--   c83fa863-0289-400b-9fad-3cf92702ead8, que NÃO existe mais em
--   lancamentos (foi apagado). Por isso o estoque mostra "Financeiro"
--   mas o Contas a Pagar do financeiro não tem nada, e o pedido não
--   volta pra Integração.
-- Solução: limpar o lancamento_id órfão. O estoque volta a mostrar o
--   botão "Gerar Conta", e o usuário reenvia ao financeiro normalmente
--   (recria o lançamento com plano de contas/categoria/unidade corretos).

-- 1) CONFERE antes (deve mostrar 1 linha com lancamento_id preenchido)
SELECT pedido_num, lancamento_id, valor, vencimento, status
FROM cmp_contas_pagar
WHERE pedido_num = '#00270';

-- 2) CONFERE que o lançamento realmente não existe (deve retornar 0 linhas)
SELECT id FROM lancamentos
WHERE id = 'c83fa863-0289-400b-9fad-3cf92702ead8';

-- 3) LIMPA o vínculo órfão (só executa se 1 e 2 confirmaram o cenário)
UPDATE cmp_contas_pagar
SET lancamento_id = NULL
WHERE pedido_num = '#00270'
  AND lancamento_id = 'c83fa863-0289-400b-9fad-3cf92702ead8';

-- 4) CONFERE depois (lancamento_id deve estar NULL agora)
SELECT pedido_num, lancamento_id, valor, vencimento, status
FROM cmp_contas_pagar
WHERE pedido_num = '#00270';

-- Depois de rodar: no estoque (aba Compras), o #00270 volta a mostrar
-- o botão "Gerar Conta". Clique nele para reenviar ao financeiro.
