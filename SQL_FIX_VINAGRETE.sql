-- CORRECAO: VINAGRETE se usava como proprio ingrediente + ingredientes inativos  -- 21/08/2026
--
-- 1) A ficha do produto VINAGRETE tinha VINAGRETE como ingrediente (0.1 Unidade de si mesma).
--    A cada recalculo o custo era multiplicado por 0.1 e caiu ate zero, levando junto PACU
--    ASSADO CANTOR e JARAQUI FRITO CANTOR, que usam VINAGRETE.
--    Aqui a linha passa a apontar para PPC VINAGRETE, a preparacao de verdade (R$ 8,15/Kg).
--    Quantidade adotada: 0.18 Kg - a porcao padrao da casa (21 das 33 fichas que usam
--    PPC VINAGRETE usam 0.18 Kg; 6 usam 0.36 para porcao dupla).
--    ATENCAO: a 0.18 Kg o vinagrete custa R$ 1,47 e o preco de venda dele e R$ 1,42.
--    Confirmar com a responsavel se a porcao vendida avulsa e menor que a que acompanha prato.
--
-- 2) MOQUECA DE PIRARUCU DELIVERY e PIRARUCU EMPANADO DELIVERY usam ingredientes INATIVOS
--    (SA CUBO DE PIRARUCU 140g e SA FILE DE PIRARUCU 80g) que o sistema ignorava no calculo.
--    Ja corrigido no codigo; aqui so o custo.
--
-- Rode DEPOIS de SQL_RECALC_CUSTOS.sql e DEPOIS do app.js corrigido estar publicado.


-- ===== PASSO 1 - CONFERIR ANTES (so leitura) =====

select p.nome as ficha, ing.nome as ingrediente, i.quantidade, i.unidade
  from est_ficha_ingredientes i
  join est_fichas_tecnicas f on f.id = i.ficha_id
  join est_produtos p on p.id = f.produto_id
  join est_produtos ing on ing.id = i.ingrediente_id
 where i.id = 'f3804ab4-c133-497f-b5dd-34ef3fc60be0';
-- Esperado: 1 linha, ficha VINAGRETE com ingrediente VINAGRETE, 0.1 Unidade.


-- ===== PASSO 2 - APLICAR =====

begin;

-- 2a) a ficha do VINAGRETE passa a usar a preparacao, nao a si mesma
update est_ficha_ingredientes set ingrediente_id = '2c1f942c-1411-427c-923a-0d16dec4983d', quantidade = 0.18, unidade = 'Kg' where id = 'f3804ab4-c133-497f-b5dd-34ef3fc60be0';

-- 2b) custos corrigidos
update est_fichas_tecnicas set custo_total = 13.974, custo_por_porcao = 13.974 where id = '5a887413-4745-4062-9f04-072dad014caf';
update est_produtos set custo_comp = 13.974 where id = 'd6ad1a56-d8a2-4b38-af4f-45ecd92725ff';  -- PACU ASSADO CANTOR
update est_fichas_tecnicas set custo_total = 7.4387, custo_por_porcao = 7.4387 where id = 'e543ae52-cf15-413f-be93-f7a590b5fd7f';
update est_produtos set custo_comp = 7.4387 where id = '6f977792-d9d2-4eac-a4f0-93f74d52015b';  -- JARAQUI FRITO CANTOR
update est_fichas_tecnicas set custo_total = 1.4676, custo_por_porcao = 1.4676 where id = '71a9204f-4d05-4d16-9bc1-11672a9ae65f';
update est_produtos set custo_comp = 1.4676 where id = 'bfeca2d7-22d3-4f12-af89-1bf92473ae81';  -- VINAGRETE
update est_fichas_tecnicas set custo_total = 10.9964, custo_por_porcao = 10.9964 where id = '932ae309-3e7c-44f3-83e5-247e5014bbb1';
update est_produtos set custo_comp = 10.9964 where id = 'e65ab5bc-a1ae-4c9f-b3c4-f10eb93452e0';  -- MOQUECA DE PIRARUCU DELIVERY
update est_fichas_tecnicas set custo_total = 6.7696, custo_por_porcao = 6.7696 where id = '55f3d551-eb12-46ae-b748-98d8d92a4692';
update est_produtos set custo_comp = 6.7696 where id = '9c0b38ac-32ab-4c33-848c-f70c3a89e70c';  -- PIRARUCU EMPANADO DELIVERY

commit;


-- ===== VARIANTE - se a porcao avulsa for menor =====
-- Para 0.10 Kg (custo R$ 0,82), troque a linha 2a por:
-- update est_ficha_ingredientes set ingrediente_id = '2c1f942c-1411-427c-923a-0d16dec4983d', quantidade = 0.10, unidade = 'Kg' where id = 'f3804ab4-c133-497f-b5dd-34ef3fc60be0';
-- e me avise para eu regerar os custos do bloco 2b.


-- ===== OPCIONAL - decidir com a responsavel =====
-- Os dois SA abaixo estao INATIVOS mas ainda sao ingredientes de pratos ativos de delivery.
-- update est_produtos set ativo = true where id = 'ffca3678-28c7-43ed-a1cd-d7345f361812';  -- SA CUBO DE PIRARUCU 140g
-- update est_produtos set ativo = true where id = '3afef0e8-a2cd-4fed-b95e-751c565476ae';  -- SA FILE DE PIRARUCU 80g
