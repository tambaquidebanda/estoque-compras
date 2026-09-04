# -*- coding: utf-8 -*-
import os,re,json,importlib.util,unicodedata,collections
RAIZ='/Users/wagnercarvalho/Documents/GitHub/estoque-compras'
src=open(os.path.join(RAIZ,'supabase.js')).read()
os.environ['SUPABASE_URL']=re.search(r"SB_URL\s*=\s*'([^']+)'",src).group(1)
os.environ['SUPABASE_SERVICE_KEY']=re.search(r"SB_SERVICE_KEY\s*=\s*'([^']+)'",src).group(1)
spec=importlib.util.spec_from_file_location('bx',os.path.join(RAIZ,'scripts','baixa_estoque_pdv.py'))
bx=importlib.util.module_from_spec(spec); spec.loader.exec_module(bx)
mapa,fpp,ipf,P,contado,setor_de,ambiguos,sem_setor=bx.carregar()
ATIVO={p['id']:p.get('ativo') for p in bx.sb_get_all('est_produtos?select=id,ativo')}

# ---------------------------------------------------------------------------
# Vendas dos ultimos 30 dias, SO da loja em BAIXA_UNIDADE_PDV (default Centro).
# Somar as duas lojas aqui ja me fez entregar analise errada uma vez: o Parque
# 10 ainda nao esta no sistema. A loja de cada caixa vem de caixas_por_unidade().
# Guarda em cache ao lado do script; apague o arquivo para forcar releitura.
# ---------------------------------------------------------------------------
import datetime, collections as _c
CACHE=os.path.join(os.path.dirname(os.path.abspath(__file__)),'.vendas_30d.json')
def _vendas30():
    hoje=datetime.date.today().isoformat()
    if os.path.exists(CACHE):
        d=json.load(open(CACHE))
        if d.get('gerado_em')==hoje: return {k:v for k,v in d['cen'].items()}
    dono=bx.caixas_por_unidade(); cen=_c.Counter(); desconhecidos=_c.Counter()
    hj=datetime.date.today()
    for i in range(1,31):
        dia=(hj-datetime.timedelta(days=i)).isoformat()
        try: j=bx.buscar_dia(dia)
        except Exception as e:
            print('  aviso: dia %s nao veio (%s)'%(dia,e)); continue
        for cx in (j.get('caixas') or []):
            un=dono.get(cx.get('caixa_id'))
            if un is None:
                if ((cx.get('totais') or {}).get('faturado') or 0)>0: desconhecidos[dia]+=1
                continue
            if un!=bx.UNIDADE_PDV: continue
            for cm in (cx.get('comandas') or []):
                if cm.get('cancelada'): continue
                for it in (cm.get('itens') or []):
                    if it.get('status')=='ativo': cen[it.get('produto_id')]+=it.get('quantidade') or 0
    if desconhecidos:
        print('  aviso: %d dia(s) com caixa sem loja identificada (relatorio do PDV nao importado): %s'
              %(len(desconhecidos),', '.join(sorted(desconhecidos))))
    # do id do iComanda para o nosso produto_id, SOMANDO quando varios apontam para o mesmo
    mp={m['icomanda_produto_id']:m['produto_id'] for m in
        bx.sb_get_all('pdv_map?select=icomanda_produto_id,produto_id,status&status=eq.mapeado')}
    out=_c.Counter()
    for pdvid,q in cen.items():
        if mp.get(pdvid): out[mp[pdvid]]+=q
    json.dump({'gerado_em':datetime.date.today().isoformat(),'cen':dict(out)},open(CACHE,'w'))
    return dict(out)
_CEN=_vendas30()
casa={k:{"qtd":v} for k,v in _CEN.items()}
def vend(p): return casa.get(p,{}).get('qtd',0) or 0
def nome(p): return (P.get(p) or {}).get('nome','?')
def sn(s):
    s=unicodedata.normalize('NFKD',s or '').encode('ascii','ignore').decode().upper()
    return re.sub(r'[^A-Z0-9 ]',' ',s)
def eff(p):
    x=P.get(p) or {}; fa=x.get('fator_conversao') or 1; pe=x.get('perda') or 0
    r=1-pe/100.0
    return ((x.get('custo_comp') or 0)/fa)/r if r>0 else 0
VEND={p for p in casa if vend(p)>0}
memo={}; BOM={p:bx._bom(p,fpp,ipf,contado,memo,set()) for p in VEND}

