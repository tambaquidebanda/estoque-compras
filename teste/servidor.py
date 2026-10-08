# -*- coding: utf-8 -*-
"""
AMBIENTE DE TESTE - passo 2: o sistema inteiro rodando em cima da copia.

Serve as telas do repositorio (index.html, producao.html, contagem.html,
recebimento.html) e faz o papel do banco: responde as mesmas chamadas que o
Supabase responderia, lendo e gravando SO em teste/dados/. O banco de verdade
nao e chamado em momento nenhum (supabase.js e trocado na hora de servir).

  python3 teste/servidor.py            (porta 8090)

Computador: http://localhost:8090      Tablet (mesmo Wi-Fi): http://IP-do-Mac:8090/producao.html
Login: o seu e-mail de sempre, QUALQUER senha.
Barra laranja embaixo de cada tela: data simulada e "Recomecar do zero".
"""
import base64
import copy
import datetime as dt
import json
import os
import re
import shutil
import socket
import sys
import threading
import urllib.parse
import uuid
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
BASE = os.path.join(AQUI, 'base')
# DADOS_TESTE: outra pasta = outra copia independente (ex.: a do Claude testar sem mexer na sua)
DADOS = os.path.join(AQUI, os.environ.get('DADOS_TESTE', 'dados'))
PORTA = int(os.environ.get('PORTA', '8090'))
LOCK = threading.RLock()

# Unicos que o banco de verdade tem e o app usa no upsert/insert
UNICOS = {
    'est_saldo_local': [('produto_id', 'local')],
    'prod_metas': [('unidade', 'semana_ini')],
    'prod_venda_sa_dia': [('data', 'unidade', 'produto_id')],
    'prod_fechamentos': [('data', 'unidade')],
}

# ───────────────────────── dados ─────────────────────────
DB = {}
SCHEMA = {}
USUARIOS = []
ESTADO = {}


def _carregar():
    global SCHEMA, USUARIOS, ESTADO
    if not os.path.isdir(BASE):
        sys.exit('Falta a copia: rode antes  python3 teste/copiar_dados.py')
    if not os.path.isdir(DADOS):
        shutil.copytree(BASE, DADOS)
    SCHEMA = json.load(open(os.path.join(DADOS, '_schema.json'), encoding='utf-8'))
    USUARIOS = json.load(open(os.path.join(DADOS, '_usuarios.json'), encoding='utf-8'))
    DB.clear()
    for t in SCHEMA:
        f = os.path.join(DADOS, t + '.json')
        DB[t] = json.load(open(f, encoding='utf-8')) if os.path.exists(f) else []
    f = os.path.join(DADOS, '_estado.json')
    ESTADO = json.load(open(f)) if os.path.exists(f) else {'hoje': None}


SUJAS = set()


def _salvar(t):
    # grava no disco em segundo plano (a cada 1 s): gravar a tabela inteira a cada
    # linha deixava o envio de uma transferencia com 20 itens lento
    SUJAS.add(t)


def _gravar_sujas():
    import time
    while True:
        time.sleep(1)
        with LOCK:
            sujas = list(SUJAS)
            SUJAS.clear()
            fotos = {t: copy.deepcopy(DB[t]) for t in sujas}
        for t, rows in fotos.items():
            tmp = os.path.join(DADOS, t + '.json.tmp')
            json.dump(rows, open(tmp, 'w', encoding='utf-8'), ensure_ascii=False)
            os.replace(tmp, os.path.join(DADOS, t + '.json'))


def _salvar_estado():
    json.dump(ESTADO, open(os.path.join(DADOS, '_estado.json'), 'w'))


def _recomecar():
    with LOCK:
        SUJAS.clear()
        hoje = ESTADO.get('hoje')
        shutil.rmtree(DADOS, ignore_errors=True)
        shutil.copytree(BASE, DADOS)
        _carregar()
        ESTADO['hoje'] = hoje
        _salvar_estado()


