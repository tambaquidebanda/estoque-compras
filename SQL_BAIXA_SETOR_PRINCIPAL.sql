-- ============================================================================
-- SETOR PRINCIPAL DOS INSUMOS CONTADOS EM MAIS DE UM SETOR
--
-- A baixa do PDV tira o insumo do setor onde a CONTAGEM diz que ele fica.
-- Quando o mesmo insumo aparece na lista de dois ou tres setores, o robo nao
-- adivinha: ele simplesmente NAO baixa, ate alguem dizer qual e o principal.
-- Esta chave e essa resposta.
--
-- Cria uma chave NOVA em inv_configuracoes ('baixa_setor_principal').
-- NAO toca em 'estrutura', 'adicoes', 'excluidos' nem 'mapeamentos'.
--
-- 14 insumos confirmados em 22/08/2026 (contagem e saldo concordavam nos dois).
-- FALTA a SA COSTELA DE TAMBAQUI (R$ 15.552/30d): churrasqueira com saldo 61 e
-- cozinha com saldo sempre 0 - decidir na loja, olhando a prateleira.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASSO 1 - SO LEITURA. O que existe hoje.
-- Se 'baixa_setor_principal' ja aparecer aqui, o passo 2 vai SUBSTITUIR o
-- conteudo dela. Confira antes.
-- ----------------------------------------------------------------------------
SELECT chave,
       jsonb_typeof(valor)                       AS tipo,
       coalesce(jsonb_array_length(
         CASE WHEN jsonb_typeof(valor)='array' THEN valor END), 0) AS itens_array,
       length(valor::text)                       AS tamanho
FROM inv_configuracoes
ORDER BY chave;


-- ----------------------------------------------------------------------------
-- PASSO 2 - GRAVA OS 14.
-- ----------------------------------------------------------------------------
INSERT INTO inv_configuracoes (chave, valor)
VALUES ('baixa_setor_principal', '{
    "MP ACUCAR": "COZINHA",
    "MP BANANA PACOVA": "COZINHA",
    "MP CANELA EM PO": "BAR",
    "MP CEBOLA": "COZINHA",
    "MP COCA COLA ZERO LATA": "BAR",
    "MP GUARANA ANTARTICA LATA": "BAR",
    "MP JAMBU": "COZINHA",
    "MP LEITE EM PO INTEGRAL": "COZINHA",
    "MP LEITE LIQUIDO INTEGRAL": "COZINHA",
    "MP LIMAO": "COZINHA",
    "MP MARGARINA": "COZINHA",
    "MP OLEO COMPOSTO": "COZINHA",
    "MP PIMENTA DE CHEIRO": "COZINHA",
    "MP SAL REFINADO": "COZINHA"
}'::jsonb)
ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor;


-- ----------------------------------------------------------------------------
-- PASSO 3 - CONFERENCIA. Deve listar exatamente os 14 nomes abaixo.
--
-- Os nomes vao SEM ACENTO de proposito. O robo compara normalizando (tira acento
-- e maiuscula), entao "MP ACUCAR" casa com "MP ACUCAR" e "MP LIMAO" casa com
-- "MP LIMAO". Os 14 ja foram conferidos um a um contra est_produtos: todos
-- casaram com exatamente um produto, nenhum ambiguo, nenhum sobrando.
-- ----------------------------------------------------------------------------
SELECT key AS insumo, value #>> '{}' AS setor
FROM inv_configuracoes, jsonb_each(valor)
WHERE chave = 'baixa_setor_principal'
ORDER BY 2, 1;


-- ============================================================================
-- PASSO 4 - A COSTELA DE TAMBAQUI (decidido em 27/08/2026)
--
-- Era o unico dos 15 ambiguos que faltava, e o unico em que os numeros de saldo
-- nao decidiam sozinhos: os dois setores contam e os dois tem peca na prateleira
-- (COZINHA 15, CHURRASQUEIRA 21, ESTOQUE DA LOJA 150 em 27/08).
--
-- Decidiu-se por CHURRASQUEIRA, com duas medicoes independentes que batem:
--
--   1. Explodindo a venda real de 14 dias pela ficha tecnica - 502 pecas:
--        367 (73%) vem de prato grelhado  -> COSTELA ASSADA DELIVERY (357),
--            CANTOR (6), CALDEIRADA ASSADA (4)
--        135 (27%) vem de prato de cozinha -> TUCUPI COM JAMBU (48), FRITA (27),
--            CALDEIRADA COZIDA (28), SALADA CAESAR (20), ESCABECHE (12)
--
--   2. O que cada setor PEDIU ao estoque nos mesmos 14 dias:
--        CHURRASQUEIRA 358 pecas (74%)   COZINHA 128 pecas (26%)
--
-- Duas fontes que nao se conversam - o cardapio vendido e o pedido interno que
-- o setor digita - chegam na mesma divisao, com 2% de diferenca. A churrasqueira
-- e' quem gasta a costela.
--
-- Os 27% da cozinha nao se perdem: a contagem diaria dela continua corrigindo o
-- saldo, e a diferenca aparece como variacao do setor, nao como buraco.
--
-- O comando ABAIXO SO ACRESCENTA a chave nova. O operador || mescla no jsonb
-- existente - as outras 14 entradas ficam intactas. NAO reescreve o objeto.
-- ============================================================================
UPDATE inv_configuracoes
   SET valor = valor || '{"SA COSTELA DE TAMBAQUI": "CHURRASQUEIRA"}'::jsonb
WHERE chave = 'baixa_setor_principal'
RETURNING chave, jsonb_pretty(valor) AS valor_final;
