# Handoff — Baixa de estoque via API do PDV iComanda

> Investigado e validado em **14/08/2026** (na conversa do restaurante-financeiro).
> Objetivo deste doc: a conversa que vai construir a **baixa de estoque** não precisa
> re-investigar a API — é só seguir daqui. Tudo abaixo foi conferido contra dados reais.

## Acesso à API
- **Base:** `https://cloud.icomanda.com/tdb/apidashboard`
- **Auth:** `?api_key=apidash_249_aB3xY7zQ9Wm2KpV5` (read-only; já pública no `index.html` do restaurante-financeiro)
- **GOTCHA:** enviar header `User-Agent` (ex.: `tdb/1.0`). Sem UA, o `urllib`/python leva **HTTP 403**.
- **Cliente de referência** (mostra todos os campos): `restaurante-financeiro/index.html` ("Consulta iComanda — Dashboard API").

## Endpoint que alimenta a baixa
`GET /` (root, index.php) → JSON `caixas[].comandas[].itens[]`

- **Params:** `data_ini`, `data_fim` (`YYYY-MM-DD`, janela máx **31 dias**).
- **Limites:** 2000 comandas / 20000 itens por chamada.
- **Campos do item:**
  | campo | uso |
  |---|---|
  | `produto_id` (int) | **CHAVE de match** |
  | `produto_nome` (str) | rótulo |
  | `quantidade` | número vendido (o que baixa) |
  | `status` | `'ativo'` = venda real → **FILTRAR por isso** |
  | `origem_tipo` | sempre `"produto"` |
  | `valor_total`, `custo_unitario`, `produto_custo_atual` | bônus p/ conferir custo |
- `produto_codigo` vem **VAZIO em 100%** dos itens → casar **sempre por `produto_id`**, nunca por código.
- **Cancelados/transferidos vêm SEPARADOS:** `comanda.cancelada=true` (pular a comanda inteira), e `itens_cancelados[]` / `itens_transferidos[]` à parte → **não baixam estoque**.
- **Combos/kits = 1 `produto_id` único** (`origem_tipo` "produto"). iComanda **não expõe receita/composição** — a explosão em insumos é da **ficha técnica do nosso lado** (estoque-compras).

## Fluxo da baixa
```
puxar itens do período
 → filtrar status='ativo' E comanda.cancelada=false
 → somar quantidade por produto_id
 → mapear produto_id(iComanda) → produto(estoque-compras)
 → aplicar ficha técnica (conversão/perda já no produto)
 → deduzir insumos no saldo (est_movimentacoes / livro-razão F3)
```

## ÚNICA questão de design a decidir
**Mapear `produto_id`(iComanda) → produto(estoque-compras).** O iComanda usa id interno próprio.
- **(a) [recomendado]** gravar o id do iComanda no cadastro do produto do estoque, OU
- (b) casar por nome normalizado (dá colisão/ambiguidade — evitar como fonte única).

## Automação (padrão que JÁ existe e funciona)
- Robô GitHub Actions no restaurante-financeiro: `scripts/pull_pdv.py` + `.github/workflows/pull-pdv.yml`
  (cron 2×/dia + `workflow_dispatch`; python `urllib`; grava via Supabase REST com service key).
  **Mesmo esqueleto serve para a baixa.**
- `.gitignore` ignora `*.py` → precisa de exceção `!scripts/<nome>.py` para versionar o script.

## Consulta de exemplo (ver a estrutura do item, 1 dia)
```bash
curl -s -A "tdb/1.0" \
  "https://cloud.icomanda.com/tdb/apidashboard/?api_key=apidash_249_aB3xY7zQ9Wm2KpV5&data_ini=2026-08-05&data_fim=2026-08-05" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); c=d['caixas'][0]['comandas'][0]; print(json.dumps(c['itens'][0], ensure_ascii=False, indent=1))"
```

## Confiança no feed
A soma bate no centavo. Ex. 05/08: os itens conferem com o faturamento; e do lado de pagamentos,
210 cartões = R$ 35.513,75 = agregado do sistema. O feed é completo, não amostra.