# ───────────────────────── valores ─────────────────────────
def _agora():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _default(t, col, spec):
    d = spec.get('default')
    if d is None:
        return None
    s = str(d)
    if 'uuid' in s:
        return str(uuid.uuid4())
    if 'now()' in s or 'CURRENT_TIMESTAMP' in s.upper():
        return _agora()
    if 'CURRENT_DATE' in s.upper():
        return dt.date.today().isoformat()
    if s.startswith('nextval'):
        return max([r.get(col) or 0 for r in DB[t]] + [0]) + 1
    m = re.match(r"^'(.*)'::", s)
    if m:
        v = m.group(1)
        if spec.get('type') in ('object', 'array') or spec.get('format') in ('jsonb', 'json'):
            try:
                return json.loads(v)
            except Exception:
                return v
        return v
    if s in ('true', 'false'):
        return s == 'true'
    try:
        return int(s) if re.fullmatch(r'-?\d+', s) else float(s)
    except ValueError:
        return d


def _tipo(t, col):
    return (SCHEMA.get(t, {}).get('cols', {}).get(col) or {}).get('type')


def _coage(t, col, v):
    """Valor que veio na URL (texto) -> tipo da coluna."""
    if v is None:
        return None
    ty = _tipo(t, col)
    if ty in ('number', 'integer'):
        try:
            return float(v)
        except ValueError:
            return v
    if ty == 'boolean':
        return str(v).lower() == 'true'
    return v


def _dtz(v):
    try:
        s = str(v).replace('Z', '+00:00')
        if len(s) == 10:
            return dt.datetime.fromisoformat(s + 'T00:00:00+00:00')
        d = dt.datetime.fromisoformat(s)
        return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None


def _cmp(a, b):
    """-1/0/1 comparando valor da linha (a) com o do filtro (b). None se nao compara."""
    if a is None or b is None:
        return None
    if isinstance(a, bool) or isinstance(b, bool):
        a, b = str(a).lower(), str(b).lower()
    elif isinstance(a, (int, float)) and isinstance(b, (int, float)):
        pass
    elif isinstance(a, str) and isinstance(b, str) and re.match(r'^\d{4}-\d{2}-\d{2}', a) and re.match(r'^\d{4}-\d{2}-\d{2}', b) \
            and (len(a) > 10 or len(b) > 10) and ('T' in a or ' ' in a or 'T' in b or ' ' in b):
        da, db_ = _dtz(a), _dtz(b)
        if da and db_:
            a, b = da, db_
    else:
        try:
            if isinstance(a, (int, float)):
                b = float(b)
            elif isinstance(b, (int, float)):
                a = float(a)
        except ValueError:
            a, b = str(a), str(b)
    try:
        return (a > b) - (a < b)
    except TypeError:
        a, b = str(a), str(b)
        return (a > b) - (a < b)


def _lista_in(s):
    s = s.strip()
    if s.startswith('(') and s.endswith(')'):
        s = s[1:-1]
    out, cur, q = [], '', False
    for ch in s:
        if ch == '"':
            q = not q
        elif ch == ',' and not q:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    if cur or s.endswith(','):
        out.append(cur)
    return [x.strip() for x in out]


def _like(pat, v, ci):
    rx = '^' + re.escape(pat).replace(r'\*', '.*').replace('%', '.*') + '$'
    return re.match(rx, str(v), re.I if ci else 0) is not None


def _ok(t, row, col, expr):
    neg = False
    if expr.startswith('not.'):
        neg, expr = True, expr[4:]
    op, _, val = expr.partition('.')
    v = row.get(col)
    if op == 'is':
        r = (v is None) if val == 'null' else (v is (val == 'true')) if val in ('true', 'false') else False
    elif op == 'in':
        alvo = [_coage(t, col, x) for x in _lista_in(val)]
        r = any(_cmp(v, x) == 0 for x in alvo)
    elif op in ('like', 'ilike'):
        r = v is not None and _like(val, v, op == 'ilike')
    elif op in ('cs', 'cd'):
        try:
            alvo = json.loads(val) if val[:1] in '[{' else _lista_in(val.replace('{', '(').replace('}', ')'))
        except Exception:
            alvo = val
        if isinstance(v, dict) and isinstance(alvo, dict):
            r = all(v.get(k) == x for k, x in alvo.items()) if op == 'cs' else all(alvo.get(k) == x for k, x in v.items())
        elif isinstance(v, list):
            alvo = alvo if isinstance(alvo, list) else [alvo]
            r = all(x in v for x in alvo) if op == 'cs' else all(x in alvo for x in v)
        else:
            r = False
    else:
        c = _cmp(v, _coage(t, col, val))
        r = c is not None and {'eq': c == 0, 'neq': c != 0, 'gt': c > 0, 'gte': c >= 0, 'lt': c < 0, 'lte': c <= 0}.get(op, False)
        if op == 'neq' and v is None:
            r = False
    return (not r) if neg else r


