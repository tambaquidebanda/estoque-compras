-- =====================================================================
-- SQL_TAMBAQUI_CADASTRO_UNICO.sql   (26/10/2026)
--
-- O tambaqui estava em DOIS cadastros:
--   MP TAMBAQUI DE BANDA (3KG)  -> compra, recebimento, Central, Producao,
--                                  Estoque Delivery e, desde 09/10, a
--                                  contagem das churrasqueiras (pelo "+").
--   MP BANDA DE TAMBAQUI        -> as 21 fichas (venda). Sem compra nunca,
--                                  sem contagem nem pedido desde 08/10:
--                                  o saldo dele (loja 68, churrasqueira 82)
--                                  esta parado desde 08/10.
--
-- Fica UM so: o cadastro do (3KG), que tem o historico de compra e o
-- saldo de verdade, com o nome novo MP TAMBAQUI DE BANDA
-- (1 unidade de compra = 1 peixe = 2 bandas, como ja esta).
--
-- O que este SQL faz:
--   1) As 21 fichas passam a usar o cadastro que fica.
--   2) O saldo parado do MP BANDA DE TAMBAQUI sai (com registro no razao).
--   3) Pedidos internos ainda abertos e compras pendentes passam para o
--      cadastro que fica.
--   4) Nome novo no cadastro que fica; MP BANDA DE TAMBAQUI fica inativo.
--   5) Listas de contagem, "+", padroes e excluidos: troca o nome nas
--      5 listas e nos 2 padroes, sem mexer em mais nada.
-- Nao mexe em compra recebida, financeiro nem no saldo do (3KG).
--
-- Rode quando ninguem estiver contando. Um PASSO de cada vez.
-- =====================================================================


-- =====================================================================
-- PASSO 1 - SO LEITURA. Confira com o esperado.
-- =====================================================================

-- (a) saldos. Esperado (pode ter mudado com a contagem da noite):
--     BANDA: ESTOQUE_LOJA 68, CHURRASQUEIRA 82
--     3KG:   ESTOQUE_LOJA 96, CHURRASQUEIRA 80, ESTOQUE DELIVERY 228, P10_CHURRASQUEIRA 17
SELECT p.nome, s.local, s.saldo, s.updated_at
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('9a329d38-02b6-4aef-8eee-623f275e81d7',   -- MP BANDA DE TAMBAQUI (sai)
                        '63c674c1-2110-4ee1-98d6-d25fac740e50')   -- MP TAMBAQUI DE BANDA (3KG) (fica)
   AND s.saldo <> 0
 ORDER BY p.nome, s.local;

-- (b) fichas. Esperado: banda 21, kg3 0
SELECT count(*) FILTER (WHERE ingrediente_id = '9a329d38-02b6-4aef-8eee-623f275e81d7') AS banda,
       count(*) FILTER (WHERE ingrediente_id = '63c674c1-2110-4ee1-98d6-d25fac740e50') AS kg3
  FROM est_ficha_ingredientes;

-- (c) nome novo ainda nao existe. Esperado: 0
SELECT count(*) AS ja_existe FROM est_produtos WHERE nome = 'MP TAMBAQUI DE BANDA';

