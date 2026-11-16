-- =====================================================================
-- SQL_FICHA_UNIDADE_DO_CADASTRO.sql  (16/11/2026)
--
-- A unidade do ingrediente na ficha técnica era texto livre, gravado em
-- cada linha (est_ficha_ingredientes.unidade). Varredura de 16/11:
-- 2.297 linhas de ficha
--   1.147 iguais ao cadastro
--     896 só grafia diferente ("Kg" x "KG", "Litro" x "LT")
--     254 com OUTRA unidade escrita ("0,01 Pacote" na PPC PASTA DE ALHO,
--         que é KG; "Porcao" em SA que é UN/PC; "Litro" em PPC que é KG)
--
-- A QUANTIDADE sempre foi lida na Unidade do cadastro (custo, baixa do
-- PDV, meta). Então a unidade escrita na linha era só texto na tela, mas
-- enganava quem lia. Este SQL:
--   PASSO 2  copia a Unidade do cadastro para todas as linhas de ficha;
--   PASSO 3  trava no banco: toda linha de ficha nasce/fica com a unidade
--            do cadastro, e mudar a Unidade no cadastro atualiza as fichas.
-- Não mexe em quantidade, custo, estoque nem financeiro.
--
-- Rode UM PASSO DE CADA VEZ. Se der "ASSERT failed", nada foi gravado.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASSO 1 - SÓ LEITURA. Quantas linhas estão diferentes do cadastro.
-- Esperado (16/11): ~1.150 diferentes (896 grafia + 254 outra unidade).
-- ---------------------------------------------------------------------
SELECT count(*) AS linhas_ficha,
       count(*) FILTER (WHERE i.unidade IS DISTINCT FROM p.unidade_uso) AS diferentes_do_cadastro,
       count(*) FILTER (WHERE upper(trim(coalesce(i.unidade,''))) <> upper(trim(coalesce(p.unidade_uso,'')))) AS sem_contar_maiuscula
  FROM est_ficha_ingredientes i
  JOIN est_produtos p ON p.id = i.ingrediente_id;


-- ---------------------------------------------------------------------
-- PASSO 2 - COPIA A UNIDADE DO CADASTRO PARA TODAS AS LINHAS DE FICHA.
-- ---------------------------------------------------------------------
BEGIN;

DO $$
DECLARE
  v_n int; v_qtd0 numeric; v_cnt0 int;
BEGIN
  SELECT count(*), coalesce(sum(quantidade),0) INTO v_cnt0, v_qtd0 FROM est_ficha_ingredientes;

  UPDATE est_ficha_ingredientes i
     SET unidade = p.unidade_uso
    FROM est_produtos p
   WHERE p.id = i.ingrediente_id
     AND coalesce(trim(p.unidade_uso), '') <> ''
     AND i.unidade IS DISTINCT FROM p.unidade_uso;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'Linhas de ficha corrigidas: %', v_n;

  ASSERT v_n BETWEEN 1000 AND 1400, format('esperava ~1.150 linhas, corrigiu %s', v_n);
  ASSERT NOT EXISTS (SELECT 1 FROM est_ficha_ingredientes i JOIN est_produtos p ON p.id = i.ingrediente_id
                      WHERE coalesce(trim(p.unidade_uso), '') <> '' AND i.unidade IS DISTINCT FROM p.unidade_uso),
         'ainda sobrou linha com unidade diferente do cadastro';
  ASSERT (SELECT count(*) FROM est_ficha_ingredientes) = v_cnt0, 'mudou a quantidade de linhas - nada foi gravado';
  ASSERT (SELECT coalesce(sum(quantidade),0) FROM est_ficha_ingredientes) = v_qtd0, 'mexeu em quantidade - nada foi gravado';
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 3 - TRAVA NO BANCO.
--  a) linha de ficha gravada (tela, duplicar produto, SQL) recebe sempre
--     a Unidade do cadastro do ingrediente;
--  b) mudar a Unidade no cadastro do produto atualiza as fichas que o usam.
-- ---------------------------------------------------------------------
BEGIN;

CREATE OR REPLACE FUNCTION est_ficha_ing_unidade_do_cadastro()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_un text;
BEGIN
  SELECT unidade_uso INTO v_un FROM est_produtos WHERE id = NEW.ingrediente_id;
  IF coalesce(trim(v_un), '') <> '' THEN
    NEW.unidade := v_un;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_ficha_ing_unidade ON est_ficha_ingredientes;
CREATE TRIGGER trg_ficha_ing_unidade
  BEFORE INSERT OR UPDATE OF unidade, ingrediente_id ON est_ficha_ingredientes
  FOR EACH ROW EXECUTE FUNCTION est_ficha_ing_unidade_do_cadastro();

CREATE OR REPLACE FUNCTION est_produto_unidade_nas_fichas()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF coalesce(trim(NEW.unidade_uso), '') <> '' THEN
    UPDATE est_ficha_ingredientes SET unidade = NEW.unidade_uso
     WHERE ingrediente_id = NEW.id AND unidade IS DISTINCT FROM NEW.unidade_uso;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_produto_unidade_nas_fichas ON est_produtos;
CREATE TRIGGER trg_produto_unidade_nas_fichas
  AFTER UPDATE OF unidade_uso ON est_produtos
  FOR EACH ROW WHEN (OLD.unidade_uso IS DISTINCT FROM NEW.unidade_uso)
  EXECUTE FUNCTION est_produto_unidade_nas_fichas();

-- Teste da trava dentro da transação: tentar gravar outra unidade não pega.
DO $$
DECLARE v_id uuid; v_un text; v_cad text;
BEGIN
  SELECT i.id, p.unidade_uso INTO v_id, v_cad
    FROM est_ficha_ingredientes i JOIN est_produtos p ON p.id = i.ingrediente_id
   WHERE coalesce(trim(p.unidade_uso), '') <> '' LIMIT 1;
  UPDATE est_ficha_ingredientes SET unidade = 'TESTE_TRAVA' WHERE id = v_id;
  SELECT unidade INTO v_un FROM est_ficha_ingredientes WHERE id = v_id;
  ASSERT v_un = v_cad, format('a trava não segurou: ficou %s, cadastro %s', v_un, v_cad);
END $$;

COMMIT;


-- ---------------------------------------------------------------------
-- PASSO 4 - SÓ LEITURA. Esperado: diferentes_do_cadastro = 0 e os 2 gatilhos.
-- ---------------------------------------------------------------------
SELECT count(*) FILTER (WHERE i.unidade IS DISTINCT FROM p.unidade_uso) AS diferentes_do_cadastro
  FROM est_ficha_ingredientes i JOIN est_produtos p ON p.id = i.ingrediente_id
 WHERE coalesce(trim(p.unidade_uso), '') <> '';

SELECT tgname, tgrelid::regclass AS tabela
  FROM pg_trigger
 WHERE tgname IN ('trg_ficha_ing_unidade', 'trg_produto_unidade_nas_fichas');
