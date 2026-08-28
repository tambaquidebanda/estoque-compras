#!/usr/bin/env python3
"""
MUNDO PARALELO - o saldo do setor calculado pela venda, ao lado da contagem real.

Para onde isso vai: a contagem manual por setor deixa de existir. O saldo passa a
ser calculado (entra o que o estoque liberou, sai o que a venda consumiu pela
ficha) e a reposicao nasce sozinha quando o saldo chega no ponto.

Este script e o instrumento que mede se ja da para confiar nesse calculo. Ele
NAO ESCREVE NADA - so le. Roda quantas vezes quiser, sem afetar o que esta no ar.

Como funciona:
    saldo_calculado(hoje) = saldo_calculado(ontem)
                          + entradas registradas no razao   (pedido interno, recebimento)
                          - consumo da venda pela ficha
Comeca na contagem real do primeiro dia e dai em diante NUNCA mais olha a
contagem - so compara com ela no fim de cada dia.

Ajustes manuais sao ignorados de proposito: o objetivo e ver onde o modelo erra
sozinho, sem herdar conserto humano.

Uso:
    SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python3 scripts/simular_mundo_paralelo.py
    SIM_INICIO=2026-08-07 SIM_DIAS=21 SIM_UNIDADE=Centro ... (padroes abaixo)

Primeira rodada, 7 a 27/08/2026: 194 insumos, 34 batem dentro de 25%,
35 explicam 80% do erro bruto de R$ 159 mil. Ver o artifact "Mundo Paralelo".
"""
import os, sys, json, time, collections, datetime, urllib.parse, importlib.util

AQUI   = os.path.dirname(os.path.abspath(__file__))
INICIO = os.environ.get('SIM_INICIO', '2026-08-07')
NDIAS  = int(os.environ.get('SIM_DIAS', '21'))
UNIDADE = os.environ.get('SIM_UNIDADE', 'Centro')   # est_inventarios.local
SETORES_IGNORAR = {'ESTOQUE_LOJA', 'ESTOQUE DA LOJA'}

spec = importlib.util.spec_from_file_location('bx', os.path.join(AQUI, 'baixa_estoque_pdv.py'))
bx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bx)

_get = bx.sb_get_all
def G(path, tentativas=5):
    for i in range(tentativas):
        try:
            return _get(path)
        except Exception:
            if i == tentativas - 1:
                raise
            time.sleep(2 * (i + 1))
bx.sb_get_all = G


def em_lotes(ids, n=60):
    for i in range(0, len(ids), n):
        yield urllib.parse.quote('(' + ','.join('"%s"' % x for x in ids[i:i + n]) + ')')


def produtos_fator():
    """{produto_id: fator_conversao} - so para MARCAR quem tem fator != 1.

    NAO e usado para converter nada. Ver o bloco UNIDADE em contagens().
    """
    return {p['id']: float(p.get('fator_conversao') or 1) or 1
            for p in G('est_produtos?select=id,fator_conversao')}


def contagens(desde):
    """{(setor, produto, dia): quantidade contada, COMO FOI DIGITADA} - ultima do dia vence.

    UNIDADE: nao converte, e isso e uma decisao, nao um esquecimento.

    A tentacao e obvia: `est_inventario_itens.total` guarda o numero cru digitado,
    a tela mostra unidade_comp, e a ficha trabalha em unidade de uso — logo era so
    multiplicar pelo fator_conversao. Testei os tres jeitos em 10-27/08/2026:

        sem converter nada                    erro bruto R$ 148 mil
        convertendo so a contagem             erro bruto R$ 154 mil
        convertendo contagem e entrada        erro bruto R$ 272 mil

    O terceiro da 275 kg de farinha por dia e 24.500 bandejas em 18 dias, que sao
    numeros fisicamente impossiveis. A conferencia de 28/08 nos 85 produtos com
    fator != 1 explicou por que: na maioria o time JA CONTA na unidade de uso e
    ignora o rotulo da tela (digitam 7 querendo dizer 7 kg de farinha, nao 7
    fardos), e numa minoria — garrafa, fator < 1 — contam na unidade de compra
    mesmo. A unidade da contagem esta no habito de quem conta, item a item, e nao
    no cadastro. Por isso a conversao tambem foi desligada no app (commit
    77390f0): so volta depois que os 85 forem curados um a um.

    Enquanto nao houver curadoria, o numero cru e a leitura menos errada — e o
    erro que sobra nesses produtos e conhecido, nao invisivel.

    FILTRA POR UNIDADE. `est_inventarios.local` guarda a unidade (Centro, Estoque
    Central, Producao, Delivery P10) e `setor` guarda o setor (BAR, COZINHA...).
    Os nomes de setor se repetem entre unidades, entao sem este filtro a contagem
    do Estoque Central entra como se fosse do Centro. Aconteceu: 8 contagens do
    Estoque Central caem em 10-17/08/2026 e sujaram a primeira rodada.
    """
    unid = urllib.parse.quote(UNIDADE)
    inv = G(f'est_inventarios?select=id,setor,grupo,data,criado_em,local'
            f'&data=gte.{desde}&local=eq.{unid}')
    cab = {i['id']: i for i in inv}
    itens = []
    for lote in em_lotes(list(cab)):
        itens += G('est_inventario_itens?select=inventario_id,produto_id,total&inventario_id=in.' + lote)
    out, quando = {}, {}
    for x in itens:
        if not x['produto_id']:
            continue
        h = cab[x['inventario_id']]
        k = (h['setor'], x['produto_id'], h['data'])
        if k not in quando or h['criado_em'] > quando[k]:
            quando[k] = h['criado_em']
            out[k] = x['total'] or 0
    return out


