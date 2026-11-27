-- ============================================================================
-- PEDIDO PADRÃO PERDIDO POR RENOMEAR PRODUTO (27/11/2026)
--
-- Até o commit 294d5d6, renomear um produto na tela de Produtos levava o nome novo
-- para a lista da contagem, mas o pedido padrão ficava guardado no nome velho
-- (a chave é "SETOR|GRUPO|NOME", com "UNIDADE>" na frente fora do Centro).
-- O produto passava a aparecer com padrão zero e o pedido do setor parava de pedir.
--
-- Como achar: o histórico das listas (inv_config_historico, desde 05/10) anota cada
-- troca. Renomear deixa, no mesmo instante e no mesmo grupo, um "saiu" (nome velho)
-- e um "entrou" (nome novo). Se o padrão do nome velho ainda existe, ele se perdeu.
-- Renomeações antes de 05/10 não têm histórico (ver PASSO 1b).
--
-- PASSOS 1 só leitura. PASSO 2 (Tangerina) RODADO E CONFERIDO EM 27/11/2026:
-- BAR|HORTIFRUTI|MP TANGERINA IMPORTADA = 1 por dia.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PASSO 1a: renomeações desde 05/10 com o padrão preso no nome velho
-- ---------------------------------------------------------------------------
WITH cfg AS (
  SELECT (SELECT valor FROM inv_configuracoes WHERE chave = 'estrutura') AS est,
         (SELECT valor FROM inv_configuracoes WHERE chave = 'padroes')   AS pad
),
centro AS (
  SELECT jsonb_object_keys(est -> 'Centro') AS se FROM cfg
),
h AS (
  SELECT criado_em, usuario, unidade, setor, grupo, acao, produto
    FROM inv_config_historico
   WHERE chave = 'estrutura'
),
um_por_um AS (   -- só o instante/grupo com exatamente 1 saída e 1 entrada (cara de renomear)
  SELECT criado_em, unidade, setor, grupo
    FROM h
   GROUP BY criado_em, unidade, setor, grupo
  HAVING count(*) FILTER (WHERE acao = 'saiu') = 1
     AND count(*) FILTER (WHERE acao = 'entrou') = 1
),
ren AS (
  SELECT g.criado_em, s.usuario, g.unidade, g.setor, g.grupo,
         s.produto AS nome_velho, e.produto AS nome_novo,
         CASE WHEN g.unidade = 'Centro' OR g.setor NOT IN (SELECT se FROM centro) THEN ''
              ELSE g.unidade || '>' END AS pref
    FROM um_por_um g
    JOIN h s ON s.criado_em = g.criado_em AND s.unidade = g.unidade AND s.setor = g.setor
            AND s.grupo = g.grupo AND s.acao = 'saiu'
    JOIN h e ON e.criado_em = g.criado_em AND e.unidade = g.unidade AND e.setor = g.setor
            AND e.grupo = g.grupo AND e.acao = 'entrou'
   WHERE upper(trim(s.produto)) <> upper(trim(e.produto))
),
chaves AS (
  SELECT r.*,
         r.pref || r.setor || '|' || r.grupo || '|' || upper(trim(r.nome_velho)) AS chave_velha,
         r.pref || r.setor || '|' || r.grupo || '|' || upper(trim(r.nome_novo))  AS chave_nova
    FROM ren r
)
SELECT to_char(c.criado_em AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI') AS quando,
       c.usuario,
       c.unidade, c.setor, c.grupo,
       c.nome_velho, c.nome_novo,
       cfg.pad -> c.chave_velha AS padrao_no_nome_velho,
       cfg.pad -> c.chave_nova  AS padrao_no_nome_novo,
       EXISTS (SELECT 1 FROM jsonb_array_elements_text(cfg.est -> c.unidade -> c.setor -> c.grupo) x(n)
                WHERE upper(trim(x.n)) = upper(trim(c.nome_novo))) AS nome_novo_na_lista_hoje,
       EXISTS (SELECT 1 FROM jsonb_array_elements_text(cfg.est -> c.unidade -> c.setor -> c.grupo) x(n)
                WHERE upper(trim(x.n)) = upper(trim(c.nome_velho))) AS nome_velho_na_lista_hoje
  FROM chaves c, cfg
 WHERE cfg.pad ? c.chave_velha
 ORDER BY c.criado_em, c.unidade, c.setor, c.grupo;

-- ---------------------------------------------------------------------------
-- PASSO 1b: padrões com quantidade que não batem com nenhuma linha da lista hoje
--   (inclui perdas de antes de 05/10 e sobras de reorganização de setor/grupo).
--   Rode separado: o SQL Editor só mostra o resultado da última consulta.
-- ---------------------------------------------------------------------------
WITH cfg AS (
  SELECT (SELECT valor FROM inv_configuracoes WHERE chave = 'estrutura') AS est,
         (SELECT valor FROM inv_configuracoes WHERE chave = 'padroes')   AS pad
),
centro AS (
  SELECT jsonb_object_keys(est -> 'Centro') AS se FROM cfg
),
linhas AS (
  SELECT CASE WHEN u.key = 'Centro' OR s.key NOT IN (SELECT se FROM centro) THEN '' ELSE u.key || '>' END
         || s.key || '|' || g.key || '|' || upper(trim(n.v)) AS chave
    FROM cfg, jsonb_each(cfg.est) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
         jsonb_array_elements_text(CASE WHEN jsonb_typeof(g.value) = 'array' THEN g.value ELSE '[]'::jsonb END) n(v)
)
SELECT p.key AS chave_do_padrao, p.value AS padrao
  FROM cfg, jsonb_each(cfg.pad) p
 WHERE NOT EXISTS (SELECT 1 FROM linhas l WHERE l.chave = p.key)
   AND EXISTS (SELECT 1 FROM jsonb_each_text(CASE WHEN jsonb_typeof(p.value) = 'object' THEN p.value ELSE '{}'::jsonb END) d
                WHERE d.value ~ '^[0-9.]+$' AND d.value::numeric > 0)
 ORDER BY p.key;

-- Resultado do PASSO 1a em 27/11 (produção): 2 linhas
--   05/10 15:30 Naldo Souza  Centro > BAR > HORTIFRUTI
--     MP TANGERINA -> MP TANGERINA IMPORTADA     renomeação de verdade (MP TANGERINA não existe
--                                                mais): o padrão ficou no nome velho -> CORRIGIR
--   05/10 14:10 wagner  Delivery P10 > MATERIAL DE LIMPEZA
--     MC PAPEL HIGIENICO FUNCIONARIO -> MC PAPEL HIGIENICO TORK SMART ONE
--                                                NÃO é renomeação: são dois produtos diferentes
--                                                (troca de item na lista) e o TORK já tem padrão
--                                                próprio -> não mexer

-- ---------------------------------------------------------------------------
-- PASSO 2: o padrão da MP TANGERINA passa para a MP TANGERINA IMPORTADA
-- ---------------------------------------------------------------------------
BEGIN;

CREATE TABLE bkp_padroes_tangerina AS SELECT * FROM inv_configuracoes WHERE chave = 'padroes';
ALTER TABLE bkp_padroes_tangerina ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  v_pad jsonb;
BEGIN
  SELECT valor INTO v_pad FROM inv_configuracoes WHERE chave = 'padroes';
  IF NOT v_pad ? 'BAR|HORTIFRUTI|MP TANGERINA' THEN
    RAISE EXCEPTION 'O padrão no nome velho (MP TANGERINA) não existe mais';
  END IF;
  IF v_pad ? 'BAR|HORTIFRUTI|MP TANGERINA IMPORTADA' THEN
    RAISE EXCEPTION 'A MP TANGERINA IMPORTADA já tem padrão: %', v_pad -> 'BAR|HORTIFRUTI|MP TANGERINA IMPORTADA';
  END IF;
END $$;

UPDATE inv_configuracoes
   SET valor = (valor - 'BAR|HORTIFRUTI|MP TANGERINA')
               || jsonb_build_object('BAR|HORTIFRUTI|MP TANGERINA IMPORTADA', valor -> 'BAR|HORTIFRUTI|MP TANGERINA')
 WHERE chave = 'padroes';

COMMIT;

-- PASSO 3 (só leitura)
SELECT k.key, k.value FROM inv_configuracoes c, jsonb_each(c.valor) k
 WHERE c.chave = 'padroes' AND k.key LIKE '%TANGERINA%';
