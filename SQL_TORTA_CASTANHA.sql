-- ============================================================================
-- SQL_TORTA_CASTANHA.sql
--
-- A contagem da torta de cupuacu com castanha cai no PRATO, nao no insumo.
--
-- O QUE ESTA ERRADO
-- Existem dois cadastros com nomes parecidos:
--
--   TORTA DE CUPUACU C/ CASTANHA    [689beba1]  cat SOBREMESAS BAR
--       -> e o PRATO que o PDV vende (codigos 1225 e 2774)
--       -> mas tem 81 contagens e saldo BAR = 18
--
--   MP TORTA CUPUACU COM CASTANHA   [d4be9706]  cat MP SOBREMESA
--       -> e o INSUMO que a ficha do prato usa
--       -> criado em 01/09/2026, ZERO contagens, nenhum saldo
--
-- A tela de contagem mostra o nome do MP, mas grava no prato, por causa desta
-- linha em inv_configuracoes['mapeamentos']:
--
--   "MP TORTA CUPUACU COM CASTANHA": "TORTA DE CUPUACU C/ CASTANHA"
--
-- Esse mapeamento e mais velho que o MP. Quando o MP foi criado ontem, o
-- mapeamento continuou desviando a contagem para o prato.
--
-- O IRMAO DE CHOCOLATE PROVA QUE E ISSO
--   MP TORTA CUPUACU COM CHOCOLATE  [15ea73e2]  sem mapeamento, 81 contagens,
--                                               saldo BAR = 5      <- certo
--   TORTA DE CUPUACU C/ CHOCOLATE   [13222127]  0 contagens, sem saldo
--                                                                  <- certo
-- No castanha esta invertido.
--
-- EFEITO HOJE
--   - o robo pede MP TORTA CUPUACU COM CASTANHA, que nao tem setor nenhum,
--     e R$ 9,29/dia ficam parados sem baixar;
--   - os 18 no BAR do prato estao congelados: nenhuma ficha consome esse
--     produto, entao aquele saldo nunca se mexe.
--
-- O CONSERTO
--   PASSO 2 apaga o mapeamento. A linha da tela passa a resolver no MP, igual
--           ao chocolate. A contagem de hoje a noite ja cai no lugar certo.
--   PASSO 3 apaga o saldo fantasma do prato.
--
-- Nao mexe em contagem passada nem em ficha.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confirmar o diagnostico antes de mexer.
-- ============================================================================

-- 1a) o mapeamento culpado
SELECT valor -> 'MP TORTA CUPUACU COM CASTANHA' AS destino_hoje
FROM inv_configuracoes WHERE chave = 'mapeamentos';
-- Esperado: "TORTA DE CUPUACU C/ CASTANHA"

-- 1b) os dois cadastros lado a lado
SELECT p.id, p.nome, p.categoria, p.ativo,
       (SELECT count(*) FROM est_inventario_itens i WHERE i.produto_id = p.id) AS contagens,
       (SELECT string_agg(s.local || '=' || s.saldo, ' | ')
          FROM est_saldo_local s WHERE s.produto_id = p.id) AS saldo
FROM est_produtos p
WHERE upper(p.nome) LIKE '%TORTA%CUPUACU%CASTANHA%'
ORDER BY p.nome;
-- Esperado: o prato com ~81 contagens e saldo BAR=18,
--           o MP com 0 contagens e saldo nulo.

-- 1c) quem usa o MP como ingrediente (deve ser a ficha do proprio prato)
SELECT dono.nome AS ficha_de, fi.quantidade, ing.nome AS ingrediente
FROM est_ficha_ingredientes fi
JOIN est_fichas_tecnicas f ON f.id = fi.ficha_id
JOIN est_produtos dono     ON dono.id = f.produto_id
JOIN est_produtos ing      ON ing.id = fi.ingrediente_id
WHERE upper(ing.nome) = 'MP TORTA CUPUACU COM CASTANHA';
-- Esperado: 1 linha - TORTA DE CUPUACU C/ CASTANHA usa 1 do MP.


-- ============================================================================
-- PASSO 2 - ESCREVE. Apaga so essa chave do mapeamentos.
--
-- O operador `-` remove uma chave do jsonb e deixa todas as outras intactas.
-- Rodar de novo nao da erro (a chave ja nao esta la).
-- ============================================================================
UPDATE inv_configuracoes
   SET valor = valor - 'MP TORTA CUPUACU COM CASTANHA'
 WHERE chave = 'mapeamentos';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 3 - ESCREVE. Apaga o saldo fantasma do PRATO.
--
-- So do prato vendido no PDV, e so a linha de saldo. A contagem historica
-- (est_inventario_itens) fica intacta - e registro do que foi contado.
-- ============================================================================
DELETE FROM est_saldo_local
 WHERE produto_id = (SELECT id FROM est_produtos
                      WHERE upper(nome) = 'TORTA DE CUPUACU C/ CASTANHA'
                      LIMIT 1);
-- Esperado: DELETE 1 ou DELETE 2 (BAR e, se existir, ESTOQUE_LOJA).


-- ============================================================================
-- PASSO 4 - CONFERENCIA.
-- ============================================================================

-- 4a) o mapeamento sumiu
SELECT valor ? 'MP TORTA CUPUACU COM CASTANHA' AS ainda_existe
FROM inv_configuracoes WHERE chave = 'mapeamentos';
-- Esperado: false

-- 4b) o prato ficou sem saldo, o MP ainda sem saldo (a contagem de hoje cria)
SELECT p.nome,
       (SELECT count(*) FROM est_saldo_local s WHERE s.produto_id = p.id) AS linhas_de_saldo
FROM est_produtos p
WHERE upper(p.nome) IN ('TORTA DE CUPUACU C/ CASTANHA', 'MP TORTA CUPUACU COM CASTANHA')
ORDER BY p.nome;
-- Esperado: as duas com 0. A contagem desta noite cria a do MP.

-- 4c) a torta continua na tela, em BAR / SOBREMESAS
SELECT u.key AS unidade, x AS nome_na_tela
FROM inv_configuracoes,
     jsonb_each(valor) AS u,
     jsonb_array_elements_text(u.value #> ARRAY['BAR','SOBREMESAS']) AS t(x)
WHERE chave = 'estrutura'
  AND x = 'MP TORTA CUPUACU COM CASTANHA';
-- Esperado: 4 linhas, uma por unidade. Nada some da tela.
