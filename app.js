'use strict';

// ═══════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════
let sb      = null;   // supabase client (anon)
let sbAdmin = null;   // supabase client (service_role)
let user = null;   // logged-in user

// caches
let cForn   = [];    // fornecedores
let cCat    = [];    // categorias
let cTipo   = [];    // tipos_produto
let cComp   = [];    // compradores
let cProd   = [];    // product names learned from past purchases
let cGrupos = [];    // grupos de produto (est_grupos_produto)

// chart instances (destroyed before re-render)
let chMensal, chCmvMensal, chFornDash, chCatDash, chCmvEvolucao;

// fichas técnicas
let cProdutosFT  = [];   // all est_produtos for autocomplete
let ftIngredientes = []; // ingredientes da ficha em edição
let ftFichasCache  = []; // fichas carregadas


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
  if (['pedido','compras'].includes(nome)) {
    document.getElementById('nav-grupo-compra')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-compra')?.classList.add('aberto');
  }
  if (['cadastros','produto'].includes(nome)) {
    document.getElementById('nav-grupo-cadastros')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-cadastros')?.classList.add('aberto');
  }
  if (['usuarios','backup'].includes(nome)) {
    document.getElementById('nav-grupo-config')?.classList.add('aberto', 'ativo');
    document.getElementById('nav-submenu-config')?.classList.add('aberto');
  }

  if (nome === 'dashboard')   carregarDashboard();
  if (nome === 'pedido')      prepararFormCompra();
  if (nome === 'compras')     carregarCompras();
  if (nome === 'faturamento') { setHoje('f-data'); carregarFaturamento(); }
  if (nome === 'cmv')         carregarCMV();
  if (nome === 'historico')   carregarHistorico();
  if (nome === 'cadastros')   { irCad('produtos', document.querySelector('#tabs-cad .nav-link')); }
  if (nome === 'inventario')    { setHoje('inv-data'); carregarInventario(); }
  if (nome === 'planejamento')  { setHoje('plan-data'); carregarPlanejamento(); }
  if (nome === 'recebimento')   { abaReceb('pendentes', document.querySelector('#tabs-receb .nav-link')); }
  if (nome === 'controlecmv')   renderHistoricoImport();
  if (nome === 'usuarios')      carregarUsuarios();
  if (nome === 'backup')        {}
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
  tipos: '🏷️ Destinos', compradores: '👤 Compradores',
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


