-- =====================================================================
-- SQL_DIAG_QUEM_LIBEROU_03NOV.sql  (03/11/2026)   SO LEITURA
--
-- As 6 emergencias da noite de 02/11 (PED-4041, 4045, 4048, 4049, 4050, 4054)
-- foram liberadas 01:12-01:15 e recebidas 01:15-01:17 de 03/11 (Manaus) pelo
-- login "Francisco Xavier". O horario do servidor confirma (nao e relogio de
-- aparelho errado). A loja diz que nao havia ninguem la a essa hora.
--
-- O login do Supabase registra cada entrada e renovacao de sessao com o IP e o
-- aparelho (user_agent). Comparando o IP da madrugada com o IP da loja durante o
-- dia, da para saber se foi feito de dentro da loja ou de fora.
-- Nao altera nada.
-- =====================================================================


-- CONSULTA 1 - toda atividade de login entre 00:00 e 02:30 de 03/11 (Manaus)
SELECT to_char(a.created_at AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI:SS') AS hora_manaus,
       a.payload->>'actor_username'                                         AS email,
       u.raw_user_meta_data->>'nome'                                        AS nome,
       a.payload->>'action'                                                 AS acao,
       a.ip_address                                                         AS ip
FROM auth.audit_log_entries a
LEFT JOIN auth.users u ON u.id::text = a.payload->>'actor_id'
WHERE a.created_at BETWEEN '2026-11-03 04:00:00+00' AND '2026-11-03 06:30:00+00'
ORDER BY a.created_at;


-- CONSULTA 2 - sessoes do Francisco vivas na madrugada, com aparelho e IP
SELECT u.email,
       u.raw_user_meta_data->>'nome'                                           AS nome,
       to_char(s.created_at   AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI') AS sessao_aberta_em,
       to_char(s.refreshed_at AT TIME ZONE 'America/Manaus', 'DD/MM HH24:MI') AS ultima_renovacao,
       s.user_agent,
       s.ip
FROM auth.sessions s
JOIN auth.users u ON u.id = s.user_id
WHERE (u.email ILIKE '%francisco%' OR u.raw_user_meta_data->>'nome' ILIKE '%francisco%')
  AND coalesce(s.refreshed_at, s.updated_at) >= '2026-11-02 12:00:00+00'
ORDER BY s.created_at;


-- CONSULTA 3 - IP da loja para comparar: logins de 02/11 e 03/11 durante o expediente
-- (o IP que mais aparece no horario da loja e o da internet da loja)
SELECT a.ip_address                              AS ip,
       COUNT(*)                                  AS registros,
       string_agg(DISTINCT a.payload->>'actor_username', ', ') AS contas
FROM auth.audit_log_entries a
WHERE a.created_at BETWEEN '2026-11-02 14:00:00+00' AND '2026-11-03 03:00:00+00'
GROUP BY a.ip_address
ORDER BY registros DESC;