# arvore COMPLETA (ignora 'contado') - so para conferir nome
memoF={}
def full(pid,stack=None):
    stack=stack or set()
    if pid in memoF: return memoF[pid]
    if pid not in fpp or pid in stack: return set()
    out=set()
    for ing,_ in (ipf.get(fpp[pid]['ficha_id']) or []):
        if ing: out|={ing}|full(ing,stack|{pid})
    memoF[pid]=out
    return out
FULL={p:full(p) for p in VEND}

USADOS={i[0] for its in ipf.values() for i in its if i[0]}
PREF={'MP','SA','PPC','PPP','MC','MU'}
VOCAB=set()
for pid in USADOS:
    for t in sn(nome(pid)).split():
        if t in PREF or len(t)<4 or any(c.isdigit() for c in t): continue
        VOCAB.add(t)
VOCAB-={'MOLHO','CREME','PASTA','FUNDO','CALDO','PORCAO','UNID','PACOTE','MASSA','COZIDO','COZIDA',
'REDUZIDO','COMPOSTO','REFINADO','DESCASCADO','GRAOS','CHEIRO','BANDA','GRANDE','PEQUENO','EMBALAGEM'}
def ingw(s): return {t for t in sn(s).split() if t in VOCAB}

ACH=collections.defaultdict(list)
def add(p,c,t): ACH[p].append((c,t))
mapeados={m['produto_id'] for m in mapa.values()}
for p in VEND:
    if p not in mapeados: add(p,'A1','vende e nao tem mapeamento no pdv_map')
    elif p not in fpp and p not in contado: add(p,'A2','mapeado e sem ficha ativa')
    elif p in fpp and not ipf.get(fpp[p]['ficha_id']): add(p,'A3','ficha ativa e VAZIA')
    elif not BOM[p][0]: add(p,'A4','a ficha nao chega em item de estoque')
    if ATIVO.get(p) is False: add(p,'D1','produto INATIVO mas vendendo')
    for fo in BOM[p][0]:
        if fo in sem_setor: add(p,'B1',f'{nome(fo)} nao tem setor na contagem')
        elif fo in ambiguos: add(p,'B2',f'{nome(fo)} contado em varios setores sem desempate')
        if ATIVO.get(fo) is False: add(p,'B3',f'insumo INATIVO: {nome(fo)}')
        if eff(fo)<=0: add(p,'B4',f'insumo com custo zero: {nome(fo)}')
    c=sum(q*eff(f) for f,q in BOM[p][0].items()); pv=(P.get(p) or {}).get('preco_venda') or 0
    if pv>0 and c>pv: add(p,'C3',f'custo R$ {c:.2f} > venda R$ {pv:.2f}')
    f=fpp.get(p)
    if f:
        for ing,q in (ipf.get(f['ficha_id']) or []):
            if not q or float(q)<=0: add(p,'C4',f'quantidade zero: {nome(ing)}')
        if not f.get('rendimento') or float(f['rendimento'])<=0: add(p,'C7','rendimento invalido')
vaz={pid for pid,f in fpp.items() if not ipf.get(f['ficha_id']) and pid not in contado}
for p in VEND:
    for pr in (set(BOM[p][1])|set(BOM[p][0]))-{p}:
        if pr in vaz: add(p,'C6',f'atravessa preparo de ficha VAZIA: {nome(pr)}')

# C2: so palavra que o resto do cardapio ALCANCA (a palavra se prova sozinha)
ARV={p:{w for x in FULL[p] for w in sn(nome(x)).split()} for p in VEND}
for w in VOCAB:
    com=[p for p in VEND if w in sn(nome(p)).split()]
    if len(com)<3: continue
    ok=[p for p in com if w in ARV[p]]
    if len(ok)/len(com)<0.6: continue
    for p in com:
        if w not in ARV[p]:
            add(p,'C2','o nome diz "%s" e a receita nao tem (outros %d de %d pratos com essa palavra alcancam)'%(w,len(ok),len(com)))

QT=re.compile(r'(\d+(?:[.,]\d+)?)\s*(ML|L|LT|UN|UNID|UNIDS|PC|G|KG|PESSOAS)?\b')
def qtds(s):
    U={'LT':'L','UNID':'UN','UNIDS':'UN','PC':'UN'}
    out=set()
    for num,un in QT.findall(sn(s)):
        out.add((num.replace(',','.').rstrip('0').rstrip('.'), U.get(un,un) or ''))
    return out