def _divide_or(s):
    s = s.strip()
    if s.startswith('(') and s.endswith(')'):
        s = s[1:-1]
    out, cur, nivel, q = [], '', 0, False
    for ch in s:
        if ch == '"':
            q = not q
        if not q and ch == '(':
            nivel += 1
        if not q and ch == ')':
            nivel -= 1
        if ch == ',' and nivel == 0 and not q:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    if cur:
        out.append(cur)
    return out


def _ok_or(t, row, s, modo='or'):
    res = []
    for cond in _divide_or(s):
        if cond.startswith('and(') or cond.startswith('or('):
            m = cond.index('(')
            res.append(_ok_or(t, row, cond[m:], cond[:m]))
            continue
        col, _, expr = cond.partition('.')
        expr = expr.replace('"', '') if not expr.startswith('in.') else expr
        res.append(_ok(t, row, col, expr))
    return any(res) if modo == 'or' else all(res)


RESERVADOS = {'select', 'order', 'limit', 'offset', 'on_conflict', 'columns', 'or', 'and'}


class Erro(Exception):
    def __init__(self, status, code, msg, details=None):
        super().__init__(msg)
        self.status, self.code, self.msg, self.details = status, code, msg, details


def _confere_col(t, col):
    if col not in SCHEMA[t]['cols']:
        raise Erro(400, '42703', f'column {t}.{col} does not exist')


def _filtrar(t, params):
    rows = DB[t]
    for k, v in params:
        if k in RESERVADOS:
            if k == 'or':
                rows = [r for r in rows if _ok_or(t, r, v)]
            elif k == 'and':
                rows = [r for r in rows if _ok_or(t, r, v, 'and')]
            continue
        _confere_col(t, k)
        rows = [r for r in rows if _ok(t, r, k, v)]
    return rows


def _ordenar(t, rows, order):
    if not order:
        return rows
    for parte in reversed(order.split(',')):
        bits = parte.split('.')
        col = bits[0]
        _confere_col(t, col)
        desc = 'desc' in bits[1:]
        nulls_first = 'nullsfirst' in bits[1:] or (desc and 'nullslast' not in bits[1:])
        com = [r for r in rows if r.get(col) is not None]
        sem = [r for r in rows if r.get(col) is None]
        import functools
        com.sort(key=functools.cmp_to_key(lambda a, b: _cmp(a.get(col), b.get(col)) or 0), reverse=desc)
        rows = (sem + com) if nulls_first else (com + sem)
    return rows


def _projetar(t, rows, select):
    if not select or select.strip() == '*':
        return [dict(r) for r in rows]
    cols = []
    for c in _divide_or(select):
        c = c.strip()
        if '(' in c:
            raise Erro(400, 'PGRST100', f'ambiente de teste nao sabe juntar tabelas: {c}')
        alias, _, nome = c.rpartition(':') if ':' in c and '::' not in c else ('', '', c)
        nome = nome.split('::')[0]
        if nome == '*':
            cols.append(('*', '*'))
            continue
        _confere_col(t, nome)
        cols.append((alias or nome, nome))
    out = []
    for r in rows:
        o = {}
        for a, n in cols:
            if n == '*':
                o.update(r)
            else:
                o[a] = r.get(n)
        out.append(o)
    return out


def _chave(r, cols):
    return tuple(str(r.get(c)) for c in cols)


