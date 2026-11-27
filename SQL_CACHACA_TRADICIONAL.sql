-- ============================================================================
-- CACHAÇA TRADICIONAL: um cadastro só para a cachaça da casa (27/11/2026)
--
-- Hoje a cachaça tradicional está espalhada em 5 cadastros:
--   6be0008d-6e8d-4420-a49f-917170bcd16a  MP CACHAÇA BRAZUKA 700ML   é o que se COMPRA, conta,
--                                          pede pro bar e tem fornecedor ligado
--   33c12d67-3fa2-428a-8d12-69067e5ffb36  MP YPIOCA PRATA 965ML      9 fichas, nunca comprada
--   3fcba41c-bcd4-4e2e-8573-1a4b20e05689  MP CACHAÇA CABARÉ          4 fichas
--   eb40e2ee-29a1-4f6a-b957-93b8bc4f671c  MP CABARÊ PRATA            repetido, sem uso
--   12fea814-c339-474b-957a-0e1550412a31  MP CACHAÇA TRADICIONAL     antigo, sem ficha
--
-- Resultado: a venda baixa a Ypioca/Cabaré e a compra entra na Brazuka.
-- Plano: o cadastro da Brazuka FICA (tem a compra, o saldo e o fornecedor) e passa a se
-- chamar MP CACHAÇA TRADICIONAL; as fichas dos outros passam para ele; os outros 4 ficam
-- inativos (o histórico deles continua lá).
--
-- RODADO E CONFERIDO EM 27/11/2026 (PASSO 3: 14 fichas na Tradicional, 1 linha na lista do bar,
-- pedido padrão 4,9 mantido, saldo BAR 4,5 / ESTOQUE_LOJA 13,15).
-- O PASSO 2 foi escrito em cima
-- do resultado do PASSO 1, porque a cópia que analisei era de 11/11.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PASSO 1 (só leitura): rode e mande o resultado
-- ---------------------------------------------------------------------------
WITH ids(id, rotulo) AS (VALUES
  ('6be0008d-6e8d-4420-a49f-917170bcd16a'::uuid, 'FICA Brazuka'),
  ('33c12d67-3fa2-428a-8d12-69067e5ffb36'::uuid, 'SAI Ypioca prata'),
  ('3fcba41c-bcd4-4e2e-8573-1a4b20e05689'::uuid, 'SAI Cabare'),
  ('eb40e2ee-29a1-4f6a-b957-93b8bc4f671c'::uuid, 'SAI Cabare prata'),
  ('12fea814-c339-474b-957a-0e1550412a31'::uuid, 'SAI Tradicional antigo')
),
nomes AS (
  SELECT i.id, i.rotulo, p.nome FROM ids i JOIN est_produtos p ON p.id = i.id
)
SELECT secao, rotulo, detalhe FROM (
  -- 1) cadastro
  SELECT 1 AS ordem, '1 cadastro' AS secao, n.rotulo,
         p.nome || ' | ativo=' || p.ativo || ' | ' || coalesce(p.unidade_comp, '') || ' -> '
         || coalesce(p.unidade_uso, '') || ' | fator=' || coalesce(p.fator_conversao::text, '')
         || ' | custo=' || coalesce(p.custo_comp::text, '') AS detalhe
    FROM nomes n JOIN est_produtos p ON p.id = n.id
  UNION ALL
  SELECT 1, '1 cadastro', 'OUTRO com nome parecido', p.id || ' ' || p.nome || ' | ativo=' || p.ativo
    FROM est_produtos p
   WHERE p.nome ILIKE '%CACHA%TRADICIONAL%' AND coalesce(p.tipo, '') <> 'VENDA'
     AND p.id NOT IN (SELECT id FROM ids)
  UNION ALL
  -- 2) saldo diferente de zero
  SELECT 2, '2 saldo', n.rotulo, s.local || ' = ' || s.saldo
    FROM nomes n JOIN est_saldo_local s ON s.produto_id = n.id
   WHERE s.saldo <> 0
  UNION ALL
  -- 3) fichas ativas que usam
  SELECT 3, '3 ficha', n.rotulo, pv.nome || ' | ' || fi.quantidade || ' ' || coalesce(fi.unidade, '')
    FROM nomes n
    JOIN est_ficha_ingredientes fi ON fi.ingrediente_id = n.id
    JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id AND f.ativo
    JOIN est_produtos pv ON pv.id = f.produto_id
  UNION ALL
  SELECT 3, '3 ficha com 2 cachacas', '', pv.nome
    FROM est_ficha_ingredientes fi
    JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id AND f.ativo
    JOIN est_produtos pv ON pv.id = f.produto_id
   WHERE fi.ingrediente_id IN (SELECT id FROM ids)
   GROUP BY f.id, pv.nome
  HAVING count(*) > 1
  UNION ALL
  -- 4) compras ainda não recebidas
  SELECT 4, '4 compra em aberto', n.rotulo,
         coalesce(c.pedido_num, '') || ' | ' || c.data || ' | ' || coalesce(c.status_receb, '') || ' | qtd=' || c.quantidade
    FROM nomes n JOIN cmp_compras c ON c.produto_id = n.id
   WHERE coalesce(c.status_receb, '') NOT IN ('recebido', 'dispensado', 'cancelado')
  UNION ALL
  -- 5) linhas nas listas de contagem (por nome)
  SELECT 5, '5 lista da contagem', n.rotulo,
         u.key || ' > ' || st.key || ' > ' || g.key || ' > posicao ' || (e.pos - 1) || ' | ' || e.nome
    FROM inv_configuracoes c,
         jsonb_each(c.valor) u, jsonb_each(u.value) st, jsonb_each(st.value) g,
         jsonb_array_elements_text(g.value) WITH ORDINALITY e(nome, pos),
         nomes n
   WHERE c.chave = 'estrutura' AND upper(e.nome) = upper(n.nome)
  UNION ALL
  -- 6) outras configurações que citam o id ou o nome
  SELECT 6, '6 outra configuracao', n.rotulo, c.chave
    FROM inv_configuracoes c, nomes n
   WHERE c.chave <> 'estrutura'
     AND (c.valor::text LIKE '%' || n.id || '%' OR upper(c.valor::text) LIKE '%' || upper(n.nome) || '%')
  UNION ALL
  -- 7) pedido sombra (o robô refaz)
  SELECT 7, '7 pedido sombra', n.rotulo, count(*)::text
    FROM nomes n JOIN pdv_pedido_sombra ps ON ps.produto_id = n.id
   GROUP BY n.rotulo
  UNION ALL
  -- 8) movimento desde 01/11
  SELECT 8, '8 movimento desde 01/11', n.rotulo, m.tipo || ' | ultima ' || max(m.data) || ' | ' || count(*) || 'x'
    FROM nomes n JOIN est_movimentacoes m ON m.produto_id = n.id
   WHERE m.data >= DATE '2026-11-01'
   GROUP BY n.rotulo, m.tipo
) x
ORDER BY ordem, rotulo, detalhe;

