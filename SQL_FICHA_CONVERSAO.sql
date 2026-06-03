-- Adiciona perda (%) e fator de conversão nos ingredientes da ficha técnica
-- perda: percentual de perda no processo (ex: 30 = 30% de perda, rendimento 70%)
-- fator_conversao: quantas unidades de uso por unidade de compra (ex: 1 UN = 2 KG → fator 2)

ALTER TABLE est_ficha_ingredientes
  ADD COLUMN IF NOT EXISTS perda numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fator_conversao numeric DEFAULT 1;
