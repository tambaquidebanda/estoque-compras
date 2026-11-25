-- SQL_FOTOS_PENSERA.sql — fotos da Biblioteca de fotos do Pensêra no cadastro dos produtos
--
-- De onde vem: Pensêra › Marketing › Biblioteca de fotos (lida em 25/11/2026). Cada foto lá
-- está ligada a um ou mais IDs de produto do iComanda; o nosso pdv_map liga esse ID ao
-- cadastro (status 'mapeado'). Cruzamento só por ID, nunca por nome.
-- 91 IDs do iComanda, 58 fotos distintas.
--
-- A foto NÃO é copiada: o cadastro guarda o endereço. A maioria fica no site do restaurante
-- (tambaquidebanda.com.br) e o resto no Pensêra; os dois abrem sem login.
-- Só preenche produto SEM foto: foto já colocada à mão no cadastro não é trocada.
-- Precisa do SQL_PRECIFICACAO.sql já rodado (coluna foto_url).

-- ═══ PASSO 1 — CONFERIR (só leitura) ═══════════════════════════════════════════════
-- Lista o que vai receber foto e o que já tem foto (fica como está).
WITH fotos(ordem, icomanda_produto_id, url) AS (VALUES
  (1, 2899, 'https://pensera.chefsnbytes.com/api/marketing/photo-library/d60d588259853e8bd98405a686f205e9'),
  (2, 2900, 'https://pensera.chefsnbytes.com/api/marketing/photo-library/a220597ac9c4e5024e21af9d2b17e80f'),
  (3, 2889, 'https://pensera.chefsnbytes.com/api/product-photo/2889'),
  (4, 2892, 'https://pensera.chefsnbytes.com/api/product-photo/2892'),
  (5, 2891, 'https://pensera.chefsnbytes.com/api/product-photo/2891'),
  (6, 2894, 'https://pensera.chefsnbytes.com/api/product-photo/2894'),
  (7, 2887, 'https://pensera.chefsnbytes.com/api/product-photo/2887'),
  (8, 2800, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-1-5l.png'),
  (9, 2771, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-zero-1-5l.png'),
  (10, 73, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-zero-1-5l.png'),
  (11, 2206, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (12, 2423, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (13, 2439, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (14, 2711, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (15, 2773, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (16, 106, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (17, 1061, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (18, 2422, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (19, 911, 'https://pensera.chefsnbytes.com/assets/product_photos/guarana-antarctica-zero-350ml.png'),
  (20, 2081, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-350ml.png'),
  (21, 2772, 'https://pensera.chefsnbytes.com/assets/product_photos/guarana-antarctica-zero-2l.png'),
  (22, 177, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-zero-350ml.png'),
  (23, 13, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caboco-enrolado.webp'),
  (24, 2699, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caboco-enrolado.webp'),
  (25, 2737, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caboco-enrolado.webp'),
  (26, 2658, 'https://www.tambaquidebanda.com.br/assets/menu-photos/camarao-com-catupiry.webp'),
  (27, 1757, 'https://www.tambaquidebanda.com.br/assets/menu-photos/isca-crocante-de-pirarucu.webp'),
  (28, 2702, 'https://www.tambaquidebanda.com.br/assets/menu-photos/isca-crocante-de-pirarucu.webp'),
  (29, 588, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tacaca.webp'),
  (30, 1652, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caldinho-de-tambaqui.webp'),
  (31, 2627, 'https://www.tambaquidebanda.com.br/assets/menu-photos/legumes-salteados.webp'),
  (32, 209, 'https://www.tambaquidebanda.com.br/assets/menu-photos/moqueca-caboca.webp'),
  (33, 2390, 'https://www.tambaquidebanda.com.br/assets/menu-photos/moqueca-caboca.webp'),
  (34, 2200, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tambaqui-de-banda.webp'),
  (35, 2674, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tambaqui-de-banda.webp'),
  (36, 2710, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tambaqui-de-banda.webp'),
  (37, 23, 'https://www.tambaquidebanda.com.br/assets/menu-photos/matrinxa-de-casaca.webp'),
  (38, 1549, 'https://www.tambaquidebanda.com.br/assets/menu-photos/pirarucu-a-parmegiana.webp'),
  (39, 1809, 'https://www.tambaquidebanda.com.br/assets/menu-photos/pirarucu-a-parmegiana.webp'),
  (40, 2703, 'https://www.tambaquidebanda.com.br/assets/menu-photos/pirarucu-a-parmegiana.webp'),
  (41, 101, 'https://www.tambaquidebanda.com.br/assets/menu-photos/jaraqui-frito.webp'),
  (42, 646, 'https://www.tambaquidebanda.com.br/assets/menu-photos/moqueca-vegetariana.webp'),
  (43, 2561, 'https://www.tambaquidebanda.com.br/assets/menu-photos/juma.webp'),
  (44, 2555, 'https://www.tambaquidebanda.com.br/assets/menu-photos/canela-de-india.webp'),
  (45, 3150, 'https://www.tambaquidebanda.com.br/assets/menu-photos/canela-de-india.webp'),
  (46, 2952, 'https://www.tambaquidebanda.com.br/assets/menu-photos/paje.webp'),
  (47, 2564, 'https://www.tambaquidebanda.com.br/assets/menu-photos/ambucu-de-cana.webp'),
  (48, 2571, 'https://www.tambaquidebanda.com.br/assets/menu-photos/vitoria-regia.webp'),
  (49, 2556, 'https://www.tambaquidebanda.com.br/assets/menu-photos/iara.webp'),
  (50, 2573, 'https://www.tambaquidebanda.com.br/assets/menu-photos/amazonia-exotica.webp'),
  (51, 2570, 'https://www.tambaquidebanda.com.br/assets/menu-photos/uirapuru.webp'),
  (52, 2567, 'https://www.tambaquidebanda.com.br/assets/menu-photos/boto-cor-de-rosa.webp'),
  (53, 2563, 'https://www.tambaquidebanda.com.br/assets/menu-photos/cunhanta.webp'),
  (54, 2888, 'https://www.tambaquidebanda.com.br/assets/menu-photos/brahma-chopp.webp'),
  (55, 1207, 'https://www.tambaquidebanda.com.br/assets/menu-photos/la-passion.webp'),
  (56, 1375, 'https://www.tambaquidebanda.com.br/assets/menu-photos/aperol-spritz.webp'),
  (57, 2734, 'https://www.tambaquidebanda.com.br/assets/menu-photos/aperol-spritz.webp'),
  (58, 1417, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sangria.webp'),
  (59, 2890, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caipirinha.webp'),
  (60, 2487, 'https://www.tambaquidebanda.com.br/assets/menu-photos/soda-caprichoso.webp'),
  (61, 2486, 'https://www.tambaquidebanda.com.br/assets/menu-photos/soda-garantido.webp'),
  (62, 116, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (63, 1438, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (64, 2385, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (65, 2769, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (66, 2802, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (67, 1770, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/ceu-de-brigadeiro.webp'),
  (68, 1772, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/chocuca.webp'),
  (69, 1771, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/botacoco.webp'),
  (70, 2389, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/botacoco.webp'),
  (71, 122, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/petit-gateau.webp'),
  (72, 1205, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/petit-ganeau.webp'),
  (73, 124, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'),
  (74, 2770, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'),
  (75, 2788, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'),
  (76, 12, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/macaxeira-frita.webp'),
  (77, 3, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/batata-frita.webp'),
  (78, 2729, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/batata-frita.webp'),
  (79, 2855, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/batata-frita.webp'),
  (80, 2844, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-001.avif'),
  (81, 2912, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-001.avif'),
  (82, 2819, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-002.avif'),
  (83, 2909, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-002.avif'),
  (84, 2783, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-003.avif'),
  (85, 2822, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-004.avif'),
  (86, 2913, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-004.avif'),
  (87, 2945, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (88, 2959, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (89, 2940, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (90, 2941, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (91, 2942, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif')
),
alvo AS (
  -- um produto ligado a mais de um ID do iComanda fica com a foto que vem primeiro na lista
  SELECT DISTINCT ON (m.produto_id) m.produto_id, f.url, f.icomanda_produto_id
  FROM fotos f
  JOIN pdv_map m ON m.icomanda_produto_id = f.icomanda_produto_id
  WHERE m.status = 'mapeado' AND m.produto_id IS NOT NULL
  ORDER BY m.produto_id, f.ordem
)
SELECT p.nome,
       a.icomanda_produto_id AS id_icomanda,
       CASE WHEN coalesce(p.foto_url, '') = '' THEN 'vai receber' ELSE 'ja tem foto (fica)' END AS situacao,
       a.url
FROM alvo a
JOIN est_produtos p ON p.id = a.produto_id
ORDER BY situacao DESC, p.nome;

-- ═══ PASSO 2 — GRAVAR ══════════════════════════════════════════════════════════════
-- Mostra no fim quantos produtos receberam foto.
WITH fotos(ordem, icomanda_produto_id, url) AS (VALUES
  (1, 2899, 'https://pensera.chefsnbytes.com/api/marketing/photo-library/d60d588259853e8bd98405a686f205e9'),
  (2, 2900, 'https://pensera.chefsnbytes.com/api/marketing/photo-library/a220597ac9c4e5024e21af9d2b17e80f'),
  (3, 2889, 'https://pensera.chefsnbytes.com/api/product-photo/2889'),
  (4, 2892, 'https://pensera.chefsnbytes.com/api/product-photo/2892'),
  (5, 2891, 'https://pensera.chefsnbytes.com/api/product-photo/2891'),
  (6, 2894, 'https://pensera.chefsnbytes.com/api/product-photo/2894'),
  (7, 2887, 'https://pensera.chefsnbytes.com/api/product-photo/2887'),
  (8, 2800, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-1-5l.png'),
  (9, 2771, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-zero-1-5l.png'),
  (10, 73, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-zero-1-5l.png'),
  (11, 2206, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (12, 2423, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (13, 2439, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (14, 2711, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-1l.png'),
  (15, 2773, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (16, 106, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (17, 1061, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (18, 2422, 'https://pensera.chefsnbytes.com/assets/product_photos/bare-2l.png'),
  (19, 911, 'https://pensera.chefsnbytes.com/assets/product_photos/guarana-antarctica-zero-350ml.png'),
  (20, 2081, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-350ml.png'),
  (21, 2772, 'https://pensera.chefsnbytes.com/assets/product_photos/guarana-antarctica-zero-2l.png'),
  (22, 177, 'https://pensera.chefsnbytes.com/assets/product_photos/coca-cola-zero-350ml.png'),
  (23, 13, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caboco-enrolado.webp'),
  (24, 2699, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caboco-enrolado.webp'),
  (25, 2737, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caboco-enrolado.webp'),
  (26, 2658, 'https://www.tambaquidebanda.com.br/assets/menu-photos/camarao-com-catupiry.webp'),
  (27, 1757, 'https://www.tambaquidebanda.com.br/assets/menu-photos/isca-crocante-de-pirarucu.webp'),
  (28, 2702, 'https://www.tambaquidebanda.com.br/assets/menu-photos/isca-crocante-de-pirarucu.webp'),
  (29, 588, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tacaca.webp'),
  (30, 1652, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caldinho-de-tambaqui.webp'),
  (31, 2627, 'https://www.tambaquidebanda.com.br/assets/menu-photos/legumes-salteados.webp'),
  (32, 209, 'https://www.tambaquidebanda.com.br/assets/menu-photos/moqueca-caboca.webp'),
  (33, 2390, 'https://www.tambaquidebanda.com.br/assets/menu-photos/moqueca-caboca.webp'),
  (34, 2200, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tambaqui-de-banda.webp'),
  (35, 2674, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tambaqui-de-banda.webp'),
  (36, 2710, 'https://www.tambaquidebanda.com.br/assets/menu-photos/tambaqui-de-banda.webp'),
  (37, 23, 'https://www.tambaquidebanda.com.br/assets/menu-photos/matrinxa-de-casaca.webp'),
  (38, 1549, 'https://www.tambaquidebanda.com.br/assets/menu-photos/pirarucu-a-parmegiana.webp'),
  (39, 1809, 'https://www.tambaquidebanda.com.br/assets/menu-photos/pirarucu-a-parmegiana.webp'),
  (40, 2703, 'https://www.tambaquidebanda.com.br/assets/menu-photos/pirarucu-a-parmegiana.webp'),
  (41, 101, 'https://www.tambaquidebanda.com.br/assets/menu-photos/jaraqui-frito.webp'),
  (42, 646, 'https://www.tambaquidebanda.com.br/assets/menu-photos/moqueca-vegetariana.webp'),
  (43, 2561, 'https://www.tambaquidebanda.com.br/assets/menu-photos/juma.webp'),
  (44, 2555, 'https://www.tambaquidebanda.com.br/assets/menu-photos/canela-de-india.webp'),
  (45, 3150, 'https://www.tambaquidebanda.com.br/assets/menu-photos/canela-de-india.webp'),
  (46, 2952, 'https://www.tambaquidebanda.com.br/assets/menu-photos/paje.webp'),
  (47, 2564, 'https://www.tambaquidebanda.com.br/assets/menu-photos/ambucu-de-cana.webp'),
  (48, 2571, 'https://www.tambaquidebanda.com.br/assets/menu-photos/vitoria-regia.webp'),
  (49, 2556, 'https://www.tambaquidebanda.com.br/assets/menu-photos/iara.webp'),
  (50, 2573, 'https://www.tambaquidebanda.com.br/assets/menu-photos/amazonia-exotica.webp'),
  (51, 2570, 'https://www.tambaquidebanda.com.br/assets/menu-photos/uirapuru.webp'),
  (52, 2567, 'https://www.tambaquidebanda.com.br/assets/menu-photos/boto-cor-de-rosa.webp'),
  (53, 2563, 'https://www.tambaquidebanda.com.br/assets/menu-photos/cunhanta.webp'),
  (54, 2888, 'https://www.tambaquidebanda.com.br/assets/menu-photos/brahma-chopp.webp'),
  (55, 1207, 'https://www.tambaquidebanda.com.br/assets/menu-photos/la-passion.webp'),
  (56, 1375, 'https://www.tambaquidebanda.com.br/assets/menu-photos/aperol-spritz.webp'),
  (57, 2734, 'https://www.tambaquidebanda.com.br/assets/menu-photos/aperol-spritz.webp'),
  (58, 1417, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sangria.webp'),
  (59, 2890, 'https://www.tambaquidebanda.com.br/assets/menu-photos/caipirinha.webp'),
  (60, 2487, 'https://www.tambaquidebanda.com.br/assets/menu-photos/soda-caprichoso.webp'),
  (61, 2486, 'https://www.tambaquidebanda.com.br/assets/menu-photos/soda-garantido.webp'),
  (62, 116, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (63, 1438, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (64, 2385, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (65, 2769, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (66, 2802, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/banana-frita.webp'),
  (67, 1770, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/ceu-de-brigadeiro.webp'),
  (68, 1772, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/chocuca.webp'),
  (69, 1771, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/botacoco.webp'),
  (70, 2389, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/botacoco.webp'),
  (71, 122, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/petit-gateau.webp'),
  (72, 1205, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/petit-ganeau.webp'),
  (73, 124, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'),
  (74, 2770, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'),
  (75, 2788, 'https://www.tambaquidebanda.com.br/assets/menu-photos/sobremesas-2026/pudim-de-leite.webp'),
  (76, 12, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/macaxeira-frita.webp'),
  (77, 3, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/batata-frita.webp'),
  (78, 2729, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/batata-frita.webp'),
  (79, 2855, 'https://www.tambaquidebanda.com.br/assets/menu-photos/happy-2026/batata-frita.webp'),
  (80, 2844, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-001.avif'),
  (81, 2912, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-001.avif'),
  (82, 2819, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-002.avif'),
  (83, 2909, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-002.avif'),
  (84, 2783, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-003.avif'),
  (85, 2822, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-004.avif'),
  (86, 2913, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-004.avif'),
  (87, 2945, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (88, 2959, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (89, 2940, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (90, 2941, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif'),
  (91, 2942, 'https://pensera.chefsnbytes.com/assets/frango_menu/fdb-005.avif')
),
alvo AS (
  -- um produto ligado a mais de um ID do iComanda fica com a foto que vem primeiro na lista
  SELECT DISTINCT ON (m.produto_id) m.produto_id, f.url, f.icomanda_produto_id
  FROM fotos f
  JOIN pdv_map m ON m.icomanda_produto_id = f.icomanda_produto_id
  WHERE m.status = 'mapeado' AND m.produto_id IS NOT NULL
  ORDER BY m.produto_id, f.ordem
),
gravados AS (
  UPDATE est_produtos p
     SET foto_url = a.url
    FROM alvo a
   WHERE p.id = a.produto_id
     AND coalesce(p.foto_url, '') = ''
  RETURNING p.id
)
SELECT count(*) AS produtos_com_foto_nova FROM gravados;
