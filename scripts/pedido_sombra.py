#!/usr/bin/env python3
"""
PEDIDO SOMBRA - fase 1 da baixa automatica. So MEDE: nao cria pedido interno,
nao mexe em saldo nem no livro-razao. Grava apenas em `pdv_pedido_sombra`.

A ideia (decidida com o Wagner em 15/09/2026): em vez de desligar a contagem de
uma vez quando o erro geral cair, o pedido calculado pela venda entra SETOR POR
SETOR. Primeiro ele roda "na sombra", ao lado do pedido que saiu da contagem,
e o placar diario diz em qual setor ele ja acerta.

Para cada item contado na noite:

    saldo do modelo = ancora + entradas no setor - consumo da venda
    pedido sombra   = max(0, padrao - saldo do modelo)
    pedido real     = est_inventario_itens.pedido
                      (= max(0, pedido_padrao - estoque), conferido em 100% das
                       1.352 linhas de 12 a 14/09/2026)

O padrao e o GRAVADO naquela contagem (pedido_padrao), com o dia da semana e o
feriado que o time escolheu na tela. Recalcular pelo inv_configuracoes seria
adivinhar o dia - e errar o padrao estraga a comparacao inteira.

Duas variantes:
    V1  ancora = contagem da noite anterior. O termometro do dia.
    V2  ancora = contagem mais recente entre 7 e 10 dias antes. Simula a
        contagem SEMANAL da fase 2 - e este numero que libera um setor.

Tres marcas separam o que nao e comparacao justa (a tela mostra a parte):
    unidade_nao_curada  fator_conversao != 1: o time conta na unidade de costume
    dois_grupos         mesmo item contado em dois grupos na mesma noite
    contado_zero        linha em branco vira zero e pede o padrao inteiro
E ha uma quarta, DERIVADA (nao e coluna): `*_saldo` negativo. O modelo viu sair
mais do que viu entrar, entao ele perdeu um lancamento - nao da para comparar.

Reaproveita o comparativo_diario.py (contagem, entradas e modelo ja com a data
corrigida para Manaus) - a medicao da sombra e a do comparativo precisam contar
a mesma historia.

"bate" = diferenca de ate 1 unidade (decisao do Wagner, 15/09/2026).

Uso:
    SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python3 scripts/pedido_sombra.py
    SOMBRA_INICIO=2026-09-12   primeira noite medida (depois do inventario de 11/09)
    SOMBRA_DIAS=3              sempre recalcula as ultimas N noites; noite mais antiga
                               sem nenhuma linha na tabela tambem e calculada (backfill)
"""
import os, sys, json, datetime, collections, importlib.util, urllib.error

AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('cmp', os.path.join(AQUI, 'comparativo_diario.py'))
cmp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cmp)
bx, G = cmp.bx, cmp.G

INICIO     = os.environ.get('SOMBRA_INICIO', '2026-09-12')
DIAS       = int(os.environ.get('SOMBRA_DIAS', '3'))
TABELA     = 'pdv_pedido_sombra'
TOLERANCIA = 1.0          # "bate" = ate 1 unidade
V2_MIN, V2_MAX = 7, 10    # a ancora semanal fica entre 7 e 10 dias antes


def d(s):
    return datetime.date.fromisoformat(s)


def iso(x):
    return x.isoformat()


def tabela_existe():
    try:
        bx.sb_send('GET', f'{TABELA}?select=id&limit=1')
        return True
    except urllib.error.HTTPError as e:
        corpo = e.read().decode(errors='ignore')
        if e.code == 404 or 'PGRST205' in corpo or 'does not exist' in corpo:
            return False
        raise


def noite_tem_linhas(noite):
    r = bx.sb_send('GET', f'{TABELA}?select=id&noite=eq.{noite}&limit=1')
    return bool(r)


def noites_alvo():
    ontem = datetime.datetime.now(bx.MANAUS).date() - datetime.timedelta(days=1)
    ini = d(INICIO)
    if ontem < ini:
        return []
    todas = [ini + datetime.timedelta(days=i) for i in range((ontem - ini).days + 1)]
    ultimas = set(todas[-DIAS:]) if DIAS > 0 else set()
    return [iso(n) for n in todas if n in ultimas or not noite_tem_linhas(iso(n))]


