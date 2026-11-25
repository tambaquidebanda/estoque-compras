-- ==========================================================================
-- PRECIFICACAO - campos novos no cadastro de produtos + fotos + acesso
-- ==========================================================================
-- POR QUE
--   O modulo de Precificacao (menu proprio no Estoque) le tudo do cadastro do
--   produto. Faltavam duas informacoes que so o cadastro deve guardar:
--     foto_url   - foto do prato (fonte unica: ficha, cardapio e precificacao
--                  leem daqui; a Precificacao nunca cadastra foto)
--     is_revenda - item comprado pronto e revendido (refrigerante, cerveja,
--                  chopp, agua, sobremesa comprada). Preco minimo dele e
--                  custo / CMV alvo (hoje 0,40), nao o markup de producao.
--   "Sem ficha = revenda" nao serve: Coca, Corona etc. tem ficha 1:1 para dar
--   baixa no estoque. Por isso o flag e explicito.
--
-- ESCOPO
--   PASSO 1: so leitura - lista candidatos a revenda para conferir.
--   PASSO 2: cria as duas colunas (nao altera nenhum dado existente).
--   PASSO 3: cria o bucket de fotos "produtos" e as permissoes dele.
--   PASSO 4: libera o menu Precificacao para o SEU usuario (os demais voce
--            marca pela tela Configuracoes > Usuarios > Permissoes).
--   PASSO 5: (opcional) marca como revenda os candidatos que voce aprovar.
--
-- Rodar PASSO 1 primeiro. Ele nao altera nada.
-- Pode rodar o arquivo inteiro de novo sem estrago (tudo e "if not exists").
-- ==========================================================================


-- ---------------------------------------------------------------- PASSO 1
-- Candidatos a REVENDA: produto de cardapio (VENDA) ativo que
--   (a) nao tem ficha ativa, ou
--   (b) tem ficha com UM ingrediente so, e esse ingrediente e comprado
--       pronto (MP/MC) - ou seja, o prato e o proprio item comprado.
-- Confira a lista: nem todo item daqui e revenda (ex.: acompanhamento simples).
SELECT p.nome,
       p.categoria                    AS grupo,
       p.custo_comp,
       p.preco_venda,
       CASE WHEN f.id IS NULL THEN 'sem ficha'
            ELSE 'ficha 1:1 com ' || i.nome END AS motivo
FROM est_produtos p
LEFT JOIN LATERAL (
  SELECT ft.id FROM est_fichas_tecnicas ft
  WHERE ft.produto_id = p.id AND ft.ativo
  LIMIT 1
) f ON true
LEFT JOIN LATERAL (
  SELECT count(*) AS n, min(fi.ingrediente_id::text) AS ing
  FROM est_ficha_ingredientes fi
  WHERE fi.ficha_id = f.id
) c ON true
LEFT JOIN est_produtos i ON i.id::text = c.ing
WHERE p.tipo = 'VENDA'
  AND p.ativo
  AND (f.id IS NULL OR (c.n = 1 AND i.tipo IN ('MP', 'MC')))
ORDER BY p.categoria, p.nome;


-- ---------------------------------------------------------------- PASSO 2
ALTER TABLE est_produtos ADD COLUMN IF NOT EXISTS foto_url   text;
ALTER TABLE est_produtos ADD COLUMN IF NOT EXISTS is_revenda boolean NOT NULL DEFAULT false;


-- ---------------------------------------------------------------- PASSO 3
-- Bucket publico para leitura (a foto aparece no card sem login de terceiros);
-- so usuario logado envia/troca/apaga foto.
INSERT INTO storage.buckets (id, name, public)
VALUES ('produtos', 'produtos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "produtos foto leitura"   ON storage.objects;
DROP POLICY IF EXISTS "produtos foto envio"     ON storage.objects;
DROP POLICY IF EXISTS "produtos foto troca"     ON storage.objects;
DROP POLICY IF EXISTS "produtos foto exclusao"  ON storage.objects;

CREATE POLICY "produtos foto leitura"  ON storage.objects
  FOR SELECT USING (bucket_id = 'produtos');
CREATE POLICY "produtos foto envio"    ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'produtos');
CREATE POLICY "produtos foto troca"    ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'produtos');
CREATE POLICY "produtos foto exclusao" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'produtos');


-- ---------------------------------------------------------------- PASSO 4
-- Troque SEU_EMAIL_AQUI pelo e-mail do seu login antes de rodar.
-- (O e-mail nao vai escrito no arquivo porque o repositorio e publico.)
-- Depois de rodar: saia do sistema e entre de novo para o menu aparecer.
UPDATE auth.users
SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || '{"precificacao": true}'::jsonb
WHERE email = 'SEU_EMAIL_AQUI';


-- ---------------------------------------------------------------- PASSO 5 (opcional)
-- Marque como revenda os nomes que voce aprovou no PASSO 1. Tambem da para
-- marcar um a um no cadastro do produto (check "Item de revenda").
-- UPDATE est_produtos SET is_revenda = true
-- WHERE tipo = 'VENDA' AND nome IN ('COCA COLA LATA', 'GUARANA LATA', 'CHOPP 300ML');
