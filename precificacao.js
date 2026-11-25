// ═══════════════════════════════════════════════════════════════════════════
// PRECIFICAÇÃO (24/11/2026)
//
// O que lê (nada de número chumbado):
//   est_produtos        VENDA ativos: custo_comp, preco_venda, categoria (= grupo),
//                       foto_url e is_revenda (estas duas só depois do SQL_PRECIFICACAO.sql)
//   est_fichas_tecnicas quem tem ficha ativa (com ficha, custo_comp já é o custo da porção)
//   vw_faturamento_dia  faturamento do PDV por unidade (Centro = salão, P10 = delivery)
//
// O que grava:
//   inv_configuracoes['precificacao_config']  todas as escolhas da tela (composição,
//                       grupos por canal, produtos ocultos, iscas, preços propostos)
//   est_produtos.preco_venda  SÓ no "Já mudei no PDV". preco_venda é o espelho do preço
//                       de tabela do iComanda e outros relatórios (Saúde das Fichas, CMV)
//                       leem esse campo: preço que ainda é estudo fica como "proposto".
//
// Regras de segurança da lista:
//   grupo novo entra DESLIGADO nos dois canais; produto novo entra OCULTO nos dois.
//   Só aparecem depois que alguém liga na aba Configuração.
//
// A conta (a "alma" das planilhas do salão e do delivery):
//   Salão     mínimo = custo × markup,  markup = 1 ÷ (1 − variáveis − fixo − lucro)
//   Delivery  mínimo = custo ÷ (1 − fixo − cartão/imposto − lucro)
//             iFood  = (próprio + próprio × coef) ÷ (1 − comissão)
//             coef   = (entrega grátis + Campanha Inteligente) ÷ ticket médio
//   Revenda   mínimo = custo ÷ CMV alvo (0,40 → markup 2,5), nos dois canais
// ═══════════════════════════════════════════════════════════════════════════

const _PC_CFG = 'precificacao_config';
const _PC_CORTESIA = 0.02;   // R$ 0,01 = comp de músico/guia/cantor: não é preço de verdade
const _PC_CANAIS = ['salao', 'deliv'];
const _PC_NOME_CANAL = { salao: 'Salão', deliv: 'Delivery' };

const _pc = {
  cfg: null,
  sets: null,
  prods: [],
  porId: new Map(),
  grupos: [],           // grupos que têm produto VENDA (índice usado nos botões da Configuração)
  chips: [],            // grupos mostrados nos chips da aba Preços (índice usado nos chips)
  colsOk: true,         // foto_url / is_revenda existem no banco?
  canal: 'salao',
  aba: 'precos',
  busca: '',
  sit: 'todos',
  ordem: 'nome',
  filtroGrupos: new Set(),
  compAberta: false,
  abertosCfg: new Set(),
  fat: null,
  carregando: null,
  erro: null,
};

// ── configuração ────────────────────────────────────────────────────────────
// Valores iniciais da composição = planilhas antigas (o Wagner avisou que estão
// desatualizados). Ficam editáveis na tela; o fixo real sai da aba Despesas.
function _pcPadrao() {
  return {
    salao: { imp: 4.8, com: 0, tax: 3.0, var: 2.6, fix: 56.9, luc: 6.7 },
    deliv: { fix: 26.9, var: 0, ci: 8.3, com: 13.1, luc: 30, eg: 10, fg: 5, tk: 72.73 },
    revcmv: 40,
    grupos: {},                         // nome -> { salao, deliv }; fora daqui = grupo novo = desligado
    conhecidos: [],                     // produto_id já revisados; fora daqui = novo = oculto
    ocultos: { salao: [], deliv: [] },  // produto_id escondidos de propósito, por canal
    isca: { salao: [], deliv: [] },     // abaixo do mínimo de propósito, por canal
    proposto: {},                       // produto_id -> preço em estudo (um preço por produto, igual ao PDV)
    iniciado: false,
    avisoInicial: false,
  };
}

function _pcMesclar(v) {
  const p = _pcPadrao();
  v = v || {};
  const porCanal = (x, base) => Array.isArray(x) ? { salao: [...x], deliv: [...x] }
    : { salao: [...(x?.salao || base.salao)], deliv: [...(x?.deliv || base.deliv)] };
  const nums = (o, base) => { const r = { ...base }; Object.keys(base).forEach(k => { const n = Number(o?.[k]); if (isFinite(n)) r[k] = n; }); return r; };
  return {
    ...p, ...v,
    salao: nums(v.salao, p.salao),
    deliv: nums(v.deliv, p.deliv),
    revcmv: isFinite(Number(v.revcmv)) && Number(v.revcmv) > 0 ? Number(v.revcmv) : p.revcmv,
    grupos: { ...(v.grupos || {}) },
    conhecidos: [...(v.conhecidos || [])],
    ocultos: porCanal(v.ocultos, p.ocultos),
    isca: porCanal(v.isca, p.isca),
    proposto: { ...(v.proposto || {}) },
  };
}

// Sugestão do primeiro acesso, pelos nomes reais dos grupos (revisável na Configuração).
function _pcPadraoGrupo(nome) {
  const n = norm(nome);
  if (/cantor|sunset|funcionario|roteros|boi (caprichoso|garantido)|semana santa|acoes operacionais|happy hour|lojinha|raizes do norte/.test(n))
    return { salao: false, deliv: false };                 // cortesia, refeição da equipe, evento, promoção, loja
  if (/ifood|delivery|pq10|parque 10/.test(n)) return { salao: false, deliv: true };
  if (/chopp|dose|drink|caipi|cerveja|extras bar|cafe/.test(n)) return { salao: true, deliv: false };
  return { salao: true, deliv: true };
}

function _pcAplicarInicio(c) {
  _pc.grupos.forEach(g => { if (!c.grupos[g]) c.grupos[g] = _pcPadraoGrupo(g); });
  c.conhecidos = _pc.prods.map(p => p.id);
  const semPreco = _pc.prods.filter(p => !(p.preco_venda > _PC_CORTESIA)).map(p => p.id);
  const soDeliv  = _pc.prods.filter(p => /delivery|ifood/.test(norm(p.nome))).map(p => p.id);
  c.ocultos = { salao: [...new Set([...semPreco, ...soDeliv])], deliv: [...semPreco] };
  c.iniciado = true;
  c.avisoInicial = true;
}

function _pcIndexar() {
  const c = _pc.cfg;
  _pc.sets = {
    conhecidos: new Set(c.conhecidos),
    ocultos: { salao: new Set(c.ocultos.salao), deliv: new Set(c.ocultos.deliv) },
    isca: { salao: new Set(c.isca.salao), deliv: new Set(c.isca.deliv) },
  };
}