def _completa(t, r):
    novo = {}
    for c, spec in SCHEMA[t]['cols'].items():
        if c in r:
            novo[c] = r[c]
        else:
            novo[c] = _default(t, c, spec)
    for c in r:
        if c not in SCHEMA[t]['cols']:
            raise Erro(400, 'PGRST204', f"Could not find the '{c}' column of '{t}' in the schema cache")
    return novo


def _inserir(t, corpo, on_conflict, resol):
    linhas = corpo if isinstance(corpo, list) else [corpo]
    pk = SCHEMA[t]['pk'] or ['id']
    chaves_unicas = [tuple(pk)] + UNICOS.get(t, [])
    alvo = tuple(on_conflict.split(',')) if on_conflict else tuple(pk)
    feitos = []
    for r in linhas:
        if resol:
            existe = next((x for x in DB[t] if all(c in r for c in alvo) and _chave(x, alvo) == _chave(r, alvo)), None)
            if existe is not None:
                if resol == 'merge-duplicates':
                    for c in r:
                        if c not in SCHEMA[t]['cols']:
                            raise Erro(400, 'PGRST204', f"Could not find the '{c}' column of '{t}'")
                    existe.update(r)
                    feitos.append(existe)
                continue
        novo = _completa(t, r)
        for ch in chaves_unicas:
            if all(novo.get(c) is not None for c in ch) and any(_chave(x, ch) == _chave(novo, ch) for x in DB[t]):
                raise Erro(409, '23505', f'duplicate key value violates unique constraint ({",".join(ch)})')
        DB[t].append(novo)
        feitos.append(novo)
    return feitos


def _rpc(nome, corpo):
    if nome in ('proximo_num_pedido', 'proximo_num_inv'):
        t, col, pre = ('pedidos_internos', 'num_pedido', 'PED') if nome == 'proximo_num_pedido' else ('est_inventarios', 'num_inv', 'INV')
        n = max([int(re.sub(r'\D', '', str(r.get(col) or '')) or 0) for r in DB[t]] + [0])
        cont = ESTADO.setdefault('seq', {})
        n = max(n, cont.get(nome, 0)) + 1
        cont[nome] = n
        _salvar_estado()
        return f'{pre}-{n:04d}'
    raise Erro(404, 'PGRST202', f'funcao {nome} nao existe no ambiente de teste')


# ───────────────────────── auth falso ─────────────────────────
def _b64(o):
    return base64.urlsafe_b64encode(json.dumps(o).encode()).decode().rstrip('=')


def _sessao(u):
    exp = int(dt.datetime.now().timestamp()) + 30 * 24 * 3600
    user = {'id': u['id'], 'aud': 'authenticated', 'role': 'authenticated', 'email': u['email'],
            'user_metadata': u.get('user_metadata') or {}, 'app_metadata': u.get('app_metadata') or {},
            'created_at': '2026-01-01T00:00:00Z'}
    tok = _b64({'alg': 'HS256', 'typ': 'JWT'}) + '.' + _b64({'sub': u['id'], 'email': u['email'], 'role': 'authenticated',
                                                           'aud': 'authenticated', 'exp': exp}) + '.teste'
    return {'access_token': tok, 'token_type': 'bearer', 'expires_in': 30 * 24 * 3600, 'expires_at': exp,
            'refresh_token': 'teste-' + u['id'], 'user': user}


def _usuario_do_token(h):
    tok = (h or '').replace('Bearer ', '')
    try:
        p = json.loads(base64.urlsafe_b64decode(tok.split('.')[1] + '=='))
        return next((u for u in USUARIOS if u['id'] == p.get('sub')), None)
    except Exception:
        return None


# ───────────────────────── telas ─────────────────────────
SUPABASE_JS = ("// AMBIENTE DE TESTE: o 'banco' e o servidor local (teste/servidor.py)\n"
               "const SB_URL = location.origin;\nconst SB_KEY = 'teste';\nconst SB_SERVICE_KEY = 'teste';\n")

TROCA_HOJE = ("function hojeLocal() { if (window.__HOJE_TESTE__) return window.__HOJE_TESTE__; return _hojeLocalReal(); }\n"
              "function _hojeLocalReal(")


