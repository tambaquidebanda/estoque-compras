// ═══════════════════════════════════════════════════════════════
// Edge Function: admin-usuarios
//
// Gestão de usuários (tela "Usuários" do Estoque e do Financeiro) SEM a
// chave service_role no navegador. A chave fica só aqui, no servidor.
//
// Quem chama manda o próprio login (Authorization: Bearer <token da sessão>,
// o supabase-js faz isso sozinho em sb.functions.invoke). A função:
//   1. confere o token no Auth do Supabase (getUser);
//   2. só segue se o chamador tiver app_metadata.admin = true
//      (app_metadata NÃO pode ser alterado pelo próprio usuário; só por SQL
//       ou pela chave de serviço — ver SQL_ADMIN_USUARIOS.sql);
//   3. executa a ação pedida.
//
// Ações (corpo JSON):
//   { acao: 'listar' }
//   { acao: 'criar',     email, senha, nome, sistemas, precificacao? }
//   { acao: 'atualizar', id, nome?, sistemas?, precificacao? }
//   { acao: 'excluir',   id }
//
// 'atualizar' MESCLA com o user_metadata atual: nome, sistemas e
// precificacao andam sempre juntos e nenhum campo some por não ter vindo.
// A função nunca altera app_metadata (o admin só se marca por SQL).
//
// Resposta: 200 { ok: true, ... }  ou  4xx/5xx { error: 'mensagem' }
// ═══════════════════════════════════════════════════════════════
import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SISTEMAS_VALIDOS = ['estoque', 'financeiro'];

function resp(status: number, corpo: unknown) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

// Chave de serviço: ADMIN_SECRET_KEY (segredo próprio, para quando as chaves
// novas sb_secret_ forem usadas) > SUPABASE_SECRET_KEYS.default > legado.
function chaveServico(): string {
  const propria = Deno.env.get('ADMIN_SECRET_KEY');
  if (propria) return propria;
  try {
    const novas = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}');
    if (novas?.default) return novas.default;
  } catch (_) { /* sem chaves novas */ }
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
}

function sistemasOk(s: unknown): s is string[] {
  return Array.isArray(s) && s.length > 0 && s.every((x) => SISTEMAS_VALIDOS.includes(x));
}

// Só o que as telas usam; nada de telefone, identidades, etc.
function resumo(u: any) {
  return {
    id: u.id,
    email: u.email,
    created_at: u.created_at,
    last_sign_in_at: u.last_sign_in_at,
    user_metadata: u.user_metadata || {},
    app_metadata: { admin: u.app_metadata?.admin === true },
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return resp(405, { error: 'Método não permitido.' });

  const url = Deno.env.get('SUPABASE_URL') || '';
  const chave = chaveServico();
  if (!url || !chave) return resp(500, { error: 'Função sem configuração (URL/chave de serviço).' });

  const admin = createClient(url, chave, { auth: { autoRefreshToken: false, persistSession: false } });

  // 1. Quem está chamando?
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (!token) return resp(401, { error: 'Sessão não encontrada. Entre de novo no sistema.' });
  const { data: quem, error: errQuem } = await admin.auth.getUser(token);
  if (errQuem || !quem?.user) return resp(401, { error: 'Sessão expirada. Entre de novo no sistema.' });
  const chamador = quem.user;

  // 2. É administrador?
  if (chamador.app_metadata?.admin !== true) {
    return resp(403, { error: 'Apenas administradores podem gerenciar usuários.' });
  }

  let corpo: any = {};
  try { corpo = await req.json(); } catch (_) { return resp(400, { error: 'Pedido inválido.' }); }
  const acao = corpo?.acao;

  try {
    // ── listar
    if (acao === 'listar') {
      const users: any[] = [];
      for (let page = 1; page <= 50; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error) return resp(400, { error: error.message });
        const lote = data?.users || [];
        users.push(...lote);
        if (lote.length < 1000) break;
      }
      return resp(200, { ok: true, users: users.map(resumo) });
    }

    // ── criar
    if (acao === 'criar') {
      const email = String(corpo.email || '').trim();
      const senha = String(corpo.senha || '');
      const nome = String(corpo.nome || '').trim();
      if (!email || !senha || !nome) return resp(400, { error: 'Preencha todos os campos.' });
      if (!sistemasOk(corpo.sistemas)) return resp(400, { error: 'Selecione ao menos um sistema.' });
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: senha,
        email_confirm: true,
        user_metadata: { nome, sistemas: corpo.sistemas, precificacao: corpo.precificacao === true },
      });
      if (error) return resp(400, { error: error.message });
      return resp(200, { ok: true, user: resumo(data.user) });
    }

    // ── atualizar (mescla com o metadata atual)
    if (acao === 'atualizar') {
      const id = String(corpo.id || '');
      if (!id) return resp(400, { error: 'Usuário não informado.' });
      if ('sistemas' in corpo && !sistemasOk(corpo.sistemas)) {
        return resp(400, { error: 'Selecione ao menos um sistema.' });
      }
      const { data: atual, error: errAtual } = await admin.auth.admin.getUserById(id);
      if (errAtual || !atual?.user) return resp(404, { error: errAtual?.message || 'Usuário não encontrado.' });
      const meta = { ...(atual.user.user_metadata || {}) };
      if (typeof corpo.nome === 'string' && corpo.nome.trim()) meta.nome = corpo.nome.trim();
      if ('sistemas' in corpo) meta.sistemas = corpo.sistemas;
      if ('precificacao' in corpo) meta.precificacao = corpo.precificacao === true;
      const { data, error } = await admin.auth.admin.updateUserById(id, { user_metadata: meta });
      if (error) return resp(400, { error: error.message });
      return resp(200, { ok: true, user: resumo(data.user) });
    }

    // ── excluir
    if (acao === 'excluir') {
      const id = String(corpo.id || '');
      if (!id) return resp(400, { error: 'Usuário não informado.' });
      if (id === chamador.id) return resp(400, { error: 'Você não pode excluir o próprio usuário.' });
      const { error } = await admin.auth.admin.deleteUser(id);
      if (error) return resp(400, { error: error.message });
      return resp(200, { ok: true });
    }

    return resp(400, { error: 'Ação desconhecida.' });
  } catch (e) {
    return resp(500, { error: 'Erro na função: ' + ((e as Error)?.message || e) });
  }
});
