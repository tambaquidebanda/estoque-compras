-- Refaz o rateio (plano x unidade) de 9 contas do comprador externo pelo que foi RECEBIDO.
-- A conta ja tem o valor certo; o rateio ficou o do PEDIDO (o recebimento nao refazia - consertado no 20dee9f).
-- #01836 FORA: o rateio antigo tinha R$ 80 da Roteros e o recebimento lancou tudo no Teatro (decidir a parte).
-- Trava: cada bloco so roda se o valor da conta e a soma do rateio ainda forem os conferidos em 06/11/2026;
-- se algo mudou, o ASSERT para tudo e nada e gravado.
-- Rateio antigo de cada conta esta no comentario de cada bloco (para desfazer, se precisar).
BEGIN;

-- ===== PENDENTES (ainda nao pagas) =====
-- #02018  conta 943.83 (pendente)  rateio hoje 1022.70 -> 943.83
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|-|912.7; 1895e819-da86-4762-94f6-0b5b1fb0aea2|-|110.0
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='4d7ac53b-9fa1-49d9-b87f-2fda56c0fe82') = 943.83 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='4d7ac53b-9fa1-49d9-b87f-2fda56c0fe82') = 1022.70, '#02018 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='4d7ac53b-9fa1-49d9-b87f-2fda56c0fe82';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('4d7ac53b-9fa1-49d9-b87f-2fda56c0fe82','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,832.83,''),
  ('4d7ac53b-9fa1-49d9-b87f-2fda56c0fe82','1895e819-da86-4762-94f6-0b5b1fb0aea2',NULL,111.00,'');

-- #02056  conta 216.73 (pendente)  rateio hoje 223.44 -> 216.73
--   antigo: 9940e98c-910c-4b82-895e-219adaa15029|-|28.49; 868a859c-829b-44b1-8a21-87dbf45d10ff|-|194.95
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='37ea0c75-3aef-47ed-929b-8b1d5946c870') = 216.73 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='37ea0c75-3aef-47ed-929b-8b1d5946c870') = 223.44, '#02056 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='37ea0c75-3aef-47ed-929b-8b1d5946c870';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('37ea0c75-3aef-47ed-929b-8b1d5946c870','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,181.55,''),
  ('37ea0c75-3aef-47ed-929b-8b1d5946c870','9940e98c-910c-4b82-895e-219adaa15029',NULL,35.18,'');

-- ===== JA PAGAS (mudam a DRE de outubro por categoria; o total nao muda) =====
-- #01735  conta 919.41 (pago)  rateio hoje 1037.84 -> 919.41
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|-|876.84; d919422a-0467-402c-872d-0f10ec4fc255|-|45.0; 1895e819-da86-4762-94f6-0b5b1fb0aea2|-|116.0
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='b5aea16b-de84-4533-91f2-553cfd02acae') = 919.41 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='b5aea16b-de84-4533-91f2-553cfd02acae') = 1037.84, '#01735 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='b5aea16b-de84-4533-91f2-553cfd02acae';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('b5aea16b-de84-4533-91f2-553cfd02acae','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,763.41,''),
  ('b5aea16b-de84-4533-91f2-553cfd02acae','d919422a-0467-402c-872d-0f10ec4fc255',NULL,45.00,''),
  ('b5aea16b-de84-4533-91f2-553cfd02acae','1895e819-da86-4762-94f6-0b5b1fb0aea2',NULL,111.00,'');

-- #01739  conta 94.87 (pago)  rateio hoje 94.66 -> 94.87
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|e031eced-0652-4af0-ad2a-13b65a29f814|84.68; 868a859c-829b-44b1-8a21-87dbf45d10ff|6696a0dc-71f9-4a98-bdb4-42d9dd989cb1|9.98
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='25d9d288-8f64-4efd-a510-4f64fc681715') = 94.87 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='25d9d288-8f64-4efd-a510-4f64fc681715') = 94.66, '#01739 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='25d9d288-8f64-4efd-a510-4f64fc681715';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('25d9d288-8f64-4efd-a510-4f64fc681715','868a859c-829b-44b1-8a21-87dbf45d10ff','e031eced-0652-4af0-ad2a-13b65a29f814',83.87,''),
  ('25d9d288-8f64-4efd-a510-4f64fc681715','868a859c-829b-44b1-8a21-87dbf45d10ff','6696a0dc-71f9-4a98-bdb4-42d9dd989cb1',11.00,'');

-- #01828  conta 129.31 (pago)  rateio hoje 129.11 -> 129.31
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|-|104.61; 3a66ff73-eb28-4332-ae55-5dfa363ba02b|-|24.5
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='2717c861-cf98-40bd-9131-ae1164d01ace') = 129.31 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='2717c861-cf98-40bd-9131-ae1164d01ace') = 129.11, '#01828 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='2717c861-cf98-40bd-9131-ae1164d01ace';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('2717c861-cf98-40bd-9131-ae1164d01ace','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,104.81,''),
  ('2717c861-cf98-40bd-9131-ae1164d01ace','3a66ff73-eb28-4332-ae55-5dfa363ba02b',NULL,24.50,'');

-- #01858  conta 305.16 (pago)  rateio hoje 342.00 -> 305.16
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|-|298.0; 9940e98c-910c-4b82-895e-219adaa15029|-|44.0
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='ccab34a7-5c4f-454a-95e1-0512b573cc29') = 305.16 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='ccab34a7-5c4f-454a-95e1-0512b573cc29') = 342.00, '#01858 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='ccab34a7-5c4f-454a-95e1-0512b573cc29';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('ccab34a7-5c4f-454a-95e1-0512b573cc29','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,265.16,''),
  ('ccab34a7-5c4f-454a-95e1-0512b573cc29','9940e98c-910c-4b82-895e-219adaa15029',NULL,40.00,'');

