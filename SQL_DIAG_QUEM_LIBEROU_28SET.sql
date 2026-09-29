-- =====================================================================
-- SQL_DIAG_QUEM_LIBEROU_28SET.sql  (29/09/2026)   SO LEITURA
--
-- Quem estava logado quando os 21 pedidos da Cozinha e do Bar foram
-- liberados (28/09 23:00-23:03) e recebidos (23:03-23:06, horario Manaus).
--
-- O sistema de login do Supabase registra cada entrada e cada renovacao
-- de sessao (a sessao renova sozinha mais ou menos a cada hora enquanto
-- a tela esta aberta), com o e-mail da conta e o IP.
-- Nao altera nada.
-- =====================================================================


-- CONSULTA 1 - atividade de login entre 21:30 e 00:30 (Manaus)
SELECT to_char(a.created_at AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI:SS') AS hora_manaus,
       a.payload->>'actor_username'                                         AS email,
       u.raw_user_meta_data->>'nome'                                        AS nome,
       a.payload->>'action'                                                 AS acao,
       a.ip_address                                                         AS ip
FROM auth.audit_log_entries a
LEFT JOIN auth.users u ON u.id::text = a.payload->>'actor_id'
WHERE a.created_at BETWEEN '2026-09-29 01:30:00+00' AND '2026-09-29 04:30:00+00'
ORDER BY a.created_at;


-- CONSULTA 2 - sessoes que estavam vivas as 23:00 de 28/09
-- (criadas antes e renovadas depois das 22:00; "refreshed_at" = ultima renovacao)
SELECT u.email,
       u.raw_user_meta_data->>'nome'                                                AS nome,
       to_char(s.created_at   AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI')      AS sessao_aberta_em,
       to_char(s.refreshed_at AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI')      AS ultima_renovacao,
       s.user_agent,
       s.ip
FROM auth.sessions s
JOIN auth.users u ON u.id = s.user_id
WHERE s.created_at   <= '2026-09-29 03:07:00+00'
  AND coalesce(s.refreshed_at, s.updated_at) >= '2026-09-29 02:00:00+00'
ORDER BY ultima_renovacao;