-- (d) onde os nomes aparecem nas listas. Esperado: 5 listas
SELECT u.key AS unidade, s.key AS setor, g.key AS grupo
  FROM inv_configuracoes c,
       jsonb_each(c.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g
 WHERE c.chave = 'estrutura'
   AND jsonb_typeof(g.value) = 'array'
   AND (g.value ? 'MP BANDA DE TAMBAQUI' OR g.value ? 'MP TAMBAQUI DE BANDA (3KG)');


-- =====================================================================
-- PASSO 2 - COPIA DE SEGURANCA (cria 3 tabelas bkp_; nao muda nada)
-- =====================================================================
CREATE TABLE IF NOT EXISTS bkp_tambaqui_20261026_config AS
  SELECT chave, valor, now() AS copiado_em FROM inv_configuracoes
   WHERE chave IN ('estrutura', 'adicoes', 'padroes', 'excluidos');

CREATE TABLE IF NOT EXISTS bkp_tambaqui_20261026_saldo AS
  SELECT * FROM est_saldo_local
   WHERE produto_id IN ('9a329d38-02b6-4aef-8eee-623f275e81d7', '63c674c1-2110-4ee1-98d6-d25fac740e50');

CREATE TABLE IF NOT EXISTS bkp_tambaqui_20261026_fichas AS
  SELECT * FROM est_ficha_ingredientes
   WHERE ingrediente_id = '9a329d38-02b6-4aef-8eee-623f275e81d7';

-- Esperado: 4, 6 (ou perto), 21
SELECT (SELECT count(*) FROM bkp_tambaqui_20261026_config) AS config,
       (SELECT count(*) FROM bkp_tambaqui_20261026_saldo)  AS saldo,
       (SELECT count(*) FROM bkp_tambaqui_20261026_fichas) AS fichas;


-- =====================================================================
-- PASSO 3 - UNIFICA (tudo ou nada; se algo nao bater, para sem mudar nada)
-- =====================================================================
BEGIN;

DO $$
DECLARE
  fica   constant uuid := '63c674c1-2110-4ee1-98d6-d25fac740e50';   -- (3KG), fica
  sai    constant uuid := '9a329d38-02b6-4aef-8eee-623f275e81d7';   -- MP BANDA DE TAMBAQUI, sai
  nb     constant text := 'MP BANDA DE TAMBAQUI';
  n3     constant text := 'MP TAMBAQUI DE BANDA (3KG)';
  novo   constant text := 'MP TAMBAQUI DE BANDA';
  hoje   date := (now() AT TIME ZONE 'America/Manaus')::date;
  r      record;
  est    jsonb;  ad jsonb;  pad jsonb;  exc jsonb;
  u text; s text; g text; k text; nk text;
  arr jsonb; narr jsonb;
  n int;
BEGIN
  IF EXISTS (SELECT 1 FROM est_produtos WHERE nome = novo) THEN
    RAISE EXCEPTION 'Ja existe produto com o nome %. Nada foi alterado.', novo;
  END IF;

  -- 1) fichas
  UPDATE est_ficha_ingredientes SET ingrediente_id = fica WHERE ingrediente_id = sai;
  GET DIAGNOSTICS n = ROW_COUNT;
  RAISE NOTICE 'Fichas: % linhas passaram para o cadastro que fica', n;

  -- 2) saldo parado do cadastro que sai
  FOR r IN SELECT local, saldo FROM est_saldo_local WHERE produto_id = sai LOOP
    IF r.saldo <> 0 THEN
      INSERT INTO est_movimentacoes (produto_id, local, tipo, quantidade, motivo, origem, responsavel, data)
      VALUES (sai, r.local, 'ajuste', -r.saldo,
              'Unificacao do tambaqui: MP BANDA DE TAMBAQUI sem contagem desde 08/10 (a contagem passou para o 3KG em 09/10); saldo parado sai',
              'ajuste', 'SQL tambaqui cadastro unico', hoje);
      RAISE NOTICE 'Saldo parado %: % sai', r.local, r.saldo;
    END IF;
  END LOOP;
  DELETE FROM est_saldo_local WHERE produto_id = sai;

  -- 3) pedidos internos abertos e compras pendentes
  UPDATE pedidos_internos_itens i SET produto_id = fica, nome = novo
    FROM pedidos_internos p
   WHERE p.id = i.pedido_id AND p.status IN ('pendente', 'liberado')
     AND i.produto_id IN (sai, fica);
  GET DIAGNOSTICS n = ROW_COUNT;
  RAISE NOTICE 'Pedidos internos abertos: % itens', n;

  UPDATE cmp_compras SET produto = novo
   WHERE produto_id = fica AND status_receb = 'pendente';
  GET DIAGNOSTICS n = ROW_COUNT;
  RAISE NOTICE 'Compras pendentes: % itens com o nome novo', n;

  -- 4) cadastro
  UPDATE est_produtos SET nome = novo WHERE id = fica;
  UPDATE est_produtos SET ativo = false WHERE id = sai;

  -- 5a) listas (estrutura): troca o nome, mesma posicao, mesmo tamanho
  SELECT valor INTO est FROM inv_configuracoes WHERE chave = 'estrutura' FOR UPDATE;
  n := 0;
  FOR u IN SELECT jsonb_object_keys(est) LOOP
    IF jsonb_typeof(est -> u) <> 'object' THEN CONTINUE; END IF;
    FOR s IN SELECT jsonb_object_keys(est -> u) LOOP
      IF jsonb_typeof(est -> u -> s) <> 'object' THEN CONTINUE; END IF;
      FOR g IN SELECT jsonb_object_keys(est -> u -> s) LOOP
        arr := est -> u -> s -> g;
        IF jsonb_typeof(arr) <> 'array' OR NOT (arr ? nb OR arr ? n3) THEN CONTINUE; END IF;
        IF (arr ? nb AND arr ? n3) OR arr ? novo THEN
          RAISE EXCEPTION 'Lista % > % > % tem os dois nomes. Nada foi alterado.', u, s, g;
        END IF;
        SELECT jsonb_agg(CASE WHEN e IN (nb, n3) THEN to_jsonb(novo) ELSE to_jsonb(e) END ORDER BY i)
          INTO narr FROM jsonb_array_elements_text(arr) WITH ORDINALITY t(e, i);
        IF jsonb_array_length(narr) <> jsonb_array_length(arr) THEN
          RAISE EXCEPTION 'Lista % > % > % mudaria de tamanho. Nada foi alterado.', u, s, g;
        END IF;
        est := jsonb_set(est, ARRAY[u, s, g], narr);
        n := n + 1;
        RAISE NOTICE 'Lista % > % > %', u, s, g;
      END LOOP;
    END LOOP;
  END LOOP;
  IF n <> 5 THEN RAISE EXCEPTION 'Esperava 5 listas e achei %. Nada foi alterado.', n; END IF;
  UPDATE inv_configuracoes SET valor = est WHERE chave = 'estrutura';

  -- 5b) "+" (adicoes): o (3KG) entrou nas churrasqueiras pelo "+"; agora o nome
  --     novo ja esta na lista delas, entao sai do "+"
  SELECT valor INTO ad FROM inv_configuracoes WHERE chave = 'adicoes' FOR UPDATE;
  n := 0;
  FOR k IN SELECT jsonb_object_keys(ad) LOOP
    arr := ad -> k;
    IF jsonb_typeof(arr) <> 'array' OR NOT (arr ? nb OR arr ? n3) THEN CONTINUE; END IF;
    IF k NOT IN ('CHURRASQUEIRA|PEIXES', 'Delivery P10>CHURRASQUEIRA|PEIXES') THEN
      RAISE EXCEPTION '"+" inesperado em %. Nada foi alterado.', k;
    END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY i), '[]'::jsonb) INTO narr
      FROM jsonb_array_elements_text(arr) WITH ORDINALITY t(e, i) WHERE e NOT IN (nb, n3);
    ad := jsonb_set(ad, ARRAY[k], narr);
    n := n + 1;
  END LOOP;
  IF n <> 2 THEN RAISE EXCEPTION 'Esperava 2 "+" e achei %. Nada foi alterado.', n; END IF;
  UPDATE inv_configuracoes SET valor = ad WHERE chave = 'adicoes';

  -- 5c) padroes: fica o do (3KG), que e o que as churrasqueiras usam desde
  --     09/10, sem mudar nenhum numero; o da BANDA sai
  SELECT valor INTO pad FROM inv_configuracoes WHERE chave = 'padroes' FOR UPDATE;
  n := 0;
  FOR k IN SELECT jsonb_object_keys(pad) LOOP
    IF right(k, length(n3) + 1) = '|' || n3 THEN
      nk := left(k, length(k) - length(n3)) || novo;
      IF pad ? nk THEN RAISE EXCEPTION 'Padrao % ja existe. Nada foi alterado.', nk; END IF;
      pad := (pad - k) || jsonb_build_object(nk, pad -> k);
      n := n + 1;
    END IF;
  END LOOP;
  FOR k IN SELECT jsonb_object_keys(pad) LOOP
    IF right(k, length(nb) + 1) = '|' || nb THEN pad := pad - k; END IF;
  END LOOP;
  IF n <> 2 THEN RAISE EXCEPTION 'Esperava 2 padroes e achei %. Nada foi alterado.', n; END IF;
  UPDATE inv_configuracoes SET valor = pad WHERE chave = 'padroes';

  -- 5d) excluidos: o nome antigo sai da lista de excluidos
  SELECT valor INTO exc FROM inv_configuracoes WHERE chave = 'excluidos' FOR UPDATE;
  SELECT coalesce(jsonb_agg(e ORDER BY i), '[]'::jsonb) INTO exc
    FROM jsonb_array_elements(exc) WITH ORDINALITY t(e, i)
   WHERE e NOT IN (to_jsonb(nb), to_jsonb(n3));
  UPDATE inv_configuracoes SET valor = exc WHERE chave = 'excluidos';

  RAISE NOTICE 'Pronto.';
