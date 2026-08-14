-- ═══════════════════════════════════════════════════════════════
-- pdv_map.setor — de qual SETOR a venda baixa o estoque
-- O setor é do PRATO/BEBIDA vendido (de lá sai o produto final ao cliente);
-- o ESTOQUE_LOJA só abastece. Rodar UMA vez.
-- ═══════════════════════════════════════════════════════════════

alter table pdv_map add column if not exists setor text;

-- Setores válidos (operacionais): COZINHA, BAR, DELIVERY, SALAO, CHURRASQUEIRA, ASG.
-- Fica NULL até ser semeado/curado. O robô apply NÃO baixa venda sem setor definido
-- (evita descontar do lugar errado).
