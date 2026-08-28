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
# a partir deste dia o app grava a entrada ja em unidade de uso (commit 6084219)
CORTE_UNIDADE = os.environ.get('SIM_CORTE_UNIDADE', '2026-08-28')

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


def fatores():
    """{produto_id: fator_conversao} - quantas unidades de USO cabem em 1 de COMPRA."""
    return {p['id']: float(p.get('fator_conversao') or 1) or 1
            for p in G('est_produtos?select=id,fator_conversao')}


def contagens(desde, fator):
    """{(setor, produto, dia): quantidade contada, EM UNIDADE DE USO} - ultima do dia vence.

    CONVERTE PARA UNIDADE DE USO. `est_inventario_itens.total` guarda o numero cru
    que a pessoa digitou, e a tela de contagem mostra a unidade de COMPRA de
    proposito (garrafa e contavel, mililitro nao). Ja as entradas do razao e o
    consumo da ficha estao em unidade de USO. Sem converter, os dois lados da conta
    ficam em unidades diferentes: a laranja e contada em pacote (1 PC = 100 UN) e
    comparada com laranja consumida em unidade - 100x de diferenca inventada.
    Sao 85 produtos ativos com fator != 1, e eles respondiam por R$ 17 mil do erro
    bruto medido na primeira rodada. Esse pedaco do erro era do instrumento, nao
    do estoque.

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
            out[k] = (x['total'] or 0) * fator.get(x['produto_id'], 1)
    return out


def entradas(fator):
    """{(setor, produto, dia): quantidade que ENTROU, EM UNIDADE DE USO}.

    Duas eras, e a conta muda entre elas. Ate 27/08/2026 o app gravava a entrada
    do pedido interno com o numero cru da tela, que esta em unidade de COMPRA
    (a laranja entra como '1' pacote, a bandeja como '20' pacotes). O commit
    6084219, de 27/08, passou a converter na gravacao. Entao movimento anterior
    ao corte precisa do fator; movimento posterior ja vem em unidade de uso.

    Sem esta divisao a conta fica pior do que sem correcao nenhuma: converter so
    a contagem e deixar a entrada crua desalinha os dois lados da subtracao.
    """
    out = collections.defaultdict(float)
    for m in G('est_movimentacoes?select=produto_id,local,data,tipo,quantidade'):
        if m['tipo'] not in ('pedido_interno_entrada', 'recebimento', 'devolucao'):
            continue
        q = m['quantidade'] or 0
        if (m['data'] or '') < CORTE_UNIDADE:
            q *= fator.get(m['produto_id'], 1)
        out[(m['local'], m['produto_id'], m['data'])] += q
    return out


def main():
    dias = [(datetime.date.fromisoformat(INICIO) + datetime.timedelta(days=i)).isoformat()
            for i in range(NDIAS)]
    print(f'Mundo paralelo: {UNIDADE}, {dias[0]} a {dias[-1]} ({NDIAS} dias). Leitura pura.\n', flush=True)

    mapa, ficha, ings, prod, contado, setor_de, ambiguos, sem_setor = bx.carregar()
    fator = fatores()
    cont = contagens(dias[0], fator)
    ent  = entradas(fator)

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

    saida = os.path.join(AQUI, '..', 'mundo_paralelo_resultado.json')
    json.dump({'inicio': dias[0], 'fim': dias[-1], 'linhas': linhas}, open(saida, 'w'),
              ensure_ascii=False, indent=1)
    print(f'\ndetalhe completo em {os.path.normpath(saida)}')


if __name__ == '__main__':
    main()
