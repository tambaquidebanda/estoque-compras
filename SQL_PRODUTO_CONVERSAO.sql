-- Adiciona conversão e perda no cadastro do produto
-- fator_conversao: quantas unidades de uso por unidade de compra (ex: 1 UN = 2 KG → fator 2)
-- perda: percentual de perda no processo (ex: 30 = 30% de perda, rendimento 70%)

ALTER TABLE est_produtos
  ADD COLUMN IF NOT EXISTS fator_conversao numeric DEFAULT 1,
  ADD COLUMN IF NOT EXISTS perda numeric DEFAULT 0;