END $$;

COMMIT;


-- =====================================================================
-- PASSO 4 - CONFERENCIA (so leitura)
-- =====================================================================

-- (a) Esperado: MP TAMBAQUI DE BANDA ativo; MP BANDA DE TAMBAQUI inativo
SELECT id, nome, ativo FROM est_produtos
 WHERE id IN ('9a329d38-02b6-4aef-8eee-623f275e81d7', '63c674c1-2110-4ee1-98d6-d25fac740e50');

-- (b) Esperado: banda 0, fica 21
SELECT count(*) FILTER (WHERE ingrediente_id = '9a329d38-02b6-4aef-8eee-623f275e81d7') AS banda,
       count(*) FILTER (WHERE ingrediente_id = '63c674c1-2110-4ee1-98d6-d25fac740e50') AS fica
  FROM est_ficha_ingredientes;

-- (c) Esperado: saldo so no MP TAMBAQUI DE BANDA, igual ao do 3KG no PASSO 1
SELECT p.nome, s.local, s.saldo
  FROM est_saldo_local s JOIN est_produtos p ON p.id = s.produto_id
 WHERE s.produto_id IN ('9a329d38-02b6-4aef-8eee-623f275e81d7', '63c674c1-2110-4ee1-98d6-d25fac740e50')
 ORDER BY p.nome, s.local;

-- (d) Esperado: todos false (nome antigo nao aparece mais em lugar nenhum)
SELECT chave,
       valor::text LIKE '%MP BANDA DE TAMBAQUI%'      AS tem_banda,
       valor::text LIKE '%MP TAMBAQUI DE BANDA (3KG)%' AS tem_3kg
  FROM inv_configuracoes
 WHERE chave IN ('estrutura', 'adicoes', 'padroes', 'excluidos', 'mapeamentos');

-- DEPOIS: F5 em todas as telas (computador e celulares), principalmente
-- na contagem das churrasqueiras.
