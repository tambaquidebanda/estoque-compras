-- ============================================================================
-- HISTORICO DAS LISTAS DE CONTAGEM   (05/10/2026)
--
-- As listas (o que aparece em cada setor/grupo, o "+", as exclusoes, o pedido
-- padrao e os apelidos) ficam em inv_configuracoes e NAO guardavam quem mudou nem
-- quando. Em 02/10 e 05/10 itens sairam e voltaram da Cozinha/Congelados do Centro
-- e so deu para descobrir perguntando.
--
-- Este SQL cria:
--   * a tabela inv_config_historico (uma linha por produto que mudou);
--   * um gatilho em inv_configuracoes que compara o ANTES com o DEPOIS de cada
--     gravacao e anota so o que mudou, com o login de quem gravou.
-- Vale para qualquer tela (computador, celular, tela antiga aberta) e para SQL.
-- Os PINs NAO sao registrados.
--
-- O gatilho nunca impede a gravacao: se a anotacao der erro, a lista grava igual
-- e o erro vira so um aviso no log do banco.
--
-- Nao muda nenhuma lista. Pode rodar a qualquer hora (nao precisa F5 depois).
-- Rodar duas vezes nao duplica nada.
-- ============================================================================

-- PASSO 1 (so leitura): gatilhos que ja existem em inv_configuracoes (esperado: nenhum)
SELECT tgname FROM pg_trigger
 WHERE tgrelid = 'public.inv_configuracoes'::regclass AND NOT tgisinternal;

-- PASSO 2
BEGIN;

