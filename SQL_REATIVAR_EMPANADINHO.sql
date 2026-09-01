-- ============================================================================
-- SQL_REATIVAR_EMPANADINHO.sql
--
-- Desfaz parte do SQL_INATIVAR_FICHAS_MORTAS.sql: reativa as duas fichas do
-- EMPANADINHO DE PIRARUCU (COM FRITAS e COM PURE).
--
-- POR QUE EU ERREI
-- Inativei porque esses pratos nao aparecem em nenhuma das 445 linhas do
-- `pdv_map`. Mas o `pdv_map` foi semeado da venda que o robo processa, e o robo
-- processa SO a Loja Centro (BAIXA_UNIDADE_PDV). O empanadinho vende no
-- DELIVERY DO PARQUE 10 - por isso nao estava la.
--
-- "Nao esta no pdv_map" NAO quer dizer "nao vende". Quer dizer "o robo do
-- Centro nunca viu". Sao coisas diferentes e eu tratei como iguais.
--
-- Nada foi perdido: `ativo = false` nao apaga ingrediente nenhum. As duas
-- fichas continuam com as 8 e 9 linhas que sempre tiveram.
--
-- DEPOIS DE REATIVAR, elas voltam para a lista de GRAVES do relatorio Saude das
-- Fichas, com "Linha sem ingrediente" - e esta certo. Sao o mesmo caso das
-- iscas kids: falta o SA ISCA DE PIRARUCU FRESCO 80G, na quantidade 1,0.
-- Se for a mesma porcao, e so trocar a linha vazia pelo SA, como voce ja fez
-- nas duas iscas.
--
-- O SA CAMARAO COM CATUPIRY 4 UNID continua inativo, e agora por confirmacao do
-- proprio Wagner (01/09): nao vende mais. Nenhuma ficha ativa usa aquele, e a
-- quantidade perdida (4,0) nao batia com o padrao da irma de 6 unidades, que
-- usa camarao em quilo (0,06).
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. O estado antes.
-- ============================================================================
SELECT p.nome, f.id AS ficha_id, f.ativo, f.rendimento,
       (SELECT count(*) FROM est_ficha_ingredientes i WHERE i.ficha_id = f.id) AS ingredientes,
       (SELECT count(*) FROM est_ficha_ingredientes i
         WHERE i.ficha_id = f.id AND i.ingrediente_id IS NULL) AS linhas_vazias
FROM est_fichas_tecnicas f
JOIN est_produtos p ON p.id = f.produto_id
WHERE f.id IN ('673939c7-a667-45ce-99e4-539ae38df2eb',    -- COM PURE
               'aa32ae8e-5507-4a58-80c1-f51d8692c795');   -- COM FRITAS
-- Esperado: ativo = false, 9 e 8 ingredientes, 1 linha vazia em cada.


-- ============================================================================
-- PASSO 2 - ESCREVE. Reativa as duas.
-- ============================================================================
UPDATE est_fichas_tecnicas
   SET ativo = true
 WHERE id IN ('673939c7-a667-45ce-99e4-539ae38df2eb',
              'aa32ae8e-5507-4a58-80c1-f51d8692c795')
   AND ativo = false;
-- Deve dizer UPDATE 2.


-- ============================================================================
-- PASSO 3 - CONFERENCIA. As duas ativas, e nenhum produto com ficha duplicada.
-- ============================================================================
SELECT p.nome, count(*) AS fichas_ativas
FROM est_fichas_tecnicas f
JOIN est_produtos p ON p.id = f.produto_id
WHERE f.ativo
  AND p.nome ILIKE 'EMPANADINHO DE PIRARUCU%'
GROUP BY p.nome
ORDER BY p.nome;
-- Esperado: COM FRITAS = 1 e COM PURE = 1.
-- Se aparecer 2 em alguma, foi criada uma ficha nova pela tela enquanto a
-- antiga estava inativa - me avise que eu resolvo qual fica.
