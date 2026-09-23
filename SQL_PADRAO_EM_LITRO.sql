-- ============================================================================
-- PADRAO EM LITRO - o ultimo passo do "tudo em litro"            (23/09/2026)
-- ============================================================================
--
-- POR QUE
-- A contagem virou litro: a tela ja mostra LT e aceita casa decimal. O PADRAO nao
-- virou - ele continua contado em GARRAFA. E o pedido e `padrao - contado`.
-- Com a contagem em litro (numero menor) e o padrao em garrafa (numero maior), o
-- sistema pede MAIS do que precisa. Ex.: LICOR 43, garrafa de 700 ml, padrao 1.
-- O bar conta 0 e o sistema pede 1 litro onde deveria pedir 0,7 - R$ 89 a mais
-- num pedido so. Somando os 23 itens, R$ 714.49 por noite de padrao cheio.
--
-- A CONVERSAO
-- padrao em litro = padrao em garrafa x fator. E a mesma quantidade fisica escrita
-- na outra unidade: ninguem passa a ter mais nem menos estoque alvo.
--
-- ============================================================================
-- >>> A HORA DE RODAR IMPORTA <<<
-- ============================================================================
-- Contagem e padrao TEM que virar na MESMA noite.
--   * padrao em litro + contagem em garrafa = o sistema pede DE MENOS
--   * padrao em garrafa + contagem em litro = o sistema pede DE MAIS (e o de hoje)
-- Rode no dia em que o bar comecar a digitar a leitura da fita em litro, antes da
-- contagem da noite. Nao rode "para deixar pronto".
--
-- O QUE NAO ENTRA
-- Quem esta com fator 1 fica de fora: 1 garrafa ja e 1 litro, nada muda. Sao
-- BLACK LABEL, RED LABEL e VODKA ABSOLUT (garrafa de 1 litro, plausivel mas nao
-- medida) e XAROPE DE MEL COM ESPECIARIAS (esse ainda precisa da fita). Os
-- xaropes PPB da soda tambem: sao preparo, ja nascem em litro.
--
-- COMO E FEITO
-- Um jsonb_set POR ITEM, e a chave e montada no banco a partir do id do produto -
-- por isso nenhum nome com acento e digitado aqui. As outras 385 chaves de
-- `padroes` nao sao tocadas. NUNCA reescrever `valor` inteiro.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O de hoje e o que vai ficar.
-- ============================================================================

