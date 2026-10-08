# -*- coding: utf-8 -*-
"""
AMBIENTE DE TESTE - passo 1: tira uma COPIA dos dados de agora (so leitura).

Le o banco de verdade e grava em teste/base/ um arquivo por tabela. Nada e
gravado no banco: so GET. O servidor de teste (teste/servidor.py) trabalha em
cima desta copia; "Recomecar do zero" na barra laranja volta para ela.

Uso:  python3 teste/copiar_dados.py
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.parse
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
BASE = os.path.join(AQUI, 'base')

_src = open(os.path.join(RAIZ, 'supabase.js'), encoding='utf-8').read()
URL = re.search(r"SB_URL\s*=\s*'([^']+)'", _src).group(1)
_K = re.search(r"SB_SERVICE_KEY\s*=\s*'([^']+)'", _src).group(1)   # nunca imprimir
H = {'apikey': _K, 'Authorization': 'Bearer ' + _K}

HOJE = dt.date.today()
DESDE_7 = (HOJE - dt.timedelta(days=7)).isoformat()
DESDE_14 = (HOJE - dt.timedelta(days=14)).isoformat()
DESDE_30 = (HOJE - dt.timedelta(days=30)).isoformat()

# Tabelas grandes que o teste da Producao nao usa: ficam vazias na copia.
PULAR = {'card_transacoes', 'lancamentos', 'lancamentos_excluidos', 'pagamentos', 'pdv_vendas',
         'pdv_pedido_sombra', 'pdv_baixa_preview', 'bancos', 'classificacao_historica',
         'conc_conciliacoes', 'card_lotes_pagamento', 'orcamentos', 'caixa_dia_conf',
         'caixa_movimentos', 'est_inventario_valorado_itens', 'inv_config_historico'}
# Tabelas grandes que entram so com o pedaco recente.
RECORTE = {
    'est_movimentacoes': f'criado_em=gte.{DESDE_7}',
    'est_inventarios': f'criado_em=gte.{DESDE_14}',
    'pedidos_internos': f'or=(criado_em.gte.{DESDE_30},status.in.(pendente,liberado))',
}


def get(path):
    out, off = [], 0
    while True:
        sep = '&' if '?' in path else '?'
        req = urllib.request.Request(f"{URL}/rest/v1/{path}{sep}offset={off}&limit=1000", headers=H)
        rows = json.load(urllib.request.urlopen(req, timeout=120))
        out += rows
        if len(rows) < 1000:
            return out
        off += 1000


def filhos(tabela, coluna, ids):
    out = []
    ids = list(ids)
    for i in range(0, len(ids), 100):
        out += get(f"{tabela}?select=*&{coluna}=in.({','.join(ids[i:i + 100])})")
    return out


def main():
    os.makedirs(BASE, exist_ok=True)
    spec = json.load(urllib.request.urlopen(urllib.request.Request(URL + '/rest/v1/', headers=H), timeout=120))
    schema = {}
    for t, d in spec.get('definitions', {}).items():
        props = d.get('properties', {})
        schema[t] = {
            'cols': {c: {'type': v.get('type'), 'format': v.get('format'), 'default': v.get('default')} for c, v in props.items()},
            'pk': [c for c, v in props.items() if 'Primary Key' in (v.get('description') or '')],
        }
    json.dump(schema, open(os.path.join(BASE, '_schema.json'), 'w'), ensure_ascii=False)

    total = 0
    for t in sorted(schema):
        if t.startswith('bkp_') or t.endswith('_bkp_20260925'):
            continue
        if t in PULAR:
            rows = []
        elif t == 'est_inventario_itens':
            continue                      # vem depois, pelos inventarios copiados
        elif t == 'pedidos_internos_itens':
            continue
        else:
            filtro = RECORTE.get(t)
            try:
                rows = get(f"{t}?select=*" + (f"&{filtro}" if filtro else ''))
            except Exception as e:
                print(f'  {t}: nao copiada ({e})')
                rows = []
        json.dump(rows, open(os.path.join(BASE, t + '.json'), 'w'), ensure_ascii=False)
        total += len(rows)
        print(f'{t:36s} {len(rows):7d}')

    inv = json.load(open(os.path.join(BASE, 'est_inventarios.json')))
    itens = filhos('est_inventario_itens', 'inventario_id', [r['id'] for r in inv])
    json.dump(itens, open(os.path.join(BASE, 'est_inventario_itens.json'), 'w'), ensure_ascii=False)
    print(f"{'est_inventario_itens':36s} {len(itens):7d}")
    ped = json.load(open(os.path.join(BASE, 'pedidos_internos.json')))
    itens = filhos('pedidos_internos_itens', 'pedido_id', [r['id'] for r in ped])
    json.dump(itens, open(os.path.join(BASE, 'pedidos_internos_itens.json'), 'w'), ensure_ascii=False)
    print(f"{'pedidos_internos_itens':36s} {len(itens):7d}")

    # Usuarios (so e-mail, id e as permissoes do user_metadata) para o login de teste
    req = urllib.request.Request(URL + '/auth/v1/admin/users?per_page=1000', headers=H)
    us = json.load(urllib.request.urlopen(req, timeout=120))
    us = us.get('users', us) if isinstance(us, dict) else us
    usuarios = [{'id': u['id'], 'email': u.get('email'), 'user_metadata': u.get('user_metadata') or {},
                 'app_metadata': u.get('app_metadata') or {}} for u in us if u.get('email')]
    json.dump(usuarios, open(os.path.join(BASE, '_usuarios.json'), 'w'), ensure_ascii=False)
    print(f'usuarios: {len(usuarios)}')

    json.dump({'copiado_em': dt.datetime.now().isoformat(timespec='seconds')},
              open(os.path.join(BASE, '_info.json'), 'w'))
    print('Copia pronta em teste/base/')


if __name__ == '__main__':
    main()
