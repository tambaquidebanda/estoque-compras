-- ============================================================================
-- GARRAFA DE VIAGEM: o desempate que faltava                      (23/09/2026)
-- ============================================================================
--
-- MC GARRAFA 500ML e contado no BAR e na COZINHA. Sem desempate, o robo da baixa
-- nao desconta de lugar nenhum - e este e o UNICO dos 13 ambiguos que a venda
-- realmente alcanca hoje: a ficha `EMBALAGEM GARRAFA P/ VIAGEM` usa ele, e essa
-- embalagem nao tem saldo proprio, entao a receita abre e chega na garrafa.
--
-- Os outros 12 nao travam nada por enquanto: nove materiais de consumo nao estao
-- em ficha nenhuma, as polpas de goiaba e manga so sao usadas pelos PPB XAROPE
-- GOIABA e PPB XAROPE MANGA (que tem saldo proprio, entao a receita para neles e
-- nunca chega na polpa), e MP COSTELA DE TAMBAQUI nao tem ficha nem pedido - e um
-- segundo cadastro ao lado de SA COSTELA DE TAMBAQUI, que e o que as fichas usam.
--
-- A DECISAO: BAR. O Wagner: "essa garrafa pra viagem sai do bar" (23/09/2026).
-- O dado sozinho nao decidia - em 30 dias a COZINHA pediu 34 (55%) e o BAR 28
-- (45%). Nos outros casos um lado ganhava de 90%; aqui quem decide e quem monta.
--
-- Mesmo metodo do SQL_DESEMPATE_COCA.sql: jsonb_set cirurgico, uma chave so.
-- NUNCA reescrever `valor` inteiro - foi assim que se perderam produtos em Jun/2026.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA
-- ============================================================================

-- 1a) os 19 desempates de hoje (a Coca comum entrou nesta mesma leva)
SELECT key AS insumo, value #>> '{}' AS setor_escolhido
FROM inv_configuracoes, jsonb_each(valor)
WHERE chave = 'baixa_setor_principal'
ORDER BY 1;

-- 1b) a garrafa ainda sem desempate: tem que voltar UMA linha, sem setor
SELECT p.nome,
       (SELECT valor -> p.nome FROM inv_configuracoes WHERE chave = 'baixa_setor_principal')
         AS desempate_hoje
FROM est_produtos p
WHERE p.nome = 'MC GARRAFA 500ML';


-- ============================================================================
-- PASSO 2 - BACKUP. Nao pule.
-- ============================================================================
-- Nome diferente do backup da Coca, para nao sobrescrever aquele.

CREATE TABLE IF NOT EXISTS bkp_desempate_garrafa AS
SELECT chave, valor AS valor_antigo, now() AS salvo_em
FROM inv_configuracoes
WHERE chave = 'baixa_setor_principal';

SELECT COUNT(*) AS chaves_salvas
FROM bkp_desempate_garrafa, jsonb_object_keys(valor_antigo);


-- ============================================================================
-- PASSO 3 - O desempate
-- ============================================================================

UPDATE inv_configuracoes
SET    valor = jsonb_set(valor, '{MC GARRAFA 500ML}', '"BAR"'::jsonb, true)
WHERE  chave = 'baixa_setor_principal';


-- ============================================================================
-- PASSO 4 - CONFERENCIA
-- ============================================================================

-- 4a) tem que voltar 20 chaves (eram 19), com a garrafa apontando para BAR
SELECT COUNT(*) AS total_desempates,
       max(value #>> '{}') FILTER (WHERE key = 'MC GARRAFA 500ML') AS setor_da_garrafa
FROM inv_configuracoes, jsonb_each(valor)
WHERE chave = 'baixa_setor_principal';

-- 4b) A PROVA QUE IMPORTA: nenhum desempate antigo se perdeu.
--     Tem que voltar ZERO linhas.
SELECT b.key AS sumiu_ou_mudou, b.value #>> '{}' AS era, c.valor -> b.key AS esta_agora
FROM bkp_desempate_garrafa, jsonb_each(valor_antigo) b
JOIN inv_configuracoes c ON c.chave = 'baixa_setor_principal'
WHERE c.valor -> b.key IS DISTINCT FROM b.value;


-- ============================================================================
-- DEPOIS DE RODAR
-- ============================================================================
-- Vale da proxima rodada do robo em diante. Os dias que ja passaram nao voltam.


-- ============================================================================
-- VOLTAR ATRAS, se precisar
-- ============================================================================
-- UPDATE inv_configuracoes c SET valor = b.valor_antigo
--   FROM bkp_desempate_garrafa b WHERE b.chave = c.chave;
