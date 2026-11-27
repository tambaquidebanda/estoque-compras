-- ============================================================================
-- MARCAS AUTORIZADAS (27/11/2026)
--
-- Um produto (ex.: MP CACHAÇA TRADICIONAL) pode ser comprado de várias marcas, e cada
-- marca pode vir num tamanho diferente (Ypioca 965 ml, Brazuka 700 ml). O pedido grava a
-- marca e o tamanho daquela compra; o recebimento converte para a unidade de uso com o
-- tamanho da marca, e o custo do cadastro fica sempre no tamanho padrão do produto.
--
--   est_produtos.marcas            [{"nome": "Brazuka", "fator": 0.7}, ...]  (fator null = o do produto)
--   cmp_compras.marca/fator_marca  a marca escolhida no pedido e o tamanho dela
--   cmp_recebimento_itens.marca/fator_marca   cópia, para estorno e devolução
--   cmp_devolucao_itens.fator_marca           cópia, para cancelar/substituir a devolução
--
-- Só cria colunas (nada é apagado). Rodar duas vezes não faz mal.
-- Depois de rodar: recarregar o sistema (Cmd+Shift+R).
-- ============================================================================

BEGIN;

ALTER TABLE est_produtos          ADD COLUMN IF NOT EXISTS marcas jsonb;
ALTER TABLE cmp_compras           ADD COLUMN IF NOT EXISTS marca text;
ALTER TABLE cmp_compras           ADD COLUMN IF NOT EXISTS fator_marca numeric;
ALTER TABLE cmp_recebimento_itens ADD COLUMN IF NOT EXISTS marca text;
ALTER TABLE cmp_recebimento_itens ADD COLUMN IF NOT EXISTS fator_marca numeric;
ALTER TABLE cmp_devolucao_itens   ADD COLUMN IF NOT EXISTS fator_marca numeric;

-- Cachaça tradicional já nasce com as 3 marcas (pelo id, não pelo nome)
UPDATE est_produtos
   SET marcas = '[{"nome": "Brazuka", "fator": 0.7}, {"nome": "Cabaré", "fator": 0.7}, {"nome": "Ypioca", "fator": 0.965}]'::jsonb
 WHERE id = '6be0008d-6e8d-4420-a49f-917170bcd16a'
   AND marcas IS NULL;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Conferência (só leitura)
SELECT table_name, column_name, data_type
  FROM information_schema.columns
 WHERE (table_name, column_name) IN (('est_produtos', 'marcas'), ('cmp_compras', 'marca'), ('cmp_compras', 'fator_marca'),
                                     ('cmp_recebimento_itens', 'marca'), ('cmp_recebimento_itens', 'fator_marca'),
                                     ('cmp_devolucao_itens', 'fator_marca'))
UNION ALL
SELECT 'est_produtos', nome, marcas::text FROM est_produtos WHERE id = '6be0008d-6e8d-4420-a49f-917170bcd16a'
 ORDER BY 1, 2;
