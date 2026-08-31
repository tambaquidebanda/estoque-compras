-- ============================================================================
-- SQL_INATIVAR_FICHAS_MORTAS.sql
--
-- Inativa as 3 fichas que sobraram com linha de ingrediente vazia e que NAO
-- VENDEM. Sao o resto da importacao das fichas: a linha ficou apontando para
-- nada, o robo pula em silencio, e o prato nunca aparece no PDV.
--
--   SA CAMARAO COM CATUPIRY 4 UNID
--   EMPANADINHO DE PIRARUCU COM PURE
--   EMPANADINHO DE PIRARUCU COM FRITAS
--
-- As duas que VENDIAM ja foram consertadas pelo Wagner em 31/08/2026, com o
-- SA ISCA DE PIRARUCU FRESCO 80G: ISCA DE PIRARUCU KIDS COM FRITAS (37/30d) e
-- COM PURE (13/30d). Essas tres nao tem contrapartida no PDV.
--
-- CONFERIDO ANTES DE ESCREVER (31/08/2026)
--   nenhuma e usada como ingrediente em ficha ativa  -> inativar nao muda calculo
--   nenhuma aparece em pdv_map (nem mapeado, nem pendente, nem ignorar)
--   SA CAMARAO COM CATUPIRY 4 UNID TEM SALDO (e contado). Para o robo isso ja
--     fazia dele uma folha: a recursao para em item contado e nunca usava a
--     ficha dele. Inativar ali e ainda mais inofensivo.
--
-- O QUE MUDA: o relatorio Saude das Fichas para de apontar as 3, e os graves
-- caem de 5 para 0. O calculo da baixa nao muda em nada - esses pratos nao
-- vendem, entao nunca entravam na conta.
--
-- O QUE NAO MUDA: os produtos continuam existindo e o historico fica intacto.
-- So a ficha sai de circulacao. Para voltar atras, e trocar false por true.
--
-- Uso o ID da ficha, nao o nome: e exato e evita acento em arquivo ASCII.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confirma que continua seguro inativar.
-- ============================================================================
WITH alvo (ficha_id) AS (VALUES
  ('bb697ec1-c6dc-469f-8c9b-f8f10308f1c7'::uuid),   -- SA CAMARAO COM CATUPIRY 4 UNID
  ('673939c7-a667-45ce-99e4-539ae38df2eb'::uuid),   -- EMPANADINHO DE PIRARUCU COM PURE
  ('aa32ae8e-5507-4a58-80c1-f51d8692c795'::uuid)    -- EMPANADINHO DE PIRARUCU COM FRITAS
)
SELECT p.nome,
       f.ativo                                        AS ficha_ativa,
       (SELECT count(*) FROM est_ficha_ingredientes i
         WHERE i.ficha_id = f.id
           AND i.ingrediente_id IS NULL)              AS linhas_vazias,
       (SELECT count(*) FROM est_ficha_ingredientes i
          JOIN est_fichas_tecnicas g ON g.id = i.ficha_id AND g.ativo
         WHERE i.ingrediente_id = f.produto_id)       AS usado_em_ficha_ativa,
       (SELECT count(*) FROM pdv_map m
         WHERE m.produto_id = f.produto_id)           AS linhas_no_pdv
FROM alvo a
JOIN est_fichas_tecnicas f ON f.id = a.ficha_id
JOIN est_produtos p        ON p.id = f.produto_id;

-- Esperado: ficha_ativa = true, linhas_vazias = 1, usado_em_ficha_ativa = 0 e
-- linhas_no_pdv = 0 nas tres. Se alguma vier diferente, PARE e me avise.


-- ============================================================================
-- PASSO 2 - ESCREVE. So mexe em ficha que ainda esta ativa.
-- ============================================================================
UPDATE est_fichas_tecnicas
   SET ativo = false
 WHERE id IN ('bb697ec1-c6dc-469f-8c9b-f8f10308f1c7',
              '673939c7-a667-45ce-99e4-539ae38df2eb',
              'aa32ae8e-5507-4a58-80c1-f51d8692c795')
   AND ativo = true;
-- Deve dizer UPDATE 3.


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Nenhuma ficha ATIVA pode sobrar com linha vazia.
-- ============================================================================
SELECT p.nome, f.id AS ficha_id, count(*) AS linhas_vazias
FROM est_fichas_tecnicas f
JOIN est_ficha_ingredientes i ON i.ficha_id = f.id AND i.ingrediente_id IS NULL
JOIN est_produtos p ON p.id = f.produto_id
WHERE f.ativo
GROUP BY p.nome, f.id
ORDER BY p.nome;
-- Deve voltar ZERO linha.