-- #01923  conta 395.25 (pago)  rateio hoje 376.55 -> 395.25
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|e031eced-0652-4af0-ad2a-13b65a29f814|164.07; 868a859c-829b-44b1-8a21-87dbf45d10ff|6696a0dc-71f9-4a98-bdb4-42d9dd989cb1|9.98; 9940e98c-910c-4b82-895e-219adaa15029|e031eced-0652-4af0-ad2a-13b65a29f814|178.0; 3a66ff73-eb28-4332-ae55-5dfa363ba02b|e031eced-0652-4af0-ad2a-13b65a29f814|24.5
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='feda2f29-b430-4db0-9b4c-455fe6f8025f') = 395.25 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='feda2f29-b430-4db0-9b4c-455fe6f8025f') = 376.55, '#01923 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='feda2f29-b430-4db0-9b4c-455fe6f8025f';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('feda2f29-b430-4db0-9b4c-455fe6f8025f','868a859c-829b-44b1-8a21-87dbf45d10ff','e031eced-0652-4af0-ad2a-13b65a29f814',150.40,''),
  ('feda2f29-b430-4db0-9b4c-455fe6f8025f','3a66ff73-eb28-4332-ae55-5dfa363ba02b','e031eced-0652-4af0-ad2a-13b65a29f814',24.50,''),
  ('feda2f29-b430-4db0-9b4c-455fe6f8025f','9940e98c-910c-4b82-895e-219adaa15029','e031eced-0652-4af0-ad2a-13b65a29f814',207.34,''),
  ('feda2f29-b430-4db0-9b4c-455fe6f8025f','868a859c-829b-44b1-8a21-87dbf45d10ff','6696a0dc-71f9-4a98-bdb4-42d9dd989cb1',13.01,'');

-- #01929  conta 1057.67 (pago)  rateio hoje 1257.30 -> 1057.67
--   antigo: 868a859c-829b-44b1-8a21-87dbf45d10ff|-|1052.3; 1895e819-da86-4762-94f6-0b5b1fb0aea2|-|116.0; d919422a-0467-402c-872d-0f10ec4fc255|-|45.0; 9940e98c-910c-4b82-895e-219adaa15029|-|44.0
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='fed0dc85-8a8c-4148-bbe5-aaeb550f536b') = 1057.67 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='fed0dc85-8a8c-4148-bbe5-aaeb550f536b') = 1257.30, '#01929 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='fed0dc85-8a8c-4148-bbe5-aaeb550f536b';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('fed0dc85-8a8c-4148-bbe5-aaeb550f536b','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,862.69,''),
  ('fed0dc85-8a8c-4148-bbe5-aaeb550f536b','9940e98c-910c-4b82-895e-219adaa15029',NULL,39.98,''),
  ('fed0dc85-8a8c-4148-bbe5-aaeb550f536b','1895e819-da86-4762-94f6-0b5b1fb0aea2',NULL,110.00,''),
  ('fed0dc85-8a8c-4148-bbe5-aaeb550f536b','d919422a-0467-402c-872d-0f10ec4fc255',NULL,45.00,'');

-- #01948  conta 82.11 (pago)  rateio hoje 83.96 -> 82.11
--   antigo: 9940e98c-910c-4b82-895e-219adaa15029|-|35.96; 868a859c-829b-44b1-8a21-87dbf45d10ff|-|48.0
DO $$ BEGIN ASSERT (SELECT valor FROM lancamentos WHERE id='219b8a72-3fda-4a46-985c-136c4560037c') = 82.11 AND (SELECT round(sum(valor)::numeric,2) FROM rateio_itens WHERE lancamento_id='219b8a72-3fda-4a46-985c-136c4560037c') = 83.96, '#01948 mudou desde a conferencia'; END $$;
DELETE FROM rateio_itens WHERE lancamento_id='219b8a72-3fda-4a46-985c-136c4560037c';
INSERT INTO rateio_itens (lancamento_id,plano_conta_id,unidade_id,valor,descricao) VALUES
  ('219b8a72-3fda-4a46-985c-136c4560037c','868a859c-829b-44b1-8a21-87dbf45d10ff',NULL,46.47,''),
  ('219b8a72-3fda-4a46-985c-136c4560037c','9940e98c-910c-4b82-895e-219adaa15029',NULL,35.64,'');

-- Conferencia: soma do rateio = valor da conta em todas
SELECT l.numero_pedido, l.valor, round(sum(r.valor)::numeric,2) AS rateio, count(*) AS linhas
FROM lancamentos l JOIN rateio_itens r ON r.lancamento_id=l.id
WHERE l.id IN ('b5aea16b-de84-4533-91f2-553cfd02acae','25d9d288-8f64-4efd-a510-4f64fc681715','2717c861-cf98-40bd-9131-ae1164d01ace','ccab34a7-5c4f-454a-95e1-0512b573cc29','feda2f29-b430-4db0-9b4c-455fe6f8025f','fed0dc85-8a8c-4148-bbe5-aaeb550f536b','219b8a72-3fda-4a46-985c-136c4560037c','4d7ac53b-9fa1-49d9-b87f-2fda56c0fe82','37ea0c75-3aef-47ed-929b-8b1d5946c870')
GROUP BY 1,2 ORDER BY 1;

COMMIT;