def _estado_js():
    return (f"window.__HOJE_TESTE__ = {json.dumps(ESTADO.get('hoje'))};\n"
            f"window.__TESTE_INFO__ = {json.dumps(json.load(open(os.path.join(BASE, '_info.json'))))};\n")


BARRA_JS = r"""
(function(){
  const h = window.__HOJE_TESTE__, info = window.__TESTE_INFO__ || {};
  const b = document.createElement('div');
  b.id = 'barra-teste';
  b.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:99999;background:#e8590c;color:#fff;font:600 14px system-ui,sans-serif;padding:7px 14px;display:flex;gap:12px;align-items:center;flex-wrap:wrap;box-shadow:0 -2px 8px rgba(0,0,0,.25)';
  const dias = ['dom','seg','ter','qua','qui','sex','sáb'];
  const rot = iso => iso ? dias[new Date(iso+'T12:00:00').getDay()] + ' ' + iso.slice(8,10)+'/'+iso.slice(5,7) : 'a de verdade';
  b.innerHTML = '<span style="font-weight:800;letter-spacing:.04em">AMBIENTE DE TESTE</span>'
    + '<span style="opacity:.9">nada aqui vai para o sistema de verdade · cópia de ' + (info.copiado_em||'').replace('T',' ').slice(0,16) + '</span>'
    + '<span style="margin-left:auto">Data simulada: <b>' + rot(h) + '</b></span>'
    + '<input type="date" id="bt-data" value="' + (h||'') + '" style="font:inherit;border:0;border-radius:6px;padding:2px 6px">'
    + '<button id="bt-real" style="font:inherit;border:1px solid #fff;background:transparent;color:#fff;border-radius:6px;padding:2px 10px">usar data real</button>'
    + '<button id="bt-zero" style="font:inherit;border:0;background:#fff;color:#e8590c;border-radius:6px;padding:2px 10px">Recomeçar do zero</button>';
  const post = (url, corpo) => fetch(url, {method:'POST', body: JSON.stringify(corpo||{})}).then(() => location.reload());
  document.addEventListener('DOMContentLoaded', () => {
    document.body.appendChild(b);
    document.body.style.paddingBottom = '48px';
    b.querySelector('#bt-data').onchange = e => post('/__teste__/data', {hoje: e.target.value || null});
    b.querySelector('#bt-real').onclick = () => post('/__teste__/data', {hoje: null});
    b.querySelector('#bt-zero').onclick = () => { if (confirm('Apagar tudo o que foi feito no teste e voltar à cópia original?')) post('/__teste__/recomecar'); };
  });
})();
"""


def _ip_local():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return '127.0.0.1'


