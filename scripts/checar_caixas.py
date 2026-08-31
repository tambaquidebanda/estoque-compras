#!/usr/bin/env python3
"""
CHECAGEM PREVIA: todo caixa do periodo tem loja identificada?

Por que isso existe. A API do iComanda devolve as DUAS lojas juntas e nao diz
qual e qual - nao ha campo de unidade no topo, no caixa, na comanda nem no item.
Quem separa e o NOSSO banco: `pdv_vendas.caixa_ext` guarda o numero do caixa e a
mesma linha traz `unidade_nome`. Esse mapa e alimentado pela importacao do
relatorio do PDV no financeiro.

Consequencia: um dia sem o relatorio importado e um dia que o robo RECUSA - e
ele recusa certo, porque incluir o caixa desconhecido seria descontar venda da
outra loja do nosso estoque, e pular seria perder venda nossa em silencio.

Durante o paralelo, um dia recusado e um buraco no razao. Este script encontra o
buraco ANTES, em vez de voce descobrir com o robo travando de manha.

O que ele NAO faz: nao escreve nada, em lugar nenhum. So le a API e o banco.

Uso:
    SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python3 scripts/checar_caixas.py
    CHK_INICIO=2026-09-08 CHK_FIM=2026-09-22 python3 scripts/checar_caixas.py

    Sem CHK_INICIO, checa os ultimos CHK_DIAS (default 14) ate ontem.

Sai com codigo 1 se algum dia derrubaria o robo - da para usar como porteiro
antes de ligar o automatico.
"""
import os, sys, time, collections, importlib.util
from datetime import date, timedelta

AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('bx', os.path.join(AQUI, 'baixa_estoque_pdv.py'))
bx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bx)

NOSSA = os.environ.get('BAIXA_UNIDADE_PDV', 'Tambaqui de Banda Loja Centro')
FIM   = os.environ.get('CHK_FIM') or (date.today() - timedelta(days=1)).isoformat()
DIAS  = int(os.environ.get('CHK_DIAS', '14'))
INI   = os.environ.get('CHK_INICIO') or (date.fromisoformat(FIM) - timedelta(days=DIAS - 1)).isoformat()


def dias_do_periodo(ini, fim):
    d, f = date.fromisoformat(ini), date.fromisoformat(fim)
    while d <= f:
        yield d.isoformat()
        d += timedelta(days=1)


def buscar(data, tentativas=4):
    for i in range(tentativas):
        try:
            return bx.buscar_dia(data)
        except Exception as e:
            if i == tentativas - 1:
                raise
            print(f'    (tentando de novo: {e})', flush=True)
            time.sleep(2 * (i + 1))


def main():
    print(f'Checagem previa de caixas: {INI} a {FIM}')
    print(f'Nossa loja: {NOSSA}\n', flush=True)

    dono = bx.caixas_por_unidade()
    print(f'{len(dono)} caixas mapeados em pdv_vendas.caixa_ext\n', flush=True)

    quebra, mudos, ok = [], [], 0
    print(f'{"dia":12}{"caixas":>8}{"nossos":>8}{"outra":>7}{"sem loja":>10}  situacao')
    for d in dias_do_periodo(INI, FIM):
        j = buscar(d)
        caixas = j.get('caixas') or []
        nossos = outros = 0
        semloja_com_venda, semloja_sem_venda = [], []
        for cx in caixas:
            cid = cx.get('caixa_id')
            un  = dono.get(cid)
            fat = (cx.get('totais') or {}).get('faturado') or 0
            itens = sum(len(cm.get('itens') or []) for cm in (cx.get('comandas') or [])
                        if not cm.get('cancelada'))
            if un is None:
                (semloja_com_venda if fat > 0 else semloja_sem_venda).append((cid, fat, itens))
            elif un == NOSSA:
                nossos += 1
            else:
                outros += 1

        if semloja_com_venda:
            sit = 'DERRUBA O ROBO'
            quebra.append((d, semloja_com_venda))
        elif semloja_sem_venda and any(i > 0 for _, _, i in semloja_sem_venda):
            sit = 'passa, mas perde venda em silencio'
            mudos.append((d, semloja_sem_venda))
        elif not nossos:
            sit = 'nenhum caixa nosso no dia'
            mudos.append((d, []))
        else:
            sit = 'ok'
            ok += 1
        n_sem = len(semloja_com_venda) + len(semloja_sem_venda)
        print(f'  {d:12}{len(caixas):>8}{nossos:>8}{outros:>7}{n_sem:>10}  {sit}', flush=True)

    print(f'\ndias ok                    : {ok}')
    print(f'dias que DERRUBAM o robo   : {len(quebra)}')
    print(f'dias que merecem um olhar  : {len(mudos)}')

    if quebra:
        print('\n=== CAIXA COM VENDA E SEM LOJA - importe o relatorio do PDV desses dias ===')
        for d, lst in quebra:
            for cid, fat, itens in lst:
                print(f'  {d}  caixa {cid}  R$ {fat:,.2f}  {itens} itens')
    if mudos:
        print('\n=== olhar, mas nao trava ===')
        for d, lst in mudos:
            if not lst:
                print(f'  {d}  nenhum caixa da nossa loja no dia')
            for cid, fat, itens in lst:
                print(f'  {d}  caixa {cid}  sem faturamento mas com {itens} itens '
                      f'- venda que ninguem vai descontar')

    if quebra:
        print('\nRESULTADO: NAO ligar o automatico ainda. Resolva os dias acima.')
        return 1
    print('\nRESULTADO: todo caixa do periodo tem loja. O robo roda o periodo inteiro.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
