#!/usr/bin/env python3
"""
Robô de baixa automática de estoque (iComanda → estoque-compras).

Puxa as vendas do PDV, explode cada produto vendido pela FICHA TÉCNICA e
calcula o consumo de insumos. Dois modos:

  BAIXA_MODE=dry   (PADRÃO) → só CALCULA e grava em `pdv_baixa_preview`.
                              NÃO toca est_saldo_local nem est_movimentacoes.
  BAIXA_MODE=apply           → baixa de verdade: grava no razão
                              (est_movimentacoes, tipo 'venda_pensera',
                              origem 'pdv_icomanda') e desconta est_saldo_local.

Regra de segurança: só baixa produto que esteja MAPEADO na `pdv_map`
(status='mapeado') E cujo produto tenha ficha ativa. Pendente/ignorar não baixam.

Idempotente por dia (`pdv_baixa_ctrl`): o modo apply pula dias já 'ok'.

Fórmula de consumo (idêntica ao app):
  consumo_insumo = ingrediente.quantidade / ficha.rendimento * qtd_vendida * pdv_map.fator
  (quantidade do ingrediente já está em unidade de USO — a mesma do saldo.)

Variáveis de ambiente (secrets do GitHub Actions):
  SUPABASE_URL, SUPABASE_SERVICE_KEY   (obrigatórios; nunca colocar a key no arquivo)
  BAIXA_MODE          dry | apply       (default dry)
  BAIXA_LOCAL         local do estoque de onde sai o insumo (default COZINHA)
  BAIXA_START_DATE    não processa antes disso (default 2026-08-15)
  BAIXA_DAYS_BACK     quantos dias retroativos revisitar (default 1 = ontem)
  ICOMANDA_API_URL, ICOMANDA_API_KEY   (opcionais; default abaixo, chave read-only pública)
"""
import os, sys, json, urllib.request, urllib.parse
from datetime import datetime, timezone, timedelta


def env(nome, default=None, obrigatorio=False):
    v = (os.environ.get(nome) or '').strip()
    if not v:
        if obrigatorio:
            sys.exit(f'ERRO: variável {nome} não definida (configure o secret no GitHub).')
        return default
    return v