-- Resultado do PASSO 1 em 27/11 (produção):
--   saldo: só a Brazuka (BAR 4,5 / ESTOQUE_LOJA 13,15); os outros 4 zerados
--   fichas: Ypioca 9, Cabaré 4, Brazuka 1; nenhuma ficha com duas cachaças
--   compra em aberto: nenhuma
--   lista da contagem: Centro > BAR > DESTILADOS posição 15 (Tradicional antigo),
--                      35 (Ypioca), 37 (Brazuka)
--   pedido padrão (padroes, chave SETOR|GRUPO|NOME): Brazuka e Tradicional antigo
--   planejamento_compras.diasProd: Cabaré e Tradicional antigo (valor antigo, ignorado)

-- ---------------------------------------------------------------------------
-- PASSO 2: unificação (tudo numa transação; qualquer trava que falhar desfaz tudo)
-- ---------------------------------------------------------------------------
BEGIN;

-- 2a) backup
CREATE TABLE bkp_cachaca_prod   AS SELECT * FROM est_produtos WHERE id IN
  ('6be0008d-6e8d-4420-a49f-917170bcd16a','33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
   'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31');
CREATE TABLE bkp_cachaca_ingr   AS SELECT * FROM est_ficha_ingredientes WHERE ingrediente_id IN
  ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
   'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31');
