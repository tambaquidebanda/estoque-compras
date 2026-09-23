-- ============================================================================
-- COCA COMUM NAO BAIXA: falta o desempate de setor                (23/09/2026)
-- ============================================================================
--
-- O QUE ACONTECE
-- O robo da baixa descobre de qual setor descontar olhando QUEM CONTA o insumo
-- (baixa_estoque_pdv.py, setor_por_insumo). Se mais de um setor conta o mesmo
-- item e nao ha desempate gravado, ele NAO DESCONTA - de proposito, porque
-- escolher no chute tiraria estoque do setor errado.
--
-- MP COCA COLA LATA e contado no BAR e no DELIVERY, e nao tem desempate.
-- Por isso ele nunca teve uma unica baixa de venda desde que o robo ligou, em
-- 08/09/2026 - enquanto MP COCA COLA ZERO LATA, que e contado nos MESMOS dois
-- setores, baixa todo dia: o desempate dele ("BAR") esta gravado desde a
-- curadoria dos 18. A Coca comum ficou de fora daquela lista.
--
-- A PROVA: em 22/09 o PDV vendeu 25 COCA COLA ZERO 350ML LT e 18 COCA COLA
-- 350ML LT. O razao registrou -25 de MP COCA COLA ZERO LATA naquele dia, e
-- nada de MP COCA COLA LATA.
--
-- POR QUE "BAR"
-- E o mesmo criterio ja aceito para a Coca Zero: mesma geladeira, mesmo setor.
-- O delivery tira do estoque do bar.
--
-- COMO E FEITO
-- jsonb_set cirurgico: acrescenta UMA chave ao objeto que ja existe. NUNCA
-- reescrever `valor` inteiro - foi assim que se perderam produtos em Jun/2026.
--
-- COMO RODAR
-- Um PASSO por vez, conferindo o resultado antes do proximo.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O desempate de hoje e os que faltam.
-- ============================================================================

-- 1a) os desempates ja gravados
SELECT key AS insumo, value #>> '{}' AS setor_escolhido
FROM inv_configuracoes, jsonb_each(valor)
WHERE chave = 'baixa_setor_principal'
ORDER BY 1;

-- 1b) A LISTA QUE IMPORTA: todo insumo contado em mais de um setor nos ultimos
--     60 dias e SEM desempate. Nenhum destes esta baixando na venda.
WITH conta AS (
  SELECT ii.produto_id, array_agg(DISTINCT i.setor ORDER BY i.setor) AS setores
  FROM est_inventarios i
  JOIN est_inventario_itens ii ON ii.inventario_id = i.id
  WHERE i.data >= current_date - 60
    AND i.local = 'Centro'
    AND i.setor NOT IN ('ESTOQUE DA LOJA', 'ESTOQUE_LOJA')
    AND ii.produto_id IS NOT NULL
  GROUP BY ii.produto_id
),
desemp AS (
  SELECT key AS nome FROM inv_configuracoes, jsonb_each(valor)
  WHERE chave = 'baixa_setor_principal'
)
SELECT p.nome, c.setores
FROM conta c
JOIN est_produtos p ON p.id = c.produto_id
WHERE array_length(c.setores, 1) > 1
  AND p.nome NOT IN (SELECT nome FROM desemp)
ORDER BY p.nome;


-- ============================================================================
-- PASSO 2 - BACKUP. Nao pule.
-- ============================================================================

CREATE TABLE IF NOT EXISTS bkp_desempate_setor AS
SELECT chave, valor AS valor_antigo, now() AS salvo_em
FROM inv_configuracoes
WHERE chave = 'baixa_setor_principal';

SELECT jsonb_object_keys(valor_antigo) AS chaves_salvas FROM bkp_desempate_setor;


-- ============================================================================
-- PASSO 3 - O desempate da Coca comum
-- ============================================================================
-- jsonb_set com create_missing = true: acrescenta a chave e NAO toca nas outras 18.

UPDATE inv_configuracoes
SET    valor = jsonb_set(valor, '{MP COCA COLA LATA}', '"BAR"'::jsonb, true)
WHERE  chave = 'baixa_setor_principal';


-- ============================================================================
-- PASSO 4 - CONFERENCIA
-- ============================================================================

-- 4a) tem que voltar 19 chaves (eram 18), com a Coca comum apontando para BAR
SELECT COUNT(*) AS total_desempates,
       COUNT(*) FILTER (WHERE key = 'MP COCA COLA LATA') AS tem_a_coca_comum,
       max(value #>> '{}') FILTER (WHERE key = 'MP COCA COLA LATA') AS setor_da_coca_comum
FROM inv_configuracoes, jsonb_each(valor)
WHERE chave = 'baixa_setor_principal';

-- 4b) A PROVA QUE IMPORTA: nenhum desempate antigo se perdeu.
--     Tem que voltar ZERO linhas.
SELECT b.key AS sumiu_ou_mudou, b.value #>> '{}' AS era, c.valor -> b.key AS esta_agora
FROM bkp_desempate_setor, jsonb_each(valor_antigo) b
JOIN inv_configuracoes c ON c.chave = 'baixa_setor_principal'
WHERE c.valor -> b.key IS DISTINCT FROM b.value;


-- ============================================================================
-- DEPOIS DE RODAR
-- ============================================================================
-- O robo so olha esta chave quando roda. A baixa da Coca comum comeca na
-- proxima rodada, e vale para as vendas dali em diante - os dias que ja
-- passaram nao voltam sozinhos.


-- ============================================================================
-- VOLTAR ATRAS, se precisar
-- ============================================================================
-- UPDATE inv_configuracoes c SET valor = b.valor_antigo
--   FROM bkp_desempate_setor b WHERE b.chave = c.chave;