API_URL    = env('ICOMANDA_API_URL', 'https://cloud.icomanda.com/tdb/apidashboard').rstrip('/')
API_KEY    = env('ICOMANDA_API_KEY', 'apidash_249_aB3xY7zQ9Wm2KpV5')
SB_URL     = env('SUPABASE_URL', obrigatorio=True).rstrip('/')
SB_KEY     = env('SUPABASE_SERVICE_KEY', obrigatorio=True)
MODE       = env('BAIXA_MODE', 'dry').lower()
LOCAL      = env('BAIXA_LOCAL', 'COZINHA')
START_DATE = env('BAIXA_START_DATE', '2026-08-15')
DAYS_BACK  = int(env('BAIXA_DAYS_BACK', '1'))
BASE       = f'{SB_URL}/rest/v1'
HDR        = {'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY}
MANAUS     = timezone(timedelta(hours=-4))


# ───────────────────────── Supabase REST ─────────────────────────
def sb_get_all(path):
    """GET paginado (1000/página) — PostgREST limita SELECT a 1000 linhas."""
    out, off = [], 0
    while True:
        sep = '&' if '?' in path else '?'
        url = f'{BASE}/{path}{sep}limit=1000&offset={off}'
        req = urllib.request.Request(url, headers={**HDR, 'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=120) as r:
            b = json.load(r)
        out += b
        if len(b) < 1000:
            return out
        off += 1000


def sb_send(method, path, payload=None, prefer=None):
    url = f'{BASE}/{path}'
    hdr = {**HDR, 'Content-Type': 'application/json', 'Accept': 'application/json'}
    if prefer:
        hdr['Prefer'] = prefer
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=hdr, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        body = r.read().decode()
        return json.loads(body) if body.strip() else None


def sb_insert(table, rows):
    return sb_send('POST', table, rows, prefer='return=minimal')


def sb_upsert(table, rows, on_conflict):
    return sb_send('POST', f'{table}?on_conflict={on_conflict}',
                   rows, prefer='resolution=merge-duplicates,return=minimal')


def sb_delete(path):
    return sb_send('DELETE', path, prefer='return=minimal')


# ───────────────────────── iComanda ─────────────────────────
def buscar_dia(data):
    qs = urllib.parse.urlencode({'api_key': API_KEY, 'data_ini': data, 'data_fim': data})
    url = f'{API_URL}/?{qs}'
    req = urllib.request.Request(url, headers={'Accept': 'application/json', 'User-Agent': 'tdb-baixa/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def vendas_do_dia(data):
    """{ icomanda_produto_id(int) -> qtd } dos itens ativos de comandas não canceladas."""
    j = buscar_dia(data)
    vendas = {}
    for cx in (j.get('caixas') or []):
        for cm in (cx.get('comandas') or []):
            if cm.get('cancelada'):
                continue
            for it in (cm.get('itens') or []):
                if it.get('status') != 'ativo':
                    continue
                pid = it.get('produto_id')
                vendas[pid] = vendas.get(pid, 0) + (it.get('quantidade') or 0)
    return vendas


# ───────────────────────── carga de mapa + fichas ─────────────────────────
def custo_efetivo(p):
    fator = p.get('fator_conversao') or 1
    rend  = 1 - ((p.get('perda') or 0) / 100)
    bruto = p.get('custo_comp') or p.get('custo_uso') or 0
    return (bruto / fator) / rend if rend > 0 else 0


def carregar():
    # mapa: só mapeados com produto
    mapa = {}
    for m in sb_get_all('pdv_map?select=icomanda_produto_id,produto_id,status,fator,setor&status=eq.mapeado'):
        if m.get('produto_id'):
            mapa[m['icomanda_produto_id']] = {'produto_id': m['produto_id'], 'fator': m.get('fator') or 1, 'setor': m.get('setor')}

    # fichas ativas (uma por produto — a mais recente vence se houver duplicidade)
    ficha_por_prod = {}
    for f in sb_get_all('est_fichas_tecnicas?select=id,produto_id,rendimento,ativo&ativo=eq.true'):
        ficha_por_prod[f['produto_id']] = {'ficha_id': f['id'], 'rendimento': f.get('rendimento') or 1}

    # ingredientes por ficha
    ings_por_ficha = {}
    for i in sb_get_all('est_ficha_ingredientes?select=ficha_id,ingrediente_id,quantidade'):
        ings_por_ficha.setdefault(i['ficha_id'], []).append((i['ingrediente_id'], i.get('quantidade') or 0))

    # info dos produtos (custo + nome)
    prod_info = {}
    for p in sb_get_all('est_produtos?select=id,nome,custo_comp,custo_uso,fator_conversao,perda'):
        prod_info[p['id']] = p

    # CONTADOS = produtos que têm saldo cadastrado (inventário controla). A recursão para neles.
    contado = set()
    for s in sb_get_all('est_saldo_local?select=produto_id'):
        if s.get('produto_id'):
            contado.add(s['produto_id'])

    return mapa, ficha_por_prod, ings_por_ficha, prod_info, contado


def _bom(pid, ficha_por_prod, ings_por_ficha, contado, memo, stack):
    """BOM achatado: quanto de cada item FOLHA (contado ou matéria-prima crua) resulta
    de 1 unidade de `pid`. Regra híbrida: para em item CONTADO (tem saldo) ou sem ficha;
    o que NÃO é contado é explodido pela própria ficha. Guarda contra ciclos."""
    if pid in memo:
        return memo[pid]
    # folha: é contado (baixa ele mesmo) OU não tem ficha (matéria-prima crua)
    if pid in contado or pid not in ficha_por_prod or pid in stack:
        memo[pid] = {pid: 1.0}
        return memo[pid]
    f = ficha_por_prod[pid]
    rend = f['rendimento'] or 1
    stack.add(pid)
    out = {}
    for ing_id, quant in ings_por_ficha.get(f['ficha_id'], []):
        if not ing_id:
            continue
        fator = (quant or 0) / rend
        if fator <= 0:
            continue
        for folha, fq in _bom(ing_id, ficha_por_prod, ings_por_ficha, contado, memo, stack).items():
            out[folha] = out.get(folha, 0) + fq * fator
    stack.discard(pid)
    memo[pid] = out
    return out


def consumo_do_dia(data, mapa, ficha_por_prod, ings_por_ficha, contado, memo=None):
    if memo is None:
        memo = {}
    vendas = vendas_do_dia(data)
    consumo, fontes = {}, {}
    itens_venda = 0
    for pid, qtd in vendas.items():
        m = mapa.get(pid)
        if not m:
            continue
        ficha = ficha_por_prod.get(m['produto_id'])
        if not ficha:
            continue
        rend = ficha['rendimento'] or 1
        setor = m.get('setor') or None
        base_mult = qtd * (m['fator'] or 1) / rend
        # explode cada ingrediente do prato até as folhas (contado/MP crua)
        for ing_id, quant in ings_por_ficha.get(ficha['ficha_id'], []):
            if not ing_id:
                continue
            base = (quant or 0) * base_mult
            if base <= 0:
                continue
            for folha, fq in _bom(ing_id, ficha_por_prod, ings_por_ficha, contado, memo, set()).items():
                c = base * fq
                if c <= 0:
                    continue
                chave = (folha, setor)   # baixa é por INSUMO + SETOR do prato
                consumo[chave] = consumo.get(chave, 0) + c
                fontes.setdefault(chave, set()).add(pid)
        itens_venda += qtd
    return consumo, fontes, itens_venda


# ───────────────────────── dias a processar ─────────────────────────
def dias_alvo():
    hoje = datetime.now(MANAUS).date()
    ini  = datetime.strptime(START_DATE, '%Y-%m-%d').date()
    out = []
    for i in range(1, DAYS_BACK + 1):
        d = hoje - timedelta(days=i)
        if d >= ini:
            out.append(d.isoformat())
    return sorted(out)


def ctrl_dias_ok():
    """Dias que o APPLY ja processou. Filtrar por modo='apply' e essencial: o dry-run
    tambem grava status='ok', e sem esse filtro o apply pulava calado todo dia que ja
    tinha preview — terminava verde, com total R$ 0,00, sem baixar nada."""
    try:
        return {r['data'] for r in
                sb_get_all('pdv_baixa_ctrl?select=data,status,modo&status=eq.ok&modo=eq.apply')}
    except Exception:
        return set()


def ja_tem_movimento(data):
    """Trava contra baixa dupla. Se o apply caiu no meio (razao gravado, saldo nao), o
    ctrl do dia nao foi escrito e uma segunda rodada baixaria tudo de novo por cima. O
    proprio razao e a evidencia: se ja existe lancamento do dia, para e pede conferencia."""
    try:
        r = sb_get_all(f'est_movimentacoes?select=id&tipo=eq.venda_pensera'
                       f'&origem=eq.pdv_icomanda&data=eq.{data}&limit=1')
        return len(r) > 0
    except Exception:
        return False


# ───────────────────────── main ─────────────────────────
def main():
    print(f'== Robô baixa PDV == modo={MODE} local={LOCAL} start={START_DATE} days_back={DAYS_BACK}')
    mapa, ficha_por_prod, ings_por_ficha, prod_info, contado = carregar()
    print(f'   mapeados={len(mapa)}  fichas={len(ficha_por_prod)}  produtos={len(prod_info)}  contados={len(contado)}')

    ja_ok = ctrl_dias_ok() if MODE == 'apply' else set()
    memo = {}
    total_valor = 0.0

    for data in dias_alvo():
        if MODE == 'apply' and data in ja_ok:
            print(f'   {data}: já baixado (apply ok) — pulando.')
            continue
        if MODE == 'apply' and ja_tem_movimento(data):
            print(f'   {data}: ⛔ JÁ EXISTE lançamento venda_pensera no razão, mas sem registro '
                  f'de apply concluído. Rodada anterior provavelmente caiu no meio. NÃO vou '
                  f'baixar de novo — confira e, se preciso, rode o SQL_ROLLBACK_BAIXA_PDV.sql.')
            continue

        # consumo: {(insumo_id, setor) -> qtd}
        consumo, fontes, itens_venda = consumo_do_dia(data, mapa, ficha_por_prod, ings_por_ficha, contado, memo)

        # agrega por INSUMO (para a preview / total) e guarda o detalhe por (insumo,setor) p/ apply
        por_insumo = {}
        sem_setor_val = 0.0
        for (ing_id, setor), qtd in consumo.items():
            cu = custo_efetivo(prod_info.get(ing_id, {}))
            val = qtd * cu
            d = por_insumo.setdefault(ing_id, {'qtd': 0.0, 'cu': cu, 'setores': set()})
            d['qtd'] += qtd
            if setor:
                d['setores'].add(setor)
            else:
                sem_setor_val += val
        valor_dia = sum(d['qtd'] * d['cu'] for d in por_insumo.values())
        total_valor += valor_dia
        aviso = f'  ⚠ R$ {sem_setor_val:,.2f} sem setor' if sem_setor_val > 0.005 else ''
        print(f'   {data}: {itens_venda} itens → {len(por_insumo)} insumos, R$ {valor_dia:,.2f}{aviso}')

        if MODE == 'dry':
            sb_delete(f'pdv_baixa_preview?data=eq.{data}')
            linhas = [{
                'data': data, 'ingrediente_id': ing, 'ingrediente_nome': prod_info.get(ing, {}).get('nome'),
                'quantidade': round(d['qtd'], 4), 'custo_unit': round(d['cu'], 4),
                'valor': round(d['qtd'] * d['cu'], 2), 'fontes': len(d['setores']),
            } for ing, d in por_insumo.items()]
            if linhas:
                for i in range(0, len(linhas), 500):
                    sb_insert('pdv_baixa_preview', linhas[i:i + 500])
            sb_upsert('pdv_baixa_ctrl', [{
                'data': data, 'modo': 'dry', 'status': 'ok',
                'itens_venda': itens_venda, 'insumos': len(linhas), 'valor': round(valor_dia, 2),
                'detalhe': 'dry-run: nada baixado', 'processado_em': datetime.now(timezone.utc).isoformat(),
            }], 'data')

        else:  # apply — baixa por (insumo, setor). Venda SEM setor NÃO baixa (trava de segurança).
            movs, alvos = [], []   # alvos = [(ing_id, setor, qtd)]
            for (ing_id, setor), qtd in consumo.items():
                if not setor:
                    continue   # sem setor definido → não baixa; fica pra curadoria
                cu = custo_efetivo(prod_info.get(ing_id, {}))
                movs.append({
                    'produto_id': ing_id, 'local': setor, 'tipo': 'venda_pensera',
                    'quantidade': -round(qtd, 4), 'custo_unit': round(cu, 4),
                    'origem': 'pdv_icomanda', 'motivo': f'Baixa venda PDV {data}',
                    # ref_id NAO recebe a data: a coluna e uuid e o insert quebrava com
                    # 22P02 invalid input syntax for type uuid. O dia ja esta em `data`,
                    # que e o campo por onde a conferencia e o rollback casam a rodada.
                    'ref_tabela': 'pdv', 'data': data,
                })
                alvos.append((ing_id, setor, qtd))
            if movs:
                for i in range(0, len(movs), 500):
                    sb_insert('est_movimentacoes', movs[i:i + 500])
            # saldo: lê atual de cada (produto,setor) e desconta
            por_setor = {}
            for ing_id, setor, qtd in alvos:
                por_setor.setdefault(setor, {})[ing_id] = por_setor.setdefault(setor, {}).get(ing_id, 0) + qtd
            saldo_rows = []
            for setor, mapa_ing in por_setor.items():
                ids = list(mapa_ing.keys())
                atual = {}
                for i in range(0, len(ids), 150):
                    inlist = ','.join(ids[i:i + 150])
                    for s in sb_get_all(f'est_saldo_local?select=produto_id,saldo&local=eq.{urllib.parse.quote(setor)}&produto_id=in.({inlist})'):
                        atual[s['produto_id']] = float(s.get('saldo') or 0)
                for ing_id, qtd in mapa_ing.items():
                    saldo_rows.append({
                        'produto_id': ing_id, 'local': setor,
                        'saldo': round(atual.get(ing_id, 0) - qtd, 4),
                        'updated_at': datetime.now(timezone.utc).isoformat(),
                    })
            if saldo_rows:
                for i in range(0, len(saldo_rows), 500):
                    sb_upsert('est_saldo_local', saldo_rows[i:i + 500], 'produto_id,local')
            sb_upsert('pdv_baixa_ctrl', [{
                'data': data, 'modo': 'apply', 'status': 'ok',
                'itens_venda': itens_venda, 'insumos': len(por_insumo), 'valor': round(valor_dia, 2),
                'detalhe': f'baixado por setor; sem-setor R$ {sem_setor_val:,.2f}',
                'processado_em': datetime.now(timezone.utc).isoformat(),
            }], 'data')

    print(f'== Fim == total R$ {total_valor:,.2f}  (modo {MODE})')


if __name__ == '__main__':
    main()