def linhas_reais(desde):
    """{(setor, grupo, produto, noite): linha da contagem} - a MAIS RECENTE da noite.

    Uma noite pode ter duas contagens do mesmo grupo (reenvio, contagem de dia de
    inventario). Fica a ultima pelo criado_em, que e a que valeu para o saldo.
    """
    unid = cmp.urllib.parse.quote(cmp.UNIDADE)
    inv = G(f'est_inventarios?select=id,setor,grupo,data,criado_em,local&data=gte.{desde}&local=eq.{unid}')
    cab = {i['id']: i for i in inv if i['setor'] not in cmp.SETORES_IGNORAR}
    itens = []
    for lote in cmp.em_lotes(list(cab)):
        itens += G('est_inventario_itens?select=inventario_id,produto_id,nome,estoque,pedido_padrao,pedido'
                   '&inventario_id=in.' + lote)
    out, quando = {}, {}
    for x in itens:
        if not x['produto_id']:
            continue
        h = cab[x['inventario_id']]
        k = (h['setor'], h['grupo'] or '', x['produto_id'], cmp.dia_da_contagem(h))
        if k not in quando or h['criado_em'] >= quando[k]:
            quando[k] = h['criado_em']
            out[k] = x
    return out


def main():
    if not tabela_existe():
        print(f'Tabela {TABELA} ainda nao existe - rode SQL_PEDIDO_SOMBRA.sql. Nada a medir hoje.')
        return
    noites = noites_alvo()
    if not noites:
        print('Pedido sombra: nenhuma noite a calcular.')
        return
    desde = iso(d(noites[0]) - datetime.timedelta(days=V2_MAX + 2))
    print(f'== Pedido sombra == noites {", ".join(noites)}  (carregando desde {desde})')

    P    = {p['id']: p for p in G('est_produtos?select=id,nome,custo_comp,custo_uso,fator_conversao,perda')}
    cont = cmp.contagens(desde)      # {(setor, produto, dia): contado}
    ent  = cmp.entradas(desde)       # {(setor, produto, dia): entrou}
    mod  = cmp.modelo(desde)         # {(setor, produto, dia): venda consumiu}
    real = linhas_reais(iso(d(desde) - datetime.timedelta(days=1)))

    dias_com_modelo = {k[2] for k in mod}
    contado_em = collections.defaultdict(set)
    for (s, _p, dia) in cont:
        contado_em[s].add(dia)

    def fator(pid):
        return float((P.get(pid) or {}).get('fator_conversao') or 1) or 1

    def rodar(setor, pid, ancora, noite):
        """saldo do modelo andando da ancora ate a noite: (qtd ancora, entradas, consumo, saldo).

        O saldo pode dar NEGATIVO - a venda comeu mais do que o modelo viu entrar,
        que e o retrato de produto saindo do estoque sem registro. O saldo negativo
        fica gravado como esta, porque e ele que denuncia o problema; quem trata o
        sinal e o `pedido_sombra` abaixo.
        """
        base = cont[(setor, pid, ancora)]
        e = c = 0.0
        dia = d(ancora) + datetime.timedelta(days=1)
        while dia <= d(noite):
            e += ent.get((setor, pid, iso(dia)), 0.0)
            c += mod.get((setor, pid, iso(dia)), 0.0)
            dia += datetime.timedelta(days=1)
        return base, e, c, base + e - c

    def ancora_v2(setor, pid, noite):
        for atras in range(V2_MIN, V2_MAX + 1):
            a = iso(d(noite) - datetime.timedelta(days=atras))
            if (setor, pid, a) in cont:
                return a
        return None

    for noite in noites:
        if noite not in dias_com_modelo:
            print(f'   {noite}: o robo ainda nao lancou a venda desta noite no razao - pula (a proxima rodada pega).')
            continue
        linhas_noite = {k: v for k, v in real.items() if k[3] == noite}
        if not linhas_noite:
            print(f'   {noite}: nenhuma contagem de setor nesta noite - pula.')
            continue
        grupos_por_item = collections.Counter((s, pid) for (s, _g, pid, _n) in linhas_noite)
        ontem = iso(d(noite) - datetime.timedelta(days=1))

        linhas, placar = [], collections.defaultdict(collections.Counter)
        for (setor, grupo, pid, _n), x in linhas_noite.items():
            padrao = float(x['pedido_padrao'] or 0)
            contado = float(x['estoque'] or 0)
            row = {
                'noite': noite, 'setor': setor, 'grupo': grupo, 'produto_id': pid,
                'nome': x['nome'] or (P.get(pid) or {}).get('nome'),
                'contado': round(contado, 4), 'padrao': round(padrao, 4),
                'pedido_real': round(float(x['pedido'] or 0), 4),
                'custo_unit': round(bx.custo_efetivo(P.get(pid, {})), 4),
                'unidade_nao_curada': fator(pid) != 1,
                'dois_grupos': grupos_por_item[(setor, pid)] > 1,
                'contado_zero': contado == 0,
            }
            for v, ancora in (('v1', ontem if (setor, pid, ontem) in cont else None),
                              ('v2', ancora_v2(setor, pid, noite))):
                if ancora:
                    base, e, c, saldo = rodar(setor, pid, ancora, noite)
                    # PEDIDO NUNCA PASSA DO PADRAO. O padrao E o nivel de estoque alvo:
                    # o pedido real e max(0, padrao - contado) e contado nunca e
                    # negativo, entao ele para no padrao. Sem o max(0, saldo) aqui, um
                    # saldo de -167 virava pedido de 227 num item de padrao 60 - numero
                    # que nenhum setor pediria. Em 12-15/09 isso inflou a fila de
                    # consertos em R$ 76 mil de R$ 104 mil. O saldo negativo continua
                    # gravado em `{v}_saldo`, e a tela marca e tira essas linhas do
                    # placar: onde o modelo vai a negativo ele nao esta comparando com
                    # a contagem, esta avisando que perdeu uma entrada ou uma saida.
                    row.update({f'{v}_ancora_data': ancora, f'{v}_ancora_qtd': round(base, 4),
                                f'{v}_entradas': round(e, 4), f'{v}_consumo': round(c, 4),
                                f'{v}_saldo': round(saldo, 4),
                                f'{v}_sombra': round(max(0.0, padrao - max(0.0, saldo)), 4)})
                else:
                    row.update({f'{v}_ancora_data': None, f'{v}_ancora_qtd': None, f'{v}_entradas': None,
                                f'{v}_consumo': None, f'{v}_saldo': None, f'{v}_sombra': None})
            linhas.append(row)

            # placar do log: so item comparavel
            limpo = (padrao > 0 and not row['unidade_nao_curada'] and not row['dois_grupos']
                     and not row['contado_zero'] and not (row['v1_saldo'] or 0) < 0)
            if limpo and row['v1_sombra'] is not None:
                p = placar[setor]
                dif = abs(row['v1_sombra'] - row['pedido_real'])
                p['itens'] += 1
                p['bate'] += dif <= TOLERANCIA + 1e-9
                p['exato'] += dif < 1e-6
                p['real_rs'] += row['pedido_real'] * row['custo_unit']
                p['bate_rs'] += (row['pedido_real'] * row['custo_unit']) if dif <= TOLERANCIA + 1e-9 else 0

        bx.sb_delete(f'{TABELA}?noite=eq.{noite}')          # rodar de novo substitui
        for i in range(0, len(linhas), 500):
            bx.sb_insert(TABELA, linhas[i:i + 500])

        print(f'   {noite}: {len(linhas)} linhas gravadas.  V1 (ancora de ontem), itens comparaveis:')
        for setor in sorted(placar):
            p = placar[setor]
            n = p['itens']
            print(f'      {setor:14} {n:>4} itens   ate 1 un {100*p["bate"]/n:>4.0f}%   exato {100*p["exato"]/n:>4.0f}%'
                  f'   valor {100*p["bate_rs"]/max(p["real_rs"], 0.01):>4.0f}%')


if __name__ == '__main__':
    main()
