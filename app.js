'use strict';

// ═══════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════
let sb      = null;   // supabase client (anon)
let sbAdmin = null;   // supabase client (service_role)
let user = null;   // logged-in user

// caches
let cForn    = [];    // fornecedores
let cCat     = [];    // categorias
let cTipo    = [];    // tipos_produto
let cProd    = [];    // product names learned from past purchases
let cGrupos  = [];    // grupos de produto (est_grupos_produto)
let cSetores = [];    // setores

// chart instances (destroyed before re-render)
let chMensal, chCmvMensal, chFornDash, chCatDash, chCmvEvolucao;

// fichas técnicas
let cProdutosFT  = [];   // all est_produtos for autocomplete
let ftIngredientes = []; // ingredientes da ficha em edição
let ftFichasCache  = []; // fichas carregadas

// pedido de compra multi-item (acumulados antes de finalizar)
let _pedidoItens    = [];   // itens do pedido em construção
let _pedidosGrupos  = {};   // { pedido_num: g } usado pelo modal financeiro
let _pedidoEditando = null; // pedido_num sendo editado (null = novo pedido)
let _pedidoAcrescimo = 0;   // acréscimo (frete/taxa) do pedido atual
let _rateioItensAtual = []; // itens de rateio já resolvidos (com plano_conta_id) para o modal atual

// plano de contas do financeiro (para resolver IDs sem busca no banco)
let cPlanoConta = [];       // { id, nome, grupo_id } — apenas subcategorias (folhas)
let cPlanoContaGrupos = []; // { id, nome } — apenas grupos-pai (para montar optgroup)

// unidades do financeiro (compartilhado via Supabase)
let cUnidades = [];         // { id, nome }


// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', async () => {
  try {
    sb = supabase.createClient(SB_URL, SB_KEY);
    const { data: { session } } = await sb.auth.getSession();
    if (session) { user = session.user; entrarNoSistema(); }
    else          { mostrarTela('login'); }
  } catch {
    mostrarTela('login');
  }
});


// ═══════════════════════════════════════════════════════════════
// TELAS
// ═══════════════════════════════════════════════════════════════
function mostrarTela(nome) {
  document.getElementById('tela-config').classList.toggle('d-none',    nome !== 'config');
  document.getElementById('tela-login').classList.toggle('d-none',     nome !== 'login');
  document.getElementById('tela-principal').classList.toggle('d-none', nome !== 'principal');
}

function mostrarConfig() { mostrarTela('config'); }


// ═══════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════
function salvarConfig() {
  const url  = (document.getElementById('cfg-url').value  || '').replace(/\s/g, '').replace(/[^\x20-\x7E]/g, '');
  const key  = (document.getElementById('cfg-key').value  || '').replace(/\s/g, '').replace(/[^\x20-\x7E]/g, '');
  const erro = document.getElementById('cfg-erro');

  if (!url.startsWith('https://')) {
    erro.textContent = `A URL deve começar com https:// — recebido: "${url.substring(0,30)}"`;
    erro.classList.remove('d-none'); return;
  }
  if (!key.startsWith('eyJ') && !key.startsWith('sb_publishable_')) {
    erro.textContent = 'A chave parece incorreta. Copie a chave "anon public" do Supabase.';
    erro.classList.remove('d-none'); return;
  }

  localStorage.setItem('gc_url', url);
  localStorage.setItem('gc_key', key);
  erro.classList.add('d-none');
  mostrarTela('login');
}


// ═══════════════════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════════════════
async function fazerLogin() {
  const email = (document.getElementById('login-email').value || '').trim();
  const senha = document.getElementById('login-senha').value;
  const erro  = document.getElementById('login-erro');

  if (!email || !senha) {
    erro.textContent = 'Preencha e-mail e senha.';
    erro.classList.remove('d-none'); return;
  }

  try {
    if (!sb) sb = supabase.createClient(SB_URL, SB_KEY);
    const { data, error } = await sb.auth.signInWithPassword({ email, password: senha });
    if (error) {
      erro.textContent = 'E-mail ou senha incorretos.';
      erro.classList.remove('d-none'); return;
    }
    user = data.user;
    erro.classList.add('d-none');
    entrarNoSistema();
  } catch (e) {
    erro.textContent = 'Erro de conexão: ' + (e.message || e);
    erro.classList.remove('d-none');
  }
}

function entrarNoSistema() {
  // Verifica permissão — bloqueia se sistemas estiver definido e não incluir 'estoque'
  const sistemas = user?.user_metadata?.sistemas;
  if (sistemas && !sistemas.includes('estoque')) {
    sb.auth.signOut();
    document.getElementById('login-erro').textContent = 'Você não tem acesso ao sistema de Gestão de Compras.';
    document.getElementById('login-erro').classList.remove('d-none');
    mostrarTela('login');
    return;
  }

  sbAdmin = supabase.createClient(SB_URL, SB_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
  mostrarTela('principal');
  document.getElementById('sb-usuario').textContent = user.email;
  setHoje('c-data');
  setHoje('f-data');
  setMes('f-filtro-mes');
  setMes('hist-mes');

  const hash = window.location.hash.slice(1) || localStorage.getItem('gc_nav') || '';
  if (hash && hash !== 'dashboard') {
    restaurarPagina(hash);
  } else {
    ir('dashboard', document.querySelector('.nav-sb a'));
  }
}

function initTooltips(scope) {
  const el = scope || document;
  el.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(t => {
    bootstrap.Tooltip.getOrCreateInstance(t, { trigger: 'hover' });
  });
}

function restaurarPagina(hash) {
  if (hash.startsWith('cad-')) {
    irCadSb(hash.slice(4), null);
  } else if (hash.startsWith('produto-')) {
    abrirProduto(hash.slice(8));
  } else if (document.getElementById('pg-' + hash)) {
    ir(hash, null);
  } else {
    ir('dashboard', document.querySelector('.nav-sb a'));
  }
}

async function sair() {
  await sb.auth.signOut();
  user = null;
  document.getElementById('login-email').value = '';
  document.getElementById('login-senha').value = '';
  mostrarTela('login');
}


// ═══════════════════════════════════════════════════════════════
// NAVEGAÇÃO
// ═══════════════════════════════════════════════════════════════
function toggleNavGrupo(grupo) {
  const btn    = document.getElementById(`nav-grupo-${grupo}`);
  const submenu = document.getElementById(`nav-submenu-${grupo}`);
  const aberto = btn.classList.contains('aberto');
  btn.classList.toggle('aberto', !aberto);
  submenu.classList.toggle('aberto', !aberto);
}

function salvarNav(chave) {
  localStorage.setItem('gc_nav', chave);
  history.replaceState(null, '', '#' + chave);
}

function ir(nome, el) {
  salvarNav(nome);
  document.querySelectorAll('.pagina').forEach(p => p.classList.remove('ativa'));
  document.querySelectorAll('.nav-sb a:not(.nav-em-breve), .nav-grupo-btn').forEach(a => a.classList.remove('ativo'));
  document.getElementById('pg-' + nome).classList.add('ativa');
  if (el) el.classList.add('ativo');
  // Abre o grupo pai conforme o item
  if (['pedido','compras','planejamento','historico'].includes(nome)) {
    document.getElementById('nav-grupo-compra')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-compra')?.classList.add('aberto');
  }
  if (['cadastros','produto'].includes(nome)) {
    document.getElementById('nav-grupo-cadastros')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-cadastros')?.classList.add('aberto');
  }
  if (['recebimento','inventario','saldo'].includes(nome)) {
    document.getElementById('nav-grupo-estoque')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-estoque')?.classList.add('aberto');
  }
  if (['usuarios','backup'].includes(nome)) {
    document.getElementById('nav-grupo-config')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-config')?.classList.add('aberto');
  }

  if (nome === 'dashboard')   carregarDashboard();
  if (nome === 'bi')          carregarBI();
  if (nome === 'pedido')      prepararFormCompra();
  if (nome === 'compras')     carregarCompras();
  if (nome === 'faturamento') { setHoje('f-data'); carregarFaturamento(); }
  if (nome === 'cmv')         carregarCMV();
  if (nome === 'historico')   carregarHistorico();
  if (nome === 'cadastros')   { irCad('produtos', document.querySelector('#tabs-cad .nav-link')); }
  if (nome === 'inventario')    { setHoje('inv-data'); carregarInventario(); }
  if (nome === 'saldo')         carregarSaldo();
  if (nome === 'planejamento')  { setHoje('plan-data'); carregarPlanejamento(); }
  if (nome === 'recebimento')   { carregarCaches().then(() => abaReceb('pendentes', document.querySelector('#tabs-receb .nav-link'))); }
  if (nome === 'controlecmv')   renderHistoricoImport();
  if (nome === 'usuarios')      carregarUsuarios();
  if (nome === 'backup')        inicializarToggleIntegracao();
}

function irCad(tab, el) {
  document.querySelectorAll('.tab-cad').forEach(t => t.classList.remove('ativa'));
  document.querySelectorAll('#tabs-cad .nav-link').forEach(a => a.classList.remove('active'));
  document.getElementById('cad-' + tab).classList.add('ativa');
  if (el) el.classList.add('active');
  if (tab === 'produtos') { carregarFichas(); return; }
  if (tab === 'grupos')   { carregarGrupos(); return; }
  renderListaCad(tab);
}

const _nomesCad = {
  fornecedores: '🏪 Fornecedores', categorias: '📂 Categorias',
  tipos: '🏷️ Destinos',
  grupos: '🗂️ Grupos de Produto', produtos: '📦 Produtos'
};

function irCadSb(tab, el) {
  salvarNav('cad-' + tab);
  document.querySelectorAll('.pagina').forEach(p => p.classList.remove('ativa'));
  document.querySelectorAll('.nav-sb a, .nav-grupo-btn').forEach(a => a.classList.remove('ativo'));
  document.getElementById('pg-cadastros').classList.add('ativa');
  document.getElementById('nav-grupo-cadastros')?.classList.add('aberto', 'ativo');
  document.getElementById('nav-submenu-cadastros')?.classList.add('aberto');
  if (el) el.classList.add('ativo');
  const h1 = document.querySelector('#pg-cadastros h1');
  if (h1) h1.textContent = _nomesCad[tab] || '⚙️ Cadastros';
  irCad(tab, null);
}

function irAba(aba, el) {
  document.querySelectorAll('#tabs-prod .nav-link').forEach(a => a.classList.remove('active'));
  if (el) el.classList.add('active');
  document.getElementById('aba-dados').style.display  = aba === 'dados'  ? '' : 'none';
  document.getElementById('aba-ficha').style.display  = aba === 'ficha'  ? '' : 'none';
  if (aba === 'ficha') carregarFichaProduto();
}


// Busca todos os registros de plano_contas paginando (igual ao financeiro)
async function fetchTodosPlanoContas() {
  const PAGE = 1000;
  let todos = [], pagina = 0;
  while (true) {
    const { data: lote } = await sb.from('plano_contas')
      .select('id,nome,grupo_id,tipo')
      .order('nome')
      .range(pagina * PAGE, (pagina + 1) * PAGE - 1);
    if (!lote || !lote.length) break;
    todos = todos.concat(lote);
    if (lote.length < PAGE) break;
    pagina++;
  }
  return todos;
}

// Constrói o HTML de um <select> hierárquico de plano de contas
function buildPlanoSelect(opcaoVazia, planoAtualId, grupos, subcats) {
  let html = `<option value="">${esc(opcaoVazia)}</option>`;
  grupos.forEach(g => {
    const subs = subcats.filter(s => s.grupo_id === g.id);
    if (!subs.length) return;
    html += `<optgroup label="${esc(g.nome)}">`;
    subs.sort((a, b) => a.nome.localeCompare(b.nome)).forEach(p => {
      html += `<option value="${p.id}"${p.id === planoAtualId ? ' selected' : ''}>${esc(p.nome)}</option>`;
    });
    html += `</optgroup>`;
  });
  return html;
}

function toggleFormCad(key) {
  const el = document.getElementById(`form-cad-${key}`);
  if (!el) return;
  el.classList.toggle('d-none');
  if (!el.classList.contains('d-none')) {
    // Popula dropdown ao abrir o form de nova categoria
    if (key === 'cat') {
      const sel = document.getElementById('n-plano');
      if (sel) {
        sel.innerHTML = '<option value="">Carregando categorias do financeiro...</option>';
        fetchTodosPlanoContas().then(todos => {
          const grupos  = todos.filter(p => p.tipo === 'pagar' && !p.grupo_id);
          const subcats = todos.filter(p => p.tipo === 'pagar' &&  p.grupo_id);
          cPlanoContaGrupos = grupos;
          cPlanoConta = subcats;
          // Mostra apenas subcategorias que ainda não existem em cmp_categorias
          const nomesExistentes = new Set(cCat.map(c => c.nome.toLowerCase()));
          const disponiveis = subcats.filter(p => !nomesExistentes.has(p.nome.toLowerCase()));
          sel.innerHTML = buildPlanoSelect('— Selecione a categoria —', '', grupos, disponiveis);
          sel.focus();
        });
      }
      return; // não tenta focar input (foi removido)
    }
    el.querySelector('input')?.focus();
  }
}

// ═══════════════════════════════════════════════════════════════
// DATE HELPERS
// ═══════════════════════════════════════════════════════════════
function setHoje(id) {
  const el = document.getElementById(id);
  if (el) el.value = new Date().toISOString().split('T')[0];
}

function setMes(id) {
  const el = document.getElementById(id);
  if (el) el.value = new Date().toISOString().slice(0, 7);
}

function mesDeData(d) { return d ? d.slice(0, 7) : ''; }

function semanaISO(dateStr) {
  const d   = new Date(dateStr + 'T12:00:00');
  const jan = new Date(d.getFullYear(), 0, 1);
  const wk  = Math.ceil(((d - jan) / 86400000 + jan.getDay() + 1) / 7);
  return `${d.getFullYear()}-S${String(wk).padStart(2, '0')}`;
}

function inicioDaSemana() {
  const hoje = new Date();
  const dow  = hoje.getDay();
  const seg  = new Date(hoje);
  seg.setDate(hoje.getDate() - (dow === 0 ? 6 : dow - 1));
  return seg.toISOString().split('T')[0];
}

function fimDaSemana() {
  const seg = new Date(inicioDaSemana() + 'T12:00:00');
  const dom = new Date(seg);
  dom.setDate(seg.getDate() + 6);
  return dom.toISOString().split('T')[0];
}


// ═══════════════════════════════════════════════════════════════
// FORMAT
// ═══════════════════════════════════════════════════════════════
function brl(v) {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(v || 0);
}

function pct(v) {
  return v != null && !isNaN(v) ? `${Number(v).toFixed(1)}%` : '—';
}

function fmtData(d) {
  if (!d) return '—';
  const [y, m, dd] = d.split('-');
  return `${dd}/${m}/${y}`;
}

function esc(s) {
  return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function norm(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

function isCompExterna(forn) {
  return norm(forn || '') === 'comprador externo';
}

function mesCurto(mesStr) {
  const [y, m] = mesStr.split('-');
  return new Date(+y, +m - 1).toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' });
}


// ═══════════════════════════════════════════════════════════════
// TOAST
// ═══════════════════════════════════════════════════════════════
function toast(msg, tipo = '') {
  const box = document.getElementById('toast-box');
  const el  = document.createElement('div');
  el.className = `toast-item toast-${tipo}`;
  el.textContent = msg;
  box.appendChild(el);
  setTimeout(() => el.remove(), 3500);
}


// ═══════════════════════════════════════════════════════════════
// CACHES
// ═══════════════════════════════════════════════════════════════
async function carregarCaches() {
  const [f, cat, tip, hist, grp, uni, set] = await Promise.all([
    sb.from('fornecedores').select('id,nome').order('nome'),
    sb.from('cmp_categorias').select('id,nome,plano_conta,plano_conta_id').eq('ativo', true).order('nome'),
    sb.from('cmp_tipos_produto').select('id,nome').order('nome'),
    sb.from('cmp_compras').select('produto,unidade_med,categoria,custo_unit,data').order('data', { ascending: false }),
    sb.from('est_grupos_produto').select('id,nome').order('nome'),
    sb.from('unidades').select('id,nome').order('nome'),
    sb.from('cmp_setores').select('id,nome').eq('ativo', true).order('nome'),
  ]);

  cForn     = f.data   || [];
  cCat      = cat.data || [];
  cTipo     = tip.data || [];
  cGrupos   = grp.data  || [];
  cUnidades = uni.data  || [];
  cSetores  = set.data  || [];

  // Carrega plano_contas com paginação (tabela pode ter >1000 linhas)
  const todosPC = await fetchTodosPlanoContas();
  // Grupos-pai (grupo_id null) — usados para montar optgroup no dropdown
  cPlanoContaGrupos = todosPC.filter(p => p.tipo === 'pagar' && !p.grupo_id);
  // Subcategorias (folhas, tipo pagar) — únicas aceitas pelo financeiro como plano_conta_id
  cPlanoConta = todosPC.filter(p => p.tipo === 'pagar' && p.grupo_id);

  // Build unique product list from past purchases — ordered DESC so first hit = last price
  const seen = new Set();
  cProd = [];
  (hist.data || []).forEach(r => {
    if (r.produto && !seen.has(r.produto.toLowerCase())) {
      seen.add(r.produto.toLowerCase());
      cProd.push({ nome: r.produto, un: r.unidade_med, cat: r.categoria, custo_unit: r.custo_unit || 0 });
    }
  });
}


// ═══════════════════════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════════════════════
async function carregarDashboard() {
  const mesAtual = new Date().toISOString().slice(0, 7);
  const segStr   = inicioDaSemana();
  const domStr   = fimDaSemana();

  const [rc, rf] = await Promise.all([
    sb.from('cmp_compras').select('data,total,fornecedor_nome,categoria').order('data'),
    sb.from('cmp_faturamento').select('data,valor').order('data'),
  ]);

  const compras     = rc.data || [];
  const faturamento = rf.data || [];

  // ── KPIs ──
  const compSem = compras
    .filter(c => c.data >= segStr && c.data <= domStr)
    .reduce((s, c) => s + (c.total || 0), 0);

  const compMes = compras
    .filter(c => mesDeData(c.data) === mesAtual)
    .reduce((s, c) => s + (c.total || 0), 0);

  const fatMes = faturamento
    .filter(f => mesDeData(f.data) === mesAtual)
    .reduce((s, f) => s + (f.valor || 0), 0);

  const cmvMes = fatMes > 0 ? (compMes / fatMes * 100) : null;

  document.getElementById('kpi-sem').textContent     = brl(compSem);
  document.getElementById('kpi-mes').textContent     = brl(compMes);
  document.getElementById('kpi-fat-mes').textContent = brl(fatMes);

  const cmvCard = document.getElementById('kpi-cmv-card');
  cmvCard.classList.remove('kpi-ok', 'kpi-ruim');
  if (cmvMes !== null) {
    document.getElementById('kpi-cmv-val').textContent  = pct(cmvMes);
    document.getElementById('kpi-cmv-meta').textContent = cmvMes <= 27 ? '✅ Dentro da meta' : '⚠️ Acima da meta (27%)';
    cmvCard.classList.add(cmvMes <= 27 ? 'kpi-ok' : 'kpi-ruim');
  } else {
    document.getElementById('kpi-cmv-val').textContent  = '—';
    document.getElementById('kpi-cmv-meta').textContent = 'sem faturamento';
  }

  // ── Build monthly buckets ──
  const byMes = {};
  compras.forEach(c => {
    const m = mesDeData(c.data);
    if (!byMes[m]) byMes[m] = { comp: 0, fat: 0 };
    byMes[m].comp += c.total || 0;
  });
  faturamento.forEach(f => {
    const m = mesDeData(f.data);
    if (!byMes[m]) byMes[m] = { comp: 0, fat: 0 };
    byMes[m].fat += f.valor || 0;
  });

  const meses     = Object.keys(byMes).sort().slice(-12);
  const labsMeses = meses.map(mesCurto);

  // ── Chart: compras por mês ──
  destroyChart('chMensal');
  const ctxM = document.getElementById('ch-mensal');
  if (ctxM) {
    chMensal = new Chart(ctxM, {
      type: 'bar',
      data: {
        labels: labsMeses,
        datasets: [{ label: 'Compras (R$)', data: meses.map(m => byMes[m].comp),
          backgroundColor: '#FF6B35', borderRadius: 5, borderSkipped: false }],
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { y: { ticks: { callback: v => 'R$' + numK(v) } } },
      },
    });
  }

  // ── Chart: CMV por mês ──
  destroyChart('chCmvMensal');
  const ctxC = document.getElementById('ch-cmv-mensal');
  if (ctxC) {
    const vals = meses.map(m =>
      byMes[m].fat > 0 ? parseFloat((byMes[m].comp / byMes[m].fat * 100).toFixed(1)) : null
    );
    chCmvMensal = new Chart(ctxC, {
      type: 'bar',
      data: {
        labels: labsMeses,
        datasets: [{ label: 'CMV %', data: vals,
          backgroundColor: vals.map(v => v == null ? '#dee2e6' : v <= 27 ? '#2EC4B6' : '#E71D36'),
          borderRadius: 5, borderSkipped: false }],
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { y: { ticks: { callback: v => v + '%' }, suggestedMax: 36 } },
      },
    });
  }

  // ── Top fornecedores ──
  const byForn = {};
  compras.forEach(c => {
    const k = c.fornecedor_nome || 'Outros';
    byForn[k] = (byForn[k] || 0) + (c.total || 0);
  });
  const topForn = Object.entries(byForn).sort((a,b) => b[1]-a[1]).slice(0, 8);

  destroyChart('chFornDash');
  const ctxF = document.getElementById('ch-forn-dash');
  if (ctxF && topForn.length) {
    chFornDash = new Chart(ctxF, {
      type: 'doughnut',
      data: {
        labels: topForn.map(([k]) => k),
        datasets: [{ data: topForn.map(([,v]) => v), borderWidth: 2, borderColor: '#fff',
          backgroundColor: CORES_GRAFICO }],
      },
      options: {
        responsive: true,
        plugins: { legend: { position: 'right', labels: { font: { size: 11 }, boxWidth: 12 } } },
      },
    });
  }

  // ── Por categoria ──
  const byCat = {};
  compras.forEach(c => {
    const k = c.categoria || 'Outros';
    byCat[k] = (byCat[k] || 0) + (c.total || 0);
  });
  const topCat = Object.entries(byCat).sort((a,b) => b[1]-a[1]).slice(0, 8);

  destroyChart('chCatDash');
  const ctxK = document.getElementById('ch-cat-dash');
  if (ctxK && topCat.length) {
    chCatDash = new Chart(ctxK, {
      type: 'bar',
      data: {
        labels: topCat.map(([k]) => k),
        datasets: [{ label: 'R$', data: topCat.map(([,v]) => v),
          backgroundColor: '#8338EC', borderRadius: 5, borderSkipped: false }],
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        plugins: { legend: { display: false } },
        scales: { x: { ticks: { callback: v => 'R$' + numK(v) } } },
      },
    });
  }
  renderInsights();
}

// ─── BI COMPRAS ───────────────────────────────────────────────────
let _biChMensal = null, _biChSemanal = null, _biChFatSem = null;

function _biISOWeek(dateStr) {
  if (!dateStr) return null;
  const d = new Date(dateStr + 'T12:00:00');
  const jan1 = new Date(d.getFullYear(), 0, 1);
  const week = Math.ceil(((d - jan1) / 86400000 + jan1.getDay() + 1) / 7);
  return `${d.getFullYear()}-W${String(week).padStart(2, '0')}`;
}

function _biChartOpts(extra = {}) {
  return {
    responsive: true,
    plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ' ' + brl(ctx.parsed.y ?? ctx.parsed.x ?? ctx.raw) } } },
    scales: {
      x: { grid: { color: 'rgba(255,255,255,.05)' }, ticks: { color: '#64748b', font: { size: 9 } } },
      y: { grid: { color: 'rgba(255,255,255,.05)' }, ticks: { color: '#64748b', font: { size: 9 }, callback: v => v >= 1000 ? (v / 1000).toFixed(0) + 'K' : v } },
    },
    ...extra,
  };
}

function limparFiltrosBI() {
  ['bi-ini', 'bi-fim', 'bi-unidade'].forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
  carregarBI();
}

async function carregarBI() {
  // Período padrão: ano corrente
  const hoje = new Date().toISOString().split('T')[0];
  const anoIni = hoje.slice(0, 4) + '-01-01';
  const iniEl = document.getElementById('bi-ini');
  const fimEl = document.getElementById('bi-fim');
  if (iniEl && !iniEl.value) iniEl.value = anoIni;
  if (fimEl && !fimEl.value) fimEl.value = hoje;
  const ini = iniEl?.value || anoIni;
  const fim = fimEl?.value || hoje;

  // Carrega dados em paralelo
  let qC = sb.from('cmp_compras')
    .select('pedido_num,data,fornecedor_nome,categoria,tipo_produto,quantidade,custo_unit')
    .gte('data', ini).lte('data', fim).order('data');
  let qF = sb.from('cmp_faturamento').select('data,valor').gte('data', ini).lte('data', fim).order('data');
  const [{ data: compras }, { data: fat }] = await Promise.all([qC, qF]);

  const C = compras || [], F = fat || [];

  // ── Totais ──
  const totalComp = C.reduce((s, c) => s + (c.quantidade || 0) * (c.custo_unit || 0), 0);
  const totalFat  = F.reduce((s, f) => s + (f.valor || 0), 0);
  const qtdPed    = new Set(C.map(c => c.pedido_num)).size;
  const ticket    = qtdPed > 0 ? totalComp / qtdPed : 0;
  const cmvPct    = totalFat > 0 ? totalComp / totalFat * 100 : null;
  const meta      = totalFat * 0.27;
  const diff      = totalComp - meta;

  // ── KPIs ──
  document.getElementById('bi-kpi-comp').textContent = brl(totalComp);
  document.getElementById('bi-kpi-fat').textContent  = totalFat > 0 ? brl(totalFat) : '—';
  document.getElementById('bi-kpi-qtd').textContent  = qtdPed.toLocaleString('pt-BR');
  document.getElementById('bi-kpi-tick').textContent = 'Ticket médio: ' + brl(ticket);

  const cmvEl = document.getElementById('bi-kpi-cmv');
  const cmvCard = document.getElementById('bi-k-cmv');
  if (cmvPct !== null) {
    cmvEl.textContent = cmvPct.toFixed(2).replace('.', ',') + '%';
    cmvCard.className = 'bi-kpi ' + (cmvPct <= 27 ? 'green' : 'red');
  } else { cmvEl.textContent = '—'; cmvCard.className = 'bi-kpi'; }

  const diffEl  = document.getElementById('bi-kpi-diff');
  const diffSub = document.getElementById('bi-kpi-diff-sub');
  const metaCard = document.getElementById('bi-k-meta');
  if (totalFat > 0) {
    const abaixo = diff < 0;
    diffEl.textContent    = (abaixo ? '▼ ' : '▲ ') + brl(Math.abs(diff));
    diffSub.textContent   = abaixo ? 'Abaixo da meta ✓' : 'Acima da meta ✗';
    metaCard.className    = 'bi-kpi ' + (abaixo ? 'green' : 'red');
  } else { diffEl.textContent = '—'; diffSub.textContent = ''; metaCard.className = 'bi-kpi'; }
  document.getElementById('bi-kpi-meta').textContent = totalFat > 0 ? brl(meta) : '—';

  // ── Agrega por mês ──
  const byMonth = {};
  C.forEach(c => { const m = (c.data || '').slice(0, 7); if (m) byMonth[m] = (byMonth[m] || 0) + (c.quantidade || 0) * (c.custo_unit || 0); });
  const months = Object.keys(byMonth).sort();
  const mLabels = months.map(m => { const [y, mo] = m.split('-'); return ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'][+mo - 1] + '/' + y.slice(2); });

  // ── Agrega por semana ──
  const byWeek = {}, byWeekFat = {};
  C.forEach(c => { const w = _biISOWeek(c.data); if (w) byWeek[w] = (byWeek[w] || 0) + (c.quantidade || 0) * (c.custo_unit || 0); });
  F.forEach(f => { const w = _biISOWeek(f.data); if (w) byWeekFat[w] = (byWeekFat[w] || 0) + (f.valor || 0); });
  const allWeeks = [...new Set([...Object.keys(byWeek), ...Object.keys(byWeekFat)])].sort().slice(-16);
  const wLabels  = allWeeks.map(w => 'S' + w.split('-W')[1]);

  // ── Agrega por categoria / tipo / fornecedor ──
  const byCat = {}, byTipo = {}, byForn = {};
  C.forEach(c => {
    const v = (c.quantidade || 0) * (c.custo_unit || 0);
    const cat  = c.categoria     || 'Outros'; byCat[cat]  = (byCat[cat]  || 0) + v;
    const tipo = c.tipo_produto  || 'Outros'; byTipo[tipo] = (byTipo[tipo] || 0) + v;
    const forn = c.fornecedor_nome || '—';   byForn[forn] = (byForn[forn] || 0) + v;
  });

  // ── Charts ──
  const orange = '#f97316', purple = '#a855f7';
  if (_biChMensal)  _biChMensal.destroy();
  if (_biChSemanal) _biChSemanal.destroy();
  if (_biChFatSem)  _biChFatSem.destroy();

  _biChMensal = new Chart(document.getElementById('bi-ch-mensal'), {
    type: 'bar',
    data: { labels: mLabels, datasets: [{ data: months.map(m => byMonth[m]), backgroundColor: orange, borderRadius: 4 }] },
    options: _biChartOpts(),
  });

  _biChSemanal = new Chart(document.getElementById('bi-ch-semanal'), {
    type: 'bar',
    data: { labels: allWeeks.map(w => 'S' + w.split('-W')[1]), datasets: [{ data: allWeeks.map(w => byWeek[w] || 0), backgroundColor: orange, borderRadius: 3 }] },
    options: _biChartOpts({ indexAxis: 'y', plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ' ' + brl(ctx.parsed.x) } } } }),
  });

  _biChFatSem = new Chart(document.getElementById('bi-ch-fat-sem'), {
    type: 'line',
    data: {
      labels: wLabels,
      datasets: [
        { label: 'Faturamento', data: allWeeks.map(w => byWeekFat[w] || 0), borderColor: orange, backgroundColor: 'rgba(249,115,22,.12)', fill: true, tension: .4, pointRadius: 2, pointBackgroundColor: orange },
        { label: 'Compras',    data: allWeeks.map(w => byWeek[w]    || 0), borderColor: purple, backgroundColor: 'rgba(168,85,247,.1)',  fill: true, tension: .4, pointRadius: 2, pointBackgroundColor: purple },
      ],
    },
    options: { ..._biChartOpts(), plugins: { legend: { display: true, labels: { color: '#94a3b8', font: { size: 9 }, boxWidth: 10 } }, tooltip: { callbacks: { label: ctx => ` ${ctx.dataset.label}: ${brl(ctx.parsed.y)}` } } } },
  });

  // ── Fornecedores ──
  const topForn = Object.entries(byForn).sort((a, b) => b[1] - a[1]).slice(0, 10);
  const totForn  = topForn.reduce((s, [, v]) => s + v, 0);
  document.getElementById('bi-tb-forn').innerHTML =
    `<thead><tr><th>Fornecedor</th><th style="text-align:right">Valor</th></tr></thead><tbody>` +
    topForn.map(([n, v]) => `<tr><td>${esc(n)}</td><td style="text-align:right">${brl(v)}</td></tr>`).join('') +
    `<tr class="bi-tb-total"><td>Total compras</td><td style="text-align:right">${brl(totForn)}</td></tr></tbody>`;

  // ── Listas de categoria e tipo ──
  function _biBarList(obj) {
    const sorted = Object.entries(obj).sort((a, b) => b[1] - a[1]);
    const maxV   = sorted[0]?.[1] || 1;
    return sorted.map(([lbl, v]) =>
      `<div class="bi-bar-item">
        <span class="bi-bar-lbl" title="${esc(lbl)}">${esc(lbl)}</span>
        <div class="bi-bar-bg"><div class="bi-bar-fill" style="width:${(v/maxV*100).toFixed(1)}%"></div></div>
        <span class="bi-bar-val">${brl(v)}</span>
      </div>`).join('');
  }
  document.getElementById('bi-cat-list').innerHTML  = _biBarList(byCat);
  document.getElementById('bi-tipo-list').innerHTML = _biBarList(byTipo);
}

async function renderInsights() {
  const container = document.getElementById('insights-container');
  if (!container) return;

  const mesAtual = new Date().toISOString().slice(0, 7);
  const { data: compras } = await sb.from('cmp_compras')
    .select('data,fornecedor_nome,categoria,unidade_uso,custo_unit,quantidade')
    .order('data', { ascending: false })
    .limit(500);

  if (!compras?.length) {
    container.innerHTML = '<p class="text-muted">Lance compras para ver os insights automáticos.</p>';
    return;
  }

  const soma = c => (c.quantidade || 0) * (c.custo_unit || 0);
  const total = compras.reduce((s, c) => s + soma(c), 0);

  const _grp = (arr, keyFn) => {
    const out = {};
    arr.forEach(c => { const k = typeof keyFn === 'function' ? keyFn(c) : c[keyFn]; if (k) out[k] = (out[k] || 0) + soma(c); });
    return out;
  };

  const byForn = _grp(compras, 'fornecedor_nome');
  const byCat  = _grp(compras, 'categoria');
  const byUso  = _grp(compras, 'unidade_uso');

  const fornLider = Object.entries(byForn).sort((a,b) => b[1]-a[1])[0] || ['—', 0];
  const catLider  = Object.entries(byCat).sort((a,b)  => b[1]-a[1])[0] || ['—', 0];
  const usoLider  = Object.entries(byUso).sort((a,b)  => b[1]-a[1])[0] || ['—', 0];
  const fornPct   = total > 0 ? (fornLider[1]/total*100).toFixed(1) : '0.0';
  const catPct    = total > 0 ? (catLider[1]/total*100).toFixed(1)  : '0.0';
  const usoPct    = total > 0 ? (usoLider[1]/total*100).toFixed(1)  : '0.0';

  const comprasMes    = compras.filter(c => c.data?.startsWith(mesAtual));
  const totalMes      = comprasMes.reduce((s,c) => s + soma(c), 0);
  const diasComCompra = new Set(comprasMes.map(c => c.data)).size;
  const diaAtual      = new Date().getDate();
  const taxaAtiv      = diaAtual > 0 ? ((diasComCompra/diaAtual)*100).toFixed(0) : 0;

  const _semanaStr = d => { const dt = new Date(d + 'T12:00:00'); dt.setDate(dt.getDate() - dt.getDay()); return dt.toISOString().slice(0,10); };
  const semAtual = _semanaStr(new Date().toISOString().slice(0,10));
  const bySem = _grp(compras, c => _semanaStr(c.data));
  const sems  = [...new Set(compras.map(c => _semanaStr(c.data)))].sort();
  const idxA  = sems.indexOf(semAtual);
  const gastoAtual    = bySem[semAtual] || 0;
  const gastoAnterior = idxA > 0 ? (bySem[sems[idxA-1]] || 0) : null;
  let varSem = null;
  if (gastoAnterior > 0) varSem = ((gastoAtual - gastoAnterior) / gastoAnterior * 100).toFixed(1);

  let resumo = '';
  if (comprasMes.length) {
    resumo = `No mês corrente, o restaurante realizou <strong>${comprasMes.length} lançamento${comprasMes.length>1?'s':''}</strong>, totalizando <strong>${brl(totalMes)}</strong>. `;
    resumo += `A categoria <strong>${catLider[0]}</strong> lidera com ${catPct}% do volume, e o fornecedor <strong>${fornLider[0]}</strong> representa ${fornPct}% das compras. `;
    if (parseFloat(fornPct) > 50) resumo += `⚠️ Concentração alta em um único fornecedor — considere diversificar. `;
    if (varSem !== null) {
      const dir = parseFloat(varSem) >= 0 ? 'alta' : 'queda';
      resumo += `Esta semana apresenta <strong>${dir} de ${Math.abs(varSem)}%</strong> em relação à semana anterior.`;
    }
  } else {
    resumo = 'Não há lançamentos no mês atual. Lance compras para gerar o resumo executivo.';
  }

  const corVar = varSem !== null ? (parseFloat(varSem) <= 0 ? '#2EC4B6' : '#E71D36') : '#6c757d';
  const bullets = [
    { icon:'🏪', label:'Fornecedor Líder',      value: fornLider[0], detail:`${brl(fornLider[1])} — ${fornPct}% das compras`, cor:'#FF6B35' },
    { icon:'📂', label:'Categoria Líder',        value: catLider[0],  detail:`${brl(catLider[1])} — ${catPct}% das compras`,  cor:'#2EC4B6' },
    { icon:'🏬', label:'Canal com Mais Gastos',  value: usoLider[0],  detail:`${brl(usoLider[1])} — ${usoPct}% do volume`,   cor:'#8338EC' },
    { icon:'📅', label:'Atividade no Mês',        value:`${diasComCompra} dia${diasComCompra!==1?'s':''} com compras`, detail:`${taxaAtiv}% dos dias — ${comprasMes.length} lançamento${comprasMes.length!==1?'s':''}`, cor:'#06D6A0' },
    { icon:'📈', label:'Tendência Semanal',       value: varSem!==null?`${parseFloat(varSem)>=0?'▲':'▼'} ${Math.abs(varSem)}% vs sem. anterior`:(gastoAtual>0?'1ª semana registrada':'Sem dados'), detail: gastoAtual>0?`Gasto atual: ${brl(gastoAtual)}`:'—', cor:corVar },
  ];

  container.innerHTML = `
    <div class="row g-3 mb-3">
      ${bullets.map(b => `<div class="col-md-4 col-6">
        <div style="background:#f8f9fa;border-radius:10px;padding:1rem;border-left:4px solid ${b.cor}">
          <div style="font-size:.7rem;text-transform:uppercase;color:#6c757d;letter-spacing:.05em">${b.icon} ${b.label}</div>
          <div style="font-weight:700;font-size:.95rem;color:#1a1a2e;margin:.3rem 0">${esc(b.value)}</div>
          <div style="font-size:.78rem;color:#6c757d">${b.detail}</div>
        </div>
      </div>`).join('')}
    </div>
    <div style="background:#fff7ed;border-radius:10px;padding:1rem 1.3rem;border-left:4px solid #FF6B35">
      <div style="font-size:.7rem;text-transform:uppercase;color:#FF6B35;font-weight:700;margin-bottom:.4rem">📋 Resumo Executivo</div>
      <p style="margin:0;color:#1a1a2e;font-size:.9rem;line-height:1.7">${resumo}</p>
    </div>`;
}

const CORES_GRAFICO = [
  '#FF6B35','#2EC4B6','#8338EC','#06D6A0',
  '#FFB703','#E71D36','#118AB2','#6c757d',
];

function destroyChart(nome) {
  const m = { chMensal, chCmvMensal, chFornDash, chCatDash, chCmvEvolucao };
  if (m[nome]) { m[nome].destroy(); }
}

function numK(v) {
  if (v >= 1000) return (v/1000).toFixed(0) + 'k';
  return v.toFixed(0);
}


// ═══════════════════════════════════════════════════════════════
// LANÇAR COMPRA
// ═══════════════════════════════════════════════════════════════
async function prepararFormCompra() {
  await carregarCaches();
  await carregarProdutosFT(true); // força recarregar para pegar atualizações do cadastro
  document.getElementById('bloco-estoque').style.display = 'none';

  // Populate selects
  const catSel = document.getElementById('c-cat');
  catSel.innerHTML = '<option value="">— Selecione —</option>' +
    cCat.map(c => `<option value="${esc(c.nome)}">${esc(c.nome)}</option>`).join('');

  const tipoSel = document.getElementById('c-tipo');
  tipoSel.innerHTML = '<option value="">— Selecione —</option>' +
    cTipo.map(t => `<option value="${esc(t.nome)}">${esc(t.nome)}</option>`).join('');

  const compSel = document.getElementById('c-comp');

  const setorSel = document.getElementById('c-setor');
  if (setorSel) {
    setorSel.innerHTML = '<option value="">— Nenhum —</option>' +
      cSetores.map(s => `<option value="${esc(s.nome)}">${esc(s.nome)}</option>`).join('');
  }

  const usoSel = document.getElementById('c-uso');
  if (usoSel && cUnidades.length) {
    usoSel.innerHTML = '<option value="">— Selecione —</option>' +
      cUnidades.map(u => `<option value="${u.id}">${esc(u.nome)}</option>`).join('');
  }

  if (_pedidoEditando) {
    // Modo edição: pré-preenche cabeçalho com dados do primeiro item
    const primeiro = _pedidoItens[0];
    if (primeiro) {
      document.getElementById('c-data').value  = primeiro.data || '';
      document.getElementById('c-forn').value  = primeiro.fornNome || '';
      document.getElementById('c-forn-id').value = primeiro.fornId || '';
      if (compSel) compSel.value = primeiro.comp || '';
      if (setorSel) setorSel.value = primeiro.setor || '';
      const fmSel = document.getElementById('c-forma-pgto');
      if (fmSel) fmSel.value = primeiro.formaPagamento || '';
    }
    setMoeda('c-acrescimo', _pedidoAcrescimo || 0);
    const proxEl = document.getElementById('prox-pedido-num');
    if (proxEl) proxEl.textContent = _pedidoEditando;
    _renderItensPedido();
    document.getElementById('aviso-editando')?.classList.remove('d-none');
    document.getElementById('aviso-editando-num').textContent = _pedidoEditando;
  } else {
    // Modo novo pedido — comprador = usuário logado
    setHoje('c-data');
    const proxNum = await _gerarNumeroPedido();
    const el = document.getElementById('prox-pedido-num');
    if (el) el.textContent = proxNum;
    document.getElementById('aviso-editando')?.classList.add('d-none');
    const nomeComp = (user?.user_metadata?.nome || '').trim() || (user?.email || '').split('@')[0];
    if (compSel) compSel.value = nomeComp;
  }

  consultarPedidos();

  // Warning if missing registers
  const falta = [];
  if (!cCat.length)  falta.push('<strong>Categorias</strong>');
  if (!cTipo.length) falta.push('<strong>Destinos</strong>');

  const av = document.getElementById('aviso-cad');
  if (falta.length) {
    av.innerHTML = `⚠️ Cadastre primeiro: ${falta.join(', ')} — acesse <a href="#" onclick="ir('cadastros',document.querySelector('.nav-sb a:nth-child(6)'))">Cadastros</a>.`;
    av.classList.remove('d-none');
  } else {
    av.classList.add('d-none');
  }
}

// Autocomplete — Fornecedor
function acForn(val) {
  const lista = document.getElementById('ac-forn');
  if (!val) { lista.classList.remove('aberta'); return; }

  const hits = cForn.filter(f => norm(f.nome).includes(norm(val))).slice(0, 8);
  if (!hits.length) { lista.classList.remove('aberta'); return; }

  lista.innerHTML = hits.map(f =>
    `<div class="ac-item" onmousedown="selecionarForn('${esc(f.nome)}','${f.id}')">${esc(f.nome)}</div>`
  ).join('');
  lista.classList.add('aberta');
}

function selecionarForn(nome, id) {
  document.getElementById('c-forn').value = nome;
  document.getElementById('c-forn-id').value = id;
  fechaAC('ac-forn');
}

// Autocomplete — Produto (apenas MP e MC)
function acProd(val) {
  const lista = document.getElementById('ac-prod');
  if (!val) { lista.classList.remove('aberta'); return; }
  const q = norm(val);

  // Apenas MP e MC do catálogo
  const mpMcNomes = new Set(cProdutosFT.filter(p => ['MP','MC'].includes(p.tipo)).map(p => p.nome.toLowerCase()));
  const vistos = new Set();
  const hits = [];
  [
    ...cProd.filter(p => mpMcNomes.has(p.nome.toLowerCase())),
    ...cProdutosFT.filter(p => ['MP','MC'].includes(p.tipo)).map(p => ({ nome: p.nome, un: p.unidade_uso, cat: p.categoria })),
  ].forEach(p => {
    if (norm(p.nome).includes(q) && !vistos.has(p.nome.toLowerCase())) {
      vistos.add(p.nome.toLowerCase());
      hits.push(p);
    }
  });

  if (!hits.length) { lista.classList.remove('aberta'); return; }

  lista.innerHTML = hits.slice(0, 10).map(p =>
    `<div class="ac-item" onmousedown="selecionarProd('${esc(p.nome)}','${esc(p.un||'')}','${esc(p.cat||'')}')">${esc(p.nome)} <small class="text-muted">${esc(p.un||'')}</small></div>`
  ).join('');
  lista.classList.add('aberta');
}

function selecionarProd(nome, un, cat) {
  document.getElementById('c-prod').value = nome;

  // Histórico de compras (tem último preço pago), catálogo (tem custo_uso)
  const prodLista = cProd.find(p => p.nome.toLowerCase() === nome.toLowerCase());
  const prodCat   = cProdutosFT.find(p => p.nome.toLowerCase() === nome.toLowerCase());

  const unFinal  = prodCat?.unidade_comp || prodLista?.un || prodCat?.unidade_uso || un;
  const catFinal = prodLista?.cat || prodCat?.categoria   || cat;

  const unEl = document.getElementById('c-un');
  if (unFinal && unEl) {
    if (![...unEl.options].some(o => o.value === unFinal)) {
      unEl.add(new Option(unFinal, unFinal));
    }
    unEl.value = unFinal;
    unEl.style.pointerEvents = 'none';
    unEl.style.opacity = '0.7';
    unEl.title = 'Unidade definida pelo produto';
  }
  if (catFinal) {
    const sel = document.getElementById('c-cat');
    if ([...sel.options].some(o => o.value === catFinal)) sel.value = catFinal;
  }
  fechaAC('ac-prod');

  // Preenche custo: custo_comp do catálogo (mais atualizado) > último preço de compra > custo_uso
  const custo = prodCat?.custo_comp > 0
    ? prodCat.custo_comp
    : (prodLista?.custo_unit > 0 ? prodLista.custo_unit : (prodCat?.custo_uso || 0));
  if (custo > 0) {
    document.getElementById('c-custo').value = custo.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
    calcTot();
  }

  // Bloco de estoque mínimo
  const blocoEl = document.getElementById('bloco-estoque');
  if (prodCat && parseFloat(prodCat.estoque_min) > 0 && blocoEl) {
    document.getElementById('c-estmin-show').textContent = prodCat.estoque_min + ' ' + (prodCat.unidade_uso || '');
    document.getElementById('c-estoque-atual').value = '';
    document.getElementById('c-sugestao').textContent = '—';
    blocoEl.style.display = '';
    blocoEl.dataset.estmin = prodCat.estoque_min;
  } else if (blocoEl) {
    blocoEl.style.display = 'none';
  }
}

function calcSugestao() {
  const estMin  = parseFloat(document.getElementById('bloco-estoque')?.dataset.estmin) || 0;
  const estAtual = parseFloat(document.getElementById('c-estoque-atual')?.value) || 0;
  const sug = Math.max(0, estMin - estAtual);
  const fmtSug = sug % 1 === 0 ? String(sug) : sug.toFixed(3).replace(/\.?0+$/, '');
  document.getElementById('c-sugestao').textContent = fmtSug;
}

function aplicarSugestao() {
  const sug = document.getElementById('c-sugestao')?.textContent;
  const qtdEl = document.getElementById('c-qtd');
  if (sug && sug !== '—' && qtdEl) { qtdEl.value = sug; calcTot(); }
}

function fechaAC(id) {
  document.getElementById(id).classList.remove('aberta');
}

function mascaraMoeda(el) {
  let v = el.value.replace(/[^\d,]/g, '');
  const partes = v.split(',');
  const intRaw = partes[0].replace(/\D/g, '');
  const intFmt = intRaw ? parseInt(intRaw, 10).toLocaleString('pt-BR') : '';
  const dec    = partes[1] !== undefined ? partes[1].replace(/\D/g, '').slice(0, 2) : null;
  el.value     = dec !== null ? `${intFmt},${dec}` : intFmt;
}

function parseMoeda(id) {
  const v = document.getElementById(id)?.value || '0';
  return parseFloat(v.replace(/\./g, '').replace(',', '.')) || 0;
}

function setMoeda(id, val) {
  const el = document.getElementById(id);
  if (!el) return;
  const n = parseFloat(val) || 0;
  el.value = n ? n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '';
}

function moedaFocus(el) {
  if (el.value.endsWith(',00')) el.value = el.value.slice(0, -3);
}

function moedaBlur(el) {
  const v = el.value.replace(/\./g, '').replace(',', '.');
  const n = parseFloat(v) || 0;
  el.value = n ? n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '';
}

// Variante para custo unitário — permite até 4 casas decimais
function mascaraCusto(el) {
  let v = el.value.replace(/[^\d,]/g, '');
  const partes = v.split(',');
  const intRaw = partes[0].replace(/\D/g, '');
  const intFmt = intRaw ? parseInt(intRaw, 10).toLocaleString('pt-BR') : '';
  const dec    = partes[1] !== undefined ? partes[1].replace(/\D/g, '').slice(0, 4) : null;
  el.value     = dec !== null ? `${intFmt},${dec}` : intFmt;
}
function custoBlur(el) {
  const v = el.value.replace(/\./g, '').replace(',', '.');
  const n = parseFloat(v) || 0;
  el.value = n ? n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 4 }) : '';
}

function _parseCusto() {
  const v = document.getElementById('c-custo').value || '0';
  return parseFloat(v.replace(/\./g, '').replace(',', '.')) || 0;
}

function calcTot() {
  const custo = _parseCusto();
  const qtd   = parseFloat(document.getElementById('c-qtd').value) || 0;
  document.getElementById('c-total-show').textContent = brl(custo * qtd);
}

// Adiciona um item à lista temporária do pedido
function adicionarItemPedido(e) {
  e.preventDefault();

  const data     = document.getElementById('c-data').value;
  const fornNome = document.getElementById('c-forn').value.trim();
  const fornId   = document.getElementById('c-forn-id').value || null;
  const comp     = document.getElementById('c-comp').value;
  const prod     = document.getElementById('c-prod').value.trim();
  const cat      = document.getElementById('c-cat').value;
  const un       = document.getElementById('c-un').value;
  const custo    = _parseCusto();
  const qtd      = parseFloat(document.getElementById('c-qtd').value) || 0;
  const usoSel    = document.getElementById('c-uso');
  const usoId     = usoSel?.value || null;
  const usoNome   = usoSel?.selectedOptions[0]?.text || '';

  if (!data || !fornNome || !comp) {
    toast('Preencha Data, Fornecedor e Comprador.', 'erro'); return;
  }
  if (!prod || !cat || !custo || !qtd) {
    toast('Preencha Produto, Categoria, Custo e Quantidade.', 'erro'); return;
  }
  if (!usoId) {
    toast('Selecione a Unidade.', 'erro'); return;
  }

  const catObj     = cCat.find(c => c.nome === cat);
  const planoConta = catObj ? (catObj.plano_conta || '') : '';

  _pedidoItens.push({
    data, fornNome, fornId, comp,
    prod, cat, planoConta, un, custo, qtd,
    uso: usoNome, unidadeId: usoId,
    total: custo * qtd,
  });

  // Limpa apenas os campos de item
  document.getElementById('c-prod').value  = '';
  document.getElementById('c-custo').value = '';
  document.getElementById('c-qtd').value   = '1';
  document.getElementById('c-total-show').textContent = 'R$ 0,00';
  document.getElementById('bloco-estoque').style.display = 'none';
  const unEl = document.getElementById('c-un');
  if (unEl) { unEl.style.pointerEvents = ''; unEl.style.opacity = ''; unEl.title = ''; }
  document.getElementById('c-prod').focus();

  if (!cProd.find(p => p.nome.toLowerCase() === prod.toLowerCase())) {
    cProd.push({ nome: prod, un, cat, custo_unit: custo });
  } else {
    // Atualiza último preço pago
    const existing = cProd.find(p => p.nome.toLowerCase() === prod.toLowerCase());
    if (existing) existing.custo_unit = custo;
  }

  _renderItensPedido();
}

function _renderItensPedido() {
  const bloco   = document.getElementById('bloco-itens-pedido');
  const tbody   = document.getElementById('tb-itens-pedido');
  const tfoot   = document.getElementById('tfoot-itens-pedido');
  const btnFin  = document.getElementById('btn-finalizar-pedido');
  const btnCanc = document.getElementById('btn-cancelar-pedido');

  if (!_pedidoItens.length) {
    bloco.style.display   = 'none';
    btnFin.disabled       = true;
    btnCanc.style.display = 'none';
    return;
  }

  bloco.style.display   = '';
  btnFin.disabled       = false;
  btnCanc.style.display = '';

  tbody.innerHTML = _pedidoItens.map((it, idx) => `
    <tr id="item-row-${idx}">
      <td><strong>${esc(it.prod)}</strong></td>
      <td><small>${esc(it.cat)}</small>${it.planoConta ? `<br><small class="text-muted">${esc(it.planoConta)}</small>` : ''}</td>
      <td class="text-center">${it.qtd.toLocaleString('pt-BR', { maximumFractionDigits: 3 })}</td>
      <td class="text-center">${esc(it.un)}</td>
      <td class="text-end">${brl(it.custo)}</td>
      <td class="text-end fw-bold">${brl(it.total)}</td>
      <td class="text-center" style="white-space:nowrap">
        <button type="button" class="btn btn-sm btn-outline-primary py-0 px-1 me-1" onclick="editarItemPedido(${idx})" title="Editar">
          <i class="bi bi-pencil-fill"></i>
        </button>
        <button type="button" class="btn btn-sm btn-outline-danger py-0 px-1" onclick="removerItemPedido(${idx})" title="Excluir">
          <i class="bi bi-trash"></i>
        </button>
      </td>
    </tr>`).join('');

  // Subtotais por plano de contas
  const grupos = {};
  _pedidoItens.forEach(it => {
    const k = it.planoConta || it.cat || '—';
    grupos[k] = (grupos[k] || 0) + it.total;
  });
  const totalItens  = _pedidoItens.reduce((s, it) => s + it.total, 0);
  const acrescimo   = parseMoeda('c-acrescimo');
  const totalGeral  = totalItens + acrescimo;

  const linhasGrupo = Object.entries(grupos).map(([k, v]) =>
    `<tr class="table-light"><td colspan="5" class="text-end text-muted small">Subtotal ${esc(k)}</td><td class="text-end fw-semibold">${brl(v)}</td><td></td></tr>`
  ).join('');

  const linhaAcr = acrescimo > 0
    ? `<tr class="table-light"><td colspan="5" class="text-end text-muted small">Acréscimo (frete/taxa)</td><td class="text-end fw-semibold" style="color:#FF6B35">${brl(acrescimo)}</td><td></td></tr>`
    : '';

  tfoot.innerHTML = linhasGrupo + linhaAcr +
    `<tr class="table-success"><td colspan="5" class="text-end fw-bold">Total do Pedido</td><td class="text-end fw-bold fs-6">${brl(totalGeral)}</td><td></td></tr>`;
}

function removerItemPedido(idx) {
  _pedidoItens.splice(idx, 1);
  _renderItensPedido();
}

function editarItemPedido(idx) {
  const it  = _pedidoItens[idx];
  const row = document.getElementById(`item-row-${idx}`);
  if (!row) return;
  const custoFmt = it.custo.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
  row.innerHTML = `
    <td><strong>${esc(it.prod)}</strong></td>
    <td><small>${esc(it.cat)}</small>${it.planoConta ? `<br><small class="text-muted">${esc(it.planoConta)}</small>` : ''}</td>
    <td class="text-center" style="min-width:80px">
      <input type="number" class="form-control form-control-sm text-center p-1" id="edit-qtd-${idx}"
        value="${it.qtd}" min="0.001" step="any" oninput="atualizarTotalInline(${idx})">
    </td>
    <td class="text-center">${esc(it.un)}</td>
    <td class="text-end" style="min-width:110px">
      <input type="text" class="form-control form-control-sm text-end p-1" id="edit-custo-${idx}"
        value="${custoFmt}" oninput="mascaraCusto(this); atualizarTotalInline(${idx})" onblur="custoBlur(this); atualizarTotalInline(${idx})">
    </td>
    <td class="text-end fw-bold" id="edit-total-${idx}">${brl(it.total)}</td>
    <td class="text-center" style="white-space:nowrap">
      <button type="button" class="btn btn-sm btn-success py-0 px-1 me-1" onclick="confirmarEdicaoItem(${idx})" title="Confirmar">
        <i class="bi bi-check-lg"></i>
      </button>
      <button type="button" class="btn btn-sm btn-outline-secondary py-0 px-1" onclick="_renderItensPedido()" title="Cancelar">
        <i class="bi bi-x-lg"></i>
      </button>
    </td>`;
  document.getElementById(`edit-qtd-${idx}`)?.focus();
}

function atualizarTotalInline(idx) {
  const qtd   = parseFloat(document.getElementById(`edit-qtd-${idx}`)?.value || 0);
  const custo = parseMoeda(`edit-custo-${idx}`);
  const el    = document.getElementById(`edit-total-${idx}`);
  if (el) el.textContent = brl(qtd * custo);
}

function confirmarEdicaoItem(idx) {
  const qtd   = parseFloat(document.getElementById(`edit-qtd-${idx}`)?.value || 0);
  const custo = parseMoeda(`edit-custo-${idx}`);
  if (!qtd || qtd <= 0) { toast('Quantidade inválida.', 'erro'); return; }
  if (custo <= 0)        { toast('Custo inválido.', 'erro'); return; }
  _pedidoItens[idx].qtd   = qtd;
  _pedidoItens[idx].custo = custo;
  _pedidoItens[idx].total = qtd * custo;
  _renderItensPedido();
}

async function finalizarPedido() {
  if (!_pedidoItens.length) { toast('Adicione pelo menos um item ao pedido.', 'erro'); return; }

  const btn = document.getElementById('btn-finalizar-pedido');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Salvando...';

  const pedido_num    = _pedidoEditando || await _gerarNumeroPedido();
  const acrescimo     = parseMoeda('c-acrescimo');
  const setor         = document.getElementById('c-setor')?.value || '';
  const forma_pagamento = document.getElementById('c-forma-pgto')?.value || '';
  if (!forma_pagamento) {
    toast('Selecione a Forma de Pagamento.', 'erro');
    btn.disabled = false;
    btn.innerHTML = '<i class="bi bi-check-circle-fill"></i> Finalizar Pedido';
    return;
  }

  const rows = _pedidoItens.map(it => ({
    data:            it.data,
    pedido_num,
    fornecedor_id:   it.fornId,
    fornecedor_nome: it.fornNome,
    produto:         it.prod,
    categoria:       it.cat,
    plano_conta:     it.planoConta,
    tipo_produto:    it.uso,
    unidade_med:     it.un,
    custo_unit:      it.custo,
    quantidade:      it.qtd,
    comprador:       it.comp,
    unidade_uso:     it.uso,
    observacao:      null,
    acrescimo,
    setor,
    forma_pagamento,
    status_receb:    'pendente',
    criado_por:      user.id,
  }));

  if (_pedidoEditando) {
    await sb.from('cmp_compras').delete().eq('pedido_num', _pedidoEditando);
  }

  const { error } = await sb.from('cmp_compras').insert(rows);

  btn.disabled = false;
  btn.innerHTML = '<i class="bi bi-check-circle-fill"></i> Finalizar Pedido';

  if (error) { toast('Erro ao salvar pedido: ' + error.message, 'erro'); return; }

  const total = _pedidoItens.reduce((s, it) => s + it.total, 0);
  const acao  = _pedidoEditando ? 'atualizado' : 'finalizado';
  toast(`✅ Pedido ${pedido_num} ${acao} — ${_pedidoItens.length} item(s) — ${brl(total)}`, 'ok');

  cancelarPedido();
  consultarPedidos();
}

function cancelarPedido() {
  _pedidoItens     = [];
  _pedidoEditando  = null;
  _pedidoAcrescimo = 0;
  setMoeda('c-acrescimo', 0);
  const setorSel = document.getElementById('c-setor');
  if (setorSel) setorSel.value = '';
  const formaPgtoSel = document.getElementById('c-forma-pgto');
  if (formaPgtoSel) formaPgtoSel.value = '';
  _renderItensPedido();

  // Oculta aviso de edição
  document.getElementById('aviso-editando')?.classList.add('d-none');

  // Limpa cabeçalho e campos de item
  document.getElementById('c-prod').value  = '';
  document.getElementById('c-custo').value = '';
  document.getElementById('c-qtd').value   = '1';
  document.getElementById('c-total-show').textContent = 'R$ 0,00';
  document.getElementById('bloco-estoque').style.display = 'none';
}


// ═══════════════════════════════════════════════════════════════
// FATURAMENTO
// ═══════════════════════════════════════════════════════════════
async function salvarFaturamento() {
  const data  = document.getElementById('f-data').value;
  const valor = parseMoeda('f-valor');
  const canal = document.getElementById('f-canal').value;
  const obs   = document.getElementById('f-obs').value.trim();

  if (!data || !valor || valor <= 0) {
    toast('Informe data e valor.', 'erro'); return;
  }

  const { error } = await sb.from('cmp_faturamento').insert([{
    data, valor, canal, observacao: obs || null, criado_por: user.id,
  }]);

  if (error) { toast('Erro ao salvar.', 'erro'); return; }

  toast('Faturamento salvo!', 'ok');
  document.getElementById('f-valor').value = '';
  document.getElementById('f-obs').value   = '';
  carregarFaturamento();
}

async function carregarFaturamento() {
  const mes = document.getElementById('f-filtro-mes').value;
  if (!mes) return;

  const { data } = await sb.from('cmp_faturamento')
    .select('*')
    .gte('data', mes + '-01')
    .lte('data', mes + '-31')
    .order('data', { ascending: false });

  const rows  = data || [];
  const total = rows.reduce((s, r) => s + (r.valor || 0), 0);

  document.getElementById('tb-faturamento').innerHTML = rows.length
    ? rows.map(r => `
        <tr>
          <td>${fmtData(r.data)}</td>
          <td>${esc(r.canal)}</td>
          <td class="fw-semibold text-success">${brl(r.valor)}</td>
          <td class="text-muted">${esc(r.observacao || '')}</td>
          <td>
            <button class="btn-del" onclick="excluirFaturamento('${r.id}')" title="Excluir">
              <i class="bi bi-trash"></i>
            </button>
          </td>
        </tr>`).join('')
    : '<tr><td colspan="5" class="text-center text-muted py-3">Nenhum lançamento no período.</td></tr>';

  document.getElementById('fat-total-mes').textContent = 'Total do mês: ' + brl(total);
}

async function excluirFaturamento(id) {
  if (!confirm('Excluir este lançamento de faturamento?')) return;
  const { error } = await sb.from('cmp_faturamento').delete().eq('id', id);
  if (error) { toast('Erro ao excluir.', 'erro'); return; }
  toast('Excluído.', 'ok');
  carregarFaturamento();
}


// ═══════════════════════════════════════════════════════════════
// CMV
// ═══════════════════════════════════════════════════════════════
async function carregarCMV() {
  const periodo = document.getElementById('cmv-periodo').value;

  const [rc, rf] = await Promise.all([
    sb.from('cmp_compras').select('data,total').order('data'),
    sb.from('cmp_faturamento').select('data,valor').order('data'),
  ]);

  const compras     = rc.data || [];
  const faturamento = rf.data || [];

  if (!compras.length) {
    document.getElementById('tb-cmv').innerHTML =
      '<tr><td colspan="5" class="text-center text-muted py-4">Lance compras para calcular o CMV.</td></tr>';
    return;
  }

  // Build period buckets
  const bucket = {};
  const chave  = d => periodo === 'mes' ? mesDeData(d) : semanaISO(d);

  compras.forEach(c => {
    const k = chave(c.data);
    if (!bucket[k]) bucket[k] = { comp: 0, fat: 0 };
    bucket[k].comp += c.total || 0;
  });
  faturamento.forEach(f => {
    const k = chave(f.data);
    if (!bucket[k]) bucket[k] = { comp: 0, fat: 0 };
    bucket[k].fat += f.valor || 0;
  });

  const periodos = Object.keys(bucket).sort();
  const ultimo   = periodos[periodos.length - 1];

  // ── KPIs ──
  if (ultimo) {
    const u      = bucket[ultimo];
    const cmvPct = u.fat > 0 ? (u.comp / u.fat * 100) : null;
    const card   = document.getElementById('kpi-cmv-periodo-card');

    document.getElementById('cmv-pct-atual').textContent  = pct(cmvPct);
    document.getElementById('cmv-comp-atual').textContent = brl(u.comp);
    document.getElementById('cmv-fat-atual').textContent  = brl(u.fat);

    card.classList.remove('kpi-ok', 'kpi-ruim');
    if (cmvPct !== null) card.classList.add(cmvPct <= 27 ? 'kpi-ok' : 'kpi-ruim');

    // Alert
    const alerta = document.getElementById('cmv-alerta');
    if (cmvPct !== null) {
      if (cmvPct <= 27) {
        alerta.className = 'alert alert-success mb-4';
        alerta.textContent = `✅ CMV dentro da meta! ${pct(cmvPct)} ≤ 27%`;
      } else {
        const excesso = u.comp - (u.fat * 0.27);
        alerta.className = 'alert alert-danger mb-4';
        alerta.innerHTML = `⚠️ <strong>CMV acima da meta!</strong> ${pct(cmvPct)} &gt; 27%. Comprou <strong>${brl(excesso)}</strong> a mais do que o ideal no período.`;
      }
      alerta.classList.remove('d-none');
    } else {
      alerta.classList.add('d-none');
    }
  }

  // ── Chart ──
  if (chCmvEvolucao) { chCmvEvolucao.destroy(); chCmvEvolucao = null; }
  const ctx = document.getElementById('ch-cmv-evolucao');
  if (ctx) {
    const vals = periodos.map(p => {
      const d = bucket[p];
      return d.fat > 0 ? parseFloat((d.comp / d.fat * 100).toFixed(1)) : null;
    });
    chCmvEvolucao = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: periodos,
        datasets: [{
          label: 'CMV %',
          data: vals,
          backgroundColor: vals.map(v => v == null ? '#dee2e6' : v <= 27 ? '#2EC4B6' : '#E71D36'),
          borderRadius: 5,
          borderSkipped: false,
        }],
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          annotation: {},
        },
        scales: {
          y: { ticks: { callback: v => v + '%' }, suggestedMax: 40 },
        },
      },
    });
  }

  // ── Table ──
  document.getElementById('tb-cmv').innerHTML = [...periodos].reverse().map(p => {
    const d   = bucket[p];
    const cmv = d.fat > 0 ? (d.comp / d.fat * 100) : null;
    const ok  = cmv !== null && cmv <= 27;
    return `<tr>
      <td class="fw-semibold">${p}</td>
      <td>${brl(d.comp)}</td>
      <td>${brl(d.fat)}</td>
      <td class="${cmv == null ? '' : ok ? 'text-success fw-bold' : 'text-danger fw-bold'}">${pct(cmv)}</td>
      <td>${cmv == null
        ? '<span class="badge bg-secondary">sem fat.</span>'
        : ok
          ? '<span class="badge bg-success">✅ OK</span>'
          : '<span class="badge bg-danger">⚠️ Alto</span>'
      }</td>
    </tr>`;
  }).join('');
}


// ═══════════════════════════════════════════════════════════════
// HISTÓRICO
// ═══════════════════════════════════════════════════════════════
async function carregarHistorico() {
  const mes  = document.getElementById('hist-mes').value;
  const forn = document.getElementById('hist-forn').value;
  const cat  = document.getElementById('hist-cat').value;
  const comp = document.getElementById('hist-comp').value;
  const tipo = document.getElementById('hist-tipo').value;

  let q = sb.from('cmp_compras')
    .select('id,data,fornecedor_nome,produto,categoria,tipo_produto,unidade_med,quantidade,custo_unit,total,comprador,unidade_uso')
    .order('data', { ascending: false })
    .order('criado_em', { ascending: false })
    .limit(600);

  if (mes)  { q = q.gte('data', mes + '-01').lte('data', mes + '-31'); }
  if (forn) { q = q.eq('fornecedor_nome', forn); }
  if (cat)  { q = q.eq('categoria', cat); }
  if (comp) { q = q.eq('comprador', comp); }
  if (tipo) { q = q.eq('tipo_produto', tipo); }

  const { data } = await q;
  const rows  = data || [];
  const total = rows.reduce((s, r) => s + (r.total || 0), 0);

  document.getElementById('hist-count').textContent = `${rows.length} lançamento(s)`;
  document.getElementById('hist-total').textContent = 'Total: ' + brl(total);

  // Populate filter dropdowns with unique values from current result
  if (!forn) preencherFiltro('hist-forn', rows, 'fornecedor_nome');
  if (!cat)  preencherFiltro('hist-cat',  rows, 'categoria');
  if (!comp) preencherFiltro('hist-comp', rows, 'comprador');
  if (!tipo) preencherFiltro('hist-tipo', rows, 'tipo_produto');

  document.getElementById('tb-historico').innerHTML = rows.length
    ? rows.map(r => `
        <tr>
          <td>${fmtData(r.data)}</td>
          <td>${esc(r.fornecedor_nome)}</td>
          <td>${esc(r.produto)}</td>
          <td>${esc(r.categoria)}</td>
          <td>${esc(r.tipo_produto || '')}</td>
          <td>${esc(r.unidade_med)}</td>
          <td>${Number(r.quantidade).toLocaleString('pt-BR', { maximumFractionDigits: 3 })}</td>
          <td>${brl(r.custo_unit)}</td>
          <td class="fw-semibold">${brl(r.total)}</td>
          <td>${esc(r.comprador || '')}</td>
          <td>${esc(r.unidade_uso || '')}</td>
          <td>
            <button class="btn-del" onclick="excluirCompra('${r.id}')" title="Excluir">
              <i class="bi bi-trash"></i>
            </button>
          </td>
        </tr>`).join('')
    : '<tr><td colspan="12" class="text-center text-muted py-4">Nenhum lançamento encontrado.</td></tr>';
}

function preencherFiltro(id, rows, campo) {
  const sel = document.getElementById(id);
  const val = sel.value;
  const opts = [...new Set(rows.map(r => r[campo]).filter(Boolean))].sort();
  sel.innerHTML = '<option value="">Todos</option>' +
    opts.map(o => `<option value="${esc(o)}">${esc(o)}</option>`).join('');
  sel.value = val;
}

function limparFiltrosHist() {
  ['hist-forn','hist-cat','hist-comp','hist-tipo'].forEach(id => {
    document.getElementById(id).innerHTML = '<option value="">Todos</option>';
  });
  carregarHistorico();
}

async function excluirCompra(id) {
  if (!confirm('Excluir este lançamento de compra?')) return;
  const { error } = await sb.from('cmp_compras').delete().eq('id', id);
  if (error) { toast('Não foi possível excluir.', 'erro'); return; }
  toast('Lançamento excluído.', 'ok');
  carregarHistorico();
}


// ═══════════════════════════════════════════════════════════════
// IMPORTAR EXCEL — HISTÓRICO
// ═══════════════════════════════════════════════════════════════
async function importarComprasExcel(event) {
  const file = event.target.files[0];
  if (!file) return;

  const msg = document.getElementById('msg-import');
  msg.innerHTML = '<span class="text-muted">Lendo arquivo...</span>';

  try {
    const buf  = await file.arrayBuffer();
    const wb   = XLSX.read(buf, { type: 'array' });
    const ws   = wb.Sheets[wb.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(ws, { defval: '' });

    if (!rows.length) { msg.innerHTML = '<span class="text-danger">Arquivo vazio.</span>'; return; }

    // Normalize column names
    const norm = s => String(s).toLowerCase()
      .normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9]/g, '_');

    const normalizeRow = row => {
      const out = {};
      Object.keys(row).forEach(k => { out[norm(k)] = row[k]; });
      return out;
    };

    // Map columns — flexible matching
    const mapCol = (row, ...options) => {
      for (const opt of options) {
        const v = row[norm(opt)] ?? row[opt];
        if (v !== undefined && v !== '') return String(v).trim();
      }
      return '';
    };

    const parseDate = v => {
      if (!v) return null;
      const s = String(v).trim();
      // DD/MM/YYYY
      const m1 = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
      if (m1) return `${m1[3]}-${m1[2].padStart(2,'0')}-${m1[1].padStart(2,'0')}`;
      // YYYY-MM-DD
      if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
      // Excel serial
      if (!isNaN(s)) {
        const d = new Date(Math.round((Number(s) - 25569) * 86400 * 1000));
        return d.toISOString().split('T')[0];
      }
      return null;
    };

    const parseNum = v => {
      if (v === '' || v == null) return null;
      return parseFloat(String(v).replace(',', '.'));
    };

    const registros = [];
    const erros     = [];

    rows.forEach((rawRow, idx) => {
      const row        = normalizeRow(rawRow);
      const data       = parseDate(mapCol(row, 'Data', 'Data Compra', 'data_compra', 'data'));
      const fornNome   = mapCol(row, 'Fornecedor', 'fornecedor');
      const produto    = mapCol(row, 'Produto', 'produto', 'Item', 'item');
      const categoria  = mapCol(row, 'Categoria', 'categoria');
      const tipo       = mapCol(row, 'Tipo', 'tipo_produto', 'Destino', 'destino', 'Tipo Produto');
      const un         = mapCol(row, 'Unidade', 'Un', 'Unidade Medida', 'unidade_med', 'unidade') || 'UN';
      const custo      = parseNum(mapCol(row, 'Custo Unitario', 'Custo Unit', 'custo_unitario', 'custo_unit', 'Valor Unit', 'valor_unit'));
      const qtd        = parseNum(mapCol(row, 'Quantidade', 'quantidade', 'Qtd', 'qtd')) || 1;
      const comprador  = mapCol(row, 'Comprador', 'comprador');
      const uso        = mapCol(row, 'Unidade Uso', 'unidade_uso', 'Uso', 'uso') || 'Loja';

      if (!data)      { erros.push(`Linha ${idx + 2}: data inválida.`);        return; }
      if (!fornNome)  { erros.push(`Linha ${idx + 2}: fornecedor ausente.`);    return; }
      if (!produto)   { erros.push(`Linha ${idx + 2}: produto ausente.`);       return; }
      if (!categoria) { erros.push(`Linha ${idx + 2}: categoria ausente.`);     return; }
      if (!custo || custo <= 0) { erros.push(`Linha ${idx + 2}: custo inválido.`); return; }

      registros.push({
        data,
        fornecedor_nome: fornNome,
        produto,
        categoria,
        tipo_produto:    tipo || null,
        unidade_med:     un.toUpperCase(),
        custo_unit:      custo,
        quantidade:      qtd,
        comprador:       comprador || null,
        unidade_uso:     uso,
        criado_por:      user.id,
      });
    });

    if (!registros.length) {
      msg.innerHTML = `<span class="text-danger">Nenhum registro válido. ${erros[0] || ''}</span>`;
      return;
    }

    msg.innerHTML = `<span class="text-muted">Salvando ${registros.length} registros...</span>`;

    // Insert in batches of 100
    let salvos = 0;
    for (let i = 0; i < registros.length; i += 100) {
      const { error } = await sb.from('cmp_compras').insert(registros.slice(i, i + 100));
      if (error) { msg.innerHTML = `<span class="text-danger">Erro ao salvar: ${error.message}</span>`; return; }
      salvos += Math.min(100, registros.length - i);
    }

    const avisoErros = erros.length
      ? ` <span class="text-warning">(${erros.length} linha(s) ignorada(s) por dados inválidos)</span>`
      : '';

    msg.innerHTML = `<span class="text-success fw-semibold">✅ ${salvos} lançamentos importados!${avisoErros}</span>`;
    toast(`${salvos} compras importadas!`, 'ok');
    event.target.value = '';
    carregarHistorico();

  } catch (err) {
    msg.innerHTML = `<span class="text-danger">Erro ao ler arquivo: ${err.message}</span>`;
  }
}


// ═══════════════════════════════════════════════════════════════
// CADASTROS
// ═══════════════════════════════════════════════════════════════
async function renderListaCad(tipo) {
  const cfg = {
    fornecedores: { tbl: 'fornecedores',      el: 'lst-fornecedores', extra: null },
    categorias:   { tbl: 'cmp_categorias',    el: 'lst-categorias',   extra: r => r.plano_conta ? `<small class="text-muted ms-2">→ ${esc(r.plano_conta)}</small>` : '<small class="text-warning ms-2">sem plano</small>' },
    tipos:        { tbl: 'cmp_tipos_produto', el: 'lst-tipos',        extra: null },
    setores:      { tbl: 'cmp_setores',       el: 'lst-setores',      extra: null },
  };

  const c = cfg[tipo];
  if (!c) return;

  const cols = c.tbl === 'cmp_categorias' ? 'id,nome,plano_conta,plano_conta_id' : 'id,nome';
  const { data } = await sb.from(c.tbl).select(cols).order('nome');
  const rows = data || [];
  const el   = document.getElementById(c.el);

  el.innerHTML = rows.length
    ? rows.map(r => `
        <div class="lista-item">
          <span>${esc(r.nome)}${c.extra ? c.extra(r) : ''}</span>
          <div class="d-flex gap-1">
            ${tipo === 'categorias' ? `
            <button class="btn-del" style="background:#e8f4f8;color:#0d6efd" onclick="editarPlanoCategoria('${r.id}','${esc(r.nome)}','${r.plano_conta_id||''}')" title="Editar plano de contas">
              <i class="bi bi-pencil"></i>
            </button>` : ''}
            <button class="btn-del" onclick="excluirCad('${c.tbl}','${r.id}','${tipo}')" title="Excluir">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>`).join('')
    : '<p class="text-muted small p-2 mb-0">Nenhum item cadastrado.</p>';
}

async function addFornecedor() {
  const nome = (document.getElementById('n-forn').value || '').trim();
  if (!nome) return;
  const msg = document.getElementById('msg-cad-forn');
  const { error } = await sb.from('fornecedores').insert([{ nome }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Já existe ou erro: ${error.message}</span>`; return; }
  document.getElementById('n-forn').value = '';
  msg.innerHTML = '';
  toggleFormCad('forn');
  toast('Fornecedor adicionado!', 'ok');
  await carregarCaches();
  renderListaCad('fornecedores');
}

async function addCategoria() {
  const planoId  = document.getElementById('n-plano').value || null;
  const msg      = document.getElementById('msg-cad-cat');
  if (!planoId) {
    msg.innerHTML = '<span class="text-danger">Selecione uma categoria do plano de contas.</span>';
    return;
  }
  const planoObj = cPlanoConta.find(p => p.id === planoId);
  const nome     = planoObj?.nome || '';
  if (!nome) return;
  const { error } = await sb.from('cmp_categorias').insert([{
    nome,
    plano_conta:    nome,
    plano_conta_id: planoId,
  }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Já existe ou erro: ${error.message}</span>`; return; }
  document.getElementById('n-plano').value = '';
  msg.innerHTML = '';
  toggleFormCad('cat');
  toast('Categoria adicionada!', 'ok');
  await carregarCaches();
  renderListaCad('categorias');
}

async function addTipo() {
  const nome = (document.getElementById('n-tipo').value || '').trim();
  if (!nome) return;
  const msg = document.getElementById('msg-cad-tipo');
  const { error } = await sb.from('cmp_tipos_produto').insert([{ nome }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Já existe ou erro: ${error.message}</span>`; return; }
  document.getElementById('n-tipo').value = '';
  msg.innerHTML = '';
  toggleFormCad('tipo');
  toast('Destino adicionado!', 'ok');
  await carregarCaches();
  renderListaCad('tipos');
}


async function addSetor() {
  const nome = (document.getElementById('n-setor').value || '').trim();
  if (!nome) return;
  const msg = document.getElementById('msg-cad-setor');
  const { error } = await sb.from('cmp_setores').insert([{ nome }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Já existe ou erro: ${error.message}</span>`; return; }
  document.getElementById('n-setor').value = '';
  msg.innerHTML = '';
  toggleFormCad('setor');
  toast('Setor adicionado!', 'ok');
  await carregarCaches();
  renderListaCad('setores');
}

async function excluirCad(tabela, id, tipo) {
  if (!confirm('Excluir este item?')) return;
  const { error } = await sb.from(tabela).delete().eq('id', id);
  if (error) { toast('Não é possível excluir — pode estar em uso.', 'erro'); return; }
  toast('Excluído.', 'ok');
  await carregarCaches();
  renderListaCad(tipo);
}

async function editarPlanoCategoria(catId, catNome, planoAtualId) {
  document.getElementById('epc-titulo').textContent = catNome;
  document.getElementById('epc-cat-id').value       = catId;
  document.getElementById('epc-plano').innerHTML    = '<option value="">Carregando...</option>';

  new bootstrap.Modal(document.getElementById('modal-editar-plano-cat')).show();

  const todos   = await fetchTodosPlanoContas();
  const grupos  = todos.filter(p => p.tipo === 'pagar' && !p.grupo_id);
  const subcats = todos.filter(p => p.tipo === 'pagar' &&  p.grupo_id);
  // Atualiza o cache para que salvarPlanoCategoria encontre o nome da subcategoria
  cPlanoContaGrupos = grupos;
  cPlanoConta = subcats;

  const sel = document.getElementById('epc-plano');
  sel.innerHTML = buildPlanoSelect('— Sem vínculo —', planoAtualId, grupos, subcats);
  // Se o ID salvo é grupo-pai (não subcategoria), limpa para forçar nova escolha
  const isSubcat = subcats.some(p => p.id === planoAtualId);
  sel.value = isSubcat ? (planoAtualId || '') : '';
}

async function salvarPlanoCategoria() {
  const catId   = document.getElementById('epc-cat-id').value;
  const novoId  = document.getElementById('epc-plano').value || null;
  const planoObj = cPlanoConta.find(p => p.id === novoId);
  const planoNome = planoObj?.nome || '';

  const { error } = await sb.from('cmp_categorias').update({
    plano_conta_id: novoId || null,
    plano_conta:    planoNome,
  }).eq('id', catId);

  bootstrap.Modal.getInstance(document.getElementById('modal-editar-plano-cat'))?.hide();

  if (error) { toast('Erro ao atualizar: ' + error.message, 'erro'); return; }
  toast(`✅ Plano de contas atualizado!`, 'ok');
  await carregarCaches();
  renderListaCad('categorias');
}


// ═══════════════════════════════════════════════════════════════
// GRUPOS DE PRODUTO
// ═══════════════════════════════════════════════════════════════

async function carregarGrupos() {
  const { data } = await sb.from('est_grupos_produto').select('id,nome').order('nome');
  cGrupos = data || [];
  renderListaGrupos();
}

function renderListaGrupos() {
  const lst = document.getElementById('lst-grupos');
  if (!lst) return;
  if (!cGrupos.length) {
    lst.innerHTML = '<tr><td colspan="2" class="text-center text-muted py-4">Nenhum grupo cadastrado.</td></tr>';
    document.getElementById('grupos-count').textContent = '';
    return;
  }
  lst.innerHTML = cGrupos.map(g => `
    <tr id="grupo-tr-${g.id}">
      <td>${esc(g.nome)}</td>
      <td class="text-end">
        <div class="d-flex gap-1 justify-content-end">
          <button class="btn-del" style="background:#e8f4f8;color:#0d6efd" onclick="editarGrupo(${g.id},'${esc(g.nome)}')" title="Renomear">
            <i class="bi bi-pencil"></i>
          </button>
          <button class="btn-del" onclick="excluirGrupo(${g.id},'${esc(g.nome)}')" title="Excluir">
            <i class="bi bi-trash3"></i>
          </button>
        </div>
      </td>
    </tr>`).join('');
  const cnt = document.getElementById('grupos-count');
  if (cnt) cnt.textContent = `${cGrupos.length} grupo(s) cadastrado(s)`;
}

async function addGrupo() {
  const nome = (document.getElementById('n-grupo').value || '').trim().toUpperCase();
  const msg  = document.getElementById('msg-cad-grupo');
  if (!nome) { msg.innerHTML = '<span class="text-danger">Informe o nome do grupo.</span>'; return; }
  const { error } = await sb.from('est_grupos_produto').insert([{ nome }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Erro: ${error.message}</span>`; return; }
  msg.innerHTML = '';
  document.getElementById('n-grupo').value = '';
  toggleFormCad('grupo');
  toast('Grupo adicionado!', 'ok');
  await carregarGrupos();
}

async function excluirGrupo(id, nome) {
  if (!confirm(`Excluir o grupo "${nome}"?`)) return;
  const { error } = await sb.from('est_grupos_produto').delete().eq('id', id);
  if (error) { toast('Não foi possível excluir.', 'erro'); return; }
  toast('Grupo excluído.', 'ok');
  await carregarGrupos();
}

function editarGrupo(id, nomeAtual) {
  const tr = document.getElementById(`grupo-tr-${id}`);
  if (!tr) return;
  tr.innerHTML = `
    <td>
      <input type="text" class="form-control form-control-sm" id="edit-grupo-${id}"
        value="${esc(nomeAtual)}" style="max-width:300px"
        onkeydown="if(event.key==='Enter') salvarEdicaoGrupo(${id}); if(event.key==='Escape') carregarGrupos()">
    </td>
    <td class="text-end d-flex gap-1 justify-content-end">
      <button class="btn btn-sm btn-primary py-0 px-2" onclick="salvarEdicaoGrupo(${id})" title="Salvar">
        <i class="bi bi-check-lg"></i>
      </button>
      <button class="btn btn-sm btn-outline-secondary py-0 px-2" onclick="carregarGrupos()" title="Cancelar">
        <i class="bi bi-x-lg"></i>
      </button>
    </td>`;
  document.getElementById(`edit-grupo-${id}`)?.focus();
}

async function salvarEdicaoGrupo(id) {
  const nome = (document.getElementById(`edit-grupo-${id}`)?.value || '').trim().toUpperCase();
  if (!nome) { toast('Informe o nome do grupo.', 'erro'); return; }

  const nomeAntigo = cGrupos.find(g => g.id == id)?.nome || '';

  const { data, error } = await sb.from('est_grupos_produto').update({ nome }).eq('id', id).select();
  if (error) { toast('Erro ao atualizar: ' + error.message, 'erro'); return; }
  if (!data || data.length === 0) {
    toast('Sem permissão para editar grupos. Verifique as políticas RLS no Supabase.', 'erro');
    await carregarGrupos();
    return;
  }

  // Atualiza também todos os produtos que usavam o nome antigo
  if (nomeAntigo && nomeAntigo !== nome) {
    await sb.from('est_produtos').update({ categoria: nome }).eq('categoria', nomeAntigo);
    // Reseta o filtro de grupo da lista de produtos para forçar recarregar
    const selCat = document.getElementById('ft-cat');
    if (selCat) selCat.innerHTML = '<option value="">Todos</option>';
    await carregarProdutosFT(true);
  }

  toast('Grupo atualizado!', 'ok');
  await carregarGrupos();
}

function preencherSelectGrupo(valorAtual) {
  const sel = document.getElementById('prod-cat');
  if (!sel) return;
  sel.innerHTML = '<option value="">— Selecione —</option>' +
    cGrupos.map(g => `<option value="${esc(g.nome)}"${g.nome === valorAtual ? ' selected' : ''}>${esc(g.nome)}</option>`).join('');
}

// ═══════════════════════════════════════════════════════════════
// FICHAS TÉCNICAS
// ═══════════════════════════════════════════════════════════════

async function carregarProdutosFT(forcar = false) {
  if (cProdutosFT.length && !forcar) return;
  const PAGE = 1000;
  let todos = [], from = 0, continua = true;
  while (continua) {
    const { data } = await sb.from('est_produtos')
      .select('id,nome,tipo,categoria,plano_cat,unidade_comp,unidade_uso,custo_comp,custo_uso,preco_venda,estoque_min,ativo,fator_conversao,perda')
      .eq('ativo', true)
      .order('nome')
      .range(from, from + PAGE - 1);
    if (data && data.length) {
      todos = todos.concat(data);
      continua = data.length === PAGE;
      from += PAGE;
    } else {
      continua = false;
    }
  }
  cProdutosFT = todos;
}

async function carregarFichas() {
  await carregarProdutosFT();

  const busca  = norm(document.getElementById('ft-busca')?.value);
  const tipo   = document.getElementById('ft-tipo')?.value   || '';
  const cat    = document.getElementById('ft-cat')?.value    || '';
  const status = document.getElementById('ft-status')?.value ?? '';

  // Popula categorias no select (só na primeira vez ou quando vazio)
  const selCat = document.getElementById('ft-cat');
  if (selCat && selCat.options.length <= 1) {
    const cats = [...new Set(cProdutosFT.map(p => p.categoria).filter(Boolean))].sort();
    cats.forEach(c => {
      const o = document.createElement('option');
      o.value = c; o.textContent = c;
      selCat.appendChild(o);
    });
  }

  const { data: fichas } = await sb.from('est_fichas_tecnicas')
    .select('id,produto_id,rendimento,unidade_rendimento,custo_total,custo_por_porcao,ativo')
    .eq('ativo', true);

  ftFichasCache = fichas || [];
  const fichaByProd = {};
  ftFichasCache.forEach(f => { fichaByProd[f.produto_id] = f; });

  let prods = [...cProdutosFT];

  if (tipo)   prods = prods.filter(p => p.tipo === tipo);
  if (cat)    prods = prods.filter(p => p.categoria === cat);
  if (busca)  prods = prods.filter(p => norm(p.nome).includes(busca));
  if (status === 'com') prods = prods.filter(p => fichaByProd[p.id]);
  if (status === 'sem') prods = prods.filter(p => !fichaByProd[p.id]);

  document.getElementById('ft-count').textContent =
    `${prods.length} produto(s) encontrado(s)`;

  const tbody = document.getElementById('tb-fichas');

  if (!prods.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-4">Nenhum produto encontrado.</td></tr>';
    return;
  }

  tbody.innerHTML = prods.map(p => {
    return `<tr onclick="abrirProduto('${p.id}')" style="cursor:pointer">
      <td class="fw-semibold">${esc(p.nome)}</td>
      <td><span class="badge-tipo badge-${p.tipo.toLowerCase()}">${p.tipo}</span></td>
      <td class="text-muted small">${esc(p.categoria || '')}</td>
      <td class="text-center">${esc(p.unidade_comp || '—')}</td>
      <td class="text-center">${esc(p.unidade_uso  || '—')}</td>
      <td class="text-end">${p.custo_comp > 0 ? brl(p.custo_comp) : '—'}</td>
      <td class="text-end">${p.preco_venda > 0 ? brl(p.preco_venda) : '—'}</td>
    </tr>`;
  }).join('');
}

function filtrarFichas() { carregarFichas(); }

async function abrirModalFicha(prodId = '', fichaId = '') {
  await carregarProdutosFT();
  ftIngredientes = [];

  document.getElementById('ft-ficha-id').value       = fichaId;
  document.getElementById('ft-produto-id').value     = prodId;
  document.getElementById('ft-produto-nome').value   = '';
  document.getElementById('ft-produto-info').textContent = '';
  document.getElementById('ft-rendimento').value     = '1';
  document.getElementById('ft-unidade-rend').value   = 'porção';
  document.getElementById('ft-custo-total').textContent = 'R$ 0,00';
  document.getElementById('ft-custo-porcao').textContent = '';
  document.getElementById('ft-ing-nome').value = '';
  document.getElementById('ft-ing-id').value   = '';
  document.getElementById('ft-ing-qtd').value  = '1';
  document.getElementById('ft-ing-un').value   = 'UN';
  document.getElementById('ft-ing-info').textContent = '';

  if (prodId) {
    const p = cProdutosFT.find(x => x.id === prodId);
    if (p) {
      document.getElementById('ft-produto-nome').value = p.nome;
      document.getElementById('ft-produto-info').textContent =
        `Tipo: ${p.tipo} | Preço venda: ${p.preco_venda > 0 ? brl(p.preco_venda) : '—'}`;
    }
  }

  document.getElementById('btn-del-ficha').style.display = fichaId ? '' : 'none';

  if (fichaId) {
    document.getElementById('modal-ficha-titulo').textContent = 'Editar Ficha Técnica';
    // Load existing ingredients
    const { data: ings } = await sb.from('est_ficha_ingredientes')
      .select('id,ingrediente_id,quantidade,unidade')
      .eq('ficha_id', fichaId);

    if (ings) {
      for (const ing of ings) {
        const prod = cProdutosFT.find(x => x.id === ing.ingrediente_id);
        if (prod) {
          const fator      = prod.fator_conversao || 1;
          const perda      = prod.perda || 0;
          const rendimento = 1 - (perda / 100);
          const custoBase  = prod.custo_comp || prod.custo_uso || 0;
          const custoEfetivo = rendimento > 0 ? (custoBase / fator) / rendimento : 0;
          ftIngredientes.push({
            id:         ing.id,
            prod_id:    ing.ingrediente_id,
            nome:       prod.nome,
            tipo:       prod.tipo,
            quantidade: ing.quantidade,
            unidade:    ing.unidade,
            custo_uso:  custoEfetivo,
          });
        }
      }
    }

    const ficha = ftFichasCache.find(f => f.id === fichaId);
    if (ficha) {
      document.getElementById('ft-rendimento').value     = ficha.rendimento;
      document.getElementById('ft-unidade-rend').value   = ficha.unidade_rendimento;
    }
  } else {
    document.getElementById('modal-ficha-titulo').textContent = 'Nova Ficha Técnica';
  }

  renderIngredientes();

  const modal = new bootstrap.Modal(document.getElementById('modal-ficha'));
  modal.show();
}

// Autocomplete produto (para o campo "Produto" da ficha)
function acFichaProduto(val) {
  const lista = document.getElementById('ac-ft-produto');
  if (!val) { lista.classList.remove('aberta'); return; }

  const hits = cProdutosFT.filter(p =>
    ['VENDA','PPB','PPC','PPP','SA'].includes(p.tipo) &&
    norm(p.nome).includes(norm(val))
  ).slice(0, 8);

  if (!hits.length) { lista.classList.remove('aberta'); return; }

  lista.innerHTML = hits.map(p =>
    `<div class="ac-item" onmousedown="selecionarFichaProduto('${p.id}')">
      ${esc(p.nome)} <small class="text-muted ms-1">${p.tipo}</small>
    </div>`
  ).join('');
  lista.classList.add('aberta');
}

function selecionarFichaProduto(id) {
  const p = cProdutosFT.find(x => x.id === id);
  if (!p) return;
  document.getElementById('ft-produto-id').value   = id;
  document.getElementById('ft-produto-nome').value = p.nome;
  document.getElementById('ft-produto-info').textContent =
    `Tipo: ${p.tipo} | Preço venda: ${p.preco_venda > 0 ? brl(p.preco_venda) : '—'}`;
  fechaAC('ac-ft-produto');
}

// Autocomplete ingrediente
function acIngrediente(val) {
  const lista = document.getElementById('ac-ft-ing');
  if (!val) { lista.classList.remove('aberta'); return; }

  // Ingredients can be MP, SA, PPB, PPC, PPP (not VENDA, not MC)
  const hits = cProdutosFT.filter(p =>
    ['MP','SA','PPB','PPC','PPP'].includes(p.tipo) &&
    norm(p.nome).includes(norm(val))
  ).slice(0, 10);

  if (!hits.length) { lista.classList.remove('aberta'); return; }

  lista.innerHTML = hits.map(p =>
    `<div class="ac-item" onmousedown="selecionarIngrediente('${p.id}')">
      ${esc(p.nome)}
      <small class="text-muted ms-1">${p.tipo} | ${esc(p.unidade_uso||'UN')} | ${brl(p.custo_uso)}</small>
    </div>`
  ).join('');
  lista.classList.add('aberta');
}

function selecionarIngrediente(id) {
  const p = cProdutosFT.find(x => x.id === id);
  if (!p) return;
  const fator      = p.fator_conversao || 1;
  const perda      = p.perda || 0;
  const rendimento = 1 - (perda / 100);
  const efetivo    = rendimento > 0 ? (p.custo_comp || 0) / fator / rendimento : 0;
  const ucmp = p.unidade_comp || 'UN';
  const uuso = p.unidade_uso  || 'UN';

  document.getElementById('ft-ing-id').value   = id;
  document.getElementById('ft-ing-nome').value = p.nome;
  document.getElementById('ft-ing-un').value   = uuso;
  document.getElementById('ft-ing-info').textContent =
    `1 ${ucmp} = ${fator} ${uuso}` +
    (perda > 0 ? ` | Perda: ${perda}%` : '') +
    ` | Custo efetivo: ${brl(efetivo)}/${uuso}`;
  fechaAC('ac-ft-ing');
  document.getElementById('ft-ing-qtd').focus();
}

function addIngrediente() {
  const id  = document.getElementById('ft-ing-id').value;
  const qtd = parseFloat(document.getElementById('ft-ing-qtd').value);
  const un  = document.getElementById('ft-ing-un').value.trim();

  if (!id || !qtd || qtd <= 0) {
    toast('Selecione um ingrediente e informe a quantidade.', 'erro'); return;
  }

  const prod = cProdutosFT.find(x => x.id === id);
  if (!prod) return;

  const fator      = prod.fator_conversao || 1;
  const perda      = prod.perda || 0;
  const rendimento = 1 - (perda / 100);
  const custoBase  = prod.custo_comp || prod.custo_uso || 0;
  const custoEfetivo = rendimento > 0 ? (custoBase / fator) / rendimento : 0;

  ftIngredientes = ftIngredientes.filter(i => i.prod_id !== id);

  ftIngredientes.push({
    id:         null,
    prod_id:    id,
    nome:       prod.nome,
    tipo:       prod.tipo,
    quantidade: qtd,
    unidade:    un,
    custo_uso:  custoEfetivo,
  });

  document.getElementById('ft-ing-nome').value       = '';
  document.getElementById('ft-ing-id').value         = '';
  document.getElementById('ft-ing-qtd').value        = '1';
  document.getElementById('ft-ing-info').textContent = '';
  document.getElementById('ft-ing-nome').focus();

  renderIngredientes();
}

function removerIngrediente(idx) {
  ftIngredientes.splice(idx, 1);
  renderIngredientes();
}

function renderIngredientes() {
  const tbody = document.getElementById('tb-ing-body');
  const vazio = document.getElementById('tr-ing-vazio');

  if (!ftIngredientes.length) {
    tbody.innerHTML = '';
    tbody.appendChild(vazio);
    recalcularCustoFicha();
    return;
  }

  tbody.innerHTML = ftIngredientes.map((ing, idx) => {
    const subtotal = ing.quantidade * ing.custo_uso;
    return `<tr>
      <td class="fw-semibold">${esc(ing.nome)}</td>
      <td><span class="badge-tipo badge-${ing.tipo.toLowerCase()}">${ing.tipo}</span></td>
      <td>${Number(ing.quantidade).toLocaleString('pt-BR', {maximumFractionDigits:4})}</td>
      <td>${esc(ing.unidade)}</td>
      <td class="text-muted">${brl(ing.custo_uso)}</td>
      <td class="fw-semibold">${brl(subtotal)}</td>
      <td>
        <button class="btn-del" onclick="removerIngrediente(${idx})" title="Remover">
          <i class="bi bi-trash"></i>
        </button>
      </td>
    </tr>`;
  }).join('');

  recalcularCustoFicha();
}

function recalcularCustoFicha() {
  const custoTotal  = ftIngredientes.reduce((s, i) => s + (i.quantidade * i.custo_uso), 0);
  const rendimento  = parseFloat(document.getElementById('ft-rendimento')?.value) || 1;
  const custoPorcao = custoTotal / rendimento;
  const unRend      = document.getElementById('ft-unidade-rend')?.value || 'porção';

  document.getElementById('ft-custo-total').textContent = brl(custoTotal);
  document.getElementById('ft-custo-porcao').textContent =
    `${brl(custoPorcao)} / ${unRend}`;
}

async function salvarFicha() {
  const prodId  = document.getElementById('ft-produto-id').value;
  const fichaId = document.getElementById('ft-ficha-id').value;
  const rend    = parseFloat(document.getElementById('ft-rendimento').value) || 1;
  const unRend  = document.getElementById('ft-unidade-rend').value.trim() || 'porção';

  if (!prodId) { toast('Selecione o produto da ficha.', 'erro'); return; }
  if (!ftIngredientes.length) { toast('Adicione pelo menos 1 ingrediente.', 'erro'); return; }

  const custoTotal  = ftIngredientes.reduce((s, i) => s + (i.quantidade * i.custo_uso), 0);
  const custoPorcao = custoTotal / rend;

  let targetFichaId = fichaId;

  if (fichaId) {
    // Update ficha header
    await sb.from('est_fichas_tecnicas').update({
      rendimento: rend, unidade_rendimento: unRend,
      custo_total: custoTotal, custo_por_porcao: custoPorcao,
    }).eq('id', fichaId);

    // Delete existing ingredients and re-insert
    await sb.from('est_ficha_ingredientes').delete().eq('ficha_id', fichaId);
  } else {
    // Create new ficha
    const { data, error } = await sb.from('est_fichas_tecnicas').insert([{
      produto_id: prodId, rendimento: rend,
      unidade_rendimento: unRend, custo_total: custoTotal,
      custo_por_porcao: custoPorcao, ativo: true,
    }]).select().single();

    if (error) { toast('Erro ao salvar ficha: ' + error.message, 'erro'); return; }
    targetFichaId = data.id;
  }

  // Insert ingredients
  const ings = ftIngredientes.map(i => ({
    ficha_id:       targetFichaId,
    ingrediente_id: i.prod_id,
    quantidade:     i.quantidade,
    unidade:        i.unidade,
  }));

  const { error: errIng } = await sb.from('est_ficha_ingredientes').insert(ings);
  if (errIng) { toast('Erro ao salvar ingredientes: ' + errIng.message, 'erro'); return; }

  // Atualiza custo_comp do produto com o custo/porção calculado pela ficha
  await sb.from('est_produtos').update({ custo_comp: custoPorcao }).eq('id', prodId);
  const idxProd = cProdutosFT.findIndex(p => p.id === prodId);
  if (idxProd >= 0) cProdutosFT[idxProd].custo_comp = custoPorcao;

  toast('Ficha técnica salva!', 'ok');
  bootstrap.Modal.getInstance(document.getElementById('modal-ficha')).hide();
  ftFichasCache = [];

  // Se estava na tela do produto, mostra a ficha direto na aba
  if (_prodAtual && _prodAtual.id === prodId) {
    irAba('ficha', document.querySelectorAll('#tabs-prod .nav-link')[1]);
  } else {
    carregarFichas();
  }
}

async function excluirFicha(fichaId) {
  if (!confirm('Excluir esta ficha técnica?')) return;
  await sb.from('est_fichas_tecnicas').delete().eq('id', fichaId);
  toast('Ficha excluída.', 'ok');
  ftFichasCache = [];
  carregarFichas();
}

async function excluirFichaModal() {
  const fichaId = document.getElementById('ft-ficha-id').value;
  if (!fichaId) return;
  bootstrap.Modal.getInstance(document.getElementById('modal-ficha')).hide();
  await excluirFicha(fichaId);
}


// ═══════════════════════════════════════════════════════════════
// INVENTÁRIOS — Estrutura Setor → Grupo → Produtos
// ═══════════════════════════════════════════════════════════════
const INVENTARIO_ESTRUTURA = {
  "CHURRASQUEIRA": {
    "PEIXES": ["MP BANDA DE TAMBAQUI","MP TAMBAQUI CASACA","MP COSTELA DE TAMBAQUI","MP MATRINXA"],
    "ESTIVAS": ["MP AZEITE","MP CEBOLA","MP LIMÃO","MP MARGARINA","MP PIMENTA DE CHEIRO","MP SAL REFINADO","MC BOBINA IMPRESSORA","MC CAIXA DE PEIXE","MC CARVÃO"]
  },
  "COZINHA": {
    "CONGELADOS": ["MP AÇAI","SA BATATA 100G","SA MACAXEIRA 300G","SA DADINHO DE TAPIOCA 6 UNID","SA BOLINHO DE PIRARUCU 5 UN","SA BOLINHO DE TAMBAQUI 5 UN","SA PASTEL DE CAMARÃO CREMOSO 3 UNID","SA PASTEL DE QUEIJO 3 UNID","SA PASTEL TAMBAQUI 3 UNID","SA PASTEL MISTO 3 UNID","SA PASTEL DE PIRARUCU COM BANANA 3 UNID","SA CAMARÃO ALHO E OLEO 220G","SA CAMARÃO COM.CATUPIRY 4 UNID","SA CAMARÃO SECO M 40G","SA CAMARÃO FRESCO 5 UNID","SA CAMARÃO SECO G 50G","SA VERDURAS CONGELADAS 200G","SA COCO SECO 250G","MP COSTELA DE TAMBAQUI","SA KIT MOQUECA DE TAMBAQUI","SA FILÉ DE PIRARUCU 160G","SA FILE DE PIRARUCU 120G","SA KIT MOQUECA DE PIRARUCU","SA PIRARUCU DE CASACA","SA PIRARUCU FRESCO DESFIADO 150g","SA CROCANTE DE PIRARUCU 150G","SA KIT MOQUECA CABOCA","SA PIRARUCU KIDS 100G","MP MEDALHÃO DE ALCATRA","SA ISCA DE FILÉ MIGNON 100G","SA MEDALHÃO DE FILÉ MIGNON","SA KIT MEIA GALINHA CAIPIRA","SA ISCA DE FRANGO 100G","SA FRANGO PASSARINHO","SA MARMTA DE FRANGO ASSADO","SA FILE DE FRANGO 100G","SA JARAQUI 1 UNID","SA SARDINHA 2 UNID","SA PACU 1 UNID","SA PICADINHO DE TAMBAQUI 150G","SA KIT TACAQUI NHOQUE","SA KIT VATAPA","SA MACAXEIRA CRUA PURE","MP QUEIJO MUSARELA FATIADO","SA QUEIJO COALHO 50G","MP PETIT GATEAU C CALDA","MP SORVETE DE BAUNILHA","SA CABEÇA DE CAMARÃO SECO 200G","SA COMPOTA DE CUPUACU 1kg (COZINHA)"],
    "HORTIFRUTI": ["MP ALFACE BOLA","MP ALFAVACA","MP ALHO DESCASCADO","MP BATATA PORTUGUESA","MP CEBOLA","MP CENOURA","MP CHICORIA","MP COENTRO","MP FOLHA DE BANANA","MP JAMBU","MP JERIMUM","MP LIMÃO","MP MAXIXE","MP PIMENTA DE CHEIRO","MP PIMENTA MURUPI","MP SEMENTE DE URUCUM","MP TOMATE","MP OVO"],
    "ESTIVAS": ["MP ACUCAR","MP ARROZ","MP AZEITE DENDE","MP OLEO COMPOSTO","MP AZEITONA VERDE SEM CAROÇO","MP CANELA EM PÓ","MP SERESTEIRO 900ML","MP CREAM CHEESE","MP CREME DE LEITE FORNEÁVEL","MP EXTRATO DE TOMATE","MP FARINHA BRANCA","MP FARINHA PANKO","MP FARINHA DE TAPIOCA","MP FARINHA OVINHA","MP FEIJÃO PRAIA","MP GOMA","MP KETCHUP","MP LEITE EM PÓ INTEGRAL","MP LEITE LIQUIDO INTEGRAL","MP MACARRÃO ESPAGUETE","MP MARGARINA","MP MASSA DE PURÊ DE BATATA","MP OLEO DE SOJA","MP OLEO DE ALGODÃO","MP SAL GROSSO","MP SAL REFINADO","MP TRIGO S/FERMENTO","MP NOZ MOSCADA","MP PIMENTA DO REINO EM GRAOS","PPC TUCUPI REDUZIDO","PPC TUCUPI TEMPERADO","MP VINAGRE"],
    "COMIDA FUNCIONÁRIO": ["MC ISCA CARNE - FUNCIONÁRIO","MC CARNE PARA GUISADO","MC AGULHA - FUNCIONÁRIO","MC FILE DE PEITO FUNCIONÁRIO","MC COXA S/ COXA - FUNCIONÁRIO","MC CALABRESA","MP KIT DE TAMBAQUI","MC OVO - FUNCIONÁRIO","MC ARROZ - FUNCIONÁRIO","MC FEIJAO CARIOCA","MC FARINHA FUNCIONÁRIO","MP BATATA PORTUGUESA","MC MACARRAO - FUNCIONÁRIO","MP ACUCAR","MC CEBOLA FUNCIONÁRIO","MC COENTRO - FUNCIONÁRIO","MC PIMENTA DE CHEIRO ( FUNCIONARIO )","MC COUVE","MP FEIJÃO DE CORDA","MC TOMATE ( FUNCIONARIO )","MC - LIMÃO - FUNCIONARIO","MP POLPA MANGA 1KG","MP POLPA GOIABA 1KG"],
    "EMBALAGENS": ["MC SACO 1 KG","MC SACO 2 KG","MC SACO 10 KG","MC LUVA PLASTICA","MC PAPEL FILME ROLO","MP POTE 1000ML","MC POTE REDONDO C/ TAMPA 750ML","MC POTE RED 500ML","MC POTE RED 250ML","MC EMBALAGEM DE ALUMINIO RETANGULAR PEQUENA","MC BANDEJA DE ALUMINIO D6","MC BANDEJA DE ALUMINIO D7","MC BANDEJA DE ALUMINIO D5","MC POTE RETANGULAR 500 ML","MC EMBALAGEM G742","MU MOLHEIRA","MC TOUCA SANFONADA","MC FITA DUREX 50X50","MC LUVA VINIL TAM G","MC GARRAFA DE 1 LITRO","MC GARRAFA DE 500ML","MC GARRAFA DE 350ML"]
  },
  "BAR": {
    "MATERIAL DE EXPEDIENTE": ["MC SACO 1 KG","MC PAPEL ROLO COZINHA TORK HANDTOWEL","MC PERFEX WIPE","MC ALCOOL LIQUIDO 70","MC FITA DUREX 50X50","MC COPO DESCARTAVEL 180ML"],
    "SOBREMESAS": ["MP PUDIM DE LEITE","MP CEU DE BRIGADEIRO","MP TORTA CUPUACU COM CHOCOLATE","MP TORTA CUPUACU COM CASTANHA","MP TORTA DE ABACAXI","MP BROWNIE DE CHOCOLATE","MP CHEESECAKE CHOCOLATE COM CUPUACU","SA CASTANHA LASCA 50g (BAR)","SA COMPOTA DE CUPUACU 1kg (BAR)","SA BOLO DE MACAXEIRA 1 UNID","MP SORVETE DE TAPIOCA","MP SORVETE DE CREME","SA COCO LASCA 50g","MP PICOLE DE GRAVIOLA","MP PICOLE DE AÇAI","MC PENA AZUL","MC PENA VERMELHA","MP PAPEL ARROZ","MP CALDA BOTACOCO"],
    "HORTIFRUTI": ["MP ABACAXI","MP ALECRIM","MP AMEIXA EM CALDA","MP CEREJA CALDA","MP HORTELÃ","MP JAMBU","MP KIWI","MP LARANJA BAHIA","MP LARANJA BAHIA DESIDRATADA","MP LIMÃO SICILIANO DESIDRATADO","MP LARANJA","MP LIMÃO","MP LIMÃO SICILIANO","MP MAÇA VERDE","MP MARACUJA FRUTA","MP PITAYA","MP PHISSALYS","MP TUCUMA","MP MORANGO FRUTA","MP PIMENTA ROSA","MP TANGERINA"],
    "POLPAS": ["MP POLPA DE CUPUAÇU","MP POLPA ACEROLA","MP POLPA MARACUJÁ","MP POLPA GRAVIOLA","MP POLPA DE CAJU","MP POLPA GOIABA","MP POLPA TAPEREBÁ","MP POLPA MANGA","MP POLPA CUPUAÇU 1 KG","MP POLPA GRAVIOLA 1 KG","MP POLPA GOIABA 1 KG","MP POLPA TAPEREBÁ 1 KG","MP POLPA MANGA 1KG","SA ABACAXI EM CUBOS 150G"],
    "ESTIVAS": ["MP AÇUCAR","MP AÇUCAR MASCAVO","MP BISCOITO DO CAFE","MP CAPSULA EXPRESSO ATENTO","MP CAPSULA CAFE COM LEITE","MP CAPSULA EXPRESSO PLENO","MP CAPSULA EXPRESSO VIBRANTE","MP CAPSULA CAPUCCINO CLASSICO","MP CAPSULA CHOCOLATE COM CARAMELO","MP CAPSULA CHOCO CARAMEL","MP COCO RALADO ÚMIDO","MP CONDENSADO LATA","MP LEITE EM PÓ","MP LEITE LIQUIDO INTEGRAL","MP LEITE INTEGRAL C4","MP CAFÉ TORRADO MOIDO 1KG","MP GRANOLA","MP AMENDOIM CROCANTE","MP LEITE CONDENSADO PIRACANJUBA 385G","MP AMENDOIM SEM CASCA"],
    "ALCOOLICAS": ["MP BARRIL CHOPP BRAHMA 50 LITROS","MP BOHEMIA 600ML","MP BRAHMA DUPLO MALTE 600 ML","MP BUDWEISER LN","MP CORONA EXTRA","MP EISENBAHN PILSEN 355ML","MP FRANZISKANER WEISSBIER 500ML","MP HEINEKEN 330ML","MP HEINEKEN 600ML","MP ITAIPAVA 600ML","MP ORIGINAL 600ML","MP STELLA ARTOIS 600ML","MP BOHEMIA 355ML","MP BUDWEISER 600ML","MP EISENBAHN DUNKEL 500ML","MP EISENBAHN PALE ALE 355ML","MP BUDWEISER LATA","MP HEINEKEN LATA","MP SKOL BEATS SENSES LATA","MP STELLA LATA","MP CACHAÇA 51 960ML","MP CACHAÇA LEBLON 750ML","MP JACK DANIEL'S 1L","MP SMIRNOFF VODKA RED 1L","MP TEQUILA JOSE CUERVO ESPECIAL 750ML","MP JOHNNIE WALKER RED LABEL 1L","MP JOHNNIE WALKER BLACK LABEL 1L","MP VINHO TINTO SUAVE 750ML","MP VINHO BRANCO SUAVE 750ML","MP ESPIRITO DE MINAS CACHAÇA 970 ML","MP VINHO TINTO SECO 750ML","MP ESPIRITO DE MINAS TRADICIONAL 970ML","MP BALLANTINES 750ML","MP GRANT'S TRIPLE WOOD 750ML","MP MONTILLA VINHO TINTO SUAVE 750ML","MP VINHO BRANCO SECO 750ML","MP SPATEN 600ML","MP AMSTEL 600ML","MP BRAHMA 600ML","MP COLORADO APPIA 600ML","MP DEVASSA DOURADA 600ML","MP ANTARCTICA ORIGINAL 600ML","MP SPATEN 350ML","MP AMSTEL LATA"],
    "NÃO ALCOOLICAS": ["MP AGUA COM GÁS","MP AGUA SEM GÁS","MP PEPSI BLACK","MP TONICA ANTARTICA 355ML","MP SUKITA LATA","MP GUARANA ANTARTICA LATA","MP PEPSI LATA","MP PEPSI BLACK LATA","MP GATORADE MARACUJA","MP REDBULL","MP SUCO DELL VALE 1L","MP GUARANÁ ANTARCTICA 600ML","MP SCHWEPPES GUARANA 600ML","MP SUKITA UVA LATA"],
    "EMBALAGEMDESCAR": ["MC CANUDO SACHE BIO FLEX 6MM","MP CANUDO PRETO CAIPIRINHA","MC CANUDO SACHER COMUM BIODEGRADAVEL","MC COPO DESCARTAVEL 300ML","MC COPO LONG DRINK 300ML DESCARTAVEL","MC SAQUINHO HIGIENICO","MC SACHET COLHER BIOPLÁSTICO 16CM","MC GUARDANAPO DE PAPEL"],
    "SODA AMAZONENSE": ["PPB XAROPE DE ABACAXI","PPB XAROPE DE ACEROLA","PPB XAROPE DE CUPUAÇU","PPB XAROPE DE GARVIOLA","PPB XAROPE DE MARACUJÁ","PPB XAROPE DE TAPEREBÁ","PPB XAROPE DE GOIABA","PPB XAROPE DE MANGA","PPB XAROPE DE MORANGO"]
  },
  "SALAO": {
    "MATERIAL EXPEDIENTE": ["MC GUARDANAPO TORK","MP PALITO SACHÊ","MP PALITO DE PICOLÉ","MP SAL SACHE","MP AÇUCAR SACHE","MC ADOÇANTE SACHE","MC ALCOOL EM GEL","MC PERFEX WIPE","MP AZEITE EXTRA VIRGEM","MC ALCOOL LIQUIDO 70","MC SACOLA BRANCA 8KG"]
  },
  "ASG": {
    "MATERIAL DE LIMPEZA": ["MC SACO DE LIXO - 50LT","MC SACO DE LIXO - 200LT","MC DETERGENTE NEUTRO 5 L","MC PROTETOR DE ASSENTO SANITARIO","MC DESINFETANTE CONCENTRADO","MC AGUA SANITARIA","MC ESPONJA COMUM","MC SABONETE CLIENTE","MC SABONETE BACTERICIDA","MC LUVA DE LIMPEZA","MC PAPEL HIGIENICO TORK SMART ONE","MC PAPEL HIGIENICO FUNCIONARIO","MC PAPEL TOALHA CLIENTE TORK","MC PAPEL ROLO COZINHA TORK HANDTOWEL","MC PAPEL TOLHA ROLO TORK ADV 4/250M FS","MC ALCOOL EM GEL","MC FIBRA PESADA","MC X-12","MC PEROXY 3000","MC LIMPA ALUMINIO","MC LIMPA VIDRO 5LT","MC CLEARON","MC PANO DE CHÃO","MC PERFEX WIPE","MC MOP"]
  },
  "DELIVERY": {
    "BEBIDAS": ["MP AGUA COM GÁS","MP AGUA SEM GÁS","MP PEPSI BLACK LATA","MP GUARANA ANTARTICA LATA","MP PEPSI LATA","MP GATORADE MARACUJA","MP REDBULL","MP SUCO DELL VALE 1L","MP GUARANÁ ANTARCTICA 600ML","MP SCHWEPPES GUARANA 600ML","MP SUKITA UVA LATA","MP SUKITA LATA","MP BRAHMA 600ML","MP HEINEKEN 330ML","MP HEINEKEN 600ML","MP STELLA ARTOIS 600ML","MP BUDWEISER LN","MP CORONA EXTRA","MP BOHEMIA 600ML","MP BOHEMIA 355ML","MP SPATEN 600ML","MP AMSTEL 600ML","MP AMSTEL LATA"],
    "DESCARTAVEL": ["MC GARFO REFEIÇÃO","MC COLHER REFEIÇÃO DESCARTAVEIS","MC FACA REFEIÇÃO","MC PRATO DESCARTAVEL","MC SACOLA BRANCA 8KG","MC FITA DUREX 50X50","MC COPO DESCARTAVEL 300ML","MC GUARDANAPO DE PAPEL"]
  }
};

function _gerarEstoqueLojaEstrutura() {
  const _n = s => String(s||'').normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase();
  const forceMerge = { 'material expediente': 'MATERIAL DE EXPEDIENTE' };
  const result = {}, seen = {}, normToCanonical = {};
  Object.entries(INVENTARIO_ESTRUTURA).forEach(([setor, grupos]) => {
    if (setor === 'ESTOQUE DA LOJA') return;
    Object.entries(grupos).forEach(([grupo, prods]) => {
      const ng = _n(grupo);
      const canonical = forceMerge[ng] || normToCanonical[ng] || grupo;
      if (!normToCanonical[ng]) normToCanonical[ng] = canonical;
      if (!result[canonical]) { result[canonical] = []; seen[canonical] = new Set(); }
      prods.forEach(p => { const np = _n(p); if (!seen[canonical].has(np)) { result[canonical].push(p); seen[canonical].add(np); } });
    });
  });
  INVENTARIO_ESTRUTURA['ESTOQUE DA LOJA'] = result;
}
_gerarEstoqueLojaEstrutura(); // initial call (replaces IIFE)

const _UNIDADES_LOCAIS = ['Centro', 'Delivery P10', 'Produção', 'Estoque Central'];
let _todasEstruturas = {};

function _aplicarEstruturaLocal(local) {
  const base = _todasEstruturas[local] || _todasEstruturas['Centro'] || {};
  Object.keys(INVENTARIO_ESTRUTURA).forEach(k => { if (k !== 'ESTOQUE DA LOJA') delete INVENTARIO_ESTRUTURA[k]; });
  Object.assign(INVENTARIO_ESTRUTURA, base);
  _gerarEstoqueLojaEstrutura();
}

let _invLocal        = 'Centro';
let _invSetor        = null;
let _invGrupo        = null;
let _invProds        = [];   // { nome, produto_id } array do grupo atual
let _invDia          = '';   // 'seg'|'ter'|'qua'|'qui'|'sex'|'sab'|'dom'
let _invFeriado      = false;
let _invMapeamentos  = {};   // carregado do Supabase (compartilhado entre dispositivos)
let _invExcluidos    = new Set();
let _invAdicoes      = {};   // { "SETOR|GRUPO": ["nome1","nome2"] }
let _invPadroes      = {};   // { "SETOR|GRUPO|PRODUTO": { "seg": 5, "ter": 3, ... } }
let _transfItens     = [];   // { produto_id, nome, unidade, qtd }

const _DIAS_LABEL = { seg:'Segunda', ter:'Terça', qua:'Quarta', qui:'Quinta', sex:'Sexta', sab:'Sábado', dom:'Domingo', feriado:'Feriado' };
const _DIAS_SEM   = ['dom','seg','ter','qua','qui','sex','sab'];

function _chavePadrao() {
  return _invFeriado ? 'feriado' : _invDia;
}

function initInvDia() {
  _invDia     = _DIAS_SEM[new Date().getDay()];
  _invFeriado = false;
  atualizarBtnsDia();
}

function setInvDia(dia) {
  _invDia = dia;
  _invFeriado = false;
  atualizarBtnsDia();
  if (_invGrupo) renderInventario();
}

function toggleFeriado() {
  _invFeriado = !_invFeriado;
  atualizarBtnsDia();
  if (_invGrupo) renderInventario();
}

function atualizarBtnsDia() {
  document.querySelectorAll('.inv-dia-btn').forEach(b => {
    b.className = 'saldo-grupo-btn inv-dia-btn' + (b.dataset.dia === _invDia && !_invFeriado ? ' ativo' : '');
  });
  const btnFer = document.getElementById('btn-inv-feriado');
  if (btnFer) btnFer.className = 'saldo-grupo-btn inv-feriado-btn' + (_invFeriado ? ' ativo' : '');
}

function mudarLocalInv(local) {
  _invLocal = local;
  _aplicarEstruturaLocal(local);
  _invSetor = null; _invGrupo = null; _invProds = [];
  document.getElementById('inv-grupo-section')?.classList.add('d-none');
  document.getElementById('inv-tabela-section')?.classList.add('d-none');
  const e2 = document.getElementById('inv-local-badge2');
  if (e2) e2.textContent = local;
  document.querySelectorAll('.inv-local-btn').forEach(b => {
    b.className = 'saldo-grupo-btn inv-local-btn' + (b.dataset.local === local ? ' ativo' : '');
  });
}

async function carregarMapeamentosInv() {
  const { data } = await sb.from('inv_configuracoes')
    .select('chave,valor').in('chave', ['mapeamentos','excluidos','adicoes','padroes','estrutura']);
  let mapeamentos = {}, excluidos = new Set();
  if (data) {
    data.forEach(row => {
      if (row.chave === 'mapeamentos') mapeamentos  = row.valor || {};
      if (row.chave === 'excluidos')   excluidos    = new Set(row.valor || []);
      if (row.chave === 'adicoes')     _invAdicoes  = row.valor || {};
      if (row.chave === 'padroes')     _invPadroes  = row.valor || {};
      if (row.chave === 'estrutura')   _todasEstruturas = row.valor || {};
    });
  }

  // Migração única: mapeamentos/excluidos do localStorage → Supabase
  if (Object.keys(mapeamentos).length === 0 && excluidos.size === 0) {
    const lsMap  = JSON.parse(localStorage.getItem('inv_mapeamentos') || '{}');
    const lsExcl = JSON.parse(localStorage.getItem('inv_excluidos')   || '[]');
    if (Object.keys(lsMap).length > 0 || lsExcl.length > 0) {
      await sb.from('inv_configuracoes').upsert([
        { chave: 'mapeamentos', valor: lsMap  },
        { chave: 'excluidos',   valor: lsExcl },
      ]);
      mapeamentos = lsMap;
      excluidos   = new Set(lsExcl);
      localStorage.removeItem('inv_mapeamentos');
      localStorage.removeItem('inv_excluidos');
      toast('Configurações de divergências migradas para a nuvem ✅', 'ok');
    }
  }

  // Migração única: inv_padroes do localStorage → Supabase
  if (Object.keys(_invPadroes).length === 0) {
    const lsPad = JSON.parse(localStorage.getItem('inv_padroes') || '{}');
    if (Object.keys(lsPad).length > 0) {
      await sb.from('inv_configuracoes').upsert({ chave: 'padroes', valor: lsPad });
      _invPadroes = lsPad;
      localStorage.removeItem('inv_padroes');
      toast('Pedidos Padrão migrados para a nuvem ✅', 'ok');
    }
  }

  // Migração única: padrões no formato antigo (PRODUTO) → novo (SETOR|GRUPO|PRODUTO)
  const keysAntigas = Object.keys(_invPadroes).filter(k => !k.includes('|'));
  if (keysAntigas.length > 0) {
    const novos = {};
    Object.keys(_invPadroes).filter(k => k.includes('|')).forEach(k => { novos[k] = _invPadroes[k]; });
    keysAntigas.forEach(prodNome => {
      const val = _invPadroes[prodNome];
      Object.entries(INVENTARIO_ESTRUTURA).forEach(([setor, grupos]) => {
        if (setor === 'ESTOQUE DA LOJA') return;
        Object.entries(grupos).forEach(([grupo, prods]) => {
          if (prods.some(p => p.trim().toUpperCase() === prodNome)) {
            novos[`${setor}|${grupo}|${prodNome}`] = val;
          }
        });
      });
    });
    _invPadroes = novos;
    await sb.from('inv_configuracoes').upsert({ chave: 'padroes', valor: _invPadroes });
    toast('Pedidos Padrão recuperados ✅', 'ok');
  }

  // Seed estrutura por unidade se vazio
  const _centroBase = {};
  Object.entries(INVENTARIO_ESTRUTURA).forEach(([k,v]) => { if (k !== 'ESTOQUE DA LOJA') _centroBase[k] = v; });
  let _estruturaMudou = false;
  if (!_todasEstruturas['Centro']) {
    _todasEstruturas['Centro'] = JSON.parse(JSON.stringify(_centroBase));
    _estruturaMudou = true;
  }
  _UNIDADES_LOCAIS.forEach(u => {
    if (!_todasEstruturas[u]) {
      _todasEstruturas[u] = JSON.parse(JSON.stringify(_todasEstruturas['Centro']));
      _estruturaMudou = true;
    }
  });
  if (_estruturaMudou) await sb.from('inv_configuracoes').upsert({ chave: 'estrutura', valor: _todasEstruturas });
  if (_invLocal && _invLocal !== 'Centro') _aplicarEstruturaLocal(_invLocal);

  _invMapeamentos = mapeamentos;
  _invExcluidos   = excluidos;
}

async function carregarInventario() {
  if (!cProdutosFT.length) await carregarProdutosFT();
  if (!_invDia) initInvDia();
  await carregarMapeamentosInv();
  carregarHistoricoInv();
}

async function selecionarSetorInv(setor) {
  _invSetor = setor;
  _invGrupo = null;
  _invProds = [];

  // Destaca botão de setor
  const isEL = setor === 'ESTOQUE DA LOJA';
  document.querySelectorAll('.inv-setor-btn').forEach(b => {
    b.className = 'saldo-grupo-btn inv-setor-btn' + (b.dataset.setor === setor ? ' ativo' : '')
      + (b.dataset.setor === 'ESTOQUE DA LOJA' ? ' inv-setor-el' : '');
  });
  document.getElementById('inv-btn-enviar')?.classList.toggle('d-none', isEL);
  document.getElementById('inv-btn-padroes')?.classList.toggle('d-none', isEL);
  document.getElementById('inv-btn-saldo-inicial')?.classList.toggle('d-none', isEL);
  document.getElementById('inv-btn-salvar-saldo')?.classList.toggle('d-none', !isEL);
  document.getElementById('inv-grupo-actions')?.style.setProperty('display', isEL ? 'none' : 'flex', 'important');

  // Monta botões de grupo
  const grupos = Object.keys(INVENTARIO_ESTRUTURA[setor] || {});
  const grupoSection = document.getElementById('inv-grupo-section');
  const grupoTitulo  = document.getElementById('inv-grupo-titulo');
  const grupoBtns    = document.getElementById('inv-grupo-btns');

  grupoTitulo.textContent = `GRUPOS — ${setor}`;
  grupoBtns.innerHTML = grupos.map(g =>
    `<button class="saldo-grupo-btn inv-grupo-btn" data-grupo="${esc(g)}"
      onclick="selecionarGrupoInv('${esc(g)}')">${esc(g)}</button>`
  ).join('');

  grupoSection.classList.remove('d-none');
  document.getElementById('inv-tabela-section').classList.add('d-none');
  document.getElementById('lst-inventario').innerHTML =
    '<tr><td colspan="4" class="text-center text-muted py-4">Selecione um grupo acima.</td></tr>';
}

async function selecionarGrupoInv(grupo) {
  const _hoje = new Date().toISOString().split('T')[0];
  const { data: pedAberto } = await sb.from('pedidos_internos')
    .select('num_pedido,status').eq('setor', _invSetor).eq('obs', grupo)
    .eq('data', _hoje).eq('status', 'pendente').limit(1);
  if (pedAberto?.length) {
    toast(`${_invSetor} / ${grupo} — ${pedAberto[0].num_pedido} ainda aguardando liberação.`, 'erro');
    return;
  }

  _invGrupo = grupo;

  // Destaca botão de grupo
  document.querySelectorAll('.inv-grupo-btn').forEach(b => {
    b.className = 'saldo-grupo-btn inv-grupo-btn' + (b.dataset.grupo === grupo ? ' ativo' : '');
  });

  // Monta lista de produtos (respeita mapeamentos e exclusões)
  const mapeamentos = _invMapeamentos;
  const excluidos   = _invExcluidos;
  const nomes = INVENTARIO_ESTRUTURA[_invSetor]?.[grupo] || [];
  _invProds = nomes
    .filter(nome => !excluidos.has(nome))
    .map(nome => {
      const nomeBusca = mapeamentos[nome] || nome;
      const nomNorm   = norm(nomeBusca.trim());
      const prod      = cProdutosFT.find(p => norm(p.nome.trim()) === nomNorm);
      return { nome, produto_id: prod?.id || null, unidade: prod?.unidade_comp || '', adicionado: false };
    });

  // Produtos adicionados manualmente via "+"
  const nomesExistentes = new Set(_invProds.map(p => norm(p.nome)));
  const _addDe = (chave) => {
    (_invAdicoes[chave] || []).forEach(nome => {
      if (nomesExistentes.has(norm(nome))) return;
      const prod = cProdutosFT.find(p => norm(p.nome.trim()) === norm(nome.trim()));
      _invProds.push({ nome, produto_id: prod?.id || null, unidade: prod?.unidade_comp || '', adicionado: true });
      nomesExistentes.add(norm(nome));
    });
  };
  if (_invSetor === 'ESTOQUE DA LOJA') {
    // Agrega adições de todos os setores reais que têm este grupo
    Object.keys(INVENTARIO_ESTRUTURA).forEach(s => {
      if (s === 'ESTOQUE DA LOJA') return;
      if (INVENTARIO_ESTRUTURA[s]?.[grupo]) _addDe(`${s}|${grupo}`);
    });
  } else {
    _addDe(`${_invSetor}|${grupo}`);
  }

  // Breadcrumb
  document.getElementById('inv-breadcrumb').textContent = `${_invSetor} / ${grupo}`;
  const e2 = document.getElementById('inv-local-badge2');
  if (e2) e2.textContent = _invLocal;

  document.getElementById('inv-tabela-section').classList.remove('d-none');

  const isEL = _invSetor === 'ESTOQUE DA LOJA';
  document.getElementById('inv-btn-padroes')?.classList.toggle('d-none', isEL);
  document.getElementById('inv-th-padrao')?.classList.toggle('d-none', isEL);
  document.getElementById('inv-th-pedido')?.classList.toggle('d-none', isEL);

  renderInventario();
}

function renderInventario() {
  const tbody = document.getElementById('lst-inventario');
  const isEL  = _invSetor === 'ESTOQUE DA LOJA';
  if (!_invProds.length) {
    tbody.innerHTML = `<tr><td colspan="${isEL ? 3 : 5}" class="text-center text-muted py-4">Nenhum produto neste grupo.</td></tr>`;
    return;
  }
  tbody.innerHTML = _invProds.map((p, i) => {
    const padrao = _getPadrao(p.nome);
    const padraoTxt = padrao !== null ? padrao : '—';
    const semProd = !p.produto_id ? ' title="Produto não encontrado no cadastro" style="color:#dc3545"' : '';
    const btnRemover = p.adicionado
      ? ` <button class="btn btn-link btn-sm p-0 ms-1 text-danger" title="Remover produto adicionado"
            onclick="removerProdInv(${esc(JSON.stringify(p.nome))})" style="font-size:.75rem;vertical-align:middle">
            <i class="bi bi-trash3"></i></button>`
      : ` <button class="btn btn-link btn-sm p-0 ms-1 text-secondary" title="Excluir da contagem"
            onclick="excluirProdInv(${esc(JSON.stringify(p.nome))})" style="font-size:.75rem;vertical-align:middle;opacity:.4" onmouseover="this.style.opacity=1" onmouseout="this.style.opacity=.4">
            <i class="bi bi-trash3"></i></button>`;
    return `<tr>
      <td><strong${semProd}>${esc(p.nome)}</strong>${!p.produto_id ? ' <i class="bi bi-exclamation-circle text-danger small" title="Não cadastrado"></i>' : ''}${btnRemover}</td>
      <td class="text-center text-muted small">${esc(p.unidade || '—')}</td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center"
          id="inv-est-${i}" min="0" step="1" value="0"
          style="width:90px;margin:auto" oninput="calcPedidoInv(${i})">
      </td>
      ${isEL ? '' : `<td class="text-center">
        <span class="badge bg-secondary" id="inv-pad-${i}">${padraoTxt}</span>
      </td>
      <td class="text-center fw-bold" id="inv-ped-${i}" style="color:#06D6A0;font-size:1.05rem">
        ${padrao !== null ? _fmtPed(Math.max(0, padrao)) : '—'}
      </td>`}
    </tr>`;
  }).join('');
}

// ─── ADICIONAR / REMOVER PRODUTO NO GRUPO ────────────────────────
function abrirAdicionarProdInv() {
  const painel = document.getElementById('inv-add-search');
  painel.style.display = 'block';
  const input = document.getElementById('inv-add-input');
  input.value = '';
  document.getElementById('inv-add-sugestoes').innerHTML = '';
  input.focus();
}
function fecharAdicionarProdInv() {
  document.getElementById('inv-add-search').style.display = 'none';
}
function filtrarProdAdd(query) {
  const q = norm(query.trim());
  const el = document.getElementById('inv-add-sugestoes');
  if (q.length < 2) { el.innerHTML = ''; return; }
  const jaExiste = new Set(_invProds.map(p => norm(p.nome)));
  const matches  = cProdutosFT.filter(p => norm(p.nome).includes(q) && !jaExiste.has(norm(p.nome))).slice(0, 12);
  el.innerHTML = matches.length
    ? matches.map(p => `<button class="list-group-item list-group-item-action py-1 small"
        onclick="confirmarAdicionarProdInv(${esc(JSON.stringify(p.nome))})">${esc(p.nome)}</button>`).join('')
    : '<div class="list-group-item text-muted small">Nenhum produto encontrado.</div>';
}
async function confirmarAdicionarProdInv(nome) {
  const key   = `${_invSetor}|${_invGrupo}`;
  const atual = _invAdicoes[key] || [];
  if (atual.find(n => norm(n) === norm(nome))) { toast('Produto já está no grupo.', 'erro'); return; }
  _invAdicoes[key] = [...atual, nome];
  await sb.from('inv_configuracoes').upsert({ chave: 'adicoes', valor: _invAdicoes });
  fecharAdicionarProdInv();
  selecionarGrupoInv(_invGrupo);
  toast(`${nome} adicionado ao grupo ✅`, 'ok');
}
async function removerProdInv(nome) {
  if (!confirm(`Remover "${nome}" deste grupo?`)) return;
  const key = `${_invSetor}|${_invGrupo}`;
  const atual = _invAdicoes[key] || [];
  _invAdicoes[key] = atual.filter(n => norm(n) !== norm(nome));
  if (!_invAdicoes[key].length) delete _invAdicoes[key];
  await sb.from('inv_configuracoes').upsert({ chave: 'adicoes', valor: _invAdicoes });
  selecionarGrupoInv(_invGrupo);
  toast(`${nome} removido do grupo.`, 'ok');
}

async function excluirProdInv(nome) {
  if (!confirm(`Excluir "${nome}" da contagem?\n\nO produto não aparecerá mais nas listas. Para desfazer, use o painel de divergências.`)) return;
  _invExcluidos.add(nome);
  await sb.from('inv_configuracoes').upsert({ chave: 'excluidos', valor: [..._invExcluidos] });
  _invProds = _invProds.filter(p => p.nome !== nome);
  renderInventario();
  toast(`"${nome}" excluído da contagem.`, 'ok');
}

function parseQtd(v) { return parseFloat(String(v ?? '').replace(',', '.')) || 0; }

function _fmtPed(v) {
  if (v % 1 === 0) return String(v);
  return v.toLocaleString('pt-BR', { minimumFractionDigits: 3, maximumFractionDigits: 3 });
}

function calcPedidoInv(i) {
  const est    = parseQtd(document.getElementById(`inv-est-${i}`)?.value);
  const nome   = _invProds[i]?.nome || '';
  const padrao = _getPadrao(nome);
  const pedEl  = document.getElementById(`inv-ped-${i}`);
  if (!pedEl) return;
  if (padrao === null) { pedEl.textContent = '—'; return; }
  const ped = Math.max(0, padrao - est);
  pedEl.textContent = _fmtPed(ped);
}

function _padKey(nome) {
  return `${_invSetor}|${_invGrupo}|${nome.trim().toUpperCase()}`;
}

function _getPadrao(nome) {
  const entry = _invPadroes[_padKey(nome)];
  if (entry === undefined || entry === null) return null;
  if (typeof entry === 'number') return entry;
  const val = entry[_chavePadrao()];
  return val !== undefined ? Number(val) : null;
}

function _setPadrao(nome, chave, val) {
  const key = _padKey(nome);
  if (!_invPadroes[key] || typeof _invPadroes[key] !== 'object') _invPadroes[key] = {};
  _invPadroes[key][chave] = val;
}

function abrirEditarPadroes() {
  if (!_invProds.length) { toast('Selecione um grupo primeiro.', 'erro'); return; }
  const padroes = _invPadroes;
  const todasDias = ['seg','ter','qua','qui','sex','sab','dom','feriado'];

  const navTabs = todasDias.map((d, i) =>
    `<li class="nav-item">
      <button class="nav-link py-1 px-2 ${i === 0 ? 'active' : ''}" data-bs-toggle="tab" data-bs-target="#pad-tab-${d}" style="font-size:.8rem">
        ${d === 'feriado' ? '🎉 ' : ''}${_DIAS_LABEL[d]}
      </button>
    </li>`
  ).join('');

  const _gruposDias = {
    'Dias Úteis (Seg-Sex)': ['seg','ter','qua','qui','sex'],
    'Fim de Semana (Sab-Dom)': ['sab','dom'],
    'Feriado': ['feriado'],
    'Todos': ['seg','ter','qua','qui','sex','sab','dom','feriado'],
  };

  const tabPanes = todasDias.map((d, i) => {
    const rows = _invProds.map((p, pi) => {
      const obj = padroes[_padKey(p.nome)];
      const val = (obj && typeof obj === 'object') ? (obj[d] ?? '') : (typeof obj === 'number' ? obj : '');
      return `<tr>
        <td class="small">${esc(p.nome)}</td>
        <td class="text-center">
          <input type="number" class="form-control form-control-sm text-center"
            id="pad-${d}-${pi}" min="0" step="1" value="${val}" placeholder="—" style="width:100px;margin:auto">
        </td>
      </tr>`;
    }).join('');

    const copyBtns = Object.entries(_gruposDias).map(([label, destinos]) =>
      `<button class="btn btn-sm btn-outline-secondary" onclick="_copiarPadraoDia('${d}',[${destinos.map(x=>`'${x}'`).join(',')}])">${label}</button>`
    ).join('');

    return `<div class="tab-pane fade ${i === 0 ? 'show active' : ''}" id="pad-tab-${d}">
      <div class="d-flex flex-wrap gap-2 align-items-center px-2 py-2 border-bottom bg-light">
        <small class="text-muted fw-semibold">📋 Replicar para:</small>
        ${copyBtns}
      </div>
      <div style="max-height:48vh;overflow-y:auto">
        <table class="table table-sm align-middle mb-0">
          <thead style="background:#f8f9fa;position:sticky;top:0">
            <tr><th>Produto</th><th class="text-center">Qtd. Padrão</th></tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
    </div>`;
  }).join('');

  document.getElementById('lista-padroes').innerHTML =
    `<ul class="nav nav-tabs mb-0 flex-wrap">${navTabs}</ul>
     <div class="tab-content">${tabPanes}</div>`;

  new bootstrap.Modal(document.getElementById('modal-padroes')).show();
}

async function salvarPadroes() {
  const todasDias = ['seg','ter','qua','qui','sex','sab','dom','feriado'];

  _invProds.forEach((p, pi) => {
    const key = _padKey(p.nome);
    if (!_invPadroes[key] || typeof _invPadroes[key] !== 'object') _invPadroes[key] = {};
    todasDias.forEach(d => {
      const input = document.getElementById(`pad-${d}-${pi}`);
      if (!input) return;
      const val = input.value.trim();
      if (val === '') delete _invPadroes[key][d];
      else _invPadroes[key][d] = parseQtd(val);
    });
    if (Object.keys(_invPadroes[key]).length === 0) delete _invPadroes[key];
  });

  await sb.from('inv_configuracoes').upsert({ chave: 'padroes', valor: _invPadroes });
  toast('Padrões salvos!', 'ok');
  bootstrap.Modal.getInstance(document.getElementById('modal-padroes'))?.hide();
  renderInventario();
}

function _copiarPadraoDia(origem, destinos) {
  const alvos = destinos.filter(d => d !== origem);
  if (!alvos.length) return;
  _invProds.forEach((_, pi) => {
    const src = document.getElementById(`pad-${origem}-${pi}`);
    if (!src) return;
    alvos.forEach(d => {
      const dst = document.getElementById(`pad-${d}-${pi}`);
      if (dst) dst.value = src.value;
    });
  });
  const labels = alvos.map(d => _DIAS_LABEL[d]).join(', ');
  toast(`Valores de ${_DIAS_LABEL[origem]} copiados para: ${labels}`, 'ok');
}

async function salvarInventario() {
  if (!_invSetor || !_invGrupo) { toast('Selecione setor e grupo antes de salvar.', 'erro'); return; }
  const data = document.getElementById('inv-data').value;
  if (!data) { toast('Selecione a data da contagem.', 'erro'); return; }
  if (!_invProds.length) { toast('Nenhum produto no grupo.', 'erro'); return; }

  const resp = (document.getElementById('inv-resp').value || '').trim();

  const itens = _invProds.map((p, i) => {
    const estoque      = parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0;
    const pedido_padrao = _getPadrao(p.nome) ?? 0;
    const pedido       = Math.max(0, pedido_padrao - estoque);
    return {
      produto_id: p.produto_id || null,
      nome: p.nome,
      estoque,
      pedido_padrao,
      pedido,
      cozinha_bar: 0,
      outros: 0,
      total: estoque,
      unidade: 'UN',
      valor_unitario: 0,
      soma_total: 0,
    };
  });

  const totalPedido = itens.reduce((s, it) => s + it.pedido, 0);

  const { data: ultInvs } = await sb.from('est_inventarios').select('num_inv').order('criado_em', { ascending: false }).limit(1);
  const ultimoNum = ultInvs?.[0]?.num_inv ? parseInt(ultInvs[0].num_inv.replace(/\D/g, '')) || 0 : 0;
  const num_inv = 'INV-' + String(ultimoNum + 1).padStart(4, '0');

  const { data: inv, error } = await sb.from('est_inventarios').insert([{
    num_inv, data, local: _invLocal, responsavel: resp,
    setor: _invSetor, grupo: _invGrupo, total_geral: totalPedido
  }]).select().single();

  if (error) { toast('Erro ao salvar: ' + error.message, 'erro'); return; }

  const itensComId = itens.map(it => ({ ...it, inventario_id: inv.id }));
  await sb.from('est_inventario_itens').insert(itensComId);

  toast(`${num_inv} salvo! Total pedido: ${totalPedido}`, 'ok');
  carregarHistoricoInv();

  // Limpa os campos de estoque
  _invProds.forEach((_, i) => {
    const el = document.getElementById(`inv-est-${i}`);
    if (el) el.value = '0';
    calcPedidoInv(i);
  });
}

function _preencherModalDivergencias() {
  const mapeamentos = _invMapeamentos;
  const excluidos   = _invExcluidos;
  const divergencias = [];
  const todosProd = [...cProdutosFT].sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'));

  Object.entries(INVENTARIO_ESTRUTURA).forEach(([setor, grupos]) => {
    Object.entries(grupos).forEach(([grupo, nomes]) => {
      nomes.forEach(nome => {
        if (excluidos.has(nome)) return;
        const nomeBusca = mapeamentos[nome] || nome;
        const nomNorm   = norm(nomeBusca.trim());
        const match     = cProdutosFT.find(p => norm(p.nome.trim()) === nomNorm);
        if (!match) {
          const palavras = norm(nome).split(/\s+/).filter(w => w.length > 2);
          const sugestoes = todosProd
            .map(p => ({ nome: p.nome, hits: palavras.filter(w => norm(p.nome).includes(w)).length }))
            .filter(s => s.hits > 0)
            .sort((a, b) => b.hits - a.hits)
            .slice(0, 5)
            .map(s => s.nome);
          divergencias.push({ setor, grupo, nome, sugestoes, mapeadoAtual: mapeamentos[nome] || '' });
        }
      });
    });
  });

  const resumoEl = document.getElementById('div-divergencias-resumo');
  const tbody    = document.getElementById('tb-divergencias-inv');

  if (!divergencias.length) {
    resumoEl.innerHTML = '<div class="alert alert-success py-2 mb-2">✅ Nenhuma divergência encontrada — todos os produtos têm correspondência!</div>';
    tbody.innerHTML = '';
  } else {
    resumoEl.innerHTML = `<div class="alert alert-warning py-2 mb-0">
      <strong>${divergencias.length}</strong> produto(s) sem correspondência em
      <strong>${[...new Set(divergencias.map(d => d.setor))].length}</strong> setor(es).
      Selecione o produto correto em cada linha e clique <strong>Salvar Correções</strong>.
    </div>`;

    tbody.innerHTML = divergencias.map((d, i) => {
      const sugestaoSet = new Set(d.sugestoes);
      const optsTop = d.sugestoes.map(s =>
        `<option value="${esc(s)}" ${d.mapeadoAtual === s ? 'selected' : ''}>★ ${esc(s)}</option>`
      ).join('');
      const optsRest = todosProd
        .filter(p => !sugestaoSet.has(p.nome))
        .map(p => `<option value="${esc(p.nome)}" ${d.mapeadoAtual === p.nome ? 'selected' : ''}>${esc(p.nome)}</option>`)
        .join('');
      const separador = optsTop ? '<option disabled>──────────────</option>' : '';

      const avisoStale = d.mapeadoAtual
        ? `<div class="text-warning small mt-1">⚠️ Salvo anteriormente como: <em>${esc(d.mapeadoAtual)}</em> (produto não encontrado no cadastro)</div>`
        : '';

      return `<tr>
        <td class="ps-3 fw-semibold" style="color:#FF6B35;white-space:nowrap">${esc(d.setor)}</td>
        <td class="text-muted small" style="white-space:nowrap">${esc(d.grupo)}</td>
        <td>
          <code style="color:#dc3545;font-size:.8rem">${esc(d.nome)}</code>
          ${avisoStale}
        </td>
        <td>
          <select class="form-select form-select-sm" id="div-sel-${i}" data-nome="${esc(d.nome)}">
            <option value="">-- manter sem match --</option>
            <option value="__excluir__" style="color:#dc3545;font-weight:600">🗑️ Excluir desta estrutura</option>
            <option disabled>──────────────</option>
            ${optsTop}${separador}${optsRest}
          </select>
        </td>
      </tr>`;
    }).join('');
  }
}

function verDivergenciasInv() {
  if (!cProdutosFT.length) { toast('Aguarde o carregamento dos produtos.', 'erro'); return; }
  _preencherModalDivergencias();
  new bootstrap.Modal(document.getElementById('modal-divergencias-inv')).show();
}

async function salvarCorrecoesDivergencias() {
  const mapeamentos = { ..._invMapeamentos };
  const excluidos   = new Set(_invExcluidos);
  let countMap = 0, countExcl = 0;

  document.querySelectorAll('[id^="div-sel-"]').forEach(sel => {
    const nomeOriginal = sel.dataset.nome;
    const valor        = sel.value;
    if (valor === '__excluir__') {
      excluidos.add(nomeOriginal);
      delete mapeamentos[nomeOriginal];
      countExcl++;
    } else if (valor) {
      mapeamentos[nomeOriginal] = valor;
      excluidos.delete(nomeOriginal);
      countMap++;
    } else {
      delete mapeamentos[nomeOriginal];
    }
  });

  // Grava no Supabase (compartilhado entre dispositivos)
  await sb.from('inv_configuracoes').upsert([
    { chave: 'mapeamentos', valor: mapeamentos },
    { chave: 'excluidos',   valor: [...excluidos] },
  ]);

  // Atualiza cache em memória
  _invMapeamentos = mapeamentos;
  _invExcluidos   = excluidos;

  const msgs = [];
  if (countMap)  msgs.push(`${countMap} mapeamento(s)`);
  if (countExcl) msgs.push(`${countExcl} exclusão(ões)`);
  toast(`✅ ${msgs.join(' e ')} salvo(s).`, 'ok');

  // Atualiza a lista no lugar (sem fechar o modal)
  _preencherModalDivergencias();
  if (_invGrupo) selecionarGrupoInv(_invGrupo);
}

async function carregarHistoricoInv() {
  const fil    = document.getElementById('hist-inv-fil')?.value   || '';
  const setor  = document.getElementById('hist-inv-setor')?.value || '';
  const ini    = document.getElementById('hist-inv-ini')?.value   || '';
  const fim    = document.getElementById('hist-inv-fim')?.value   || '';

  let query = sb.from('est_inventarios')
    .select('id,num_inv,data,local,setor,grupo,responsavel,total_geral')
    .order('criado_em', { ascending: false })
    .limit(200);
  if (fil)   query = query.eq('local', fil);
  if (setor) query = query.eq('setor', setor);
  if (ini)   query = query.gte('data', ini);
  if (fim)   query = query.lte('data', fim);
  const { data: lista } = await query;

  const cont = document.getElementById('lst-historico-inv');
  if (!cont) return;
  if (!lista?.length) { cont.innerHTML = '<p class="text-muted">Nenhuma contagem encontrada.</p>'; return; }

  // Popula filtro de setor dinamicamente
  const setorEl = document.getElementById('hist-inv-setor');
  if (setorEl) {
    const setores = [...new Set(lista.map(i => i.setor).filter(Boolean))].sort();
    const cur = setorEl.value;
    setorEl.innerHTML = '<option value="">Todos os setores</option>' +
      setores.map(s => `<option value="${esc(s)}"${s === cur ? ' selected' : ''}>${esc(s)}</option>`).join('');
  }

  cont.innerHTML = lista.map(inv => {
    const localCor = inv.local === 'Centro' ? '#0d6efd' : '#198754';
    const dataBR   = inv.data.split('-').reverse().join('/');
    return `<div class="d-flex align-items-center justify-content-between border-bottom py-2">
      <div>
        <span class="badge bg-dark me-1">${inv.num_inv}</span>
        <span class="badge me-2" style="background:${localCor}">${inv.local}</span>
        <strong>${dataBR}</strong>
        ${inv.setor ? `<span class="badge ms-1" style="background:#6f42c1">${esc(inv.setor)}</span>` : ''}
        ${inv.grupo ? `<span class="badge ms-1" style="background:#0d6efd">${esc(inv.grupo)}</span>` : ''}
        ${inv.responsavel ? `<span class="text-muted ms-2">— ${inv.responsavel}</span>` : ''}
      </div>
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-sm btn-outline-primary" title="Ver detalhes" onclick="verDetalheContagem('${inv.id}')">
          <i class="bi bi-eye"></i>
        </button>
        <button class="btn btn-sm btn-outline-secondary" title="Editar contagem" onclick="abrirEditarContagem('${inv.id}')">
          <i class="bi bi-pencil"></i>
        </button>
        <button class="btn btn-sm btn-outline-danger" onclick="excluirInventario('${inv.id}')">
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </div>`;
  }).join('');
}

function limparFiltrosHist() {
  ['hist-inv-fil','hist-inv-setor','hist-inv-ini','hist-inv-fim'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  carregarHistoricoInv();
}

async function verDetalheContagem(invId) {
  const modalEl = document.getElementById('modal-ver-contagem');
  const body    = document.getElementById('modal-ver-contagem-body');
  const titulo  = document.getElementById('modal-ver-contagem-titulo');
  body.innerHTML = '<p class="text-center text-muted py-3">Carregando...</p>';
  bootstrap.Modal.getOrCreateInstance(modalEl).show();

  const [{ data: inv }, { data: itens }] = await Promise.all([
    sb.from('est_inventarios').select('*').eq('id', invId).single(),
    sb.from('est_inventario_itens').select('*').eq('inventario_id', invId).order('nome'),
  ]);

  titulo.innerHTML = `<i class="bi bi-eye-fill"></i> ${inv?.num_inv || ''} · ${esc(inv?.setor || '')} · ${esc(inv?.grupo || '')}`;

  // Tenta buscar o pedido interno correspondente (mesmo setor/grupo/local/data)
  let atendidoMap = {};
  if (inv?.setor && inv?.grupo) {
    const { data: pedidos } = await sb.from('pedidos_internos')
      .select('id').eq('setor', inv.setor).eq('obs', inv.grupo)
      .eq('local', inv.local).eq('data', inv.data).limit(1);
    if (pedidos?.length) {
      const { data: pedItens } = await sb.from('pedidos_internos_itens')
        .select('produto_id,produto_nome,qtd_pedida,qtd_liberada').eq('pedido_id', pedidos[0].id);
      (pedItens || []).forEach(pi => {
        atendidoMap[pi.produto_id || pi.produto_nome] = {
          solicitado: pi.qtd_pedida ?? 0,
          atendido:   pi.qtd_liberada ?? '—',
        };
      });
    }
  }

  const dataBR = (inv?.data || '').split('-').reverse().join('/');
  const rows = (itens || []).map(it => {
    const key   = it.produto_id || it.nome;
    const ped   = atendidoMap[key] || {};
    const solicitado = ped.solicitado ?? Math.max(0, (it.pedido_padrao ?? 0) - (it.estoque ?? 0));
    const atendido   = ped.atendido ?? '—';
    const atCor = typeof ped.atendido === 'number' && ped.atendido < solicitado ? 'text-danger' : '';
    return `<tr>
      <td>${esc(it.nome)}</td>
      <td class="text-center">${+(it.estoque ?? 0)}</td>
      <td class="text-center text-muted">${it.pedido_padrao ?? '—'}</td>
      <td class="text-center fw-bold text-primary">${+solicitado}</td>
      <td class="text-center fw-bold ${atCor}">${typeof atendido === 'number' ? +atendido : atendido}</td>
    </tr>`;
  }).join('');

  body.innerHTML = `
    <div class="alert alert-secondary py-2 mb-3 small">
      <strong>${esc(inv?.num_inv || '')}</strong> · ${esc(inv?.setor || '')} · ${esc(inv?.grupo || '')} · ${dataBR} · ${esc(inv?.responsavel || '')}
    </div>
    <div class="table-responsive">
      <table class="table table-sm align-middle">
        <thead class="table-light"><tr>
          <th>Produto</th>
          <th class="text-center">Contado</th>
          <th class="text-center">Padrão</th>
          <th class="text-center">Solicitado</th>
          <th class="text-center">Atendido</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;
}

async function excluirInventario(id) {
  if (!confirm('Excluir esta contagem?')) return;
  await sb.from('est_inventarios').delete().eq('id', id);
  toast('Contagem excluída.', 'ok');
  carregarHistoricoInv();
}

let _editContagemInv = null;

async function abrirEditarContagem(invId) {
  const { data: inv   } = await sb.from('est_inventarios').select('*').eq('id', invId).single();
  const { data: itens } = await sb.from('est_inventario_itens').select('*').eq('inventario_id', invId).order('nome');
  _editContagemInv = inv;

  const padroes = Object.fromEntries((itens || []).map(i => [i.id, i.pedido_padrao ?? 0]));
  const rows = (itens || []).map(it => {
    const ped     = Math.max(0, (it.pedido_padrao ?? 0) - (it.estoque ?? 0));
    const prodCad = cProdutosFT.find(p => p.id === it.produto_id);
    const unidade = prodCad?.unidade_comp || '';
    return `<tr>
      <td>${esc(it.nome)}</td>
      <td class="text-center text-muted small">${esc(unidade || '—')}</td>
      <td class="text-center text-muted">${it.pedido_padrao ?? '—'}</td>
      <td class="text-center" style="width:120px">
        <input type="number" class="form-control form-control-sm text-center"
          id="cont-est-${it.id}" value="${it.estoque ?? 0}" min="0" step="1"
          oninput="_recalcPed('${it.id}',${it.pedido_padrao ?? 0})">
      </td>
      <td class="text-center fw-bold text-primary" id="cont-ped-${it.id}" style="width:90px">${ped}</td>
    </tr>`;
  }).join('');

  const dataBR = (inv?.data || '').split('-').reverse().join('/');
  document.getElementById('modal-editar-contagem-body').innerHTML = `
    <div class="alert alert-secondary py-2 mb-3">
      <strong>${esc(inv?.num_inv || '—')}</strong> ·
      ${esc(inv?.setor || '')} · ${esc(inv?.grupo || '')} · ${dataBR}
    </div>
    <div class="table-responsive">
      <table class="table table-sm align-middle">
        <thead class="table-light"><tr>
          <th>Produto</th>
          <th class="text-center">Un.</th>
          <th class="text-center">Padrão</th>
          <th class="text-center">Estoque Contado</th>
          <th class="text-center">Pedido</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    <input type="hidden" id="cont-itens-ids" value='${JSON.stringify((itens || []).map(i => i.id))}'>
    <input type="hidden" id="cont-padroes"   value='${JSON.stringify(padroes)}'>`;

  new bootstrap.Modal(document.getElementById('modal-editar-contagem')).show();
}

function _recalcPed(itId, padrao) {
  const est = parseQtd(document.getElementById(`cont-est-${itId}`)?.value);
  const el  = document.getElementById(`cont-ped-${itId}`);
  if (el) el.textContent = Math.max(0, padrao - est);
}

async function confirmarEdicaoContagem() {
  if (!_editContagemInv) return;
  const ids     = JSON.parse(document.getElementById('cont-itens-ids')?.value || '[]');
  const padroes = JSON.parse(document.getElementById('cont-padroes')?.value || '{}');

  const updates = ids.map(id => {
    const estoque = parseQtd(document.getElementById(`cont-est-${id}`)?.value);
    const pedido  = Math.max(0, (padroes[id] ?? 0) - estoque);
    return { id, estoque, pedido };
  });

  await Promise.all(updates.map(u =>
    sb.from('est_inventario_itens').update({ estoque: u.estoque, pedido: u.pedido }).eq('id', u.id)
  ));

  const totalGeral = updates.reduce((s, u) => s + u.pedido, 0);
  await sb.from('est_inventarios').update({ total_geral: totalGeral }).eq('id', _editContagemInv.id);

  // Atualiza pedido pendente do mesmo setor+grupo
  const { data: peds } = await sb.from('pedidos_internos')
    .select('id').eq('setor', _editContagemInv.setor).eq('obs', _editContagemInv.grupo)
    .eq('status', 'pendente').limit(1);

  if (peds?.length) {
    const pedidoId = peds[0].id;
    const { data: pedItens  } = await sb.from('pedidos_internos_itens').select('*').eq('pedido_id', pedidoId);
    const { data: contItens } = await sb.from('est_inventario_itens').select('id,nome,produto_id').eq('inventario_id', _editContagemInv.id);
    const nomeMap = Object.fromEntries((contItens || []).map(c => [c.id, c]));

    const toUpdate = [], toInsert = [];
    for (const u of updates) {
      const info  = nomeMap[u.id];
      if (!info) continue;
      const pedIt = pedItens?.find(p => (info.produto_id && p.produto_id === info.produto_id) || p.nome === info.nome);
      if (pedIt) {
        toUpdate.push({ pedItId: pedIt.id, qtd_pedida: u.pedido });
      } else if (u.pedido > 0) {
        toInsert.push({ pedido_id: pedidoId, produto_id: info.produto_id || null, nome: info.nome, qtd_pedida: u.pedido });
      }
    }

    await Promise.all([
      ...toUpdate.map(u => sb.from('pedidos_internos_itens').update({ qtd_pedida: u.qtd_pedida }).eq('id', u.pedItId)),
      toInsert.length ? sb.from('pedidos_internos_itens').insert(toInsert) : null,
    ].filter(Boolean));

    bootstrap.Modal.getInstance(document.getElementById('modal-editar-contagem'))?.hide();
    toast('Contagem atualizada e pedido recalculado! ✅', 'ok');
  } else {
    bootstrap.Modal.getInstance(document.getElementById('modal-editar-contagem'))?.hide();
    toast('Contagem atualizada.', 'ok');
  }

  carregarHistoricoInv();
}

// ═══════════════════════════════════════════════════════════════
// PEDIDOS INTERNOS (setor → estoque)
// ═══════════════════════════════════════════════════════════════

const _STATUS_PED = {
  pendente:  '<span class="badge bg-warning text-dark">Pendente</span>',
  liberado:  '<span class="badge bg-primary">Liberado</span>',
  recebido:  '<span class="badge bg-success">Recebido</span>',
  cancelado: '<span class="badge bg-danger">Cancelado</span>',
};

async function _proximoNumPedido() {
  const { data } = await sb.from('pedidos_internos')
    .select('num_pedido').order('criado_em', { ascending: false }).limit(1);
  const n = data?.[0]?.num_pedido ? parseInt(data[0].num_pedido.replace(/\D/g, '')) || 0 : 0;
  return 'PED-' + String(n + 1).padStart(4, '0');
}

async function enviarPedidoInterno() {
  if (!_invSetor || !_invGrupo) { toast('Selecione setor e grupo antes de enviar.', 'erro'); return; }
  const data = document.getElementById('inv-data').value;
  if (!data) { toast('Selecione a data da contagem.', 'erro'); return; }
  if (!_invProds.length) { toast('Nenhum produto no grupo.', 'erro'); return; }

  const { data: pedAberto } = await sb.from('pedidos_internos')
    .select('num_pedido,status').eq('setor', _invSetor).eq('obs', _invGrupo)
    .eq('data', data).eq('status', 'pendente').limit(1);
  if (pedAberto?.length) {
    toast(`${_invSetor} / ${_invGrupo} — ${pedAberto[0].num_pedido} ainda aguardando liberação.`, 'erro'); return;
  }

  const resp = (document.getElementById('inv-resp').value || '').trim();

  // ─── 1. Salvar contagem ───
  const itensCont = _invProds.map((p, i) => {
    const estoque       = parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0;
    const pedido_padrao = _getPadrao(p.nome) ?? 0;
    const pedido        = Math.max(0, pedido_padrao - estoque);
    return { produto_id: p.produto_id || null, nome: p.nome, estoque, pedido_padrao, pedido,
             cozinha_bar: 0, outros: 0, total: estoque, unidade: 'UN', valor_unitario: 0, soma_total: 0 };
  });
  const totalPedido = itensCont.reduce((s, it) => s + it.pedido, 0);

  const { data: ultInvs } = await sb.from('est_inventarios').select('num_inv').order('criado_em', { ascending: false }).limit(1);
  const ultimoNum = ultInvs?.[0]?.num_inv ? parseInt(ultInvs[0].num_inv.replace(/\D/g, '')) || 0 : 0;
  const num_inv   = 'INV-' + String(ultimoNum + 1).padStart(4, '0');

  const { data: inv, error: eInv } = await sb.from('est_inventarios').insert([{
    num_inv, data, local: _invLocal, responsavel: resp,
    setor: _invSetor, grupo: _invGrupo, total_geral: totalPedido,
  }]).select().single();
  if (eInv) { toast('Erro ao salvar contagem: ' + eInv.message, 'erro'); return; }
  await sb.from('est_inventario_itens').insert(itensCont.map(it => ({ ...it, inventario_id: inv.id })));

  // ─── 2. Criar pedido interno (só itens com pedido > 0) ───
  const itensPed = itensCont.filter(it => it.pedido > 0)
    .map(it => ({ produto_id: it.produto_id, nome: it.nome, qtd_pedida: it.pedido }));

  if (!itensPed.length) {
    toast(`${num_inv} salvo! Todos os produtos estão no padrão — nenhum pedido gerado.`, 'ok');
    carregarHistoricoInv();
    _limparCamposEstoque();
    return;
  }

  const numPed = await _proximoNumPedido();
  const { data: ped, error: ePed } = await sb.from('pedidos_internos').insert({
    num_pedido: numPed, data,
    dia_semana: _invFeriado ? 'feriado' : _invDia,
    setor: _invSetor, local: _invLocal,
    tipo: 'normal', status: 'pendente',
    responsavel: resp, obs: _invGrupo,
  }).select().single();
  if (ePed) { toast(`${num_inv} salvo, mas erro no pedido: ` + ePed.message, 'warn'); return; }

  await sb.from('pedidos_internos_itens').insert(itensPed.map(it => ({ ...it, pedido_id: ped.id })));

  toast(`${num_inv} salvo + ${numPed} enviado (${itensPed.length} item(s))! ✅`, 'ok');
  carregarHistoricoInv();
  _limparCamposEstoque();
}

async function salvarSaldoContagemDesktop() {
  if (!_invSetor || !_invGrupo || !_invProds.length) { toast('Selecione grupo antes de salvar.', 'erro'); return; }
  const data = document.getElementById('inv-data').value;
  const resp = (document.getElementById('inv-resp').value || '').trim();
  const btn  = document.getElementById('inv-btn-salvar-saldo');
  if (btn) { btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>'; }

  const agora = new Date().toISOString();
  const itensCont = _invProds.map((p, i) => ({
    produto_id: p.produto_id || null, nome: p.nome,
    estoque: parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0,
    pedido_padrao: 0, pedido: 0, cozinha_bar: 0, outros: 0,
    total: parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0,
    unidade: p.unidade || 'UN', valor_unitario: 0, soma_total: 0,
  }));

  // Registra em est_inventarios para histórico
  const { data: ultInvs } = await sb.from('est_inventarios').select('num_inv').order('criado_em',{ascending:false}).limit(1);
  const ultimoNum = ultInvs?.[0]?.num_inv ? parseInt(ultInvs[0].num_inv.replace(/\D/g,''))||0 : 0;
  const num_inv   = 'INV-' + String(ultimoNum+1).padStart(4,'0');
  const { data: inv } = await sb.from('est_inventarios').insert([{
    num_inv, data, local: _invLocal, responsavel: resp,
    setor: 'ESTOQUE DA LOJA', grupo: _invGrupo, total_geral: 0,
  }]).select().single();
  if (inv) await sb.from('est_inventario_itens').insert(itensCont.map(it => ({ ...it, inventario_id: inv.id })));

  // Atualiza saldo absoluto
  const saldoRows = itensCont.filter(it => it.produto_id)
    .map(it => ({ produto_id: it.produto_id, local: 'ESTOQUE_LOJA', saldo: it.estoque, updated_at: agora }));
  if (saldoRows.length) await sb.from('est_saldo_local').upsert(saldoRows, { onConflict: 'produto_id,local' });

  toast(`${num_inv} salvo! ✅`, 'ok');
  if (btn) { btn.disabled = false; btn.innerHTML = '<i class="bi bi-floppy-fill"></i> Salvar Saldo'; }
  carregarHistoricoInv();
  _limparCamposEstoque();
}

async function salvarSaldoInicialSetor() {
  if (!_invSetor || !_invGrupo || !_invProds.length) { toast('Selecione grupo antes de salvar.', 'erro'); return; }
  if (!confirm(`Salvar saldo inicial de ${_invSetor} / ${_invGrupo}?\nIsso define o estoque de partida do setor.`)) return;
  const data = document.getElementById('inv-data').value;
  const resp = (document.getElementById('inv-resp').value || '').trim();
  const btn  = document.getElementById('inv-btn-saldo-inicial');
  if (btn) { btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>'; }

  const agora = new Date().toISOString();
  const itensCont = _invProds.map((p, i) => ({
    produto_id: p.produto_id || null, nome: p.nome,
    estoque: parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0,
    pedido_padrao: 0, pedido: 0, cozinha_bar: 0, outros: 0,
    total: parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0,
    unidade: p.unidade || 'UN', valor_unitario: 0, soma_total: 0,
  }));

  // Histórico em est_inventarios
  const { data: ultInvs } = await sb.from('est_inventarios').select('num_inv').order('criado_em',{ascending:false}).limit(1);
  const ultimoNum = ultInvs?.[0]?.num_inv ? parseInt(ultInvs[0].num_inv.replace(/\D/g,''))||0 : 0;
  const num_inv   = 'INV-' + String(ultimoNum+1).padStart(4,'0');
  const { data: inv } = await sb.from('est_inventarios').insert([{
    num_inv, data, local: _invLocal, responsavel: resp,
    setor: _invSetor, grupo: _invGrupo, total_geral: 0,
  }]).select().single();
  if (inv) await sb.from('est_inventario_itens').insert(itensCont.map(it => ({ ...it, inventario_id: inv.id })));

  // Salva saldo absoluto do setor
  const saldoRows = itensCont.filter(it => it.produto_id)
    .map(it => ({ produto_id: it.produto_id, local: _invSetor, saldo: it.estoque, updated_at: agora }));
  if (saldoRows.length) await sb.from('est_saldo_local').upsert(saldoRows, { onConflict: 'produto_id,local' });

  toast(`${num_inv} — saldo inicial de ${_invSetor} salvo! ✅`, 'ok');
  if (btn) { btn.disabled = false; btn.innerHTML = '<i class="bi bi-floppy-fill"></i> Saldo Inicial'; }
  carregarHistoricoInv();
  _limparCamposEstoque();
}

function _limparCamposEstoque() {
  _invProds.forEach((_, i) => {
    const el = document.getElementById(`inv-est-${i}`);
    if (el) el.value = '0';
    calcPedidoInv(i);
  });
}

async function carregarPedidosInternos() {
  const local    = document.getElementById('fil-ped-local')?.value     || '';
  const setor    = document.getElementById('fil-ped-setor')?.value     || '';
  const status   = document.getElementById('fil-ped-status')?.value    || '';
  const tipo     = document.getElementById('fil-ped-tipo')?.value      || '';
  const dataIni  = document.getElementById('fil-ped-data-ini')?.value  || '';
  const dataFim  = document.getElementById('fil-ped-data-fim')?.value  || '';

  let q = sb.from('pedidos_internos').select('*').neq('tipo', 'transferencia').order('criado_em', { ascending: false }).limit(200);
  if (local)   q = q.eq('local', local);
  if (setor)   q = q.eq('setor', setor);
  if (status)  q = q.eq('status', status);
  if (tipo)    q = q.eq('tipo', tipo);
  if (dataIni) q = q.gte('data', dataIni);
  if (dataFim) q = q.lte('data', dataFim);

  const { data: peds, error } = await q;
  if (error) { toast('Erro ao carregar pedidos: ' + error.message, 'erro'); return; }

  const el = document.getElementById('lst-pedidos-estoque');
  if (!peds?.length) { el.innerHTML = '<p class="text-muted text-center py-4">Nenhum pedido encontrado.</p>'; return; }

  const { data: itens } = await sb.from('pedidos_internos_itens')
    .select('*').in('pedido_id', peds.map(p => p.id));

  _renderPedEstoque(peds, itens || []);
}

async function carregarMeusPedidos() {
  const setor   = document.getElementById('fil-meus-setor')?.value     || '';
  const status  = document.getElementById('fil-meus-status')?.value    || '';
  const tipo    = document.getElementById('fil-meus-tipo')?.value      || '';
  const dataIni = document.getElementById('fil-meus-data-ini')?.value  || '';
  const dataFim = document.getElementById('fil-meus-data-fim')?.value  || '';

  const el = document.getElementById('lst-meus-pedidos');
  if (!setor) { el.innerHTML = '<p class="text-muted text-center py-4">Selecione um setor.</p>'; return; }

  let q = sb.from('pedidos_internos').select('*').eq('setor', setor).order('criado_em', { ascending: false }).limit(200);
  if (status)  q = q.eq('status', status);
  if (tipo)    q = q.eq('tipo', tipo);
  if (dataIni) q = q.gte('data', dataIni);
  if (dataFim) q = q.lte('data', dataFim);

  const { data: peds, error } = await q;
  if (error) { toast('Erro: ' + error.message, 'erro'); return; }
  if (!peds?.length) { el.innerHTML = '<p class="text-muted text-center py-4">Nenhum pedido encontrado.</p>'; return; }

  const { data: itens } = await sb.from('pedidos_internos_itens')
    .select('*').in('pedido_id', peds.map(p => p.id));

  _renderMeusPedidos(peds, itens || []);
}

function _renderPedEstoque(peds, todosItens) {
  document.getElementById('lst-pedidos-estoque').innerHTML = peds.map(ped => {
    const its = todosItens.filter(it => it.pedido_id === ped.id);
    const rows = its.map(it => `<tr>
      <td class="ps-3">${esc(it.nome)}</td>
      <td class="text-center">${it.qtd_pedida ?? '—'}</td>
      <td class="text-center">${it.qtd_liberada ?? '—'}</td>
    </tr>`).join('');
    const tipo = ped.tipo === 'emergencia' ? '<span class="badge bg-danger ms-1">🚨 Emergência</span>' : '';
    return `<div class="card mb-3">
      <div class="card-header d-flex align-items-center justify-content-between py-2 flex-wrap gap-2">
        <div>
          <strong>${esc(ped.num_pedido || '—')}</strong>${tipo}
          <span class="text-muted small ms-2">${ped.data} · ${esc(ped.setor)} · ${esc(ped.local || '')}${ped.obs ? ' · ' + esc(ped.obs) : ''}</span>
        </div>
        <div class="d-flex align-items-center gap-2">
          ${_STATUS_PED[ped.status] || ped.status}
          ${ped.status === 'pendente' ? `
          <button class="btn btn-sm btn-success" onclick="abrirLiberarPedido('${ped.id}')">
            <i class="bi bi-box-arrow-right"></i> Liberar
          </button>
          <button class="btn btn-sm btn-outline-danger" onclick="cancelarPedidoInterno('${ped.id}','${ped.num_pedido}')">
            <i class="bi bi-x-circle"></i> Cancelar
          </button>` : ''}
        </div>
      </div>
      <div class="table-responsive">
        <table class="table table-sm mb-0">
          <thead class="table-light"><tr>
            <th class="ps-3">Produto</th>
            <th class="text-center">Pedido</th>
            <th class="text-center">Liberado</th>
          </tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
      ${ped.responsavel ? `<div class="card-footer py-1 small text-muted">Responsável: ${esc(ped.responsavel)}</div>` : ''}
    </div>`;
  }).join('');
}

function _renderMeusPedidos(peds, todosItens) {
  document.getElementById('lst-meus-pedidos').innerHTML = peds.map(ped => {
    const its = todosItens.filter(it => it.pedido_id === ped.id);
    const rows = its.map(it => `<tr>
      <td class="ps-3">${esc(it.nome)}</td>
      <td class="text-center">${it.qtd_pedida ?? '—'}</td>
      <td class="text-center">${it.qtd_liberada ?? '—'}</td>
      <td class="text-center">${it.qtd_recebida ?? '—'}</td>
    </tr>`).join('');
    const tipo = ped.tipo === 'emergencia' ? '<span class="badge bg-danger ms-1">🚨 Emergência</span>' : '';
    return `<div class="card mb-3">
      <div class="card-header d-flex align-items-center justify-content-between py-2 flex-wrap gap-2">
        <div>
          <strong>${esc(ped.num_pedido || '—')}</strong>${tipo}
          <span class="text-muted small ms-2">${ped.data}</span>
        </div>
        <div class="d-flex align-items-center gap-2">
          ${_STATUS_PED[ped.status] || ped.status}
          ${ped.status === 'pendente' ? `<button class="btn btn-sm btn-outline-secondary" onclick="abrirEditarPedido('${ped.id}')">
            <i class="bi bi-pencil"></i> Editar
          </button>` : ''}
          ${ped.status === 'liberado' ? `<button class="btn btn-sm btn-primary" onclick="abrirReceberPedido('${ped.id}')">
            <i class="bi bi-check-circle"></i> Confirmar Recebimento
          </button>` : ''}
        </div>
      </div>
      <div class="table-responsive">
        <table class="table table-sm mb-0">
          <thead class="table-light"><tr>
            <th class="ps-3">Produto</th>
            <th class="text-center">Pedido</th>
            <th class="text-center">Liberado</th>
            <th class="text-center">Recebido</th>
          </tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
      ${ped.responsavel ? `<div class="card-footer py-1 small text-muted">Responsável: ${esc(ped.responsavel)}</div>` : ''}
    </div>`;
  }).join('');
}

async function cancelarPedidoInterno(id, num) {
  if (!confirm(`Cancelar pedido ${num}?\n\nO setor poderá enviar um novo pedido hoje.`)) return;
  const { error } = await sb.from('pedidos_internos')
    .update({ status: 'cancelado' }).eq('id', id).eq('status', 'pendente');
  if (error) { toast('Erro ao cancelar: ' + error.message, 'erro'); return; }
  toast(`${num} cancelado.`, 'ok');
  carregarPedidosInternos();
}

let _pedLiberarId = null;

async function abrirLiberarPedido(pedidoId) {
  _pedLiberarId = pedidoId;
  const [{ data: ped }, { data: itens }] = await Promise.all([
    sb.from('pedidos_internos').select('*').eq('id', pedidoId).single(),
    sb.from('pedidos_internos_itens').select('*').eq('pedido_id', pedidoId),
  ]);

  // Busca contagem relacionada (mesmo setor + local + data + grupo)
  const estoqueMap = {};
  const { data: invs } = await sb.from('est_inventarios')
    .select('id').eq('setor', ped?.setor).eq('local', ped?.local)
    .eq('data', ped?.data).eq('grupo', ped?.obs)
    .order('criado_em', { ascending: false }).limit(1);
  if (invs?.[0]) {
    const { data: invItens } = await sb.from('est_inventario_itens')
      .select('nome,estoque').eq('inventario_id', invs[0].id);
    (invItens || []).forEach(i => { estoqueMap[i.nome?.trim().toUpperCase()] = i.estoque; });
  }

  const getPad = (nome) => {
    const entry = _invPadroes[`${ped?.setor}|${ped?.obs}|${nome.trim().toUpperCase()}`];
    if (entry === undefined || entry === null) return '—';
    if (typeof entry === 'number') return entry;
    const val = entry[ped?.dia_semana];
    return val !== undefined ? val : '—';
  };

  const rows = (itens || []).map(it => {
    const est = estoqueMap[it.nome?.trim().toUpperCase()];
    const pad = getPad(it.nome || '');
    const estFmt = est !== undefined ? est : '—';
    const estCor = est !== undefined && est <= 0 ? 'color:#dc3545;font-weight:600' : 'color:#fd7e14;font-weight:600';
    return `<tr>
      <td>${esc(it.nome)}</td>
      <td class="text-center text-muted">${pad}</td>
      <td class="text-center" style="${estCor}">${estFmt}</td>
      <td class="text-center">${it.qtd_pedida ?? '—'}</td>
      <td class="text-center" style="width:110px">
        <input type="number" class="form-control form-control-sm text-center"
          id="lib-qtd-${it.id}" value="${it.qtd_pedida ?? 0}" min="0" step="1">
      </td>
    </tr>`;
  }).join('');

  document.getElementById('modal-liberar-body').innerHTML = `
    <div class="alert alert-success py-2 mb-3">
      <strong>${esc(ped?.num_pedido || '—')}</strong> ·
      ${esc(ped?.setor || '')} · ${esc(ped?.local || '')} · ${ped?.data || ''}
      ${ped?.obs ? `<br><small class="text-muted">${esc(ped.obs)}</small>` : ''}
    </div>
    <div class="table-responsive">
      <table class="table table-sm align-middle">
        <thead class="table-light"><tr>
          <th>Produto</th>
          <th class="text-center text-muted" title="Quantidade padrão para o dia">Padrão</th>
          <th class="text-center" title="Estoque contado na contagem">Estoque</th>
          <th class="text-center">Pedido</th>
          <th class="text-center">Qtd. a Liberar</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    <input type="hidden" id="lib-itens" value='${JSON.stringify((itens || []).map(i => i.id))}'>`;

  new bootstrap.Modal(document.getElementById('modal-liberar-pedido')).show();
}

async function confirmarLiberacao() {
  if (!_pedLiberarId) return;
  const itenIds = JSON.parse(document.getElementById('lib-itens')?.value || '[]');

  await Promise.all(itenIds.map(id => {
    const qtd = parseQtd(document.getElementById(`lib-qtd-${id}`)?.value);
    return sb.from('pedidos_internos_itens').update({ qtd_liberada: qtd }).eq('id', id);
  }));

  await sb.from('pedidos_internos').update({
    status: 'liberado', liberado_em: new Date().toISOString(),
  }).eq('id', _pedLiberarId);

  bootstrap.Modal.getInstance(document.getElementById('modal-liberar-pedido'))?.hide();
  toast('Pedido liberado! ✅', 'ok');
  carregarPedidosInternos();
}

let _pedEditarId = null;

async function abrirEditarPedido(pedidoId) {
  _pedEditarId = pedidoId;
  const { data: ped   } = await sb.from('pedidos_internos').select('*').eq('id', pedidoId).single();
  const { data: itens } = await sb.from('pedidos_internos_itens').select('*').eq('pedido_id', pedidoId);

  const rows = (itens || []).map(it => `<tr>
    <td>${esc(it.nome)}</td>
    <td class="text-center" style="width:130px">
      <input type="number" class="form-control form-control-sm text-center"
        id="edit-qtd-${it.id}" value="${it.qtd_pedida ?? 0}" min="0" step="1">
    </td>
  </tr>`).join('');

  document.getElementById('modal-editar-body').innerHTML = `
    <div class="alert alert-secondary py-2 mb-3">
      <strong>${esc(ped?.num_pedido || '—')}</strong> ·
      ${esc(ped?.setor || '')} · ${esc(ped?.obs || '')} · ${ped?.data || ''}
    </div>
    <div class="table-responsive">
      <table class="table table-sm align-middle">
        <thead class="table-light"><tr>
          <th>Produto</th>
          <th class="text-center">Qtd. Pedida</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    <input type="hidden" id="edit-itens-ids" value='${JSON.stringify((itens || []).map(i => i.id))}'>`;

  new bootstrap.Modal(document.getElementById('modal-editar-pedido')).show();
}

async function confirmarEdicaoPedido() {
  if (!_pedEditarId) return;
  const ids = JSON.parse(document.getElementById('edit-itens-ids')?.value || '[]');
  await Promise.all(ids.map(id => {
    const qtd = parseQtd(document.getElementById(`edit-qtd-${id}`)?.value);
    return sb.from('pedidos_internos_itens').update({ qtd_pedida: qtd }).eq('id', id);
  }));
  bootstrap.Modal.getInstance(document.getElementById('modal-editar-pedido'))?.hide();
  toast('Pedido atualizado!', 'ok');
  carregarMeusPedidos();
}

let _pedReceberId    = null;
let _pedReceberItens = [];
let _pedReceberSetor = null;

async function _movSaldo(produto_id, local, delta) {
  if (!produto_id || !delta) return;
  const { data: cur } = await sb.from('est_saldo_local')
    .select('saldo').eq('produto_id', produto_id).eq('local', local).maybeSingle();
  const novoSaldo = (cur?.saldo ?? 0) + delta;
  await sb.from('est_saldo_local')
    .upsert({ produto_id, local, saldo: novoSaldo, updated_at: new Date().toISOString() });
}

async function abrirReceberPedido(pedidoId) {
  _pedReceberId = pedidoId;
  const { data: ped } = await sb.from('pedidos_internos').select('*').eq('id', pedidoId).single();
  const { data: itens } = await sb.from('pedidos_internos_itens').select('*').eq('pedido_id', pedidoId);
  _pedReceberItens = itens || [];
  _pedReceberSetor = ped?.setor || null;

  const rows = (itens || []).map(it => `<tr>
    <td>${esc(it.nome)}</td>
    <td class="text-center">${it.qtd_pedida ?? '—'}</td>
    <td class="text-center">${it.qtd_liberada ?? '—'}</td>
    <td class="text-center" style="width:130px">
      <input type="number" class="form-control form-control-sm text-center"
        id="rec-qtd-${it.id}" value="${it.qtd_liberada ?? 0}" min="0" step="1">
    </td>
  </tr>`).join('');

  document.getElementById('modal-receber-body').innerHTML = `
    <div class="alert alert-primary py-2 mb-3">
      <strong>${esc(ped?.num_pedido || '—')}</strong> · ${esc(ped?.setor || '')} · ${ped?.data || ''}
    </div>
    <div class="table-responsive">
      <table class="table table-sm align-middle">
        <thead class="table-light"><tr>
          <th>Produto</th>
          <th class="text-center">Pedido</th>
          <th class="text-center">Liberado</th>
          <th class="text-center">Qtd. Recebida</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    <input type="hidden" id="rec-itens" value='${JSON.stringify((itens || []).map(i => i.id))}'>`;

  new bootstrap.Modal(document.getElementById('modal-receber-pedido')).show();
}

async function confirmarRecebimentoInv() {
  if (!_pedReceberId) return;
  const itenIds = JSON.parse(document.getElementById('rec-itens')?.value || '[]');

  await Promise.all(itenIds.map(id => {
    const qtd = parseQtd(document.getElementById(`rec-qtd-${id}`)?.value);
    return sb.from('pedidos_internos_itens').update({ qtd_recebida: qtd }).eq('id', id);
  }));

  await sb.from('pedidos_internos').update({
    status: 'recebido', recebido_em: new Date().toISOString(),
  }).eq('id', _pedReceberId);

  // Movimentar saldo: diminui ESTOQUE_LOJA, aumenta setor
  await Promise.all(_pedReceberItens.filter(it => it.produto_id).map(async it => {
    const qtd = parseQtd(document.getElementById(`rec-qtd-${it.id}`)?.value);
    if (!qtd) return;
    await _movSaldo(it.produto_id, 'ESTOQUE_LOJA', -qtd);
    if (_pedReceberSetor) await _movSaldo(it.produto_id, _pedReceberSetor, +qtd);
  }));

  bootstrap.Modal.getInstance(document.getElementById('modal-receber-pedido'))?.hide();
  toast('Recebimento confirmado! ✅', 'ok');
  carregarMeusPedidos();
}

// ════════════════════════════════════════════════════════════════
// TRANSFERÊNCIAS ENTRE UNIDADES
// Estoque Loja (Centro / Delivery P10) solicita ao Estoque Central
// Estoque Central aprova e envia → saldo sai do Estoque Central
// Unidade destino confirma recebimento → saldo entra no ESTOQUE_LOJA
//
// criarSolicitacaoTransf() é a API pública: pode ser chamada
// manualmente (origem='manual') ou pela engine de ficha técnica
// no futuro (origem='automatico').
// ════════════════════════════════════════════════════════════════

async function carregarTransferencias() {
  const local = _invLocal || 'Centro';
  const isEC  = local === 'Estoque Central';

  document.getElementById('transf-solicitar')?.classList.toggle('d-none', isEC);
  document.getElementById('transf-atender')?.classList.toggle('d-none', !isEC);

  if (isEC) {
    await _carregarTransfAtender();
  } else {
    await _carregarTransfSolicitacoes(local);
  }
}

async function _carregarTransfSolicitacoes(local) {
  const el = document.getElementById('transf-lista-solicitacoes');
  if (!el) return;
  const { data, error } = await sb.from('pedidos_internos')
    .select('*').eq('tipo', 'transferencia').eq('local', local)
    .order('criado_em', { ascending: false }).limit(30);
  if (error) { el.innerHTML = '<p class="text-danger">Erro ao carregar.</p>'; return; }
  if (!data?.length) { el.innerHTML = '<p class="text-muted text-center py-4">Nenhuma solicitação ainda.</p>'; return; }
  const ids = data.map(p => p.id);
  const { data: itens } = await sb.from('pedidos_internos_itens').select('*').in('pedido_id', ids);
  const byPedido = {};
  (itens || []).forEach(it => { if (!byPedido[it.pedido_id]) byPedido[it.pedido_id] = []; byPedido[it.pedido_id].push(it); });
  el.innerHTML = data.map(p => _renderTransfCard({ ...p, _itens: byPedido[p.id] || [] }, false)).join('');
}

async function _carregarTransfAtender() {
  const el = document.getElementById('transf-lista-atender');
  if (!el) return;
  const { data, error } = await sb.from('pedidos_internos')
    .select('*').eq('tipo', 'transferencia').eq('unidade_origem', 'Estoque Central')
    .order('criado_em', { ascending: false }).limit(30);
  if (error) { el.innerHTML = '<p class="text-danger">Erro ao carregar.</p>'; return; }
  if (!data?.length) { el.innerHTML = '<p class="text-muted text-center py-4">Nenhuma solicitação recebida.</p>'; return; }
  const ids = data.map(p => p.id);
  const { data: itens } = await sb.from('pedidos_internos_itens').select('*').in('pedido_id', ids);
  const byPedido = {};
  (itens || []).forEach(it => { if (!byPedido[it.pedido_id]) byPedido[it.pedido_id] = []; byPedido[it.pedido_id].push(it); });
  el.innerHTML = data.map(p => _renderTransfCard({ ...p, _itens: byPedido[p.id] || [] }, true)).join('');
}

function _renderTransfCard(p, isSupplier) {
  const statusMap = { pendente: '🟡 Pendente', aprovado: '🟢 Enviado', entregue: '✅ Entregue', cancelado: '🔴 Cancelado' };
  const itens = (p._itens || []).map(it => {
    const nome     = it.nome || it.produto_id;
    const un       = '';
    const aprovada = it.qtd_aprovada != null ? it.qtd_aprovada : it.qtd_pedida;
    return `<tr><td>${esc(nome)}</td><td class="text-center">${it.qtd_pedida}</td><td class="text-center">${aprovada}</td><td class="text-muted small">${esc(un)}</td></tr>`;
  }).join('');

  const acoes = isSupplier && p.status === 'pendente'
    ? `<button class="btn btn-sm btn-success" onclick="aprovarTransferencia('${p.id}')">✅ Aprovar e Enviar</button>`
    : !isSupplier && p.status === 'aprovado'
    ? `<button class="btn btn-sm btn-primary" onclick="confirmarRecebimentoTransf('${p.id}')">📦 Confirmar Recebimento</button>`
    : '';

  return `<div class="card-grafico mb-3">
    <div class="d-flex justify-content-between align-items-start mb-2">
      <div>
        <span class="fw-bold">${isSupplier ? `📍 ${esc(p.local)}` : '📦 Estoque Central'}</span>
        <span class="badge bg-secondary ms-2">${statusMap[p.status] || p.status}</span>
        ${p.origem === 'automatico' ? '<span class="badge bg-info ms-1">🤖 Auto</span>' : ''}
      </div>
      <small class="text-muted">${new Date(p.criado_em || p.data).toLocaleDateString('pt-BR')}</small>
    </div>
    <table class="table table-sm mb-2">
      <thead><tr><th>Produto</th><th class="text-center">Solicitado</th><th class="text-center">Aprovado</th><th>Un.</th></tr></thead>
      <tbody>${itens}</tbody>
    </table>
    ${acoes ? `<div class="d-flex justify-content-end">${acoes}</div>` : ''}
  </div>`;
}

// ── CRIAR SOLICITAÇÃO ───────────────────────────────────────────
// Esta função pode ser chamada manualmente (pela UI) OU automaticamente
// (pela engine de ficha técnica no futuro — origem='automatico')
async function criarSolicitacaoTransf(itens, origem = 'manual') {
  const local = _invLocal || 'Centro';
  const resp  = (document.getElementById('inv-resp')?.value || '').trim();
  const { data: pedido, error } = await sb.from('pedidos_internos').insert({
    tipo: 'transferencia',
    local,
    setor: 'TRANSFERENCIA',
    unidade_origem: 'Estoque Central',
    responsavel: resp,
    status: 'pendente',
    data: new Date().toISOString().split('T')[0],
    origem,
  }).select().single();
  if (error || !pedido) { toast('Erro ao criar solicitação.', 'erro'); return null; }

  const itensBd = itens.map(it => ({
    pedido_id:    pedido.id,
    produto_id:   it.produto_id,
    qtd_pedida:   it.qtd,
    qtd_aprovada: null,
  }));
  await sb.from('pedidos_internos_itens').insert(itensBd);
  return pedido;
}

function abrirNovaTransferencia() {
  _transfItens = [];
  const inp = document.getElementById('transf-busca-prod');
  if (inp) inp.value = '';
  document.getElementById('transf-resultados-busca').innerHTML = '';
  _renderTransfItensSelecionados();
  new bootstrap.Modal(document.getElementById('modal-nova-transf')).show();
}

async function buscarProdutosTransf() {
  const q  = (document.getElementById('transf-busca-prod')?.value || '').trim();
  const el = document.getElementById('transf-resultados-busca');
  if (!q || q.length < 2) { el.innerHTML = ''; return; }
  const { data } = await sb.from('est_produtos').select('id,nome,unidade_uso').ilike('nome', `%${q}%`).limit(8);
  if (!data?.length) { el.innerHTML = '<p class="text-muted small">Nenhum produto encontrado.</p>'; return; }
  el.innerHTML = data.map(p =>
    `<button class="btn btn-sm btn-outline-secondary me-1 mb-1" onclick="adicionarItemTransf('${p.id}','${esc(p.nome)}','${esc(p.unidade_uso||'')}')">
      + ${esc(p.nome)} <span class="text-muted">(${esc(p.unidade_uso||'')})</span>
    </button>`
  ).join('');
}

function adicionarItemTransf(produto_id, nome, unidade) {
  if (_transfItens.find(i => i.produto_id === produto_id)) { toast('Produto já adicionado.', 'erro'); return; }
  _transfItens.push({ produto_id, nome, unidade, qtd: 1 });
  _renderTransfItensSelecionados();
  const inp = document.getElementById('transf-busca-prod');
  if (inp) inp.value = '';
  document.getElementById('transf-resultados-busca').innerHTML = '';
}

function _renderTransfItensSelecionados() {
  const el = document.getElementById('transf-itens-lista');
  if (!el) return;
  if (!_transfItens.length) { el.innerHTML = '<p class="text-muted small">Nenhum produto adicionado ainda.</p>'; return; }
  el.innerHTML = `<table class="table table-sm">
    <thead><tr><th>Produto</th><th>Un.</th><th style="width:120px">Qtd</th><th></th></tr></thead>
    <tbody>${_transfItens.map((it, i) => `
      <tr>
        <td>${esc(it.nome)}</td>
        <td class="text-muted small">${esc(it.unidade)}</td>
        <td><input type="number" class="form-control form-control-sm" min="0.01" step="0.01" value="${it.qtd}" onchange="_transfItens[${i}].qtd=Number(this.value)"></td>
        <td><button class="btn btn-sm btn-link text-danger p-0" onclick="_transfItens.splice(${i},1);_renderTransfItensSelecionados()">🗑</button></td>
      </tr>`).join('')}
    </tbody>
  </table>`;
}

async function enviarSolicitacaoTransf() {
  if (!_transfItens.length) { toast('Adicione ao menos um produto.', 'erro'); return; }
  const pedido = await criarSolicitacaoTransf(_transfItens, 'manual');
  if (!pedido) return;
  bootstrap.Modal.getInstance(document.getElementById('modal-nova-transf'))?.hide();
  toast('Solicitação enviada ao Estoque Central! ✅', 'ok');
  await _carregarTransfSolicitacoes(_invLocal || 'Centro');
}

// ── ATENDER (Estoque Central) ───────────────────────────────────
async function aprovarTransferencia(pedidoId) {
  const { error } = await sb.from('pedidos_internos')
    .update({ status: 'aprovado' })
    .eq('id', pedidoId);
  if (error) { toast('Erro ao aprovar.', 'erro'); return; }
  // Diminui saldo do Estoque Central ESTOQUE_LOJA
  const { data: itens } = await sb.from('pedidos_internos_itens').select('*').eq('pedido_id', pedidoId);
  for (const it of itens || []) {
    const qtd = it.qtd_aprovada ?? it.qtd_pedida;
    await _movSaldo(it.produto_id, 'ESTOQUE_LOJA', -qtd);
  }
  toast('Transferência aprovada e enviada! 📦', 'ok');
  await _carregarTransfAtender();
}

// ── CONFIRMAR RECEBIMENTO (unidade destino) ─────────────────────
async function confirmarRecebimentoTransf(pedidoId) {
  const { error } = await sb.from('pedidos_internos')
    .update({ status: 'entregue' })
    .eq('id', pedidoId);
  if (error) { toast('Erro ao confirmar.', 'erro'); return; }
  // Aumenta saldo da unidade receptora ESTOQUE_LOJA
  const { data: itens } = await sb.from('pedidos_internos_itens').select('*').eq('pedido_id', pedidoId);
  for (const it of itens || []) {
    const qtd = it.qtd_aprovada ?? it.qtd_pedida;
    await _movSaldo(it.produto_id, 'ESTOQUE_LOJA', +qtd);
  }
  toast('Recebimento confirmado! ✅', 'ok');
  await _carregarTransfSolicitacoes(_invLocal || 'Centro');
}

let _emergIdx = 0;

function _rowEmerg(idx) {
  const podeDeletar = idx > 0;
  return `<div class="d-flex gap-2 align-items-start mb-2" id="emerg-row-${idx}">
    <div class="flex-grow-1">
      <input type="text" class="form-control form-control-sm" id="emerg-busca-${idx}"
        placeholder="Buscar produto..." oninput="buscarProdutoEmerg(${idx})" autocomplete="off">
      <div id="emerg-sugest-${idx}" class="list-group mt-1" style="max-height:160px;overflow-y:auto;position:relative;z-index:10"></div>
      <input type="hidden" id="emerg-id-${idx}">
    </div>
    <div style="width:85px">
      <input type="number" class="form-control form-control-sm text-center" id="emerg-qtd-${idx}"
        min="1" step="1" placeholder="Qtd">
    </div>
    ${podeDeletar
      ? `<button type="button" class="btn btn-sm btn-outline-secondary" onclick="removerItemEmerg(${idx})"><i class="bi bi-x"></i></button>`
      : `<div style="width:31px"></div>`}
  </div>`;
}

function adicionarItemEmerg() {
  _emergIdx++;
  document.getElementById('emerg-itens').insertAdjacentHTML('beforeend', _rowEmerg(_emergIdx));
}

function removerItemEmerg(idx) {
  document.getElementById(`emerg-row-${idx}`)?.remove();
}

function abrirEmergencia() {
  _emergIdx = 0;
  const sel = document.getElementById('emerg-setor');
  if (sel && _invSetor) sel.value = _invSetor;
  document.getElementById('emerg-itens').innerHTML = _rowEmerg(0);
  document.getElementById('emerg-obs').value  = '';
  const resp = document.getElementById('inv-resp')?.value || '';
  document.getElementById('emerg-resp').value = resp;
  new bootstrap.Modal(document.getElementById('modal-emergencia')).show();
}

function buscarProdutoEmerg(idx) {
  const q  = (document.getElementById(`emerg-busca-${idx}`)?.value || '').trim().toLowerCase();
  const el = document.getElementById(`emerg-sugest-${idx}`);
  if (q.length < 2) { el.innerHTML = ''; return; }
  const hits = cProdutosFT.filter(p => p.nome.toLowerCase().includes(q)).slice(0, 10);
  el.innerHTML = hits.length
    ? hits.map(p => `<button type="button" class="list-group-item list-group-item-action py-1 small"
        onclick="selecionarProdEmerg(${idx},${JSON.stringify(p.id)},${JSON.stringify(p.nome)})">${esc(p.nome)}</button>`).join('')
    : '<div class="list-group-item text-muted small py-1">Nenhum produto encontrado.</div>';
}

function selecionarProdEmerg(idx, id, nome) {
  document.getElementById(`emerg-id-${idx}`).value    = id;
  document.getElementById(`emerg-busca-${idx}`).value = nome;
  document.getElementById(`emerg-sugest-${idx}`).innerHTML = '';
}

async function enviarEmergencia() {
  const setor = document.getElementById('emerg-setor')?.value?.trim();
  const resp  = (document.getElementById('emerg-resp')?.value || '').trim();
  const obs   = (document.getElementById('emerg-obs')?.value  || '').trim();

  if (!setor) { toast('Selecione o setor.', 'warn'); return; }

  const itens = [];
  for (const row of document.querySelectorAll('[id^="emerg-row-"]')) {
    const idx      = row.id.replace('emerg-row-', '');
    const prodNome = (document.getElementById(`emerg-busca-${idx}`)?.value || '').trim();
    const prodId   = (document.getElementById(`emerg-id-${idx}`)?.value   || '').trim();
    const qtd      = parseQtd(document.getElementById(`emerg-qtd-${idx}`)?.value);
    if (!prodNome) continue;
    if (qtd <= 0) { toast(`Informe a quantidade para "${prodNome}".`, 'warn'); return; }
    itens.push({ produto_id: prodId || null, nome: prodNome, qtd_pedida: qtd });
  }

  if (!itens.length) { toast('Adicione ao menos um produto.', 'warn'); return; }

  const numPed = await _proximoNumPedido();
  const data   = new Date().toISOString().slice(0, 10);

  const { data: ped, error: e1 } = await sb.from('pedidos_internos').insert({
    num_pedido: numPed, data,
    dia_semana: _invFeriado ? 'feriado' : _invDia,
    setor, local: _invLocal,
    tipo: 'emergencia', status: 'pendente',
    responsavel: resp, obs,
  }).select().single();

  if (e1) { toast('Erro: ' + e1.message, 'erro'); return; }

  await sb.from('pedidos_internos_itens').insert(itens.map(it => ({ ...it, pedido_id: ped.id })));

  bootstrap.Modal.getInstance(document.getElementById('modal-emergencia'))?.hide();
  toast(`${numPed} (emergência) enviado com ${itens.length} item(s)! ✅`, 'ok');
}

// ─── PINs Mobile ─────────────────────────────────────────────────
async function abrirConfigurarPins() {
  const { data } = await sb.from('inv_configuracoes').select('valor').eq('chave','pins').single();
  const pinsAtual = data?.valor || {};
  ['CHURRASQUEIRA','COZINHA','BAR','SALAO','ASG','DELIVERY','ESTOQUE'].forEach(s => {
    const el = document.getElementById(`pin-${s}`);
    if (el) el.value = pinsAtual[s] || '';
  });
  new bootstrap.Modal(document.getElementById('modal-pins')).show();
}

async function salvarPins() {
  const pins = {};
  ['CHURRASQUEIRA','COZINHA','BAR','SALAO','ASG','DELIVERY','ESTOQUE'].forEach(s => {
    const val = document.getElementById(`pin-${s}`)?.value?.trim();
    if (val) pins[s] = val;
  });
  await sb.from('inv_configuracoes').upsert({ chave: 'pins', valor: pins });
  bootstrap.Modal.getInstance(document.getElementById('modal-pins'))?.hide();
  toast('PINs salvos! ✅', 'ok');
}

// Importação de planilha para o inventário
function handleDropInvFile(e) { e.preventDefault(); const f = e.dataTransfer.files[0]; if (f) _processarArqInv(f); }
function importarProdutosInv(e) { const f = e.target.files[0]; if (f) _processarArqInv(f); }

function _processarArqInv(file) {
  const ext = file.name.split('.').pop().toLowerCase();
  const reader = new FileReader();
  reader.onload = e => {
    const wb = ext === 'csv'
      ? XLSX.read(e.target.result, { type: 'string' })
      : XLSX.read(new Uint8Array(e.target.result), { type: 'array', cellDates: true });
    _processarWbInv(wb);
  };
  if (ext === 'csv') reader.readAsText(file, 'UTF-8');
  else reader.readAsArrayBuffer(file);
}

function _processarWbInv(wb) {
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { raw: true, defval: '' });
  const msgEl = document.getElementById('msg-imp-inv');
  if (!rows.length) { if (msgEl) msgEl.innerHTML = '<div class="alert alert-warning small">Planilha vazia.</div>'; return; }

  const headers = Object.keys(rows[0]).map(h => h.toLowerCase().trim());
  const ci = (...ts) => headers.findIndex(h => ts.some(t => h.includes(t)));
  const col = {
    nome:    ci('produto','product','nome','item','descriç'),
    unidade: ci('unidade','unit','un.','und'),
    valor:   ci('valor','preço','preco','custo','unit'),
    cat:     ci('categoria','category','categ'),
  };
  if (col.nome < 0) {
    if (msgEl) msgEl.innerHTML = '<div class="alert alert-danger small">Coluna "Produto" não encontrada.</div>';
    return;
  }

  let atualizados = 0;
  rows.forEach(r => {
    const vals = Object.values(r);
    const nome = String(vals[col.nome] || '').trim();
    if (!nome) return;
    // Encontra o produto na lista carregada
    const idx = _invProdutos.findIndex(p => p.nome.toLowerCase() === nome.toLowerCase());
    if (idx < 0) return;
    const p = _invProdutos[idx];
    // Atualiza unidade e valor com os da planilha
    if (col.unidade >= 0 && vals[col.unidade]) p.unidade_uso = String(vals[col.unidade]).trim();
    if (col.valor >= 0 && vals[col.valor]) p.custo_uso = parseFloat(String(vals[col.valor]).replace(/[R$\s.]/g,'').replace(',','.')) || p.custo_uso;
    atualizados++;
  });

  document.getElementById('imp-inv-file').value = '';
  if (msgEl) {
    msgEl.innerHTML = `<div class="alert alert-success small">✅ ${atualizados} produto(s) atualizados com unidade e valor da planilha.</div>`;
    setTimeout(() => { if (msgEl) msgEl.innerHTML = ''; }, 5000);
  }
  renderInventario();
}


// ═══════════════════════════════════════════════════════════════
// PLANEJAMENTO
// ═══════════════════════════════════════════════════════════════
let _planDados    = [];   // dados importados de Excel (vazio = usa catálogo)
let _planProdutos = [];   // produtos do catálogo com médias calculadas

async function carregarPlanejamento() {
  setHoje('plan-data');
  setHoje('plan-data-entrega');

  if (!cForn.length) await carregarCaches();

  const nomeComp   = (user?.user_metadata?.nome || '').trim() || (user?.email || '').split('@')[0];
  const compEl     = document.getElementById('plan-comp');
  const compFornEl = document.getElementById('plan-comp-forn');
  if (compEl)     compEl.value     = nomeComp;
  if (compFornEl) compFornEl.value = nomeComp;

  await _popularSelectInvPlan();

  // Carrega produtos com médias (catálogo de fallback)
  const [{ data: prods }, { data: compras }] = await Promise.all([
    sb.from('est_produtos')
      .select('id,nome,tipo,categoria,unidade_uso,custo_uso,estoque_min,vendas_medias,ativo')
      .eq('ativo', true)
      .in('tipo', ['MP','SA','MC'])
      .order('categoria').order('nome'),
    sb.from('cmp_compras')
      .select('produto,quantidade,data,fornecedor_nome,categoria,tipo_produto,unidade_med')
      .gte('data', _planDataAtras(12)),
  ]);

  // Média semanal por produto (últimas 12 semanas)
  const histMap = {};
  (compras || []).forEach(c => {
    const key = (c.produto || '').trim().toUpperCase();
    if (!histMap[key]) histMap[key] = { qtd: 0, semanas: new Set(), forn: '', cat: '', tipo: '', un: '' };
    const dias = Math.floor((Date.now() - new Date(c.data).getTime()) / 86400000);
    histMap[key].semanas.add(Math.floor(dias / 7));
    histMap[key].qtd += parseFloat(c.quantidade) || 0;
    if (c.fornecedor_nome) histMap[key].forn = c.fornecedor_nome;
    if (c.categoria)       histMap[key].cat  = c.categoria;
    if (c.tipo_produto)    histMap[key].tipo = c.tipo_produto;
    if (c.unidade_med)     histMap[key].un   = c.unidade_med;
  });

  _planProdutos = (prods || []).map(p => {
    const h   = histMap[p.nome.trim().toUpperCase()] || {};
    const medHist = h.semanas?.size ? Math.round((h.qtd / h.semanas.size) * 10) / 10 : 0;
    // Usa demanda semanal salva quando disponível; cai no histórico calculado se não
    const med = parseFloat(p.vendas_medias) > 0 ? parseFloat(p.vendas_medias) : medHist;
    return {
      id: p.id, nome: p.nome, tipo: p.tipo,
      categoria: p.categoria || '', unidade: p.unidade_uso || 'UN',
      valor: p.custo_uso || 0, plano: '',
      estoque_min: parseFloat(p.estoque_min) || 0,
      est_atual: 0, coz_bar: 0, outros: 0,
      vendas_med: med,
      forn_pad:  h.forn || '', cat_pad: h.cat || p.categoria || '',
      tipo_pad:  h.tipo || '', un_pad:  h.un  || p.unidade_uso || 'UN',
    };
  });

  renderPlanejamento();
}

async function _popularSelectInvPlan() {
  const { data: invs } = await sb.from('est_inventarios')
    .select('id,num_inv,data,local,responsavel')
    .order('criado_em', { ascending: false })
    .limit(30);
  const sel = document.getElementById('inv-plan-sel');
  if (!sel) return;
  sel.innerHTML = '<option value="">— selecione —</option>' +
    (invs || []).map(inv => {
      const dataBR = (inv.data || '').split('-').reverse().join('/');
      const num    = inv.num_inv || String(inv.id).slice(0, 8);
      const label  = `${num} — ${inv.local} — ${dataBR}${inv.responsavel ? ' (' + inv.responsavel + ')' : ''}`;
      return `<option value="${inv.id}">${label}</option>`;
    }).join('');
}

async function carregarSaldoInventarioPlan() {
  const msgEl = document.getElementById('msg-inv-plan');
  const selId = document.getElementById('inv-plan-sel')?.value;
  if (!selId) {
    if (msgEl) msgEl.innerHTML = '<span class="text-warning">⚠️ Selecione uma contagem.</span>';
    return;
  }

  const { data: itens } = await sb.from('est_inventario_itens')
    .select('produto_id,nome,estoque,cozinha_bar,outros')
    .eq('inventario_id', selId);

  if (!itens?.length) {
    if (msgEl) msgEl.innerHTML = '<span class="text-danger">Contagem sem itens.</span>';
    return;
  }

  const saldoMap = {};
  itens.forEach(it => {
    if (it.produto_id) saldoMap[it.produto_id] = it;
    if (it.nome) saldoMap[(it.nome || '').toLowerCase().trim()] = it;
  });

  let atualizados = 0;
  if (_planDados.length) {
    _planDados = _planDados.map(r => {
      const s = saldoMap[r.produto_id] || saldoMap[(r.nome || '').toLowerCase().trim()];
      if (!s) return r;
      atualizados++;
      const est = parseFloat(s.estoque) || 0, cb = parseFloat(s.cozinha_bar) || 0, out = parseFloat(s.outros) || 0;
      return { ...r, estoque: est, cb, outros: out, total_inv: est + cb + out };
    });
  } else {
    _planProdutos = _planProdutos.map(p => {
      const s = saldoMap[p.id] || saldoMap[(p.nome || '').toLowerCase().trim()];
      if (!s) return p;
      atualizados++;
      return { ...p, est_atual: parseFloat(s.estoque) || 0, coz_bar: parseFloat(s.cozinha_bar) || 0, outros: parseFloat(s.outros) || 0 };
    });
  }

  const { data: invInfo } = await sb.from('est_inventarios').select('num_inv,data,local').eq('id', selId).single();
  const dataBR = (invInfo?.data || '').split('-').reverse().join('/');
  if (msgEl) msgEl.innerHTML = `<span class="text-success">✅ <strong>${invInfo?.num_inv || '—'}</strong> — ${dataBR} — <strong>${atualizados}</strong> produto(s) atualizados</span>`;
  renderPlanejamento();
}

function handleDropPlan(e) { e.preventDefault(); const f = e.dataTransfer.files[0]; if (f) _processarArqPlan(f); }
function importarPlanExcel(e) { const f = e.target.files[0]; if (f) _processarArqPlan(f); }

function _processarArqPlan(file) {
  const ext    = file.name.split('.').pop().toLowerCase();
  const reader = new FileReader();
  reader.onload = e => {
    let wb;
    if (ext === 'csv') wb = XLSX.read(e.target.result, { type: 'string' });
    else               wb = XLSX.read(new Uint8Array(e.target.result), { type: 'array', cellDates: true });
    _processarWbPlan(wb);
  };
  if (ext === 'csv') reader.readAsText(file, 'UTF-8');
  else               reader.readAsArrayBuffer(file);
}

function _processarWbPlan(wb) {
  const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { raw: true, defval: '' });
  const msgEl = document.getElementById('msg-imp-plan');
  if (!rows.length) { if (msgEl) msgEl.innerHTML = '<div class="alert alert-warning">Planilha vazia.</div>'; return; }

  const headers = Object.keys(rows[0]).map(h => h.toLowerCase().trim());
  const ci = (...ts) => { for (const t of ts) { const i = headers.findIndex(h => h.includes(t)); if (i >= 0) return i; } return -1; };

  const col = {
    nome:       ci('produto','product','nome','item','descriç'),
    vendas:     ci('dem. semanal','dem.semanal','dem_semanal','venda','médias','media','demanda','consumo','semanal'),
    estmin:     ci('mínimo','minimo','est. min','estoque min','est.min'),
    estoque:    -1,
    cb:         ci('cozinha','bar'),
    outros:     ci('outros','other'),
    total:      ci('total'),
    unidade:    ci('unidade','unit','un.','und'),
    valor:      ci('valor','preço','preco','custo','unit'),
    plano:      ci('plano','conta'),
    fornecedor: ci('fornecedor','supplier','forn'),
    categoria:  ci('categoria','category','categ'),
    tipo:       ci('tipo','destino','type'),
  };
  col.estoque = headers.findIndex(h => h.includes('estoque') && !h.includes('mín') && !h.includes('min'));

  if (col.nome < 0) {
    if (msgEl) msgEl.innerHTML = '<div class="alert alert-danger">Coluna "Produto" não encontrada.</div>';
    return;
  }

  _planDados = rows.map(r => {
    const vals = Object.values(r);
    const nome = String(vals[col.nome] || '').trim();
    if (!nome) return null;
    const est = col.estoque >= 0 ? (parseFloat(vals[col.estoque]) || 0) : 0;
    const cb  = col.cb     >= 0 ? (parseFloat(vals[col.cb])      || 0) : 0;
    const out = col.outros >= 0 ? (parseFloat(vals[col.outros])  || 0) : 0;
    const totCol = col.total >= 0 ? (parseFloat(vals[col.total]) || 0) : 0;
    const total_inv = totCol > 0 ? totCol : (est + cb + out);
    const prod = _planProdutos.find(p => p.nome.toLowerCase() === nome.toLowerCase());
    return {
      nome,
      vendas_medias:  col.vendas  >= 0 ? (parseFloat(vals[col.vendas])  || 0) : (prod?.vendas_med || 0),
      estoque_minimo: col.estmin  >= 0 ? (parseFloat(vals[col.estmin])  || 0) : (prod?.estoque_min || 0),
      estoque: est, cb, outros: out, total_inv,
      unidade:       col.unidade >= 0 ? String(vals[col.unidade] || '').trim() : (prod?.unidade || 'UN'),
      valor_unitario: col.valor  >= 0 ? (parseFloat(String(vals[col.valor]).replace(/[R$\s.]/g,'').replace(',','.')) || 0) : (prod?.valor || 0),
      plano_conta:   col.plano   >= 0 ? String(vals[col.plano]   || '').trim() : '',
      fornecedor:    (col.fornecedor >= 0 ? String(vals[col.fornecedor] || '').trim() : '') || prod?.forn_pad || '',
      categoria:     (col.categoria  >= 0 ? String(vals[col.categoria]  || '').trim() : '') || prod?.cat_pad  || '',
      tipo:          (col.tipo       >= 0 ? String(vals[col.tipo]       || '').trim() : '') || prod?.tipo_pad || '',
      produto_id:    prod?.id || null,
    };
  }).filter(Boolean);

  document.getElementById('imp-plan-file').value = '';
  if (msgEl) msgEl.innerHTML = `<div class="alert alert-success">✅ <strong>${_planDados.length}</strong> produto(s) importado(s). Clique em 🔄 Recalcular.</div>`;
  setTimeout(() => { const m = document.getElementById('msg-imp-plan'); if (m) m.innerHTML = ''; }, 5000);
  renderPlanejamento();
}

function limparDadosPlan() {
  if (!confirm('Limpar a planilha importada? A tabela voltará a usar os dados do catálogo.')) return;
  _planDados = [];
  renderPlanejamento();
}


// ─── IMPORTAR DEMANDA SEMANAL ───────────────────────────────────
function handleDropDem(e) { e.preventDefault(); const f = e.dataTransfer.files[0]; if (f) _processarDemanda(f); }
function importarDemandaSemanal(e) { const f = e.target.files[0]; if (f) _processarDemanda(f); }

async function _processarDemanda(file) {
  const msgEl = document.getElementById('msg-dem-semanal');
  msgEl.innerHTML = '<span class="text-muted">Lendo arquivo...</span>';

  try {
    const buf  = await file.arrayBuffer();
    const wb   = XLSX.read(new Uint8Array(buf), { type: 'array' });
    const ws   = wb.Sheets[wb.SheetNames[0]];

    // Planilha tem 3 linhas de cabeçalho; linha 3 (índice 2) contém "Produto" e "Dem. Semanal"
    const rows = XLSX.utils.sheet_to_json(ws, { range: 2, defval: '' });

    if (!rows.length) {
      msgEl.innerHTML = '<div class="alert alert-warning small">Planilha vazia ou formato não reconhecido.</div>';
      return;
    }

    const allKeys = Object.keys(rows[0]);
    const prodKey = allKeys.find(k => k.toLowerCase().includes('produto') || k.toLowerCase().includes('product'));
    const demKey  = allKeys.find(k => k.toLowerCase().includes('dem') || k.toLowerCase().includes('semanal'));

    if (!prodKey || !demKey) {
      msgEl.innerHTML = `<div class="alert alert-danger small">Colunas "Produto" e "Dem. Semanal" não encontradas. Detectadas: ${allKeys.slice(0, 8).join(', ')}</div>`;
      return;
    }

    const parseNum = v => {
      if (typeof v === 'number') return v;
      return parseFloat(String(v || '0').replace(/\./g, '').replace(',', '.')) || 0;
    };

    const linhas = rows
      .map(r => ({ nome: String(r[prodKey] || '').trim(), dem: parseNum(r[demKey]) }))
      .filter(r => r.nome && r.dem > 0);

    if (!linhas.length) {
      msgEl.innerHTML = '<div class="alert alert-warning small">Nenhum produto válido encontrado na planilha.</div>';
      return;
    }

    msgEl.innerHTML = `<span class="text-muted">Carregando catálogo e atualizando ${linhas.length} produtos...</span>`;
    await carregarProdutosFT(true);

    const naoEncontrados = [];
    const matched = linhas.map(u => {
      const prod = cProdutosFT.find(p => p.nome.trim().toLowerCase() === u.nome.toLowerCase());
      if (!prod) { naoEncontrados.push(u.nome); return null; }
      return { id: prod.id, vendas_medias: u.dem };
    }).filter(Boolean);

    // Atualiza em lotes de 20 chamadas paralelas
    const BATCH = 20;
    let atualizados = 0;
    for (let i = 0; i < matched.length; i += BATCH) {
      await Promise.all(
        matched.slice(i, i + BATCH).map(u =>
          sb.from('est_produtos').update({ vendas_medias: u.vendas_medias }).eq('id', u.id)
        )
      );
      atualizados += Math.min(BATCH, matched.length - i);
    }

    document.getElementById('imp-dem-file').value = '';

    let html = `<div class="alert alert-success small">✅ <strong>${atualizados}</strong> produto(s) atualizados com a Demanda Semanal.`;
    if (naoEncontrados.length) {
      html += ` <strong>${naoEncontrados.length}</strong> não encontrado(s) no cadastro: ${naoEncontrados.slice(0, 5).map(n => `<em>${n}</em>`).join(', ')}${naoEncontrados.length > 5 ? '...' : ''}.`;
    }
    html += '</div>';
    msgEl.innerHTML = html;

    // Recarrega o planejamento com os novos valores
    await carregarPlanejamento();

  } catch (err) {
    msgEl.innerHTML = `<div class="alert alert-danger small">Erro ao processar arquivo: ${err.message}</div>`;
  }
}


function _planDataAtras(n) {
  const d = new Date();
  d.setDate(d.getDate() - n * 7);
  return d.toISOString().split('T')[0];
}

function renderPlanejamento() {
  const soRepor = document.getElementById('plan-so-repor')?.checked;

  // Monta linhas da fonte ativa
  let linhas;
  if (_planDados.length) {
    linhas = _planDados.map((r, i) => {
      const comprar  = Math.round(Math.max(0, r.vendas_medias + Math.abs(r.estoque_minimo || 0) - r.total_inv));
      const totalEst = comprar * (r.valor_unitario || 0);
      return { key: `imp_${i}`, nome: r.nome, forn: r.fornecedor, cat: r.categoria, tipo: r.tipo,
               vendas: r.vendas_medias, estMin: Math.round(Math.abs(r.estoque_minimo || 0)),
               estoque: r.estoque, cb: r.cb, outros: r.outros, total_inv: r.total_inv,
               un: r.unidade, valor: r.valor_unitario, plano: r.plano_conta,
               comprar, totalEst };
    });
  } else {
    if (!_planProdutos.length) {
      document.getElementById('lst-planejamento').innerHTML =
        '<tr><td colspan="16" class="text-center text-muted py-4">Cadastre produtos ou importe uma planilha.</td></tr>';
      _planKpis([]);
      return;
    }
    linhas = _planProdutos.map(p => {
      const total_inv = p.est_atual + p.coz_bar + p.outros;
      const comprar   = Math.round(Math.max(0, p.vendas_med + p.estoque_min - total_inv));
      const totalEst  = comprar * (p.valor || 0);
      return { key: p.id, nome: p.nome, forn: p.forn_pad, cat: p.cat_pad, tipo: p.tipo_pad,
               vendas: p.vendas_med, estMin: p.estoque_min,
               estoque: p.est_atual, cb: p.coz_bar, outros: p.outros, total_inv,
               un: p.unidade, valor: p.valor, plano: p.plano || '',
               comprar, totalEst };
    });
  }

  const filtradas = soRepor ? linhas.filter(l => l.comprar > 0) : linhas;
  const fmt = v => v % 1 === 0 ? String(v) : v.toFixed(3).replace(/\.?0+$/, '');

  const buildOpts = (lista, cur, ph) => {
    const opts = ['', ...lista.map(x => typeof x === 'string' ? x : x.nome)];
    if (cur && !opts.includes(cur)) opts.push(cur);
    return opts.map(v => `<option value="${v}"${v === cur ? ' selected' : ''}>${v || ph}</option>`).join('');
  };

  document.getElementById('lst-planejamento').innerHTML = filtradas.map(l => {
    const cor    = l.comprar > 0 ? '#E71D36' : '#2EC4B6';
    const status = l.comprar > 0 ? '🚨 Repor' : '✅ OK';
    const bg     = l.comprar > 0 ? 'background:#fff5f5' : '';
    return `<tr style="${bg}">
      <td><strong>${esc(l.nome)}</strong></td>
      <td><select class="form-select form-select-sm" id="plan-forn-${l.key}" style="min-width:130px" onchange="sincFiltroFornPlan()">${buildOpts(cForn, l.forn, '— Fornecedor —')}</select></td>
      <td><select class="form-select form-select-sm" id="plan-cat-${l.key}"  style="min-width:120px">${buildOpts(cCat, l.cat, '— Categoria —')}</select></td>
      <td><select class="form-select form-select-sm" id="plan-tipo-${l.key}" style="min-width:110px">${buildOpts(cTipo, l.tipo, '— Tipo/Destino —')}</select></td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center" id="plan-vend-${l.key}"
          min="0" step="0.001" value="${l.vendas}" style="width:80px;margin:auto" oninput="recalcLinhaPlan('${l.key}')">
      </td>
      <td class="text-center text-muted">${l.estMin}</td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center" id="plan-est-${l.key}"
          min="0" step="0.001" value="${l.estoque}" style="width:75px;margin:auto" oninput="recalcLinhaPlan('${l.key}')">
      </td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center" id="plan-cb-${l.key}"
          min="0" step="0.001" value="${l.cb}" style="width:75px;margin:auto" oninput="recalcLinhaPlan('${l.key}')">
      </td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center" id="plan-out-${l.key}"
          min="0" step="0.001" value="${l.outros}" style="width:75px;margin:auto" oninput="recalcLinhaPlan('${l.key}')">
      </td>
      <td class="text-center fw-semibold" id="plan-tinv-${l.key}">${fmt(l.total_inv)}</td>
      <td class="text-center"><small>${esc(l.un)}</small></td>
      <td class="text-center fw-bold fs-6" id="plan-comprar-${l.key}" style="color:${cor}">${fmt(l.comprar)}</td>
      <td class="text-center text-muted small">${l.valor ? brl(l.valor) : '—'}</td>
      <td><small class="text-muted">${esc(l.plano || '—')}</small></td>
      <td class="text-center fw-bold" id="plan-total-${l.key}" style="color:#06D6A0">${l.totalEst > 0 ? brl(l.totalEst) : '—'}</td>
      <td class="text-center"><span class="badge" style="background:${cor}">${status}</span></td>
    </tr>`;
  }).join('') || '<tr><td colspan="16" class="text-center text-muted py-3">Nenhum item.</td></tr>';

  document.getElementById('lst-planejamento').dataset.keys = JSON.stringify(filtradas.map(l => l.key));

  // Popula filtro de fornecedor — usa cadastro completo (cForn)
  const filtFornEl = document.getElementById('plan-filtro-forn');
  const curFilt    = filtFornEl?.value || '';
  if (filtFornEl) {
    filtFornEl.innerHTML = '<option value="">— Todos os fornecedores —</option>' +
      cForn.map(f => `<option value="${esc(f.nome)}"${f.nome === curFilt ? ' selected' : ''}>${esc(f.nome)}</option>`).join('');
  }

  _planKpis(linhas);
  _planAtualizarTotal();
}

function recalcLinhaPlan(key) {
  const vendas  = parseFloat(document.getElementById(`plan-vend-${key}`)?.value) || 0;
  const estoque = parseFloat(document.getElementById(`plan-est-${key}`)?.value)  || 0;
  const cb      = parseFloat(document.getElementById(`plan-cb-${key}`)?.value)   || 0;
  const outros  = parseFloat(document.getElementById(`plan-out-${key}`)?.value)  || 0;
  const total_inv = estoque + cb + outros;
  const tInvEl  = document.getElementById(`plan-tinv-${key}`);
  const fmt     = v => v % 1 === 0 ? String(v) : v.toFixed(3).replace(/\.?0+$/, '');
  if (tInvEl) tInvEl.textContent = fmt(total_inv);

  // Descobre estMin e valor
  let estMin = 0, valor = 0;
  if (key.startsWith('imp_')) {
    const idx = parseInt(key.replace('imp_', ''));
    const r = _planDados[idx];
    if (r) {
      estMin = Math.round(Math.abs(r.estoque_minimo || 0));
      valor  = r.valor_unitario || 0;
      r.vendas_medias = vendas; r.estoque = estoque; r.cb = cb; r.outros = outros; r.total_inv = total_inv;
    }
  } else {
    const p = _planProdutos.find(x => x.id === key);
    if (p) {
      estMin = p.estoque_min; valor = p.valor || 0;
      p.est_atual = estoque; p.coz_bar = cb; p.outros = outros; p.vendas_med = vendas;
    }
  }

  const comprar = Math.round(Math.max(0, vendas + estMin - total_inv));
  const cor = comprar > 0 ? '#E71D36' : '#2EC4B6';
  const compEl = document.getElementById(`plan-comprar-${key}`);
  const totEl  = document.getElementById(`plan-total-${key}`);
  if (compEl) { compEl.textContent = fmt(comprar); compEl.style.color = cor; }
  if (totEl)  totEl.textContent = comprar > 0 ? brl(comprar * valor) : '—';
  _planAtualizarTotal();
}

function _planAtualizarTotal() {
  let total = 0;
  document.querySelectorAll('[id^="plan-total-"]').forEach(el => {
    const v = (el.textContent || '').replace(/[R$\s.]/g,'').replace(',','.');
    total += parseFloat(v) || 0;
  });
  const fmt = brl(total);
  const e1 = document.getElementById('plan-kpi-total');
  const e2 = document.getElementById('plan-rodape-total');
  if (e1) e1.textContent = fmt;
  if (e2) e2.textContent = fmt;
}

function _planKpis(linhas) {
  const e1 = document.getElementById('plan-kpi-prod');
  const e2 = document.getElementById('plan-kpi-repor');
  const e3 = document.getElementById('plan-kpi-ok');
  if (e1) e1.textContent = linhas.length;
  if (e2) e2.textContent = linhas.filter(l => l.comprar > 0).length;
  if (e3) e3.textContent = linhas.filter(l => l.comprar === 0).length;
}

function sincFiltroFornPlan() {
  const tbody  = document.getElementById('lst-planejamento');
  const keys   = JSON.parse(tbody.dataset.keys || '[]');
  const filtEl = document.getElementById('plan-filtro-forn');
  if (!filtEl) return;
  const curFilt = filtEl.value;
  const forns   = [...new Set(keys.map(k => document.getElementById(`plan-forn-${k}`)?.value || '').filter(Boolean))].sort();
  filtEl.innerHTML = '<option value="">— Todos os fornecedores —</option>' +
    forns.map(f => `<option value="${f}"${f === curFilt ? ' selected' : ''}>${esc(f)}</option>`).join('');
  const btnConf = document.getElementById('btn-confirmar-forn');
  if (btnConf) btnConf.disabled = !filtEl.value;
}

function filtrarPlanFornecedor() {
  const forn    = document.getElementById('plan-filtro-forn')?.value || '';
  const tbody   = document.getElementById('lst-planejamento');
  const keys    = JSON.parse(tbody.dataset.keys || '[]');
  const btnConf = document.getElementById('btn-confirmar-forn');

  keys.forEach(key => {
    const row     = document.getElementById(`plan-vend-${key}`)?.closest('tr');
    if (!row) return;
    const fornRow = document.getElementById(`plan-forn-${key}`)?.value || '';
    row.style.display = (!forn || fornRow === forn) ? '' : 'none';
  });
  if (btnConf) btnConf.disabled = !forn;
}

async function _gerarNumeroPedido() {
  const { data } = await sb.from('cmp_compras')
    .select('pedido_num')
    .not('pedido_num', 'is', null)
    .order('pedido_num', { ascending: false })
    .limit(1);
  const ultimo = data?.[0]?.pedido_num || '#00000';
  const num    = (parseInt(ultimo.replace(/\D/g, '')) || 0) + 1;
  return '#' + String(num).padStart(5, '0');
}

function _planLinhasDados(keys) {
  return keys.map(key => {
    const comprar   = parseInt(document.getElementById(`plan-comprar-${key}`)?.textContent) || 0;
    const forn      = document.getElementById(`plan-forn-${key}`)?.value  || '';
    const cat       = document.getElementById(`plan-cat-${key}`)?.value   || '';
    const tipo      = document.getElementById(`plan-tipo-${key}`)?.value  || '';
    let nome, unidade, valor, plano;
    if (key.startsWith('imp_')) {
      const r = _planDados[parseInt(key.replace('imp_', ''))];
      if (!r) return null;
      nome = r.nome; unidade = r.unidade; valor = r.valor_unitario; plano = r.plano_conta;
    } else {
      const p = _planProdutos.find(x => x.id === key);
      if (!p) return null;
      nome = p.nome; unidade = p.unidade; valor = p.valor || 0;
      const catObj = cCat.find(c => c.nome === cat);
      plano = catObj?.plano_conta || '';
    }
    return { key, comprar, forn, cat, tipo, nome, unidade, valor, plano };
  }).filter(Boolean);
}

async function confirmarPedidoFornecedor() {
  const forn      = document.getElementById('plan-filtro-forn')?.value || '';
  const comprador = document.getElementById('plan-comp-forn')?.value   || '';
  const dataEntr  = document.getElementById('plan-data-entrega')?.value || '';
  if (!forn)      { toast('Selecione um fornecedor no filtro.', 'erro'); return; }
  if (!comprador) { toast('Selecione um comprador.', 'erro'); return; }

  const tbody = document.getElementById('lst-planejamento');
  const keys  = JSON.parse(tbody.dataset.keys || '[]');
  const data  = document.getElementById('plan-data')?.value || new Date().toISOString().split('T')[0];

  const linhasRepor = _planLinhasDados(keys).filter(l => l.forn === forn && l.comprar > 0);
  if (!linhasRepor.length) { toast(`Nenhum produto de "${forn}" com status 🚨 Repor.`, 'erro'); return; }

  const pedido_num = await _gerarNumeroPedido();
  const registros  = linhasRepor.map(l => ({
    data, pedido_num, data_entrega: dataEntr || null,
    fornecedor_id:   cForn.find(f => f.nome === l.forn)?.id || null,
    fornecedor_nome: l.forn, produto: l.nome,
    categoria: l.cat, plano_conta: l.plano, tipo_produto: l.tipo,
    unidade_med: l.unidade || 'UN', custo_unit: l.valor || 0,
    quantidade: l.comprar, comprador,
    unidade_uso: 'Loja', observacao: 'Gerado pelo Planejamento de Compra',
    status_receb: 'pendente', criado_por: user.id,
  }));

  const { error } = await sb.from('cmp_compras').insert(registros);
  if (error) { toast('Erro ao confirmar: ' + error.message, 'erro'); return; }
  toast(`✅ Pedido ${pedido_num} gerado com ${linhasRepor.length} produto(s) de "${forn}".`, 'ok');
}

async function gerarPedidosPlanejamento() {
  const comprador = document.getElementById('plan-comp')?.value || '';
  if (!comprador) { toast('Selecione um comprador antes de gerar os pedidos.', 'erro'); return; }

  const tbody = document.getElementById('lst-planejamento');
  const keys  = JSON.parse(tbody.dataset.keys || '[]');
  const data  = document.getElementById('plan-data')?.value || new Date().toISOString().split('T')[0];

  const todasLinhas = _planLinhasDados(keys).filter(l => l.comprar > 0);
  if (!todasLinhas.length) { toast('Nenhum produto com quantidade a comprar > 0.', 'erro'); return; }

  const numPorForn = {};
  const registros  = [];
  for (const l of todasLinhas) {
    if (!numPorForn[l.forn]) numPorForn[l.forn] = await _gerarNumeroPedido();
    registros.push({
      data, pedido_num: numPorForn[l.forn],
      fornecedor_id:   cForn.find(f => f.nome === l.forn)?.id || null,
      fornecedor_nome: l.forn, produto: l.nome,
      categoria: l.cat, plano_conta: l.plano, tipo_produto: l.tipo,
      unidade_med: l.unidade || 'UN', custo_unit: l.valor || 0,
      quantidade: l.comprar, comprador,
      unidade_uso: 'Loja', observacao: 'Gerado pelo Planejamento de Compra',
      status_receb: 'pendente', criado_por: user.id,
    });
  }

  const { error } = await sb.from('cmp_compras').insert(registros);
  if (error) { toast('Erro ao gerar pedidos: ' + error.message, 'erro'); return; }
  const numForn = Object.keys(numPorForn).length;
  toast(`✅ ${registros.length} produto(s) em ${numForn} pedido(s) — um por fornecedor.`, 'ok');
}

function salvarLimparLista() {
  _planDados = [];
  _planProdutos.forEach(p => { p.est_atual = 0; p.coz_bar = 0; p.outros = 0; });
  renderPlanejamento();
  toast('Lista limpa. Use inventário ou importe planilha para carregar saldos.', 'ok');
}

function imprimirPlanejamento() {
  const data   = document.getElementById('plan-data')?.value || new Date().toISOString().split('T')[0];
  const dataBR = data.split('-').reverse().join('/');
  const tbody  = document.getElementById('lst-planejamento');
  const keys   = JSON.parse(tbody.dataset.keys || '[]');
  const total  = document.getElementById('plan-rodape-total')?.textContent || 'R$ 0,00';

  const rows = _planLinhasDados(keys).map(l => {
    const comprar = l.comprar;
    const tinv    = document.getElementById(`plan-tinv-${l.key}`)?.textContent || '0';
    const estMin  = l.key.startsWith('imp_') ? (_planDados[parseInt(l.key.replace('imp_',''))]?.estoque_minimo || 0) : (_planProdutos.find(p => p.id === l.key)?.estoque_min || 0);
    const cor     = comprar > 0 ? '#E71D36' : '#2EC4B6';
    const totalEst = brl(comprar * (l.valor || 0));
    return `<tr>
      <td>${esc(l.nome)}</td><td>${esc(l.forn||'—')}</td><td>${esc(l.cat||'—')}</td><td>${esc(l.tipo||'—')}</td>
      <td style="text-align:center">${document.getElementById(`plan-vend-${l.key}`)?.value || 0}</td>
      <td style="text-align:center">${estMin}</td>
      <td style="text-align:center">${tinv}</td>
      <td style="text-align:center;font-weight:bold;color:${cor}">${comprar}</td>
      <td style="text-align:center">${l.valor ? brl(l.valor) : '—'}</td>
      <td style="text-align:center;font-weight:bold">${comprar > 0 ? totalEst : '—'}</td>
    </tr>`;
  }).join('');

  const w = window.open('', '_blank', 'width=1300,height=750');
  w.document.write(`<!DOCTYPE html><html lang="pt-BR"><head>
  <meta charset="UTF-8"><title>Planejamento — ${dataBR}</title>
  <style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;font-size:11px;padding:1cm}
  h2{color:#FF6B35;font-size:1.2rem;margin-bottom:.3rem}p{color:#555;margin-bottom:.6rem}
  table{width:100%;border-collapse:collapse}thead tr{background:#1a1a2e;color:#fff}
  th,td{padding:4px 6px;border:1px solid #e0e0e0}tbody tr:nth-child(even){background:#fafafa}
  .tot{background:#f0fdf4;font-weight:700}@media print{body{padding:.3cm}}</style></head>
  <body>
  <h2>Tambaqui de Banda — Planejamento de Compra</h2>
  <p><strong>Semana:</strong> ${dataBR} &nbsp;|&nbsp; Fórmula: Comprar = Vendas Médias + Est. Mínimo − Total Inventário</p>
  <table><thead><tr>
    <th>Produto</th><th>Fornecedor</th><th>Categoria</th><th>Tipo</th>
    <th style="text-align:center">Dem. Semanal</th><th style="text-align:center">Est. Mín.</th>
    <th style="text-align:center">∑ Inventário</th><th style="text-align:center">Comprar</th>
    <th style="text-align:center">Valor Unit.</th><th style="text-align:center">Total Est.</th>
  </tr></thead>
  <tbody>${rows}</tbody>
  <tfoot><tr class="tot">
    <td colspan="9" style="text-align:right;padding-right:6px">TOTAL ESTIMADO</td>
    <td style="text-align:center">${total}</td>
  </tr></tfoot>
  </table>
  <script>setTimeout(()=>window.print(),400)<\/script>
  </body></html>`);
  w.document.close();
}

function imprimirItensOKPlan() {
  const tbody = document.getElementById('lst-planejamento');
  const keys  = JSON.parse(tbody.dataset.keys || '[]');
  const data  = document.getElementById('plan-data')?.value || new Date().toISOString().split('T')[0];
  const dataBR = data.split('-').reverse().join('/');

  const itensOK = keys.filter(key => {
    const comprar = parseInt(document.getElementById(`plan-comprar-${key}`)?.textContent) || 0;
    const tr = document.getElementById(`plan-vend-${key}`)?.closest('tr');
    return comprar === 0 && tr && tr.style.display !== 'none';
  });

  if (!itensOK.length) { toast('Nenhum item com status ✅ OK encontrado.', 'erro'); return; }

  const rows = itensOK.map((key, i) => {
    const tr     = document.getElementById(`plan-vend-${key}`)?.closest('tr');
    const nome   = tr?.cells[0]?.querySelector('strong')?.textContent?.trim() || '—';
    const forn   = document.getElementById(`plan-forn-${key}`)?.value || '—';
    const cat    = document.getElementById(`plan-cat-${key}`)?.value  || '—';
    const tinv   = document.getElementById(`plan-tinv-${key}`)?.textContent || '0';
    const estMin = key.startsWith('imp_') ? (_planDados[parseInt(key.replace('imp_',''))]?.estoque_minimo||0) : (_planProdutos.find(p=>p.id===key)?.estoque_min||0);
    const un     = tr?.cells[10]?.textContent?.trim() || '';
    return `<tr>
      <td>${i+1}</td><td><strong>${esc(nome)}</strong></td><td>${esc(forn)}</td><td>${esc(cat)}</td>
      <td style="text-align:center">${estMin}</td>
      <td style="text-align:center">${tinv}</td>
      <td style="text-align:center">${un}</td>
      <td style="text-align:center;color:#2EC4B6;font-weight:700">✅ OK</td>
    </tr>`;
  }).join('');

  const w = window.open('', '_blank', 'width=1000,height=700');
  w.document.write(`<!DOCTYPE html><html lang="pt-BR"><head>
  <meta charset="UTF-8"><title>Itens OK — ${dataBR}</title>
  <style>*{box-sizing:border-box;margin:0;padding:0}
  body{font-family:'Segoe UI',Arial,sans-serif;font-size:12px;padding:1.5cm}
  h2{color:#2EC4B6;font-size:1.2rem;margin-bottom:.3rem}p{color:#555;margin-bottom:.8rem;font-size:.85rem}
  table{width:100%;border-collapse:collapse}thead tr{background:#1a1a2e;color:#fff}
  th,td{padding:5px 8px;border:1px solid #e0e0e0}tbody tr:nth-child(even){background:#f9fffe}
  @media print{body{padding:.5cm}}</style></head>
  <body>
  <h2>✅ Tambaqui de Banda — Itens com Estoque OK</h2>
  <p><strong>Data:</strong> ${dataBR} &nbsp;|&nbsp; <strong>Itens:</strong> ${itensOK.length} produto(s) sem necessidade de reposição</p>
  <table><thead><tr>
    <th>#</th><th>Produto</th><th>Fornecedor</th><th>Categoria</th>
    <th style="text-align:center">Est. Mín.</th>
    <th style="text-align:center">∑ Inventário</th>
    <th style="text-align:center">Unidade</th>
    <th style="text-align:center">Status</th>
  </tr></thead>
  <tbody>${rows}</tbody>
  </table>
  <script>setTimeout(()=>window.print(),400)<\/script>
  </body></html>`);
  w.document.close();
}


// ═══════════════════════════════════════════════════════════════
// RECEBIMENTOS
// ═══════════════════════════════════════════════════════════════
let _recebItensAbertos = [];  // itens do pedido aberto no modal

function abaReceb(aba, el) {
  document.querySelectorAll('#tabs-receb .nav-link').forEach(a => a.classList.remove('active'));
  if (el) el.classList.add('active');
  document.getElementById('receb-pendentes').style.display   = aba === 'pendentes'   ? '' : 'none';
  document.getElementById('receb-historico').style.display   = aba === 'historico'   ? '' : 'none';
  document.getElementById('receb-contaspagar').style.display = aba === 'contaspagar' ? '' : 'none';
  if (aba === 'pendentes')   renderPendentes();
  if (aba === 'historico')   renderHistReceb();
  if (aba === 'contaspagar') renderContasPagar();
}

async function renderPendentes() {
  const ini     = document.getElementById('receb-ini')?.value || '';
  const fim     = document.getElementById('receb-fim')?.value || '';
  const fornSel = document.getElementById('receb-forn')?.value || '';

  let query = sb.from('cmp_compras')
    .select('id,pedido_num,data,data_entrega,fornecedor_id,fornecedor_nome,comprador,produto,categoria,plano_conta,tipo_produto,unidade_med,quantidade,custo_unit,status_receb,unidade_uso,acrescimo,setor,forma_pagamento')
    .not('pedido_num', 'is', null)
    .neq('status_receb', 'recebido')
    .order('data', { ascending: false });

  if (ini) query = query.gte('data', ini);
  if (fim) query = query.lte('data', fim);

  const { data: compras } = await query;

  // Agrupa por pedido_num
  const grupos = {};
  (compras || []).forEach(c => {
    const key = c.pedido_num;
    if (!grupos[key]) grupos[key] = {
      pedido_num: key, data: c.data, forn: c.fornecedor_nome,
      fornecedor_id: c.fornecedor_id, plano_conta: c.plano_conta,
      comp: c.comprador, setor: c.setor || '',
      forma_pagamento: c.forma_pagamento || '', itens: [], total: 0,
      acrescimo: parseFloat(c.acrescimo) || 0,
    };
    grupos[key].itens.push(c);
    grupos[key].total += (c.quantidade || 0) * (c.custo_unit || 0);
  });

  // Inclui acréscimo no total de cada grupo
  Object.values(grupos).forEach(g => { g.total += g.acrescimo; });

  let lista = Object.values(grupos).sort((a,b) => b.pedido_num.localeCompare(a.pedido_num));

  // Salva grupos para o modal de financeiro
  _pedidosGrupos = {};
  lista.forEach(g => { _pedidosGrupos[g.pedido_num] = g; });

  // Popula filtro de fornecedor
  const fornEl = document.getElementById('receb-forn');
  if (fornEl) {
    const forns = [...new Set(lista.map(g => g.forn).filter(Boolean))].sort();
    const cur = fornEl.value;
    fornEl.innerHTML = '<option value="">Todos os fornecedores</option>' +
      forns.map(f => `<option value="${f}"${f === cur ? ' selected' : ''}>${esc(f)}</option>`).join('');
  }

  if (fornSel) lista = lista.filter(g => g.forn === fornSel);

  const tbody = document.getElementById('tb-receb-pendentes');
  if (!lista.length) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted py-3">Nenhum pedido pendente de recebimento.</td></tr>';
    return;
  }

  // Verifica estado de integração de cada pedido consultando as fontes diretas
  const numeros = lista.map(g => g.pedido_num);
  const [resLancamentos, resRascunhos] = await Promise.all([
    // Consulta lancamentos do financeiro diretamente — mais confiável que cmp_contas_pagar.lancamento_id
    sb.from('lancamentos').select('numero_pedido').in('numero_pedido', numeros),
    sb.from('lancamentos_rascunho').select('pedido_num').in('pedido_num', numeros),
  ]);
  const lancamentosSet = new Set();
  const rascunhoSet    = new Set();
  (resLancamentos.data || []).forEach(l => lancamentosSet.add(l.numero_pedido));
  (resRascunhos.data   || []).forEach(r => rascunhoSet.add(r.pedido_num));

  tbody.innerHTML = lista.map(g => {
    const jaEnviado   = lancamentosSet.has(g.pedido_num);
    const temRascunho = rascunhoSet.has(g.pedido_num);
    const badgeFin = jaEnviado
      ? `<span class="badge bg-success">✅ Enviado</span>`
      : temRascunho
      ? `<span class="badge bg-warning text-dark">⏳ Aguardando</span>`
      : `<span class="badge bg-light text-muted border">Não enviado</span>`;
    return `
    <tr>
      <td><span class="badge" style="background:#FF6B35">${esc(g.pedido_num)}</span></td>
      <td>${(g.data||'').split('-').reverse().join('/')}</td>
      <td>
        <strong>${esc(g.forn||'—')}</strong>
        ${g.setor ? `<br><span class="badge" style="background:#6f42c1;font-size:.7rem">${esc(g.setor)}</span>` : ''}
      </td>
      <td>${esc(g.comp||'—')}</td>
      <td class="text-center"><span class="badge bg-secondary">${g.itens.length} item(s)</span></td>
      <td class="text-center"><strong>${brl(g.total)}</strong></td>
      <td class="text-center">${badgeFin}</td>
      <td class="text-center">
        <button class="btn btn-sm btn-success py-0 px-2" onclick="abrirModalReceber('${esc(g.pedido_num)}')">
          📬 Receber
        </button>
      </td>
      <td class="text-center">
        ${jaEnviado
          ? `<button class="btn btn-sm btn-outline-secondary py-0 px-2" disabled
               title="Pedido enviado ao financeiro — exclua o lançamento lá primeiro">
               🔒 Excluir
             </button>`
          : `<button class="btn btn-sm btn-outline-danger py-0 px-2" onclick="excluirPedidoReceb('${esc(g.pedido_num)}')">
               🗑️ Excluir
             </button>`
        }
      </td>
    </tr>`;
  }).join('');
}

async function excluirPedidoReceb(pedido_num) {
  // Verificação de segurança: bloqueia se já existe lançamento no financeiro
  const { data: lanc } = await sb.from('lancamentos').select('id').eq('numero_pedido', pedido_num).maybeSingle();
  if (lanc) {
    toast('Pedido já enviado ao financeiro — exclua o lançamento lá primeiro.', 'erro');
    return;
  }
  if (!confirm(`Excluir o pedido ${pedido_num}? Esta ação não pode ser desfeita.`)) return;
  await Promise.all([
    sb.from('cmp_compras').delete().eq('pedido_num', pedido_num),
    sb.from('lancamentos_rascunho').delete().eq('pedido_num', pedido_num),
    sb.from('cmp_contas_pagar').delete().eq('pedido_num', pedido_num),
  ]);
  toast('Pedido excluído.', 'ok');
  renderPendentes();
}

async function abrirModalReceber(pedido_num) {
  const { data: itens } = await sb.from('cmp_compras')
    .select('id,produto,categoria,plano_conta,unidade_med,quantidade,custo_unit,fornecedor_id,fornecedor_nome,comprador,acrescimo,unidade_uso')
    .eq('pedido_num', pedido_num)
    .or('status_receb.neq.recebido,status_receb.is.null');

  if (!itens?.length) { toast('Itens não encontrados.', 'erro'); return; }
  _recebItensAbertos = itens;

  document.getElementById('receb-pedido-num-hidden').value = pedido_num;
  document.getElementById('receb-ped-num').textContent     = pedido_num;
  document.getElementById('receb-data-rec').value          = new Date().toISOString().split('T')[0];
  document.getElementById('receb-vencimento').value        = '';
  document.getElementById('receb-responsavel').value       = '';
  document.getElementById('receb-nf').value                = '';
  setMoeda('receb-acrescimo', parseFloat(itens[0]?.acrescimo) || 0);
  document.getElementById('alerta-diverg').style.display   = 'none';

  document.getElementById('tb-receber-itens').innerHTML = itens.map(x => `
    <tr id="row-rec-${x.id}">
      <td><strong>${esc(x.produto)}</strong></td>
      <td><small class="text-muted">${esc(x.categoria||'—')}</small></td>
      <td class="text-center">${(x.quantidade||0).toLocaleString('pt-BR',{maximumFractionDigits:3})} ${esc(x.unidade_med||'')}</td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center" style="width:90px;margin:auto"
          id="qtd-rec-${x.id}" value="${x.quantidade||0}" min="0" step="any"
          oninput="recalcReceb('${x.id}',${x.quantidade||0})">
      </td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-end" style="width:100px;margin:auto"
          id="vlr-rec-${x.id}" value="${x.custo_unit||0}" min="0" step="any"
          oninput="recalcReceb('${x.id}',${x.quantidade||0})">
      </td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-end" style="width:90px;margin:auto"
          id="dsc-rec-${x.id}" value="0" min="0" step="any" placeholder="0,00"
          oninput="recalcReceb('${x.id}',${x.quantidade||0})">
      </td>
      <td class="text-center fw-bold" id="tot-rec-${x.id}">${brl((x.quantidade||0)*(x.custo_unit||0))}</td>
      <td class="text-center">
        <button type="button" class="btn-check-receber" id="inc-rec-${x.id}"
          onclick="togIncluirReceb('${x.id}')">✓</button>
      </td>
      <td class="text-center">
        <div class="form-check form-switch d-flex justify-content-center">
          <input class="form-check-input" type="checkbox" id="div-rec-${x.id}" onchange="marcarDiverg('${x.id}')">
        </div>
      </td>
      <td><input type="text" class="form-control form-control-sm" id="obs-rec-${x.id}"
        placeholder="Observação..." style="display:none"></td>
    </tr>`).join('');

  calcTotalReceb();
  new bootstrap.Modal(document.getElementById('modal-receber')).show();
}

function togIncluirReceb(id) {
  const btn = document.getElementById(`inc-rec-${id}`);
  btn.classList.toggle('checked');
  calcTotalReceb();
}

function recalcReceb(id, qtdPedida) {
  const qtdRec  = parseFloat(document.getElementById(`qtd-rec-${id}`)?.value) || 0;
  const vlr     = parseFloat(document.getElementById(`vlr-rec-${id}`)?.value) || 0;
  const desconto = parseFloat(document.getElementById(`dsc-rec-${id}`)?.value) || 0;
  const total   = Math.max(0, qtdRec * vlr - desconto);
  const totEl   = document.getElementById(`tot-rec-${id}`);
  if (totEl) totEl.textContent = brl(total);
  const divEl = document.getElementById(`div-rec-${id}`);
  if (divEl && Math.abs(qtdRec - qtdPedida) > 0.001) { divEl.checked = true; marcarDiverg(id); }
  calcTotalReceb();
}

function marcarDiverg(id) {
  const checked = document.getElementById(`div-rec-${id}`)?.checked;
  const obsEl   = document.getElementById(`obs-rec-${id}`);
  const row     = document.getElementById(`row-rec-${id}`);
  if (obsEl) obsEl.style.display = checked ? '' : 'none';
  if (row)   row.style.background = checked ? '#fff8f0' : '';
  const temDiv = document.querySelectorAll('[id^="div-rec-"]:checked').length > 0;
  document.getElementById('alerta-diverg').style.display = temDiv ? '' : 'none';
}

function calcTotalReceb() {
  let total = 0;
  document.querySelectorAll('[id^="qtd-rec-"]').forEach(el => {
    const id  = el.id.replace('qtd-rec-', '');
    const inc = document.getElementById(`inc-rec-${id}`);
    if (!inc?.classList.contains('checked')) return;
    const txt = (document.getElementById(`tot-rec-${id}`)?.textContent || '0').replace(/[R$\s.]/g,'').replace(',','.');
    total += parseFloat(txt) || 0;
  });
  const acrescimo = parseMoeda('receb-acrescimo');
  const el = document.getElementById('receb-total-modal');
  if (el) el.textContent = brl(total + acrescimo);
}

async function confirmarRecebimento() {
  const pedido_num  = document.getElementById('receb-pedido-num-hidden').value;
  const dataRec     = document.getElementById('receb-data-rec').value;
  const responsavel = (document.getElementById('receb-responsavel').value || '').trim();
  const vencimento  = document.getElementById('receb-vencimento').value;
  if (!dataRec)     { toast('Informe a data do recebimento.', 'erro'); return; }
  if (!responsavel) { toast('Informe o responsável.', 'erro'); return; }
  if (!vencimento)  { toast('Informe a data de vencimento.', 'erro'); return; }

  const acrescimo     = parseMoeda('receb-acrescimo');

  // Alerta se acréscimo = 0 (possível esquecimento)
  if (acrescimo === 0) {
    const ok = confirm('⚠️ O campo Acréscimo está zerado.\n\nSe a NF tem frete ou taxa, cancele e preencha o valor antes de confirmar.\n\nDeseja continuar sem acréscimo?');
    if (!ok) return;
  }

  // Apenas itens marcados para receber agora
  const incluidos = _recebItensAbertos.filter(x => document.getElementById(`inc-rec-${x.id}`)?.classList.contains('checked'));
  if (!incluidos.length) { toast('Selecione ao menos um item para receber.', 'erro'); return; }

  const ref = incluidos[0];
  const itensReceb = incluidos.map(x => {
    const qtdRec   = parseFloat(document.getElementById(`qtd-rec-${x.id}`)?.value) || 0;
    const vlr      = parseFloat(document.getElementById(`vlr-rec-${x.id}`)?.value) || x.custo_unit || 0;
    const desconto = parseFloat(document.getElementById(`dsc-rec-${x.id}`)?.value) || 0;
    const totalItem = Math.max(0, qtdRec * vlr - desconto);
    // valor_unitario efetivo = total_com_desconto / qtd (para custo por unidade correto)
    const vlrEfetivo = qtdRec > 0 ? totalItem / qtdRec : vlr;
    const diverg = document.getElementById(`div-rec-${x.id}`)?.checked || false;
    const obs    = document.getElementById(`obs-rec-${x.id}`)?.value || '';
    return {
      compra_id: x.id, produto: x.produto, categoria: x.categoria || '',
      unidade: x.unidade_med || '', qtd_pedida: x.quantidade || 0,
      qtd_recebida: qtdRec, valor_unitario: vlrEfetivo,
      total_recebido: totalItem,
      divergencia: diverg, obs_divergencia: obs,
    };
  });

  const totalItens    = itensReceb.reduce((s, i) => s + i.total_recebido, 0);
  const totalRecebido = totalItens + acrescimo;
  const temDiverg     = itensReceb.some(i => i.divergencia);

  // Guard: impede receber pedido já finalizado no financeiro
  const { data: _guardConta } = await sb.from('cmp_contas_pagar')
    .select('lancamento_id').eq('pedido_num', pedido_num).maybeSingle();
  if (_guardConta?.lancamento_id) {
    toast('Este pedido já foi enviado ao financeiro e não pode ser recebido novamente.', 'erro');
    return;
  }

  // Salva recebimento cabeçalho
  const { data: receb, error: errReceb } = await sb.from('cmp_recebimentos').insert([{
    pedido_num, data_receb: dataRec, responsavel,
    fornecedor: ref?.fornecedor_nome || '', comprador: ref?.comprador || '',
    total_recebido: totalRecebido,
    status: temDiverg ? 'parcial' : 'confirmado',
  }]).select().single();
  if (errReceb) { toast('Erro ao salvar recebimento: ' + errReceb.message, 'erro'); return; }

  // Salva itens
  await sb.from('cmp_recebimento_itens').insert(itensReceb.map(it => ({ ...it, recebimento_id: receb.id })));

  // Resolve nf, unidade_id e modalidade antes de ambos os flows
  const nf = document.getElementById('receb-nf')?.value?.trim() || null;
  if (!cUnidades.length) await carregarCaches();
  const uniNome = ref?.unidade_uso || '';
  const unidade_id = cUnidades.find(u => u.nome.toLowerCase() === uniNome.toLowerCase())?.id || null;
  const isCompExt = isCompExterna(ref?.fornecedor_nome);

  // Verifica se já foi gerada conta no financeiro (Flow A)
  const { data: contaExist } = await sb.from('cmp_contas_pagar')
    .select('id,lancamento_id,adiantamento_lancamento_id').eq('pedido_num', pedido_num).maybeSingle();

  // Todos os fornecedores: acumula total de todos os recebimentos, não envia ao financeiro ainda
  const { data: todosReceb } = await sb.from('cmp_recebimentos')
    .select('total_recebido').eq('pedido_num', pedido_num);
  const totalAcumulado = (todosReceb || []).reduce((s, r) => s + (r.total_recebido || 0), 0);

  if (contaExist) {
    await sb.from('cmp_contas_pagar').update({
      recebimento_id: receb.id, data_receb: dataRec, vencimento, valor: totalAcumulado,
    }).eq('id', contaExist.id);
  } else {
    await sb.from('cmp_contas_pagar').insert([{
      pedido_num, recebimento_id: receb.id,
      fornecedor: ref?.fornecedor_nome || '',
      data_receb: dataRec, vencimento, valor: totalAcumulado, status: 'pendente',
    }]);
  }

  // Marca cada item: se qtd completa → recebido; se parcial → atualiza quantidade restante
  // Sempre atualiza custo_unit com o valor efetivamente recebido
  for (const ir of itensReceb) {
    const restante = (ir.qtd_pedida || 0) - (ir.qtd_recebida || 0);
    if (restante <= 0.001) {
      await sb.from('cmp_compras').update({ status_receb: 'recebido', custo_unit: ir.valor_unitario }).eq('id', ir.compra_id);
    } else {
      await sb.from('cmp_compras').update({ quantidade: Math.max(restante, 0), status_receb: 'pendente', custo_unit: ir.valor_unitario }).eq('id', ir.compra_id);
    }
  }
  // Persiste acréscimo atualizado
  if (acrescimo !== (parseFloat(_recebItensAbertos[0]?.acrescimo) || 0)) {
    await sb.from('cmp_compras').update({ acrescimo }).eq('pedido_num', pedido_num);
  }

  // Todos os fornecedores: auto-finaliza quando todos os itens foram recebidos
  const { data: restantes } = await sb.from('cmp_compras')
    .select('id').eq('pedido_num', pedido_num)
    .not('status_receb', 'in', '("recebido","dispensado","cancelado")');
  if (!restantes?.length) {
    const { data: contaFinal } = await sb.from('cmp_contas_pagar')
      .select('id,adiantamento_lancamento_id,lancamento_id,vencimento').eq('pedido_num', pedido_num).maybeSingle();
    if (contaFinal && !contaFinal.lancamento_id) {
      if (isCompExt) {
        await _executarFinalizarCompExt(pedido_num, contaFinal, ref, unidade_id, nf);
      } else {
        await _executarFinalizarRegular(pedido_num, contaFinal, ref, unidade_id, nf);
      }
      toast(`✅ Pedido ${pedido_num} finalizado e enviado ao financeiro!`, 'ok');
    }
  }

  // Aumentar saldo ESTOQUE_LOJA para cada item recebido com produto cadastrado
  if (!cProdutosFT.length) await carregarProdutosFT();
  await Promise.all(itensReceb.map(async it => {
    if (!it.qtd_recebida) return;
    const prod = cProdutosFT.find(p => norm(p.nome.trim()) === norm((it.produto || '').trim()));
    if (!prod) return;
    await _movSaldo(prod.id, 'ESTOQUE_LOJA', +it.qtd_recebida);
  }));

  bootstrap.Modal.getInstance(document.getElementById('modal-receber')).hide();
  toast(`✅ Recebimento confirmado! ${brl(totalRecebido)} — Venc. ${vencimento.split('-').reverse().join('/')}${temDiverg ? ' ⚠️ Com divergências.' : ''}`, 'ok');
  renderPendentes();
}

async function renderHistReceb() {
  const { data: lista } = await sb.from('cmp_recebimentos')
    .select('id,pedido_num,data_receb,responsavel,fornecedor,status,total_recebido')
    .order('criado_em', { ascending: false });

  const tbody = document.getElementById('tb-receb-hist');
  if (!lista?.length) {
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">Nenhum recebimento registrado.</td></tr>';
    return;
  }
  tbody.innerHTML = lista.map(r => {
    const cor    = r.status === 'confirmado' ? '#2EC4B6' : '#FF6B35';
    const label  = r.status === 'confirmado' ? '✅ Confirmado' : '⚠️ Divergência';
    const dataBR = (r.data_receb||'').split('-').reverse().join('/');
    return `<tr>
      <td><span class="badge bg-secondary">R</span></td>
      <td><span class="badge" style="background:#FF6B35">${esc(r.pedido_num)}</span></td>
      <td>${dataBR}</td>
      <td>${esc(r.fornecedor||'—')}</td>
      <td>${esc(r.responsavel||'—')}</td>
      <td class="text-center"><span class="badge" style="background:${cor}">${label}</span></td>
      <td class="text-center fw-bold">${brl(r.total_recebido)}</td>
      <td class="text-center">
        <button class="btn btn-sm btn-outline-secondary py-0 px-2" onclick="verDetalheReceb('${r.id}')">🔍 Ver</button>
      </td>
    </tr>`;
  }).join('');
}

async function verDetalheReceb(id) {
  const { data: r } = await sb.from('cmp_recebimentos').select('*').eq('id', id).single();
  const { data: itens } = await sb.from('cmp_recebimento_itens').select('*').eq('recebimento_id', id);
  if (!r) return;

  const dataBR = (r.data_receb||'').split('-').reverse().join('/');
  const linhas = (itens||[]).map((it, i) => `
    <tr style="${it.divergencia ? 'background:#fff8f0' : ''}">
      <td>${i+1}</td>
      <td><strong>${esc(it.produto)}</strong></td>
      <td class="text-center">${it.qtd_pedida} ${esc(it.unidade||'')}</td>
      <td class="text-center ${it.qtd_recebida !== it.qtd_pedida ? 'text-danger fw-bold' : ''}">${it.qtd_recebida} ${esc(it.unidade||'')}</td>
      <td class="text-center">${brl(it.total_recebido)}</td>
      <td class="text-center">${it.divergencia ? '<span class="badge bg-warning text-dark">⚠️ Divergência</span>' : '<span class="badge bg-success">✅ OK</span>'}</td>
      <td>${esc(it.obs_divergencia||'—')}</td>
    </tr>`).join('');

  document.getElementById('detalhe-receb-body').innerHTML = `
    <div class="mb-3 p-3 rounded" style="background:#f8f9fa">
      <div class="row g-2">
        <div class="col-md-3"><small class="text-muted d-block">Pedido</small><strong>${esc(r.pedido_num)}</strong></div>
        <div class="col-md-3"><small class="text-muted d-block">Data</small>${dataBR}</div>
        <div class="col-md-3"><small class="text-muted d-block">Fornecedor</small>${esc(r.fornecedor||'—')}</div>
        <div class="col-md-3"><small class="text-muted d-block">Responsável</small>${esc(r.responsavel||'—')}</div>
      </div>
    </div>
    <div class="table-responsive">
      <table class="table table-sm">
        <thead style="background:#1a1a2e;color:#fff;font-size:.8rem">
          <tr><th>#</th><th>Produto</th><th class="text-center">Qtd Pedida</th><th class="text-center">Qtd Recebida</th><th class="text-center">Total</th><th class="text-center">Status</th><th>Obs.</th></tr>
        </thead>
        <tbody>${linhas}</tbody>
        <tfoot><tr style="background:#f0fdf4">
          <td colspan="4" class="text-end fw-bold">TOTAL RECEBIDO</td>
          <td class="text-center fw-bold text-success">${brl(r.total_recebido)}</td>
          <td colspan="2"></td>
        </tr></tfoot>
      </table>
    </div>`;
  new bootstrap.Modal(document.getElementById('modal-detalhe-receb')).show();
}

async function renderContasPagar() {
  const { data: contas } = await sb.from('cmp_contas_pagar')
    .select('id,pedido_num,fornecedor,data_receb,vencimento,valor,status,data_pagamento')
    .order('criado_em', { ascending: false });

  const lista = contas || [];
  const pendente = lista.filter(c => c.status === 'pendente').reduce((s,c) => s + (c.valor||0), 0);
  const pago     = lista.filter(c => c.status === 'pago').reduce((s,c) => s + (c.valor||0), 0);
  const e1 = document.getElementById('cp-kpi-pend');
  const e2 = document.getElementById('cp-kpi-pago');
  if (e1) e1.textContent = brl(pendente);
  if (e2) e2.textContent = brl(pago);

  const tbody = document.getElementById('tb-contas-pagar');
  if (!lista.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted py-3">Nenhuma conta a pagar.</td></tr>';
    return;
  }
  const hoje_ = new Date().toISOString().slice(0,10);
  tbody.innerHTML = lista.map(c => {
    const vencBR   = (c.vencimento||'').split('-').reverse().join('/');
    const recBR    = (c.data_receb||'').split('-').reverse().join('/');
    const vencido  = c.status === 'pendente' && c.vencimento && c.vencimento < hoje_;
    const corBadge = c.status === 'pago' ? '#2EC4B6' : vencido ? '#dc3545' : '#FF6B35';
    const label    = c.status === 'pago' ? '✅ Pago' : vencido ? '🔴 Vencido' : '⏳ Pendente';
    return `<tr>
      <td><span class="badge" style="background:#FF6B35">${esc(c.pedido_num||'—')}</span></td>
      <td>${esc(c.fornecedor||'—')}</td>
      <td>${recBR}</td>
      <td>${vencBR}</td>
      <td class="text-center fw-bold">${brl(c.valor)}</td>
      <td class="text-center"><span class="badge" style="background:${corBadge}">${label}</span></td>
      <td class="text-center">
        ${c.status === 'pendente'
          ? `<button class="btn btn-sm btn-success py-0 px-2" onclick="marcarPago('${c.id}')">✅ Marcar Pago</button>`
          : `<small class="text-muted">${(c.data_pagamento||'').split('-').reverse().join('/')}</small>`}
      </td>
    </tr>`;
  }).join('');
}

async function marcarPago(id) {
  if (!confirm('Confirmar pagamento desta conta?')) return;
  const hoje_ = new Date().toISOString().split('T')[0];
  await sb.from('cmp_contas_pagar').update({ status: 'pago', data_pagamento: hoje_ }).eq('id', id);
  toast('Pagamento registrado.', 'ok');
  renderContasPagar();
}


// ═══════════════════════════════════════════════════════════════
// CONTROLE CMV — IMPORTAÇÃO HISTÓRICA
// ═══════════════════════════════════════════════════════════════
let _histDados  = [];
let _histPend   = null;
let chHistMens  = null;
let chHistCMV   = null;
let chHistTipo  = null;

const MESES_PT = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
const _labelMes = m => { const [y,mo] = m.split('-'); return `${MESES_PT[parseInt(mo)-1]}/${y.slice(2)}`; };
const _mes      = d => d ? d.slice(0,7) : '';
const META_CMV  = 27;

function _grpBy(arr, keyFn, valField) {
  const out = {};
  arr.forEach(r => {
    const k = typeof keyFn === 'function' ? keyFn(r) : r[keyFn];
    if (!k) return;
    out[k] = (out[k] || 0) + (parseFloat(r[valField]) || 0);
  });
  return out;
}

function _normalizarData(val) {
  if (!val) return '';
  if (typeof val === 'number') {
    const d = new Date(Math.round((val - 25569) * 86400 * 1000));
    return d.toISOString().split('T')[0];
  }
  const s = String(val).trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0,10);
  const m = s.match(/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})/);
  if (m) {
    const y = m[3].length === 2 ? '20' + m[3] : m[3];
    return `${y}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;
  }
  return '';
}

function _parseBRLStr(v) {
  if (typeof v === 'number') return v;
  return parseFloat(String(v).replace(/[R$\s.]/g,'').replace(',','.')) || 0;
}

function handleDropHistCMV(e) { e.preventDefault(); const f = e.dataTransfer.files[0]; if (f) _processarArqHist(f); }
function importarHistoricoFile(e) { const f = e.target.files[0]; if (f) _processarArqHist(f); }

function _processarArqHist(file) {
  const ext = file.name.split('.').pop().toLowerCase();
  const reader = new FileReader();
  reader.onload = e => {
    const wb = ext === 'csv'
      ? XLSX.read(e.target.result, { type: 'string' })
      : XLSX.read(new Uint8Array(e.target.result), { type: 'array', cellDates: true });
    _processarWbHist(wb);
  };
  if (ext === 'csv') reader.readAsText(file, 'UTF-8');
  else reader.readAsArrayBuffer(file);
}

function _processarWbHist(wb) {
  const ws   = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: true });
  if (rows.length < 2) { toast('Planilha vazia.', 'erro'); return; }

  const headers = rows[0].map(h => String(h).toLowerCase().trim());
  const enc = (...ts) => headers.findIndex(h => ts.some(t => h.includes(t)));

  const col = {
    fornecedor: enc('fornecedor','supplier'),
    categoria:  enc('categoria','category'),
    tipo:       enc('tipo','type'),
    data: (() => {
      const i = headers.findIndex(h => h.includes('data') && (h.includes('compra') || h.includes('pedido') || h.includes('lanc')));
      return i >= 0 ? i : enc('data compra','data_compra','data');
    })(),
    vencimento: enc('vencimento','venc'),
    unidade:    enc('unidade','unit'),
    valor:      enc('valor','total','preco','preço','r$'),
  };

  if (col.data < 0 || col.valor < 0) {
    toast('Não encontrei colunas "Data Compra" e "Valor". Verifique os cabeçalhos.', 'erro');
    return;
  }

  const registros = [];
  for (let i = 1; i < rows.length; i++) {
    const r = rows[i];
    if (!r[col.data] && !r[col.valor]) continue;
    const data  = _normalizarData(r[col.data]);
    const valor = _parseBRLStr(r[col.valor]);
    if (!data || valor <= 0) continue;
    registros.push({
      fornecedor:      col.fornecedor >= 0 ? String(r[col.fornecedor]||'').trim() : '—',
      categoria:       col.categoria  >= 0 ? String(r[col.categoria] ||'').trim() : '',
      tipo:            col.tipo       >= 0 ? String(r[col.tipo]      ||'').trim() : '',
      data_compra:     data,
      data_vencimento: col.vencimento >= 0 ? _normalizarData(r[col.vencimento]) : '',
      unidade:         col.unidade    >= 0 ? String(r[col.unidade]   ||'').trim() : '',
      valor,
    });
  }

  if (!registros.length) { toast('Nenhum registro válido encontrado.', 'erro'); return; }

  document.getElementById('hist-import-count').textContent = `${registros.length} registro(s)`;
  document.getElementById('hist-preview-body').innerHTML =
    registros.slice(0,10).map(r => `<tr>
      <td>${r.data_compra}</td><td>${esc(r.fornecedor)}</td><td>${esc(r.categoria)}</td>
      <td>${esc(r.tipo)}</td><td>${esc(r.unidade)}</td>
      <td class="text-success fw-semibold">${brl(r.valor)}</td>
    </tr>`).join('') +
    (registros.length > 10 ? `<tr><td colspan="6" class="text-muted text-center">... e mais ${registros.length-10} registros</td></tr>` : '');
  document.getElementById('hist-import-preview').classList.remove('d-none');
  _histPend = registros;
}

function confirmarImportHist() {
  if (!_histPend?.length) return;
  _histDados = [..._histDados, ..._histPend];
  const n = _histPend.length;
  _histPend = null;
  document.getElementById('hist-cmv-file').value = '';
  document.getElementById('hist-import-preview').classList.add('d-none');
  document.getElementById('msg-hist').innerHTML =
    `<div class="alert alert-success">✅ <strong>${n}</strong> registro(s) importado(s) com sucesso!</div>`;
  setTimeout(() => { const m = document.getElementById('msg-hist'); if (m) m.innerHTML = ''; }, 4000);
  renderHistoricoImport();
}

function cancelarImportHist() {
  _histPend = null;
  document.getElementById('hist-cmv-file').value = '';
  document.getElementById('hist-import-preview').classList.add('d-none');
}

function limparHistorico() {
  if (!confirm(`Apagar todos os ${_histDados.length} registros importados? Não pode ser desfeito.`)) return;
  _histDados = [];
  renderHistoricoImport();
}

async function renderHistoricoImport() {
  const data   = _histDados;
  const show   = (id, vis) => { const el = document.getElementById(id); if (el) el.style.display = vis ? '' : 'none'; };
  const clearEl = document.getElementById('hist-clear-btn-area');
  if (clearEl) clearEl.innerHTML = data.length
    ? `<button class="btn btn-sm btn-outline-danger" onclick="limparHistorico()">🗑️ Apagar todos os dados importados (${data.length} registros)</button>`
    : '';

  if (!data.length) {
    document.getElementById('hist-kpis').innerHTML = '<div class="col-12"><p class="text-muted">Importe sua planilha para visualizar os dados.</p></div>';
    ['hist-filtros','hist-charts-row1','hist-charts-row2','hist-table-card'].forEach(id => show(id, false));
    return;
  }

  ['hist-filtros','hist-charts-row1','hist-charts-row2','hist-table-card'].forEach(id => show(id, true));

  // Preenche filtros
  const anos       = [...new Set(data.map(r => r.data_compra.slice(0,4)))].sort();
  const categorias = [...new Set(data.map(r => r.categoria).filter(Boolean))].sort();
  const unidades   = [...new Set(data.map(r => r.unidade).filter(Boolean))].sort();
  const tipos      = [...new Set(data.map(r => r.tipo).filter(Boolean))].sort();

  const fillSel = (id, opts, ph) => {
    const el = document.getElementById(id); if (!el) return;
    const cur = el.value;
    el.innerHTML = `<option value="">${ph}</option>` + opts.map(o => `<option value="${o}"${o===cur?' selected':''}>${esc(o)}</option>`).join('');
  };
  fillSel('hist-ano',      anos,       'Todos os anos');
  fillSel('hist-cat-fil',  categorias, 'Todas as categorias');
  fillSel('hist-uni-fil',  unidades,   'Todas as unidades');
  fillSel('hist-tipo-fil', tipos,      'Todos os tipos');

  const anoFil  = document.getElementById('hist-ano')?.value      || '';
  const catFil  = document.getElementById('hist-cat-fil')?.value  || '';
  const uniFil  = document.getElementById('hist-uni-fil')?.value  || '';
  const tipoFil = document.getElementById('hist-tipo-fil')?.value || '';

  let fil = data;
  if (anoFil)  fil = fil.filter(r => r.data_compra.startsWith(anoFil));
  if (catFil)  fil = fil.filter(r => r.categoria === catFil);
  if (uniFil)  fil = fil.filter(r => r.unidade   === uniFil);
  if (tipoFil) fil = fil.filter(r => r.tipo      === tipoFil);

  // Faturamento do Supabase
  const { data: fatRows } = await sb.from('cmp_faturamento')
    .select('data,valor').order('data');
  const byFatMes = _grpBy(fatRows || [], r => _mes(r.data), 'valor');

  const byCompMes  = _grpBy(fil, r => _mes(r.data_compra), 'valor');
  const todosMeses = [...new Set(Object.keys(byCompMes))].sort();

  const totalComp = fil.reduce((s,r) => s + r.valor, 0);
  const totalFat  = todosMeses.reduce((s,m) => s + (byFatMes[m]||0), 0);
  const cmvMedio  = totalFat > 0 ? (totalComp / totalFat * 100) : null;
  const corCMV    = cmvMedio !== null && cmvMedio <= META_CMV ? 'var(--verde)' : 'var(--vermelho)';

  // KPIs
  document.getElementById('hist-kpis').innerHTML = `
    <div class="col-md-3 col-6"><div class="card-kpi">
      <div class="kpi-label">📦 Registros no Período</div>
      <div class="kpi-val">${fil.length.toLocaleString('pt-BR')}</div>
    </div></div>
    <div class="col-md-3 col-6"><div class="card-kpi" style="border-color:#FF6B35">
      <div class="kpi-label">💰 Total de Compras</div>
      <div class="kpi-val">${brl(totalComp)}</div>
    </div></div>
    <div class="col-md-3 col-6"><div class="card-kpi" style="border-color:var(--verde)">
      <div class="kpi-label">🏦 Faturamento (período)</div>
      <div class="kpi-val">${totalFat ? brl(totalFat) : '—'}</div>
      ${!totalFat ? '<div class="small text-muted">Lance faturamento para calcular</div>' : ''}
    </div></div>
    <div class="col-md-3 col-6"><div class="card-kpi" style="border-color:${corCMV}">
      <div class="kpi-label">📈 CMV Médio</div>
      <div class="kpi-val" style="color:${corCMV}">${cmvMedio !== null ? cmvMedio.toFixed(1) + '%' : '—'}</div>
      <div class="small text-muted">Meta: ${META_CMV}%</div>
    </div></div>`;

  if (!todosMeses.length) return;

  const labels  = todosMeses.map(_labelMes);
  const valComp = todosMeses.map(m => byCompMes[m]||0);
  const cmvPct  = todosMeses.map(m => byFatMes[m] ? ((byCompMes[m]||0)/byFatMes[m]*100) : null);

  // Gráfico 1 — Compras mensais
  if (chHistMens) { chHistMens.destroy(); chHistMens = null; }
  const ctx1 = document.getElementById('ch-hist-mensal');
  if (ctx1) chHistMens = new Chart(ctx1, {
    type: 'bar',
    data: { labels, datasets: [{ label:'Compras', data:valComp, backgroundColor:'#FF6B35', borderRadius:6 }] },
    options: {
      plugins: { legend:{display:false}, tooltip:{callbacks:{label:ctx=>` ${brl(ctx.raw)}`}} },
      scales: { y: { ticks:{ callback: v => 'R$'+(v>=1000?(v/1000).toFixed(0)+'k':v) } } }
    }
  });

  // Gráfico 2 — CMV % mensal
  if (chHistCMV) { chHistCMV.destroy(); chHistCMV = null; }
  const ctx2 = document.getElementById('ch-hist-cmv-pct');
  if (ctx2) chHistCMV = new Chart(ctx2, {
    type: 'bar',
    data: { labels, datasets: [
      { label:'CMV %', data:cmvPct, backgroundColor:cmvPct.map(v => v===null?'#ddd':v<=META_CMV?'#2EC4B6':'#E71D36'), borderRadius:5 },
      { label:`Meta ${META_CMV}%`, type:'line', data:todosMeses.map(()=>META_CMV),
        borderColor:'orange', borderWidth:2, borderDash:[5,4], pointRadius:0, fill:false }
    ]},
    options: {
      plugins: { legend:{display:true}, tooltip:{callbacks:{label:ctx=>ctx.datasetIndex===0?` CMV: ${ctx.raw!==null?ctx.raw.toFixed(1)+'%':'—'}`:` Meta: ${META_CMV}%`}} },
      scales: { y: { min:0, ticks:{callback: v=>v+'%'} } }
    }
  });

  // Gráfico 3 — Por tipo (donut)
  if (chHistTipo) { chHistTipo.destroy(); chHistTipo = null; }
  const byTipo = _grpBy(fil, 'tipo', 'valor');
  const tks    = Object.keys(byTipo).filter(Boolean).sort((a,b) => byTipo[b]-byTipo[a]);
  const ctx3   = document.getElementById('ch-hist-tipo');
  if (ctx3 && tks.length) chHistTipo = new Chart(ctx3, {
    type: 'doughnut',
    data: { labels:tks, datasets:[{ data:tks.map(k=>byTipo[k]), backgroundColor:CORES_GRAFICO }] },
    options: { plugins: { legend:{position:'bottom'}, tooltip:{callbacks:{label:ctx=>` ${brl(ctx.raw)}`}} } }
  });

  // Tabela mensal
  document.getElementById('tb-hist-cmv').innerHTML = [...todosMeses].reverse().map(m => {
    const comp = byCompMes[m]||0;
    const fat  = byFatMes[m]||0;
    const pct  = fat > 0 ? (comp/fat*100) : null;
    return `<tr>
      <td><strong>${_labelMes(m)}</strong></td>
      <td>${brl(comp)}</td>
      <td>${fat ? brl(fat) : '<span class="text-muted">—</span>'}</td>
      <td>${pct!==null?`<span class="badge ${pct<=META_CMV?'bg-success':'bg-danger'}">${pct.toFixed(1)}%</span>`:'<span class="text-muted">Sem faturamento</span>'}</td>
      <td>${pct!==null?(pct<=META_CMV?'<span class="text-success">✅ Dentro da meta</span>':'<span class="text-danger">⚠️ Acima da meta</span>'):'—'}</td>
    </tr>`;
  }).join('');
}


// ═══════════════════════════════════════════════════════════════
// CONSULTA E IMPRESSÃO DE PEDIDOS
// ═══════════════════════════════════════════════════════════════
async function consultarPedidos() {
  const ini     = document.getElementById('ped-ini')?.value || '';
  const fim     = document.getElementById('ped-fim')?.value || '';
  const fornSel = document.getElementById('ped-forn')?.value || '';

  let query = sb.from('cmp_compras')
    .select('id,pedido_num,data,fornecedor_nome,comprador,produto,categoria,tipo_produto,unidade_med,quantidade,custo_unit')
    .not('pedido_num','is',null)
    .order('data', { ascending: false })
    .order('pedido_num', { ascending: false });
  if (ini) query = query.gte('data', ini);
  if (fim) query = query.lte('data', fim);

  const { data: compras } = await query;
  if (!compras) return;

  // Agrupa por pedido_num
  const grupos = {};
  compras.forEach(c => {
    const key = c.pedido_num;
    if (!grupos[key]) grupos[key] = { pedido_num: key, data: c.data, forn: c.fornecedor_nome, comp: c.comprador, itens: [], total: 0 };
    grupos[key].itens.push(c);
    grupos[key].total += (c.quantidade||0) * (c.custo_unit||0);
  });

  let lista = Object.values(grupos).sort((a,b) => b.pedido_num.localeCompare(a.pedido_num));

  // Popula filtro fornecedor
  const fornEl = document.getElementById('ped-forn');
  if (fornEl) {
    const forns = [...new Set(lista.map(g => g.forn).filter(Boolean))].sort();
    const cur = fornEl.value;
    fornEl.innerHTML = '<option value="">Todos</option>' +
      forns.map(f => `<option value="${f}"${f===cur?' selected':''}>${esc(f)}</option>`).join('');
  }
  if (fornSel) lista = lista.filter(g => g.forn === fornSel);

  // KPIs
  const kpisEl = document.getElementById('ped-kpis');
  if (lista.length && kpisEl) {
    kpisEl.style.display = '';
    const totalGeral = lista.reduce((s,g) => s+g.total, 0);
    document.getElementById('ped-qtd').textContent    = lista.length;
    document.getElementById('ped-total').textContent  = brl(totalGeral);
    document.getElementById('ped-ticket').textContent = brl(lista.length ? totalGeral / lista.length : 0);
  } else if (kpisEl) kpisEl.style.display = 'none';

  const cont = document.getElementById('lst-pedidos-grupos');
  if (!lista.length) {
    cont.innerHTML = '<p class="text-muted text-center py-3">Nenhum pedido encontrado.</p>';
    return;
  }

  cont.innerHTML = lista.map(g => {
    const dataBR  = (g.data||'').split('-').reverse().join('/');
    const itensHtml = g.itens.map(c => `
      <tr>
        <td class="ps-4 text-muted small">${esc(c.produto)}</td>
        <td class="text-muted small">${esc(c.categoria||'—')}</td>
        <td class="text-center small">${c.quantidade} ${esc(c.unidade_med||'')}</td>
        <td class="text-center small">${brl(c.custo_unit)}</td>
        <td class="text-center small fw-semibold">${brl((c.quantidade||0)*(c.custo_unit||0))}</td>
        <td class="text-center">
          <button class="btn btn-sm btn-outline-secondary py-0 px-1" onclick="imprimirPedido('${c.pedido_num}')">🖨️</button>
        </td>
      </tr>`).join('');

    return `<div class="border rounded mb-2">
      <div class="d-flex align-items-center justify-content-between p-2 px-3" style="background:#f8f9fa;cursor:pointer"
           onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'':'none'">
        <div class="d-flex align-items-center gap-2">
          <span class="badge" style="background:#FF6B35">${esc(g.pedido_num)}</span>
          <strong>${esc(g.forn||'—')}</strong>
          <small class="text-muted">${dataBR}</small>
          <span class="badge bg-secondary">${g.itens.length} item(s)</span>
        </div>
        <strong class="text-success">${brl(g.total)}</strong>
      </div>
      <div style="display:none">
        <table class="table table-sm mb-0">
          <thead style="background:#f0f0f0;font-size:.78rem">
            <tr><th class="ps-4">Produto</th><th>Categoria</th><th class="text-center">Qtd</th><th class="text-center">Vlr.Unit</th><th class="text-center">Total</th><th></th></tr>
          </thead>
          <tbody>${itensHtml}</tbody>
        </table>
      </div>
    </div>`;
  }).join('');
}

async function imprimirPedido(pedido_num) {
  const { data: itens } = await sb.from('cmp_compras')
    .select('*').eq('pedido_num', pedido_num);
  if (!itens?.length) return;
  const ref       = itens[0];
  const dataBR    = (ref.data||'').split('-').reverse().join('/');
  const subtotal  = itens.reduce((s,c) => s + (c.quantidade||0)*(c.custo_unit||0), 0);
  const acrescimo = parseFloat(ref.acrescimo) || 0;
  const total     = subtotal + acrescimo;

  const linhas = itens.map((c,i) => `<tr>
    <td>${i+1}</td>
    <td><strong>${esc(c.produto)}</strong></td>
    <td>${esc(c.categoria||'—')}</td>
    <td>${esc(c.tipo_produto||'—')}</td>
    <td style="text-align:center">${c.quantidade} ${esc(c.unidade_med||'')}</td>
    <td style="text-align:center">${brl(c.custo_unit)}</td>
    <td style="text-align:center;font-weight:bold">${brl((c.quantidade||0)*(c.custo_unit||0))}</td>
  </tr>`).join('');

  const w = window.open('', '_blank', 'width=900,height=700');
  w.document.write(`<!DOCTYPE html><html lang="pt-BR"><head>
  <meta charset="UTF-8"><title>Pedido ${pedido_num}</title>
  <style>*{box-sizing:border-box;margin:0;padding:0}
  body{font-family:'Segoe UI',Arial,sans-serif;font-size:12px;padding:1.5cm}
  .header{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:1.5rem;border-bottom:3px solid #FF6B35;padding-bottom:1rem}
  h1{color:#1a1a2e;font-size:1.4rem}.num{font-size:1.8rem;font-weight:700;color:#FF6B35}
  .meta{display:flex;gap:2rem;margin-bottom:1rem;font-size:.85rem}
  .meta strong{display:block;color:#1a1a2e}.meta span{color:#666}
  table{width:100%;border-collapse:collapse}thead tr{background:#1a1a2e;color:#fff}
  th,td{padding:5px 8px;border:1px solid #e0e0e0}tbody tr:nth-child(even){background:#fafafa}
  .tot{background:#f0fdf4;font-weight:700;font-size:1rem}
  @media print{body{padding:.5cm}}</style></head><body>
  <div class="header">
    <div><h1>Tambaqui de Banda</h1><p style="color:#666">Pedido de Compra</p></div>
    <div class="num">Nº ${esc(pedido_num)}</div>
  </div>
  <div class="meta">
    <div><span>Data</span><strong>${dataBR}</strong></div>
    <div><span>Fornecedor</span><strong>${esc(ref.fornecedor_nome||'—')}</strong></div>
    <div><span>Comprador</span><strong>${esc(ref.comprador||'—')}</strong></div>
    ${ref.unidade_uso ? `<div><span>Unidade</span><strong>${esc(ref.unidade_uso)}</strong></div>` : ''}
    ${ref.forma_pagamento ? `<div><span>Forma de Pagamento</span><strong>${esc(ref.forma_pagamento)}</strong></div>` : ''}
    ${ref.data_entrega ? `<div><span>Entrega</span><strong>${ref.data_entrega.split('-').reverse().join('/')}</strong></div>` : ''}
  </div>
  <table><thead><tr><th>#</th><th>Produto</th><th>Categoria</th><th>Tipo</th>
    <th style="text-align:center">Quantidade</th><th style="text-align:center">Valor Unit.</th>
    <th style="text-align:center">Total</th></tr></thead>
  <tbody>${linhas}</tbody>
  <tfoot>
    ${acrescimo > 0 ? `<tr style="font-size:.9rem;color:#c2410c">
      <td colspan="6" style="text-align:right;padding-right:8px">Acréscimo (frete/taxa)</td>
      <td style="text-align:center">${brl(acrescimo)}</td>
    </tr>` : ''}
    <tr class="tot">
      <td colspan="6" style="text-align:right;padding-right:8px">TOTAL DO PEDIDO</td>
      <td style="text-align:center">${brl(total)}</td>
    </tr>
  </tfoot></table>
  <div style="margin-top:3rem;display:flex;gap:4rem">
    <div style="border-top:1px solid #333;width:180px;padding-top:.3rem;text-align:center;font-size:.8rem">Comprador</div>
    <div style="border-top:1px solid #333;width:180px;padding-top:.3rem;text-align:center;font-size:.8rem">Fornecedor</div>
  </div>
  <script>setTimeout(()=>window.print(),400)<\/script>
  </body></html>`);
  w.document.close();
}

async function imprimirTodosPedidosForn() {
  const ini = document.getElementById('ped-ini')?.value || '';
  const fim = document.getElementById('ped-fim')?.value || '';
  let query = sb.from('cmp_compras')
    .select('*').not('pedido_num','is',null).order('pedido_num');
  if (ini) query = query.gte('data', ini);
  if (fim) query = query.lte('data', fim);
  const { data: compras } = await query;
  if (!compras?.length) { toast('Nenhum pedido no período.', 'erro'); return; }

  const grupos = {};
  compras.forEach(c => {
    const key = c.pedido_num;
    if (!grupos[key]) grupos[key] = { pedido_num: key, data: c.data, forn: c.fornecedor_nome, comp: c.comprador, itens: [] };
    grupos[key].itens.push(c);
  });

  const pagesHtml = Object.values(grupos).map(g => {
    const dataBR = (g.data||'').split('-').reverse().join('/');
    const total  = g.itens.reduce((s,c) => s+(c.quantidade||0)*(c.custo_unit||0), 0);
    const linhas = g.itens.map((c,i) => `<tr>
      <td>${i+1}</td><td><strong>${esc(c.produto)}</strong></td>
      <td>${esc(c.categoria||'—')}</td>
      <td style="text-align:center">${c.quantidade} ${esc(c.unidade_med||'')}</td>
      <td style="text-align:center">${brl(c.custo_unit)}</td>
      <td style="text-align:center;font-weight:bold">${brl((c.quantidade||0)*(c.custo_unit||0))}</td>
    </tr>`).join('');
    return `<div class="page">
      <div class="header"><div><strong>Tambaqui de Banda</strong> — Pedido de Compra</div>
      <div class="num">Nº ${esc(g.pedido_num)}</div></div>
      <div class="meta"><span>Data: ${dataBR}</span><span>Fornecedor: <strong>${esc(g.forn||'—')}</strong></span>
      <span>Comprador: ${esc(g.comp||'—')}</span></div>
      <table><thead><tr><th>#</th><th>Produto</th><th>Categoria</th>
        <th>Qtd</th><th>Vlr Unit.</th><th>Total</th></tr></thead>
      <tbody>${linhas}</tbody>
      <tfoot><tr class="tot"><td colspan="5" style="text-align:right">TOTAL</td>
        <td style="text-align:center">${brl(total)}</td></tr></tfoot></table>
    </div>`;
  }).join('');

  const w = window.open('', '_blank', 'width=1000,height=750');
  w.document.write(`<!DOCTYPE html><html><head><meta charset="UTF-8">
  <title>Pedidos por Fornecedor</title>
  <style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:Arial,sans-serif;font-size:11px}
  .page{padding:1cm;page-break-after:always}
  .header{display:flex;justify-content:space-between;border-bottom:2px solid #FF6B35;padding-bottom:.5rem;margin-bottom:.7rem}
  .num{font-size:1.4rem;font-weight:700;color:#FF6B35}
  .meta{display:flex;gap:1.5rem;margin-bottom:.7rem;font-size:.85rem}
  table{width:100%;border-collapse:collapse}thead tr{background:#1a1a2e;color:#fff}
  th,td{padding:3px 6px;border:1px solid #e0e0e0}
  .tot{background:#f0fdf4;font-weight:700}
  @media print{.page{page-break-after:always}}</style></head>
  <body>${pagesHtml}
  <script>setTimeout(()=>window.print(),400)<\/script></body></html>`);
  w.document.close();
}


// ═══════════════════════════════════════════════════════════════
// COMPRAS — LISTA DE PEDIDOS
// ═══════════════════════════════════════════════════════════════
async function carregarCompras() {
  const ini     = document.getElementById('cps-ini')?.value || '';
  const fim     = document.getElementById('cps-fim')?.value || '';
  const fornSel = document.getElementById('cps-forn')?.value || '';

  let query = sb.from('cmp_compras')
    .select('id,pedido_num,data,data_entrega,fornecedor_id,fornecedor_nome,comprador,produto,categoria,quantidade,custo_unit,status_receb,setor,acrescimo')
    .not('pedido_num','is',null)
    .order('data', { ascending: false })
    .order('pedido_num', { ascending: false });
  if (ini) query = query.gte('data', ini);
  if (fim) query = query.lte('data', fim);

  const { data: rows } = await query;
  if (!rows) return;

  // Agrupa por pedido_num
  const grupos = {};
  rows.forEach(c => {
    const key = c.pedido_num;
    if (!grupos[key]) grupos[key] = {
      pedido_num: key, data: c.data, data_entrega: c.data_entrega,
      forn: c.fornecedor_nome, comp: c.comprador, fornecedor_id: c.fornecedor_id || '',
      setor: c.setor || '', itens: [], total: 0, acrescimo: parseFloat(c.acrescimo) || 0,
      recebido: c.status_receb === 'recebido'
    };
    grupos[key].itens.push(c);
    grupos[key].total += (c.quantidade||0) * (c.custo_unit||0);
    if (c.status_receb !== 'recebido') grupos[key].recebido = false;
  });

  // Inclui acréscimo no total de cada grupo
  Object.values(grupos).forEach(g => { g.total += g.acrescimo; });

  // Verifica status financeiro de cada pedido
  const numeros = Object.keys(grupos);
  const lancSet     = new Set();
  const rascunhoSet = new Set();
  const adiantSet   = new Set(); // pedidos com adiantamento_lancamento_id (advance separado)
  const valorRecebMap = {}; // pedido_num → valor efetivamente recebido (cmp_contas_pagar.valor)
  const somaRecebMap  = {}; // pedido_num → soma de todos os cmp_recebimentos.total_recebido
  if (numeros.length) {
    const [resLanc, resRasc, resContas, resReceb] = await Promise.all([
      sb.from('lancamentos').select('numero_pedido').in('numero_pedido', numeros),
      sb.from('lancamentos_rascunho').select('pedido_num').in('pedido_num', numeros),
      sb.from('cmp_contas_pagar').select('pedido_num,lancamento_id,adiantamento_lancamento_id,valor').in('pedido_num', numeros),
      sb.from('cmp_recebimentos').select('pedido_num,total_recebido').in('pedido_num', numeros),
    ]);
    (resLanc.data   || []).forEach(l => lancSet.add(l.numero_pedido));
    (resRasc.data   || []).forEach(r => rascunhoSet.add(r.pedido_num));
    (resContas.data || []).forEach(c => {
      if (c.lancamento_id)              lancSet.add(c.pedido_num);
      if (c.adiantamento_lancamento_id) adiantSet.add(c.pedido_num);
      if (c.valor > 0) valorRecebMap[c.pedido_num] = c.valor;
    });
    (resReceb.data  || []).forEach(r => {
      somaRecebMap[r.pedido_num] = (somaRecebMap[r.pedido_num] || 0) + (r.total_recebido || 0);
    });
  }

  // Para pedidos recebidos: usa cmp_contas_pagar.valor como total (correto: qtd_recebida × preço_recebido + acréscimo)
  Object.values(grupos).forEach(g => {
    if (g.recebido && valorRecebMap[g.pedido_num]) {
      g.total = valorRecebMap[g.pedido_num];
    }
  });

  let lista = Object.values(grupos).sort((a,b) => b.pedido_num.localeCompare(a.pedido_num));

  // Popula filtro fornecedor
  const fornEl = document.getElementById('cps-forn');
  if (fornEl) {
    const forns = [...new Set(lista.map(g => g.forn).filter(Boolean))].sort();
    const cur = fornEl.value;
    fornEl.innerHTML = '<option value="">Todos</option>' +
      forns.map(f => `<option value="${f}"${f===cur?' selected':''}>${esc(f)}</option>`).join('');
  }
  if (fornSel) lista = lista.filter(g => g.forn === fornSel);

  // KPIs
  const totalGeral  = lista.reduce((s,g) => s+g.total, 0);
  const qtdRecebido = lista.filter(g => g.recebido).length;
  document.getElementById('cps-kpi-qtd').textContent   = lista.length;
  document.getElementById('cps-kpi-total').textContent  = brl(totalGeral);
  document.getElementById('cps-kpi-receb').textContent  = `${qtdRecebido} / ${lista.length}`;

  const tbody = document.getElementById('tb-compras-lista');
  if (!lista.length) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted py-4">Nenhum pedido encontrado.</td></tr>';
    return;
  }

  tbody.innerHTML = lista.map(g => {
    const dataBR  = (g.data||'').split('-').reverse().join('/');
    const entregaBR = g.data_entrega ? g.data_entrega.split('-').reverse().join('/') : '—';
    const corEstoque  = g.recebido ? '#2EC4B6' : '#FF6B35';
    const statusEstoque = g.recebido ? '✅ Recebido' : '⏳ Pendente';
    const enviado    = lancSet.has(g.pedido_num);
    const adiantado  = adiantSet.has(g.pedido_num);
    const aguardando = !enviado && !adiantado && rascunhoSet.has(g.pedido_num);
    const isCompExt  = isCompExterna(g.forn);

    let badgeFinanc;
    if (isCompExt) {
      // Fluxo Comprador Externo
      if (lancSet.has(g.pedido_num)) {
        badgeFinanc = `<span class="badge" style="background:#6f42c1">💰 Financeiro</span>`;
      } else if (adiantado) {
        // Adiantamento enviado — mostra botão Finalizar se houver algum recebimento parcial
        badgeFinanc = `<span class="badge" style="background:#fd7e14">💳 Adiantamento</span>
          <button class="btn btn-sm btn-outline-success py-0 px-2 d-block mt-1"
            onclick="event.stopPropagation();finalizarPedidoCompExt('${esc(g.pedido_num)}')"
            title="Finalizar pedido e enviar despesa ao financeiro">
            🏁 Finalizar Pedido
          </button>`;
      } else {
        badgeFinanc = `<span class="badge bg-light text-muted border">Não enviado</span>
          <button class="btn btn-sm btn-outline-warning py-0 px-2 d-block mt-1"
            onclick="event.stopPropagation();abrirAdiantamento('${esc(g.pedido_num)}','${esc(g.forn||'')}','${g.fornecedor_id||''}',${g.total})"
            title="Enviar ao financeiro">
            📤 Enviar Financeiro
          </button>`;
      }
    } else if (enviado && adiantado) {
      // Adiantamento + NF registrados = completo
      badgeFinanc = `<span class="badge" style="background:#6f42c1">💰 Financeiro</span>`;
    } else if (enviado) {
      badgeFinanc = `<span class="badge" style="background:#6f42c1">💰 Financeiro</span>`;
    } else if (adiantado && g.recebido) {
      // Adiantamento feito + recebido → aguardando Gerar NF
      badgeFinanc = `<span class="badge" style="background:#fd7e14">💳 Adiantamento</span>
        <button class="btn btn-sm btn-outline-primary py-0 px-2 d-block mt-1"
          onclick="event.stopPropagation();abrirGerarConta('${esc(g.pedido_num)}','${esc(g.forn||'')}','${g.fornecedor_id||''}',${g.total})"
          title="Registrar NF com valor real no financeiro">
          <i class="bi bi-arrow-left-right"></i> Gerar NF
        </button>`;
    } else if (adiantado) {
      // Adiantamento feito, aguardando recebimento
      badgeFinanc = `<span class="badge" style="background:#fd7e14">💳 Adiantamento</span>`;
    } else if (aguardando) {
      badgeFinanc = `<span class="badge bg-warning text-dark">⏳ Aguardando</span>`;
    } else if (g.recebido) {
      // Recebido, sem adiantamento → Gerar Conta normal
      badgeFinanc = `<button class="btn btn-sm btn-outline-primary py-0 px-2"
          onclick="event.stopPropagation();abrirGerarConta('${esc(g.pedido_num)}','${esc(g.forn||'')}','${g.fornecedor_id||''}',${g.total})"
          title="Pedido recebido — enviar ao financeiro">
          <i class="bi bi-arrow-left-right"></i> Gerar Conta
        </button>`;
    } else {
      // Não recebido, sem adiantamento
      badgeFinanc = `<span class="badge bg-light text-muted border">Não enviado</span>
        <button class="btn btn-sm btn-outline-warning py-0 px-2 d-block mt-1"
          onclick="event.stopPropagation();abrirAdiantamento('${esc(g.pedido_num)}','${esc(g.forn||'')}','${g.fornecedor_id||''}',${g.total})"
          title="Enviar ao financeiro">
          📤 Enviar Financeiro
        </button>`;
    }
    const btnFecharPedido = (!isCompExt && !g.recebido)
      ? `<button class="btn btn-sm btn-outline-secondary py-0 px-2 d-block mt-1"
          onclick="event.stopPropagation();finalizarPedidoRegular('${esc(g.pedido_num)}')"
          title="Fechar pedido — dispensar itens não entregues">🏁 Fechar Pedido</button>`
      : '';

    const podeEditar   = !g.recebido && !enviado;
    const podeReabrir  = g.recebido && !aguardando;
    const editarTitle  = g.recebido ? 'Pedido já recebido' : enviado ? 'Pedido enviado ao financeiro' : 'Editar pedido';
    const excluirTitle = g.recebido ? 'Pedido já recebido' : enviado ? 'Pedido enviado ao financeiro' : 'Excluir pedido';
    const somaReceb    = somaRecebMap[g.pedido_num] || 0;
    const cpValor      = valorRecebMap[g.pedido_num] || 0;
    const divergeReceb = g.recebido && cpValor > 0 && Math.abs(somaReceb - cpValor) > 0.01;
    const avisoReceb   = divergeReceb
      ? ` <span data-bs-toggle="tooltip" data-bs-title="Múltiplos recebimentos: soma ${brl(somaReceb)} vs financeiro ${brl(cpValor)} — verifique antes de aprovar" style="color:#fd7e14;cursor:help">⚠️</span>`
      : '';
    return `<tr style="cursor:pointer" onclick="toggleDetalheCompra('${g.pedido_num}', this)">
      <td>${dataBR}</td>
      <td><span class="badge" style="background:#FF6B35">${esc(g.pedido_num)}</span></td>
      <td>
        <strong>${esc(g.forn||'—')}</strong>
        ${g.setor ? `<br><span class="badge" style="background:#6f42c1;font-size:.7rem">${esc(g.setor)}</span>` : ''}
      </td>
      <td>${esc(g.comp||'—')}</td>
      <td class="text-center"><span class="badge bg-secondary">${g.itens.length}</span></td>
      <td class="text-center">${entregaBR}</td>
      <td class="text-center fw-bold">${brl(g.total)}${avisoReceb}</td>
      <td class="text-center">
        <div class="d-flex flex-column gap-1 align-items-center">
          <span class="badge" style="background:${corEstoque}">${statusEstoque}</span>
          ${badgeFinanc}
          ${btnFecharPedido}
        </div>
      </td>
      <td class="text-center">
        <div class="d-flex gap-2 justify-content-center align-items-center" onclick="event.stopPropagation()">
          ${podeReabrir ? `
          <span data-bs-toggle="tooltip" data-bs-title="Reabrir para edição">
            <button class="btn btn-sm btn-outline-warning py-1 px-2" onclick="event.stopPropagation();reabrirPedido('${g.pedido_num}')" style="white-space:nowrap"><i class="bi bi-arrow-counterclockwise"></i> Reabrir</button>
          </span>` : ''}
          <span data-bs-toggle="tooltip" data-bs-title="${editarTitle}">
            <button class="btn btn-sm py-1 px-2 ${podeEditar ? 'btn-outline-primary' : 'btn-outline-secondary'}" ${podeEditar ? `onclick="editarPedido('${g.pedido_num}')"` : 'disabled'} style="white-space:nowrap;pointer-events:${podeEditar?'auto':'none'}"><i class="bi bi-pencil-fill"></i> Editar</button>
          </span>
          <span data-bs-toggle="tooltip" data-bs-title="${podeEditar ? 'Dividir entre unidades' : 'Não é possível dividir'}">
            <button class="btn btn-link p-0" ${podeEditar ? `onclick="dividirPedido('${g.pedido_num}')"` : 'disabled'} style="font-size:1.1rem;${podeEditar ? 'color:#fd7e14' : 'color:#ced4da;pointer-events:none'}"><i class="bi bi-scissors"></i></button>
          </span>
          <span data-bs-toggle="tooltip" data-bs-title="Imprimir">
            <button class="btn btn-link p-0" onclick="imprimirPedido('${g.pedido_num}')" style="color:#6c757d;font-size:1.1rem"><i class="bi bi-printer-fill"></i></button>
          </span>
          <span data-bs-toggle="tooltip" data-bs-title="${podeEditar ? 'Excluir' : excluirTitle}">
            <button class="btn btn-link p-0" ${podeEditar ? `onclick="excluirPedidoCompras('${g.pedido_num}')"` : 'disabled'} style="font-size:1.2rem;${podeEditar ? 'color:#dc3545' : 'color:#ced4da;pointer-events:none'}"><i class="bi bi-trash3-fill"></i></button>
          </span>
        </div>
      </td>
    </tr>
    <tr id="detalhe-${g.pedido_num}" style="display:none;background:#f8f9fa">
      <td colspan="9" class="p-0">
        <table class="table table-sm mb-0" style="font-size:.82rem">
          <thead style="background:#e9ecef">
            <tr><th class="ps-4">Produto</th><th>Categoria</th><th class="text-center">Qtd</th><th class="text-center">Vlr.Unit</th><th class="text-center fw-bold">Total</th></tr>
          </thead>
          <tbody>
            ${g.itens.map(c => `<tr>
              <td class="ps-4">${esc(c.produto)}</td>
              <td class="text-muted">${esc(c.categoria||'—')}</td>
              <td class="text-center">${c.quantidade}</td>
              <td class="text-center">${brl(c.custo_unit)}</td>
              <td class="text-center fw-bold">${brl((c.quantidade||0)*(c.custo_unit||0))}</td>
            </tr>`).join('')}
          </tbody>
        </table>
      </td>
    </tr>`;
  }).join('');

  initTooltips(document.getElementById('tb-compras-lista'));
}

function toggleDetalheCompra(pedido_num, tr) {
  const detalhe = document.getElementById(`detalhe-${pedido_num}`);
  if (!detalhe) return;
  const visivel = detalhe.style.display !== 'none';
  detalhe.style.display = visivel ? 'none' : '';
  tr.style.background = visivel ? '' : '#fff8f0';
}

function limparFiltrosCompras() {
  document.getElementById('cps-ini').value = '';
  document.getElementById('cps-fim').value = '';
  document.getElementById('cps-forn').value = '';
  carregarCompras();
}

async function excluirPedidoCompras(pedido_num) {
  const { data: lanc } = await sb.from('lancamentos').select('id').eq('numero_pedido', pedido_num).maybeSingle();
  if (lanc) {
    toast('Pedido já enviado ao financeiro — exclua o lançamento lá primeiro.', 'erro');
    return;
  }
  if (!confirm(`Excluir o pedido ${pedido_num}? Esta ação não pode ser desfeita.`)) return;
  await Promise.all([
    sb.from('cmp_compras').delete().eq('pedido_num', pedido_num),
    sb.from('lancamentos_rascunho').delete().eq('pedido_num', pedido_num),
    sb.from('cmp_contas_pagar').delete().eq('pedido_num', pedido_num),
  ]);
  toast('Pedido excluído.', 'ok');
  carregarCompras();
}

// ── DIVIDIR PEDIDO ──────────────────────────────────────────────
let _divItens = [];
let _divPedidoNum = null;

async function dividirPedido(pedido_num) {
  if (!cUnidades.length) await carregarCaches();

  const { data: itens } = await sb.from('cmp_compras')
    .select('*').eq('pedido_num', pedido_num).order('id');
  if (!itens?.length) { toast('Pedido não encontrado.', 'erro'); return; }

  _divPedidoNum = pedido_num;
  _divItens = itens;

  document.getElementById('div-pedido-num').textContent = '#' + pedido_num;

  const optsUni = '<option value="">— Selecione —</option>' +
    cUnidades.map(u => `<option value="${u.id}" data-nome="${esc(u.nome)}">${esc(u.nome)}</option>`).join('');
  document.getElementById('div-unid-a').innerHTML = optsUni;
  document.getElementById('div-unid-b').innerHTML = optsUni;
  document.getElementById('div-aviso').classList.add('d-none');

  const tbody = document.getElementById('div-itens-tbody');
  tbody.innerHTML = itens.map((it, i) => `
    <tr>
      <td><strong>${esc(it.produto)}</strong><br><small class="text-muted">${esc(it.categoria||'')}</small></td>
      <td class="text-center fw-bold">${(it.quantidade||0).toLocaleString('pt-BR',{maximumFractionDigits:3})}</td>
      <td class="text-center text-muted">${esc(it.unidade_med||'')}</td>
      <td class="text-center" style="width:110px">
        <input type="number" class="form-control form-control-sm text-center" id="div-a-${i}"
          min="0" max="${it.quantidade}" step="any" value="${it.quantidade}"
          oninput="calcDivB(${i},${it.quantidade})">
      </td>
      <td class="text-center" style="width:110px">
        <input type="number" class="form-control form-control-sm text-center bg-light" id="div-b-${i}"
          min="0" max="${it.quantidade}" step="any" value="0" readonly>
      </td>
      <td class="text-end text-muted">${brl(it.custo_unit||0)}</td>
    </tr>`).join('');

  atualizarTotaisDivisao();
  new bootstrap.Modal(document.getElementById('modal-dividir')).show();
}

function calcDivB(idx, totalQtd) {
  const a  = parseFloat(document.getElementById(`div-a-${idx}`)?.value) || 0;
  const b  = Math.max(0, totalQtd - a);
  const elB = document.getElementById(`div-b-${idx}`);
  if (elB) elB.value = parseFloat(b.toFixed(3));
  atualizarTotaisDivisao();
}

function atualizarTotaisDivisao() {
  let totalA = 0, totalB = 0;
  _divItens.forEach((it, i) => {
    const a = parseFloat(document.getElementById(`div-a-${i}`)?.value) || 0;
    const b = parseFloat(document.getElementById(`div-b-${i}`)?.value) || 0;
    totalA += a * (it.custo_unit || 0);
    totalB += b * (it.custo_unit || 0);
  });
  const nomeA = document.getElementById('div-unid-a')?.selectedOptions[0]?.dataset?.nome || 'Unidade A';
  const nomeB = document.getElementById('div-unid-b')?.selectedOptions[0]?.dataset?.nome || 'Unidade B';
  document.getElementById('div-totais-tfoot').innerHTML = `
    <tr class="table-primary"><td colspan="3" class="text-end fw-semibold">Total ${esc(nomeA)}</td>
      <td class="text-center fw-bold" style="color:#0d6efd">${brl(totalA)}</td><td colspan="2"></td></tr>
    <tr class="table-success"><td colspan="3" class="text-end fw-semibold">Total ${esc(nomeB)}</td>
      <td></td><td class="text-center fw-bold" style="color:#198754">${brl(totalB)}</td><td></td></tr>`;
}

async function confirmarDivisao() {
  const unidAId   = document.getElementById('div-unid-a').value;
  const unidBId   = document.getElementById('div-unid-b').value;
  const unidANome = document.getElementById('div-unid-a').selectedOptions[0]?.dataset?.nome || '';
  const unidBNome = document.getElementById('div-unid-b').selectedOptions[0]?.dataset?.nome || '';
  const aviso     = document.getElementById('div-aviso');

  if (!unidAId || !unidBId) { aviso.textContent = 'Selecione as duas unidades.'; aviso.classList.remove('d-none'); return; }
  if (unidAId === unidBId)  { aviso.textContent = 'As duas unidades devem ser diferentes.'; aviso.classList.remove('d-none'); return; }

  // Valida que qtdA + qtdB = total para cada item
  let valido = true;
  _divItens.forEach((it, i) => {
    const a   = parseFloat(document.getElementById(`div-a-${i}`)?.value) || 0;
    const b   = parseFloat(document.getElementById(`div-b-${i}`)?.value) || 0;
    const tot = it.quantidade || 0;
    if (Math.abs(a + b - tot) > 0.001) valido = false;
  });
  if (!valido) { aviso.textContent = 'As quantidades de A + B devem somar o total de cada item.'; aviso.classList.remove('d-none'); return; }

  aviso.classList.add('d-none');

  const pedidoA = _divPedidoNum + '-A';
  const pedidoB = _divPedidoNum + '-B';

  const rowsA = [], rowsB = [];
  _divItens.forEach((it, i) => {
    const qA = parseFloat(document.getElementById(`div-a-${i}`)?.value) || 0;
    const qB = parseFloat(document.getElementById(`div-b-${i}`)?.value) || 0;
    const base = { ...it, id: undefined };
    if (qA > 0) rowsA.push({ ...base, pedido_num: pedidoA, quantidade: qA, total: qA * (it.custo_unit||0), unidade_uso: unidANome });
    if (qB > 0) rowsB.push({ ...base, pedido_num: pedidoB, quantidade: qB, total: qB * (it.custo_unit||0), unidade_uso: unidBNome });
  });

  if (!rowsA.length && !rowsB.length) { aviso.textContent = 'Nenhum item com quantidade maior que zero.'; aviso.classList.remove('d-none'); return; }

  // Exclui pedido original e insere os dois novos
  await sb.from('cmp_compras').delete().eq('pedido_num', _divPedidoNum);
  if (rowsA.length) await sb.from('cmp_compras').insert(rowsA);
  if (rowsB.length) await sb.from('cmp_compras').insert(rowsB);

  bootstrap.Modal.getInstance(document.getElementById('modal-dividir'))?.hide();
  toast(`Pedido dividido: ${pedidoA} e ${pedidoB}`, 'ok');
  carregarCompras();
}

async function reabrirPedido(pedido_num) {
  const { data: contaExiste } = await sb.from('cmp_contas_pagar').select('id').eq('pedido_num', pedido_num).maybeSingle();
  const aviso = contaExiste
    ? `Reabrir pedido ${pedido_num}?\n\nO recebimento e o vínculo com o financeiro (Contas a Pagar) serão removidos. O pedido voltará para pendente, liberando a edição.\n\nSe o lançamento já foi aprovado no financeiro, exclua-o de lá também.`
    : `Reabrir pedido ${pedido_num}?\n\nO recebimento será desfeito e o pedido voltará para pendente, liberando a edição.`;
  if (!confirm(aviso)) return;

  // Volta todos os itens para pendente e restaura quantidades originais via recebimento_itens
  const { data: recebimentos } = await sb.from('cmp_recebimentos').select('id').eq('pedido_num', pedido_num);
  if (recebimentos?.length) {
    const ids = recebimentos.map(r => r.id);
    await sb.from('cmp_recebimento_itens').delete().in('recebimento_id', ids);
    await sb.from('cmp_recebimentos').delete().in('id', ids);
  }
  await sb.from('cmp_contas_pagar').delete().eq('pedido_num', pedido_num);
  await sb.from('cmp_compras').update({ status_receb: 'pendente' }).eq('pedido_num', pedido_num);

  toast(`Pedido ${pedido_num} reaberto. Edite e receba novamente.`, 'ok');
  carregarCompras();
}

async function editarPedido(pedido_num) {
  // Busca itens do pedido
  const { data: itens } = await sb.from('cmp_compras')
    .select('data,fornecedor_id,fornecedor_nome,comprador,produto,categoria,plano_conta,unidade_med,custo_unit,quantidade,unidade_uso,acrescimo,setor,forma_pagamento')
    .eq('pedido_num', pedido_num)
    .order('id');

  if (!itens || !itens.length) { toast('Pedido não encontrado.', 'erro'); return; }

  // Garante caches carregados para o lookup de unidades
  await carregarCaches();

  // Constrói _pedidoItens a partir do banco
  _pedidoItens = itens.map(it => {
    const uniObj = cUnidades.find(u => u.nome === it.unidade_uso);
    return {
      data:       it.data,
      fornNome:   it.fornecedor_nome,
      fornId:     it.fornecedor_id,
      comp:       it.comprador,
      prod:       it.produto,
      cat:        it.categoria,
      planoConta: it.plano_conta,
      un:         it.unidade_med,
      custo:      it.custo_unit,
      qtd:        it.quantidade,
      uso:        it.unidade_uso,
      unidadeId:  uniObj?.id || null,
      setor:          it.setor || '',
      formaPagamento: it.forma_pagamento || '',
      total:          (it.custo_unit || 0) * (it.quantidade || 0),
    };
  });

  _pedidoEditando  = pedido_num;
  _pedidoAcrescimo = parseFloat(itens[0]?.acrescimo) || 0;

  // Navega para o formulário — prepararFormCompra() vai detectar _pedidoEditando e pré-preencher
  const navEl = document.querySelector('.nav-sb a[onclick*="\'pedido\'"]');
  ir('pedido', navEl);
}


// ═══════════════════════════════════════════════════════════════
// DETALHE DO PRODUTO
// ═══════════════════════════════════════════════════════════════
let _prodAtual = null;

async function abrirProduto(prodId) {
  // Busca diretamente do banco para garantir dados frescos
  const { data: prod } = await sb.from('est_produtos')
    .select('id,nome,tipo,categoria,plano_cat,unidade_comp,unidade_uso,custo_comp,custo_uso,preco_venda,estoque_min,ativo,fator_conversao,perda')
    .eq('id', prodId).single();
  if (!prod) return;
  // Atualiza cache local com o dado fresco
  const idx = cProdutosFT.findIndex(x => x.id === prodId);
  if (idx >= 0) cProdutosFT[idx] = { ...cProdutosFT[idx], ...prod };
  const p = prod;
  _prodAtual = p;
  if (!cCat.length || !cGrupos.length) await carregarCaches();

  // Navega para pg-produto
  salvarNav('produto-' + prodId);
  document.querySelectorAll('.pagina').forEach(s => s.classList.remove('ativa'));
  document.getElementById('pg-produto').classList.add('ativa');
  document.getElementById('nav-grupo-cadastros')?.classList.add('aberto', 'ativo');
  document.getElementById('nav-submenu-cadastros')?.classList.add('aberto');

  // Reseta abas
  document.querySelectorAll('#tabs-prod .nav-link').forEach(a => a.classList.remove('active'));
  document.querySelector('#tabs-prod .nav-link')?.classList.add('active');
  document.getElementById('aba-dados').style.display = '';
  document.getElementById('aba-ficha').style.display = 'none';

  // Cabeçalho
  document.getElementById('prod-titulo').textContent = p.nome;
  document.getElementById('prod-tipo-badge').textContent = p.tipo;
  document.getElementById('prod-id').value = p.id;

  // Preenche form de dados
  document.getElementById('prod-nome').value         = p.nome          || '';
  document.getElementById('prod-tipo').value         = p.tipo          || '';
  setMoeda('prod-custo-comp', p.custo_comp);
  setMoeda('prod-preco-venda', p.preco_venda);
  document.getElementById('prod-fator-conv').value = p.fator_conversao || 1;
  document.getElementById('prod-perda').value       = p.perda          || 0;
  document.getElementById('prod-est-min').value     = p.estoque_min    || 0;
  document.getElementById('prod-ativo').checked      = p.ativo !== false;

  // Categoria select
  // Grupo do produto — texto livre
  document.getElementById('prod-cat').value = p.categoria || '';

  // Grupo do produto — select de est_grupos_produto
  preencherSelectGrupo(p.categoria || '');

  // Categoria do plano de contas — select de cmp_categorias
  const planoCatSel = document.getElementById('prod-plano-cat');
  if (planoCatSel) {
    planoCatSel.innerHTML = '<option value="">— Selecione —</option>' +
      cCat.map(c => `<option value="${esc(c.nome)}"${c.nome === (p.plano_cat || '') ? ' selected' : ''}>${esc(c.nome)}</option>`).join('');
  }

  // Unidades
  const uns = ['UN','KG','CX','LT','FD','PC','MT','DZ'];
  const setUnSel = (id, val) => {
    const sel = document.getElementById(id);
    sel.innerHTML = uns.map(u => `<option${u === val ? ' selected' : ''}>${u}</option>`).join('');
  };
  setUnSel('prod-un-comp', p.unidade_comp || 'UN');
  setUnSel('prod-un-uso',  p.unidade_uso  || 'UN');
  atualizarCustoEfetivo();
}

function atualizarCustoEfetivo() {
  const unComp = document.getElementById('prod-un-comp')?.value || 'UN';
  const unUso  = document.getElementById('prod-un-uso')?.value  || 'UN';
  const custo  = parseMoeda('prod-custo-comp');
  const fator  = parseFloat(document.getElementById('prod-fator-conv')?.value) || 1;
  const perda  = parseFloat(document.getElementById('prod-perda')?.value)      || 0;

  const rendimento = 1 - (perda / 100);
  const efetivo    = rendimento > 0 ? (custo / fator) / rendimento : 0;

  document.getElementById('prod-fator-label').textContent       = `1 ${unComp} = ${fator.toLocaleString('pt-BR', {maximumFractionDigits:2})} ${unUso}`;
  document.getElementById('prod-custo-efetivo').textContent     = brl(efetivo);
  document.getElementById('prod-custo-efetivo-un').textContent  = `por ${unUso}`;
}

async function salvarDadosProduto() {
  const id = document.getElementById('prod-id').value;
  if (!id) return;

  const dados = {
    nome:         document.getElementById('prod-nome').value.trim(),
    tipo:         document.getElementById('prod-tipo').value,
    categoria:    document.getElementById('prod-cat').value,
    plano_cat:    document.getElementById('prod-plano-cat').value || null,
    unidade_comp: document.getElementById('prod-un-comp').value,
    unidade_uso:  document.getElementById('prod-un-uso').value,
    custo_comp:      parseMoeda('prod-custo-comp'),
    fator_conversao: parseFloat(document.getElementById('prod-fator-conv').value)  || 1,
    perda:           parseFloat(document.getElementById('prod-perda').value)        || 0,
    preco_venda:     parseMoeda('prod-preco-venda'),
    estoque_min:     parseFloat(document.getElementById('prod-est-min').value)      || 0,
    ativo:           document.getElementById('prod-ativo').checked,
  };

  const nomeAntigo = _prodAtual.nome;

  const { error } = await sb.from('est_produtos').update(dados).eq('id', id);
  if (error) { toast('Erro ao salvar: ' + error.message, 'erro'); return; }

  // Atualiza cache local
  const idx = cProdutosFT.findIndex(p => p.id === id);
  if (idx >= 0) cProdutosFT[idx] = { ...cProdutosFT[idx], ...dados };
  _prodAtual = { ..._prodAtual, ...dados };
  document.getElementById('prod-titulo').textContent = dados.nome;

  // Se o nome mudou, propaga para estrutura de contagem e mapeamentos
  if (nomeAntigo && dados.nome && nomeAntigo !== dados.nome) {
    await _renomearProdutoNaEstrutura(nomeAntigo, dados.nome);
    toast('✅ Produto atualizado e estrutura de contagem sincronizada!', 'ok');
  } else {
    toast('✅ Produto atualizado com sucesso!', 'ok');
  }

  // Recalcula todas as fichas que usam este produto como ingrediente
  await recalcularFichasDoIngrediente(id);
}

async function _renomearProdutoNaEstrutura(nomeAntigo, nomeNovo) {
  let mudouEstrutura = false;
  let mudouMapea     = false;

  // Atualiza _todasEstruturas: varre todas as unidades → setores → grupos
  Object.values(_todasEstruturas).forEach(unidade => {
    Object.values(unidade).forEach(grupos => {
      Object.keys(grupos).forEach(grupo => {
        const prods = grupos[grupo];
        if (!Array.isArray(prods)) return;
        const i = prods.indexOf(nomeAntigo);
        if (i >= 0) { prods[i] = nomeNovo; mudouEstrutura = true; }
      });
    });
  });

  // Atualiza _invAdicoes se o nome antigo aparecer nos arrays de adições
  Object.values(_invAdicoes).forEach(arr => {
    if (!Array.isArray(arr)) return;
    const i = arr.indexOf(nomeAntigo);
    if (i >= 0) { arr[i] = nomeNovo; mudouEstrutura = true; }
  });

  // Atualiza _invMapeamentos: se o nome antigo for chave, move para nova chave
  if (_invMapeamentos[nomeAntigo] !== undefined) {
    _invMapeamentos[nomeNovo] = _invMapeamentos[nomeAntigo];
    delete _invMapeamentos[nomeAntigo];
    mudouMapea = true;
  }

  const upserts = [];
  if (mudouEstrutura) upserts.push(
    sb.from('inv_configuracoes').upsert({ chave: 'estrutura', valor: _todasEstruturas }),
    sb.from('inv_configuracoes').upsert({ chave: 'adicoes',   valor: _invAdicoes }),
  );
  if (mudouMapea) upserts.push(
    sb.from('inv_configuracoes').upsert({ chave: 'mapeamentos', valor: _invMapeamentos }),
  );
  if (upserts.length) await Promise.all(upserts);

  // Re-aplica estrutura na tela atual
  if (mudouEstrutura) _aplicarEstruturaLocal(_invLocal || 'Centro');
}

async function recalcularFichasDoIngrediente(ingredienteId) {
  // Busca fichas que contêm este ingrediente
  const { data: usos } = await sb.from('est_ficha_ingredientes')
    .select('ficha_id').eq('ingrediente_id', ingredienteId);
  if (!usos?.length) return;

  const fichaIds = [...new Set(usos.map(i => i.ficha_id))];

  const { data: fichas } = await sb.from('est_fichas_tecnicas')
    .select('id,produto_id,rendimento').in('id', fichaIds).eq('ativo', true);
  if (!fichas?.length) return;

  for (const ficha of fichas) {
    const { data: ings } = await sb.from('est_ficha_ingredientes')
      .select('quantidade,ingrediente_id').eq('ficha_id', ficha.id);

    let custoTotal = 0;
    for (const ing of (ings || [])) {
      const prod = cProdutosFT.find(p => p.id === ing.ingrediente_id);
      if (!prod) continue;
      const fator = prod.fator_conversao || 1;
      const perda = prod.perda || 0;
      const rend  = 1 - (perda / 100);
      const base  = prod.custo_comp || 0;
      custoTotal += ing.quantidade * (rend > 0 ? (base / fator) / rend : 0);
    }

    const custoPorcao = ficha.rendimento > 0 ? custoTotal / ficha.rendimento : custoTotal;

    await sb.from('est_fichas_tecnicas').update({
      custo_total: custoTotal, custo_por_porcao: custoPorcao
    }).eq('id', ficha.id);

    await sb.from('est_produtos').update({ custo_comp: custoPorcao }).eq('id', ficha.produto_id);

    const iProd = cProdutosFT.findIndex(p => p.id === ficha.produto_id);
    if (iProd >= 0) cProdutosFT[iProd].custo_comp = custoPorcao;

    // Se estiver vendo o produto pai agora, atualiza o display
    if (_prodAtual?.id === ficha.produto_id) {
      setMoeda('prod-custo-comp', custoPorcao);
      atualizarCustoEfetivo();
    }
  }

  if (fichas.length > 0)
    toast(`${fichas.length} ficha(s) recalculada(s) automaticamente.`, 'ok');
}

function abrirModalNovoProduto() {
  document.getElementById('np-nome').value = '';
  document.getElementById('np-tipo').value = 'MP';
  new bootstrap.Modal(document.getElementById('modal-novo-produto')).show();
  setTimeout(() => document.getElementById('np-nome').focus(), 300);
}

async function criarProduto() {
  const nome = document.getElementById('np-nome').value.trim().toUpperCase();
  const tipo  = document.getElementById('np-tipo').value;
  if (!nome) { toast('Informe o nome do produto.', 'erro'); return; }

  const { data, error } = await sb.from('est_produtos').insert([{
    nome, tipo, ativo: true,
    unidade_comp: 'UN', unidade_uso: 'UN',
    custo_comp: 0, custo_uso: 0, preco_venda: 0, estoque_min: 0,
  }]).select('id,nome,tipo,categoria,plano_cat,unidade_comp,unidade_uso,custo_comp,custo_uso,preco_venda,estoque_min,ativo,fator_conversao,perda').single();

  if (error) { toast('Erro ao criar produto: ' + error.message, 'erro'); return; }

  cProdutosFT.push(data);
  bootstrap.Modal.getInstance(document.getElementById('modal-novo-produto')).hide();
  toast('Produto criado! Preencha os dados.', 'ok');
  abrirProduto(data.id);
}

async function excluirProduto() {
  if (!_prodAtual) return;
  if (!confirm(`Excluir o produto "${_prodAtual.nome}"? Esta ação não pode ser desfeita.`)) return;
  const { error } = await sb.from('est_produtos').delete().eq('id', _prodAtual.id);
  if (error) { toast('Não foi possível excluir — pode estar em uso em compras, fichas ou inventários.', 'erro'); return; }
  toast('Produto excluído.', 'ok');
  const idx = cProdutosFT.findIndex(p => p.id === _prodAtual.id);
  if (idx >= 0) cProdutosFT.splice(idx, 1);
  _prodAtual = null;
  irCadSb('produtos', null);
}

async function duplicarProduto() {
  if (!_prodAtual) return;
  const p = _prodAtual;

  const { data, error } = await sb.from('est_produtos').insert([{
    nome:            p.nome + ' (cópia)',
    tipo:            p.tipo            || 'MP',
    categoria:       p.categoria       || null,
    plano_cat:       p.plano_cat       || null,
    unidade_comp:    p.unidade_comp    || 'UN',
    unidade_uso:     p.unidade_uso     || 'UN',
    custo_comp:      p.custo_comp      || 0,
    custo_uso:       p.custo_uso       || 0,
    preco_venda:     p.preco_venda     || 0,
    estoque_min:     p.estoque_min     || 0,
    fator_conversao: p.fator_conversao || 1,
    perda:           p.perda           || 0,
    ativo:           true,
  }]).select('id,nome,tipo,categoria,plano_cat,unidade_comp,unidade_uso,custo_comp,custo_uso,preco_venda,estoque_min,ativo,fator_conversao,perda').single();

  if (error) { toast('Erro ao duplicar: ' + error.message, 'erro'); return; }

  cProdutosFT.push(data);
  toast('Produto duplicado! Edite o nome e salve.', 'ok');
  abrirProduto(data.id);
}

async function carregarFichaProduto() {
  if (!_prodAtual) return;
  const cont = document.getElementById('prod-ficha-conteudo');

  const { data: fichas } = await sb.from('est_fichas_tecnicas')
    .select('id,rendimento,unidade_rendimento,custo_total,custo_por_porcao')
    .eq('produto_id', _prodAtual.id)
    .eq('ativo', true);

  const ficha = fichas?.[0];

  let html = `<div class="d-flex align-items-center justify-content-between mb-3">
    <h5 class="mb-0">Ficha Técnica — ${esc(_prodAtual.nome)}</h5>
    <button class="btn btn-primary btn-sm" onclick="abrirModalFicha('${_prodAtual.id}','${ficha?.id || ''}')">
      <i class="bi bi-pencil-fill"></i> ${ficha ? 'Editar Ficha' : 'Criar Ficha Técnica'}
    </button>
  </div>`;

  if (!ficha) {
    html += `<div class="alert alert-info small">Este produto ainda não tem ficha técnica. Clique em "Criar Ficha Técnica" para criar.</div>`;
  } else {
    const { data: ings } = await sb.from('est_ficha_ingredientes')
      .select('quantidade,unidade,ingrediente_id')
      .eq('ficha_id', ficha.id);

    let custoTotalCalc = 0;
    const ingHtml = await Promise.all((ings || []).map(async ing => {
      const prod = cProdutosFT.find(x => x.id === ing.ingrediente_id);
      const fator      = prod?.fator_conversao || 1;
      const perda      = prod?.perda || 0;
      const rendimento = 1 - (perda / 100);
      const custoBase  = prod?.custo_comp || prod?.custo_uso || 0;
      const custoUnit  = rendimento > 0 ? (custoBase / fator) / rendimento : 0;
      const subtotal = custoUnit * ing.quantidade;
      custoTotalCalc += subtotal;
      return `<tr>
        <td>${esc(prod?.nome || ing.ingrediente_id)}</td>
        <td><span class="badge-tipo badge-${(prod?.tipo||'').toLowerCase()}">${prod?.tipo||'—'}</span></td>
        <td class="text-center">${ing.quantidade} ${ing.unidade}</td>
        <td class="text-center">${brl(subtotal)}</td>
      </tr>`;
    }));
    const custoPorcaoCalc = ficha.rendimento > 0 ? custoTotalCalc / ficha.rendimento : 0;

    html += `<div class="card-grafico mb-3">
      <div class="row g-3">
        <div class="col-md-3"><div class="card-kpi"><div class="kpi-label">Rendimento</div>
          <div class="kpi-val">${ficha.rendimento} ${ficha.unidade_rendimento}</div></div></div>
        <div class="col-md-3"><div class="card-kpi"><div class="kpi-label">Custo Total</div>
          <div class="kpi-val">${brl(custoTotalCalc)}</div></div></div>
        <div class="col-md-3"><div class="card-kpi"><div class="kpi-label">Custo/Porção</div>
          <div class="kpi-val">${brl(custoPorcaoCalc)}</div></div></div>
        <div class="col-md-3"><div class="card-kpi"><div class="kpi-label">Preço de Venda</div>
          <div class="kpi-val">${brl(_prodAtual.preco_venda||0)}</div></div></div>
      </div>
    </div>
    <div class="card-grafico">
      <h6 class="mb-3">Ingredientes</h6>
      <div class="table-responsive">
        <table class="table table-sm">
          <thead style="background:#1a1a2e;color:#fff;font-size:.8rem">
            <tr><th>Ingrediente</th><th>Tipo</th><th class="text-center">Quantidade</th><th class="text-center">Subtotal</th></tr>
          </thead>
          <tbody>${ingHtml.join('')}</tbody>
        </table>
      </div>
    </div>`;
  }

  cont.innerHTML = html;
}


// ═══════════════════════════════════════════════════════════════
// USUÁRIOS
// ═══════════════════════════════════════════════════════════════
async function carregarUsuarios() {
  const tbody = document.getElementById('tb-usuarios');
  tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-3">Carregando...</td></tr>';

  const { data, error } = await sbAdmin.auth.admin.listUsers();
  if (error) {
    tbody.innerHTML = `<tr><td colspan="5" class="text-danger small py-3">${error.message}</td></tr>`;
    return;
  }

  const users = (data?.users || []).sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

  const me = users.find(u => u.id === user?.id);
  if (me) {
    document.getElementById('cfg-user-nome').textContent  = me.user_metadata?.nome || me.email;
    document.getElementById('cfg-user-email').textContent = me.email;
  }

  tbody.innerHTML = users.map(u => {
    const nome    = u.user_metadata?.nome || '—';
    const isAdmin = u.id === user?.id;
    const perfil  = isAdmin
      ? '<span class="text-danger fw-bold">Administrador</span>'
      : 'Funcionário';
    const dt      = new Date(u.created_at).toLocaleDateString('pt-BR');
    const sistemas = u.user_metadata?.sistemas;
    const sisBadges = sistemas
      ? sistemas.map(s => s === 'estoque'
          ? '<span class="badge bg-primary me-1">Compras</span>'
          : '<span class="badge bg-success me-1">Financeiro</span>'
        ).join('')
      : '<span class="badge bg-secondary">Todos</span>';
    const metaNome = encodeURIComponent(nome);
    const btnPerm = !isAdmin
      ? `<button class="btn btn-sm btn-outline-secondary me-1" title="Permissões"
           onclick="abrirPermissoes('${u.id}','${esc(u.email)}','${metaNome}',${JSON.stringify(sistemas||null)})">
           <i class="bi bi-shield-lock"></i>
         </button>`
      : '';
    const btnDel = !isAdmin
      ? `<button class="btn btn-sm btn-danger" onclick="excluirUsuario('${u.id}','${esc(u.email)}')">
           <i class="bi bi-trash"></i>
         </button>`
      : '';
    return `<tr>
      <td class="fw-semibold">${esc(nome)}</td>
      <td>${esc(u.email)}</td>
      <td>${perfil}</td>
      <td>${sisBadges}</td>
      <td>${dt}</td>
      <td class="text-end">${btnPerm}${btnDel}</td>
    </tr>`;
  }).join('');
}

async function convidarFuncionario() {
  const nome  = document.getElementById('inv-nome').value.trim();
  const email = document.getElementById('inv-email').value.trim();
  const senha = document.getElementById('inv-senha').value;
  const msg   = document.getElementById('inv-msg');

  if (!nome || !email || !senha) {
    msg.textContent = 'Preencha todos os campos.';
    msg.className   = 'text-danger small mt-2';
    return;
  }

  const sistemas = [];
  if (document.getElementById('inv-sys-estoque').checked)   sistemas.push('estoque');
  if (document.getElementById('inv-sys-financeiro').checked) sistemas.push('financeiro');
  if (!sistemas.length) {
    msg.textContent = 'Selecione ao menos um sistema.';
    msg.className   = 'text-danger small mt-2';
    return;
  }

  const { error } = await sbAdmin.auth.admin.createUser({
    email,
    password: senha,
    user_metadata: { nome, sistemas },
    email_confirm: true,
  });

  if (error) {
    msg.textContent = error.message;
    msg.className   = 'text-danger small mt-2';
    return;
  }

  msg.textContent = 'Funcionário criado com sucesso!';
  msg.className   = 'text-success small mt-2';

  document.getElementById('inv-nome').value  = '';
  document.getElementById('inv-email').value = '';
  document.getElementById('inv-senha').value = '';

  setTimeout(() => {
    bootstrap.Modal.getInstance(document.getElementById('modal-convidar'))?.hide();
    msg.textContent = '';
    carregarUsuarios();
  }, 1500);
}

async function excluirUsuario(id, email) {
  if (!confirm(`Excluir o usuário ${email}?`)) return;
  const { error } = await sbAdmin.auth.admin.deleteUser(id);
  if (error) { toast(error.message, 'erro'); return; }
  toast('Usuário excluído.', 'ok');
  carregarUsuarios();
}

function abrirPermissoes(id, email, metaNome, sistemas) {
  document.getElementById('perm-user-id').value        = id;
  document.getElementById('perm-user-meta-nome').value = decodeURIComponent(metaNome);
  document.getElementById('perm-user-nome').textContent = `${decodeURIComponent(metaNome)} (${email})`;
  document.getElementById('perm-sys-estoque').checked   = !sistemas || sistemas.includes('estoque');
  document.getElementById('perm-sys-financeiro').checked = !sistemas || sistemas.includes('financeiro');
  document.getElementById('perm-msg').textContent = '';
  new bootstrap.Modal(document.getElementById('modal-perm')).show();
}

async function salvarPermissoes() {
  const id   = document.getElementById('perm-user-id').value;
  const nome = document.getElementById('perm-user-meta-nome').value;
  const msg  = document.getElementById('perm-msg');

  const sistemas = [];
  if (document.getElementById('perm-sys-estoque').checked)   sistemas.push('estoque');
  if (document.getElementById('perm-sys-financeiro').checked) sistemas.push('financeiro');

  if (!sistemas.length) {
    msg.textContent = 'Selecione ao menos um sistema.';
    msg.className   = 'text-danger small';
    return;
  }

  const { error } = await sbAdmin.auth.admin.updateUserById(id, {
    user_metadata: { nome, sistemas }
  });

  if (error) { msg.textContent = error.message; msg.className = 'text-danger small'; return; }

  msg.textContent = 'Permissões salvas!';
  msg.className   = 'text-success small';
  setTimeout(() => {
    bootstrap.Modal.getInstance(document.getElementById('modal-perm'))?.hide();
    carregarUsuarios();
  }, 1200);
}

async function alterarMinhaSenha() {
  const nova = document.getElementById('nova-senha').value;
  const conf = document.getElementById('conf-senha').value;
  const msg  = document.getElementById('senha-msg');

  if (!nova || nova.length < 6) {
    msg.textContent = 'Senha deve ter ao menos 6 caracteres.';
    msg.className   = 'text-danger small mt-2';
    return;
  }
  if (nova !== conf) {
    msg.textContent = 'As senhas não coincidem.';
    msg.className   = 'text-danger small mt-2';
    return;
  }

  const { error } = await sb.auth.updateUser({ password: nova });
  if (error) { msg.textContent = error.message; msg.className = 'text-danger small mt-2'; return; }

  msg.textContent = 'Senha alterada com sucesso!';
  msg.className   = 'text-success small mt-2';

  setTimeout(() => {
    bootstrap.Modal.getInstance(document.getElementById('modal-senha'))?.hide();
    msg.textContent = '';
    document.getElementById('nova-senha').value = '';
    document.getElementById('conf-senha').value = '';
  }, 1500);
}


// ═══════════════════════════════════════════════════════════════
// BACKUP
// ═══════════════════════════════════════════════════════════════
async function fazerBackup() {
  const btn = document.getElementById('btn-backup');
  btn.disabled    = true;
  btn.innerHTML   = '<span class="spinner-border spinner-border-sm"></span> Exportando...';

  try {
    const tabelas = [
      'est_produtos', 'est_grupos_produto',
      'est_fichas_tecnicas', 'est_ficha_ingredientes',
      'est_inventarios', 'est_inventario_itens',
    ];
    const backup = { versao: 1, data: new Date().toISOString(), tabelas: {} };

    for (const tb of tabelas) {
      const { data } = await sb.from(tb).select('*');
      backup.tabelas[tb] = data || [];
    }

    const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href     = url;
    a.download = `backup_estoque_${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    toast('Backup exportado com sucesso!', 'ok');
  } catch (e) {
    toast('Erro ao exportar: ' + e.message, 'erro');
  } finally {
    btn.disabled  = false;
    btn.innerHTML = '<i class="bi bi-download"></i> Fazer Backup Agora';
  }
}

function carregarArquivoBackup() {
  document.getElementById('inp-backup').click();
}

async function restaurarBackup(e) {
  const file = e.target.files?.[0];
  if (!file) return;

  let backup;
  try { backup = JSON.parse(await file.text()); } catch { toast('Arquivo inválido.', 'erro'); return; }
  if (!backup.tabelas) { toast('Formato de backup inválido.', 'erro'); return; }
  if (!confirm('Restaurar o backup? Os dados atuais serão substituídos nas tabelas exportadas.')) return;

  const btn = document.getElementById('btn-restaurar');
  btn.disabled  = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Restaurando...';

  try {
    for (const [tb, rows] of Object.entries(backup.tabelas)) {
      await sb.from(tb).delete().neq('id', '00000000-0000-0000-0000-000000000000');
      if (rows.length) await sb.from(tb).insert(rows);
    }
    toast('Backup restaurado! Recarregando...', 'ok');
    setTimeout(() => location.reload(), 2000);
  } catch (e) {
    toast('Erro ao restaurar: ' + e.message, 'erro');
  } finally {
    btn.disabled  = false;
    btn.innerHTML = '<i class="bi bi-upload"></i> Carregar Backup para Restaurar';
    e.target.value = '';
  }
}

function redefinirConexao() {
  if (!confirm('Redefinir a conexão com o Supabase? Você será desconectado.')) return;
  localStorage.removeItem('gc_url');
  localStorage.removeItem('gc_key');
  location.reload();
}


// ═══════════════════════════════════════════════════════════════
// INTEGRAÇÃO FINANCEIRO — CONTAS A PAGAR
// ═══════════════════════════════════════════════════════════════

function modoIntegracaoProducao() {
  return localStorage.getItem('gc_integracao_fin') === 'producao';
}

function alternarModoIntegracao(ativo) {
  const modo   = ativo ? 'producao' : 'teste';
  localStorage.setItem('gc_integracao_fin', modo);
  document.getElementById('label-integracao-fin').textContent = ativo ? 'Modo Produção' : 'Modo Teste';
  document.getElementById('badge-integracao-fin').textContent = ativo
    ? 'PRODUÇÃO — dados enviados ao financeiro' : 'TESTE — dados não são enviados';
  document.getElementById('badge-integracao-fin').style.background = ativo ? '#198754' : '#6c757d';
  document.getElementById('desc-integracao-fin').innerHTML = ativo
    ? 'Em Modo Produção: contas a pagar são <strong>gravadas de verdade</strong> no sistema financeiro.'
    : 'Em Modo Teste: mostra preview completo mas <strong>não grava</strong> nada no financeiro.';
}

// Inicializa o toggle conforme o valor salvo
function inicializarToggleIntegracao() {
  const prod = modoIntegracaoProducao();
  const el   = document.getElementById('toggle-integracao-fin');
  if (el) {
    el.checked = prod;
    alternarModoIntegracao(prod);
  }
}

function abrirAdiantamento(pedido_num, forn, fornId, total) {
  abrirGerarConta(pedido_num, forn, fornId, total, 'adiantamento');
}


function atualizarTotalGC() {
  const nota      = parseMoeda('gc-valor') || 0;
  const acrescimo = parseMoeda('gc-acrescimo') || 0;
  const total     = nota + acrescimo;
  const el = document.getElementById('gc-total-display');
  if (el) el.textContent = total > 0 ? brl(total) : '—';
}

async function abrirGerarConta(pedido_num, forn, fornId, total, tipo = 'nf') {
  if (!cCat.length) await carregarCaches();
  document.getElementById('gc-pedido-num').value             = pedido_num;
  document.getElementById('gc-fornecedor-id').value          = fornId;
  document.getElementById('gc-pedido-label').textContent     = pedido_num;
  document.getElementById('gc-fornecedor-label').textContent = forn || '—';
  document.getElementById('gc-tipo').value                   = tipo;
  setMoeda('gc-valor', total);
  setMoeda('gc-acrescimo', 0);
  atualizarTotalGC();
  document.getElementById('gc-vencimento').value = '';
  document.getElementById('gc-nf').value         = '';
  document.getElementById('gc-preview').classList.add('d-none');

  // Título e alerta informativo por tipo
  const titulo  = document.getElementById('gc-modal-title');
  const infoEl  = document.getElementById('gc-tipo-info');
  if (tipo === 'adiantamento') {
    titulo.innerHTML = '<i class="bi bi-send"></i> Enviar ao Financeiro';
    infoEl.innerHTML = `<div class="alert alert-warning py-2 small mb-2 mt-2">
      📤 <strong>Envio antecipado:</strong> O valor sairá da conta antes do recebimento.
      Após receber os itens com o valor real da NF, use <strong>"Gerar NF"</strong> para
      registrar o custo definitivo no financeiro.</div>`;
    infoEl.classList.remove('d-none');
  } else {
    titulo.innerHTML = '<i class="bi bi-arrow-left-right"></i> Gerar Conta a Pagar no Financeiro';
    infoEl.innerHTML = '';
    infoEl.classList.add('d-none');
  }

  // Busca dados do pedido (forma_pagamento + itens + acréscimo para quando _pedidosGrupos estiver vazio)
  const { data: pedRows } = await sb.from('cmp_compras')
    .select('forma_pagamento,categoria,plano_conta,quantidade,custo_unit,unidade_uso,fornecedor_id,fornecedor_nome,acrescimo')
    .eq('pedido_num', pedido_num);
  const pedRow0    = pedRows?.[0] || {};
  const formaPgto  = pedRow0.forma_pagamento || '';

  // Calcula nota e acréscimo separados para preencher os campos do modal
  if (pedRows?.length) {
    const subtotalDB  = pedRows.reduce((s, r) => s + (r.quantidade||0) * (r.custo_unit||0), 0);
    const acrescimoDB = parseFloat(pedRow0.acrescimo) || 0;
    const { data: contaRow } = await sb.from('cmp_contas_pagar')
      .select('valor').eq('pedido_num', pedido_num).maybeSingle();

    // total = cmp_contas_pagar.valor (gravado no recebimento = subtotal_recebido + acrescimo)
    // nota  = total - acrescimo  (o valor da NF sem o frete/taxa)
    const totalFinal = contaRow?.valor || subtotalDB + acrescimoDB;
    const notaFinal  = Math.max(0, totalFinal - acrescimoDB);
    setMoeda('gc-valor',    notaFinal);
    setMoeda('gc-acrescimo', acrescimoDB);
    atualizarTotalGC();
  }
  const elFP = document.getElementById('gc-forma-pgto-label');
  if (elFP) elFP.textContent = formaPgto || '—';
  const prefixoObs = tipo === 'adiantamento' ? 'Adiantamento Pedido' : 'Pedido';
  document.getElementById('gc-obs').value = formaPgto
    ? `${prefixoObs} ${pedido_num} — ${formaPgto}`
    : `${prefixoObs} ${pedido_num}`;

  // Se fornId não veio (null/vazio), resolve pelo nome ou pela linha do banco
  if (!fornId) {
    const idNoBanco  = pedRow0.fornecedor_id || null;
    const idPorNome  = !idNoBanco ? (cForn.find(f => f.nome === forn)?.id || null) : null;
    const resolvedId = idNoBanco || idPorNome || '';
    document.getElementById('gc-fornecedor-id').value = resolvedId;
  }

  // Garante que _pedidosGrupos tem os itens necessários para resolver categoria
  if (!_pedidosGrupos[pedido_num]?.itens?.length && pedRows?.length) {
    _pedidosGrupos[pedido_num] = {
      pedido_num, forn, fornecedor_id: fornId || pedRow0.fornecedor_id || '',
      itens: pedRows.map(r => ({
        categoria: r.categoria, plano_conta: r.plano_conta,
        quantidade: r.quantidade, custo_unit: r.custo_unit, unidade_uso: r.unidade_uso,
      })),
    };
  }

  // Busca categorias do banco pelo nome (garante plano_conta_id mesmo com cCat vazio)
  const g = _pedidosGrupos[pedido_num];
  const catNomes = [...new Set((g?.itens || []).map(it => it.categoria).filter(Boolean))];
  const { data: catData } = catNomes.length
    ? await sb.from('cmp_categorias').select('nome,plano_conta,plano_conta_id').in('nome', catNomes)
    : { data: [] };
  const catDbMap = {};
  (catData || []).forEach(c => { catDbMap[c.nome] = c; });

  const rateioMap = {};
  (g?.itens || []).forEach(it => {
    const catObj   = catDbMap[it.categoria] || cCat.find(c => c.nome === it.categoria);
    const pcNome   = catObj?.plano_conta || it.plano_conta || it.categoria || '—';
    const storedId = catObj?.plano_conta_id;
    const pcId     = (storedId && cPlanoConta.find(p => p.id === storedId) ? storedId : null)
      || cPlanoConta.find(p => p.nome.toLowerCase() === pcNome.toLowerCase())?.id
      || null;
    const key = pcId || pcNome;
    if (!rateioMap[key]) rateioMap[key] = { plano_conta_id: pcId, nome: pcNome, valor: 0 };
    rateioMap[key].valor += (it.quantidade || 0) * (it.custo_unit || 0);
  });
  _rateioItensAtual = Object.values(rateioMap);

  // Fallback: busca subcategorias direto do banco para itens que ainda estão sem ID
  const semId = _rateioItensAtual.filter(r => !r.plano_conta_id && r.nome !== '—');
  if (semId.length) {
    const { data: pcRows } = await sb.from('plano_contas')
      .select('id,nome,grupo_id').in('nome', semId.map(r => r.nome));
    const pcRowsSubcat = (pcRows || []).filter(p => p.grupo_id);
    if (pcRowsSubcat.length) {
      const pcMap = {};
      pcRowsSubcat.forEach(p => { pcMap[p.nome.toLowerCase()] = p.id; });
      _rateioItensAtual.forEach(r => {
        if (!r.plano_conta_id) r.plano_conta_id = pcMap[r.nome.toLowerCase()] || null;
      });
    }
  }

  const temRateio = _rateioItensAtual.length > 1;

  const rateioSection  = document.getElementById('gc-rateio-section');
  const planoSection   = document.getElementById('gc-plano-section');
  const rateioBody     = document.getElementById('gc-rateio-body');

  if (temRateio) {
    rateioSection.classList.remove('d-none');
    planoSection.classList.add('d-none');
    rateioBody.innerHTML = _rateioItensAtual.map(r =>
      `<tr><td>${esc(r.nome)}</td><td class="text-end">${brl(r.valor)}</td></tr>`
    ).join('');
  } else {
    rateioSection.classList.add('d-none');
    planoSection.classList.remove('d-none');
    document.getElementById('gc-plano-label').textContent = _rateioItensAtual[0]?.nome || '—';
  }

  // Popula dropdown de unidade e pré-seleciona pelo nome salvo no pedido
  const uniSel = document.getElementById('gc-unidade');
  if (uniSel) {
    uniSel.innerHTML = '<option value="">— Nenhuma —</option>' +
      cUnidades.map(u => `<option value="${u.id}">${esc(u.nome)}</option>`).join('');
    const gItems = (_pedidosGrupos[pedido_num]?.itens || []);
    const usoNome = gItems[0]?.unidade_uso || gItems[0]?.uso || '';
    const unidadeIdItem = cUnidades.find(u => u.nome.toLowerCase() === usoNome.toLowerCase())?.id || null;
    if (unidadeIdItem) uniSel.value = unidadeIdItem;
  }

  document.getElementById('btn-gc-label').textContent = 'Enviar Financeiro';
  document.getElementById('btn-gc-enviar').className = 'btn btn-primary';

  new bootstrap.Modal(document.getElementById('modal-gerar-conta')).show();
}

function previewContaFinanceiro() {
  const nota      = parseMoeda('gc-valor');
  const acrescimo = parseMoeda('gc-acrescimo') || 0;
  const valor     = nota + acrescimo;
  const venc   = document.getElementById('gc-vencimento').value;
  const nf     = document.getElementById('gc-nf').value.trim();
  const obs    = document.getElementById('gc-obs').value.trim();
  const pedido = document.getElementById('gc-pedido-num').value;
  const forn   = document.getElementById('gc-fornecedor-label').textContent;

  if (!nota || !venc) { toast('Informe valor e vencimento antes de visualizar.', 'erro'); return; }

  const temRateio = !document.getElementById('gc-rateio-section').classList.contains('d-none');
  const plano = temRateio ? 'Rateio' : document.getElementById('gc-plano-label').textContent;

  document.getElementById('gc-preview-dados').innerHTML = `
    <div class="row g-2">
      <div class="col-6"><strong>tipo:</strong> pagar</div>
      <div class="col-6"><strong>status:</strong> pendente</div>
      <div class="col-12"><strong>descricao:</strong> Pedido ${pedido} — ${forn}</div>
      <div class="col-3"><strong>nota:</strong> ${brl(nota)}</div>
      <div class="col-3"><strong>acréscimo:</strong> ${brl(acrescimo)}</div>
      <div class="col-3"><strong>total:</strong> ${brl(valor)}</div>
      <div class="col-3"><strong>vencimento:</strong> ${venc.split('-').reverse().join('/')}</div>
      <div class="col-6"><strong>fornecedor:</strong> ${forn}</div>
      <div class="col-6"><strong>plano_contas:</strong> ${plano}</div>
      ${obs ? `<div class="col-12"><strong>observacoes:</strong> ${obs}</div>` : ''}
    </div>`;
  document.getElementById('gc-preview').classList.remove('d-none');
}

async function confirmarGerarConta() {
  const pedido_num    = document.getElementById('gc-pedido-num').value;
  const fornecedor_id = document.getElementById('gc-fornecedor-id').value || null;
  const nota          = parseMoeda('gc-valor');
  const acrescimo_val = parseMoeda('gc-acrescimo') || 0;
  const valor         = nota + acrescimo_val;  // total = nota + acréscimo
  const vencimento    = document.getElementById('gc-vencimento').value;
  const nf_numero     = document.getElementById('gc-nf').value.trim() || null;
  const obs           = document.getElementById('gc-obs').value.trim();
  const forn_nome     = document.getElementById('gc-fornecedor-label').textContent;
  const tipo          = document.getElementById('gc-tipo').value || 'nf';

  if (!nota || nota <= 0) { toast('Informe um valor válido.', 'erro'); return; }
  if (!vencimento) { toast('Informe a data de vencimento.', 'erro'); return; }

  const temRateio             = !document.getElementById('gc-rateio-section').classList.contains('d-none');
  const plano_conta           = temRateio ? null : document.getElementById('gc-plano-label').textContent;
  const rateioItensResolvidos = temRateio ? _rateioItensAtual : [];
  const unidade_id            = document.getElementById('gc-unidade')?.value || null;

  if (tipo === 'adiantamento') {
    // Fluxo Adiantamento: cria/atualiza cmp_contas_pagar sem tocar em lancamento_id
    const { data: conta } = await sb.from('cmp_contas_pagar')
      .upsert([{ pedido_num, fornecedor: forn_nome, vencimento, valor, nf_numero, status: 'pendente' }],
              { onConflict: 'pedido_num', ignoreDuplicates: false })
      .select().single();
    await gerarContaFinanceiro({
      pedido_num, vencimento, valor, acrescimo: acrescimo_val,
      fornecedor_id, fornecedor_nome: forn_nome,
      plano_conta, nf_numero, conta_id: conta?.id || null,
      obs: obs || `Adiantamento Pedido ${pedido_num}`,
      temRateio, rateioItensResolvidos, unidade_id,
      campo_id_destino: 'adiantamento_lancamento_id',
    });
  } else {
    // Fluxo NF normal (padrão)
    const { data: conta } = await sb.from('cmp_contas_pagar')
      .upsert([{ pedido_num, fornecedor: forn_nome, vencimento, valor, nf_numero, status: 'pendente' }],
              { onConflict: 'pedido_num', ignoreDuplicates: false })
      .select().single();
    await gerarContaFinanceiro({
      pedido_num, vencimento, valor, acrescimo: acrescimo_val,
      fornecedor_id, fornecedor_nome: forn_nome,
      plano_conta, nf_numero, conta_id: conta?.id || null,
      obs: obs || `Pedido ${pedido_num}`,
      temRateio, rateioItensResolvidos, unidade_id,
      campo_id_destino: 'lancamento_id',
    });
  }

  bootstrap.Modal.getInstance(document.getElementById('modal-gerar-conta'))?.hide();
  renderPendentes();
}

async function sincronizarValoresFinanceiro() {
  if (!confirm('Isso vai atualizar o valor de TODOS os lançamentos no financeiro para refletir os valores reais recebidos no estoque.\n\nContinuar?')) return;

  // Busca todas as contas com lancamento_id e valor recebido
  const { data: contas, error } = await sb.from('cmp_contas_pagar')
    .select('id,pedido_num,lancamento_id,valor,acrescimo,fornecedor')
    .not('lancamento_id', 'is', null)
    .not('valor', 'is', null);

  if (error || !contas?.length) {
    toast('Nenhum lançamento encontrado para sincronizar.', 'erro');
    return;
  }

  let atualizados = 0, erros = 0;
  for (const c of contas) {
    // Não atualiza Comprador Externo — esses usam outro fluxo
    if (isCompExterna(c.fornecedor)) continue;

    const acrescimo = parseFloat(c.acrescimo) || 0;
    const nota      = Math.max(0, (parseFloat(c.valor) || 0) - acrescimo);

    const { error: errUpd } = await sb.from('lancamentos').update({
      valor:     nota,
      acrescimo: acrescimo,
    }).eq('id', c.lancamento_id);

    if (errUpd) erros++;
    else atualizados++;
  }

  toast(`✅ ${atualizados} lançamento(s) sincronizado(s)${erros ? ` — ${erros} erro(s)` : ''}.`, 'ok');
}

// Núcleo da finalização do Comprador Externo — chamado auto (último item) ou manual (botão Finalizar)
async function _executarFinalizarCompExt(pedido_num, conta, ref, unidade_id, nf) {
  // Total acumulado de todos os recebimentos
  const { data: todosReceb } = await sb.from('cmp_recebimentos')
    .select('total_recebido').eq('pedido_num', pedido_num);
  const totalAcumulado = (todosReceb || []).reduce((s, r) => s + (r.total_recebido || 0), 0);
  const acrescimo = parseFloat(_recebItensAbertos?.[0]?.acrescimo) || 0;

  // Detecta banco do adiantamento
  let bancoDespesa = BANCO_NUBANK_ID;
  if (conta.adiantamento_lancamento_id) {
    const { data: adLanc } = await sb.from('lancamentos').select('banco_id').eq('id', conta.adiantamento_lancamento_id).maybeSingle();
    if (adLanc?.banco_id) bancoDespesa = adLanc.banco_id;
  }

  // Busca itens recebidos de todos os recebimentos
  const { data: recebIds } = await sb.from('cmp_recebimentos').select('id').eq('pedido_num', pedido_num);
  const { data: itensTodos } = await sb.from('cmp_recebimento_itens')
    .select('*').in('recebimento_id', (recebIds||[]).map(r => r.id));

  const dataRec = new Date().toISOString().split('T')[0];
  const venc = conta.vencimento || dataRec;

  await enviarDespesaCompExterno({
    pedido_num, conta_id: conta.id,
    itensReceb: itensTodos || [],
    totalRecebido: totalAcumulado, acrescimo,
    dataRec, vencimento: venc,
    fornecedor_id: ref?.fornecedor_id || null,
    unidade_id, nf, banco_id: bancoDespesa,
  });
}

// Chamado pelo botão "Finalizar Pedido" na Aba Compras
async function finalizarPedidoCompExt(pedido_num) {
  if (!confirm(`Finalizar pedido ${pedido_num}?\nItens não entregues serão marcados como dispensados e o total recebido será enviado ao financeiro.`)) return;

  // Marca itens pendentes como dispensados
  await sb.from('cmp_compras')
    .update({ status_receb: 'dispensado' })
    .eq('pedido_num', pedido_num)
    .not('status_receb', 'in', '("recebido","dispensado","cancelado")');

  // Busca conta e referência do pedido
  const { data: conta } = await sb.from('cmp_contas_pagar')
    .select('id,adiantamento_lancamento_id,lancamento_id,vencimento').eq('pedido_num', pedido_num).maybeSingle();
  if (!conta) { toast('Conta a pagar não encontrada.', 'erro'); return; }
  if (conta.lancamento_id) { toast('Pedido já foi enviado ao financeiro.', 'erro'); return; }

  const { data: refItem } = await sb.from('cmp_compras')
    .select('fornecedor_nome,fornecedor_id,comprador,unidade_uso').eq('pedido_num', pedido_num).limit(1).maybeSingle();

  if (!cUnidades.length) await carregarCaches();
  const unidade_id = cUnidades.find(u => u.nome.toLowerCase() === (refItem?.unidade_uso||'').toLowerCase())?.id || null;

  await _executarFinalizarCompExt(pedido_num, conta, refItem, unidade_id, null);
  toast(`${pedido_num} finalizado e enviado ao financeiro! ✅`, 'ok');
  renderPendentes();
}

async function _executarFinalizarRegular(pedido_num, conta, ref, unidade_id, nf) {
  const { data: todosReceb } = await sb.from('cmp_recebimentos')
    .select('total_recebido').eq('pedido_num', pedido_num);
  const totalAcumulado = (todosReceb || []).reduce((s, r) => s + (r.total_recebido || 0), 0);
  if (!totalAcumulado) return;

  const dataRec = new Date().toISOString().split('T')[0];
  const venc = conta.vencimento || dataRec;

  await gerarContaFinanceiro({
    pedido_num, vencimento: venc, valor: totalAcumulado, acrescimo: 0,
    fornecedor_id: ref?.fornecedor_id || null,
    fornecedor_nome: ref?.fornecedor_nome || '',
    plano_conta: ref?.plano_conta || '',
    nf_numero: nf, conta_id: conta.id, unidade_id,
    obs: nf ? `Pedido ${pedido_num} — NF ${nf}` : `Pedido ${pedido_num}`,
  });
}

async function finalizarPedidoRegular(pedido_num) {
  if (!confirm(`Fechar pedido ${pedido_num}?\nItens não entregues serão marcados como dispensados e o total recebido será enviado ao financeiro.`)) return;

  await sb.from('cmp_compras')
    .update({ status_receb: 'dispensado' })
    .eq('pedido_num', pedido_num)
    .not('status_receb', 'in', '("recebido","dispensado","cancelado")');

  const { data: conta } = await sb.from('cmp_contas_pagar')
    .select('id,lancamento_id,vencimento').eq('pedido_num', pedido_num).maybeSingle();

  if (conta && !conta.lancamento_id) {
    const { data: refItem } = await sb.from('cmp_compras')
      .select('fornecedor_nome,fornecedor_id,plano_conta,unidade_uso').eq('pedido_num', pedido_num).limit(1).maybeSingle();
    if (!cUnidades.length) await carregarCaches();
    const unidade_id = cUnidades.find(u => u.nome.toLowerCase() === (refItem?.unidade_uso||'').toLowerCase())?.id || null;
    await _executarFinalizarRegular(pedido_num, conta, refItem, unidade_id, null);
  }

  toast(`${pedido_num} fechado e enviado ao financeiro ✅`, 'ok');
  renderPendentes();
}

async function enviarDespesaCompExterno({ pedido_num, conta_id, itensReceb, totalRecebido, acrescimo, dataRec, vencimento, fornecedor_id, unidade_id, nf, banco_id }) {
  if (!cCat.length || !cPlanoConta.length) await carregarCaches();

  const totalItens = Math.max(0, totalRecebido - acrescimo);

  // Agrupa por plano_conta usando os itens originais abertos
  const grupos = {};
  for (const ir of itensReceb) {
    const orig = _recebItensAbertos.find(o => o.id === ir.compra_id);
    const plano = orig?.plano_conta || '';
    if (!grupos[plano]) grupos[plano] = { plano_conta: plano, subtotal: 0 };
    grupos[plano].subtotal += ir.total_recebido;
  }
  const gruposList = Object.values(grupos);
  const temRateio  = gruposList.length > 1;

  // Resolve plano_conta_id por grupo
  for (const g of gruposList) {
    const cat = cCat.find(c => c.plano_conta === g.plano_conta);
    g.plano_conta_id = (cat?.plano_conta_id && cPlanoConta.find(p => p.id === cat.plano_conta_id))
      ? cat.plano_conta_id
      : cPlanoConta.find(p => p.nome.toLowerCase() === g.plano_conta.toLowerCase())?.id || null;
  }

  const { data: lanc, error } = await sb.from('lancamentos').insert([{
    descricao:      `Pedido ${pedido_num} — Comprador Externo`,
    valor:          totalItens,
    acrescimo:      acrescimo,
    vencimento,
    tipo:           'pagar',
    status:         banco_id === BANCO_NUBANK_ID ? 'pendente' : 'pago',
    data_pagamento: banco_id === BANCO_NUBANK_ID ? null : dataRec,
    banco_id:       banco_id || BANCO_NUBANK_ID,
    fornecedor_id:  fornecedor_id || null,
    plano_conta_id: temRateio ? null : (gruposList[0]?.plano_conta_id || null),
    numero_pedido:  pedido_num,
    observacoes:    nf ? `Pedido ${pedido_num} — NF ${nf}` : `Pedido ${pedido_num}`,
    desconto:       0,
    tem_rateio:     temRateio,
    unidade_id:     unidade_id || null,
  }]).select('id').single();

  if (error) { toast('Erro ao enviar despesa ao financeiro: ' + error.message, 'erro'); return; }

  if (temRateio && lanc?.id && gruposList.length) {
    await sb.from('rateio_itens').insert(
      gruposList.map(g => ({ lancamento_id: lanc.id, plano_conta_id: g.plano_conta_id, valor: g.subtotal, descricao: '' }))
    );
  }

  if (conta_id && lanc?.id) {
    await sb.from('cmp_contas_pagar').update({ lancamento_id: lanc.id }).eq('id', conta_id);
  }
}

async function gerarContaFinanceiro({ pedido_num, vencimento, valor, acrescimo = 0, fornecedor_id,
  fornecedor_nome, plano_conta, nf_numero, conta_id, obs, temRateio = false, rateioItensResolvidos = [], unidade_id = null,
  campo_id_destino = 'lancamento_id' }) {

  const producao = modoIntegracaoProducao();

  // Resolve plano_conta_id do plano único (sem rateio) — valida que é subcategoria
  let plano_conta_id = null;
  if (!temRateio && plano_conta && plano_conta !== '—') {
    const catComPlano = cCat.find(c => c.plano_conta === plano_conta);
    const storedId = catComPlano?.plano_conta_id;
    plano_conta_id = (storedId && cPlanoConta.find(p => p.id === storedId) ? storedId : null)
      || cPlanoConta.find(p => p.nome.toLowerCase() === plano_conta.toLowerCase())?.id
      || null;
  }

  // Rateio: usa itens já resolvidos (plano_conta_id vem direto de cCat)
  const rateioItens = temRateio
    ? rateioItensResolvidos.map(r => ({ plano_conta_id: r.plano_conta_id, valor: r.valor, descricao: '' }))
    : [];

  const dadosBase = {
    descricao:      `Pedido ${pedido_num} — ${fornecedor_nome}`,
    valor:          valor - acrescimo,  // valor da nota sem acréscimo
    vencimento,
    tipo:           'pagar',
    status:         'pendente',
    fornecedor_id:  fornecedor_id || null,
    plano_conta_id: plano_conta_id,
    numero_pedido:  nf_numero || pedido_num,
    observacoes:    obs || null,
    acrescimo:      acrescimo,          // acréscimo no campo correto do financeiro
    desconto:       0,
    tem_rateio:     temRateio,
    unidade_id:     unidade_id || null,
  };

  if (!producao) {
    // Modo Teste — grava em lancamentos_rascunho
    const { data: existente } = await sb.from('lancamentos_rascunho').select('id').eq('pedido_num', pedido_num).limit(1);
    if (existente?.length) { toast(`Rascunho para ${pedido_num} já existe no financeiro.`, 'erro'); return; }

    const { data_pagamento: _, tem_rateio: tr, ...dadosRascunho } = { data_pagamento: null, ...dadosBase };
    const { data: rasc, error: errRasc } = await sb.from('lancamentos_rascunho').insert([{
      ...dadosRascunho,
      tem_rateio: temRateio,
      pedido_num,
      conta_id: conta_id || null,
    }]).select('id').single();
    if (errRasc) { toast('Erro ao salvar rascunho: ' + errRasc.message, 'erro'); return; }

    // Grava itens de rateio do rascunho
    if (temRateio && rasc?.id && rateioItens.length) {
      const { error: errRateio } = await sb.from('rascunho_rateio_itens').insert(
        rateioItens.map(r => ({ ...r, rascunho_id: rasc.id }))
      );
      if (errRateio) { toast('Aviso: rateio não gravado — ' + errRateio.message, 'erro'); return; }
    } else if (temRateio) {
      toast('Aviso: nenhum item de rateio encontrado para gravar.', 'erro'); return;
    }

    toast(`🧪 Rascunho enviado ao financeiro! ${brl(valor)} — venc. ${vencimento.split('-').reverse().join('/')}`, 'ok');
    return;
  }

  // Modo Produção — grava em lancamentos
  const { data: lancExist } = await sb.from('lancamentos').select('id').eq('numero_pedido', pedido_num).limit(1);
  if (lancExist?.length) { toast(`Lançamento para ${pedido_num} já existe no financeiro.`, 'erro'); return; }

  const { data: lanc, error } = await sb.from('lancamentos').insert([{
    ...dadosBase, data_pagamento: null,
  }]).select('id').single();
  if (error) { toast('Erro ao gerar no financeiro: ' + error.message, 'erro'); return; }

  // Grava rateio_itens
  if (temRateio && lanc?.id && rateioItens.length) {
    const { error: errRateio } = await sb.from('rateio_itens').insert(
      rateioItens.map(r => ({ ...r, lancamento_id: lanc.id }))
    );
    if (errRateio) toast('Aviso: rateio não gravado — ' + errRateio.message, 'erro');
  }

  // Registra o id do lançamento no campo correto (lancamento_id ou adiantamento_lancamento_id)
  if (conta_id && lanc?.id) {
    await sb.from('cmp_contas_pagar').update({ [campo_id_destino]: lanc.id }).eq('id', conta_id);
  }

  toast(`✅ Conta gerada no financeiro! ${brl(valor)} — venc. ${vencimento.split('-').reverse().join('/')}`, 'ok');
}


// ═══════════════════════════════════════════════════════════════
// AJUSTE HISTÓRICO — COMPRADOR EXTERNO
// ═══════════════════════════════════════════════════════════════

const BANCO_SANTANDER_ID = '2bc3c4df-923b-407b-91d1-99b0bee89882';
const BANCO_NUBANK_ID    = 'c342ece3-9015-40d6-a5ce-72c668f17395';
const COMP_EXT_FORN_ID   = 'c194fd5b-1ba9-4229-a416-2e7cdc05f287';

const FORNEC_EXT_HISTORICO = [
  'assaí atacadista','assai atacadista','sendas distribuidora',
  'cdl centro','atack hiperatacadao','atack hiperatacadão',
  'medeiros comercio','vitória supermercados','vitoria supermercados',
  'supermercados db','feira manaus moderna',
  'atacadao','atacadão','comprador externo',
];

function isFornecExtHistorico(nome) {
  const n = norm(nome || '');
  return FORNEC_EXT_HISTORICO.some(f => n.includes(norm(f)));
}

let _ajusteRows = []; // cache das linhas carregadas

async function abrirAjusteHistoricoCompExterno() {
  const modal = document.getElementById('modal-ajuste-comp-ext');
  modal.classList.remove('d-none');
  document.getElementById('ajuste-comp-ext-body').innerHTML =
    '<tr><td colspan="7" class="text-center py-4">Carregando...</td></tr>';

  // 1. Agrupar pedidos de fornecedores externos
  const { data: compras } = await sb.from('cmp_compras')
    .select('pedido_num,fornecedor_nome,total,status_receb,unidade_uso')
    .order('pedido_num', { ascending: true });

  const pedidos = {};
  for (const r of compras || []) {
    if (!isFornecExtHistorico(r.fornecedor_nome)) continue;
    const pn = r.pedido_num;
    if (!pedidos[pn]) pedidos[pn] = { forn: r.fornecedor_nome, totalEst: 0, recebido: false, unidade_uso: r.unidade_uso || '' };
    pedidos[pn].totalEst += parseFloat(r.total || 0);
    if (r.status_receb === 'recebido') pedidos[pn].recebido = true;
  }

  // 2. Buscar cmp_contas_pagar para esses pedidos
  const nums = Object.keys(pedidos);
  const { data: contas } = await sb.from('cmp_contas_pagar')
    .select('id,pedido_num,valor,data_receb,lancamento_id,adiantamento_lancamento_id')
    .in('pedido_num', nums);
  const contasIdx = {};
  for (const c of contas || []) contasIdx[c.pedido_num] = c;

  // 3. Buscar lançamentos do financeiro por número do pedido
  const lancBusca = {};
  for (const pn of nums) {
    const numPuro = pn.replace(/^#+/, '');
    const { data: ll } = await sb.from('lancamentos')
      .select('id,descricao,valor,status,tipo,ofx_id,data_pagamento')
      .ilike('descricao', `Pedido #${numPuro}%`)
      .eq('tipo', 'pagar')
      .order('valor', { ascending: false });
    const match = (ll || []).find(l => l.descricao && l.descricao.startsWith(`Pedido #${numPuro}`));
    if (match) lancBusca[pn] = match;
  }

  // 4. Montar rows
  _ajusteRows = nums.map(pn => ({
    pn,
    forn:       pedidos[pn].forn,
    totalEst:   pedidos[pn].totalEst,
    recebido:   pedidos[pn].recebido,
    unidade_uso: pedidos[pn].unidade_uso,
    conta:      contasIdx[pn] || null,
    lanc:       lancBusca[pn] || null,
    convertido: false,
    despesaOk:  !!(contasIdx[pn]?.lancamento_id),
  }));

  renderAjusteHistoricoRows();
}

function renderAjusteHistoricoRows() {
  const tbody = document.getElementById('ajuste-comp-ext-body');
  tbody.innerHTML = _ajusteRows.map((r, i) => {
    const lancVal  = r.lanc ? brl(r.lanc.valor) : '—';
    const lancSt   = r.lanc ? (r.lanc.ofx_id ? '✅ Conciliado' : '⏳ Pendente') : '—';
    const estVal   = brl(r.totalEst);
    const recSt    = r.recebido ? '✅ Sim' : '❌ Não';
    const fornShort = r.forn.length > 22 ? r.forn.slice(0,22)+'…' : r.forn;

    let acoes = '';
    if (r.convertido) {
      acoes = '<span class="badge bg-success">Transferência criada</span>';
    } else if (!r.lanc) {
      acoes = '<span class="text-muted small">Sem lançamento no financeiro</span>';
    } else {
      acoes = `<button class="btn btn-sm btn-outline-primary me-1" onclick="converterParaTransferenciaHistorico(${i})">
        🔄 Converter
      </button>`;
    }

    if (r.recebido && !r.despesaOk) {
      acoes += ` <button class="btn btn-sm btn-outline-success" onclick="registrarDespesaRealHistorico(${i})">
        💰 Despesa Real
      </button>`;
    } else if (r.despesaOk) {
      acoes += ' <span class="badge bg-success ms-1">Despesa ok</span>';
    }

    return `<tr>
      <td class="small">${r.pn}</td>
      <td class="small">${fornShort}</td>
      <td class="small text-end">${lancVal}</td>
      <td class="small text-end">${estVal}</td>
      <td class="small">${lancSt}</td>
      <td class="small">${recSt}</td>
      <td>${acoes}</td>
    </tr>`;
  }).join('');
}

async function converterParaTransferenciaHistorico(idx) {
  const r = _ajusteRows[idx];
  if (!r?.lanc) return;
  const lancId = r.lanc.id;
  const valor  = r.lanc.valor;
  const data   = r.lanc.data_pagamento || new Date().toISOString().split('T')[0];

  if (!confirm(`Converter adiantamento do ${r.pn} (${brl(valor)}) em Transferência Santander → Nubank?\n\nO lançamento atual será excluído. Você precisará re-conciliar essa entrada no extrato do Santander.`)) return;

  // 1. Criar transferência
  const { error: errT } = await sb.from('transferencias').insert([{
    banco_origem_id:  BANCO_SANTANDER_ID,
    banco_destino_id: BANCO_NUBANK_ID,
    valor,
    data,
    descricao: `Adiantamento ${r.pn} — Comprador Externo`,
  }]);
  if (errT) { toast('Erro ao criar transferência: ' + errT.message, 'erro'); return; }

  // 2. Excluir lançamento antigo
  const { error: errD } = await sb.from('lancamentos').delete().eq('id', lancId);
  if (errD) { toast('Erro ao excluir lançamento: ' + errD.message, 'erro'); return; }

  _ajusteRows[idx].convertido = true;
  _ajusteRows[idx].lanc = null;
  renderAjusteHistoricoRows();
  toast(`✅ ${r.pn} convertido para Transferência Santander→Nubank!`, 'ok');
}

async function registrarDespesaRealHistorico(idx) {
  const r = _ajusteRows[idx];
  if (!r?.recebido) return;

  // Itens recebidos desse pedido
  const { data: itens } = await sb.from('cmp_compras')
    .select('total,plano_conta')
    .eq('pedido_num', r.pn)
    .eq('status_receb', 'recebido');

  if (!itens?.length) { toast('Nenhum item recebido encontrado.', 'erro'); return; }

  const dataRec = r.conta?.data_receb || new Date().toISOString().split('T')[0];
  const totalReal = (itens).reduce((s, i) => s + parseFloat(i.total || 0), 0);

  // Agrupar por plano_conta
  const grupos = {};
  for (const it of itens) {
    const k = it.plano_conta || '';
    if (!grupos[k]) grupos[k] = 0;
    grupos[k] += parseFloat(it.total || 0);
  }
  const gruposList = Object.entries(grupos).map(([plano, subtotal]) => ({ plano, subtotal }));

  if (!cPlanoConta.length) await carregarCaches();
  for (const g of gruposList) {
    g.plano_conta_id = cPlanoConta.find(p => norm(p.nome) === norm(g.plano))?.id || null;
  }

  const temRateio = gruposList.length > 1;
  if (!cUnidades.length) await carregarCaches();
  const unidade_id = cUnidades.find(u => norm(u.nome) === norm(r.unidade_uso))?.id || null;

  const { data: lanc, error } = await sb.from('lancamentos').insert([{
    descricao:      `Pedido ${r.pn} — Comprador Externo`,
    valor:          totalReal,
    acrescimo:      0,
    vencimento:     dataRec,
    tipo:           'pagar',
    status:         'pago',
    data_pagamento: dataRec,
    banco_id:       BANCO_NUBANK_ID,
    fornecedor_id:  COMP_EXT_FORN_ID,
    plano_conta_id: temRateio ? null : (gruposList[0]?.plano_conta_id || null),
    numero_pedido:  r.pn,
    desconto:       0,
    tem_rateio:     temRateio,
    unidade_id:     unidade_id || null,
  }]).select('id').single();

  if (error) { toast('Erro ao criar despesa: ' + error.message, 'erro'); return; }

  if (temRateio && lanc?.id && gruposList.length) {
    await sb.from('rateio_itens').insert(
      gruposList.map(g => ({ lancamento_id: lanc.id, plano_conta_id: g.plano_conta_id, valor: g.subtotal, descricao: '' }))
    );
  }

  if (r.conta?.id && lanc?.id) {
    await sb.from('cmp_contas_pagar').update({ lancamento_id: lanc.id }).eq('id', r.conta.id);
  }

  _ajusteRows[idx].despesaOk = true;
  renderAjusteHistoricoRows();
  toast(`✅ Despesa real do ${r.pn} registrada no financeiro (${brl(totalReal)})!`, 'ok');
}

function fecharAjusteHistoricoCompExterno() {
  document.getElementById('modal-ajuste-comp-ext').classList.add('d-none');
}

// ─── SALDO ESTOQUE DA LOJA ────────────────────────────────────────
const _SETOR_EMOJI = { CHURRASQUEIRA:'🔥', COZINHA:'🍳', BAR:'🍹', SALAO:'🪑', ASG:'🧹', DELIVERY:'🛵' };
const _SETOR_COR   = { CHURRASQUEIRA:'#dc3545', COZINHA:'#fd7e14', BAR:'#6f42c1', SALAO:'#0d6efd', ASG:'#20c997', DELIVERY:'#e6ac00' };
const _SETOR_LABEL = { CHURRASQUEIRA:'Churrasqueira', COZINHA:'Cozinha', BAR:'Bar', SALAO:'Salão', ASG:'ASG', DELIVERY:'Delivery' };

let _saldoList   = [];
let _saldoGrupo  = null;
let _saldoMatrix = {};
let _saldoSetores = [];

async function carregarSaldo() {
  if (!cProdutosFT.length) await carregarProdutosFT();
  if (!Object.keys(_invMapeamentos).length) await carregarMapeamentosInv();

  const estrutura = INVENTARIO_ESTRUTURA['ESTOQUE DA LOJA'] || {};
  const grupos    = Object.keys(estrutura);

  const container = document.getElementById('saldo-grupo-btns');
  if (container) {
    container.innerHTML = grupos.map(g =>
      `<button class="saldo-grupo-btn" data-grupo="${esc(g)}"
        onclick="selecionarGrupoSaldo('${esc(g)}')">${esc(g)}</button>`
    ).join('');
  }

  if (!_saldoGrupo && grupos.length) await selecionarGrupoSaldo(grupos[0]);
  else if (_saldoGrupo)              await selecionarGrupoSaldo(_saldoGrupo);
}

async function selecionarGrupoSaldo(grupo) {
  _saldoGrupo = grupo;
  document.querySelectorAll('.saldo-grupo-btn').forEach(b => {
    b.className = 'saldo-grupo-btn' + (b.dataset.grupo === grupo ? ' ativo' : '');
  });

  const estrutura = INVENTARIO_ESTRUTURA['ESTOQUE DA LOJA'] || {};
  const nomes = estrutura[grupo] || [];

  // Lista de produtos deste grupo
  _saldoList = nomes.map(nome => {
    const nomeBusca = _invMapeamentos[nome] || nome;
    const prod = cProdutosFT.find(p => norm(p.nome.trim()) === norm(nomeBusca.trim()));
    return { nome, produto_id: prod?.id || null, unidade: prod?.unidade_comp || '', saldo: 0 };
  });

  // Setores fixos (sempre todos)
  _saldoSetores = Object.keys(INVENTARIO_ESTRUTURA).filter(s => s !== 'ESTOQUE DA LOJA');
  const todosLocais = ['ESTOQUE_LOJA', ..._saldoSetores];

  // Saldo de todos os locais via est_saldo_local
  const ids = _saldoList.filter(p => p.produto_id).map(p => p.produto_id);
  const { data: saldos } = ids.length
    ? await sb.from('est_saldo_local').select('produto_id,local,saldo').in('produto_id', ids)
    : { data: [] };

  // Mapa: produto_id → { local → saldo }
  _saldoMatrix = {};
  (saldos || []).forEach(s => {
    if (!_saldoMatrix[s.produto_id]) _saldoMatrix[s.produto_id] = {};
    _saldoMatrix[s.produto_id][s.local] = Number(s.saldo);
  });
  _saldoList.forEach(p => {
    if (p.produto_id) p.saldo = _saldoMatrix[p.produto_id]?.['ESTOQUE_LOJA'] ?? 0;
  });

  renderSaldo();
}

function renderSaldo() {
  const busca = norm(document.getElementById('saldo-busca')?.value || '');
  const filtrado = _saldoList.filter(p => !busca || norm(p.nome).includes(busca));

  document.getElementById('saldo-contador').textContent = `${filtrado.length} produto(s)`;

  const thead = document.getElementById('thead-saldo');
  const tbody = document.getElementById('lst-saldo');
  if (!filtrado.length) {
    if (thead) thead.innerHTML = '';
    tbody.innerHTML = '<tr><td class="text-center text-muted py-4">Nenhum produto encontrado.</td></tr>';
    return;
  }

  // Header
  if (thead) {
    thead.innerHTML = `<tr style="background:#1a1a2e;color:#fff">
      <th style="min-width:200px;padding:.75rem 1rem">Produto</th>
      <th class="text-center" style="min-width:60px">Un.</th>
      <th class="text-center" style="min-width:120px;background:#166534;color:#fff;border-left:3px solid #16a34a">
        🏪 Estoque<br><small style="font-weight:400;opacity:.85;font-size:.7rem">da Loja</small>
      </th>
      ${_saldoSetores.map(s => {
        const cor = _SETOR_COR[s] || '#6c757d';
        return `<th class="text-center" style="min-width:100px;background:${cor}22;color:${cor};border-top:3px solid ${cor}">
          ${_SETOR_EMOJI[s] || ''} ${_SETOR_LABEL[s] || s}<br>
          <small style="font-weight:400;font-size:.68rem;opacity:.75">últ. contagem</small>
        </th>`;
      }).join('')}
      <th class="text-center" style="min-width:90px;background:#1a1a2e;color:#ffc107;border-left:2px solid #ffc107">
        Total
      </th>
    </tr>`;
  }

  tbody.innerHTML = filtrado.map((p, idx) => {
    const key      = p.produto_id || norm(p.nome);
    const saldoFmt = p.saldo % 1 === 0 ? String(p.saldo) : parseFloat(p.saldo).toFixed(3).replace(/\.?0+$/, '');
    const semProd  = !p.produto_id ? ' <span class="text-danger" title="Não cadastrado">⚠</span>' : '';
    const bgRow    = idx % 2 === 0 ? '#fff' : '#f8fffe';

    let total = p.saldo;
    const setorCells = _saldoSetores.map(s => {
      const cor = _SETOR_COR[s] || '#6c757d';
      const val = p.produto_id ? (_saldoMatrix[p.produto_id]?.[s]) : undefined;
      if (val === undefined) return `<td class="text-center" style="background:#f8f9fa;color:#ccc;font-size:.8rem">—</td>`;
      total += val;
      const numBg  = val <= 0 ? '#fff5f5' : bgRow;
      const numCor = val <= 0 ? '#dc3545' : '#212529';
      return `<td class="text-center fw-semibold" style="background:${numBg};color:${numCor};border-left:1px solid ${cor}22">${val}</td>`;
    }).join('');

    const elBg     = p.saldo <= 0 ? '#fff5f5' : '#f0fdf4';
    const elCor    = p.saldo <= 0 ? '#dc3545' : '#166534';
    const totalFmt = total % 1 === 0 ? String(total) : parseFloat(total).toFixed(3).replace(/\.?0+$/, '');
    const totalCor = total <= 0 ? '#dc3545' : '#b45309';

    const elCell = p.produto_id
      ? `<div class="d-flex align-items-center justify-content-center gap-1">
           <span class="fw-bold" style="color:${elCor};min-width:36px">${saldoFmt}</span>
           <button class="btn btn-link btn-sm p-0" style="color:#16a34a;font-size:.7rem;line-height:1"
             title="Ajustar saldo" onclick="ajustarSaldoLocal('${p.produto_id}','ESTOQUE_LOJA','${esc(p.nome)}')">
             ✏️
           </button>
         </div>`
      : '<span class="text-muted">—</span>';

    return `<tr style="background:${bgRow}">
      <td style="padding:.6rem 1rem"><strong>${esc(p.nome)}</strong>${semProd}</td>
      <td class="text-center text-muted small">${esc(p.unidade || '—')}</td>
      <td class="text-center" style="background:${elBg};border-left:3px solid #16a34a">${elCell}</td>
      ${setorCells}
      <td class="text-center fw-bold" style="border-left:2px solid #ffc10733;color:${totalCor};font-size:1rem">${totalFmt}</td>
    </tr>`;
  }).join('');
}

async function ajustarSaldoLocal(produto_id, local, nome) {
  const atual = _saldoMatrix[produto_id]?.[local] ?? 0;
  const novoStr = prompt(`Ajustar saldo de "${nome}" (${local})\nValor atual: ${atual}\n\nNovo saldo:`, atual);
  if (novoStr === null) return;
  const novoSaldo = parseQtd(novoStr);
  const { error } = await sb.from('est_saldo_local')
    .upsert({ produto_id, local, saldo: novoSaldo, updated_at: new Date().toISOString() });
  if (error) { toast('Erro: ' + error.message, 'erro'); return; }
  if (!_saldoMatrix[produto_id]) _saldoMatrix[produto_id] = {};
  _saldoMatrix[produto_id][local] = novoSaldo;
  const item = _saldoList.find(p => p.produto_id === produto_id);
  if (item && local === 'ESTOQUE_LOJA') item.saldo = novoSaldo;
  toast('Saldo ajustado.', 'ok');
  renderSaldo();
}

// ─── GERENCIAR SETORES / GRUPOS POR UNIDADE ──────────────────────

async function _salvarEstruturaSupabase() {
  await sb.from('inv_configuracoes').upsert({ chave: 'estrutura', valor: _todasEstruturas });
  _aplicarEstruturaLocal(_invLocal || 'Centro');
}

function gerenciarSetoresUnidade() {
  const local = _invLocal || 'Centro';
  document.getElementById('ger-setor-unidade').textContent = local.toUpperCase();

  // All known sectors = union of all units (excluding ESTOQUE DA LOJA)
  const todosSetores = new Set();
  Object.values(_todasEstruturas).forEach(est => {
    Object.keys(est || {}).forEach(s => { if (s !== 'ESTOQUE DA LOJA') todosSetores.add(s); });
  });

  const ativos = new Set(Object.keys(_todasEstruturas[local] || {}).filter(s => s !== 'ESTOQUE DA LOJA'));

  document.getElementById('ger-setor-lista').innerHTML = [...todosSetores].map(s => `
    <div class="form-check">
      <input class="form-check-input" type="checkbox" id="ger-cb-${s.replace(/\W/g,'_')}" value="${esc(s)}" ${ativos.has(s) ? 'checked' : ''}>
      <label class="form-check-label" for="ger-cb-${s.replace(/\W/g,'_')}">${esc(s)}</label>
    </div>`).join('');

  document.getElementById('ger-setor-novo').value = '';
  new bootstrap.Modal(document.getElementById('modal-gerenciar-setores')).show();
}

async function adicionarSetorNaUnidade() {
  const inp = document.getElementById('ger-setor-novo');
  const nome = (inp?.value || '').trim().toUpperCase();
  if (!nome) return;

  const li = document.getElementById('ger-setor-lista');
  const id = `ger-cb-${nome.replace(/\W/g,'_')}`;
  if (!document.getElementById(id)) {
    li.insertAdjacentHTML('beforeend', `
      <div class="form-check">
        <input class="form-check-input" type="checkbox" id="${id}" value="${esc(nome)}" checked>
        <label class="form-check-label" for="${id}">${esc(nome)}</label>
      </div>`);
  }
  inp.value = '';
}

async function salvarSetoresUnidade() {
  const local = _invLocal || 'Centro';
  if (!_todasEstruturas[local]) _todasEstruturas[local] = {};
  const est = _todasEstruturas[local];

  // Collect checked sectors
  const checados = [...document.querySelectorAll('#ger-setor-lista .form-check-input:checked')].map(cb => cb.value);
  const todos = [...document.querySelectorAll('#ger-setor-lista .form-check-input')].map(cb => cb.value);

  // Add new sectors (checked, not yet in est)
  checados.forEach(s => { if (!est[s]) est[s] = {}; });
  // Remove unchecked sectors (with confirmation if they have data)
  todos.filter(s => !checados.includes(s)).forEach(s => {
    if (est[s] && Object.keys(est[s]).length > 0) {
      if (!confirm(`Remover setor "${s}" e todos os seus grupos/produtos desta unidade?`)) return;
    }
    delete est[s];
  });

  await _salvarEstruturaSupabase();
  bootstrap.Modal.getInstance(document.getElementById('modal-gerenciar-setores'))?.hide();

  // Re-render setor buttons
  _renderizarSetoresBtns();
  toast('Setores atualizados!', 'ok');
}

function _renderizarSetoresBtns() {
  const local = _invLocal || 'Centro';
  const setores = Object.keys(_todasEstruturas[local] || {}).filter(s => s !== 'ESTOQUE DA LOJA');
  const container = document.getElementById('inv-setor-btns');
  if (!container) return;

  container.innerHTML = setores.map(s => {
    const ativo = s === _invSetor ? ' ativo' : '';
    return `<button class="saldo-grupo-btn inv-setor-btn${ativo}" data-setor="${esc(s)}" onclick="selecionarSetorInv('${esc(s)}')">${esc(s)}</button>`;
  }).join('') +
    `<button class="saldo-grupo-btn inv-setor-btn inv-setor-el${_invSetor === 'ESTOQUE DA LOJA' ? ' ativo' : ''}" data-setor="ESTOQUE DA LOJA" onclick="selecionarSetorInv('ESTOQUE DA LOJA')">🏪 ESTOQUE DA LOJA</button>`;
}

async function adicionarGrupoUnidade() {
  const local = _invLocal || 'Centro';
  const setor = _invSetor;
  if (!setor || setor === 'ESTOQUE DA LOJA') { toast('Selecione um setor primeiro.', 'erro'); return; }

  const nome = (prompt('Nome do novo grupo:') || '').trim().toUpperCase();
  if (!nome) return;

  if (!_todasEstruturas[local]) _todasEstruturas[local] = {};
  if (!_todasEstruturas[local][setor]) _todasEstruturas[local][setor] = {};
  if (_todasEstruturas[local][setor][nome]) { toast('Grupo já existe.', 'erro'); return; }

  _todasEstruturas[local][setor][nome] = [];
  await _salvarEstruturaSupabase();
  selecionarSetorInv(_invSetor);
  toast(`Grupo ${nome} adicionado!`, 'ok');
}

async function removerGrupoUnidade() {
  const local = _invLocal || 'Centro';
  const setor = _invSetor;
  const grupo = _invGrupo;
  if (!setor || !grupo) { toast('Selecione um grupo primeiro.', 'erro'); return; }
  if (!confirm(`Remover grupo "${grupo}" do setor "${setor}"?`)) return;

  delete _todasEstruturas[local]?.[setor]?.[grupo];
  await _salvarEstruturaSupabase();
  _invGrupo = null;
  _invProds = [];
  document.getElementById('inv-tabela-section')?.classList.add('d-none');
  selecionarSetorInv(_invSetor);
  toast(`Grupo ${grupo} removido.`, 'ok');
}
