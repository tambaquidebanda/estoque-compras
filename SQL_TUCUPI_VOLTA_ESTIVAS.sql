-- ============================================================================
-- SQL_TUCUPI_VOLTA_ESTIVAS.sql
--
-- Poe o PPC TUCUPI REDUZIDO de volta em COZINHA | ESTIVAS, que e o lugar certo.
--
-- O QUE ACONTECEU
-- O produto ja esta na estrutura em COZINHA|ESTIVAS. Em algum momento ele foi
-- marcado como EXCLUIDO da contagem e sumiu da tela. Sem saber disso, o
-- funcionario adicionou ele a mao em dois lugares errados:
--
--     COZINHA | HORTIFRUTI          (grupo errado)
--     ESTOQUE DA LOJA | ESTIVAS     (setor errado)
--
-- Isso fez o mesmo produto aparecer DUAS VEZES na tela. Contagem repetida do
-- mesmo cadastro nao soma: o sistema fica com o MAIOR valor e o outro some
-- calado (foi o problema corrigido em 31/08).
--
-- O CONSERTO E DESFAZER, NAO MOVER: tirar da lista de excluidos (a estrutura
-- ja tem ele no lugar certo) e apagar as duas adicoes.
--
-- POR QUE ISSO IMPORTA AGORA
-- Sao R$ 13,12/dia que hoje nao baixam, porque sem contagem o robo nao
-- descobre de qual setor o insumo sai. Rodando hoje, ele e contado a noite e
-- ja entra na baixa amanha.
--
-- ATENCAO: nao existe como desfazer exclusao pela tela. O painel de
-- divergencias promete isso na mensagem, mas ele pula os produtos excluidos.
-- Por isso precisa de SQL.
-- ============================================================================


-- ============================================================================
-- PASSO 1 - SO LEITURA. Confirma o estado antes de mexer.
-- ============================================================================

-- 1a) Ele esta na lista de excluidos? (esperado: 1 linha)
SELECT 'excluido' AS situacao, x AS nome
FROM inv_configuracoes, jsonb_array_elements_text(valor) x
WHERE chave = 'excluidos' AND x = 'PPC TUCUPI REDUZIDO';

-- 1b) Em quais grupos ele foi adicionado a mao? (esperado: as 2 linhas erradas)
SELECT k AS setor_grupo, v AS lista
FROM inv_configuracoes, jsonb_each(valor) AS t(k, v)
WHERE chave = 'adicoes' AND v @> '["PPC TUCUPI REDUZIDO"]'::jsonb;

-- 1c) Onde ele esta na estrutura? (esperado: Centro / COZINHA / ESTIVAS)
SELECT unid.key AS unidade, setor.key AS setor, grupo.key AS grupo
FROM inv_configuracoes c,
     jsonb_each(c.valor)      AS unid,
     jsonb_each(unid.value)   AS setor,
     jsonb_each(setor.value)  AS grupo
WHERE c.chave = 'estrutura'
  AND grupo.value @> '["PPC TUCUPI REDUZIDO"]'::jsonb;


-- ============================================================================
-- PASSO 2 - ESCREVE. Tira da lista de excluidos.
--
-- Remove SO esse nome. Os outros 79 ficam intactos.
-- ============================================================================
UPDATE inv_configuracoes
   SET valor = (SELECT jsonb_agg(x)
                  FROM jsonb_array_elements(valor) x
                 WHERE x <> '"PPC TUCUPI REDUZIDO"'::jsonb)
 WHERE chave = 'excluidos';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 3 - ESCREVE. Apaga a adicao em COZINHA | HORTIFRUTI.
--
-- Se a lista do grupo ficar vazia, a chave inteira sai (e o que a tela faz).
-- Nenhum outro grupo e tocado.
-- ============================================================================
WITH calc AS (
  SELECT COALESCE((SELECT jsonb_agg(x)
                     FROM jsonb_array_elements(valor -> 'COZINHA|HORTIFRUTI') x
                    WHERE x <> '"PPC TUCUPI REDUZIDO"'::jsonb), '[]'::jsonb) AS nova
    FROM inv_configuracoes WHERE chave = 'adicoes'
)
UPDATE inv_configuracoes c
   SET valor = CASE WHEN jsonb_array_length(calc.nova) = 0
                    THEN c.valor - 'COZINHA|HORTIFRUTI'
                    ELSE jsonb_set(c.valor, '{COZINHA|HORTIFRUTI}', calc.nova) END
  FROM calc
 WHERE c.chave = 'adicoes';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 4 - ESCREVE. Apaga a adicao em ESTOQUE DA LOJA | ESTIVAS.
-- ============================================================================
WITH calc AS (
  SELECT COALESCE((SELECT jsonb_agg(x)
                     FROM jsonb_array_elements(valor -> 'ESTOQUE DA LOJA|ESTIVAS') x
                    WHERE x <> '"PPC TUCUPI REDUZIDO"'::jsonb), '[]'::jsonb) AS nova
    FROM inv_configuracoes WHERE chave = 'adicoes'
)
UPDATE inv_configuracoes c
   SET valor = CASE WHEN jsonb_array_length(calc.nova) = 0
                    THEN c.valor - 'ESTOQUE DA LOJA|ESTIVAS'
                    ELSE jsonb_set(c.valor, '{ESTOQUE DA LOJA|ESTIVAS}', calc.nova) END
  FROM calc
 WHERE c.chave = 'adicoes';
-- Deve dizer UPDATE 1.


-- ============================================================================
-- PASSO 5 - CONFERENCIA. As tres devem voltar VAZIAS.
-- ============================================================================

-- 5a) Nao pode mais estar excluido.
SELECT x AS ainda_excluido
FROM inv_configuracoes, jsonb_array_elements_text(valor) x
WHERE chave = 'excluidos' AND x = 'PPC TUCUPI REDUZIDO';

-- 5b) Nao pode sobrar nenhuma adicao a mao.
SELECT k AS ainda_adicionado_em
FROM inv_configuracoes, jsonb_each(valor) AS t(k, v)
WHERE chave = 'adicoes' AND v @> '["PPC TUCUPI REDUZIDO"]'::jsonb;

-- 5c) Nenhum outro nome pode ter sumido da lista de excluidos.
--     Antes eram 80. Agora devem ser 79.
SELECT jsonb_array_length(valor) AS excluidos_agora
FROM inv_configuracoes WHERE chave = 'excluidos';


-- ============================================================================
-- DEPOIS DE RODAR
-- Abrir a tela de Contagem e conferir que o PPC TUCUPI REDUZIDO aparece
-- UMA VEZ SO, em COZINHA / ESTIVAS. Contar hoje a noite.
-- ============================================================================