MET={'ASSADA','ASSADO','FRITA','FRITO','COZIDA','COZIDO','GRELHADA','GRELHADO'}
DOB={'DOBRO','DUPLO','DUPLA'}
assin=collections.defaultdict(list)
for pid,f in fpp.items():
    its=ipf.get(f['ficha_id']) or []
    if its: assin[tuple(sorted((str(i[0]),round(float(i[1] or 0),4)) for i in its))].append(pid)
def maior(a,b):
    """qual dos dois nomes declara a MAIOR quantidade (3UN x 6UN)."""
    na=[float(x[0]) for x in qtds(a) if x[0]]
    nb=[float(x[0]) for x in qtds(b) if x[0]]
    if not na or not nb: return None
    return a if max(na)>max(nb) else (b if max(nb)>max(na) else None)
for its,pids in assin.items():
    if len(pids)<2: continue
    for p in pids:
        if p not in VEND: continue
        w=ingw(nome(p)); sp=set(sn(nome(p)).split())
        for o in pids:
            if o==p: continue
            wo=ingw(nome(o)); so=set(sn(nome(o)).split())
            if w and wo and not (w&wo):
                add(p,'C1',f'ficha identica a de {nome(o)} - nao tem nenhum ingrediente em comum no nome')
            elif w==wo:
                a,b=qtds(nome(p)),qtds(nome(o))
                # C8: quem erra e o de MAIOR quantidade (baixa o preparo do menor).
                # Se o culpado nao vende, nao ha exposicao e nao ha achado.
                if a!=b and a and b:
                    culpado=maior(nome(p),nome(o))
                    if culpado==nome(p):
                        add(p,'C8',f'mesma ficha de {nome(o)}, mas este declara quantidade maior - deve estar baixando o preparo do menor')
                # C10: quem erra e o DOBRO. Idem: so acusa se o dobro vender.
                if (sp&DOB) and not (so&DOB):
                    add(p,'C10',f'e dobro e tem a mesma ficha de {nome(o)} - deveria baixar o dobro')
                ma,mb=sp&MET,so&MET
                if ma and mb and ma!=mb:
                    add(p,'C9',f'mesma ficha de {nome(o)}, mas um e {"/".join(ma)} e o outro {"/".join(mb)}')
dup=collections.defaultdict(list)
for pid,x in P.items():
    if ATIVO.get(pid) is False: continue      # cadastro inativado nao e duplicata
    dup[sn(x['nome']).strip()].append(pid)
for n_,pids in dup.items():
    if len(pids)>1:
        for p in [x for x in pids if vend(x)>0]: add(p,'D2',f'{len(pids)} cadastros com este mesmo nome')
for p in VEND:
    x=P.get(p) or {}
    uc=(x.get('unidade_comp') or '').upper().strip(); uu=(x.get('unidade_uso') or '').upper().strip()
    if uc and uu and uc!=uu and (x.get('fator_conversao') or 1)==1: add(p,'D3',f'compra em {uc}, usa em {uu}, fator 1')
for m in mapa.values():
    if m['produto_id'] not in P: add(m['produto_id'],'D4','pdv_map aponta para produto inexistente')


