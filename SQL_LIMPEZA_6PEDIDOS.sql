-- LIMPEZA dos recebimentos duplicados/fantasmas de 6 pedidos (o #00619 fica de fora, aguardando confirmacao).
-- Mantem o recebimento REAL de cada pedido, apaga o resto, e acerta valor da conta + rascunho da integracao.
-- NAO toca no financeiro (nenhum foi aprovado em lancamentos).
-- BLOCO DO = UMA unica instrucao (pode rodar direto).

DO $$
DECLARE
  ped   text;
  keep  uuid[];
  novo_valor numeric;
BEGIN
  FOR ped, keep IN
    SELECT * FROM (VALUES
      ('#00560', ARRAY['943e7363-7220-4bc7-989d-789c3ca6d7f5']::uuid[]),
      ('#00561', ARRAY['6d313a3f-1d59-4448-9fa1-f6f1a5dd0de6']::uuid[]),
      ('#00600', ARRAY['16c387fc-9c6f-41a3-a6c9-2a10a026b917']::uuid[]),
      ('#00659', ARRAY['18519e4a-4a74-4b9b-8481-2599e7ef5b32']::uuid[]),
      ('#00662', ARRAY['165dea4a-925b-4c4a-841d-a6c91dbe642d']::uuid[]),
      ('#00666', ARRAY['c7b7a947-1b6d-4d51-8b2e-04b00b1afff2']::uuid[])
    ) AS t(pedido, recebs)
  LOOP
    -- 0. repointa a conta a pagar para o recebimento mantido ANTES de apagar
    --    (senao o FK cmp_contas_pagar.recebimento_id -> cmp_recebimentos bloqueia o DELETE)
    UPDATE cmp_contas_pagar SET recebimento_id = keep[1] WHERE pedido_num = ped;
    -- 1. apaga itens dos recebimentos NAO mantidos
    DELETE FROM cmp_recebimento_itens
     WHERE recebimento_id IN (
       SELECT id FROM cmp_recebimentos WHERE pedido_num = ped AND NOT (id = ANY(keep))
     );
    -- 2. apaga os cabecalhos NAO mantidos
    DELETE FROM cmp_recebimentos WHERE pedido_num = ped AND NOT (id = ANY(keep));
    -- 3. valor real = soma dos cabecalhos que sobraram (os mantidos)
    SELECT COALESCE(SUM(total_recebido),0) INTO novo_valor
      FROM cmp_recebimentos WHERE pedido_num = ped;
    -- 4. ajusta o valor da conta a pagar (se existir)
    UPDATE cmp_contas_pagar
       SET valor = novo_valor
     WHERE pedido_num = ped;
    -- 5. ajusta o rascunho da integracao (se existir)
    UPDATE lancamentos_rascunho
       SET valor = GREATEST(0, novo_valor - COALESCE(acrescimo,0))
     WHERE pedido_num = ped;
    -- 6. recomputa a quantidade de cada item pela soma real do que sobrou nos recebimentos
    UPDATE cmp_compras c
       SET quantidade = COALESCE((
             SELECT SUM(ri.qtd_recebida) FROM cmp_recebimento_itens ri WHERE ri.compra_id = c.id
           ), c.quantidade)
     WHERE c.pedido_num = ped
       AND EXISTS (SELECT 1 FROM cmp_recebimento_itens ri WHERE ri.compra_id = c.id);
  END LOOP;
END $$;
