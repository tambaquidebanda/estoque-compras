#!/usr/bin/env python3
"""
Venda de SA por dia e por unidade — a base da META DE PRODUÇÃO.

Para cada dia e cada unidade cadastrada em `prod_unidades` (Centro e Delivery P10),
puxa a venda do iComanda, explode cada prato pela ficha técnica e PARA na SA:
o que sobra é "quantas unidades de cada SA a venda daquela loja consumiu".
Grava em `prod_venda_sa_dia` (apaga o dia+unidade e regrava, então rodar de novo
substitui em vez de somar). E em `prod_venda_sa_origem` o mesmo consumo aberto por
prato vendido — é o que a tela da meta mostra ao passar o mouse na SA (08/10/2026).
Sem essa tabela (SQL_PRODUCAO_VENDA_ORIGEM.sql não rodado) o robô segue igual.
E em `prod_venda_item_dia` a venda de cada produto do cadastro, sem abrir a ficha
(PDV mapeado × fator): é a base do PLANEJAMENTO DE COMPRAS (22/10/2026), que abre a
ficha na tela até a MP. Sem a tabela (SQL_PLANEJAMENTO_COMPRAS.sql) o robô segue igual.

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
from functools import lru_cache  # noqa: E402

# O iComanda devolve o dia inteiro (as duas lojas) numa chamada só, e ela pode levar
# 15 s ou mais (09/10/2026). Sem isto cada dia era baixado uma vez por unidade.
bx.buscar_dia = lru_cache(maxsize=1)(bx.buscar_dia)

DIAS   = int(bx.env('VENDA_SA_DIAS', '3'))
INICIO = datetime.strptime(bx.env('VENDA_SA_INICIO', '2026-08-15'), '%Y-%m-%d').date()

# Acompanhamento que o cliente ESCOLHE no PDV mas que a ficha do prato traz fixo (09/10/2026).
# Nos pratos do delivery a comanda traz, a R$ 0, a escolha do cliente: PORC BATATA FRITA (P10)
# / BATATA FRITA DELIVERY (Centro), PURE DE BATATA, MAIONESE DE BATATA ou FEIJAO, cada um
# mapeado e com ficha própria. A ficha do prato também tem SA BATATA 100g = 1 (fica por
# causa do preço e do cadastro no iFood), então a batata contava 2x quando o cliente
# escolhia batata e 1x quando escolhia purê/maionese/feijão. Aqui a linha é ignorada SÓ
# para a meta; a ficha, o custo e a baixa não mudam. Varredura de 14 dias (25/09 a 08/10,
# as duas lojas) achou só estes 5 pratos. O combo "STROGONOFF + REFRI LATA" está mapeado
# para o ESTROGONOFF DE FRANGO e entra junto. A mesma lista está em app.js
# (_META_ACOMP_ESCOLHIDO): mudar uma, mudar a outra.
SA_BATATA = '97d60b41-adce-419a-b834-129c3c4e237a'           # SA BATATA 100g
ACOMP_ESCOLHIDO = {
    '5917edfc-0e35-4199-87e1-674c4f9a9d5c': {SA_BATATA},   # ESTROGONOFF DE FRANGO
    'a13761b4-9c9d-4155-a3b5-24fecb0c5ee9': {SA_BATATA},   # ESTROGONOFF DE FRANGO - TDB
    'b2cd6c47-6fba-4720-ae04-92eed5d93875': {SA_BATATA},   # MARMITA DE FRANGO ASSADO NA BRASA
    '1447281d-b246-466b-9168-d11bb484ce84': {SA_BATATA},   # MARMITA DE FRANGO ASSADO NA BRASA - TDB
    'c8b220ed-a151-4a4a-9583-33d5399676a1': {SA_BATATA},   # EMPANADO DE PIRARUCU
    '2680e403-e06b-4ae8-b0d1-f2f344e48e93': {SA_BATATA},   # MARMITA FRANGO A PARMEGIANA (23/10/2026, P10 e delivery do Centro)
}


# Guarnição que o cliente ESCOLHE entre arroz e baião (Wagner, 28/10/2026). A comanda traz,
# logo depois do prato e a R$ 0, uma linha ARROZ / BAIÃO / MIX ARROZ E BAIÃO com a escolha.
# Essas linhas são 'ignorar' na pdv_map (a ficha do prato já traz a guarnição, como ARROZ
# COZIDO, por causa do preço), então o baião escolhido não entrava em nada: o feijão de praia
# do Planejamento dava 3,3 kg em 4 semanas no Centro, com 150 kg comprados. Medido de 29/09
# a 26/10 casando cada escolha com o prato de antes: baião 79% no Centro (2.116 de 2.685) e
# 72% no P10 (875 de 1.222); arroz 16% e 28%; mix 5% no Centro (é meia porção de cada).
# Aqui, SÓ para prod_venda_item_dia (Planejamento): quando o cliente escolhe baião, o arroz
# cozido da ficha do prato vira baião do mesmo peso (o mix troca metade). Linha de arroz/baião
# vendida avulsa (com preço) entra pelo produto dela. A ficha, o custo, a baixa e as SA não
# mudam. A mesma troca é a solução da baixa (est_ficha_ingredientes.baixa_estoque, pendente).
PPC_ARROZ = 'f5e99f52-6639-4f05-9ea4-894dfb0c363e'          # PPC ARROZ COZIDO
PPC_BAIAO = '686ba5e4-0411-4309-869c-ecdbd1203c1d'          # PPC BAIAO DE DOIS
GUARN_BAIAO = {692, 2577, 629, 3034}                        # BAIAO GRANDE, BAIAO, BAIAO PEQUENO, BAIÃO
GUARN_MIX = 1726                                            # MIX ARROZ E BAIAO (meia porção de cada)
GUARN_ARROZ = {28, 2576}                                    # ARROZ GRANDE, ARROZ (ignorar)
GUARN_MIX_PARTES = ('2bf5942a-8637-4d79-a011-2b7e24c65c98', # ARROZ GRANDE
                    '6f26dc21-6392-4d8a-9820-30f05f310579') # BAIAO GRANDE


def carregar():
    # mapa: icomanda_id -> (produto_id, fator) so dos MAPEADOS; 'ignorar' fica fora
    # do mapa e tambem fora do aviso (bebida, taxa, etc. nao levam SA de proposito).
    mapa, ignorados, guarn = {}, set(), {}
    for m in bx.sb_get_all('pdv_map?select=icomanda_produto_id,produto_id,fator,status'):
        if m['icomanda_produto_id'] in GUARN_BAIAO | GUARN_ARROZ and m.get('produto_id'):
            guarn[m['icomanda_produto_id']] = m['produto_id']
        if m.get('status') == 'mapeado' and m.get('produto_id'):
            mapa[m['icomanda_produto_id']] = (m['produto_id'], m.get('fator') or 1)
        elif m.get('status') == 'ignorar':
            ignorados.add(m['icomanda_produto_id'])
    mapa['_ignorados'] = ignorados
    mapa['_guarn'] = guarn
    fic = {}
    for f in bx.sb_get_all('est_fichas_tecnicas?select=id,produto_id,rendimento&ativo=eq.true'):
        fic[f['produto_id']] = {'ficha_id': f['id'], 'rendimento': f.get('rendimento') or 1}
    ings = {}
    for i in bx.sb_get_all('est_ficha_ingredientes?select=ficha_id,ingrediente_id,quantidade'):
        ings.setdefault(i['ficha_id'], []).append((i['ingrediente_id'], i.get('quantidade') or 0))
    for prato, tirar in ACOMP_ESCOLHIDO.items():        # o acompanhamento entra pelo item escolhido
        f = fic.get(prato)
        if f:
            ings[f['ficha_id']] = [(ing, q) for ing, q in ings.get(f['ficha_id'], []) if ing not in tirar]
    sas, nomes = set(), {}
    for p in bx.sb_get_all('est_produtos?select=id,nome,tipo'):
        nomes[p['id']] = p.get('nome')
        if p.get('tipo') == 'SA':
            sas.add(p['id'])
    unidades = bx.sb_get_all('prod_unidades?select=unidade,unidade_pdv&order=ordem')
    return mapa, fic, ings, sas, unidades, nomes


def sa_do_dia(data, unidade_pdv, mapa, fic, ings, sas):
    bx.UNIDADE_PDV = unidade_pdv          # vendas_do_dia filtra por esta global
    vendas = bx.vendas_do_dia(data)
    memo, out, origem, itens, sem_mapa = {}, {}, {}, {}, 0
    for ip, qtd in vendas.items():
        m = mapa.get(ip)
        if not m:
            if ip not in mapa['_ignorados']:
                sem_mapa += qtd          # vendido e ainda sem decisao na pdv_map
            continue
        pid, fator = m
        itens[pid] = itens.get(pid, 0) + qtd * fator
        # `sas` no lugar de `contado`: a recursão para em QUALQUER SA.
        folhas, _ = bx._bom(pid, fic, ings, sas, memo, set())
        for folha, fq in folhas.items():
            if folha in sas:
                out[folha] = out.get(folha, 0) + fq * qtd * fator
                o = origem.setdefault((folha, pid), [0, 0])     # [pratos vendidos, SA consumida]
                o[0] += qtd * fator
                o[1] += fq * qtd * fator
    for pid, q in guarnicao_do_dia(unidade_pdv, mapa, fic, ings, data).items():
        itens[pid] = itens.get(pid, 0) + q
    return out, origem, sem_mapa, itens


def _arroz_do_prato(pid, fic, ings):
    """kg de PPC ARROZ COZIDO direto na ficha de 1 unidade do prato (0 se não tem)."""
    f = fic.get(pid)
    if not f:
        return 0
    return sum(q or 0 for ing, q in ings.get(f['ficha_id'], []) if ing == PPC_ARROZ) / (f['rendimento'] or 1)


def guarnicao_do_dia(unidade_pdv, mapa, fic, ings, data):
    """{ produto_id: qtd } a somar na venda por item do dia: a troca arroz -> baião da
    escolha do cliente (pode ser negativa no PPC ARROZ COZIDO) e a guarnição avulsa.
    Lê as comandas do dia (já baixadas por vendas_do_dia, que também confere os caixas)."""
    dono = bx.caixas_por_unidade()
    out = {}
    def soma(pid, q):
        out[pid] = out.get(pid, 0) + q
    for cx in (bx.buscar_dia(data).get('caixas') or []):
        if (cx.get('status_caixa') or '') != 'fechado' or dono.get(cx.get('caixa_id')) != unidade_pdv:
            continue
        for cm in (cx.get('comandas') or []):
            if cm.get('cancelada'):
                continue
            prato = None      # último item com preço antes da escolha
            for it in sorted((i for i in bx.itens_vendidos(cm) if i.get('status') == 'ativo'), key=lambda i: i.get('id') or 0):
                ip, qtd = it.get('produto_id'), it.get('quantidade') or 0
                pago = (it.get('valor_unitario') or 0) > 0
                eh_guarn = ip in GUARN_BAIAO or ip in GUARN_ARROZ or ip == GUARN_MIX
                if eh_guarn and pago:                      # guarnição vendida avulsa
                    if ip == GUARN_MIX:
                        for parte in GUARN_MIX_PARTES:
                            soma(parte, 0.5 * qtd)
                    elif mapa['_guarn'].get(ip):
                        soma(mapa['_guarn'][ip], qtd)
                    continue
                if eh_guarn:                               # escolha do cliente, a R$ 0
                    if ip in GUARN_ARROZ or not prato:
                        continue                           # arroz: a ficha do prato já conta
                    parte = 0.5 if ip == GUARN_MIX else 1
                    m = mapa.get(prato)
                    arroz = _arroz_do_prato(m[0], fic, ings) * m[1] if m else 0
                    if arroz > 0:
                        soma(PPC_ARROZ, -arroz * parte * qtd)
                        soma(PPC_BAIAO, arroz * parte * qtd)
                    elif ip in GUARN_BAIAO and mapa['_guarn'].get(ip):
                        soma(mapa['_guarn'][ip], parte * qtd)   # prato sem arroz na ficha: baião a mais
                    continue
                if pago:
                    prato = ip
    return out


def tem_tabela(tabela, sem):
    try:
        bx.sb_get_all(f'{tabela}?select=data&data=eq.1900-01-01')
        return True
    except Exception as e:
        print(f'  {tabela} indisponível ({e}): {sem}')
        return False


def main():
    mapa, fic, ings, sas, unidades, nomes = carregar()
    com_origem = tem_tabela('prod_venda_sa_origem', 'os pratos de cada SA não são guardados.')
    com_itens = tem_tabela('prod_venda_item_dia', 'o Planejamento de Compras fica sem a venda do dia.')
    print(f'== Venda de SA por dia == {len(unidades)} unidades, {len(sas)} SA cadastradas, {len(mapa) - 1} itens mapeados')
    hoje = datetime.now(bx.MANAUS).date()
    for i in range(DIAS, 0, -1):
        dia = hoje - timedelta(days=i)
        if dia < INICIO:
            continue
        data = dia.isoformat()
        for u in unidades:
            try:
                sa, origem, sem_mapa, itens = sa_do_dia(data, u['unidade_pdv'], mapa, fic, ings, sas)
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
            if com_origem:
                orig = [{'data': data, 'unidade': u['unidade'], 'sa_id': sa_id, 'prato_id': pid,
                         'prato_nome': nomes.get(pid), 'qtd_vendida': round(v, 4), 'qtd_sa': round(q, 4)}
                        for (sa_id, pid), (v, q) in origem.items() if q > 0]
                bx.sb_delete(f'prod_venda_sa_origem?data=eq.{data}&unidade=eq.{urllib.parse.quote(u["unidade"])}')
                for j in range(0, len(orig), 500):
                    bx.sb_insert('prod_venda_sa_origem', orig[j:j + 500])
            if com_itens:
                vit = [{'data': data, 'unidade': u['unidade'], 'produto_id': pid, 'quantidade': round(q, 4)}
                       for pid, q in itens.items() if abs(q) > 1e-9]   # PPC ARROZ COZIDO pode ficar negativo (troca pelo baião)
                bx.sb_delete(f'prod_venda_item_dia?data=eq.{data}&unidade=eq.{urllib.parse.quote(u["unidade"])}')
                for j in range(0, len(vit), 500):
                    bx.sb_insert('prod_venda_item_dia', vit[j:j + 500])
            print(f'  {data} {u["unidade"]}: {len(linhas)} SA gravadas'
                  + (f' · {sem_mapa:g} itens vendidos sem mapa no PDV' if sem_mapa else ''))
    print('== Fim ==')


if __name__ == '__main__':
    main()
