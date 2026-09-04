#!/usr/bin/env python3
"""
COMPARATIVO DIARIO DO PARALELO - o que a venda comeu x o que a contagem achou.

Este e o instrumento de medicao dos 15 dias (08/09 a 22/09/2026). Ele NAO
ESCREVE NADA - so le. Pode rodar quantas vezes quiser.

De onde vem cada lado:

  MODELO  est_movimentacoes tipo='venda_pensera', que o robo grava todo dia em
          modo razao. Ja vem por (insumo, setor) e ja em unidade de uso.

  REAL    contagem(ontem) + entradas(hoje) - contagem(hoje).
          E o consumo implicito entre duas contagens consecutivas.

Diferenca importante para o simular_mundo_paralelo.py: aquele deixa o modelo
correr SOZINHO por semanas e mede a deriva acumulada - responde "da para
desligar a contagem?". Este aqui compara UM DIA por vez, com a contagem
reancorando todo dia - responde "o que errou ontem, e em qual item?". Os dois
numeros sao diferentes de proposito e nao se substituem.

O CRITERIO combinado em 28/08/2026 para desligar a contagem manual:

  erro bruto do dia <= 10% do consumo do dia,
  em 10 dos ultimos 15 dias,
  e nenhum dos 20 maiores insumos fora de +-25%.

UNIDADE: nao converte nada, igual ao simulador. A unidade da contagem esta no
habito de quem conta, nao no cadastro (ver o bloco UNIDADE em
simular_mundo_paralelo.py). Produtos com fator != 1 saem marcados, porque o
erro deles e conhecido e nao deve ser confundido com erro de ficha.

DIA SEM CONTAGEM nao vira erro. Se um setor nao foi contado no dia, o par
(ontem, hoje) nao existe e aquele setor fica FORA da conta daquele dia - e o
rodape diz quanto do consumo ficou sem cobertura. Tratar contagem ausente como
zero inventaria consumo que ninguem mediu.

Uso:
    SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python3 scripts/comparativo_diario.py
    CMP_INICIO=2026-09-08 CMP_DIAS=15 CMP_UNIDADE=Centro   (padroes)
    CMP_DETALHE=20   quantas linhas de insumo mostrar por dia (0 = so o resumo)
"""
import os, sys, json, collections, datetime, urllib.parse, importlib.util

AQUI    = os.path.dirname(os.path.abspath(__file__))
INICIO  = os.environ.get('CMP_INICIO', '2026-09-08')
NDIAS   = int(os.environ.get('CMP_DIAS', '15'))
UNIDADE = os.environ.get('CMP_UNIDADE', 'Centro')
DETALHE = int(os.environ.get('CMP_DETALHE', '12'))
SETORES_IGNORAR = {'ESTOQUE_LOJA', 'ESTOQUE DA LOJA'}

spec = importlib.util.spec_from_file_location('bx', os.path.join(AQUI, 'baixa_estoque_pdv.py'))
bx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bx)
G = bx.sb_get_all

spec2 = importlib.util.spec_from_file_location('sim', os.path.join(AQUI, 'simular_mundo_paralelo.py'))


def em_lotes(ids, n=60):
    ids = list(ids)
    for i in range(0, len(ids), n):
        yield '(' + ','.join(ids[i:i + n]) + ')'


def dias():
    d0 = datetime.date.fromisoformat(INICIO)
    return [(d0 + datetime.timedelta(days=i)).isoformat() for i in range(NDIAS)]


def contagens(desde):
    """{(setor, produto, dia): quantidade contada, COMO FOI DIGITADA}.

    Copia deliberada da regra do simular_mundo_paralelo.py, inclusive o desempate
    de linha repetida (fica com o MAIOR, igual ao registrarContagem do app) e o
    filtro por `local` — sem ele a contagem do Estoque Central entra como se
    fosse do Centro, porque os nomes de setor se repetem entre unidades.
    """
    unid = urllib.parse.quote(UNIDADE)
    inv  = G(f'est_inventarios?select=id,setor,grupo,data,criado_em,local'
             f'&data=gte.{desde}&local=eq.{unid}')
    cab  = {i['id']: i for i in inv}
    itens = []
    for lote in em_lotes(list(cab)):
        itens += G('est_inventario_itens?select=inventario_id,produto_id,total&inventario_id=in.' + lote)
    out, quando = {}, {}
    for x in itens:
        if not x['produto_id']:
            continue
        h = cab[x['inventario_id']]
        if h['setor'] in SETORES_IGNORAR:
            continue
        k = (h['setor'], x['produto_id'], h['data'])
        v = x['total'] or 0
        if k not in quando or h['criado_em'] > quando[k]:
            quando[k] = h['criado_em']; out[k] = v
        elif h['criado_em'] == quando[k]:
            out[k] = max(out[k], v)
    return out


