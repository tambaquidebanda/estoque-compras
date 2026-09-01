-- ============================================================================
-- SQL_DESEMPATE_CERVEJA.sql
--
-- Diz de qual setor sai a cerveja em garrafa, para o robo poder baixar.
--
-- POR QUE PRECISA
-- A partir de 01/09/2026 o robo descobre o setor de cada insumo olhando ONDE O
-- PRODUTO FOI CONTADO (est_inventario_itens, por produto_id), e nao mais a
-- configuracao da tela. Com isso, tres cervejas apareceram contadas em DOIS
-- setores - BAR e DELIVERY - e o robo se recusa a escolher sozinho:
--
--   MP STELLA ARTOIS 600ML   R$ 106,09/dia
--   MP SPATEN 600ml          R$  87,45/dia
--   MP BUDWEISER LN          R$  13,93/dia
--                            R$ 207,47/dia parados
--
-- O Wagner confirmou em 01/09: cerveja em garrafa sai do BAR. A contagem no
-- DELIVERY foi feita no setor errado, e ele ja reforcou isso com a equipe.
--
-- `baixa_setor_principal` e o mecanismo que ja existe para isso, com 15 entradas
-- desde agosto. Estas sao a 16a, 17a e 18a.
--
-- ATENCAO PARA O FUTURO: esta chave e indexada por NOME do produto. Se o nome
-- mudar no cadastro, o desempate para de valer em silencio - foi exatamente
-- assim que a lista `excluidos` apodreceu (56 dos 80 nomes nao existem mais).
-- Enquanto for por nome, revisar esta chave quando renomear produto.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O que ja esta la.
-- ============================================================================
SELECT jsonb_pretty(valor) AS desempates_hoje
FROM inv_configuracoes WHERE chave = 'baixa_setor_principal';


-- ============================================================================
-- PASSO 2 - ESCREVE. Acrescenta as tres. Nao mexe nas 15 existentes.
--
-- O `||` sobrescreve so as chaves iguais; as outras ficam intactas. Rodar de
-- novo nao duplica.
-- ============================================================================
UPDATE inv_configuracoes
   SET valor = valor || jsonb_build_object(
         'MP STELLA ARTOIS 600ML', 'BAR',
         'MP SPATEN 600ml',        'BAR',
         'MP BUDWEISER LN',        'BAR')
 WHERE chave = 'baixa_setor_principal';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 3 - CONFERENCIA. Devem aparecer 18 entradas, as tres novas com BAR.
-- ============================================================================
SELECT count(*) AS total_desempates
FROM inv_configuracoes, jsonb_each_text(valor)
WHERE chave = 'baixa_setor_principal';

SELECT key AS produto, value AS setor
FROM inv_configuracoes, jsonb_each_text(valor)
WHERE chave = 'baixa_setor_principal'
  AND key IN ('MP STELLA ARTOIS 600ML', 'MP SPATEN 600ml', 'MP BUDWEISER LN');
-- Esperado: as tres com BAR. Repare que 'MP SPATEN 600ml' termina em minusculo
-- de proposito - e assim que esta no cadastro.
