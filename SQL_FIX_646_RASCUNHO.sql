-- ============================================================================
-- FIX #00646 — remove o rascunho órfão que faz o pedido reaparecer na Integração
-- ----------------------------------------------------------------------------
-- Contexto: o #00646 já tem lançamento REAL e PAGO (id 7dde1ca6..., conciliado).
-- Mas sobrou um rascunho do adiantamento (24/07) que nunca foi apagado quando o
-- lançamento real foi gerado (30/07). A tela de Integração lista rascunhos, então
-- o pedido continua aparecendo lá. Remover só esse rascunho resolve.
-- ============================================================================

-- 1) CONFIRME o rascunho órfão (rode primeiro):
SELECT id, pedido_num, descricao, observacoes, valor, status, criado_em
FROM lancamentos_rascunho
WHERE id = 'c238f720-36ca-4fc6-bd58-024dc00acadd';

-- 2) Só depois de confirmar, DESCOMENTE a linha abaixo e rode.
--    (o lançamento real 7dde1ca6, pago e conciliado, NÃO é tocado)
-- DELETE FROM lancamentos_rascunho
-- WHERE id = 'c238f720-36ca-4fc6-bd58-024dc00acadd';

-- 3) Verificação pós-fix (deve voltar 0 linhas):
-- SELECT id FROM lancamentos_rascunho WHERE pedido_num = '#00646';
