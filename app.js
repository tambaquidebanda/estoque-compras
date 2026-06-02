'use strict';

// ═══════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════
let sb   = null;   // supabase client
let user = null;   // logged-in user

// caches
let cForn = [];    // fornecedores
let cCat  = [];    // categorias
let cTipo = [];    // tipos_produto
let cComp = [];    // compradores
let cProd = [];    // product names learned from past purchases

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
  const url = localStorage.getItem('gc_url');
  const key = localStorage.getItem('gc_key');

  if (!url || !key) { mostrarTela('config'); return; }

  try {
    sb = supabase.createClient(url, key);
    const { data: { session } } = await sb.auth.getSession();
    if (session) { user = session.user; entrarNoSistema(); }
    else          { mostrarTela('login'); }
  } catch {
    mostrarTela('config');
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

  const url = localStorage.getItem('gc_url');
  const key = localStorage.getItem('gc_key');
  sb = supabase.createClient(url, key);

  const { data, error } = await sb.auth.signInWithPassword({ email, password: senha });
  if (error) {
    erro.textContent = 'E-mail ou senha incorretos.';
    erro.classList.remove('d-none'); return;
  }

  user = data.user;
  erro.classList.add('d-none');
  entrarNoSistema();
}

function entrarNoSistema() {
  mostrarTela('principal');
  document.getElementById('sb-usuario').textContent = user.email;
  setHoje('c-data');
  setHoje('f-data');
  setMes('f-filtro-mes');
  setMes('hist-mes');
  ir('dashboard', document.querySelector('.nav-sb a'));
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
function ir(nome, el) {
  document.querySelectorAll('.pagina').forEach(p => p.classList.remove('ativa'));
  document.querySelectorAll('.nav-sb a:not(.nav-em-breve)').forEach(a => a.classList.remove('ativo'));
  document.getElementById('pg-' + nome).classList.add('ativa');
  if (el) el.classList.add('ativo');

  if (nome === 'dashboard')   carregarDashboard();
  if (nome === 'compra')      prepararFormCompra();
  if (nome === 'faturamento') { setHoje('f-data'); carregarFaturamento(); }
  if (nome === 'cmv')         carregarCMV();
  if (nome === 'historico')   carregarHistorico();
  if (nome === 'cadastros')   { irCad('fornecedores', document.querySelector('#tabs-cad .nav-link')); }
  if (nome === 'inventario')    { setHoje('inv-data'); carregarInventario(); }
  if (nome === 'planejamento')  { setHoje('plan-data'); carregarPlanejamento(); }
}

function irCad(tab, el) {
  document.querySelectorAll('.tab-cad').forEach(t => t.classList.remove('ativa'));
  document.querySelectorAll('#tabs-cad .nav-link').forEach(a => a.classList.remove('active'));
  document.getElementById('cad-' + tab).classList.add('ativa');
  if (el) el.classList.add('active');
  if (tab === 'produtos') { carregarFichas(); return; }
  renderListaCad(tab);
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
  const [f, cat, tip, comp, hist] = await Promise.all([
    sb.from('fornecedores').select('id,nome').order('nome'),
    sb.from('cmp_categorias').select('id,nome,plano_conta').eq('ativo', true).order('nome'),
    sb.from('cmp_tipos_produto').select('id,nome').order('nome'),
    sb.from('cmp_compradores').select('id,nome').eq('ativo', true).order('nome'),
    sb.from('cmp_compras').select('produto,unidade_med,categoria').order('produto'),
  ]);

  cForn = f.data    || [];
  cCat  = cat.data  || [];
  cTipo = tip.data  || [];
  cComp = comp.data || [];

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
  setHoje('c-data');

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

  const hits = cProd.filter(p => p.nome.toLowerCase().includes(val.toLowerCase())).slice(0, 8);
  if (!hits.length) { lista.classList.remove('aberta'); return; }

  lista.innerHTML = hits.map(p =>
    `<div class="ac-item" onmousedown="selecionarProd('${esc(p.nome)}','${esc(p.unidade_med||'')}','${esc(p.categoria||'')}')">${esc(p.nome)} <small class="text-muted">${esc(p.unidade_med||'')}</small></div>`
  ).join('');
  lista.classList.add('aberta');
}

function selecionarProd(nome, un, cat) {
  document.getElementById('c-prod').value = nome;
  if (un)  document.getElementById('c-un').value  = un;
  if (cat) {
    const sel = document.getElementById('c-cat');
    if ([...sel.options].some(o => o.value === cat)) sel.value = cat;
  }
  fechaAC('ac-prod');
}

function fechaAC(id) {
  document.getElementById(id).classList.remove('aberta');
}

function calcTot() {
  const custo = parseFloat(document.getElementById('c-custo').value) || 0;
  const qtd   = parseFloat(document.getElementById('c-qtd').value)   || 0;
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
  const custo    = parseFloat(document.getElementById('c-custo').value);
  const qtd      = parseFloat(document.getElementById('c-qtd').value);
  const comp     = document.getElementById('c-comp').value;
  const uso      = document.getElementById('c-uso').value;
  const obs      = document.getElementById('c-obs').value.trim();

  if (!data || !fornNome || !prod || !cat || !tipo || !custo || !qtd || !comp) {
    toast('Preencha todos os campos obrigatórios.', 'erro'); return;
  }

  const catObj    = cCat.find(c => c.nome === cat);
  const planoConta = catObj ? (catObj.plano_conta || '') : '';

  const { error } = await sb.from('cmp_compras').insert([{
    data,
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
    criado_por:      user.id,
  }]);

  if (error) { toast('Erro ao salvar compra: ' + error.message, 'erro'); return; }

  toast(`✅ ${prod} salvo! ${brl(custo * qtd)}`, 'ok');

  // Reset product-specific fields, keep meta fields
  document.getElementById('c-prod').value   = '';
  document.getElementById('c-custo').value  = '';
  document.getElementById('c-qtd').value    = '1';
  document.getElementById('c-obs').value    = '';
  document.getElementById('c-total-show').textContent = 'R$ 0,00';
  document.getElementById('c-prod').focus();

  // Update product cache so it appears in autocomplete next time
  if (!cProd.find(p => p.nome.toLowerCase() === prod.toLowerCase())) {
    cProd.push({ nome: prod, unidade_med: un, categoria: cat });
  }
}


// ═══════════════════════════════════════════════════════════════
// FATURAMENTO
// ═══════════════════════════════════════════════════════════════
async function salvarFaturamento() {
  const data  = document.getElementById('f-data').value;
  const valor = parseFloat(document.getElementById('f-valor').value);
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
// FICHAS TÉCNICAS
// ═══════════════════════════════════════════════════════════════

async function carregarProdutosFT(forcar = false) {
  if (cProdutosFT.length && !forcar) return;
  const PAGE = 1000;
  let todos = [], from = 0, continua = true;
  while (continua) {
    const { data } = await sb.from('est_produtos')
      .select('id,nome,tipo,categoria,unidade_uso,custo_uso,preco_venda')
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
    tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted py-4">Nenhum produto encontrado.</td></tr>';
    return;
  }

  tbody.innerHTML = prods.map(p => {
    const f      = fichaByProd[p.id];
    const margem = f && p.preco_venda > 0
      ? ((p.preco_venda - f.custo_por_porcao) / p.preco_venda * 100)
      : null;

    return `<tr onclick="abrirModalFicha('${p.id}','${f ? f.id : ''}')">
      <td class="fw-semibold">${esc(p.nome)}</td>
      <td><span class="badge-tipo badge-${p.tipo.toLowerCase()}">${p.tipo}</span></td>
      <td class="text-muted small">${esc(p.categoria || '')}</td>
      <td>${f ? `${Number(f.rendimento).toLocaleString('pt-BR')} ${esc(f.unidade_rendimento)}` : '—'}</td>
      <td>${f ? brl(f.custo_total) : '—'}</td>
      <td>${f ? brl(f.custo_por_porcao) : '—'}</td>
      <td>${p.preco_venda > 0 ? brl(p.preco_venda) : '—'}</td>
      <td class="${margem !== null ? (margem >= 60 ? 'text-success fw-bold' : margem >= 40 ? 'text-warning fw-bold' : 'text-danger fw-bold') : ''}">
        ${margem !== null ? pct(margem) : '—'}
      </td>
      <td class="text-end" onclick="event.stopPropagation()">
        ${f ? `<button class="btn-del" onclick="excluirFicha('${f.id}')" title="Excluir ficha"><i class="bi bi-trash"></i></button>` : ''}
      </td>
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
          ftIngredientes.push({
            id:        ing.id,
            prod_id:   ing.ingrediente_id,
            nome:      prod.nome,
            tipo:      prod.tipo,
            quantidade: ing.quantidade,
            unidade:   ing.unidade,
            custo_uso: prod.custo_uso || 0,
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
  document.getElementById('ft-ing-id').value   = id;
  document.getElementById('ft-ing-nome').value = p.nome;
  document.getElementById('ft-ing-un').value   = p.unidade_uso || 'UN';
  document.getElementById('ft-ing-info').textContent =
    `Custo: ${brl(p.custo_uso)} / ${p.unidade_uso || 'UN'}`;
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

  // Remove if already exists
  ftIngredientes = ftIngredientes.filter(i => i.prod_id !== id);

  ftIngredientes.push({
    id:        null,
    prod_id:   id,
    nome:      prod.nome,
    tipo:      prod.tipo,
    quantidade: qtd,
    unidade:   un,
    custo_uso: prod.custo_uso || 0,
  });

  // Reset fields
  document.getElementById('ft-ing-nome').value = '';
  document.getElementById('ft-ing-id').value   = '';
  document.getElementById('ft-ing-qtd').value  = '1';
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

  toast('Ficha técnica salva!', 'ok');
  bootstrap.Modal.getInstance(document.getElementById('modal-ficha')).hide();
  ftFichasCache = [];
  carregarFichas();
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
  document.getElementById('inv-local-badge').textContent = local;
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
        <input type="number" class="form-control form-control-sm text-center inv-campo"
          id="inv-val-${i}" min="0" step="0.01" value="${val.toFixed(2)}"
          style="width:90px;margin:auto" oninput="calcLinhaInv(${i})">
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
  const val = parseFloat(document.getElementById(`inv-val-${i}`)?.value) || 0;
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
  if (e1) e1.textContent = fmt;
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
    valor_unitario: parseFloat(document.getElementById(`inv-val-${i}`)?.value) || 0,
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
  document.querySelectorAll('.inv-campo').forEach(el => { if (el.type === 'number' && !el.id.startsWith('inv-val-')) el.value = '0'; });
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


// ═══════════════════════════════════════════════════════════════
// PLANEJAMENTO
// ═══════════════════════════════════════════════════════════════
let _planProdutos = [];

async function carregarPlanejamento() {
  // Populate selects
  const compSel = document.getElementById('plan-comp');
  if (compSel) {
    compSel.innerHTML = '<option value="">— selecione —</option>' +
      cComp.map(c => `<option>${esc(c.nome)}</option>`).join('');
  }
  const fornFil = document.getElementById('plan-fil-forn');
  if (fornFil) {
    fornFil.innerHTML = '<option value="">— Todos os fornecedores —</option>' +
      cForn.map(f => `<option>${esc(f.nome)}</option>`).join('');
  }

  const [{ data: prods }, { data: invCab }, { data: compras }] = await Promise.all([
    sb.from('est_produtos')
      .select('id,nome,tipo,categoria,unidade_uso,custo_uso,estoque_min,ativo')
      .eq('ativo', true)
      .in('tipo', ['MP','SA','MC'])
      .order('categoria').order('nome'),
    sb.from('est_inventarios')
      .select('id').order('criado_em', { ascending: false }).limit(1),
    sb.from('cmp_compras')
      .select('produto,quantidade,data,fornecedor_nome,categoria,tipo_produto,unidade_med')
      .gte('data', _dataNSemanasAtras(12)),
  ]);

  // Mapa do último inventário por produto_id
  let invMap = {};
  if (invCab?.[0]) {
    const { data: itens } = await sb.from('est_inventario_itens')
      .select('produto_id,estoque,cozinha_bar,outros')
      .eq('inventario_id', invCab[0].id);
    (itens || []).forEach(it => { invMap[it.produto_id] = it; });
  }

  // Média semanal por produto (últimas 12 semanas)
  const histMap = {};
  (compras || []).forEach(c => {
    const key = (c.produto || '').trim().toUpperCase();
    if (!histMap[key]) histMap[key] = { qtd: 0, semanas: new Set(), forn: '', cat: '', tipo: '', un: '' };
    const diasAtras = Math.floor((Date.now() - new Date(c.data).getTime()) / 86400000);
    histMap[key].semanas.add(Math.floor(diasAtras / 7));
    histMap[key].qtd += parseFloat(c.quantidade) || 0;
    if (c.fornecedor_nome) histMap[key].forn = c.fornecedor_nome;
    if (c.categoria)       histMap[key].cat  = c.categoria;
    if (c.tipo_produto)    histMap[key].tipo = c.tipo_produto;
    if (c.unidade_med)     histMap[key].un   = c.unidade_med;
  });

  _planProdutos = (prods || []).map(p => {
    const inv  = invMap[p.id] || {};
    const hist = histMap[p.nome.trim().toUpperCase()] || {};
    const nSem = hist.semanas?.size || 1;
    const med  = hist.semanas?.size ? Math.round((hist.qtd / nSem) * 10) / 10 : 0;
    return {
      ...p,
      est_atual: parseFloat(inv.estoque)     || 0,
      coz_bar:   parseFloat(inv.cozinha_bar) || 0,
      outros:    parseFloat(inv.outros)      || 0,
      vendas_med: med,
      forn_pad:   hist.forn || '',
      cat_pad:    hist.cat  || p.categoria || '',
      tipo_pad:   hist.tipo || '',
      un_pad:     hist.un   || p.unidade_uso || 'UN',
    };
  });

  renderPlanejamento();
}

function _dataNSemanasAtras(n) {
  const d = new Date();
  d.setDate(d.getDate() - n * 7);
  return d.toISOString().split('T')[0];
}

function renderPlanejamento() {
  const filtForn = document.getElementById('plan-fil-forn')?.value || '';
  let prods = _planProdutos;
  if (filtForn) prods = prods.filter(p => p.forn_pad === filtForn);

  const tbody = document.getElementById('lst-planejamento');
  if (!tbody) return;

  if (!prods.length) {
    tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted py-4">Nenhum produto encontrado.</td></tr>';
    return;
  }

  tbody.innerHTML = prods.map(p => {
    const totalEst  = p.est_atual + p.coz_bar + p.outros;
    const qtdSug    = Math.max(0, Math.round((p.vendas_med - totalEst) * 10) / 10);
    const abaixoMin = p.estoque_min > 0 && totalEst < p.estoque_min;
    const rowCls    = abaixoMin ? 'table-warning' : '';

    const fornOpts = cForn.map(f => `<option${f.nome === p.forn_pad ? ' selected' : ''}>${esc(f.nome)}</option>`).join('');
    const catOpts  = cCat.map(c  => `<option${c.nome === p.cat_pad  ? ' selected' : ''}>${esc(c.nome)}</option>`).join('');
    const tipoOpts = cTipo.map(t => `<option${t.nome === p.tipo_pad ? ' selected' : ''}>${esc(t.nome)}</option>`).join('');

    return `<tr class="${rowCls}">
      <td><strong>${esc(p.nome)}</strong><br><small class="text-muted">${p.tipo}</small></td>
      <td><select class="form-select form-select-sm" id="plan-forn-${p.id}">
        <option value="">—</option>${fornOpts}</select></td>
      <td><select class="form-select form-select-sm" id="plan-cat-${p.id}">
        <option value="">—</option>${catOpts}</select></td>
      <td><select class="form-select form-select-sm" id="plan-tipo-${p.id}">
        <option value="">—</option>${tipoOpts}</select></td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center"
          id="plan-med-${p.id}" value="${p.vendas_med}" min="0" step="0.1" style="width:80px;margin:auto">
      </td>
      <td class="text-center text-muted">${p.estoque_min || 0}</td>
      <td class="text-center">${p.est_atual}</td>
      <td class="text-center">${p.coz_bar}</td>
      <td class="text-center">${p.outros}</td>
      <td class="text-center">
        <input type="number" class="form-control form-control-sm text-center"
          id="plan-qtd-${p.id}" value="${qtdSug}" min="0" step="0.1" style="width:80px;margin:auto">
      </td>
    </tr>`;
  }).join('');
}

async function confirmarPlanejamento() {
  const data = document.getElementById('plan-data')?.value;
  const comp = document.getElementById('plan-comp')?.value;
  if (!data) { toast('Selecione a data de entrega.', 'erro'); return; }
  if (!comp) { toast('Selecione o comprador.', 'erro'); return; }

  const registros = [];
  _planProdutos.forEach(p => {
    const qtd = parseFloat(document.getElementById(`plan-qtd-${p.id}`)?.value) || 0;
    if (qtd <= 0) return;
    const fornNome = document.getElementById(`plan-forn-${p.id}`)?.value || '';
    const cat      = document.getElementById(`plan-cat-${p.id}`)?.value  || p.categoria || '';
    const tipo     = document.getElementById(`plan-tipo-${p.id}`)?.value || '';
    const fornObj  = cForn.find(f => f.nome === fornNome);
    const catObj   = cCat.find(c => c.nome === cat);
    registros.push({
      data,
      fornecedor_id:   fornObj?.id || null,
      fornecedor_nome: fornNome,
      produto:         p.nome,
      categoria:       cat,
      plano_conta:     catObj?.plano_conta || '',
      tipo_produto:    tipo,
      unidade_med:     p.un_pad || p.unidade_uso || 'UN',
      custo_unit:      p.custo_uso || 0,
      quantidade:      qtd,
      comprador:       comp,
      unidade_uso:     p.unidade_uso || 'UN',
      criado_por:      user.id,
    });
  });

  if (!registros.length) { toast('Nenhuma linha com quantidade preenchida.', 'erro'); return; }

  const { error } = await sb.from('cmp_compras').insert(registros);
  if (error) { toast('Erro ao confirmar: ' + error.message, 'erro'); return; }

  toast(`✅ ${registros.length} compras registradas no histórico!`, 'ok');
  _planProdutos.forEach(p => {
    const el = document.getElementById(`plan-qtd-${p.id}`);
    if (el) el.value = '0';
  });
}

function salvarLimparLista() {
  _planProdutos.forEach(p => {
    const totalEst = p.est_atual + p.coz_bar + p.outros;
    const qtdSug   = Math.max(0, Math.round((p.vendas_med - totalEst) * 10) / 10);
    const el = document.getElementById(`plan-qtd-${p.id}`);
    if (el) el.value = qtdSug;
  });
  toast('Quantidades restauradas para o sugerido.', 'ok');
}

function imprimirListaPlano(soItensOK) {
  const prods = soItensOK
    ? _planProdutos.filter(p => (parseFloat(document.getElementById(`plan-qtd-${p.id}`)?.value) || 0) > 0)
    : _planProdutos;

  if (!prods.length) { toast('Nenhum item para imprimir.', 'erro'); return; }

  const linhas = prods.map(p => {
    const qtd  = document.getElementById(`plan-qtd-${p.id}`)?.value  || '0';
    const forn = document.getElementById(`plan-forn-${p.id}`)?.value || '—';
    const cat  = document.getElementById(`plan-cat-${p.id}`)?.value  || '—';
    const tipo = document.getElementById(`plan-tipo-${p.id}`)?.value || '—';
    const med  = document.getElementById(`plan-med-${p.id}`)?.value  || p.vendas_med;
    const abx  = p.estoque_min > 0 && (p.est_atual + p.coz_bar + p.outros) < p.estoque_min;
    return `<tr style="${abx ? 'background:#fff3cd' : ''}">
      <td>${esc(p.nome)}</td><td>${esc(forn)}</td><td>${esc(cat)}</td><td>${esc(tipo)}</td>
      <td style="text-align:center">${med}</td>
      <td style="text-align:center">${p.estoque_min || 0}</td>
      <td style="text-align:center">${p.est_atual}</td>
      <td style="text-align:center">${p.coz_bar}</td>
      <td style="text-align:center">${p.outros}</td>
      <td style="text-align:center"><strong>${qtd}</strong></td>
    </tr>`;
  }).join('');

  const html = `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Lista de Compra Sugerida</title>
    <style>body{font-family:Arial,sans-serif;font-size:11px}h2{text-align:center}
    table{width:100%;border-collapse:collapse}th,td{border:1px solid #ccc;padding:3px 5px}
    th{background:#1a1a2e;color:#fff}</style></head><body>
    <h2>Lista de Compra Sugerida — Tambaqui de Banda</h2>
    <p style="text-align:center">Emitida em: ${new Date().toLocaleDateString('pt-BR')}</p>
    <table><thead><tr>
      <th>Produto</th><th>Fornecedor</th><th>Categoria</th><th>Tipo/Destino</th>
      <th>Vendas Méd.</th><th>Est.Mín.</th><th>Estoque</th><th>Coz.&Bar</th>
      <th>Outros</th><th>Qtd Pedido</th>
    </tr></thead><tbody>${linhas}</tbody></table>
    </body></html>`;

  const w = window.open('', '_blank');
  w.document.write(html);
  w.document.close();
  w.print();
}
