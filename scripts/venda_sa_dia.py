#!/usr/bin/env python3
"""
Venda de SA por dia e por unidade — a base da META DE PRODUÇÃO.

Para cada dia e cada unidade cadastrada em `prod_unidades` (Centro e Delivery P10),
puxa a venda do iComanda, explode cada prato pela ficha técnica e PARA na SA:
o que sobra é "quantas unidades de cada SA a venda daquela loja consumiu".
Grava em `prod_venda_sa_dia` (apaga o dia+unidade e regrava, então rodar de novo
substitui em vez de somar).

NÃO é baixa. Não encosta em saldo, razão nem pedido. É medição, como o
pdv_preparo_dia: se falhar, nada da operação para.

Por que parar na SA e não usar o saldo: a SA é o que a Produção fabrica. Um prato
pode levar a SA direto (filé de pirarucu no prato) ou dentro de um preparo da loja;
a recursão atravessa os preparos até achar a SA, e qualquer SA conta — tenha ela
saldo cadastrado ou não.

Mesma regra de segurança do robô da baixa: só conta produto do PDV que esteja
MAPEADO na `pdv_map` e tenha ficha ativa. Produto sem mapa aparece no log.

Variáveis de ambiente:
  SUPABASE_URL, SUPABASE_SERVICE_KEY   (obrigatórios; secrets do GitHub)
  VENDA_SA_DIAS     quantos dias para trás, a partir de ontem (default 3)
  VENDA_SA_INICIO   não processa antes desta data (default 2026-08-15)
"""
import os, sys, urllib.parse
from datetime import datetime, timedelta

# O módulo da baixa lê o ambiente ao ser importado. Forçar 'dry' garante que nada
# daqui consiga lançar no razão, mesmo que alguém configure BAIXA_MODE no job.
os.environ['BAIXA_MODE'] = 'dry'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import baixa_estoque_pdv as bx  # noqa: E402

DIAS   = int(bx.env('VENDA_SA_DIAS', '3'))
INICIO = datetime.strptime(bx.env('VENDA_SA_INICIO', '2026-08-15'), '%Y-%m-%d').date()


def carregar():
    # mapa: icomanda_id -> (produto_id, fator) so dos MAPEADOS; 'ignorar' fica fora
    # do mapa e tambem fora do aviso (bebida, taxa, etc. nao levam SA de proposito).
    mapa, ignorados = {}, set()
    for m in bx.sb_get_all('pdv_map?select=icomanda_produto_id,produto_id,fator,status'):
        if m.get('status') == 'mapeado' and m.get('produto_id'):
            mapa[m['icomanda_produto_id']] = (m['produto_id'], m.get('fator') or 1)
        elif m.get('status') == 'ignorar':
            ignorados.add(m['icomanda_produto_id'])
    mapa['_ignorados'] = ignorados
    fic = {}
    for f in bx.sb_get_all('est_fichas_tecnicas?select=id,produto_id,rendimento&ativo=eq.true'):
        fic[f['produto_id']] = {'ficha_id': f['id'], 'rendimento': f.get('rendimento') or 1}
    ings = {}
    for i in bx.sb_get_all('est_ficha_ingredientes?select=ficha_id,ingrediente_id,quantidade'):
        ings.setdefault(i['ficha_id'], []).append((i['ingrediente_id'], i.get('quantidade') or 0))
    sas = {p['id'] for p in bx.sb_get_all('est_produtos?select=id&tipo=eq.SA')}
    unidades = bx.sb_get_all('prod_unidades?select=unidade,unidade_pdv&order=ordem')
    return mapa, fic, ings, sas, unidades


def sa_do_dia(data, unidade_pdv, mapa, fic, ings, sas):
    bx.UNIDADE_PDV = unidade_pdv          # vendas_do_dia filtra por esta global
    vendas = bx.vendas_do_dia(data)
    memo, out, sem_mapa = {}, {}, 0
    for ip, qtd in vendas.items():
        m = mapa.get(ip)
        if not m:
            if ip not in mapa['_ignorados']:
                sem_mapa += qtd          # vendido e ainda sem decisao na pdv_map
            continue
        pid, fator = m
        # `sas` no lugar de `contado`: a recursão para em QUALQUER SA.
        folhas, _ = bx._bom(pid, fic, ings, sas, memo, set())
        for folha, fq in folhas.items():
            if folha in sas:
                out[folha] = out.get(folha, 0) + fq * qtd * fator
    return out, sem_mapa


def main():
    mapa, fic, ings, sas, unidades = carregar()
    print(f'== Venda de SA por dia == {len(unidades)} unidades, {len(sas)} SA cadastradas, {len(mapa) - 1} itens mapeados')
    hoje = datetime.now(bx.MANAUS).date()
    for i in range(DIAS, 0, -1):
        dia = hoje - timedelta(days=i)
        if dia < INICIO:
            continue
        data = dia.isoformat()
        for u in unidades:
            try:
                sa, sem_mapa = sa_do_dia(data, u['unidade_pdv'], mapa, fic, ings, sas)
            except bx.DiaAindaAberto as e:
                print(f'  {data} {u["unidade"]}: pulado — {e}')
                continue
            except Exception as e:
                print(f'  {data} {u["unidade"]}: ERRO — {e}')
                continue
            linhas = [{'data': data, 'unidade': u['unidade'], 'produto_id': pid,
                       'quantidade': round(q, 4)} for pid, q in sa.items() if q > 0]
            bx.sb_delete(f'prod_venda_sa_dia?data=eq.{data}&unidade=eq.{urllib.parse.quote(u["unidade"])}')
            for j in range(0, len(linhas), 500):
                bx.sb_insert('prod_venda_sa_dia', linhas[j:j + 500])
            print(f'  {data} {u["unidade"]}: {len(linhas)} SA gravadas'
                  + (f' · {sem_mapa:g} itens vendidos sem mapa no PDV' if sem_mapa else ''))
    print('== Fim ==')


if __name__ == '__main__':
    main()