WITH alvo(pid, grupo, fator) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'DESTILADOS', 0.75),   -- MP APEROL 750 ML                 padrao 1 -> 0.75
  ('1eac7858-5712-4b8a-8ab0-6ce1c12d6866'::uuid, 'DESTILADOS', 0.97),   -- MP CACHACA AMBURANA              padrao 2 -> 1.94
  ('5c26a2e3-845d-473c-90b2-64dc5071f2a3'::uuid, 'DESTILADOS', 0.75),   -- MP CACHACA JAMBUCANA             padrao 4 -> 3
  ('12fea814-c339-474b-957a-0e1550412a31'::uuid, 'DESTILADOS', 0.7),   -- MP CACHACA TRADICIONAL           padrao 4,5 -> 2.8,3.5
  ('dc0aa62f-89c0-42d9-9b31-8313c2a5579b'::uuid, 'DESTILADOS', 0.7),   -- MP COINTREAL                     padrao 1 -> 0.7
  ('348f8e7e-917b-4d81-853f-cff3b5ac01a1'::uuid, 'DESTILADOS', 0.72),   -- MP CURACAU RED                   padrao 1 -> 0.72
  ('9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'::uuid, 'DESTILADOS', 0.72),   -- MP CURACAU BLUE                  padrao 1 -> 0.72
  ('11970412-9a4c-424c-a72f-c41ca6033ef9'::uuid, 'DESTILADOS', 0.66),   -- MP ESPUMANTE MOSCATEL            padrao 2 -> 1.32
  ('ff2788a6-aec3-4531-b766-da4f971e18f3'::uuid, 'DESTILADOS', 0.7),   -- MP LICOR 43                      padrao 1 -> 0.7
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'DESTILADOS', 0.75),   -- MP RUM BACARDI                   padrao 1 -> 0.75
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'DESTILADOS', 0.7),   -- MP SAGATIBA PURA 700ML           padrao 1 -> 0.7
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'DESTILADOS', 0.75),   -- MP TANQUERAY 750ML               padrao 1 -> 0.75
  ('dbfc101a-ada5-4223-9acd-bd9c2524ae83'::uuid, 'DESTILADOS', 0.75),   -- MP TEQUILA PRATA                 padrao 1 -> 0.75
  ('af2e33ae-e844-469e-b8b3-aaf379809e7f'::uuid, 'DESTILADOS', 0.75),   -- MP VINHO CABERNET SAUVIGNON      padrao 1 -> 0.75
  ('3c95a146-b5bd-4b21-88ea-403949ed2e5f'::uuid, 'DESTILADOS', 0.75),   -- MP VINHO TINTO SUAVE 750ML       padrao 2 -> 1.5
  ('ce74b177-5c8f-4b06-9bed-d516a2c87ed1'::uuid, 'DESTILADOS', 0.75),   -- MP VODKA KETEL ONE BOTANICAS     padrao 1 -> 0.75
  ('983ccdb0-d68f-4211-8700-794adb5b2296'::uuid, 'DESTILADOS', 0.998),   -- MP VODKA SMIRNORFF               padrao 2 -> 1.996
  ('c88c41db-2f97-4e5e-bb80-6c8babbb7834'::uuid, 'SODA AMAZONENSE', 1.5),   -- MP XAROPE DE GUARANA MAGISTRAL   padrao 1 -> 1.5
  ('0221c68f-d582-4fc4-96c7-337c53c4eda5'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE DE LARANJA             padrao 1 -> 0.7
  ('82c72946-a920-4104-b7b8-c5426b0c5b48'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE DE MORANGO             padrao 1 -> 0.7
  ('ab1d2041-541d-41d6-8ee9-5da0eef04aa4'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE GENGIBRE               padrao 1 -> 0.7
  ('9e8acc72-05af-4460-a6b7-5155f9e0cc83'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE LIMAO SICILIANO        padrao 1 -> 0.7
  ('b8107ccc-62b4-4f13-aa27-82e4b6e9857e'::uuid, 'DESTILADOS', 0.965)   -- MP YPIOCA OURO 965ML             padrao 1 -> 0.965
)
SELECT p.nome, a.fator,
       c.valor -> ('BAR|' || a.grupo || '|' || p.nome) AS padrao_hoje_em_garrafa,
       (SELECT jsonb_object_agg(d, to_jsonb(round((v #>> '{}')::numeric * a.fator, 3)))
        FROM jsonb_each(c.valor -> ('BAR|' || a.grupo || '|' || p.nome)) AS x(d, v))
         AS vai_virar_em_litro
FROM alvo a
JOIN est_produtos p ON p.id = a.pid
JOIN inv_configuracoes c ON c.chave = 'padroes'
WHERE c.valor -> ('BAR|' || a.grupo || '|' || p.nome) IS NOT NULL
ORDER BY p.nome;

-- quantas chaves `padroes` tem hoje (tem que continuar a mesma no PASSO 4)
SELECT COUNT(*) AS chaves_em_padroes
FROM inv_configuracoes, jsonb_object_keys(valor)
WHERE chave = 'padroes';


-- ============================================================================
-- PASSO 2 - BACKUP. Nao pule.
-- ============================================================================

CREATE TABLE IF NOT EXISTS bkp_padrao_litro AS
SELECT chave, valor AS valor_antigo, now() AS salvo_em
FROM inv_configuracoes
WHERE chave = 'padroes';

SELECT COUNT(*) AS chaves_salvas
FROM bkp_padrao_litro, jsonb_object_keys(valor_antigo);


-- ============================================================================
-- PASSO 3 - A conversao, um item por vez
-- ============================================================================

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    WITH alvo(pid, grupo, fator) AS (VALUES
  ('3954697a-df62-4656-b9aa-1d99f07da4d9'::uuid, 'DESTILADOS', 0.75),   -- MP APEROL 750 ML                 padrao 1 -> 0.75
  ('1eac7858-5712-4b8a-8ab0-6ce1c12d6866'::uuid, 'DESTILADOS', 0.97),   -- MP CACHACA AMBURANA              padrao 2 -> 1.94
  ('5c26a2e3-845d-473c-90b2-64dc5071f2a3'::uuid, 'DESTILADOS', 0.75),   -- MP CACHACA JAMBUCANA             padrao 4 -> 3
  ('12fea814-c339-474b-957a-0e1550412a31'::uuid, 'DESTILADOS', 0.7),   -- MP CACHACA TRADICIONAL           padrao 4,5 -> 2.8,3.5
  ('dc0aa62f-89c0-42d9-9b31-8313c2a5579b'::uuid, 'DESTILADOS', 0.7),   -- MP COINTREAL                     padrao 1 -> 0.7
  ('348f8e7e-917b-4d81-853f-cff3b5ac01a1'::uuid, 'DESTILADOS', 0.72),   -- MP CURACAU RED                   padrao 1 -> 0.72
  ('9fa4d92e-1e53-4e13-8915-0c3b09d1f7d5'::uuid, 'DESTILADOS', 0.72),   -- MP CURACAU BLUE                  padrao 1 -> 0.72
  ('11970412-9a4c-424c-a72f-c41ca6033ef9'::uuid, 'DESTILADOS', 0.66),   -- MP ESPUMANTE MOSCATEL            padrao 2 -> 1.32
  ('ff2788a6-aec3-4531-b766-da4f971e18f3'::uuid, 'DESTILADOS', 0.7),   -- MP LICOR 43                      padrao 1 -> 0.7
  ('fa42e4ef-7a10-4dbf-9a3c-168e511cd3d7'::uuid, 'DESTILADOS', 0.75),   -- MP RUM BACARDI                   padrao 1 -> 0.75
  ('9dc31ac2-ff24-43bc-9307-7380022bbe0c'::uuid, 'DESTILADOS', 0.7),   -- MP SAGATIBA PURA 700ML           padrao 1 -> 0.7
  ('7e63019e-5060-4052-85e8-32eaa003b24f'::uuid, 'DESTILADOS', 0.75),   -- MP TANQUERAY 750ML               padrao 1 -> 0.75
  ('dbfc101a-ada5-4223-9acd-bd9c2524ae83'::uuid, 'DESTILADOS', 0.75),   -- MP TEQUILA PRATA                 padrao 1 -> 0.75
  ('af2e33ae-e844-469e-b8b3-aaf379809e7f'::uuid, 'DESTILADOS', 0.75),   -- MP VINHO CABERNET SAUVIGNON      padrao 1 -> 0.75
  ('3c95a146-b5bd-4b21-88ea-403949ed2e5f'::uuid, 'DESTILADOS', 0.75),   -- MP VINHO TINTO SUAVE 750ML       padrao 2 -> 1.5
  ('ce74b177-5c8f-4b06-9bed-d516a2c87ed1'::uuid, 'DESTILADOS', 0.75),   -- MP VODKA KETEL ONE BOTANICAS     padrao 1 -> 0.75
  ('983ccdb0-d68f-4211-8700-794adb5b2296'::uuid, 'DESTILADOS', 0.998),   -- MP VODKA SMIRNORFF               padrao 2 -> 1.996
  ('c88c41db-2f97-4e5e-bb80-6c8babbb7834'::uuid, 'SODA AMAZONENSE', 1.5),   -- MP XAROPE DE GUARANA MAGISTRAL   padrao 1 -> 1.5
  ('0221c68f-d582-4fc4-96c7-337c53c4eda5'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE DE LARANJA             padrao 1 -> 0.7
  ('82c72946-a920-4104-b7b8-c5426b0c5b48'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE DE MORANGO             padrao 1 -> 0.7
  ('ab1d2041-541d-41d6-8ee9-5da0eef04aa4'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE GENGIBRE               padrao 1 -> 0.7
  ('9e8acc72-05af-4460-a6b7-5155f9e0cc83'::uuid, 'DESTILADOS', 0.7),   -- MP XAROPE LIMAO SICILIANO        padrao 1 -> 0.7
  ('b8107ccc-62b4-4f13-aa27-82e4b6e9857e'::uuid, 'DESTILADOS', 0.965)   -- MP YPIOCA OURO 965ML             padrao 1 -> 0.965
    )
    SELECT ('BAR|' || a.grupo || '|' || p.nome) AS k, a.fator AS f
    FROM alvo a JOIN est_produtos p ON p.id = a.pid
  LOOP
    UPDATE inv_configuracoes
    SET    valor = jsonb_set(valor, ARRAY[r.k],
             (SELECT jsonb_object_agg(d, to_jsonb(round((v #>> '{}')::numeric * r.f, 3)))
              FROM jsonb_each(valor -> r.k) AS x(d, v)))
    WHERE  chave = 'padroes'
      AND  valor -> r.k IS NOT NULL;
  END LOOP;
END $$;


-- ============================================================================
-- PASSO 4 - CONFERENCIA
-- ============================================================================

-- 4a) o numero de chaves nao pode ter mudado
SELECT (SELECT COUNT(*) FROM inv_configuracoes, jsonb_object_keys(valor) WHERE chave='padroes') AS agora,
       (SELECT COUNT(*) FROM bkp_padrao_litro, jsonb_object_keys(valor_antigo))                 AS antes;

-- 4b) A PROVA QUE IMPORTA: mudou SO o que estava na lista.
--     Tem que voltar exatamente os 23 itens, e nenhum outro.
SELECT b.key AS chave_que_mudou, b.value AS era, c.valor -> b.key AS esta_agora
FROM bkp_padrao_litro, jsonb_each(valor_antigo) b
JOIN inv_configuracoes c ON c.chave = 'padroes'
WHERE c.valor -> b.key IS DISTINCT FROM b.value
ORDER BY 1;


-- ============================================================================
-- VOLTAR ATRAS, se precisar
-- ============================================================================
-- UPDATE inv_configuracoes c SET valor = b.valor_antigo
--   FROM bkp_padrao_litro b WHERE b.chave = c.chave;
