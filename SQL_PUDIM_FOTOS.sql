-- SQL_PUDIM_FOTOS.sql — foto nos 3 cadastros de pudim separados em 25/11
--
-- Mesma foto que o pudim já usava (Biblioteca do Pensêra, ids 124/2770/2788 do iComanda,
-- arquivo do site do restaurante). Acha o cadastro pelo nome EXATO e só grava se cada
-- nome existir em UM produto de venda ativo. Só preenche quem está SEM foto.

-- ═══ PASSO 1 — CONFERIR (só leitura) ═══════════════════════════════════════════════
-- Esperado: 3 linhas, cada nome uma vez; "situacao" diz quem vai receber.
SELECT p.nome, p.categoria AS grupo,
       CASE WHEN coalesce(p.foto_url, '') = '' THEN 'vai receber' ELSE 'já tem foto (fica)' END AS situacao
FROM est_produtos p
WHERE p.tipo = 'VENDA' AND p.ativo
  AND upper(trim(p.nome)) IN ('PUDIM DE LEITE', 'PUDIM DE LEITE DELIVERY', 'PUDIM DE LEITE DELIVERY C/ DESCONTO')
ORDER BY p.nome;

-- ═══ PASSO 2 — GRAVAR ══════════════════════════════════════════════════════════════
DO $$
DECLARE
  nome text;
  n int;
BEGIN
  FOREACH nome IN ARRAY ARRAY['PUDIM DE LEITE', 'PUDIM DE LEITE DELIVERY', 'PUDIM DE LEITE DELIVERY C/ DESCONTO'] LOOP
    SELECT count(*) INTO n FROM est_produtos p
     WHERE upper(trim(p.nome)) = nome AND p.tipo = 'VENDA' AND p.ativo;
    IF n <> 1 THEN
      RAISE EXCEPTION 'Nada gravado: "%" existe em % produtos de venda ativos (precisa ser 1).', nome, n;
    END IF;
  END LOOP;

  UPDATE est_produtos p
     SET foto_url = 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'
   WHERE p.tipo = 'VENDA' AND p.ativo
     AND upper(trim(p.nome)) IN ('PUDIM DE LEITE', 'PUDIM DE LEITE DELIVERY', 'PUDIM DE LEITE DELIVERY C/ DESCONTO')
     AND coalesce(p.foto_url, '') = '';
END $$;

-- ═══ PASSO 3 — CONFERIR DEPOIS (só leitura) ═════════════════════════════════════════
SELECT p.nome, p.categoria AS grupo, p.foto_url
FROM est_produtos p
WHERE p.tipo = 'VENDA' AND p.ativo
  AND upper(trim(p.nome)) IN ('PUDIM DE LEITE', 'PUDIM DE LEITE DELIVERY', 'PUDIM DE LEITE DELIVERY C/ DESCONTO')
ORDER BY p.nome;