function toggleFormCad(key) {
  const el = document.getElementById(`form-cad-${key}`);
  if (!el) return;
  el.classList.toggle('d-none');
  if (!el.classList.contains('d-none')) {
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
  const [f, cat, tip, comp, hist, grp] = await Promise.all([
    sb.from('fornecedores').select('id,nome').order('nome'),
    sb.from('cmp_categorias').select('id,nome,plano_conta').eq('ativo', true).order('nome'),
    sb.from('cmp_tipos_produto').select('id,nome').order('nome'),
    sb.from('cmp_compradores').select('id,nome').eq('ativo', true).order('nome'),
    sb.from('cmp_compras').select('produto,unidade_med,categoria').order('produto'),
    sb.from('est_grupos_produto').select('id,nome').order('nome'),
  ]);

  cForn   = f.data    || [];
  cCat    = cat.data  || [];
  cTipo   = tip.data  || [];
  cComp   = comp.data || [];
  cGrupos = grp.data  || [];

  // Build unique product list from past purchases (self-learning autocomplete)
  const seen = new Set();
  cProd = [];
  (hist.data || []).forEach(r => {
    if (r.produto && !seen.has(r.produto.toLowerCase())) {
      seen.add(r.produto.toLowerCase());
      cProd.push({ nome: r.produto, unidade_med: r.unidade_med, categoria: r.categoria });
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
  await carregarProdutosFT();
  setHoje('c-data');
  document.getElementById('bloco-estoque').style.display = 'none';
  // Mostra próximo número de pedido
  const proxNum = await _gerarNumeroPedido();
  const el = document.getElementById('prox-pedido-num');
  if (el) el.textContent = proxNum;
  consultarPedidos();

  // Populate selects
  const catSel = document.getElementById('c-cat');
  catSel.innerHTML = '<option value="">— Selecione —</option>' +
    cCat.map(c => `<option value="${esc(c.nome)}">${esc(c.nome)}</option>`).join('');

  const tipoSel = document.getElementById('c-tipo');
  tipoSel.innerHTML = '<option value="">— Selecione —</option>' +
    cTipo.map(t => `<option value="${esc(t.nome)}">${esc(t.nome)}</option>`).join('');

  const compSel = document.getElementById('c-comp');
  compSel.innerHTML = '<option value="">— Selecione —</option>' +
    cComp.map(c => `<option value="${esc(c.nome)}">${esc(c.nome)}</option>`).join('');

  // Warning if missing registers
  const falta = [];
  if (!cCat.length)  falta.push('<strong>Categorias</strong>');
  if (!cTipo.length) falta.push('<strong>Destinos</strong>');
  if (!cComp.length) falta.push('<strong>Compradores</strong>');

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

  const hits = cForn.filter(f => f.nome.toLowerCase().includes(val.toLowerCase())).slice(0, 8);
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

// Autocomplete — Produto
function acProd(val) {
  const lista = document.getElementById('ac-prod');
  if (!val) { lista.classList.remove('aberta'); return; }
  const q = val.toLowerCase();

  // Busca apenas nos 347 produtos de compra da planilha categorizada
  const hits = PRODUTOS_COMPRA.filter(p => p.nome.toLowerCase().includes(q)).slice(0, 10);

  if (!hits.length) { lista.classList.remove('aberta'); return; }

  lista.innerHTML = hits.map(p =>
    `<div class="ac-item" onmousedown="selecionarProd('${esc(p.nome)}','${esc(p.un)}','${esc(p.cat)}')">${esc(p.nome)} <small class="text-muted">${esc(p.un)}</small></div>`
  ).join('');
  lista.classList.add('aberta');
}

function selecionarProd(nome, un, cat) {
  document.getElementById('c-prod').value = nome;

  // Busca unidade da lista de compra (prioridade) ou catálogo
  const prodLista = PRODUTOS_COMPRA.find(p => p.nome.toLowerCase() === nome.toLowerCase());
  const prodCat   = cProdutosFT.find(p => p.nome.toLowerCase() === nome.toLowerCase());
  const unFinal  = prodLista?.un || prodCat?.unidade_uso || un;
  const catFinal = prodLista?.cat || prodCat?.categoria || cat;

  const unEl = document.getElementById('c-un');
  if (unFinal && unEl) {
    // Adiciona a opção se não existir e bloqueia o campo
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
  // Preenche valor do produto no campo custo (formatado)
  if (prodCat?.custo_uso > 0) {
    const custoFmt = prodCat.custo_uso.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    document.getElementById('c-custo').value = custoFmt;
    calcTot();
  }
  // Bloco de estoque mínimo
  const prod = prodCat;
  const blocoEl = document.getElementById('bloco-estoque');
  if (prod && parseFloat(prod.estoque_min) > 0 && blocoEl) {
    document.getElementById('c-estmin-show').textContent = prod.estoque_min + ' ' + (prod.unidade_uso || '');
    document.getElementById('c-estoque-atual').value = '';
    document.getElementById('c-sugestao').textContent = '—';
    blocoEl.style.display = '';
    blocoEl.dataset.estmin = prod.estoque_min;
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

function _parseCusto() {
  const v = document.getElementById('c-custo').value || '0';
  return parseFloat(v.replace(/\./g, '').replace(',', '.')) || 0;
}

function calcTot() {
  const custo = _parseCusto();
  const qtd   = parseFloat(document.getElementById('c-qtd').value) || 0;
  document.getElementById('c-total-show').textContent = brl(custo * qtd);
}

async function salvarCompra(e) {
  e.preventDefault();

  const data     = document.getElementById('c-data').value;
  const fornNome = document.getElementById('c-forn').value.trim();
  const fornId   = document.getElementById('c-forn-id').value || null;
  const prod     = document.getElementById('c-prod').value.trim();
  const cat      = document.getElementById('c-cat').value;
  const tipo     = document.getElementById('c-tipo').value;
  const un       = document.getElementById('c-un').value;
  const custo    = _parseCusto();
  const qtd      = parseFloat(document.getElementById('c-qtd').value);
  const comp     = document.getElementById('c-comp').value;
  const uso      = document.getElementById('c-uso').value;
  const obs      = document.getElementById('c-obs').value.trim();

  if (!data || !fornNome || !prod || !cat || !tipo || !custo || !qtd || !comp) {
    toast('Preencha todos os campos obrigatórios.', 'erro'); return;
  }

  const catObj    = cCat.find(c => c.nome === cat);
  const planoConta = catObj ? (catObj.plano_conta || '') : '';

  const pedido_num = await _gerarNumeroPedido();

  const { error } = await sb.from('cmp_compras').insert([{
    data, pedido_num,
    fornecedor_id:   fornId,
    fornecedor_nome: fornNome,
    produto:         prod,
    categoria:       cat,
    plano_conta:     planoConta,
    tipo_produto:    tipo,
    unidade_med:     un,
    custo_unit:      custo,
    quantidade:      qtd,
    comprador:       comp,
    unidade_uso:     uso,
    observacao:      obs || null,
    status_receb:    'pendente',
    criado_por:      user.id,
  }]);

  if (error) { toast('Erro ao salvar compra: ' + error.message, 'erro'); return; }

  toast(`✅ ${prod} — Pedido ${pedido_num} — ${brl(custo * qtd)}`, 'ok');

  document.getElementById('c-prod').value   = '';
  document.getElementById('c-custo').value  = '';
  document.getElementById('c-total-show').textContent = 'R$ 0,00';
  document.getElementById('c-qtd').value    = '1';
  document.getElementById('c-obs').value    = '';
  const unEl = document.getElementById('c-un');
  if (unEl) { unEl.style.pointerEvents = ''; unEl.style.opacity = ''; unEl.title = ''; }
  document.getElementById('c-total-show').textContent = 'R$ 0,00';
  document.getElementById('bloco-estoque').style.display = 'none';
  document.getElementById('c-prod').focus();

  if (!cProd.find(p => p.nome.toLowerCase() === prod.toLowerCase())) {
    cProd.push({ nome: prod, unidade_med: un, categoria: cat });
  }

  // Atualiza próximo número e lista de pedidos
  const proxNum = await _gerarNumeroPedido();
  const numEl = document.getElementById('prox-pedido-num');
  if (numEl) numEl.textContent = proxNum;
  consultarPedidos();
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
    categorias:   { tbl: 'cmp_categorias',    el: 'lst-categorias',   extra: r => r.plano_conta ? `<small class="text-muted ms-2">${esc(r.plano_conta)}</small>` : '' },
    tipos:        { tbl: 'cmp_tipos_produto', el: 'lst-tipos',        extra: null },
    compradores:  { tbl: 'cmp_compradores',   el: 'lst-compradores',  extra: null },
  };

  const c = cfg[tipo];
  if (!c) return;

  const cols = c.tbl === 'cmp_categorias' ? 'id,nome,plano_conta' : 'id,nome';
  const { data } = await sb.from(c.tbl).select(cols).order('nome');
  const rows = data || [];
  const el   = document.getElementById(c.el);

  el.innerHTML = rows.length
    ? rows.map(r => `
        <div class="lista-item">
          <span>${esc(r.nome)}${c.extra ? c.extra(r) : ''}</span>
          <button class="btn-del" onclick="excluirCad('${c.tbl}','${r.id}','${tipo}')" title="Excluir">
            <i class="bi bi-trash"></i>
          </button>
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
  const nome  = (document.getElementById('n-cat').value   || '').trim();
  const plano = (document.getElementById('n-plano').value || '').trim();
  if (!nome) return;
  const msg = document.getElementById('msg-cad-cat');
  const { error } = await sb.from('cmp_categorias').insert([{ nome, plano_conta: plano }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Já existe ou erro: ${error.message}</span>`; return; }
  document.getElementById('n-cat').value   = '';
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

async function addComprador() {
  const nome = (document.getElementById('n-comp').value || '').trim();
  if (!nome) return;
  const msg = document.getElementById('msg-cad-comp');
  const { error } = await sb.from('cmp_compradores').insert([{ nome }]);
  if (error) { msg.innerHTML = `<span class="text-danger">Já existe ou erro: ${error.message}</span>`; return; }
  document.getElementById('n-comp').value = '';
  msg.innerHTML = '';
  toggleFormCad('comp');
  toast('Comprador adicionado!', 'ok');
  await carregarCaches();
  renderListaCad('compradores');
}

async function excluirCad(tabela, id, tipo) {
  if (!confirm('Excluir este item?')) return;
  const { error } = await sb.from(tabela).delete().eq('id', id);
  if (error) { toast('Não é possível excluir — pode estar em uso.', 'erro'); return; }
  toast('Excluído.', 'ok');
  await carregarCaches();
  renderListaCad(tipo);
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
    <tr>
      <td>${esc(g.nome)}</td>
      <td class="text-end">
        <button class="btn-del" onclick="excluirGrupo(${g.id},'${esc(g.nome)}')" title="Excluir">
          <i class="bi bi-trash3"></i>
        </button>
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

  const busca  = (document.getElementById('ft-busca')?.value  || '').toLowerCase();
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
  if (busca)  prods = prods.filter(p => p.nome.toLowerCase().includes(busca));
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
    p.nome.toLowerCase().includes(val.toLowerCase())
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
    p.nome.toLowerCase().includes(val.toLowerCase())
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
// INVENTÁRIOS
// ═══════════════════════════════════════════════════════════════
let _invLocal    = 'Centro';
let _invProdutos = [];  // produtos filtrados atualmente na tela

function mudarLocalInv(local) {
  _invLocal = local;
  document.getElementById('inv-local-badge').textContent    = local;
  const e2 = document.getElementById('inv-local-badge2');
  const e3 = document.getElementById('imp-inv-local-badge');
  if (e2) e2.textContent = local;
  if (e3) e3.textContent = local;
  document.getElementById('btn-inv-centro').className = local === 'Centro' ? 'btn btn-primary' : 'btn btn-outline-primary';
  document.getElementById('btn-inv-p10').className    = local === 'P10'    ? 'btn btn-primary' : 'btn btn-outline-primary';
  document.getElementById('inv-busca').value = '';
  renderInventario();
}

async function carregarInventario() {
  await carregarProdutosFT();
  renderInventario();
  carregarHistoricoInv();
}

function filtrarInventario() {
  renderInventario();
}

function renderInventario() {
  const busca = (document.getElementById('inv-busca')?.value || '').toLowerCase();
  let prods = cProdutosFT.filter(p => ['MP','SA','MC'].includes(p.tipo));
  if (busca) prods = prods.filter(p => p.nome.toLowerCase().includes(busca));
  _invProdutos = prods;

  const tbody = document.getElementById('lst-inventario');
  if (!prods.length) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted py-4">Nenhum produto encontrado.</td></tr>';
    calcTotalInv();
    return;
  }

  const uns = ['UN','KG','CX','LT','FD','PC','MT','DZ'];
  tbody.innerHTML = prods.map((p, i) => {
    const unOpts = uns.map(u => `<option${u === (p.unidade_uso || 'UN') ? ' selected' : ''}>${u}</option>`).join('');
    const val = p.custo_uso || 0;
    return `<tr>
      <td><strong>${esc(p.nome)}</strong></td>
      <td class="text-muted small">${esc(p.categoria || '')}</td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center inv-campo"
          id="inv-est-${i}" min="0" step="0.001" value="0"
          style="width:80px;margin:auto" oninput="calcLinhaInv(${i})">
      </td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center inv-campo"
          id="inv-cb-${i}" min="0" step="0.001" value="0"
          style="width:80px;margin:auto" oninput="calcLinhaInv(${i})">
      </td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center inv-campo"
          id="inv-out-${i}" min="0" step="0.001" value="0"
          style="width:80px;margin:auto" oninput="calcLinhaInv(${i})">
      </td>
      <td class="text-center fw-bold" id="inv-tot-${i}">0</td>
      <td class="text-center">
        <select class="form-select form-select-sm" id="inv-un-${i}" style="width:75px;margin:auto">${unOpts}</select>
      </td>
      <td class="text-center">
        <input type="text" class="form-control form-control-sm text-center inv-campo"
          id="inv-val-${i}" inputmode="decimal"
          value="${val > 0 ? val.toLocaleString('pt-BR', {minimumFractionDigits:2, maximumFractionDigits:2}) : ''}"
          placeholder="0,00" style="width:90px;margin:auto"
          oninput="mascaraMoeda(this); calcLinhaInv(${i})"
          onfocus="moedaFocus(this)" onblur="moedaBlur(this); calcLinhaInv(${i})">
      </td>
      <td class="text-center fw-bold text-success" id="inv-soma-${i}">R$ 0,00</td>
    </tr>`;
  }).join('');

  calcTotalInv();
}

function calcLinhaInv(i) {
  const est = parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0;
  const cb  = parseFloat(document.getElementById(`inv-cb-${i}`)?.value)  || 0;
  const out = parseFloat(document.getElementById(`inv-out-${i}`)?.value) || 0;
  const val = parseMoeda(`inv-val-${i}`);
  const tot  = est + cb + out;
  const soma = tot * val;
  const totEl  = document.getElementById(`inv-tot-${i}`);
  const somaEl = document.getElementById(`inv-soma-${i}`);
  if (totEl)  totEl.textContent  = tot % 1 === 0 ? String(tot) : tot.toFixed(3).replace(/\.?0+$/, '');
  if (somaEl) somaEl.textContent = brl(soma);
  calcTotalInv();
}

function calcTotalInv() {
  let total = 0;
  document.querySelectorAll('[id^="inv-soma-"]').forEach(el => {
    const v = el.textContent.replace(/[R$\s.]/g, '').replace(',', '.');
    total += parseFloat(v) || 0;
  });
  const fmt = brl(total);
  const e1 = document.getElementById('inv-total-geral');
  const e2 = document.getElementById('inv-rodape-total');
  if (e1) e1.textContent = fmt;
  if (e2) e2.textContent = fmt;
}

async function salvarInventario() {
  const data = document.getElementById('inv-data').value;
  if (!data) { toast('Selecione a data do inventário.', 'erro'); return; }
  if (!_invProdutos.length) { toast('Nenhum produto na lista.', 'erro'); return; }

  const resp = (document.getElementById('inv-resp').value || '').trim();

  // Monta itens
  const itens = _invProdutos.map((p, i) => ({
    produto_id:     p.id,
    nome:           p.nome,
    estoque:        parseFloat(document.getElementById(`inv-est-${i}`)?.value) || 0,
    cozinha_bar:    parseFloat(document.getElementById(`inv-cb-${i}`)?.value)  || 0,
    outros:         parseFloat(document.getElementById(`inv-out-${i}`)?.value) || 0,
    total:          parseFloat(document.getElementById(`inv-tot-${i}`)?.textContent) || 0,
    unidade:        document.getElementById(`inv-un-${i}`)?.value || 'UN',
    valor_unitario: parseMoeda(`inv-val-${i}`),
    soma_total:     (() => {
      const v = (document.getElementById(`inv-soma-${i}`)?.textContent || '0').replace(/[R$\s.]/g,'').replace(',','.');
      return parseFloat(v) || 0;
    })(),
  }));

  const totalGeral = itens.reduce((s, it) => s + it.soma_total, 0);

  // Número sequencial
  const { data: ultInvs } = await sb.from('est_inventarios').select('num_inv').order('criado_em', { ascending: false }).limit(1);
  const ultimoNum = ultInvs?.[0]?.num_inv ? parseInt(ultInvs[0].num_inv.replace(/\D/g, '')) || 0 : 0;
  const num_inv = 'INV-' + String(ultimoNum + 1).padStart(4, '0');

  // Salva cabeçalho
  const { data: inv, error } = await sb.from('est_inventarios').insert([{
    num_inv, data, local: _invLocal, responsavel: resp, total_geral: totalGeral
  }]).select().single();

  if (error) { toast('Erro ao salvar inventário: ' + error.message, 'erro'); return; }

  // Salva itens (só os que têm alguma quantidade > 0, ou todos)
  const itensComId = itens.map(it => ({ ...it, inventario_id: inv.id }));
  await sb.from('est_inventario_itens').insert(itensComId);

  toast(`${num_inv} salvo! Total: ${brl(totalGeral)}`, 'ok');
  carregarHistoricoInv();

  // Limpa os campos
  document.querySelectorAll('.inv-campo').forEach(el => { el.value = el.id.startsWith('inv-val-') ? '' : '0'; });
  document.querySelectorAll('[id^="inv-tot-"]').forEach(el => el.textContent = '0');
  document.querySelectorAll('[id^="inv-soma-"]').forEach(el => el.textContent = 'R$ 0,00');
  calcTotalInv();
}

async function carregarHistoricoInv() {
  const fil  = document.getElementById('hist-inv-fil')?.value || '';
  let query  = sb.from('est_inventarios').select('id,num_inv,data,local,responsavel,total_geral').order('criado_em', { ascending: false });
  if (fil) query = query.eq('local', fil);
  const { data: lista } = await query;

  const cont = document.getElementById('lst-historico-inv');
  if (!cont) return;
  if (!lista?.length) { cont.innerHTML = '<p class="text-muted">Nenhum inventário salvo ainda.</p>'; return; }

  cont.innerHTML = lista.map(inv => {
    const localCor = inv.local === 'Centro' ? '#0d6efd' : '#198754';
    const dataBR   = inv.data.split('-').reverse().join('/');
    return `<div class="d-flex align-items-center justify-content-between border-bottom py-2">
      <div>
        <span class="badge bg-dark me-1">${inv.num_inv}</span>
        <span class="badge me-2" style="background:${localCor}">${inv.local}</span>
        <strong>${dataBR}</strong>
        ${inv.responsavel ? `<span class="text-muted ms-2">— ${inv.responsavel}</span>` : ''}
      </div>
      <div class="d-flex align-items-center gap-2">
        <strong class="text-success">${brl(inv.total_geral)}</strong>
        <button class="btn btn-sm btn-outline-danger" onclick="excluirInventario('${inv.id}')">
          <i class="bi bi-trash"></i>
        </button>
      </div>
    </div>`;
  }).join('');
}

async function excluirInventario(id) {
  if (!confirm('Excluir este inventário?')) return;
  await sb.from('est_inventarios').delete().eq('id', id);
  toast('Inventário excluído.', 'ok');
  carregarHistoricoInv();
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

  if (!cForn.length || !cComp.length) await carregarCaches();

  const compHtml = '<option value="">— selecione —</option>' +
    cComp.map(c => `<option>${esc(c.nome)}</option>`).join('');
  const compEl     = document.getElementById('plan-comp');
  const compFornEl = document.getElementById('plan-comp-forn');
  if (compEl)     compEl.innerHTML     = compHtml;
  if (compFornEl) compFornEl.innerHTML = compHtml;

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
    if (msgEl) msgEl.innerHTML = '<span class="text-warning">⚠️ Selecione um inventário.</span>';
    return;
  }

  const { data: itens } = await sb.from('est_inventario_itens')
    .select('produto_id,nome,estoque,cozinha_bar,outros')
    .eq('inventario_id', selId);

  if (!itens?.length) {
    if (msgEl) msgEl.innerHTML = '<span class="text-danger">Inventário sem itens.</span>';
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
    .select('id,pedido_num,data,data_entrega,fornecedor_nome,comprador,produto,categoria,tipo_produto,unidade_med,quantidade,custo_unit,status_receb')
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
    if (!grupos[key]) grupos[key] = { pedido_num: key, data: c.data, forn: c.fornecedor_nome, comp: c.comprador, itens: [], total: 0 };
    grupos[key].itens.push(c);
    grupos[key].total += (c.quantidade || 0) * (c.custo_unit || 0);
  });

  let lista = Object.values(grupos).sort((a,b) => b.data.localeCompare(a.data));

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
    tbody.innerHTML = '<tr><td colspan="8" class="text-center text-muted py-3">Nenhum pedido pendente de recebimento.</td></tr>';
    return;
  }
  tbody.innerHTML = lista.map(g => `
    <tr>
      <td><span class="badge" style="background:#FF6B35">${esc(g.pedido_num)}</span></td>
      <td>${(g.data||'').split('-').reverse().join('/')}</td>
      <td><strong>${esc(g.forn||'—')}</strong></td>
      <td>${esc(g.comp||'—')}</td>
      <td class="text-center"><span class="badge bg-secondary">${g.itens.length} item(s)</span></td>
      <td class="text-center"><strong>${brl(g.total)}</strong></td>
      <td class="text-center">
        <button class="btn btn-sm btn-success py-0 px-2" onclick="abrirModalReceber('${esc(g.pedido_num)}')">
          📬 Receber
        </button>
      </td>
      <td class="text-center">
        <button class="btn btn-sm btn-outline-danger py-0 px-2" onclick="excluirPedidoReceb('${esc(g.pedido_num)}')">
          🗑️ Excluir
        </button>
      </td>
    </tr>`).join('');
}

async function excluirPedidoReceb(pedido_num) {
  if (!confirm(`Excluir o pedido ${pedido_num}? Esta ação não pode ser desfeita.`)) return;
  await sb.from('cmp_compras').delete().eq('pedido_num', pedido_num);
  toast('Pedido excluído.', 'ok');
  renderPendentes();
}

async function abrirModalReceber(pedido_num) {
  const { data: itens } = await sb.from('cmp_compras')
    .select('id,produto,categoria,unidade_med,quantidade,custo_unit,fornecedor_nome,comprador')
    .eq('pedido_num', pedido_num)
    .neq('status_receb', 'recebido');

  if (!itens?.length) { toast('Itens não encontrados.', 'erro'); return; }
  _recebItensAbertos = itens;

  document.getElementById('receb-pedido-num-hidden').value = pedido_num;
  document.getElementById('receb-ped-num').textContent     = pedido_num;
  document.getElementById('receb-data-rec').value          = new Date().toISOString().split('T')[0];
  document.getElementById('receb-vencimento').value        = '';
  document.getElementById('receb-responsavel').value       = '';
  document.getElementById('alerta-diverg').style.display   = 'none';

  document.getElementById('tb-receber-itens').innerHTML = itens.map(x => `
    <tr id="row-rec-${x.id}">
      <td><strong>${esc(x.produto)}</strong></td>
      <td><small class="text-muted">${esc(x.categoria||'—')}</small></td>
      <td class="text-center">${(x.quantidade||0).toLocaleString('pt-BR',{maximumFractionDigits:3})} ${esc(x.unidade_med||'')}</td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center" style="width:90px;margin:auto"
          id="qtd-rec-${x.id}" value="${x.quantidade||0}" min="0" step="0.001"
          oninput="recalcReceb('${x.id}',${x.custo_unit||0},${x.quantidade||0})">
      </td>
      <td class="text-center">${brl(x.custo_unit||0)}</td>
      <td class="text-center fw-bold" id="tot-rec-${x.id}">${brl((x.quantidade||0)*(x.custo_unit||0))}</td>
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

function recalcReceb(id, vlrUnit, qtdPedida) {
  const qtdRec = parseFloat(document.getElementById(`qtd-rec-${id}`)?.value) || 0;
  const tot    = qtdRec * vlrUnit;
  const totEl  = document.getElementById(`tot-rec-${id}`);
  if (totEl) totEl.textContent = brl(tot);
  const divEl = document.getElementById(`div-rec-${id}`);
  if (divEl && qtdRec !== qtdPedida) { divEl.checked = true; marcarDiverg(id); }
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
    const id = el.id.replace('qtd-rec-', '');
    const txt = (document.getElementById(`tot-rec-${id}`)?.textContent || '0').replace(/[R$\s.]/g,'').replace(',','.');
    total += parseFloat(txt) || 0;
  });
  const el = document.getElementById('receb-total-modal');
  if (el) el.textContent = brl(total);
}

async function confirmarRecebimento() {
  const pedido_num  = document.getElementById('receb-pedido-num-hidden').value;
  const dataRec     = document.getElementById('receb-data-rec').value;
  const responsavel = (document.getElementById('receb-responsavel').value || '').trim();
  const vencimento  = document.getElementById('receb-vencimento').value;
  if (!dataRec)     { toast('Informe a data do recebimento.', 'erro'); return; }
  if (!responsavel) { toast('Informe o responsável.', 'erro'); return; }
  if (!vencimento)  { toast('Informe a data de vencimento.', 'erro'); return; }

  const ref = _recebItensAbertos[0];
  const itensReceb = _recebItensAbertos.map(x => {
    const qtdRec = parseFloat(document.getElementById(`qtd-rec-${x.id}`)?.value) || 0;
    const diverg = document.getElementById(`div-rec-${x.id}`)?.checked || false;
    const obs    = document.getElementById(`obs-rec-${x.id}`)?.value || '';
    return {
      compra_id: x.id, produto: x.produto, categoria: x.categoria || '',
      unidade: x.unidade_med || '', qtd_pedida: x.quantidade || 0,
      qtd_recebida: qtdRec, valor_unitario: x.custo_unit || 0,
      total_recebido: qtdRec * (x.custo_unit || 0),
      divergencia: diverg, obs_divergencia: obs,
    };
  });

  const totalRecebido = itensReceb.reduce((s, i) => s + i.total_recebido, 0);
  const temDiverg     = itensReceb.some(i => i.divergencia);

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

  // Gera conta a pagar
  await sb.from('cmp_contas_pagar').insert([{
    pedido_num, recebimento_id: receb.id,
    fornecedor: ref?.fornecedor_nome || '',
    data_receb: dataRec, vencimento, valor: totalRecebido,
    status: 'pendente',
  }]);

  // Marca itens como recebidos
  await sb.from('cmp_compras').update({ status_receb: 'recebido' }).eq('pedido_num', pedido_num);

  bootstrap.Modal.getInstance(document.getElementById('modal-receber')).hide();
  toast(`✅ Recebimento confirmado! Conta gerada: ${brl(totalRecebido)} — Venc. ${vencimento.split('-').reverse().join('/')}${temDiverg ? ' ⚠️ Com divergências.' : ''}`, 'ok');
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
  const ref = itens[0];
  const dataBR = (ref.data||'').split('-').reverse().join('/');
  const total  = itens.reduce((s,c) => s + (c.quantidade||0)*(c.custo_unit||0), 0);

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
    ${ref.data_entrega ? `<div><span>Entrega</span><strong>${ref.data_entrega.split('-').reverse().join('/')}</strong></div>` : ''}
  </div>
  <table><thead><tr><th>#</th><th>Produto</th><th>Categoria</th><th>Tipo</th>
    <th style="text-align:center">Quantidade</th><th style="text-align:center">Valor Unit.</th>
    <th style="text-align:center">Total</th></tr></thead>
  <tbody>${linhas}</tbody>
  <tfoot><tr class="tot">
    <td colspan="6" style="text-align:right;padding-right:8px">TOTAL DO PEDIDO</td>
    <td style="text-align:center">${brl(total)}</td>
  </tr></tfoot></table>
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
    .select('id,pedido_num,data,data_entrega,fornecedor_nome,comprador,produto,categoria,quantidade,custo_unit,status_receb')
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
      forn: c.fornecedor_nome, comp: c.comprador,
      itens: [], total: 0, recebido: c.status_receb === 'recebido'
    };
    grupos[key].itens.push(c);
    grupos[key].total += (c.quantidade||0) * (c.custo_unit||0);
    if (c.status_receb !== 'recebido') grupos[key].recebido = false;
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
    const cor     = g.recebido ? '#2EC4B6' : '#FF6B35';
    const status  = g.recebido ? '✅ Recebido' : '⏳ Pendente';
    return `<tr style="cursor:pointer" onclick="toggleDetalheCompra('${g.pedido_num}', this)">
      <td>${dataBR}</td>
      <td><span class="badge" style="background:#FF6B35">${esc(g.pedido_num)}</span></td>
      <td><strong>${esc(g.forn||'—')}</strong></td>
      <td>${esc(g.comp||'—')}</td>
      <td class="text-center"><span class="badge bg-secondary">${g.itens.length}</span></td>
      <td class="text-center">${entregaBR}</td>
      <td class="text-center fw-bold">${brl(g.total)}</td>
      <td class="text-center"><span class="badge" style="background:${cor}">${status}</span></td>
      <td class="text-center">
        <div class="d-flex gap-1 justify-content-center" onclick="event.stopPropagation()">
          <button class="btn btn-sm btn-outline-secondary py-0 px-2" onclick="imprimirPedido('${g.pedido_num}')" title="Imprimir">🖨️</button>
          ${!g.recebido ? `<button class="btn btn-sm btn-success py-0 px-2" onclick="abrirModalReceber('${g.pedido_num}')" title="Receber">📬 Receber</button>` : ''}
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

  const { error } = await sb.from('est_produtos').update(dados).eq('id', id);
  if (error) { toast('Erro ao salvar: ' + error.message, 'erro'); return; }

  toast('✅ Produto atualizado com sucesso!', 'ok');

  // Atualiza cache local
  const idx = cProdutosFT.findIndex(p => p.id === id);
  if (idx >= 0) cProdutosFT[idx] = { ...cProdutosFT[idx], ...dados };
  _prodAtual = { ..._prodAtual, ...dados };
  document.getElementById('prod-titulo').textContent = dados.nome;

  // Recalcula todas as fichas que usam este produto como ingrediente
  await recalcularFichasDoIngrediente(id);
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
