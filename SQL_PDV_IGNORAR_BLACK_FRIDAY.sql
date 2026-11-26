-- SQL_PDV_IGNORAR_BLACK_FRIDAY.sql — id 3149 do iComanda (TAMBAQUI DE BANDA BLACK FRIDAY) vira "ignorar"
--
-- Por quê (levantado em 25/11 nas comandas do iComanda de 26/10 a 24/11):
--   * 431 das 433 vendas são pedidos do iFood que entraram sozinhos pela integração;
--     403 delas de 01/11 a 04/11, quando a integração trocou os itens (pratos de vários
--     preços caíram neste produto e o tambaqui do delivery entrou como o do salão).
--   * 219 saíram a R$ 0,00; o preço do cadastro (R$ 109,90) foi cobrado só 2 vezes.
--   * Depois de 04/11 sobra 1 a 5 por dia, a R$ 0,00, numa opção da Marmita de Frango à
--     Parmegiana do Cardápio Web do iFood. Não é tambaqui.
-- "ignorar" = as vendas deste id não dão baixa em nada. Não mexe em estoque, não apaga
-- nada, não muda venda antiga e não muda o iComanda. Volta atrás pela tela de
-- Mapeamento do PDV.
-- O conserto de verdade é no iComanda: tirar o vínculo da opção da marmita com este
-- produto na integração do iFood e inativar o produto se a promoção acabou.

-- ═══ PASSO 1 — CONFERIR (só leitura) ═══════════════════════════════════════════════
-- Esperado: nenhuma linha (o id nunca entrou no mapeamento) ou uma linha sem produto ligado.
SELECT m.icomanda_produto_id, m.icomanda_nome, m.status, p.nome AS ligado_a, m.obs
FROM pdv_map m
LEFT JOIN est_produtos p ON p.id = m.produto_id
WHERE m.icomanda_produto_id = 3149;

-- ═══ PASSO 2 — GRAVAR ══════════════════════════════════════════════════════════════
INSERT INTO pdv_map (icomanda_produto_id, icomanda_nome, status, obs)
VALUES (3149, 'TAMBAQUI DE BANDA BLACK FRIDAY', 'ignorar',
        'Ignorado em 25/11/2026: integracao do iFood jogou itens trocados neste produto (01-04/11) e depois so a opcao R$ 0 da marmita parmegiana do Cardapio Web. Nao e tambaqui.')
ON CONFLICT (icomanda_produto_id)
DO UPDATE SET status = 'ignorar', produto_id = NULL, obs = EXCLUDED.obs, atualizado_em = now();

-- ═══ PASSO 3 — CONFERIR DEPOIS (só leitura) ═════════════════════════════════════════
-- Esperado: 1 linha, status = ignorar, ligado_a vazio.
SELECT m.icomanda_produto_id, m.icomanda_nome, m.status, p.nome AS ligado_a, m.obs, m.atualizado_em
FROM pdv_map m
LEFT JOIN est_produtos p ON p.id = m.produto_id
WHERE m.icomanda_produto_id = 3149;