# ==========================================================================
# EXCECOES - achados conferidos um a um e classificados como NAO-ERRO.
# Nada aqui e suprimido em silencio: o rodape diz quantos foram e por que.
# Formato: (codigo, trecho do nome do produto, trecho do texto, motivo, data)
#   trecho vazio = casa com qualquer coisa
# Para reabrir um caso, apague a linha e rode de novo.
# ==========================================================================
EXCECOES = [
 # --- decisoes do Wagner (04/09/2026) ---
 ('C6','', 'PPC FUNDO DE PEIXE',
  'o fundo e feito de sobra de corte de peixe: nao tem custo e nao entra na contagem, '
  'entao ficha vazia e o certo mesmo', '2026-09-04'),
 ('C9','BANANA','',
  'oleo de fritura e material de apoio, nao materia-prima: nao entra em ficha', '2026-09-04'),
 ('C2','PIRAO DE TAMBAQUI','TAMBAQUI',
  'o peixe entraria pelo PPC FUNDO DE PEIXE, que e vazio de proposito (ver excecao C6)', '2026-09-04'),

 ('D1','CAIPILE','',
  'os dois caipiles do CLUBE ROTEROS BAR sairam do cardapio e do PDV em 31/08; '
  'as vendas que aparecem sao anteriores a inativacao', '2026-09-04'),

 # --- falsos positivos que eu conferi um a um ---
 ('C2','MATRINXA DE CASACA','CASACA',
  'a ficha tem MP MATRINXA. "De casaca" e modo de preparo, nao ingrediente', '2026-09-04'),
 ('C2','MOQUECA VEGETARIANA','MOQUECA',
  'a ficha tem jambu, tucupi, leite de coco, banana e tomate: e uma moqueca completa', '2026-09-04'),
 ('C2','CAIXA TAMBAQUI VIAGEM','TAMBAQUI',
  'o produto e a embalagem (MC CAIXA DE PEIXE), nao o peixe', '2026-09-04'),
 ('C2','FAROFA DE CAMARAO','FAROFA',
  'e feita do zero com farinha ovinha; nao usa o preparo PPC FAROFA', '2026-09-04'),
 ('C2','GUARANA BARE 2L','GUARANA',
  'usa MP BARE DE 2 LITROS, que e o guarana; a palavra so nao esta no nome do insumo', '2026-09-04'),
 ('C2','PETIT GANEAU','PETIT',
  'e outro produto, nao um petit gateau: a ficha dele esta certa', '2026-09-04'),
 ('C1','GUARANA BARE 2L','PEPSI BLACK',
  'o guarana esta certo; quem tem a ficha errada e a PEPSI BLACK 1 L, que vende 0', '2026-09-04'),
 ('C1','ISCA DE FRANGO KIDS','ESTROGONOFF DE CARNE',
  'a ficha e de isca com fritas mesmo; quem esta errado e o estrogonoff, que vende 0', '2026-09-04'),
 ('C1','MOLHO DE CUPUACU','MAIONESE EXTRA',
  'o molho de cupuacu esta certo; quem esta errada e a MAIONESE EXTRA, que vende 0', '2026-09-04'),
]
def _excecao(pid,cod,txt):
    nm=sn(nome(pid))
    for c,frag_nome,frag_txt,motivo,data in EXCECOES:
        if c!=cod: continue
        if frag_nome and sn(frag_nome) not in nm: continue
        if frag_txt and sn(frag_txt) not in sn(txt): continue
        return motivo
    return None
SUPRIMIDOS=[]
for pid in list(ACH):
    fica=[]
    for cod,txt in ACH[pid]:
        m=_excecao(pid,cod,txt)
        if m: SUPRIMIDOS.append((cod,nome(pid),m))
        else: fica.append((cod,txt))
    if fica: ACH[pid]=fica
    else: del ACH[pid]

json.dump(dict(ACH),open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'.checagem_ultimo.json'),'w'))
NOMES={'A1':'vende e nao tem mapeamento','A2':'mapeado sem ficha','A3':'ficha ativa e vazia','A4':'ficha nao chega em estoque',
'B1':'insumo sem setor na contagem','B2':'insumo em varios setores','B3':'insumo inativo','B4':'insumo com custo zero',
'C1':'ficha de outro produto','C2':'nome cita ingrediente que a receita nao tem','C3':'custo maior que a venda',
'C4':'ingrediente com quantidade zero','C6':'atravessa preparo de ficha vazia','C7':'rendimento invalido',
'C8':'mesma ficha, quantidade diferente no nome','C9':'mesma ficha, metodo de preparo diferente',
'C10':'mesma ficha, um deles e DOBRO','D1':'produto inativo vendendo','D2':'cadastro duplicado',
'D3':'fator 1 com unidades diferentes','D4':'pdv_map orfao'}
print("universo: %d produtos venderam nos ultimos 30 dias\n"%len(VEND))
print("%-5s %-46s %8s %9s"%("cod","o que e","produtos","un/30d"))
print("-"*72)
for c in ['A1','A2','A3','A4','B1','B2','B3','B4','C1','C2','C3','C4','C6','C7','C8','C9','C10','D1','D2','D3','D4']:
    ps={p for p,v in ACH.items() if any(x[0]==c for x in v)}
    print("%-5s %-46s %8d %9.0f"%(c,NOMES[c],len(ps),sum(vend(p) for p in ps)))
print("-"*72)
print("produtos com achado: %d de %d"%(len(ACH),len(VEND)))
print()
print("%d achado(s) suprimido(s) por excecao conferida:"%len(SUPRIMIDOS))
vis=set()
for cod,nm,motivo in SUPRIMIDOS:
    if (cod,nm) in vis: continue
    vis.add((cod,nm))
    print("   %-4s %-40s %s"%(cod,nm[:40],motivo[:70]))