class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, fmt, *a):
        if '/rest/v1/' in self.path and self.command != 'GET':
            sys.stderr.write('[teste] %s %s\n' % (self.command, urllib.parse.unquote(self.path)[:160]))

    # ── respostas
    def _env(self, status, corpo=b'', tipo='application/json', extra=None):
        if isinstance(corpo, (dict, list)) or corpo is None:
            corpo = json.dumps(corpo, ensure_ascii=False).encode()
        elif isinstance(corpo, str):
            corpo = corpo.encode()
        self.send_response(status)
        self.send_header('Content-Type', tipo + ('; charset=utf-8' if 'json' in tipo or 'text' in tipo or 'javascript' in tipo else ''))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,PATCH,PUT,DELETE,HEAD,OPTIONS')
        self.send_header('Access-Control-Expose-Headers', 'Content-Range')
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.send_header('Content-Length', str(len(corpo) if self.command != 'HEAD' else 0))
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(corpo)

    def _corpo(self):
        n = int(self.headers.get('Content-Length') or 0)
        raw = self.rfile.read(n) if n else b''
        return json.loads(raw) if raw.strip() else None

    def do_OPTIONS(self):
        self._env(204, b'')

    def do_GET(self):
        self._rota()

    def do_HEAD(self):
        self._rota()

    def do_POST(self):
        self._rota()

    def do_PATCH(self):
        self._rota()

    def do_PUT(self):
        self._rota()

    def do_DELETE(self):
        self._rota()

    def _rota(self):
        u = urllib.parse.urlsplit(self.path)
        try:
            if u.path.startswith('/rest/v1/'):
                with LOCK:
                    return self._rest(u)
            if u.path.startswith('/auth/v1/'):
                return self._auth(u)
            if u.path.startswith('/__teste__/'):
                return self._controle(u)
            if u.path.startswith('/realtime/') or u.path.startswith('/storage/'):
                return self._env(404, {'message': 'nao existe no teste'})
            return self._arquivo(u)
        except Erro as e:
            return self._env(e.status, {'code': e.code, 'message': e.msg, 'details': e.details, 'hint': None})
        except Exception as e:
            import traceback
            traceback.print_exc()
            return self._env(500, {'code': 'TESTE', 'message': f'erro no ambiente de teste: {e}'})

    # ── arquivos do repositorio
    def _arquivo(self, u):
        p = urllib.parse.unquote(u.path)
        if p in ('', '/'):
            p = '/index.html'
        if p == '/supabase.js':
            return self._env(200, SUPABASE_JS, 'application/javascript')
        caminho = os.path.normpath(os.path.join(RAIZ, p.lstrip('/')))
        # a copia (teste/), o .git e o que esta fora do repositorio nao sao servidos
        if not caminho.startswith(RAIZ + os.sep) or p.startswith('/teste') or p.startswith('/.'):
            return self._env(404, {'message': 'nao encontrado'})
        if not os.path.isfile(caminho):
            return self._env(404, {'message': 'nao encontrado'})
        ext = os.path.splitext(caminho)[1].lower()
        tipos = {'.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png',
                 '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.json': 'application/json'}
        if ext in ('.html', '.js'):
            txt = open(caminho, encoding='utf-8').read().replace('function hojeLocal(', TROCA_HOJE)
            if ext == '.html':
                txt = re.sub(r'<head([^>]*)>', r'<head\1>\n<script src="/__teste__/estado.js"></script><script src="/__teste__/barra.js"></script>', txt, count=1)
                txt = re.sub(r'<title>', '<title>[TESTE] ', txt, count=1)
            return self._env(200, txt, tipos[ext])
        return self._env(200, open(caminho, 'rb').read(), tipos.get(ext, 'application/octet-stream'))

    # ── controles da barra
    def _controle(self, u):
        if u.path == '/__teste__/estado.js':
            return self._env(200, _estado_js(), 'application/javascript')
        if u.path == '/__teste__/barra.js':
            return self._env(200, BARRA_JS, 'application/javascript')
        if u.path == '/__teste__/data' and self.command == 'POST':
            c = self._corpo() or {}
            with LOCK:
                ESTADO['hoje'] = c.get('hoje') or None
                _salvar_estado()
            return self._env(200, {'ok': True})
        if u.path == '/__teste__/recomecar' and self.command == 'POST':
            _recomecar()
            return self._env(200, {'ok': True})
        return self._env(404, {'message': 'nao encontrado'})

    # ── auth
    def _auth(self, u):
        q = dict(urllib.parse.parse_qsl(u.query))
        if u.path == '/auth/v1/token':
            c = self._corpo() or {}
            if q.get('grant_type') == 'password':
                us = next((x for x in USUARIOS if (x['email'] or '').lower() == (c.get('email') or '').lower()), None)
                if not us or not c.get('password'):
                    return self._env(400, {'error': 'invalid_grant', 'error_description': 'Invalid login credentials',
                                           'code': 'invalid_credentials', 'msg': 'Invalid login credentials'})
                return self._env(200, _sessao(us))
            if q.get('grant_type') == 'refresh_token':
                uid = str(c.get('refresh_token') or '').replace('teste-', '')
                us = next((x for x in USUARIOS if x['id'] == uid), None)
                return self._env(200, _sessao(us)) if us else self._env(400, {'error': 'invalid_grant'})
        if u.path == '/auth/v1/user':
            us = _usuario_do_token(self.headers.get('Authorization'))
            if not us:
                return self._env(401, {'msg': 'sem sessao'})
            if self.command == 'PUT':
                c = self._corpo() or {}
                us['user_metadata'].update(c.get('data') or {})
            return self._env(200, _sessao(us)['user'])
        if u.path == '/auth/v1/logout':
            return self._env(204, b'')
        if u.path.startswith('/auth/v1/admin/users'):
            if self.command == 'GET':
                return self._env(200, {'users': [_sessao(x)['user'] for x in USUARIOS], 'aud': 'authenticated'})
            return self._env(400, {'msg': 'Usuarios nao podem ser alterados no ambiente de teste'})
        return self._env(404, {'msg': 'nao existe no teste'})

    # ── banco
    def _rest(self, u):
        partes = u.path[len('/rest/v1/'):].split('/')
        params = urllib.parse.parse_qsl(u.query, keep_blank_values=True)
        pd = dict(params)
        prefer = self.headers.get('Prefer', '')
        if partes[0] == 'rpc':
            return self._env(200, _rpc(partes[1], self._corpo()))
        t = partes[0]
        if t not in DB:
            raise Erro(404, '42P01', f'relation "public.{t}" does not exist')
        metodo = self.command
        objeto = 'vnd.pgrst.object' in (self.headers.get('Accept') or '')
        rep = 'return=representation' in prefer
        if metodo in ('GET', 'HEAD'):
            rows = _ordenar(t, _filtrar(t, params), pd.get('order'))
            total = len(rows)
            off = int(pd.get('offset') or 0)
            lim = pd.get('limit')
            rg = self.headers.get('Range')
            if rg and '-' in rg:
                a, b_ = rg.split('-')
                off, lim = int(a), int(b_) - int(a) + 1
            rows = rows[off: off + int(lim)] if lim is not None else rows[off:]
            out = _projetar(t, rows, pd.get('select'))
            extra = {'Content-Range': (f'{off}-{off + len(out) - 1}' if out else '*') + (f'/{total}' if 'count=' in prefer else '/*')}
            return self._resp_linhas(out, objeto, extra)
        corpo = self._corpo()
        if metodo == 'POST':
            resol = 'merge-duplicates' if 'merge-duplicates' in prefer else ('ignore-duplicates' if 'ignore-duplicates' in prefer else None)
            feitos = _inserir(t, corpo if corpo is not None else {}, pd.get('on_conflict'), resol)
            _salvar(t)
            if not rep:
                return self._env(201, b'')
            return self._resp_linhas(_projetar(t, feitos, pd.get('select')), objeto, status=201)
        if metodo == 'PATCH':
            alvo = _filtrar(t, params)
            for c in (corpo or {}):
                _confere_col(t, c)
            for r in alvo:
                r.update(corpo or {})
            _salvar(t)
            if not rep:
                return self._env(204, b'')
            return self._resp_linhas(_projetar(t, alvo, pd.get('select')), objeto)
        if metodo == 'DELETE':
            alvo = _filtrar(t, params)
            ids = set(map(id, alvo))
            DB[t] = [r for r in DB[t] if id(r) not in ids]
            _salvar(t)
            if not rep:
                return self._env(204, b'')
            return self._resp_linhas(_projetar(t, alvo, pd.get('select')), objeto)
        raise Erro(405, 'TESTE', 'metodo nao suportado')

    def _resp_linhas(self, out, objeto, extra=None, status=200):
        if objeto:
            if len(out) != 1:
                return self._env(406, {'code': 'PGRST116', 'message': 'JSON object requested, multiple (or no) rows returned',
                                       'details': f'The result contains {len(out)} rows', 'hint': None}, extra=extra)
            return self._env(status, out[0], extra=extra)
        return self._env(status, out, extra=extra)


def main():
    _carregar()
    ip = _ip_local()
    print('=' * 64)
    print(' AMBIENTE DE TESTE - nada aqui toca o banco de verdade')
    print(f'  Computador: http://localhost:{PORTA}')
    print(f'  Tablet (mesmo Wi-Fi): http://{ip}:{PORTA}/producao.html')
    print('  Login: seu e-mail de sempre, qualquer senha')
    print('=' * 64)
    sys.stdout.flush()
    threading.Thread(target=_gravar_sujas, daemon=True).start()
    ThreadingHTTPServer(('0.0.0.0', PORTA), H).serve_forever()


if __name__ == '__main__':
    main()
