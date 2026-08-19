-- =============================================================
-- est_fichas_tecnicas: desativar as 50 fichas ATIVAS DUPLICADAS
-- 17 produtos tinham mais de uma ficha ativa. Nenhuma tela mostra
-- isso: a lista indexa por produto (ultima vence) e a aba do produto
-- pega fichas[0] sem ORDER BY. O robo pega a ultima. Ou seja, tela e
-- robo podiam estar lendo fichas diferentes do mesmo produto.
--
-- NAO apaga: marca ativo = false. Reversivel e preserva historico.
-- Os ingredientes (est_ficha_ingredientes) ficam intactos.
--
-- Escolha do que MANTER:
--   PPP RUB DO FRANGO DE BANDA -> a de rendimento 0,85 (a que aparece na tela)
--   PPC BATATONESE             -> a de 3 ingredientes, R$ 11,21 (a que aparece na tela)
--   demais 15                  -> copias identicas entre si; mantida a mais antiga
-- =============================================================


-- PASSO 1: conferir o estado atual. Rode so este SELECT.

select p.nome, count(*) as fichas_ativas
  from est_fichas_tecnicas f
  join est_produtos p on p.id = f.produto_id
 where f.ativo
 group by p.nome
having count(*) > 1
 order by count(*) desc;


-- PASSO 2: desativar as 50 duplicadas (lista explicita de IDs).

update est_fichas_tecnicas
   set ativo = false
 where id in (
   '50aba8da-f61b-4740-8618-8d46da0ee5e5',
   '044b2efa-512a-42d2-a3a9-3ca6ded54d8e',
   '00e757bb-7d81-4c07-a4a3-a9384fdca34c',
   '6da56ec7-f9cd-4680-90a4-96319c0bafaf',
   'e04f19ba-da8d-442a-a27f-332d70a27c78',
   'ccbe0a48-0f2a-4f18-929b-72aa8830026c',
   '0521e696-5d74-449e-8aed-5380710c6d55',
   '96a1ddc5-6fcf-4fdb-a7d9-9322fc78c034',
   '34970e81-ffe1-444b-860a-e826d883df73',
   'f1fbad36-42c2-4e6c-8dc0-35918bd2472a',
   '7621788c-d005-46ef-a783-b5433c1ff286',
   'e3dc5db7-dd90-47b5-8b96-f4948b97345a',
   '99900aa7-17fe-48cc-8fc0-64bbf6c90fb1',
   'ad91a0da-9be3-42c3-a55b-1652de9cc501',
   '72698f74-5c14-4eb5-b02c-c5489d8fd139',
   'f8a6fb3e-080d-420f-b939-3e6df5aa82f0',
   'a5c83ef2-fe33-4948-98e9-18204f25becf',
   'cd80880e-a1d9-4d9b-828e-b428bfc2a9f1',
   '86da72e7-9405-4756-a93e-7fb49fe661e4',
   'adc54e17-46d1-4174-b204-dfc477178fa8',
   'd6458f12-eec9-4e80-8dfd-66b295b6365f',
   'c512d0cb-61e9-48db-bd20-4e1040d407e2',
   'a123278b-d3e5-4bb1-bc3b-1e3b6b45f09a',
   '450cfe78-546d-4f84-9f6a-f664958e0e52',
   '980f5ca5-d978-4496-996e-fd1975dfed3b',
   '9a585d91-d083-4567-ac2c-9adb0aa1bf44',
   '888dd5d4-55cf-4182-8f41-1434727d34dc',
   '5584056e-3960-46e3-afd6-7309f6dc1a7b',
   '77e26ca5-0508-42be-aecc-52745bbed98e',
   '9e1026ba-e51e-4e27-a375-78df83a57534',
   'd1d98da3-1801-4ac9-b992-89d4965e97d0',
   'a3d32c86-bab3-42a6-a405-c6eb78fa8602',
   '83a2fcde-f83e-4127-96d3-d7a375e0411b',
   '10d35b1f-cb0a-4913-ac0f-e59c5433a8d7',
   '6950db52-ee8a-4cde-8d0b-984e14919f95',
   '9308ba36-36b0-4927-821c-dd67911ce066',
   '6c3ddac5-afa5-47e3-aea0-17ab2d4b97b3',
   'a33c9a53-062b-4e85-9b33-d29ac9d1b027',
   'b389d6aa-6734-4bda-95a1-00c687307008',
   '8a2bc976-f5cd-4c4b-a93d-4cf57689a0a5',
   '631a1f27-1acf-4928-aecf-0e0f6fa8e8a5',
   '64556fa6-cb04-4770-b866-db3b7e80aee4',
   'd059f3fa-ee4f-450e-891f-65175a5fd340',
   '4c5cd055-99c5-4131-a308-b3ff943d7962',
   'f1bfc7cf-115e-490c-95da-7fbdb3d7a9cb',
   'a07de6fe-cf5c-4328-95f4-cc86b27dbf6d',
   '2886ba54-c33e-4e6e-a963-5890523bed49',
   '9ba0ccf1-e328-46d1-9389-795b8ad6e211',
   '581f8034-5ba3-4b39-bb9f-6920cebf2efa',
   '444eda97-bc20-4334-9f20-518c03e1a413'
 );

-- PASSO 3: conferir. O SELECT do passo 1 deve voltar ZERO linhas.
-- E o total de fichas ativas deve cair de 579 para 529.

select count(*) as fichas_ativas from est_fichas_tecnicas where ativo;


-- PASSO 4: travar para nao voltar a acontecer.
-- So funciona depois do passo 2; com duplicata no banco, falha.

create unique index if not exists uniq_ficha_ativa_por_produto
  on est_fichas_tecnicas (produto_id) where ativo;
