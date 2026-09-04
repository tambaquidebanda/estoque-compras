-- ============================================================================
-- ALINHA A UNIDADE ESCRITA NA FICHA COM A UNIDADE DO CADASTRO
-- ============================================================================
-- POR QUE ISSO EXISTE
--   A unidade gravada em cada linha de ficha (est_ficha_ingredientes.unidade) e
--   uma COPIA da unidade de uso do produto, feita na hora em que o ingrediente
--   foi adicionado. Ate 21/08/2026 trocar a unidade no cadastro nao mexia nessas
--   copias (o commit 9c33b88 corrigiu isso dali pra frente). As linhas gravadas
--   antes ficaram com o rotulo velho.
--
-- POR QUE E SEGURO
--   O rotulo NAO entra em conta nenhuma. Todo custo no sistema e
--   quantidade x custo_uso (app.js:2513, 2545, 2555, 7646, 7700) e a baixa
--   automatica do PDV le so a quantidade. Este UPDATE muda texto, nao numero.
--
-- O QUE ELE NAO FAZ
--   So alinha os 7 pares em que as duas escritas sao A MESMA PALAVRA, uma por
--   extenso e a outra abreviada (LITRO/LT, UNIDADE/UN, MACO/MA...).
--   Ele NAO toca em nada onde a unidade mudou de sentido (PACOTE x KG,
--   LITRO x UN, PORCAO x UN) - esses casos precisam de alguem da cozinha
--   dizendo se a QUANTIDADE ainda esta certa, e estao na planilha
--   FICHAS_UNIDADES_CONFERIR.xlsx.
--
-- Rodar PASSO 1 primeiro. Ele nao altera nada.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA: o que o PASSO 2 vai mudar
-- ---------------------------------------------------------------------------
SELECT upper(btrim(fi.unidade))     AS escrito_na_ficha,
       upper(btrim(p.unidade_uso))  AS diz_o_cadastro,
       count(*)                     AS linhas
  FROM est_ficha_ingredientes fi
  JOIN est_produtos        p ON p.id = fi.ingrediente_id
  JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id
 WHERE f.ativo = true
   AND (upper(btrim(fi.unidade)), upper(btrim(p.unidade_uso))) IN (
        ('UNIDADE','UN'), ('LITRO','LT'), ('LITRO','LI'),
        ('MACO','MA'),    ('PORCAO','PO'),
        ('LI','LT'),      ('PACOTE','PA'))
 GROUP BY 1, 2
 ORDER BY 3 DESC;

-- Esperado: 7 linhas, somando 503.
--   UNIDADE -> UN   175
--   LITRO   -> LT   157
--   LITRO   -> LI    93
--   MACO    -> MA    44
--   PORCAO  -> PO    24
--   LI      -> LT     5
--   PACOTE  -> PA     5


-- ---------------------------------------------------------------------------
-- PASSO 2 - ALINHA
-- ---------------------------------------------------------------------------
UPDATE est_ficha_ingredientes fi
   SET unidade = p.unidade_uso
  FROM est_produtos p, est_fichas_tecnicas f
 WHERE fi.ingrediente_id = p.id
   AND fi.ficha_id       = f.id
   AND f.ativo           = true
   AND (upper(btrim(fi.unidade)), upper(btrim(p.unidade_uso))) IN (
        ('UNIDADE','UN'), ('LITRO','LT'), ('LITRO','LI'),
        ('MACO','MA'),    ('PORCAO','PO'),
        ('LI','LT'),      ('PACOTE','PA'));

-- Esperado: UPDATE 503


-- ---------------------------------------------------------------------------
-- PASSO 3 - CONFERE
-- ---------------------------------------------------------------------------
-- 3a) O PASSO 1 tem que voltar VAZIO agora.
SELECT count(*) AS ainda_sobrou
  FROM est_ficha_ingredientes fi
  JOIN est_produtos        p ON p.id = fi.ingrediente_id
  JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id
 WHERE f.ativo = true
   AND (upper(btrim(fi.unidade)), upper(btrim(p.unidade_uso))) IN (
        ('UNIDADE','UN'), ('LITRO','LT'), ('LITRO','LI'),
        ('MACO','MA'),    ('PORCAO','PO'),
        ('LI','LT'),      ('PACOTE','PA'));
-- Esperado: 0

-- 3b) O que continua divergente e o que foi DE PROPOSITO deixado para a cozinha.
SELECT upper(btrim(fi.unidade))    AS escrito_na_ficha,
       upper(btrim(p.unidade_uso)) AS diz_o_cadastro,
       count(*)                    AS linhas
  FROM est_ficha_ingredientes fi
  JOIN est_produtos        p ON p.id = fi.ingrediente_id
  JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id
 WHERE f.ativo = true
   AND upper(btrim(fi.unidade)) <> upper(btrim(p.unidade_uso))
 GROUP BY 1, 2
 ORDER BY 3 DESC;
-- Esperado: 299 linhas no total (169 de troca de grandeza + 130 de contagem
-- diferente). Todas estao na planilha de conferencia.
