-- LIMPEZA: cadeia morta do recheio de pirarucu seco  --  21/08/2026
--
-- Confirmado pelo Wagner: bolinho e pastel usam o PPP RECHEIO DE PIRARUCU FRESCO 1,5KG.
-- A versao com pirarucu seco ficou sem uso:
--
--   PPP RECHEIO DE PIRARUCU 1,5KG
--       -> so alimenta SA BOLINHO DE PIRARUCU 5 UNID, um produto INATIVO (receita antiga)
--   PPP PIRARUCU SECO E FRESCO DESFIADO 1KG
--       -> so alimenta o recheio acima
--
-- Conferido antes: as duas nao tem saldo, nao tem NENHUMA movimentacao, nao estao na
-- estrutura de contagem e nao estao no mapeamento do PDV. Desativar nao afeta estoque,
-- financeiro nem a baixa automatica.
--
-- Desativa (ativo = false), nao apaga: o historico e as fichas continuam consultaveis
-- e da para reverter a qualquer momento com o bloco do fim.


-- ===== PASSO 1 - CONFERIR ANTES (so leitura) =====

select p.nome, p.tipo, p.ativo as produto_ativo, f.ativo as ficha_ativa, f.custo_total
  from est_produtos p
  left join est_fichas_tecnicas f on f.produto_id = p.id and f.ativo
 where p.id in ('c59f59ed-29c0-4246-9832-3d037a6d776c',
                'a7934475-8361-4f73-a4a5-25217b9ead03');

-- Esperado: 2 linhas, as duas com produto_ativo = true e ficha_ativa = true.


-- ===== PASSO 2 - APLICAR (selecione do begin ao commit) =====

begin;

update est_fichas_tecnicas set ativo = false
 where produto_id in ('c59f59ed-29c0-4246-9832-3d037a6d776c',
                      'a7934475-8361-4f73-a4a5-25217b9ead03');

update est_produtos set ativo = false
 where id in ('c59f59ed-29c0-4246-9832-3d037a6d776c',
              'a7934475-8361-4f73-a4a5-25217b9ead03');

commit;


-- ===== PASSO 3 - CONFERIR DEPOIS =====
-- Rode o PASSO 1 de novo: as duas colunas de ativo devem estar false
-- (ficha_ativa vem nula, porque o join so pega ficha ativa).


-- ===== REVERTER, se precisar =====
-- begin;
-- update est_produtos set ativo = true
--  where id in ('c59f59ed-29c0-4246-9832-3d037a6d776c','a7934475-8361-4f73-a4a5-25217b9ead03');
-- update est_fichas_tecnicas set ativo = true
--  where produto_id in ('c59f59ed-29c0-4246-9832-3d037a6d776c','a7934475-8361-4f73-a4a5-25217b9ead03')
--    and id in ('151ba4b7-440e-488d-a995-abd3090ec044','597d2cd3-9e89-483a-826c-f6b490092cd1');
-- commit;
