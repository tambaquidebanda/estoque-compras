-- ============================================================================
-- SQL_GUARNICAO_BAIAO_IGNORAR.sql
--
-- Fecha a fase 1 da guarnicao, que tinha sido aplicada pela metade.
--
-- O QUE ESTAVA ERRADO
-- Em 18/08/2026 as linhas de ARROZ e FAROFA foram marcadas 'ignorar' com a
-- observacao "guarnicao ja na ficha do prato". O BAIAO ficou de fora. Resultado:
-- quando o cliente pede Tambaqui de Banda e escolhe baiao, o modelo descontava
--   - arroz 0,26 pela ficha do prato (e o cliente nao comeu arroz)
--   - baiao 0,32 pela linha da escolha (correto)
-- Os dois. Sao 3.058 porcoes/mes descontadas duas vezes: +R$ 2.708/mes a mais
-- do que a casa consome.
--
-- O QUE ESTE ARQUIVO FAZ
-- Marca 'ignorar' as quatro linhas de baiao que sao ACOMPANHAMENTO (a escolha
-- do cliente entre arroz e baiao), igualando o tratamento ao do arroz e da
-- farofa. A guarnicao volta a ser descontada uma vez so, pela ficha do prato.
--
-- O QUE NAO MUDA
-- BAIAO DE DOIS (id 60) e BAIAO DE DOIS 500g (id 2854) continuam 'mapeado':
-- esses sao vendidos A PARTE, nao sao acompanhamento, e devem descontar mesmo.
--
-- O QUE ISTO CUSTA, DE PROPOSITO
-- Passa a descontar arroz onde o cliente comeu baiao. O erro inverte de sinal e
-- diminui: de +R$ 2.708/mes para -R$ 2.346/mes. Em quilo, o MP FEIJAO DE PRAIA
-- some da conta e o MP ARROZ sobra. E o preco de ficar coerente sem mexer no
-- motor da baixa a oito dias do paralelo.
--
-- COMO ISTO SE RESOLVE DE VERDADE (depois de 01/10, com numero na mao)
-- Coluna `baixa_estoque` em est_ficha_ingredientes, marcada false nas 80 linhas
-- de guarnicao das 31 fichas das 7 familias que tem escolha (Tambaqui de Banda,
-- de Casaca, Matrinxa, Costela frita e assada, Jaraqui, Sardinha). O
-- ingrediente continua contando no PRECO e para de contar na BAIXA. O paralelo
-- vai medir exatamente quanto isso vale antes de decidir.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confira o antes.
-- ============================================================================
SELECT icomanda_produto_id AS id, icomanda_nome, status, qtd_30d, obs
FROM pdv_map
WHERE icomanda_produto_id IN (692, 2577, 3034, 629, 60, 2854)
ORDER BY qtd_30d DESC;
-- Esperado: os quatro primeiros 'mapeado' (BAIAO GRANDE 1900, BAIAO 1124,
-- BAIAO PEQUENO 16, BAIAO 18) e os dois de DOIS tambem 'mapeado'.


-- ============================================================================
-- PASSO 2 - ESCREVE. So os quatro de acompanhamento.
-- ============================================================================
UPDATE pdv_map
   SET status = 'ignorar',
       obs = 'guarnicao ja na ficha do prato (fase 1 fechada 01/09) - '
             || 'acompanhamento, o cliente escolhe entre arroz e baiao',
       atualizado_em = now()
 WHERE icomanda_produto_id IN (692, 2577, 3034, 629)
   AND status <> 'ignorar';
-- Deve dizer UPDATE 4.


-- ============================================================================
-- PASSO 3 - CONFERENCIA.
-- ============================================================================
SELECT icomanda_produto_id AS id, icomanda_nome, status, qtd_30d
FROM pdv_map
WHERE upper(icomanda_nome) LIKE 'BAIA%' OR upper(icomanda_nome) LIKE 'BAI_O%'
ORDER BY status, qtd_30d DESC;
-- Esperado:
--   ignorar : BAIAO GRANDE 1900, BAIAO 1124, BAIAO 18, BAIAO PEQUENO 16
--   mapeado : BAIAO DE DOIS 57, BAIAO DE DOIS 500g 11


-- ============================================================================
-- PASSO 4 - SO LEITURA. Duas coisas para voce olhar, que eu nao mexi.
-- ============================================================================
-- O mesmo nome aparece duas vezes no PDV com tratamento OPOSTO. Nao mudei
-- porque nao sei se sao cardapios diferentes (salao x delivery) ou id antigo e
-- novo. Se forem a mesma coisa, um dos dois esta errado.
SELECT icomanda_produto_id AS id, icomanda_nome, status, qtd_30d
FROM pdv_map
WHERE icomanda_produto_id IN (68, 2576, 630, 61)
ORDER BY icomanda_nome, status;
--   ARROZ  id 68   mapeado    75/mes
--   ARROZ  id 2576 ignorar   222/mes
--   FAROFA id 61   mapeado    32/mes
--   FAROFA id 630  ignorar  2333/mes