// ── formatos ────────────────────────────────────────────────────────────────
const _pcNum = (v, d = 2) => (Number(v) || 0).toLocaleString('pt-BR', { minimumFractionDigits: d, maximumFractionDigits: d });
const _pcPct = v => (v == null || !isFinite(v) ? '—' : _pcNum(v, 1) + '%');
function _pcLerNum(s) {
  s = String(s ?? '').trim().replace(/[^\d,.-]/g, '');
  if (s.includes(',')) s = s.replace(/\./g, '').replace(',', '.');
  const v = parseFloat(s);
  return isFinite(v) ? v : NaN;
}
// Arredonda PARA CIMA no próximo ",90" (nunca abaixo do mínimo).
function _pcSnap90(m) {
  let c = Math.floor(m) + 0.90;
  if (c < m - 1e-9) c = Math.floor(m) + 1.90;
  return Math.round(c * 100) / 100;
}
function _pcHue(s) { let h = 0; for (const ch of String(s)) h = (h * 31 + ch.charCodeAt(0)) % 360; return h; }
function _pcGrad(nome) { const h = _pcHue(nome); return `linear-gradient(135deg,hsl(${h} 42% 40%),hsl(${(h + 28) % 360} 45% 27%))`; }
function _pcIniciais(nome) {
  const ps = String(nome || '').split(/[\s\-/]+/).filter(w => w && !/^(de|da|do|das|dos|e|com|a|o)$/i.test(w));
  return ((ps[0]?.[0] || '') + (ps[1]?.[0] || '')).toUpperCase() || '?';
}
const _pcUrlCss = u => encodeURI(u).replace(/'/g, '%27');

// ── leitura ─────────────────────────────────────────────────────────────────
// Paginado e SEM engolir erro (o _fetchAllPaged do app.js devolve lista vazia se der erro).
async function _pcPaginado(tabela, colunas, filtro) {
  const PAGE = 1000;
  let todos = [], from = 0;
  for (;;) {
    let q = sb.from(tabela).select(colunas).range(from, from + PAGE - 1);
    if (filtro) q = filtro(q);
    const { data, error } = await q;
    if (error) throw error;
    todos = todos.concat(data || []);
    if (!data || data.length < PAGE) return todos;
    from += PAGE;
  }
}

async function _pcLerProdutos() {
  const base = 'id,nome,categoria,custo_comp,preco_venda,fator_conversao,perda';
  const filtro = q => q.eq('tipo', 'VENDA').eq('ativo', true).order('nome').order('id');
  try {
    const r = await _pcPaginado('est_produtos', base + ',foto_url,is_revenda', filtro);
    _pc.colsOk = true;
    return r;
  } catch (e) {
    if (!/foto_url|is_revenda|column/i.test(e?.message || '')) throw e;
    _pc.colsOk = false;               // SQL_PRECIFICACAO.sql ainda não rodou: segue sem foto/revenda
    return _pcPaginado('est_produtos', base, filtro);
  }
}

async function _pcLerFichas() {
  const r = await _pcPaginado('est_fichas_tecnicas', 'produto_id', q => q.eq('ativo', true).order('id'));
  return new Set(r.map(x => x.produto_id));
}

async function _pcLerConfig() {
  const { data, error } = await sb.from('inv_configuracoes').select('valor').eq('chave', _PC_CFG).maybeSingle();
  if (error) throw error;
  return data?.valor || null;
}

// Grava lendo ANTES o que está no banco e aplicando só a mudança: duas pessoas mexendo
// em coisas diferentes não apagam a alteração uma da outra. Só toca a chave da Precificação.
async function _pcSalvar(mudar) {
  try {
    if (!await _garantirSessao()) return false;
    const atual = _pcMesclar(await _pcLerConfig());
    mudar(atual);
    const { error } = await sb.from('inv_configuracoes').upsert({ chave: _PC_CFG, valor: atual }, { onConflict: 'chave' });
    if (error) throw error;
    _pc.cfg = atual;
    _pcIndexar();
    return true;
  } catch (e) {
    toast(_msgErroBanco(e), 'erro');
    return false;
  }
}

function _pcMontarProdutos(lista, fichas) {
  _pc.prods = lista.map(p => {
    const ficha = fichas.has(p.id);
    const fator = Number(p.fator_conversao) || 1, perda = Number(p.perda) || 0;
    const bruto = Number(p.custo_comp) || 0;
    // Com ficha, custo_comp é o custo da porção (a ficha grava). Sem ficha é o custo de
    // COMPRA: vira custo de uso pela conversão e pela perda (= "Custo Efetivo" do cadastro).
    const custo = ficha ? bruto : (perda < 100 ? bruto / fator / (1 - perda / 100) : 0);
    return {
      id: p.id, nome: p.nome, foto_url: p.foto_url || null,
      preco_venda: Number(p.preco_venda) || 0,
      _ficha: ficha, _custo: custo, _rev: p.is_revenda === true,
      _grupo: String(p.categoria || '').trim() || 'Sem grupo',
    };
  });
  _pc.porId = new Map(_pc.prods.map(p => [p.id, p]));
  _pc.grupos = [...new Set(_pc.prods.map(p => p._grupo))].sort((a, b) => a.localeCompare(b, 'pt-BR'));
}

async function carregarPrecificacao() {
  if (!_temAcessoPrecif()) return;
  document.getElementById('nav-precificacao')?.classList.add('ativo');
  if (_pc.carregando) return _pc.carregando;
  if (!_pc.cfg) document.getElementById('pc-cards').innerHTML = '<div class="pc-vazio">Carregando produtos, fichas e preços…</div>';
  _pc.carregando = (async () => {
    try {
      const [prods, fichas, cfgBanco] = await Promise.all([_pcLerProdutos(), _pcLerFichas(), _pcLerConfig()]);
      _pcMontarProdutos(prods, fichas);
      _pc.cfg = _pcMesclar(cfgBanco);
      if (!_pc.cfg.iniciado) {
        const ok = await _pcSalvar(c => { if (!c.iniciado) _pcAplicarInicio(c); });
        if (!ok || !_pc.cfg.iniciado) _pcAplicarInicio(_pc.cfg);   // sem gravar, a tela funciona na memória
      }
      _pcIndexar();
      _pc.fat = null;                 // faturamento relido quando abrir Despesas
      _pc.erro = null;
    } catch (e) {
      console.error('precificação:', e);
      _pc.erro = e;
    } finally {
      _pc.carregando = null;
    }
    _pcRender();
  })();
  return _pc.carregando;
}

function pcLimpar() {
  Object.assign(_pc, { cfg: null, sets: null, prods: [], porId: new Map(), grupos: [], chips: [], fat: null, erro: null,
                       busca: '', sit: 'todos', ordem: 'nome', compAberta: false });
  _pc.filtroGrupos.clear();
  _pc.abertosCfg.clear();
  ['pc-kpis', 'pc-cards', 'pc-grupos', 'pc-sit', 'pc-comp', 'pc-aviso', 'pc-view-despesas', 'pc-view-config', 'pc-comp-chip']
    .forEach(id => { const e = document.getElementById(id); if (e) e.innerHTML = ''; });
  const b = document.getElementById('pc-busca');
  if (b) b.value = '';
}

// ── regras ──────────────────────────────────────────────────────────────────
function _pcGrupoNoCanal(g, canal = _pc.canal) { return _pc.cfg.grupos[g]?.[canal] === true; }
function _pcProdNoCanal(p, canal = _pc.canal) { return _pc.sets.conhecidos.has(p.id) && !_pc.sets.ocultos[canal].has(p.id); }
function _pcNoCanal(p, canal = _pc.canal) { return _pcGrupoNoCanal(p._grupo, canal) && _pcProdNoCanal(p, canal); }
function _pcPreco(p) {
  const v = Number(_pc.cfg.proposto[p.id]);
  return v > 0 && Math.abs(v - p.preco_venda) >= 0.005 ? v : p.preco_venda;
}
function _pcTemProposta(p) { return _pcPreco(p) !== p.preco_venda; }

function _pcCalc(p, preco, canal = _pc.canal) {
  const c = _pc.cfg, custo = p._custo, P = preco;
  const rcmv = c.revcmv / 100;
  let minimo, mc = null, ifood = null, eg = null, ci = null;
  if (canal === 'salao') {
    const s = c.salao, varTot = s.imp + s.com + s.tax + s.var;
    const base = (varTot + s.fix + s.luc) / 100;
    const mk = p._rev ? (rcmv > 0 ? 1 / rcmv : Infinity) : (base < 1 ? 1 / (1 - base) : Infinity);
    minimo = custo * mk;
    if (P > 0) mc = (1 - varTot / 100 - custo / P) * 100;
  } else {
    const d = c.deliv, div = 1 - (d.fix + d.var + d.ci + d.luc) / 100;
    minimo = p._rev ? (rcmv > 0 ? custo / rcmv : Infinity) : (div > 0 ? custo / div : Infinity);
    const coef = d.tk > 0 ? (d.eg + d.fg) / d.tk : 0, com = d.com / 100;
    if (P > 0) {
      ifood = com < 1 ? (P + P * coef) / (1 - com) : null;
      eg = d.tk > 0 ? P * d.eg / d.tk : 0;
      ci = d.tk > 0 ? P * d.fg / d.tk : 0;
    }
  }
  const semCusto = !(custo > 0), semPreco = !(P > 0);
  const cmv = !semCusto && !semPreco ? custo / P * 100 : null;
  const adic = !semCusto && !semPreco && isFinite(minimo) ? (P - minimo) / P * 100 : null;
  return { custo, preco: P, minimo, cmv, adic, mc, ifood, eg, ci, semCusto, semPreco };
}

function _pcStatus(p, k, canal = _pc.canal) {
  if (k.semCusto) return { cls: 'sem', txt: 'Sem custo — conferir ficha', grupo: 'sem' };
  if (k.semPreco) return { cls: 'sem', txt: 'Sem preço no PDV', grupo: 'sem' };
  if (k.adic >= 0) return { cls: 'ok', txt: 'Na meta', grupo: 'meta' };
  if (_pc.sets.isca[canal].has(p.id)) return { cls: 'isca', txt: 'Prato-isca', grupo: 'isca' };
  if (k.adic >= -6) return { cls: 'lim', txt: 'No limite', grupo: 'aumento' };
  return { cls: 'mal', txt: 'Abaixo do mínimo', grupo: 'aumento' };
}

function _pcLista() {
  const q = norm(_pc.busca);
  let L = _pc.prods.filter(p => _pcNoCanal(p));
  if (_pc.filtroGrupos.size) L = L.filter(p => _pc.filtroGrupos.has(p._grupo));
  if (q) L = L.filter(p => norm(p.nome).includes(q));
  const base = L.map(p => { const k = _pcCalc(p, _pcPreco(p)); return { p, k, st: _pcStatus(p, k) }; });
  let lista = base;
  if (_pc.sit === 'proposto') lista = base.filter(x => _pcTemProposta(x.p));
  else if (_pc.sit !== 'todos') lista = base.filter(x => x.st.grupo === _pc.sit);
  const ord = {
    abaixo:     (a, b) => (a.k.adic ?? 1e9) - (b.k.adic ?? 1e9),
    cmv:        (a, b) => (b.k.cmv ?? -1) - (a.k.cmv ?? -1),
    preco_desc: (a, b) => b.k.preco - a.k.preco,
    preco_asc:  (a, b) => a.k.preco - b.k.preco,
  }[_pc.ordem];
  if (ord) lista = [...lista].sort(ord);      // 'nome' já vem do banco em ordem de nome
  return { base, lista };
}

// ── tela: casca ─────────────────────────────────────────────────────────────
function _pcRender() {
  document.querySelectorAll('#pc-canais .plan-uni').forEach(b => {
    const on = b.dataset.canal === _pc.canal;
    b.classList.toggle('ativo', on); b.setAttribute('aria-selected', on);
  });
  document.querySelectorAll('#pc-abas .plan-modo').forEach(b => {
    const on = b.dataset.aba === _pc.aba;
    b.classList.toggle('ativo', on); b.setAttribute('aria-selected', on);
  });
  ['precos', 'despesas', 'config'].forEach(a =>
    document.getElementById('pc-view-' + a).classList.toggle('d-none', a !== _pc.aba));

  const aviso = document.getElementById('pc-aviso');
  if (!_pc.cfg) {
    aviso.innerHTML = _pc.erro
      ? `<div class="pc-aviso">Não foi possível carregar a Precificação: ${esc(_msgErroBanco(_pc.erro))}
           <button type="button" class="link" onclick="carregarPrecificacao()">Tentar de novo</button></div>` : '';
    document.getElementById('pc-cards').innerHTML = '';
    return;
  }
  _pcAviso();
  _pcSubs();
  if (_pc.aba === 'precos') _pcRenderPrecos();
  else if (_pc.aba === 'despesas') _pcRenderDespesas();
  else _pcRenderConfig();
}

function _pcNovos() {
  return {
    grupos: _pc.grupos.filter(g => !_pc.cfg.grupos[g]),
    prods: _pc.prods.filter(p => !_pc.sets.conhecidos.has(p.id)),
  };
}

function _pcAviso() {
  const partes = [];
  if (!_pc.colsOk)
    partes.push('Foto e “item de revenda” ainda não funcionam: falta rodar o <b>SQL_PRECIFICACAO.sql</b> no Supabase. O resto da tela já funciona.');
  if (_pc.cfg.avisoInicial)
    partes.push(`<b>Primeiro acesso.</b> Os grupos já vieram separados por canal como sugestão (iFood/Delivery/PQ10 → Delivery; bar → só Salão; cortesias, eventos e Happy Hour desligados). Produtos sem venda no PDV começam ocultos.
      <button type="button" class="link" onclick="pcAba('config')">Conferir na Configuração</button> ·
      <button type="button" class="link" onclick="pcFecharAvisoInicial()">Entendi</button>`);
  const n = _pcNovos();
  if (n.grupos.length || n.prods.length) {
    const t = [n.grupos.length ? `${n.grupos.length} grupo(s) novo(s)` : '', n.prods.length ? `${n.prods.length} produto(s) novo(s)` : ''].filter(Boolean).join(' e ');
    partes.push(`${t} no cadastro: ficam fora da precificação até você decidir. <button type="button" class="link" onclick="pcAba('config')">Revisar</button>`);
  }
  document.getElementById('pc-aviso').innerHTML = partes.map(t => `<div class="pc-aviso">${t}</div>`).join('');
}

function _pcSubs() {
  const n = _pc.prods.filter(p => _pcNoCanal(p)).length;
  document.getElementById('pc-aba-sub-precos').textContent = `${n} no ${_PC_NOME_CANAL[_pc.canal]}`;
  const nv = _pcNovos();
  const tot = nv.grupos.length + nv.prods.length;
  document.getElementById('pc-aba-sub-config').textContent = tot ? `${tot} para revisar` : 'grupos e produtos';
}

function pcCanal(canal) {
  if (!_PC_CANAIS.includes(canal) || _pc.canal === canal) return;
  _pc.canal = canal;
  _pc.filtroGrupos.clear();
  document.getElementById('pc-comp').dataset.canal = '';
  if (_pc.cfg) _pcRender();
}

function pcAba(aba) {
  _pc.aba = aba;
  if (_pc.cfg) _pcRender();
}

async function pcFecharAvisoInicial() {
  _pc.cfg.avisoInicial = false;
  _pcAviso();
  await _pcSalvar(c => { c.avisoInicial = false; });
}

// ── tela: Preços ────────────────────────────────────────────────────────────
function _pcRenderPrecos() {
  _pcChips();
  const { base, lista } = _pcLista();
  _pcKpis(base);
  _pcSitSeg(base);
  _pcCompChip();
  const painel = document.getElementById('pc-comp');
  painel.classList.toggle('d-none', !_pc.compAberta);
  if (_pc.compAberta && painel.dataset.canal !== _pc.canal) _pcCompPainel();
  _pcRenderCards(lista);
}

function _pcRenderCards(lista) {
  const el = document.getElementById('pc-cards');
  if (!lista.length) {
    const algumGrupo = _pc.grupos.some(g => _pcGrupoNoCanal(g));
    el.innerHTML = `<div class="pc-vazio">${algumGrupo
      ? 'Nenhum produto com esse filtro.'
      : `Nenhum grupo ligado no ${_PC_NOME_CANAL[_pc.canal]}. <button type="button" class="btn btn-link p-0 align-baseline" onclick="pcAba('config')">Ligar na Configuração</button>`}</div>`;
    return;
  }
  el.innerHTML = lista.map(x => _pcCardHTML(x.p)).join('');
  el.querySelectorAll('.pc-card').forEach(card => _pcPintar(card, _pc.porId.get(card.dataset.id)));
}

function _pcKpis(base) {
  const deliv = _pc.canal === 'deliv';
  const ok = base.filter(x => !x.k.semCusto && !x.k.semPreco);
  const media = f => (ok.length ? ok.reduce((s, x) => s + f(x), 0) / ok.length : null);
  const aumento = base.filter(x => x.st.grupo === 'aumento').length;
  const semCalc = base.length - ok.length;
  const kpi = (rot, val, sub, alerta) =>
    `<div class="pc-kpi${alerta ? ' alerta' : ''}"><div class="rot">${rot}</div><div class="val">${val}</div>${sub ? `<div class="sub">${sub}</div>` : ''}</div>`;
  const mPreco = media(x => x.k.preco);
  const terceiro = deliv
    ? kpi('iFood médio sugerido', ok.length ? brl(media(x => x.k.ifood || 0)) : '—', 'comissão + entrega grátis + CI')
    : kpi('CMV médio', _pcPct(media(x => x.k.cmv)), `alvo ${_pcPct(_pcCmvAlvoSalao())}`);
  document.getElementById('pc-kpis').innerHTML =
    kpi('Produtos', base.length, semCalc ? `${semCalc} sem custo ou sem preço` : 'com custo e preço') +
    kpi(deliv ? 'Preço médio próprio' : 'Preço médio', mPreco == null ? '—' : brl(mPreco), _pcTemPropostaNaLista(base) ? 'inclui preços propostos' : 'preço de tabela do PDV') +
    terceiro +
    kpi('Precisam de aumento', aumento, aumento ? 'abaixo do mínimo, fora as iscas' : 'nenhum abaixo do mínimo', aumento > 0);
}
const _pcTemPropostaNaLista = base => base.some(x => _pcTemProposta(x.p));
function _pcCmvAlvoSalao() {
  const s = _pc.cfg.salao, base = (s.imp + s.com + s.tax + s.var + s.fix + s.luc) / 100;
  return base < 1 ? (1 - base) * 100 : null;
}

function _pcSitSeg(base) {
  const n = { todos: base.length, aumento: 0, meta: 0, isca: 0, proposto: 0 };
  base.forEach(x => { if (x.st.grupo in n) n[x.st.grupo]++; if (_pcTemProposta(x.p)) n.proposto++; });
  const b = (key, rot) =>
    `<button type="button" class="${_pc.sit === key ? 'ativo' : ''}" aria-pressed="${_pc.sit === key}" onclick="pcFiltro('sit','${key}')">${rot}<span class="n">${n[key]}</span></button>`;
  document.getElementById('pc-sit').innerHTML =
    b('todos', 'Todos') + b('aumento', 'Precisam de aumento') + b('meta', 'Na meta') + b('isca', 'Isca') + b('proposto', 'Propostos');
}

function _pcChips() {
  const cont = {};
  _pc.prods.forEach(p => { if (_pcNoCanal(p)) cont[p._grupo] = (cont[p._grupo] || 0) + 1; });
  _pc.chips = Object.keys(cont).sort((a, b) => a.localeCompare(b, 'pt-BR'));
  [..._pc.filtroGrupos].forEach(g => { if (!cont[g]) _pc.filtroGrupos.delete(g); });
  const total = Object.values(cont).reduce((s, n) => s + n, 0);
  const el = document.getElementById('pc-grupos');
  el.innerHTML = _pc.chips.length < 2 ? '' :
    `<button type="button" class="plan-cat${_pc.filtroGrupos.size ? '' : ' ativo'}" aria-pressed="${!_pc.filtroGrupos.size}" onclick="pcChip(-1)">Todos os grupos<span class="n">${total}</span></button>` +
    _pc.chips.map((g, i) => {
      const on = _pc.filtroGrupos.has(g);
      return `<button type="button" class="plan-cat${on ? ' ativo' : ''}" aria-pressed="${on}" onclick="pcChip(${i})">${esc(g)}<span class="n">${cont[g]}</span></button>`;
    }).join('');
}

function pcChip(i) {
  if (i < 0) _pc.filtroGrupos.clear();
  else {
    const g = _pc.chips[i];
    if (g == null) return;
    _pc.filtroGrupos.has(g) ? _pc.filtroGrupos.delete(g) : _pc.filtroGrupos.add(g);
  }
  _pcRenderPrecos();
}

function pcFiltro(tipo, v) {
  if (!_pc.cfg) return;
  if (tipo === 'busca') _pc.busca = v;
  else if (tipo === 'sit') _pc.sit = v;
  else if (tipo === 'ordem') _pc.ordem = v;
  _pcRenderPrecos();
}

// Card: o esqueleto sai aqui; os números são pintados por _pcPintar (que também roda
// a cada tecla no preço, sem recriar o card e sem tirar o foco do campo).
function _pcCardHTML(p) {
  const deliv = _pc.canal === 'deliv';
  const preco = _pcPreco(p);
  const tags = (p._rev ? '<span class="pc-tag dir">REVENDA</span>' : '') +
    (!p._ficha && !p._rev ? '<span class="pc-tag esq" title="Custo vem do cadastro (compra), não de ficha técnica">SEM FICHA</span>' : '');
  const hero = p.foto_url
    ? `<div class="pc-hero" style="background-image:url('${_pcUrlCss(p.foto_url)}'),${_pcGrad(p.nome)}" role="img" aria-label="Foto de ${esc(p.nome)}">${tags}</div>`
    : `<div class="pc-hero" style="background:${_pcGrad(p.nome)}" aria-hidden="true">${tags}${esc(_pcIniciais(p.nome))}</div>`;
  const caixa = `
      <div class="pc-preco" data-k="box">
        <div class="rot"><span data-k="rotPreco"></span><span class="de" data-k="dePdv"></span></div>
        <div class="linha"><span class="rs">R$</span><input data-id="${p.id}" value="${preco > 0 ? _pcNum(preco) : ''}" placeholder="0,00"
          inputmode="decimal" aria-label="Preço de ${esc(p.nome)}" oninput="pcDigitou(this)" onchange="pcConfirmou(this)"
          onkeydown="if(event.key==='Enter')this.blur();if(event.key==='Escape'){pcVoltarPreco(this);this.blur();}"></div>
      </div>`;
  const precos = deliv
    ? `<div class="pc-precos2">${caixa}<div class="pc-preco ifood" title="Preço sugerido para iFood/99Food (logística própria)"><div class="rot"><span>iFood/99Food</span></div><div class="v" data-k="ifood">—</div></div></div>`
    : caixa;
  const rev = p._rev ? ` · revenda ÷${_pcNum(_pc.cfg.revcmv / 100)}` : '';
  return `
  <article class="pc-card" data-id="${p.id}">
    ${hero}
    <div class="pc-corpo">
      <div><div class="pc-nome">${esc(p.nome)}</div><div class="pc-grupo">${esc(p._grupo)}</div></div>
      <span class="pc-st" data-k="st"></span>
      ${precos}
      <div data-k="prop"></div>
      <div class="pc-linhas">
        <div class="l"><span class="k">${p._ficha ? 'Custo da ficha' : 'Custo (cadastro)'}</span><span class="v">${p._custo > 0 ? brl(p._custo) : '—'}</span></div>
        <div class="l"><span class="k">Preço mínimo${deliv ? ' (próprio)' : ''}${rev}</span><span class="v min" data-k="min"></span></div>
        ${deliv ? `<div class="l"><span class="k">Entrega embutida</span><span class="v" data-k="eg"></span></div>
        <div class="l"><span class="k">Campanha embutida</span><span class="v" data-k="ci"></span></div>` : ''}
        <div class="l"><span class="k">CMV${deliv ? ' (sobre o próprio)' : ''}</span><span class="v" data-k="cmv"></span></div>
        ${deliv ? '' : '<div class="l"><span class="k">Margem de contribuição</span><span class="v" data-k="mc"></span></div>'}
      </div>
      <div class="pc-dica" data-k="dica"></div>
      <div data-k="abaixo"></div>
      <div class="pc-pe"><button type="button" class="btn btn-outline-secondary btn-sm" onclick="pcVerFicha('${p.id}')">
        <i class="bi bi-${p._ficha ? 'diagram-3' : 'box-seam'}"></i> ${p._ficha ? 'Ver ficha técnica' : 'Abrir cadastro'}</button></div>
    </div>
  </article>`;
}

function _pcPintar(card, p, digitado = null) {
  if (!card || !p) return;
  const deliv = _pc.canal === 'deliv';
  const preco = digitado != null ? digitado : _pcPreco(p);
  const k = _pcCalc(p, preco), st = _pcStatus(p, k);
  const $k = s => card.querySelector(`[data-k="${s}"]`);

  const elSt = $k('st');
  elSt.className = 'pc-st ' + st.cls;
  elSt.textContent = st.txt;
  $k('min').textContent = k.semCusto || !isFinite(k.minimo) ? '—' : brl(k.minimo);
  $k('cmv').textContent = _pcPct(k.cmv);
  if (deliv) {
    $k('ifood').textContent = k.ifood == null ? '—' : brl(k.ifood);
    $k('eg').textContent = k.eg == null ? '—' : brl(k.eg);
    $k('ci').textContent = k.ci == null ? '—' : brl(k.ci);
  } else {
    $k('mc').textContent = _pcPct(k.mc);
  }

  // Caixa do preço: tabela do PDV × proposto.
  const difPdv = Math.abs(preco - p.preco_venda) >= 0.005 && preco > 0;
  $k('box').classList.toggle('proposto', difPdv);
  $k('rotPreco').textContent = difPdv ? (deliv ? 'Próprio · proposto' : 'Preço proposto') : (deliv ? 'Próprio · PDV' : 'Preço · PDV');
  $k('dePdv').textContent = difPdv ? `PDV: ${p.preco_venda > 0 ? brl(p.preco_venda) : 'sem preço'}` : '';
  if (digitado == null) {
    $k('prop').innerHTML = _pcTemProposta(p)
      ? `<div class="pc-prop"><span><i class="bi bi-arrow-repeat"></i> Mude no iComanda e confirme:</span>
           <button type="button" class="btn btn-success btn-sm pc-mini" onclick="pcAplicarPdv('${p.id}')">Já mudei no PDV</button>
           <button type="button" class="btn btn-outline-secondary btn-sm pc-mini" onclick="pcDescartar('${p.id}')">Descartar</button></div>`
      : '';
  }

  const dica = $k('dica');
  if (k.adic == null) {
    dica.textContent = k.semCusto ? 'Sem custo no cadastro: não dá para calcular o mínimo.' : 'Digite um preço para ver CMV e margem.';
  } else {
    const lado = k.adic >= 0 ? `<b>${_pcPct(k.adic)}</b> acima do mínimo` : `<b style="color:var(--pl-vermelho)">${_pcPct(-k.adic)}</b> abaixo do mínimo`;
    dica.innerHTML = deliv && k.ifood != null ? `${lado} · iFood <b>${_pcPct((k.ifood / preco - 1) * 100)}</b> acima do próprio` : lado;
  }

  const ab = $k('abaixo');
  const isca = _pc.sets.isca[_pc.canal].has(p.id);
  if (k.adic != null && k.adic < 0 && !isca) {
    ab.innerHTML = `<div class="pc-abaixo"><span>Abaixo do mínimo de <b>${brl(k.minimo)}</b></span>
      <button type="button" class="btn btn-danger btn-sm pc-mini" onclick="pcSubir('${p.id}')">Subir para ${brl(_pcSnap90(k.minimo))}</button>
      <label><input type="checkbox" onchange="pcIsca('${p.id}', this.checked)"> manter como isca</label></div>`;
  } else if (k.adic != null && k.adic < 0 && isca) {
    ab.innerHTML = `<div class="pc-abaixo isca"><span>Prato-isca: abaixo do mínimo de propósito</span>
      <label class="ms-auto"><input type="checkbox" checked onchange="pcIsca('${p.id}', this.checked)"> isca</label></div>`;
  } else {
    ab.innerHTML = '';
  }
}

function _pcCard(id) { return document.querySelector(`#pc-cards .pc-card[data-id="${id}"]`); }
function _pcRepintar(id) {
  const card = _pcCard(id), p = _pc.porId.get(id);
  if (!card || !p) return;
  const inp = card.querySelector('input[data-id]');
  if (inp && document.activeElement !== inp) { const v = _pcPreco(p); inp.value = v > 0 ? _pcNum(v) : ''; }
  _pcPintar(card, p);
  const { base } = _pcLista();
  _pcKpis(base);
  _pcSitSeg(base);
}

function pcDigitou(inp) {
  const p = _pc.porId.get(inp.dataset.id);
  if (!p) return;
  const v = _pcLerNum(inp.value);
  _pcPintar(inp.closest('.pc-card'), p, v > 0 ? v : 0);
}

function pcVoltarPreco(inp) {
  const p = _pc.porId.get(inp.dataset.id);
  if (!p) return;
  const v = _pcPreco(p);
  inp.value = v > 0 ? _pcNum(v) : '';
  _pcPintar(inp.closest('.pc-card'), p);
}

async function pcConfirmou(inp) {
  const id = inp.dataset.id, p = _pc.porId.get(id);
  if (!p) return;
  let v = _pcLerNum(inp.value);
  if (!(v > 0)) { pcVoltarPreco(inp); return; }       // vazio ou zero: volta ao que era
  v = Math.round(v * 100) / 100;
  const igualPdv = Math.abs(v - p.preco_venda) < 0.005;
  if (igualPdv && !(id in _pc.cfg.proposto)) { _pcRepintar(id); return; }
  const ok = await _pcSalvar(c => { if (igualPdv) delete c.proposto[id]; else c.proposto[id] = v; });
  if (!ok) { pcVoltarPreco(inp); return; }
  _pcRepintar(id);
}

async function pcSubir(id) {
  const p = _pc.porId.get(id);
  if (!p) return;
  const k = _pcCalc(p, _pcPreco(p));
  if (!isFinite(k.minimo) || !(k.minimo > 0)) return;
  const v = _pcSnap90(k.minimo);
  const igualPdv = Math.abs(v - p.preco_venda) < 0.005;
  if (await _pcSalvar(c => { if (igualPdv) delete c.proposto[id]; else c.proposto[id] = v; })) {
    const inp = _pcCard(id)?.querySelector('input[data-id]');
    if (inp) inp.value = _pcNum(v);
    _pcRepintar(id);
  }
}

async function pcIsca(id, on) {
  const canal = _pc.canal;
  if (await _pcSalvar(c => {
    c.isca[canal] = c.isca[canal].filter(x => x !== id);
    if (on) c.isca[canal].push(id);
  })) _pcRepintar(id);
  else _pcRepintar(id);   // não gravou: volta o check ao estado salvo
}

async function pcDescartar(id) {
  if (await _pcSalvar(c => { delete c.proposto[id]; })) _pcRepintar(id);
}

async function pcAplicarPdv(id) {
  const p = _pc.porId.get(id);
  const v = Number(_pc.cfg.proposto[id]);
  if (!p || !(v > 0)) return;
  if (!confirm(`Confirma que "${p.nome}" já está a ${brl(v)} no iComanda?\n\nO cadastro do produto passa a usar esse preço (relatórios e fichas também).`)) return;
  if (!await _garantirSessao()) return;
  const { error } = await sb.from('est_produtos').update({ preco_venda: v }).eq('id', id);
  if (error) { toast(_msgErroBanco(error), 'erro'); return; }
  p.preco_venda = v;
  const cache = (typeof cProdutosFT !== 'undefined') ? cProdutosFT.find(x => x.id === id) : null;
  if (cache) cache.preco_venda = v;
  await _pcSalvar(c => { delete c.proposto[id]; });
  _pcRepintar(id);
  toast(`Preço de ${p.nome} atualizado no cadastro.`, 'ok');
}

// Produto com ficha: abre a ficha numa janela por cima, só para conferir (igual ao rascunho).
// Editar é no Estoque, pelo botão da janela. Sem ficha: vai direto ao cadastro.
let _pcFichaVez = 0;
async function pcVerFicha(id) {
  const p = _pc.porId.get(id);
  if (!p?._ficha) return _pcIrCadastro(id, false);
  const vez = ++_pcFichaVez;
  const el = document.getElementById('modal-pc-ficha');
  document.getElementById('pc-ficha-nome').textContent = p.nome;
  document.getElementById('pc-ficha-sub').textContent = (p._grupo || 'Sem grupo') + ' · ficha técnica · conferência';
  document.getElementById('pc-ficha-corpo').innerHTML = '<div class="pc-ficha-msg">Carregando a ficha…</div>';
  document.getElementById('pc-ficha-abrir').onclick = () => _pcIrCadastro(id, true);
  bootstrap.Modal.getOrCreateInstance(el).show();
  try {
    const html = await _pcFichaHTML(p);
    if (vez === _pcFichaVez) document.getElementById('pc-ficha-corpo').innerHTML = html;
  } catch (e) {
    if (vez === _pcFichaVez) document.getElementById('pc-ficha-corpo').innerHTML =
      `<div class="pc-ficha-msg erro">Não consegui ler a ficha: ${esc(_msgErroBanco(e))}</div>`;
  }
}

async function _pcFichaHTML(p) {
  const { data: fichas, error: e1 } = await sb.from('est_fichas_tecnicas')
    .select('id,rendimento,unidade_rendimento').eq('produto_id', p.id).eq('ativo', true).order('id').limit(1);
  if (e1) throw e1;
  const ficha = fichas?.[0];
  if (!ficha) return '<div class="pc-ficha-msg">Este produto não tem ficha ativa.</div>';
  const { data: ings, error: e2 } = await sb.from('est_ficha_ingredientes')
    .select('ingrediente_id,quantidade').eq('ficha_id', ficha.id);
  if (e2) throw e2;
  const ids = [...new Set((ings || []).map(i => i.ingrediente_id))];
  let insumos = [];
  if (ids.length) {
    const { data, error: e3 } = await sb.from('est_produtos')
      .select('id,nome,unidade_uso,fator_conversao,perda,custo_comp,custo_uso').in('id', ids);
    if (e3) throw e3;
    insumos = data || [];
  }
  const porIns = new Map(insumos.map(x => [x.id, x]));
  // Mesma conta da ficha no Estoque: custo de compra ÷ conversão ÷ (1 − perda).
  const efetivo = x => {
    const r = 1 - (Number(x.perda) || 0) / 100;
    return r > 0 ? (Number(x.custo_comp) || Number(x.custo_uso) || 0) / (Number(x.fator_conversao) || 1) / r : 0;
  };
  const linhas = (ings || []).map(i => {
    const x = porIns.get(i.ingrediente_id);
    const qtd = Number(i.quantidade) || 0;
    return { nome: x?.nome || 'Insumo não encontrado', un: (x?.unidade_uso || '').trim(), qtd, valor: x ? qtd * efetivo(x) : 0 };
  }).sort((a, b) => b.valor - a.valor);
  const total = linhas.reduce((s, l) => s + l.valor, 0);
  const rend = Number(ficha.rendimento) || 1;
  const porcao = total / rend;
  const qtdTxt = l => `${l.qtd.toLocaleString('pt-BR', { maximumFractionDigits: 3 })}${l.un ? ' ' + esc(l.un) : ''}`;
  const rendTxt = rend !== 1
    ? `<div class="pc-ficha-lin sub"><span>Custo total · rende ${_pcNum(rend, rend % 1 ? 2 : 0)} ${esc(ficha.unidade_rendimento || 'porções')}</span><b>R$ ${_pcNum(total)}</b></div>` : '';
  const dif = Math.abs(porcao - p._custo) > 0.01
    ? `<div class="pc-ficha-msg">O card usa o custo gravado no cadastro (R$ ${_pcNum(p._custo)}). A diferença vem de preço de insumo que mudou depois; ela se acerta quando a ficha for salva de novo no Estoque.</div>` : '';
  return `<div class="pc-ficha-lista">${linhas.map(l => `
      <div class="pc-ficha-lin"><span>${esc(l.nome)} <small>${qtdTxt(l)}</small></span><b>R$ ${_pcNum(l.valor)}</b></div>`).join('')
      || '<div class="pc-ficha-msg">A ficha está sem ingredientes.</div>'}
    </div>
    ${rendTxt}
    <div class="pc-ficha-lin tot"><span>Custo da ficha${rend !== 1 ? ' (por porção)' : ''}</span><b>R$ ${_pcNum(porcao)}</b></div>
    ${dif}
    <div class="pc-ficha-nota"><i class="bi bi-search"></i> Só para conferir. A ficha é a mesma do Estoque; editar os insumos é lá.</div>`;
}

async function _pcIrCadastro(id, abaFicha) {
  const el = document.getElementById('modal-pc-ficha');
  bootstrap.Modal.getInstance(el)?.hide();
  document.getElementById('nav-precificacao')?.classList.remove('ativo');   // senão o menu fica com 2 itens acesos
  await abrirProduto(id);
  if (abaFicha) irAba('ficha', document.querySelectorAll('#tabs-prod .nav-link')[1]);
}

// ── composição (parâmetros do markup) ───────────────────────────────────────
const _PC_CAMPOS = {
  salao: [['imp', 'Impostos', '%'], ['com', 'Comissão', '%'], ['tax', 'Taxas de cartão', '%'],
          ['var', 'Variável / perdas', '%'], ['fix', 'Custos fixos', '%'], ['luc', 'Lucro', '%']],
  deliv: [['fix', 'Custo fixo (delivery)', '%'], ['var', 'Variável (embalagem, gás…)', '%'], ['ci', 'Cartão + imposto', '%'], ['com', 'Comissão do app', '%'],
          ['luc', 'Lucro', '%'], ['eg', 'Entrega por pedido', 'R$'], ['fg', 'Campanha por pedido', 'R$'], ['tk', 'Ticket médio', 'R$']],
};

function _pcCompChip() {
  const c = _pc.cfg, chip = document.getElementById('pc-comp-chip');
  const rev = `<span class="sep"></span>Revenda <b>÷${_pcNum(c.revcmv / 100)}</b>`;
  if (_pc.canal === 'salao') {
    const alvo = _pcCmvAlvoSalao();
    chip.innerHTML = `<i class="bi bi-sliders"></i> Markup <b>${alvo ? _pcNum(100 / alvo) : '—'}</b><span class="sep"></span>CMV alvo <b>${_pcPct(alvo)}</b>${rev}`;
  } else {
    const d = c.deliv;
    chip.innerHTML = `<i class="bi bi-sliders"></i> Coef. entrega <b>${_pcPct(d.tk > 0 ? (d.eg + d.fg) / d.tk * 100 : null)}</b><span class="sep"></span>Comissão <b>${_pcPct(d.com)}</b>${rev}`;
  }
  chip.setAttribute('aria-expanded', String(_pc.compAberta));
}

function pcToggleComp() {
  if (!_pc.cfg) return;
  _pc.compAberta = !_pc.compAberta;
  const painel = document.getElementById('pc-comp');
  painel.classList.toggle('d-none', !_pc.compAberta);
  if (_pc.compAberta) _pcCompPainel();
  _pcCompChip();
}

function _pcCompPainel() {
  const canal = _pc.canal, obj = _pc.cfg[canal];
  const painel = document.getElementById('pc-comp');
  painel.dataset.canal = canal;
  const campo = (grupo, k, rot, un, val) => `
    <label class="d-block mb-0"><span class="plan-painel-rot">${rot}</span>
      <span class="input-group input-group-sm" style="width:150px">
        ${un === 'R$' ? '<span class="input-group-text">R$</span>' : ''}
        <input type="text" inputmode="decimal" class="form-control text-end" value="${_pcNum(val, un === 'R$' ? 2 : 1)}"
          oninput="pcComp('${grupo}','${k}',this.value,false)" onchange="pcComp('${grupo}','${k}',this.value,true)">
        ${un === '%' ? '<span class="input-group-text">%</span>' : ''}
      </span></label>`;
  painel.innerHTML = `
    <div class="plan-painel-grade">
      ${_PC_CAMPOS[canal].map(([k, r, u]) => campo(canal, k, r, u, obj[k])).join('')}
      ${campo('rev', 'revcmv', 'CMV alvo revenda', '%', _pc.cfg.revcmv)}
    </div>
    <div class="plan-como" id="pc-comp-resumo"></div>`;
  _pcCompResumo();
}

function _pcCompResumo() {
  const el = document.getElementById('pc-comp-resumo');
  if (!el) return;
  const c = _pc.cfg, rc = c.revcmv / 100;
  const revTxt = `<dt>Revenda</dt><dd>mínimo = custo ÷ ${_pcNum(rc)} (markup ${rc > 0 ? _pcNum(1 / rc) : '—'}). Vale para item marcado como revenda no cadastro.</dd>`;
  if (_pc.canal === 'salao') {
    const s = c.salao, varTot = s.imp + s.com + s.tax + s.var, alvo = _pcCmvAlvoSalao();
    el.innerHTML = `<dl>
      <dt>Variáveis</dt><dd>${_pcPct(varTot)} (impostos + comissão + cartão + perdas)</dd>
      <dt>Markup</dt><dd>${alvo ? _pcNum(100 / alvo) : '—'} → CMV alvo ${_pcPct(alvo)}. Mínimo = custo da ficha × markup.</dd>
      ${revTxt}
      <dt>De onde vem</dt><dd>A aba <b>Despesas</b> traz os % reais do Financeiro (botão "Usar estes números"). O lucro é decisão sua. CMV entra pela ficha, não soma no fixo.</dd></dl>`;
  } else {
    const d = c.deliv;
    el.innerHTML = `<dl>
      <dt>%MNT</dt><dd>${_pcPct(d.fix + d.var + d.ci)} (fixo + variável + cartão/imposto). Mínimo do próprio = custo ÷ (1 − %MNT − lucro).</dd>
      <dt>Coeficiente</dt><dd>${_pcPct(d.tk > 0 ? (d.eg + d.fg) / d.tk * 100 : null)} = (entrega por pedido + campanha por pedido) ÷ ticket médio.</dd>
      <dt>iFood</dt><dd>(próprio + próprio × coeficiente) ÷ (1 − comissão).</dd>
      ${revTxt}</dl>`;
  }
}

async function pcComp(grupo, k, txt, salvar) {
  const v = _pcLerNum(txt);
  if (!isFinite(v) || v < 0) return;
  if (grupo === 'rev') { if (!(v > 0 && v < 100)) return; _pc.cfg.revcmv = v; }
  else _pc.cfg[grupo][k] = v;
  _pcCompChip();
  _pcCompResumo();
  const { base, lista } = _pcLista();
  _pcKpis(base); _pcSitSeg(base); _pcRenderCards(lista);
  if (salvar) await _pcSalvar(c => { if (grupo === 'rev') c.revcmv = v; else c[grupo][k] = v; });
}

// ── tela: Despesas ──────────────────────────────────────────────────────────
// Fonte: vw_precificacao_mensal, feita e mantida pelo Financeiro (classificação do plano de
// contas, rateio, competência = vencimento). Aqui só se lê e se converte em % da composição.
// Salão = unidade Centro; Delivery = unidade P10 (nomes curtos já traduzidos pela view).
const _PC_UNI = { salao: 'Centro', deliv: 'P10' };
const _pcMesNome = mes => { const [y, m] = mes.split('-'); return ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'][+m - 1] + '/' + y.slice(2); };
const _PC_GRUPOS_DESP = [
  ['imposto_venda', 'Impostos sobre venda'],
  ['taxa_cartao', 'Taxa de cartão (maquininha)'],
  ['antecipacao_cartao', 'Antecipação do cartão'],
  ['comissao_venda', 'Comissão sobre venda'],
  ['variavel', 'Variável (embalagem, gás, limpeza…)'],
  ['fixo', 'Fixo (pessoal, aluguel, energia…)'],
  ['delivery_comissao', 'App de delivery (comissão + campanha)'],
  ['delivery_entrega', 'Entrega (motoboy)'],
  ['delivery_campanha', 'Campanha no app'],
  ['cmv', 'CMV realizado'],
  ['fora', 'Fora da operação'],
];

async function _pcLerDespesas() {
  const { data, error } = await sb.from('vw_precificacao_mensal')
    .select('mes,unidade,grupo,valor,fechado,tipo,origem').eq('tipo', 'realizado').order('mes');
  if (error) throw error;
  const meses = new Map();   // mes -> { fechado, porUni: { Centro: {grupo: valor} } }
  (data || []).forEach(r => {
    const mes = String(r.mes).slice(0, 7);
    const m = meses.get(mes) || { mes, fechado: false, porUni: {}, origem: {} };
    m.fechado = m.fechado || r.fechado === true;
    (m.porUni[r.unidade] = m.porUni[r.unidade] || {})[r.grupo] = Number(r.valor) || 0;
    if (r.origem) (m.origem[r.unidade] = m.origem[r.unidade] || {})[r.grupo] = r.origem;
    meses.set(mes, m);
  });
  _pc.fat = { meses: [...meses.values()].sort((x, y) => x.mes.localeCompare(y.mes)) };
}

// Soma dos meses fechados ÷ faturamento dos mesmos meses (média ponderada, não média de %).
function _pcDespResumo(canal) {
  const u = _PC_UNI[canal];
  const fech = (_pc.fat?.meses || []).filter(m => m.fechado && m.porUni[u]?.faturamento > 0);
  const soma = g => fech.reduce((s, m) => s + (m.porUni[u][g] || 0), 0);
  const fat = soma('faturamento'), ped = soma('pedidos');
  const pct = g => fat > 0 ? soma(g) / fat * 100 : null;
  return { u, fech, fat, ped, n: fech.length, pct, soma,
    fatMes: fech.length ? fat / fech.length : 0, ticket: ped > 0 ? fat / ped : null,
    porPedido: g => ped > 0 ? soma(g) / ped : null };
}

// O que a view sugere para cada campo da composição. O lucro fica de fora: é decisão do dono.
function _pcDespPropostas(canal) {
  const r = _pcDespResumo(canal);
  if (!r.n) return null;
  const p1 = v => v == null ? null : Math.round(v * 10) / 10, r2 = v => v == null ? null : Math.round(v * 100) / 100;
  if (canal === 'salao') return {
    imp: p1(r.pct('imposto_venda')), tax: p1((r.pct('taxa_cartao') || 0) + (r.pct('antecipacao_cartao') || 0)), com: p1(r.pct('comissao_venda')),
    var: p1(r.pct('variavel')), fix: p1(r.pct('fixo')),
  };
  return {
    fix: p1(r.pct('fixo')), var: p1(r.pct('variavel')),
    ci: p1((r.pct('taxa_cartao') || 0) + (r.pct('antecipacao_cartao') || 0) + (r.pct('imposto_venda') || 0)),
    eg: r2(r.porPedido('delivery_entrega')), fg: r2(r.porPedido('delivery_campanha')), tk: r2(r.ticket),
  };
}

// Quantos produtos do canal mudam de situação se a composição virar `nova`.
function _pcDespImpacto(canal, nova) {
  const prods = _pc.prods.filter(p => _pcNoCanal(p, canal));
  const antes = _pc.cfg[canal];
  const medir = () => {
    let abaixo = 0, somaMin = 0, n = 0;
    prods.forEach(p => {
      const k = _pcCalc(p, _pcPreco(p), canal);
      if (k.semCusto || k.semPreco || !isFinite(k.minimo)) return;
      n++; somaMin += k.minimo;
      if (k.adic < 0 && !_pc.sets.isca[canal].has(p.id)) abaixo++;
    });
    return { abaixo, minMedio: n ? somaMin / n : 0 };
  };
  const a = medir();
  let d;
  _pc.cfg[canal] = { ...antes, ...nova };
  try { d = medir(); } finally { _pc.cfg[canal] = antes; }
  return { antes: a, depois: d };
}

async function _pcRenderDespesas() {
  const el = document.getElementById('pc-view-despesas');
  if (!_pc.fat) {
    el.innerHTML = '<div class="pc-vazio">Lendo as despesas do Financeiro…</div>';
    try { await _pcLerDespesas(); }
    catch (e) {
      el.innerHTML = `<div class="pc-aviso">Não deu para ler as despesas do Financeiro (vw_precificacao_mensal): ${esc(_msgErroBanco(e))}</div>`;
      return;
    }
    if (_pc.aba !== 'despesas') return;
  }
  const canal = _pc.canal, c = _pc.cfg, r = _pcDespResumo(canal), nome = _PC_NOME_CANAL[canal];
  if (!r.n) {
    el.innerHTML = `<div class="pc-aviso">O Financeiro ainda não tem mês fechado para a unidade ${esc(r.u)}.</div>`;
    return;
  }
  const prop = _pcDespPropostas(canal);
  const r0 = v => 'R$ ' + Math.round(v || 0).toLocaleString('pt-BR');
  const fora = r.pct('fora');
  const periodo = r.fech.map(m => _pcMesNome(m.mes)).join(' + ');
  const abertos = _pc.fat.meses.filter(m => !m.fechado && m.porUni[r.u]).map(m => _pcMesNome(m.mes));

  // destino de cada grupo na composição deste canal
  const destino = canal === 'salao'
    ? { imposto_venda: 'imp', taxa_cartao: 'tax', antecipacao_cartao: 'tax', comissao_venda: 'com', variavel: 'var', fixo: 'fix' }
    : { imposto_venda: 'ci', taxa_cartao: 'ci', antecipacao_cartao: 'ci', variavel: 'var', fixo: 'fix', delivery_entrega: 'eg', delivery_campanha: 'fg' };
  const notaGrupo = {
    salao: { delivery_comissao: 'pedido de app do Centro: não entra no salão', delivery_entrega: 'idem', delivery_campanha: 'idem',
             cmv: 'só referência: o preço usa a ficha', fora: 'o lucro precisa cobrir' },
    deliv: { delivery_comissao: 'a comissão do app é % do preço do app: ajuste à mão', comissao_venda: 'zero na casa',
             cmv: 'só referência: o preço usa a ficha', fora: 'o lucro precisa cobrir' },
  }[canal];
  const rotCampo = Object.fromEntries(_PC_CAMPOS[canal].map(([k, rot]) => [k, rot]));
  const origemTxt = { rateio_faturamento: 'rateado pelo faturamento', derivado: 'calculado pelo Financeiro',
    estimado: 'estimada pela taxa da cessão ao Santander, conferida com o extrato do banco' };

  const linhas = _PC_GRUPOS_DESP.map(([g, rot]) => {
    const tot = r.soma(g);
    const meses = r.fech.map(m => { const f = m.porUni[r.u].faturamento; return f > 0 ? (m.porUni[r.u][g] || 0) / f * 100 : null; });
    const orig = g === 'antecipacao_cartao' ? 'estimado' : r.fech.map(m => m.origem[r.u]?.[g]).find(Boolean);
    const dest = destino[g], nota = notaGrupo[g] || (dest ? '→ ' + rotCampo[dest] : '');
    const ref = g === 'cmv' || g === 'fora';
    return `<tr${ref ? ' class="text-muted"' : ''}>
      <td>${rot}${orig && origemTxt[orig] ? `<div class="small text-muted">${origemTxt[orig]}</div>` : ''}</td>
      ${meses.map(v => `<td class="text-end">${_pcPct(v)}</td>`).join('')}
      <td class="text-end fw-bold">${_pcPct(r.pct(g))}</td>
      <td class="text-end text-nowrap">${r0(tot / r.n)}</td>
      <td class="small">${esc(nota)}</td></tr>`;
  }).join('');

  // comparação campo a campo com o que está na composição hoje
  const fmt = (k, v) => v == null ? '—' : (['eg', 'fg', 'tk'].includes(k) ? brl(v) : _pcPct(v));
  const muda = Object.entries(prop).filter(([k, v]) => v != null && Math.abs(v - c[canal][k]) >= (['eg', 'fg', 'tk'].includes(k) ? 0.005 : 0.05));
  const imp = muda.length ? _pcDespImpacto(canal, Object.fromEntries(muda)) : null;
  // mesmo cálculo com o lucro cobrindo o que está fora da operação (decisão de 25/11)
  const lucFora = fora != null ? Math.round(fora * 10) / 10 : null;
  const impFora = imp && lucFora != null && lucFora > c[canal].luc + 0.05
    ? _pcDespImpacto(canal, { ...Object.fromEntries(muda), luc: lucFora }) : null;
  const comp = Object.entries(prop).map(([k, v]) => `<tr${muda.some(x => x[0] === k) ? ' class="fw-bold"' : ''}>
      <td>${rotCampo[k]}</td><td class="text-end">${fmt(k, c[canal][k])}</td><td class="text-end">${fmt(k, v)}</td></tr>`).join('');
  const lucro = c[canal].luc;

  el.innerHTML = `
    <div class="pc-desp-res">
      <div class="pc-kpi"><div class="rot">Faturamento médio / mês</div><div class="val">${r0(r.fatMes)}</div><div class="sub">${esc(r.u)} · ${periodo}</div></div>
      <div class="pc-kpi"><div class="rot">Pedidos / mês · ticket</div><div class="val">${Math.round(r.ped / r.n).toLocaleString('pt-BR')}</div><div class="sub">ticket médio ${r.ticket ? brl(r.ticket) : '—'}</div></div>
      <div class="pc-kpi"><div class="rot">Custos da operação</div><div class="val">${_pcPct(['imposto_venda', 'taxa_cartao', 'antecipacao_cartao', 'comissao_venda', 'variavel', 'fixo', ...(canal === 'deliv' ? ['delivery_comissao', 'delivery_entrega', 'delivery_campanha'] : [])].reduce((s, g) => s + (r.pct(g) || 0), 0))}</div><div class="sub">do faturamento, sem CMV</div></div>
      <div class="pc-kpi${fora != null && lucro < fora ? ' alerta' : ''}"><div class="rot">Fora da operação × lucro</div><div class="val">${_pcPct(fora)}</div>
        <div class="sub">parcelamento, empréstimos, distribuição. Lucro alvo hoje: ${_pcPct(lucro)}${fora != null && lucro < fora ? ' (não cobre)' : ''}</div></div>
    </div>
    <div class="row g-3">
      <div class="col-xl-8">
        <div class="plan-lista" style="overflow-x:auto"><table class="table plan-tabela mb-0">
          <thead><tr><th>% do faturamento · ${esc(r.u)}</th>${r.fech.map(m => `<th class="text-end">${_pcMesNome(m.mes)}</th>`).join('')}<th class="text-end">Média</th><th class="text-end">R$ / mês</th><th>Na composição</th></tr></thead>
          <tbody>${linhas}</tbody>
        </table></div>
        <div class="small text-muted mt-2">Só meses fechados pelo Financeiro${abertos.length ? ` (fora: ${abertos.join(', ')}, ainda aberto ou com faturamento sem unidade)` : ''}. Média = soma dos meses ÷ faturamento dos mesmos meses.</div>
      </div>
      <div class="col-xl-4">
        <div class="plan-painel">
          <span class="plan-painel-rot">Composição do ${nome}: hoje × Financeiro</span>
          <table class="table table-sm mb-2"><thead><tr><th></th><th class="text-end">Hoje</th><th class="text-end">Financeiro</th></tr></thead><tbody>${comp}</tbody></table>
          ${imp ? `<div class="small mb-2">Se usar: preço mínimo médio ${brl(imp.antes.minMedio)} → <b>${brl(imp.depois.minMedio)}</b>; abaixo do mínimo ${imp.antes.abaixo} → <b>${imp.depois.abaixo}</b> produtos.${impFora
              ? `<br>Com lucro de ${_pcPct(lucFora)} (o que está fora da operação): mínimo médio <b>${brl(impFora.depois.minMedio)}</b>, abaixo do mínimo <b>${impFora.depois.abaixo}</b>.` : ''}</div>
            <button type="button" class="btn btn-sm btn-primary" onclick="pcUsarDespesas()">Usar estes números no ${nome}</button>`
            : '<div class="small text-muted">A composição já está igual ao Financeiro.</div>'}
          <div class="plan-como mt-2"><dl>
            <dt>Lucro</dt><dd>não vem do Financeiro: é decisão sua, no painel de composição da aba Preços. Ele precisa cobrir o que está fora da operação.</dd>
            ${canal === 'deliv' ? '<dt>Comissão do app</dt><dd>não muda aqui. A view traz o valor em R$, e a composição usa % sobre o preço do app (o Financeiro mede no agregado: comissão + entrega do app + campanha juntas).</dd>' : ''}
            <dt>Provisório</dt><dd>Central de Produção, Estoque Central e administrativo estão lançados no Centro. O fixo do salão está mais alto e o do delivery mais baixo do que o real, até o Financeiro separar a retaguarda.</dd>
          </dl></div>
        </div>
      </div>
    </div>`;
}

async function pcUsarDespesas() {
  const canal = _pc.canal, prop = _pcDespPropostas(canal);
  if (!prop) return;
  const novo = Object.fromEntries(Object.entries(prop).filter(([, v]) => v != null));
  if (!confirm(`Usar na composição do ${_PC_NOME_CANAL[canal]} os números do Financeiro?\nTodos os preços mínimos desse canal mudam. O lucro não muda.`)) return;
  if (await _pcSalvar(c => { Object.assign(c[canal], novo); })) {
    document.getElementById('pc-comp').dataset.canal = '';
    toast(`${_PC_NOME_CANAL[canal]} agora usa os números do Financeiro.`, 'ok');
    _pcRenderDespesas();
  }
}

// ── tela: Configuração ──────────────────────────────────────────────────────
function _pcRenderConfig() {
  const el = document.getElementById('pc-view-config');
  const c = _pc.cfg;
  const porGrupo = {};
  _pc.prods.forEach(p => { (porGrupo[p._grupo] = porGrupo[p._grupo] || []).push(p); });
  const nv = _pcNovos();
  const sw = (on, attrs, rot, peq, desab) =>
    `<label class="pc-sw${peq ? ' peq' : ''}"${desab ? ` title="${desab}"` : ''}><input type="checkbox" ${on ? 'checked' : ''} ${desab ? 'disabled' : ''} ${attrs} aria-label="${rot}"><span></span></label>`;

  const corpo = _pc.grupos.map((g, i) => {
    const prods = porGrupo[g] || [];
    const novo = !c.grupos[g];
    const aberto = _pc.abertosCfg.has(g);
    const nNovos = prods.filter(p => !_pc.sets.conhecidos.has(p.id)).length;
    const vis = ch => _pcGrupoNoCanal(g, ch)
      ? `${_PC_NOME_CANAL[ch]} ${prods.filter(p => _pcProdNoCanal(p, ch)).length} visíve${prods.filter(p => _pcProdNoCanal(p, ch)).length === 1 ? 'l' : 'is'}`
      : `${_PC_NOME_CANAL[ch]} desligado`;
    const sub = [`${prods.length} produto${prods.length === 1 ? '' : 's'}`,
                 `${vis('salao')} · ${vis('deliv')}`,
                 nNovos ? `<span style="color:var(--pl-ambar);font-weight:700">${nNovos} novo${nNovos === 1 ? '' : 's'}</span>` : ''].filter(Boolean).join(' · ');
    let html = `<tr class="plan-linha${aberto ? ' plan-aberta' : ''}" onclick="pcCfgAbrir(${i})">
        <td><div class="plan-nome"><i class="bi bi-chevron-right"></i>${esc(g)}${novo ? '<span class="pc-novo">NOVO</span>' : ''}</div><div class="plan-sub">${sub}</div></td>
        ${_PC_CANAIS.map(ch => `<td class="text-center" onclick="event.stopPropagation()">${sw(_pcGrupoNoCanal(g, ch), `onchange="pcCfgGrupo(${i},'${ch}',this.checked)"`, `${esc(g)} no ${_PC_NOME_CANAL[ch]}`)}</td>`).join('')}
      </tr>`;
    if (aberto) {
      html += prods.map(p => {
        const conhecido = _pc.sets.conhecidos.has(p.id);
        const algumVisivel = _PC_CANAIS.some(ch => _pcGrupoNoCanal(g, ch) && _pcProdNoCanal(p, ch));
        const thumb = p.foto_url
          ? `<span class="pc-thumb" style="background-image:url('${_pcUrlCss(p.foto_url)}'),${_pcGrad(p.nome)}" role="img" aria-label="Foto"></span>`
          : `<span class="pc-thumb" style="background:${_pcGrad(p.nome)}" aria-hidden="true">${esc(_pcIniciais(p.nome))}</span>`;
        const pv = p.preco_venda > _PC_CORTESIA ? brl(p.preco_venda) : (p.preco_venda > 0 ? 'cortesia' : 'sem venda no PDV');
        return `<tr class="pc-prod-tr${algumVisivel ? '' : ' oculto'}">
          <td><div class="pc-prod-nm">${thumb}<span class="nm" title="${esc(p.nome)}">${esc(p.nome)}${conhecido ? '' : '<span class="pc-novo">NOVO</span>'}${p._rev ? '<span class="pc-novo" style="background:#e0e7ff;color:#1e40af">REVENDA</span>' : ''}</span><span class="pv">${pv}</span></div></td>
          ${_PC_CANAIS.map(ch => `<td class="text-center">${sw(conhecido && _pcProdNoCanal(p, ch), `onchange="pcCfgProduto('${p.id}','${ch}',this.checked)"`,
              `Mostrar ${esc(p.nome)} no ${_PC_NOME_CANAL[ch]}`, true, _pcGrupoNoCanal(g, ch) ? '' : `Grupo desligado no ${_PC_NOME_CANAL[ch]}`)}</td>`).join('')}
        </tr>`;
      }).join('') || `<tr class="pc-prod-tr"><td colspan="3" class="text-muted">Sem produtos neste grupo.</td></tr>`;
    }
    return html;
  }).join('');

  el.innerHTML = `
    ${nv.prods.length ? `<div class="pc-aviso">${nv.prods.length} produto(s) novo(s) no cadastro, ocultos até você ligar.
      <button type="button" class="link" onclick="pcRevisarNovos()">Marcar todos como revisados (continuam ocultos)</button></div>` : ''}
    <p class="plan-aviso-meta">Ligue o grupo no canal e, dentro dele, esconda o que não está no cardápio. <b>Grupo novo entra desligado e produto novo entra oculto</b>: nada entra na precificação sem você decidir. Foto e “revenda” são do cadastro do produto.</p>
    <div class="plan-lista"><table class="table plan-tabela mb-0">
      <thead><tr><th>Grupo / produto</th><th class="text-center" style="width:120px">Salão</th><th class="text-center" style="width:120px">Delivery</th></tr></thead>
      <tbody>${corpo || '<tr><td colspan="3" class="text-muted">Nenhum produto de cardápio (tipo VENDA) ativo.</td></tr>'}</tbody>
    </table></div>`;
}

function pcCfgAbrir(i) {
  const g = _pc.grupos[i];
  if (g == null) return;
  _pc.abertosCfg.has(g) ? _pc.abertosCfg.delete(g) : _pc.abertosCfg.add(g);
  _pcRenderConfig();
}

async function pcCfgGrupo(i, canal, on) {
  const g = _pc.grupos[i];
  if (g == null || !_PC_CANAIS.includes(canal)) return;
  await _pcSalvar(c => { c.grupos[g] = { salao: false, deliv: false, ...(c.grupos[g] || {}), [canal]: on }; });
  _pcRenderConfig(); _pcSubs(); _pcAviso();
}

async function pcCfgProduto(id, canal, on) {
  if (!_PC_CANAIS.includes(canal)) return;
  await _pcSalvar(c => {
    if (!c.conhecidos.includes(id)) {
      // primeira decisão sobre um produto novo: o OUTRO canal continua oculto
      c.conhecidos.push(id);
      _PC_CANAIS.forEach(ch => { if (!c.ocultos[ch].includes(id)) c.ocultos[ch].push(id); });
    }
    c.ocultos[canal] = c.ocultos[canal].filter(x => x !== id);
    if (!on) c.ocultos[canal].push(id);
  });
  _pcRenderConfig(); _pcSubs(); _pcAviso();
}

async function pcRevisarNovos() {
  const ids = _pcNovos().prods.map(p => p.id);
  if (!ids.length) return;
  await _pcSalvar(c => {
    ids.forEach(id => {
      if (!c.conhecidos.includes(id)) c.conhecidos.push(id);
      _PC_CANAIS.forEach(ch => { if (!c.ocultos[ch].includes(id)) c.ocultos[ch].push(id); });
    });
  });
  _pcRenderConfig(); _pcSubs(); _pcAviso();
}
