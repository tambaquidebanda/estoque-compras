-- SQL_PUDIM_VINCULO_PDV.sql — liga os 3 pudins do iComanda aos 3 cadastros certos
--
-- Antes: os ids 124, 2770 e 2788 do iComanda caíam TODOS num cadastro só (grupo IFOOD),
-- herança da importação de junho, que casou pelo nome. Em 25/11 o Wagner separou no
-- iComanda e no Estoque:
--   124  PUDIM DE LEITE (Sobremesas Bar, salão)          -> PUDIM DE LEITE
--   2788 PUDIM DE LEITE DELIVERY (IFOOD)                 -> PUDIM DE LEITE DELIVERY
--   2770 PUDIM DE LEITE DELIVERY C/ DESCONTO (IFOOD)     -> PUDIM DE LEITE DELIVERY C/ DESCONTO
--
-- O cadastro de destino é achado pelo nome EXATO, e o PASSO 2 só grava se cada nome
-- existir em UM produto de venda ativo (senão para sem gravar nada).
-- Muda só o pdv_map. Vale para as vendas daqui para frente; as já baixadas ficam onde estão.

-- ═══ PASSO 1 — CONFERIR (só leitura) ═══════════════════════════════════════════════
-- Esperado: cadastros_com_esse_nome = 1 nas 3 linhas.
WITH alvo(icomanda_produto_id, nome_cadastro) AS (VALUES
  (124,  'PUDIM DE LEITE'),
  (2788, 'PUDIM DE LEITE DELIVERY'),
  (2770, 'PUDIM DE LEITE DELIVERY C/ DESCONTO')
)
SELECT a.icomanda_produto_id, a.nome_cadastro AS vai_ligar_em,
       (SELECT count(*) FROM est_produtos p
         WHERE upper(trim(p.nome)) = upper(a.nome_cadastro) AND p.tipo = 'VENDA' AND p.ativo) AS cadastros_com_esse_nome,
       (SELECT string_agg(coalesce(p.categoria, 'sem grupo') || ' · R$ ' || coalesce(p.preco_venda, 0), ', ')
          FROM est_produtos p
         WHERE upper(trim(p.nome)) = upper(a.nome_cadastro) AND p.tipo = 'VENDA' AND p.ativo) AS grupo_e_preco,
       m.icomanda_nome, m.status, hoje.nome AS ligado_hoje_a
FROM alvo a
LEFT JOIN pdv_map m ON m.icomanda_produto_id = a.icomanda_produto_id
LEFT JOIN est_produtos hoje ON hoje.id = m.produto_id
ORDER BY a.icomanda_produto_id;

-- ═══ PASSO 2 — GRAVAR ══════════════════════════════════════════════════════════════
DO $$
DECLARE
  r record;
  n int;
  pid uuid;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      (124,  'PUDIM DE LEITE'),
      (2788, 'PUDIM DE LEITE DELIVERY'),
      (2770, 'PUDIM DE LEITE DELIVERY C/ DESCONTO')
    ) AS t(icomanda_produto_id, nome_cadastro)
  LOOP
    SELECT count(*), min(p.id::text)::uuid INTO n, pid
      FROM est_produtos p
     WHERE upper(trim(p.nome)) = upper(r.nome_cadastro) AND p.tipo = 'VENDA' AND p.ativo;
    IF n <> 1 THEN
      RAISE EXCEPTION 'Nada gravado: "%" existe em % produtos de venda ativos (precisa ser 1).', r.nome_cadastro, n;
    END IF;

    UPDATE pdv_map
       SET produto_id = pid, status = 'mapeado', atualizado_em = now()
     WHERE icomanda_produto_id = r.icomanda_produto_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Nada gravado: o id % do iComanda não está no mapeamento do PDV.', r.icomanda_produto_id;
    END IF;
  END LOOP;
END $$;

-- ═══ PASSO 3 — CONFERIR DEPOIS (só leitura) ═════════════════════════════════════════
SELECT m.icomanda_produto_id, m.icomanda_nome, m.status, p.nome AS cadastro, p.categoria AS grupo, p.preco_venda
FROM pdv_map m
LEFT JOIN est_produtos p ON p.id = m.produto_id
WHERE m.icomanda_produto_id IN (124, 2770, 2788)
ORDER BY m.icomanda_produto_id;
