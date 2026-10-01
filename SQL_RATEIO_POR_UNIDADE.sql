-- ============================================================================
-- RATEIO POR UNIDADE (01/10/2026)
--
-- Pedido conjunto (ex.: um boleto com itens do Centro e do Delivery P10) virava
-- conta a pagar com UMA unidade so, a do primeiro item. A DRE por unidade ficava
-- errada. Agora cada linha do rateio carrega a sua unidade:
--   rascunho_rateio_itens.unidade_id  (o estoque grava)
--   rateio_itens.unidade_id           (o financeiro copia ao aprovar; a DRE le)
-- Vazio = usa a unidade do lancamento, como sempre foi (nada antigo muda).
--
-- E o item recebido guarda onde entrou no estoque:
--   cmp_recebimento_itens.local  (item do Delivery P10 entra no ESTOQUE DELIVERY;
--   o estorno do recebimento desfaz no mesmo lugar). Vazio = o local do cabecalho
--   (cmp_recebimentos.local), como sempre foi.
--
-- So ACRESCENTA colunas que podem ficar vazias. Nao apaga, nao altera nada.
-- RODAR ANTES do Push do codigo.
-- ============================================================================

-- PASSO 1 (so leitura): as colunas ainda nao existem?
SELECT table_name, column_name
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND ((table_name IN ('rascunho_rateio_itens','rateio_itens') AND column_name = 'unidade_id')
     OR (table_name = 'cmp_recebimento_itens' AND column_name = 'local'));

-- PASSO 2
ALTER TABLE rascunho_rateio_itens ADD COLUMN IF NOT EXISTS unidade_id uuid REFERENCES unidades(id);
ALTER TABLE rateio_itens          ADD COLUMN IF NOT EXISTS unidade_id uuid REFERENCES unidades(id);
ALTER TABLE cmp_recebimento_itens ADD COLUMN IF NOT EXISTS local text;

-- PASSO 3 (conferencia): tem que aparecer 3 linhas
SELECT table_name, column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND ((table_name IN ('rascunho_rateio_itens','rateio_itens') AND column_name = 'unidade_id')
     OR (table_name = 'cmp_recebimento_itens' AND column_name = 'local'))
 ORDER BY 1;