def entradas():
    """{(setor, produto, dia): quantidade que ENTROU} - so movimento oficial.

    Tambem sem conversao, e pelo mesmo motivo da contagem: a entrada do pedido
    interno e gravada com o numero da tela do setor, entao ela esta na mesma
    unidade em que aquele item e contado. Somar contagem e entrada crua mantem
    os dois lados da subtracao coerentes entre si.
    """
    out = collections.defaultdict(float)
    for m in G('est_movimentacoes?select=produto_id,local,data,tipo,quantidade'):
        if m['tipo'] in ('pedido_interno_entrada', 'recebimento', 'devolucao'):
            out[(m['local'], m['produto_id'], m['data'])] += m['quantidade'] or 0
    return out


def main():
    dias = [(datetime.date.fromisoformat(INICIO) + datetime.timedelta(days=i)).isoformat()
            for i in range(NDIAS)]
    print(f'Mundo paralelo: {UNIDADE}, {dias[0]} a {dias[-1]} ({NDIAS} dias). Leitura pura.\n', flush=True)

    mapa, ficha, ings, prod, contado, setor_de, ambiguos, sem_setor = bx.carregar()
    fator = produtos_fator()          # so para marcar quem tem fator != 1 no relatorio
    cont = contagens(dias[0])
    ent  = entradas()

    consumo, memo = collections.defaultdict(float), {}
    for d in dias:
        c, _, n = bx.consumo_do_dia(d, mapa, ficha, ings, contado, setor_de, memo)
        for (folha, setor), q in c.items():
            if setor and setor not in SETORES_IGNORAR:
                consumo[(setor, folha, d)] += q
        print(f'  {d}  {n} itens de venda', flush=True)

    # consumo REAL implicito entre duas contagens: contagem(antes) + entradas - contagem(depois)
    pares = collections.defaultdict(lambda: [0.0, 0.0])
    for (setor, p) in {(s, p) for (s, p, _) in consumo}:
        anterior = None
        for d in dias:
            c = cont.get((setor, p, d))
            if c is None:
                continue
            if anterior:
                entre = [x for x in dias if anterior[0] < x <= d]
                real = anterior[1] + sum(ent.get((setor, p, x), 0) for x in entre) - c
                mod  = sum(consumo.get((setor, p, x), 0) for x in entre)
                pares[(setor, p)][0] += real
                pares[(setor, p)][1] += mod
            anterior = (d, c)

    linhas = []
    for (setor, p), (real, mod) in pares.items():
        if mod < 1 and real < 1:
            continue
        linhas.append({
            'insumo': prod.get(p, {}).get('nome', '?'), 'setor': setor,
            'real': round(real, 2), 'modelo': round(mod, 2),
            'razao': round(mod / real, 3) if real > 0.5 else None,
            'gap_reais': round((mod - real) * bx.custo_efetivo(prod.get(p, {})), 2),
            # fator != 1: unidade da contagem ainda nao curada, o gap deste insumo
            # pode ser so unidade trocada. Nao confie na linha antes de curar.
            'fator': fator.get(p, 1),
        })
    linhas.sort(key=lambda x: -abs(x['gap_reais']))

    batem = [x for x in linhas if x['razao'] and 0.8 <= x['razao'] <= 1.25]
    bruto = sum(abs(x['gap_reais']) for x in linhas)
    acc, n80 = 0.0, 0
    for x in linhas:
        acc += abs(x['gap_reais'])
        n80 += 1
        if acc >= 0.8 * bruto:
            break

    print(f'\n{"insumo":34}{"setor":15}{"real":>10}{"modelo":>10}{"gap R$":>12}')
    for x in linhas[:25]:
        print(f'  {x["insumo"][:32]:32}{x["setor"]:15}{x["real"]:>10.1f}{x["modelo"]:>10.1f}{x["gap_reais"]:>12,.2f}')

    print(f'\ninsumos simulados          : {len(linhas)}')
    print(f'batem com a contagem (+-25%): {len(batem)}')
    print(f'erro bruto                 : R$ {bruto:,.2f}')
    print(f'erro liquido               : R$ {sum(x["gap_reais"] for x in linhas):,.2f}'
          '   <- os erros se cancelam; nao leia so este numero')
    print(f'{n80} insumos explicam 80% do erro bruto')
    naocur = [x for x in linhas if x['fator'] != 1]
    print(f'{len(naocur)} linhas sao de insumo com fator != 1 (unidade da contagem nao curada), '
          f'R$ {sum(abs(x["gap_reais"]) for x in naocur):,.2f} do erro bruto')

    saida = os.path.join(AQUI, '..', 'mundo_paralelo_resultado.json')
    json.dump({'inicio': dias[0], 'fim': dias[-1], 'linhas': linhas}, open(saida, 'w'),
              ensure_ascii=False, indent=1)
    print(f'\ndetalhe completo em {os.path.normpath(saida)}')


if __name__ == '__main__':
    main()
