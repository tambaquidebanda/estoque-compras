-- ══════════════════════════════════════════════════════════════
-- Configurações compartilhadas do Inventário (mapeamentos e exclusões)
-- Rodar no Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS inv_configuracoes (
  chave text PRIMARY KEY,
  valor jsonb NOT NULL DEFAULT '{}'
);

-- Linhas iniciais (não sobrescreve se já existirem)
INSERT INTO inv_configuracoes (chave, valor) VALUES ('mapeamentos', '{}') ON CONFLICT DO NOTHING;
INSERT INTO inv_configuracoes (chave, valor) VALUES ('excluidos',   '[]') ON CONFLICT DO NOTHING;
