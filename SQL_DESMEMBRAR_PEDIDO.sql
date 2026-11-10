-- =====================================================================
-- SQL_DESMEMBRAR_PEDIDO.sql  (10/11/2026)
--
-- Pedido que o fornecedor divide em várias notas (AMBEV, Coca): no
-- recebimento, o estoquista marca "Esta nota é só uma parte do pedido" e
-- os itens daquela nota viram um pedido novo, #02021/1, #02021/2...
-- Cada parte é recebida e vai ao financeiro como um pedido comum (com a
-- sua NF, valor e vencimento). Antes, o compras tinha que criar um pedido
-- novo à mão para vincular a nota.
--
-- Esta função faz a separação tudo-ou-nada: se qualquer item falhar,
-- nada muda. Não mexe no estoque nem no financeiro.
--   p_pedido: o pedido aberto na tela (ex.: '#02021')
--   p_itens : [{"id": "<cmp_compras.id>", "qtd": 200}, ...] o que veio NESTA nota
-- Item que veio inteiro (qtd >= pedido) muda de pedido; item que veio em
-- parte é dividido: a parte nova leva a quantidade da nota e a linha
-- original fica no pedido com o que falta.
-- Devolve {"novo": "#02021/1", "mapa": {"<id antigo>": "<id novo>"}}.
--
-- Rodar ANTES do Push do código. Um bloco só.
-- =====================================================================

CREATE OR REPLACE FUNCTION cmp_desmembrar_pedido(p_pedido text, p_itens jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_base text := split_part(p_pedido, '/', 1);
  v_n    int;
  v_novo text;
  v_it   jsonb;
  v_row  cmp_compras%ROWTYPE;
  v_q    numeric;
  v_id   uuid;
  v_mapa jsonb := '{}'::jsonb;
BEGIN
  IF p_pedido IS NULL OR p_pedido !~ '^#[0-9]+(/[0-9]+)?$' THEN
    RAISE EXCEPTION 'Número de pedido inválido: %', p_pedido;
  END IF;
  IF jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Nenhum item para desmembrar';
  END IF;

  -- Trava: pedido que já tem algo no financeiro (adiantamento, rascunho ou
  -- lançamento) foi pago/lançado pelo valor inteiro: desmembrar mudaria isso.
  IF EXISTS (SELECT 1 FROM lancamentos WHERE numero_pedido = p_pedido)
     OR EXISTS (SELECT 1 FROM lancamentos_rascunho WHERE pedido_num = p_pedido)
     OR EXISTS (SELECT 1 FROM cmp_contas_pagar WHERE pedido_num = p_pedido
                  AND (lancamento_id IS NOT NULL OR adiantamento_lancamento_id IS NOT NULL)) THEN
    RAISE EXCEPTION 'O pedido % já está no financeiro (adiantamento ou lançamento): não dá para desmembrar. Receba normal ou fale com o compras.', p_pedido;
  END IF;

  -- Um desmembramento por vez no mesmo pedido (dois celulares ao mesmo tempo)
  PERFORM pg_advisory_xact_lock(hashtext('desmembrar ' || v_base));

  SELECT coalesce(max(nullif(split_part(pedido_num, '/', 2), '')::int), 0) + 1 INTO v_n
    FROM cmp_compras WHERE pedido_num LIKE v_base || '/%';
  v_novo := v_base || '/' || v_n;

  FOR v_it IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
    v_id := (v_it->>'id')::uuid;
    v_q  := (v_it->>'qtd')::numeric;
    IF v_q IS NULL OR v_q <= 0 THEN
      RAISE EXCEPTION 'Quantidade inválida no item %', v_id;
    END IF;
    SELECT * INTO v_row FROM cmp_compras
     WHERE id = v_id AND pedido_num = p_pedido AND status_receb = 'pendente'
     FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Um item não está mais pendente no pedido % (alguém recebeu agora?). Atualize a tela.', p_pedido;
    END IF;

    IF v_q < v_row.quantidade - 0.0001 THEN
      -- Veio parte: linha nova com a quantidade da nota; a original fica com o resto
      INSERT INTO cmp_compras
      SELECT * FROM jsonb_populate_record(NULL::cmp_compras,
               to_jsonb(v_row) || jsonb_build_object(
                 'id', gen_random_uuid(), 'pedido_num', v_novo, 'quantidade', v_q,
                 'total', round(v_q * coalesce(v_row.custo_unit, 0), 2), 'acrescimo', 0))
      RETURNING id INTO v_id;
      UPDATE cmp_compras
         SET quantidade = v_row.quantidade - v_q,
             total = round((v_row.quantidade - v_q) * coalesce(v_row.custo_unit, 0), 2)
       WHERE id = v_row.id;
      v_mapa := v_mapa || jsonb_build_object(v_row.id::text, v_id::text);
    ELSE
      -- Veio inteiro (ou a mais): a linha muda de pedido
      UPDATE cmp_compras SET pedido_num = v_novo, acrescimo = 0 WHERE id = v_row.id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('novo', v_novo, 'mapa', v_mapa);
END;
$$;

-- Conferência: deve listar a função.
SELECT proname, pg_get_function_arguments(oid) FROM pg_proc WHERE proname = 'cmp_desmembrar_pedido';
