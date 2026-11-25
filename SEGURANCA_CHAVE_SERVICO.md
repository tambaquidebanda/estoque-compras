# Chave de serviço do Supabase: tirar do navegador e trocar

**O problema.** A chave `service_role` (chave de serviço) estava no `supabase.js`. Esse arquivo vai para
o navegador de quem abre o sistema, e o repositório é público. Quem tem essa chave lê e altera
**qualquer** tabela do Estoque e do Financeiro e mexe em qualquer usuário. A chave antiga continua no
histórico do Git, então **considere que ela vazou**. Apagar a chave do arquivo não basta: ela só deixa de
funcionar quando for **desligada no painel** (passo 5).

**O que mudou no código (branch desta sessão):**
- `supabase.js` só tem a chave pública (anon).
- A tela **Usuários** (listar, criar, permissões, excluir) agora chama a Edge Function
  `admin-usuarios` (`supabase/functions/admin-usuarios/index.ts`). A chave de serviço fica só no
  servidor do Supabase.
- A função só atende **administrador**: `app_metadata.admin = true`. O próprio usuário não consegue
  alterar o `app_metadata` pelo navegador. Quem não é admin vê "Apenas administradores podem gerenciar
  usuários."
- Ao salvar permissões, a função mescla `nome`, `sistemas` e `precificacao` com o que já existe.
  Nenhum campo se perde.
- Os scripts locais (`scripts/checagem_fichas.py`, `teste/copiar_dados.py`) leem a chave da variável
  `SUPABASE_SERVICE_KEY` ou do arquivo `~/.supabase_service_key`, que fica fora do repositório.
  Os scripts das rotinas do GitHub já aceitam a chave nova (`sb_secret_...`).

---

## Passo a passo (nesta ordem)

### 1. Marcar você como administrador
SQL Editor do Supabase → abra `SQL_ADMIN_USUARIOS.sql` → troque `SEU_EMAIL_AQUI` pelo seu e-mail
(**só no SQL Editor**, não salve o arquivo com ele) → rode. O resultado esperado é `UPDATE 1`.

### 2. Publicar a função `admin-usuarios`
Painel do Supabase → **Edge Functions** → **Deploy a new function** → **Via Editor**
- Nome: `admin-usuarios` (exatamente assim)
- Cole todo o conteúdo de `supabase/functions/admin-usuarios/index.ts` → **Deploy**
- Depois, nos detalhes da função, **desligue "Verify JWT" / "Enforce JWT verification"**. A função
  confere o login no próprio código.

(Com o Supabase CLI instalado, o mesmo passo é `supabase functions deploy admin-usuarios`, rodado
na pasta do repositório. O `supabase/config.toml` já desliga o verify_jwt.)

### 3. Publicar o Estoque
Faça o merge desta branch na `main` e o Push pelo GitHub Desktop. Depois entre como admin e teste a
tela **Usuários**: ela precisa listar, abrir permissões e salvar. Entre também com um funcionário: a tela
deve mostrar a recusa.

### 4. Antes de trocar a chave: o Financeiro
O `restaurante-financeiro` **também tem a chave de serviço no `supabase.js`** e a usa na tela de
usuários (`app.js`: listar, alterar permissões, criar). Enquanto esse site estiver no ar, a chave
continua exposta, mesmo com o Estoque já corrigido. Esse repositório precisa da mesma troca, e a mesma
função `admin-usuarios` serve para ele. Se a chave for desligada antes disso, só a tela de usuários do
Financeiro para de funcionar. O resto do Financeiro continua normal.

### 5. Trocar (girar) a chave: só depois dos passos 2 a 4
Este é o caminho que a documentação do Supabase recomenda para chave de serviço vazada. Ninguém é
deslogado.

1. **Settings → API Keys** → aba **Publishable and secret API keys** → **Create new API keys**.
   O painel cria uma chave `sb_publishable_...` (pública) e uma `sb_secret_...` (de serviço).
2. Coloque a **`sb_secret_...`** nestes lugares, sempre em lugar privado e nunca em arquivo do repositório:
   - GitHub → `estoque-compras` → Settings → Secrets and variables → Actions → `SUPABASE_SERVICE_KEY`
     (rotinas baixa-estoque-pdv e venda-sa-dia);
   - GitHub → `restaurante-financeiro` → mesmo segredo `SUPABASE_SERVICE_KEY` (pull-getnet, pull-pdv,
     pull-caixa). **Atenção:** os scripts de lá mandam a chave também como `Authorization: Bearer`, e com a
     chave nova isso dá "Invalid JWT". Eles precisam do mesmo ajuste de uma linha feito aqui em
     `scripts/baixa_estoque_pdv.py`;
   - Supabase → **Edge Functions → Secrets** → novo segredo `ADMIN_SECRET_KEY` = a `sb_secret_...`;
   - no Mac: arquivo `~/.supabase_service_key`, só com a chave (para scripts locais e `teste/copiar_dados.py`);
   - o script de backup do Supabase para o Google Drive, se ele usa a chave de serviço.
3. Coloque a **`sb_publishable_...`** no lugar da chave `SB_KEY` do `supabase.js` dos **dois**
   repositórios e dê Push. Isso é necessário porque o passo 5 desliga também a chave anon antiga.
4. Espere um dia rodando. Depois, em **Settings → API Keys**, aba de chaves antigas (legacy), confira o
   "last used". Se a `service_role` ou a `anon` antigas ainda aparecem em uso por uma rotina sua, falta
   trocar a chave em algum lugar da lista acima. Quando estiver tudo trocado, clique em
   **Disable JWT-based API keys**. **É aqui que a chave vazada morre.**
5. Por último, **Settings → JWT Keys** → **Migrate JWT secret**. Espere pelo menos 1h15 e então
   **revogue o segredo JWT antigo** (legacy). A documentação pede esse passo quando a chave vazada é uma
   `service_role` antiga. Ninguém é deslogado.

Se algo parar depois do item 4, dá para reativar as chaves antigas no mesmo lugar. Mas isso
reativa também a chave vazada, então use só para corrigir o que ficou para trás e desligue de novo.

**O que não é afetado:** a conexão do Pensêra (usuário de banco `pensera_leitura`), que não usa essas chaves.
