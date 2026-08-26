-- ============================================================================
-- NUMERACAO DE PEDIDO E CONTAGEM SAI DO BANCO, NAO DO APARELHO
--
-- Hoje o numero e' feito no celular: le o maior num_pedido, soma 1. Dois envios
-- ao mesmo tempo leem o mesmo maior e nascem com o MESMO numero. Ja aconteceu 61
-- vezes com PED e 26 vezes com INV. Em dois casos foram setores diferentes - ou
-- seja, aparelhos diferentes, coisa que a trava de toque duplo no codigo NAO pega.
--
-- A correcao troca isso por uma sequence do Postgres. nextval e' atomico: dois
-- chamados simultaneos nunca recebem o mesmo numero.
--
-- ORDEM: rode este SQL ANTES de subir o codigo novo. O codigo novo tenta a funcao
-- e, se ela nao existir, volta sozinho para o jeito antigo - entao rodar o SQL
-- antes ou depois nao quebra nada, so adianta a protecao.
--
-- PASSO 1 e' so leitura. Rode um passo de cada vez.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- PASSO 1 (leitura): como esta hoje
-- ---------------------------------------------------------------------------
SELECT 'pedidos_internos' AS tabela,
       count(*)                                                        AS linhas,
       max(NULLIF(regexp_replace(num_pedido, '\D', '', 'g'), '')::int)  AS maior_numero,
       count(*) - count(DISTINCT num_pedido)                            AS linhas_com_numero_repetido
FROM pedidos_internos
UNION ALL
SELECT 'est_inventarios',
       count(*),
       max(NULLIF(regexp_replace(num_inv, '\D', '', 'g'), '')::int),
       count(*) - count(DISTINCT num_inv)
FROM est_inventarios;


-- ---------------------------------------------------------------------------
-- PASSO 2: cria as sequences ja posicionadas depois do maior numero existente
-- ---------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_num_pedido AS bigint START WITH 1;
CREATE SEQUENCE IF NOT EXISTS seq_num_inv    AS bigint START WITH 1;

SELECT setval('seq_num_pedido',
              COALESCE(max(NULLIF(regexp_replace(num_pedido, '\D', '', 'g'), '')::bigint), 0) + 1,
              false)
FROM pedidos_internos;

SELECT setval('seq_num_inv',
              COALESCE(max(NULLIF(regexp_replace(num_inv, '\D', '', 'g'), '')::bigint), 0) + 1,
              false)
FROM est_inventarios;


-- ---------------------------------------------------------------------------
-- PASSO 3: as funcoes que o sistema vai chamar
--
-- O bloco do "maior" no meio e' rede de seguranca para celular com a versao
-- antiga em cache, que continua numerando por conta propria por uns dias: se
-- algum ja gravou um numero igual ou maior, a sequence pula para depois dele em
-- vez de repetir. Some sozinho quando todo mundo recarregar a pagina.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION proximo_num_pedido()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n     bigint;
  maior bigint;
BEGIN
  n := nextval('seq_num_pedido');

  SELECT COALESCE(max(NULLIF(regexp_replace(num_pedido, '\D', '', 'g'), '')::bigint), 0)
    INTO maior
  FROM pedidos_internos;

  IF maior >= n THEN
    n := setval('seq_num_pedido', maior + 1);
  END IF;

  RETURN 'PED-' || lpad(n::text, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION proximo_num_inv()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n     bigint;
  maior bigint;
BEGIN
  n := nextval('seq_num_inv');

  SELECT COALESCE(max(NULLIF(regexp_replace(num_inv, '\D', '', 'g'), '')::bigint), 0)
    INTO maior
  FROM est_inventarios;

  IF maior >= n THEN
    n := setval('seq_num_inv', maior + 1);
  END IF;

  RETURN 'INV-' || lpad(n::text, 4, '0');
END;
$$;

GRANT USAGE, SELECT, UPDATE ON SEQUENCE seq_num_pedido, seq_num_inv TO anon, authenticated;
GRANT EXECUTE ON FUNCTION proximo_num_pedido(), proximo_num_inv() TO anon, authenticated;


-- ---------------------------------------------------------------------------
-- PASSO 4 (teste): tem de devolver o proximo numero de cada um
--
-- Atencao: testar QUEIMA um numero de cada (o proximo pedido de verdade vai pular
-- um). Nao tem problema nenhum - numero de pedido nao precisa ser sequencia sem
-- buraco, so precisa nao repetir.
-- ---------------------------------------------------------------------------
SELECT proximo_num_pedido() AS proximo_pedido, proximo_num_inv() AS proxima_contagem;


-- ---------------------------------------------------------------------------
-- PASSO 5 (OPCIONAL - so daqui a uns dias): trava definitiva no banco
--
-- Este indice impede fisicamente dois pedidos com o mesmo numero, mas SO vale
-- para linhas criadas de 27/08/2026 em diante - o historico repetido fica como
-- esta, sem ser mexido.
--
-- NAO rode hoje. Enquanto houver celular com a versao antiga em cache, esse
-- aparelho continua numerando sozinho e pode bater de frente com a sequence; com
-- o indice no ar, o pedido dele daria ERRO e o funcionario ficaria sem enviar.
-- Espere todo mundo abrir o sistema pelo menos uma vez com a versao nova.
--
-- Para conferir que ja pode: o PASSO 1 rodado de novo nao pode mostrar numero
-- repetido novo depois da data abaixo.
--
-- CREATE UNIQUE INDEX IF NOT EXISTS uniq_pedidos_internos_num_novo
--   ON pedidos_internos (num_pedido)
--   WHERE criado_em >= '2026-08-27';
--
-- CREATE UNIQUE INDEX IF NOT EXISTS uniq_est_inventarios_num_novo
--   ON est_inventarios (num_inv)
--   WHERE criado_em >= '2026-08-27';
