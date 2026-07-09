-- Corrige a quantidade do pedido 00416 para a que foi realmente recebida (300).
-- O custo_unit ja esta em precisao real (3.1899), entao 300 x 3.1899 = 956.97, bate com o total.
UPDATE cmp_compras
SET quantidade = 300
WHERE pedido_num ILIKE '%00416%'
  AND produto ILIKE '%BANDEJA 4 DIVISORIAS%';
