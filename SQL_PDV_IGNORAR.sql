-- =============================================================
-- pdv_map: marcar como 'ignorar' as linhas que causariam BAIXA EM DOBRO
-- Levantado em 18/08/2026 sobre 10 dias de comandas do iComanda.
-- Cirurgico: so mexe em status (e escreve rastro em obs) das linhas
-- listadas. Nao apaga nada, nao toca em produto_id / setor / fator,
-- nao toca em estoque.
-- =============================================================


-- PASSO 1: conferir antes. Rode SO este select e leia o resultado.

select icomanda_produto_id, icomanda_nome, status, setor, qtd_30d
  from pdv_map
 where icomanda_produto_id in (337,2306,568,2176,2453,2204,610,1631,
                               630,28,2576,58,2872,1726)
 order by qtd_30d desc;


-- PASSO 2: grupo 1, composicao interna do iComanda.
-- O PDV tem ficha propria e emite os insumos dele como linha a R$ 0,00.
-- Nosso sistema ja explode a ficha; mapear estes conta o insumo 2 vezes.
-- Reconheciveis pelo prefixo MP/SA/PPC e pela quantidade quebrada.
--   337  MP SORVETE DE BAUNILHA     (acompanha COMPOTE-SE DE CUPUACU)
--   2306 SA COMPOTA DE CUPUACU 1kg  (idem)
--   568  PPC BAIAO DE DOIS          (acompanha BAIAO DE DOIS, 14 de 14)
--   2176 SA CASTANHA LASCA 50g      (acompanha CHOCUCA, 14 de 14)
--   2453 PPC MACARRAO COZIDO        (acompanha MACARRAO)
--   2204 PPC PURE DE MACAXEIRA COM BATATA
--   610  PPC OLEO DE URUCUM         (0,03 em 10 dias)
--   1631 PPC PASTA DE ALHO          (0,01 em 10 dias)

update pdv_map
   set status = 'ignorar',
       obs = coalesce(obs || ' | ', '') || 'composicao interna do PDV (18/08)',
       atualizado_em = now()
 where icomanda_produto_id in (337,2306,568,2176,2453,2204,610,1631);


-- PASSO 3: grupo 2, guarnicao que JA ESTA na ficha do prato.
-- Confirmado abrindo as fichas: TAMBAQUI DE BANDA tem PPC FAROFA e
-- PPC ARROZ COZIDO; FRANGO ASSADO + 2 ACOMP tem PPC ARROZ COZIDO,
-- PPC FAROFA e SA MOLHO BBQ.
-- TEMPORARIO: na fase 2, ao tirar a guarnicao das 10 fichas, estas
-- voltam para 'mapeado'.
--   630  FAROFA             784 em 10d, ficha tem PPC FAROFA
--   28   ARROZ GRANDE       178 em 10d, ficha tem PPC ARROZ COZIDO
--   2576 ARROZ               88 em 10d
--   58   ARROZ PEQUENO        1 em 10d
--   2872 MOLHO BBQ           16 em 10d, ficha do frango tem SA MOLHO BBQ
--   1726 MIX ARROZ E BAIAO   53 em 10d, ficha = ARROZ GRANDE + BAIAO GRANDE

update pdv_map
   set status = 'ignorar',
       obs = coalesce(obs || ' | ', '') || 'guarnicao ja na ficha do prato, rever na fase 2 (18/08)',
       atualizado_em = now()
 where icomanda_produto_id in (630,28,2576,58,2872,1726);


-- PASSO 4: conferir depois.
-- Esperado: 'ignorar' sobe de 15 para 29 linhas.

select status, count(*) as linhas, sum(qtd_30d) as vendas_30d
  from pdv_map
 group by status
 order by status;