def entradas(desde):
    """{(setor, produto, dia): quantidade que ENTROU} - so movimento oficial."""
    out = collections.defaultdict(float)
    for m in G(f'est_movimentacoes?select=produto_id,local,data,tipo,quantidade&data=gte.{desde}'):
        if m['tipo'] in ('pedido_interno_entrada', 'recebimento', 'devolucao'):
            out[(m['local'], m['produto_id'], m['data'])] += m['quantidade'] or 0
    return out


def modelo(desde):
    """{(setor, produto, dia): quantidade que a VENDA consumiu} - o razao do robo.

    As quantidades no razao sao negativas (saida); aqui viram positivas para
    ficarem do mesmo lado da conta que o consumo real.
    """
    out = collections.defaultdict(float)
    for m in G(f'est_movimentacoes?select=produto_id,local,data,quantidade'
               f'&tipo=eq.venda_pensera&origem=eq.pdv_icomanda&data=gte.{desde}'):
        out[(m['local'], m['produto_id'], m['data'])] += abs(m['quantidade'] or 0)
    return out


def main():
    ds = dias()
    desde = (datetime.date.fromisoformat(INICIO) - datetime.timedelta(days=2)).isoformat()
    print(f'== Comparativo diario == {ds[0]} a {ds[-1]}  ({UNIDADE})')

    P = {p['id']: p for p in G('est_produtos?select=id,nome,custo_comp,custo_uso,'
                               'fator_conversao,perda,unidade_uso')}
    cont = contagens(desde)
    ent  = entradas(desde)
    mod  = modelo(desde)
    if not mod:
        print('\nO robo ainda nao lancou nenhum dia no razao (tipo=venda_pensera).')
        print('Isso e esperado antes do primeiro dia do paralelo.')
        return

    def custo(pid):
        return bx.custo_efetivo(P.get(pid, {}))

    def nome(pid):
        return (P.get(pid) or {}).get('nome', '?')

    def fator(pid):
        return float((P.get(pid) or {}).get('fator_conversao') or 1) or 1

    # dias em que cada setor foi contado, para saber o que da para comparar
    contado_em = collections.defaultdict(set)     # setor -> {dia}
    for (setor, _pid, dia) in cont:
        contado_em[setor].add(dia)

    linhas_dia = []          # (dia, consumo_modelo, erro_bruto, cobertura, n_insumos)
    acum = collections.defaultdict(lambda: {'real': 0.0, 'mod': 0.0})

    for dia in ds:
        ontem = (datetime.date.fromisoformat(dia) - datetime.timedelta(days=1)).isoformat()
        do_dia = {k: v for k, v in mod.items() if k[2] == dia}
        if not do_dia:
            continue

        comparavel, sem_contagem = {}, 0.0
        for (setor, pid, _d), qmod in do_dia.items():
            # so compara se o setor foi contado NOS DOIS dias: sem os dois pontos
            # nao existe consumo real para aquele intervalo.
            if dia not in contado_em.get(setor, ()) or ontem not in contado_em.get(setor, ()):
                sem_contagem += qmod * custo(pid)
                continue
            c_ant = cont.get((setor, pid, ontem))
            c_hoje = cont.get((setor, pid, dia))
            if c_ant is None or c_hoje is None:
                # o setor foi contado, mas este item nao apareceu na folha
                sem_contagem += qmod * custo(pid)
                continue
            real = c_ant + ent.get((setor, pid, dia), 0.0) - c_hoje
            comparavel[(setor, pid)] = (real, qmod)
            acum[pid]['real'] += real
            acum[pid]['mod']  += qmod

        # CONSUMO REAL NEGATIVO: a contagem subiu sem entrada registrada. Nao e
        # erro de ficha nem de modelo - e mercadoria que entrou no setor por fora
        # do sistema (ou contagem digitada errada). Sai destacado porque a acao e
        # outra: rotina de entrada, nao conserto de ficha. Era 31% do erro na
        # medicao de 28/08.
        negativos = {k: v for k, v in comparavel.items() if v[0] < 0}
        val_neg = sum(abs(r) * custo(pid) for (_s, pid), (r, _q) in negativos.items())

        cons_mod = sum(q * custo(pid) for (_s, pid), (_r, q) in comparavel.items())
        erro     = sum(abs(q - r) * custo(pid) for (_s, pid), (r, q) in comparavel.items())
        total_mod = sum(q * custo(pid) for (_s, pid, _d), q in do_dia.items())
        cobertura = (cons_mod / total_mod * 100) if total_mod > 0 else 0.0
        pct = (erro / cons_mod * 100) if cons_mod > 0 else 0.0
        passa = 'OK ' if (cons_mod > 0 and pct <= 10) else '-- '
        linhas_dia.append((dia, cons_mod, erro, pct, cobertura, len(comparavel), passa))

        print(f'\n{passa}{dia}   consumo comparavel R$ {cons_mod:>9,.2f}   '
              f'erro bruto R$ {erro:>9,.2f}  ({pct:>5.1f}% do consumo)   '
              f'{len(comparavel)} insumos, {cobertura:.0f}% do valor coberto pela contagem')
        if sem_contagem > 0.005:
            print(f'      R$ {sem_contagem:,.2f} ficou de fora: setor ou item sem as duas contagens do intervalo')
        if negativos:
            print(f'      {len(negativos)} item(ns) com consumo real NEGATIVO (R$ {val_neg:,.2f}): '
                  f'a contagem subiu sem entrada registrada — entrada por fora do sistema')
        if DETALHE:
            piores = sorted(comparavel.items(),
                            key=lambda kv: -abs(kv[1][1] - kv[1][0]) * custo(kv[0][1]))[:DETALHE]
            if piores:
                print(f'      {"insumo":38} {"setor":14} {"real":>9} {"modelo":>9} {"gap R$":>10}')
                for (setor, pid), (real, qmod) in piores:
                    g = (qmod - real) * custo(pid)
                    if abs(g) < 0.005:
                        continue
                    marca = ' *' if fator(pid) != 1 else ''
                    print(f'      {nome(pid)[:38]:38} {setor[:14]:14} '
                          f'{real:>9.2f} {qmod:>9.2f} {g:>10,.2f}{marca}')

    if not linhas_dia:
        print('\nNenhum dia com lancamento no razao dentro da janela.')
        return

    # ---------------- placar contra o criterio ----------------
    print('\n' + '=' * 78)
    print('PLACAR CONTRA O CRITERIO DE 28/08')
    print('=' * 78)
    ultimos = linhas_dia[-15:]
    ok = sum(1 for l in ultimos if l[6].strip() == 'OK')
    print(f'  1) erro <= 10% do consumo: {ok} de {len(ultimos)} dias   (precisa de 10 em 15)')

    top20 = sorted(acum.items(), key=lambda kv: -kv[1]['mod'] * custo(kv[0]))[:20]
    fora = []
    for pid, d in top20:
        if d['real'] <= 0:
            fora.append((pid, d, 'contagem <= 0'))
            continue
        desvio = (d['mod'] - d['real']) / d['real'] * 100
        if abs(desvio) > 25:
            fora.append((pid, d, f'{desvio:+.0f}%'))
    print(f'  2) 20 maiores insumos dentro de +-25%: {20 - len(fora)} de 20   (precisa de 20)')
    for pid, d, por in fora:
        marca = '  * unidade de contagem nao curada' if fator(pid) != 1 else ''
        print(f'       fora: {nome(pid)[:38]:38} real {d["real"]:>9.2f}  modelo {d["mod"]:>9.2f}  {por}{marca}')

    aprovado = ok >= 10 and not fora
    print(f'\n  => {"CRITERIO ATENDIDO" if aprovado else "CRITERIO NAO ATENDIDO"}'
          f' — {"da para desligar a contagem" if aprovado else "a contagem continua"}')
    print('\n  * = produto com fator != 1: a unidade da contagem ainda nao foi curada,')
    print('      entao o erro dele e conhecido e nao deve ser lido como erro de ficha.')

    saida = os.path.join(AQUI, '.comparativo_ultimo.json')
    json.dump({'gerado_em': datetime.datetime.now().isoformat(),
               'dias': [{'data': l[0], 'consumo': l[1], 'erro': l[2], 'pct': l[3],
                         'cobertura': l[4], 'insumos': l[5], 'passa': l[6].strip() == 'OK'}
                        for l in linhas_dia],
               'acumulado': {nome(p): d for p, d in acum.items()}}, open(saida, 'w'))
    print(f'\n  detalhe em {saida}')


if __name__ == '__main__':
    main()