CREATE TABLE IF NOT EXISTS inv_config_historico (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  usuario       text,
  usuario_email text,
  chave         text NOT NULL,   -- estrutura | adicoes | padroes | excluidos | mapeamentos
  acao          text NOT NULL,   -- entrou | saiu | alterou
  unidade       text,
  setor         text,
  grupo         text,
  produto       text,
  antes         jsonb,
  depois        jsonb
);
CREATE INDEX IF NOT EXISTS idx_inv_hist_data  ON inv_config_historico (criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_inv_hist_grupo ON inv_config_historico (setor, grupo, criado_em DESC);

-- So leitura para quem esta logado. Ninguem grava pela tela: so o gatilho.
ALTER TABLE inv_config_historico ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ler_logado" ON inv_config_historico;
CREATE POLICY "ler_logado" ON inv_config_historico FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION inv_config_historico_log() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c       jsonb;
  v_email text;
  v_nome  text;
BEGIN
  IF NEW.valor IS NOT DISTINCT FROM OLD.valor THEN RETURN NULL; END IF;
  BEGIN
    c := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    v_email := c->>'email';
    v_nome  := coalesce(nullif(c->'user_metadata'->>'nome', ''),
                        nullif(split_part(v_email, '@', 1), ''),
                        CASE WHEN c->>'role' = 'service_role' THEN 'chave de servico' ELSE 'SQL Editor' END);

    IF NEW.chave = 'estrutura' THEN
      WITH o AS (
        SELECT u.key AS un, s.key AS se, g.key AS gr, n.v AS pr
          FROM jsonb_each(OLD.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
               jsonb_array_elements_text(CASE WHEN jsonb_typeof(g.value) = 'array' THEN g.value ELSE '[]'::jsonb END) n(v)
      ), w AS (
        SELECT u.key AS un, s.key AS se, g.key AS gr, n.v AS pr
          FROM jsonb_each(NEW.valor) u, jsonb_each(u.value) s, jsonb_each(s.value) g,
               jsonb_array_elements_text(CASE WHEN jsonb_typeof(g.value) = 'array' THEN g.value ELSE '[]'::jsonb END) n(v)
      )
      INSERT INTO inv_config_historico (usuario, usuario_email, chave, acao, unidade, setor, grupo, produto)
      SELECT v_nome, v_email, 'estrutura', 'entrou', un, se, gr, pr FROM (SELECT * FROM w EXCEPT SELECT * FROM o) x
      UNION ALL
      SELECT v_nome, v_email, 'estrutura', 'saiu',   un, se, gr, pr FROM (SELECT * FROM o EXCEPT SELECT * FROM w) y;

    ELSIF NEW.chave = 'adicoes' THEN
      -- chave "SETOR|GRUPO" ou "UNIDADE>SETOR|GRUPO"
      WITH o AS (
        SELECT a.key AS k, n.v AS pr FROM jsonb_each(OLD.valor) a,
               jsonb_array_elements_text(CASE WHEN jsonb_typeof(a.value) = 'array' THEN a.value ELSE '[]'::jsonb END) n(v)
      ), w AS (
        SELECT a.key AS k, n.v AS pr FROM jsonb_each(NEW.valor) a,
               jsonb_array_elements_text(CASE WHEN jsonb_typeof(a.value) = 'array' THEN a.value ELSE '[]'::jsonb END) n(v)
      ), d AS (
        SELECT 'entrou' AS acao, * FROM (SELECT * FROM w EXCEPT SELECT * FROM o) x
        UNION ALL
        SELECT 'saiu',           * FROM (SELECT * FROM o EXCEPT SELECT * FROM w) y
      )
      INSERT INTO inv_config_historico (usuario, usuario_email, chave, acao, unidade, setor, grupo, produto)
      SELECT v_nome, v_email, 'adicoes', acao,
             CASE WHEN position('>' in k) > 0 THEN split_part(k, '>', 1) END,
             split_part(CASE WHEN position('>' in k) > 0 THEN substr(k, position('>' in k) + 1) ELSE k END, '|', 1),
             split_part(CASE WHEN position('>' in k) > 0 THEN substr(k, position('>' in k) + 1) ELSE k END, '|', 2),
             pr
        FROM d;

    ELSIF NEW.chave = 'padroes' THEN
      -- chave "SETOR|GRUPO|PRODUTO" ou "UNIDADE>SETOR|GRUPO|PRODUTO"
      INSERT INTO inv_config_historico (usuario, usuario_email, chave, acao, unidade, setor, grupo, produto, antes, depois)
      SELECT v_nome, v_email, 'padroes',
             CASE WHEN o.value IS NULL THEN 'entrou' WHEN w.value IS NULL THEN 'saiu' ELSE 'alterou' END,
             CASE WHEN position('>' in k) > 0 THEN split_part(k, '>', 1) END,
             split_part(r, '|', 1), split_part(r, '|', 2),
             substr(r, length(split_part(r, '|', 1)) + length(split_part(r, '|', 2)) + 3),
             o.value, w.value
        FROM jsonb_each(OLD.valor) o
        FULL JOIN jsonb_each(NEW.valor) w ON w.key = o.key
        CROSS JOIN LATERAL (SELECT coalesce(o.key, w.key) AS k) kk
        CROSS JOIN LATERAL (SELECT CASE WHEN position('>' in k) > 0 THEN substr(k, position('>' in k) + 1) ELSE k END AS r) rr
       WHERE o.value IS DISTINCT FROM w.value;

    ELSIF NEW.chave = 'excluidos' THEN
      WITH o AS (SELECT jsonb_array_elements_text(CASE WHEN jsonb_typeof(OLD.valor) = 'array' THEN OLD.valor ELSE '[]'::jsonb END) AS pr),
           w AS (SELECT jsonb_array_elements_text(CASE WHEN jsonb_typeof(NEW.valor) = 'array' THEN NEW.valor ELSE '[]'::jsonb END) AS pr)
      INSERT INTO inv_config_historico (usuario, usuario_email, chave, acao, produto)
      SELECT v_nome, v_email, 'excluidos', 'entrou', pr FROM (SELECT pr FROM w EXCEPT SELECT pr FROM o) x
      UNION ALL
      SELECT v_nome, v_email, 'excluidos', 'saiu',   pr FROM (SELECT pr FROM o EXCEPT SELECT pr FROM w) y;

    ELSIF NEW.chave = 'mapeamentos' THEN
      INSERT INTO inv_config_historico (usuario, usuario_email, chave, acao, produto, antes, depois)
      SELECT v_nome, v_email, 'mapeamentos',
             CASE WHEN o.value IS NULL THEN 'entrou' WHEN w.value IS NULL THEN 'saiu' ELSE 'alterou' END,
             coalesce(o.key, w.key), o.value, w.value
        FROM jsonb_each(OLD.valor) o
        FULL JOIN jsonb_each(NEW.valor) w ON w.key = o.key
       WHERE o.value IS DISTINCT FROM w.value;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'inv_config_historico_log (%): %', NEW.chave, SQLERRM;
  END;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_inv_config_historico ON inv_configuracoes;
CREATE TRIGGER trg_inv_config_historico
  AFTER UPDATE ON inv_configuracoes
  FOR EACH ROW
  WHEN (NEW.chave IN ('estrutura', 'adicoes', 'padroes', 'excluidos', 'mapeamentos'))
  EXECUTE FUNCTION inv_config_historico_log();

-- Teste dentro da mesma transacao: poe um produto de mentira numa adicao de mentira,
-- confere que o historico anotou, tira de novo e apaga as linhas do teste.
-- Se o historico nao anotar, o SQL inteiro e desfeito (nada fica criado).
UPDATE inv_configuracoes SET valor = valor || '{"TESTE|HISTORICO": ["PRODUTO TESTE"]}'::jsonb
 WHERE chave = 'adicoes';
DO $$
BEGIN
  IF (SELECT count(*) FROM inv_config_historico
       WHERE chave = 'adicoes' AND acao = 'entrou' AND setor = 'TESTE' AND grupo = 'HISTORICO'
         AND produto = 'PRODUTO TESTE') <> 1 THEN
    RAISE EXCEPTION 'O historico nao anotou o teste - nada foi criado';
  END IF;
END $$;
UPDATE inv_configuracoes SET valor = valor - 'TESTE|HISTORICO' WHERE chave = 'adicoes';
DELETE FROM inv_config_historico WHERE setor = 'TESTE' AND grupo = 'HISTORICO';
COMMIT;

-- PASSO 3 (conferencia): esperado  gatilho = 1 | teste_ficou = 0 | linhas_historico = 0
-- (linhas_historico pode passar de 0 se alguem mexeu numa lista nesse minuto - e o historico ja funcionando)
SELECT (SELECT count(*) FROM pg_trigger WHERE tgname = 'trg_inv_config_historico') AS gatilho,
       (SELECT count(*) FROM inv_configuracoes WHERE chave = 'adicoes' AND valor ? 'TESTE|HISTORICO') AS teste_ficou,
       (SELECT count(*) FROM inv_config_historico) AS linhas_historico;