CREATE TABLE bkp_cachaca_config AS SELECT * FROM inv_configuracoes
  WHERE chave IN ('estrutura', 'padroes', 'planejamento_compras');
ALTER TABLE bkp_cachaca_prod   ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_cachaca_ingr   ENABLE ROW LEVEL SECURITY;
ALTER TABLE bkp_cachaca_config ENABLE ROW LEVEL SECURITY;

-- 2b) travas: o estado tem que ser o do PASSO 1
DO $$
DECLARE
  v_nomes   text;
  v_saldo   numeric;
  v_n       int;
  v_lista   text;
  v_padrao  numeric;
BEGIN
  SELECT string_agg(normalize(upper(trim(nome)), NFC) || '=' || ativo, ' / ' ORDER BY id) INTO v_nomes
    FROM est_produtos WHERE id IN
    ('6be0008d-6e8d-4420-a49f-917170bcd16a','33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
     'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31');
  IF v_nomes IS DISTINCT FROM normalize(
       'MP CACHAÇA TRADICIONAL=true / MP YPIOCA PRATA 965ML=true / MP CACHAÇA CABARÉ=true / '
       || 'MP CACHAÇA BRAZUKA 700ML=true / MP CABARÊ PRATA=true', NFC) THEN
    RAISE EXCEPTION 'Cadastros diferentes do PASSO 1: %', v_nomes;
  END IF;

  SELECT coalesce(sum(abs(saldo)), 0) INTO v_saldo FROM est_saldo_local WHERE produto_id IN
    ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
     'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31');
  IF v_saldo <> 0 THEN RAISE EXCEPTION 'Um cadastro que sai ganhou saldo (%). Parei.', v_saldo; END IF;

  SELECT count(*) INTO v_n FROM cmp_compras WHERE produto_id IN
    ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
     'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31')
     AND coalesce(status_receb, '') NOT IN ('recebido', 'dispensado', 'cancelado');
  IF v_n <> 0 THEN RAISE EXCEPTION 'Há % compra(s) em aberto num cadastro que sai', v_n; END IF;

  SELECT count(*) INTO v_n FROM (
    SELECT fi.ficha_id FROM est_ficha_ingredientes fi
     WHERE fi.ingrediente_id IN ('6be0008d-6e8d-4420-a49f-917170bcd16a','33c12d67-3fa2-428a-8d12-69067e5ffb36',
           '3fcba41c-bcd4-4e2e-8573-1a4b20e05689','eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31')
     GROUP BY fi.ficha_id HAVING count(*) > 1) x;
  IF v_n <> 0 THEN RAISE EXCEPTION '% ficha(s) com duas cachaças', v_n; END IF;

  SELECT count(*) INTO v_n FROM est_ficha_ingredientes fi JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id AND f.ativo
   WHERE fi.ingrediente_id IN ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689');
  IF v_n <> 13 THEN RAISE EXCEPTION 'Esperava 13 fichas ativas (9 Ypioca + 4 Cabaré), achei %', v_n; END IF;

  SELECT normalize(upper(valor #>> '{Centro,BAR,DESTILADOS,15}'), NFC) || ' / '
      || normalize(upper(valor #>> '{Centro,BAR,DESTILADOS,35}'), NFC) || ' / '
      || normalize(upper(valor #>> '{Centro,BAR,DESTILADOS,37}'), NFC)
    INTO v_lista FROM inv_configuracoes WHERE chave = 'estrutura';
  IF v_lista IS DISTINCT FROM normalize('MP CACHAÇA TRADICIONAL / MP YPIOCA PRATA 965ML / MP CACHAÇA BRAZUKA 700ML', NFC) THEN
    RAISE EXCEPTION 'A lista do bar mudou desde o PASSO 1: %', v_lista;
  END IF;

  -- o pedido padrão do Tradicional antigo é apagado: só segue se estiver zerado
  SELECT coalesce(sum(abs(d.value::numeric)), 0) INTO v_padrao
    FROM inv_configuracoes c, jsonb_each(c.valor) k, jsonb_each_text(k.value) d
   WHERE c.chave = 'padroes'
     AND normalize(upper(k.key), NFC) LIKE normalize('%|MP CACHAÇA TRADICIONAL', NFC);
  IF v_padrao <> 0 THEN RAISE EXCEPTION 'O pedido padrão do Tradicional antigo não está zerado (%)', v_padrao; END IF;
END $$;

-- 2c) cadastros: o antigo sai do caminho do nome, a Brazuka vira a Tradicional
UPDATE est_produtos SET nome = 'MP CACHAÇA TRADICIONAL (ANTIGO)', ativo = false
 WHERE id = '12fea814-c339-474b-957a-0e1550412a31';
UPDATE est_produtos SET nome = 'MP CACHAÇA TRADICIONAL'
 WHERE id = '6be0008d-6e8d-4420-a49f-917170bcd16a';
UPDATE est_produtos SET ativo = false
 WHERE id IN ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689','eb40e2ee-29a1-4f6a-b957-93b8bc4f671c');

-- 2d) fichas: Ypioca e Cabaré passam para a Tradicional (mesma quantidade, mesma unidade LT)
UPDATE est_ficha_ingredientes SET ingrediente_id = '6be0008d-6e8d-4420-a49f-917170bcd16a'
 WHERE ingrediente_id IN ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689');

-- 2e) lista do bar: a linha da Brazuka ganha o nome novo; as do Ypioca e do antigo saem
--     (troca a 37 antes; tira a 35 e depois a 15, de trás para frente)
UPDATE inv_configuracoes
   SET valor = jsonb_set(valor, '{Centro,BAR,DESTILADOS,37}', to_jsonb('MP CACHAÇA TRADICIONAL'::text))
               #- '{Centro,BAR,DESTILADOS,35}'
               #- '{Centro,BAR,DESTILADOS,15}'
 WHERE chave = 'estrutura';

-- 2f) pedido padrão: tira a chave zerada do antigo e renomeia a da Brazuka (mantém os valores)
UPDATE inv_configuracoes c
   SET valor = (
     SELECT jsonb_object_agg(
              CASE WHEN normalize(upper(k.key), NFC) LIKE normalize('%|MP CACHAÇA BRAZUKA 700ML', NFC)
                   THEN regexp_replace(k.key, '[^|]*$', '') || 'MP CACHAÇA TRADICIONAL'
                   ELSE k.key END,
              k.value)
       FROM jsonb_each(c.valor) k
      WHERE normalize(upper(k.key), NFC) NOT LIKE normalize('%|MP CACHAÇA TRADICIONAL', NFC))
 WHERE c.chave = 'padroes';

-- 2g) planejamento: tira o diasProd (antigo, já ignorado) dos dois que ficam inativos
UPDATE inv_configuracoes
   SET valor = valor #- '{Centro,diasProd,12fea814-c339-474b-957a-0e1550412a31}'
                     #- '{Centro,diasProd,3fcba41c-bcd4-4e2e-8573-1a4b20e05689}'
 WHERE chave = 'planejamento_compras';

-- 2h) conferência dentro da transação
DO $$
DECLARE
  v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM est_produtos
   WHERE ativo AND normalize(upper(trim(nome)), NFC) = normalize('MP CACHAÇA TRADICIONAL', NFC);
  IF v_n <> 1 THEN RAISE EXCEPTION 'Esperava 1 cadastro ativo MP CACHAÇA TRADICIONAL, achei %', v_n; END IF;

  SELECT count(*) INTO v_n FROM est_ficha_ingredientes WHERE ingrediente_id IN
    ('33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
     'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31');
  IF v_n <> 0 THEN RAISE EXCEPTION 'Ainda há % linha(s) de ficha nos cadastros que saem', v_n; END IF;

  SELECT count(*) INTO v_n FROM est_ficha_ingredientes fi JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id AND f.ativo
   WHERE fi.ingrediente_id = '6be0008d-6e8d-4420-a49f-917170bcd16a';
  IF v_n <> 14 THEN RAISE EXCEPTION 'Esperava 14 fichas na Tradicional, achei %', v_n; END IF;

  SELECT count(*) INTO v_n
    FROM inv_configuracoes c, jsonb_array_elements_text(c.valor #> '{Centro,BAR,DESTILADOS}') e(nome)
   WHERE c.chave = 'estrutura'
     AND normalize(upper(e.nome), NFC) IN (normalize('MP CACHAÇA TRADICIONAL', NFC), normalize('MP YPIOCA PRATA 965ML', NFC),
                                           normalize('MP CACHAÇA BRAZUKA 700ML', NFC));
  IF v_n <> 1 THEN RAISE EXCEPTION 'Lista do bar: esperava 1 linha de cachaça tradicional, achei %', v_n; END IF;

  SELECT count(*) INTO v_n FROM inv_configuracoes c, jsonb_each(c.valor) k
   WHERE c.chave = 'padroes' AND normalize(upper(k.key), NFC) LIKE normalize('%|MP CACHAÇA BRAZUKA 700ML', NFC);
  IF v_n <> 0 THEN RAISE EXCEPTION 'Pedido padrão ainda com a chave da Brazuka'; END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- PASSO 3 (só leitura): conferência
-- ---------------------------------------------------------------------------
SELECT 'cadastro' AS secao, p.nome || ' | ativo=' || p.ativo AS detalhe
  FROM est_produtos p WHERE p.id IN
  ('6be0008d-6e8d-4420-a49f-917170bcd16a','33c12d67-3fa2-428a-8d12-69067e5ffb36','3fcba41c-bcd4-4e2e-8573-1a4b20e05689',
   'eb40e2ee-29a1-4f6a-b957-93b8bc4f671c','12fea814-c339-474b-957a-0e1550412a31')
UNION ALL
SELECT 'saldo', s.local || ' = ' || s.saldo FROM est_saldo_local s
 WHERE s.produto_id = '6be0008d-6e8d-4420-a49f-917170bcd16a' AND s.saldo <> 0
UNION ALL
SELECT 'ficha', pv.nome || ' | ' || fi.quantidade || ' ' || coalesce(fi.unidade, '')
  FROM est_ficha_ingredientes fi
  JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id AND f.ativo
  JOIN est_produtos pv ON pv.id = f.produto_id
 WHERE fi.ingrediente_id = '6be0008d-6e8d-4420-a49f-917170bcd16a'
UNION ALL
SELECT 'lista do bar', e.nome
  FROM inv_configuracoes c, jsonb_array_elements_text(c.valor #> '{Centro,BAR,DESTILADOS}') e(nome)
 WHERE c.chave = 'estrutura' AND e.nome ILIKE '%CACHA%'
UNION ALL
SELECT 'pedido padrao', k.key || ' = ' || k.value::text
  FROM inv_configuracoes c, jsonb_each(c.valor) k
 WHERE c.chave = 'padroes' AND k.key ILIKE '%CACHA%TRADICIONAL%';
