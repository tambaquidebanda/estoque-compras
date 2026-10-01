-- ============================================================================
-- PEDIDO #01549 (AMBEV, 250 L chopp, R$ 3.325) -> BONIFICADO   (01/10/2026)
--
-- O recebimento de 25/09 16:35 (Ricardo, celular) gravou o chopp SEM a marca
-- de bonificado. Por isso nasceu conta a pagar de R$ 3.325 e o rascunho
-- na integracao (card Aprovar/Rejeitar). Fica igual ao #01409 (chopp so,
-- bonificado): conta com valor 0, sem rascunho, sem lancamento.
-- O estoque NAO muda (bonificado entra no estoque com o valor real).
-- ============================================================================

-- PASSO 1 (so leitura)
SELECT 'compra' k, bonificado::text v, total::text x FROM cmp_compras WHERE pedido_num = '#01549'
UNION ALL SELECT 'conta', status, valor::text || ' lanc=' || coalesce(lancamento_id::text,'-') FROM cmp_contas_pagar WHERE pedido_num = '#01549'
UNION ALL SELECT 'rascunho', status, valor::text FROM lancamentos_rascunho WHERE pedido_num = '#01549';

-- PASSO 2
BEGIN;

CREATE TABLE bkp_fix01549_rascunho AS SELECT * FROM lancamentos_rascunho WHERE pedido_num = '#01549';
CREATE TABLE bkp_fix01549_conta    AS SELECT * FROM cmp_contas_pagar     WHERE pedido_num = '#01549';
CREATE TABLE bkp_fix01549_receb    AS SELECT * FROM cmp_recebimentos     WHERE pedido_num = '#01549';
ALTER TABLE bkp_fix01549_rascunho ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_fix01549_conta    ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_fix01549_receb    ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF (SELECT count(*) FROM lancamentos_rascunho WHERE pedido_num = '#01549' AND status = 'pendente') <> 1 THEN
    RAISE EXCEPTION 'Rascunho do #01549 nao esta mais pendente (alguem aprovou ou rejeitou)';
  END IF;
  IF EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = '#01549' AND lancamento_id IS NOT NULL) THEN
    RAISE EXCEPTION 'O #01549 ja virou lancamento no financeiro';
  END IF;
  IF (SELECT count(*) FROM cmp_compras WHERE pedido_num = '#01549') <> 1 THEN
    RAISE EXCEPTION 'O #01549 deveria ter 1 item so';
  END IF;
END $$;

UPDATE cmp_compras SET bonificado = true WHERE pedido_num = '#01549';
UPDATE cmp_recebimento_itens SET bonificado = true
 WHERE recebimento_id IN (SELECT id FROM cmp_recebimentos WHERE pedido_num = '#01549');
UPDATE cmp_recebimentos SET total_recebido = 0 WHERE pedido_num = '#01549';
UPDATE cmp_contas_pagar SET valor = 0 WHERE pedido_num = '#01549';
DELETE FROM lancamentos_rascunho WHERE pedido_num = '#01549';

COMMIT;

-- PASSO 3 (conferencia)
SELECT 'compra' k, bonificado::text v, total::text x FROM cmp_compras WHERE pedido_num = '#01549'
UNION ALL SELECT 'conta', status, valor::text FROM cmp_contas_pagar WHERE pedido_num = '#01549'
UNION ALL SELECT 'rascunhos', count(*)::text, '' FROM lancamentos_rascunho WHERE pedido_num = '#01549';
