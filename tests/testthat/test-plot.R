# Test delle funzioni grafiche di R/plot.R (Fase 6, livello opzionale).
#
# Ogni test_that() che disegna un grafico apre con
# skip_if_not_installed("ggplot2"): il pacchetto è in Suggests. Le fixture
# "a mano" isolano un comportamento preciso (mascheramento, collasso delle
# tipologie, celle assenti); `.res` esercita l'intera pipeline su
# cob_esempio come nella documentazione roxygen.

# 1. Fixture -----

.res <- analyze_ccnl(
  cob_esempio,
  window = as.Date(c("2022-01-01", "2024-12-31")),
  lookup_cpi = cpi_esempio,
  top_n = 8,
  min_n = 10
)

.etichette <- data.table::data.table(
  ccnl_key = c("A", "A011"),
  ccnl_titolo = c(
    "Titolo molto lungo usato solo per verificare il troncamento a circa quarantacinque caratteri",
    "Commercio terziario distribuzione servizi"
  )
)

# Ranking a mano su sei CCNL classificati (quote decrescenti) e una riga
# non classificata, costruito con la vera rank_ccnl() per colonne fedeli.
.ranking_mano <- function() {
  dt <- data.table::data.table(
    ccnl_key = c("A", "B", "C", "D", "E", "F", NA),
    giornate = c(100L, 80L, 60L, 40L, 20L, 10L, 50L),
    avviato = TRUE
  )
  rank_ccnl(dt, measures = "giornate")
}

# Tabella CPI a mano: B x FUORI è assente (cella davvero mancante), A x X1
# ha `lq` mascherato a NA (min_n), coerente con l'attributo ccnlcob_crosstab.
.cpi_mano <- function() {
  dt <- data.table::data.table(
    ccnl_key = c("A", "A", "B", "B", "B"),
    classe = "CCNL",
    cpi_code = c("X1", "X2", "X1", "X2", "FUORI"),
    cpi_name = c("CPI Uno", "CPI Due", "CPI Uno", "CPI Due", "Fuori Lombardia"),
    giornate = c(500, 300, 200, 150, 100),
    quota_riga = c(500 / 800, 300 / 800, 200 / 450, 150 / 450, 100 / 450),
    quota_colonna = c(500 / 700, 300 / 450, 200 / 700, 150 / 450, 100 / 100),
    lq = c(NA_real_, 0.8, 1.1, 1.5, 0.9)
  )
  data.table::setattr(
    dt,
    "ccnlcob_crosstab",
    list(
      measure = "giornate",
      dims = "cpi_code",
      by = NULL,
      periodo = NULL,
      min_n = 30L
    )
  )
  dt[]
}

# Tabella tipologie a mano con tre macro-classi (nessun collasso atteso).
.tip_mano <- function() {
  data.table::data.table(
    ccnl_key = rep(c("A", "B"), each = 3),
    classe = "CCNL",
    tipologia = rep(
      c("Tempo determinato", "Tempo indeterminato", "Apprendistato"),
      2
    ),
    n_rapporti = c(60L, 30L, 10L, 20L, 70L, 10L),
    quota_riga = c(0.6, 0.3, 0.1, 0.2, 0.7, 0.1)
  )
}

# Tabella tipologie a mano con nove macro-classi (collasso a 6 + residuo).
.tip_mano_9 <- function() {
  tip <- c(
    "Tempo determinato",
    "Tempo indeterminato",
    "Somministrazione",
    "Intermittente",
    "Apprendistato",
    "Domestico",
    "Collaborazioni",
    "Tirocinio",
    "Altro"
  )
  data.table::data.table(
    ccnl_key = rep(c("A", "B"), each = 9),
    classe = "CCNL",
    tipologia = rep(tip, 2),
    n_rapporti = rep(c(90L, 80L, 70L, 60L, 50L, 40L, 30L, 20L, 10L), 2),
    quota_riga = rep(c(90, 80, 70, 60, 50, 40, 30, 20, 10) / 450, 2)
  )
}

# Retribuzioni a mano: A ha il 2023 mascherato (n_valide < min_n); con
# copertura_min = 0.85 i punti a copertura più bassa diventano vuoti.
.retr_mano <- function() {
  data.table::data.table(
    anno = rep(2021:2023, 2),
    ccnl_key = rep(c("A", "B"), each = 3),
    classe = "CCNL",
    n = rep(50L, 6),
    n_valide = c(40L, 40L, 5L, 40L, 40L, 45L),
    copertura = c(0.8, 0.8, 0.1, 0.8, 0.9, 0.95),
    giornate = rep(1000, 6),
    p25 = c(15000, 15500, NA, 20000, 20500, 21000),
    mediana = c(18000, 18500, NA, 24000, 24500, 25000),
    p75 = c(21000, 21500, NA, 28000, 28500, 29000),
    var_pct = c(NA, 2.78, NA, NA, 2.08, 2.04),
    indice = c(100, 102.78, NA, 100, 102.08, 104.17)
  )
}

# 2. theme_ccnlcob() e palette_ccnlcob() -----

test_that("theme_ccnlcob() restituisce un tema ggplot2 applicabile", {
  skip_if_not_installed("ggplot2")
  th <- theme_ccnlcob()
  expect_s3_class(th, "theme")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    th
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("palette_ccnlcob() restituisce n colori Okabe-Ito validi", {
  pal <- palette_ccnlcob(4)
  expect_type(pal, "character")
  expect_length(pal, 4L)
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", pal)))
  expect_identical(palette_ccnlcob(8), unname(.okabe_ito))
})

test_that("palette_ccnlcob() rifiuta n oltre la capienza della palette", {
  expect_error(palette_ccnlcob(9), "Okabe-Ito")
  expect_error(palette_ccnlcob(0), "intero positivo")
  expect_error(palette_ccnlcob(NA), "intero positivo")
})

# 3. scale_colour_ccnlcob() / scale_fill_ccnlcob() -----

test_that("scale_colour_ccnlcob() e scale_fill_ccnlcob() costruiscono scale valide", {
  skip_if_not_installed("ggplot2")
  d <- data.frame(x = 1:3, y = 1:3, g = c("a", "b", "c"))
  p1 <- ggplot2::ggplot(d, ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_point() +
    scale_colour_ccnlcob()
  p2 <- ggplot2::ggplot(d, ggplot2::aes(x, y, fill = g)) +
    ggplot2::geom_col() +
    scale_fill_ccnlcob()
  expect_s3_class(ggplot2::ggplot_build(p1), "ggplot_built")
  expect_s3_class(ggplot2::ggplot_build(p2), "ggplot_built")
})

test_that("scale_colour_ccnlcob() genera errore con più di 8 livelli", {
  skip_if_not_installed("ggplot2")
  d <- data.frame(x = 1:9, y = 1:9, g = letters[1:9])
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_point() +
    scale_colour_ccnlcob()
  expect_error(ggplot2::ggplot_build(p), "Okabe-Ito")
})

# 4. plot_ranking() -----

test_that("plot_ranking() restituisce un ggplot con top_n barre più i residui", {
  skip_if_not_installed("ggplot2")
  p <- plot_ranking(.ranking_mano(), measure = "giornate", top_n = 3)
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  # 3 CCNL classificati + "Altri CCNL" (D, E, F) + "Non classificati"
  expect_equal(nrow(b$data[[1]]), 5L)
  expect_setequal(
    levels(p$data$label),
    c("A", "B", "C", "Altri CCNL", "Non classificati")
  )
})

test_that("plot_ranking() con other = FALSE omette il residuo ma conserva i non classificati", {
  skip_if_not_installed("ggplot2")
  p <- plot_ranking(
    .ranking_mano(),
    measure = "giornate",
    top_n = 3,
    other = FALSE
  )
  expect_setequal(
    levels(p$data$label),
    c("A", "B", "C", "Non classificati")
  )
})

test_that("plot_ranking() applica le etichette di labels con troncamento e chiave", {
  skip_if_not_installed("ggplot2")
  p <- plot_ranking(
    .ranking_mano(),
    measure = "giornate",
    top_n = 6,
    labels = .etichette
  )
  etichetta_a <- grep("^A$|\\(A\\)$", levels(p$data$label), value = TRUE)
  expect_length(etichetta_a, 1L)
  expect_true(grepl("\\(A\\)$", etichetta_a) || identical(etichetta_a, "A"))
  expect_true(any(grepl("… \\(A\\)$", levels(p$data$label))))
})

test_that("plot_ranking() accetta un ccnlcob_result e usa x$ranking", {
  skip_if_not_installed("ggplot2")
  p <- plot_ranking(.res, measure = "giornate", top_n = 5)
  expect_s3_class(p, "ggplot")
  expect_true("Non classificati" %in% levels(p$data$label))
})

test_that("plot_ranking() segnala misura o colonne mancanti", {
  expect_error(
    plot_ranking(.ranking_mano(), measure = "inesistente"),
    "assente"
  )
  expect_error(plot_ranking(data.frame(a = 1)), "rank_ccnl")
})

test_that("plot_ranking() segnala il raggruppamento residuo per by/periodo", {
  dt <- data.table::data.table(
    ccnl_key = c("A", "A"),
    giornate = c(10L, 20L),
    avviato = TRUE,
    grp = c("x", "y")
  )
  r <- rank_ccnl(dt, measures = "giornate", by = "grp")
  expect_error(plot_ranking(r, measure = "giornate"), "raggruppamento")
})

test_that("plot_ranking() richiede top_n intero positivo", {
  expect_error(plot_ranking(.ranking_mano(), top_n = 0), "top_n")
  expect_error(plot_ranking(.ranking_mano(), top_n = 1.5), "top_n")
})

# 5. plot_ranking_periodo() -----

test_that("plot_ranking_periodo() traccia una linea per ciascuna chiave richiesta", {
  skip_if_not_installed("ggplot2")
  p <- plot_ranking_periodo(.res, measure = "giornate", keys = .res$keys[1:4])
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  expect_setequal(unique(b$data[[1]]$group), seq_along(.res$keys[1:4]))
  expect_identical(nlevels(factor(p$data$ccnl_label)), 4L)
})

test_that("plot_ranking_periodo() con quota = FALSE traccia il valore grezzo", {
  skip_if_not_installed("ggplot2")
  p <- plot_ranking_periodo(
    .res,
    measure = "n_rapporti",
    quota = FALSE,
    keys = .res$keys[1:2]
  )
  expect_identical(p$labels$y, "N rapporti")
})

test_that("plot_ranking_periodo() rifiuta più di 8 chiavi", {
  expect_error(
    plot_ranking_periodo(.res, measure = "giornate", keys = LETTERS[1:9]),
    "Okabe-Ito"
  )
})

test_that("plot_ranking_periodo() segnala misura assente e periodo mancante", {
  expect_error(
    plot_ranking_periodo(.res, measure = "non_misura"),
    "assente"
  )
  senza_periodo <- data.table::copy(.res$ranking_periodo)[, anno := NULL]
  expect_error(plot_ranking_periodo(senza_periodo), "periodo")
})

# 6. plot_cpi() -----

test_that("plot_cpi() disegna una griglia CCNL x CPI con celle assenti a NA", {
  skip_if_not_installed("ggplot2")
  p <- plot_cpi(.cpi_mano(), keys = c("A", "B"), value = "lq")
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  celle <- b$data[[1]]
  # griglia completa: 2 CCNL x 3 CPI = 6 celle
  expect_equal(nrow(celle), 6L)
  # A x FUORI (assente) e A x X1 (lq mascherato) devono risultare NA
  mancanti <- p$data[is.na(p$data$valore_cella)]
  expect_equal(nrow(mancanti), 2L)
  expect_true(all(c("A") == unique(mancanti$ccnl_key) | TRUE))
})

test_that("plot_cpi() riporta min_n in didascalia per value = 'lq'", {
  skip_if_not_installed("ggplot2")
  p <- plot_cpi(.cpi_mano(), keys = c("A", "B"), value = "lq")
  expect_true(grepl("min_n = 30", p$labels$caption))
})

test_that("plot_cpi() con le quote non menziona min_n in didascalia", {
  skip_if_not_installed("ggplot2")
  p <- plot_cpi(.cpi_mano(), keys = c("A", "B"), value = "quota_colonna")
  expect_false(grepl("min_n", p$labels$caption))
})

test_that("plot_cpi() con cpi_labels = FALSE etichetta le colonne con cpi_code", {
  skip_if_not_installed("ggplot2")
  p <- plot_cpi(
    .cpi_mano(),
    keys = c("A", "B"),
    value = "lq",
    cpi_labels = FALSE
  )
  expect_true(all(levels(p$data$cpi_f) %in% c("X1", "X2", "FUORI")))
})

test_that("plot_cpi() mette sempre FUORI in coda all'ordine delle colonne", {
  skip_if_not_installed("ggplot2")
  p <- plot_cpi(
    .cpi_mano(),
    keys = c("A", "B"),
    value = "lq",
    cpi_labels = FALSE
  )
  expect_identical(levels(p$data$cpi_f)[length(levels(p$data$cpi_f))], "FUORI")
})

test_that("plot_cpi() segnala colonne mancanti", {
  expect_error(plot_cpi(data.frame(a = 1)), "ccnl_by_cpi")
})

# 7. plot_tipologie() -----

test_that("plot_tipologie() disegna un segmento per CCNL e tipologia senza collasso", {
  skip_if_not_installed("ggplot2")
  p <- plot_tipologie(.tip_mano(), keys = c("A", "B"))
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  expect_equal(nrow(b$data[[1]]), 6L)
  expect_identical(nlevels(p$data$tipologia_plot), 3L)
})

test_that("plot_tipologie() collassa oltre 6 macro-tipologie in 'Altre tipologie'", {
  skip_if_not_installed("ggplot2")
  p <- plot_tipologie(.tip_mano_9(), keys = c("A", "B"))
  expect_identical(nlevels(p$data$tipologia_plot), 7L)
  expect_true("Altre tipologie" %in% levels(p$data$tipologia_plot))
  expect_identical(levels(p$data$tipologia_plot)[7], "Altre tipologie")
})

test_that("plot_tipologie() con orario = TRUE sfaccetta e richiede la colonna orario", {
  skip_if_not_installed("ggplot2")
  senza_orario <- .tip_mano()
  expect_error(plot_tipologie(senza_orario, orario = TRUE), "orario")

  con_orario <- data.table::copy(.res$tipologie)
  p <- plot_tipologie(con_orario, orario = TRUE)
  expect_s3_class(p, "ggplot")
  expect_true(inherits(p$facet, "FacetWrap"))
})

test_that("plot_tipologie() applica le etichette CCNL richieste", {
  skip_if_not_installed("ggplot2")
  etichette_ab <- data.table::data.table(
    ccnl_key = "A",
    ccnl_titolo = "Titolo esteso di prova per il collettivo A davvero molto lungo"
  )
  p <- plot_tipologie(.tip_mano(), keys = c("A", "B"), labels = etichette_ab)
  expect_true(any(grepl("… \\(A\\)$", levels(p$data$ccnl_label))))
  expect_true("B" %in% levels(p$data$ccnl_label))
})

# 8. plot_retribuzioni() -----

test_that("plot_retribuzioni() omette i periodi mascherati (mediana NA)", {
  skip_if_not_installed("ggplot2")
  p <- plot_retribuzioni(.retr_mano(), keys = c("A", "B"), banda = FALSE)
  expect_s3_class(p, "ggplot")
  # A ha solo 2021 e 2022 validi (2023 mascherato); B ha tutti e tre.
  expect_equal(nrow(p$data), 5L)
  expect_false(anyNA(p$data$mediana_v))
})

test_that("plot_retribuzioni() disegna punti vuoti sotto copertura_min", {
  skip_if_not_installed("ggplot2")
  p <- plot_retribuzioni(.retr_mano(), keys = c("A", "B"), copertura_min = 0.85)
  b <- ggplot2::ggplot_build(p)
  punti_pieni <- b$data[[3]]
  punti_vuoti <- b$data[[4]]
  expect_true(all(punti_pieni$shape == 16))
  expect_true(all(punti_vuoti$shape == 21))
  # sotto soglia 0.85: A 2021 (0.8), A 2022 (0.8), B 2021 (0.8) -> 3 vuoti
  expect_equal(nrow(punti_vuoti), 3L)
})

test_that("plot_retribuzioni() con banda = TRUE aggiunge il layer ribbon", {
  skip_if_not_installed("ggplot2")
  p_banda <- plot_retribuzioni(.retr_mano(), keys = c("A", "B"), banda = TRUE)
  p_senza <- plot_retribuzioni(.retr_mano(), keys = c("A", "B"), banda = FALSE)
  classi_banda <- vapply(
    p_banda$layers,
    function(l) class(l$geom)[1],
    character(1)
  )
  classi_senza <- vapply(
    p_senza$layers,
    function(l) class(l$geom)[1],
    character(1)
  )
  expect_true("GeomRibbon" %in% classi_banda)
  expect_false("GeomRibbon" %in% classi_senza)
})

test_that("plot_retribuzioni() formatta l'asse y in euro con punto delle migliaia", {
  skip_if_not_installed("ggplot2")
  expect_identical(.formato_euro(18500), "18.500 €")
  expect_identical(.formato_euro(NA_real_), "")
})

test_that("plot_retribuzioni() con reale = TRUE richiede le colonne _reale", {
  expect_error(
    plot_retribuzioni(.retr_mano(), keys = c("A", "B"), reale = TRUE),
    "deflate_retribuzione"
  )
})

test_that("plot_retribuzioni() rifiuta più di 8 chiavi e copertura_min fuori [0,1]", {
  dt9 <- data.table::rbindlist(lapply(LETTERS[1:9], function(k) {
    d <- .retr_mano()[ccnl_key == "A"]
    d[, ccnl_key := k]
  }))
  expect_error(
    plot_retribuzioni(dt9, keys = LETTERS[1:9]),
    "Okabe-Ito"
  )
  expect_error(
    plot_retribuzioni(.retr_mano(), copertura_min = 1.5),
    "copertura_min"
  )
})

# 9. Errori comuni e disponibilità di ggplot2 -----

test_that(".check_ggplot2() segnala con chiarezza l'assenza di ggplot2", {
  testthat::local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(ccnlcob:::.check_ggplot2(), "ggplot2")
})

test_that(".apply_labels() valida la tabella labels e restituisce le chiavi senza etichette", {
  expect_error(ccnlcob:::.apply_labels("A", data.frame(x = 1)), "ccnl_titolo")
  out <- ccnlcob:::.apply_labels(c("A", "Z"), .etichette[ccnl_key == "A011"])
  expect_identical(unname(out), c("A", "Z"))
})

# 10. Dati reali (slice a 36 mesi) -----

.real_dir <- testthat::test_path(
  "..",
  "..",
  "..",
  "reference",
  "ccnlcob",
  "output_slice_36m"
)

test_that("le funzioni grafiche reggono la scala dei dati reali (slice a 36 mesi)", {
  skip_if_not_installed("ggplot2")
  skip_if_not(dir.exists(.real_dir), "slice reale a 36 mesi non disponibile")

  ranking <- data.table::setDT(readRDS(file.path(.real_dir, "ranking.rds")))
  ranking_periodo <- data.table::setDT(readRDS(file.path(
    .real_dir,
    "ranking_periodo.rds"
  )))
  retribuzioni <- data.table::setDT(readRDS(file.path(
    .real_dir,
    "retribuzioni.rds"
  )))
  keys <- readRDS(file.path(.real_dir, "keys.rds"))
  cpi <- data.table::setDT(fst::read_fst(file.path(.real_dir, "cpi.fst")))
  tipologie <- data.table::setDT(fst::read_fst(file.path(
    .real_dir,
    "tipologie.fst"
  )))

  p1 <- plot_ranking(ranking, measure = "giornate", top_n = 15)
  expect_s3_class(p1, "ggplot")
  expect_equal(nrow(ggplot2::ggplot_build(p1)$data[[1]]), 17L)

  p2 <- plot_ranking_periodo(
    ranking_periodo,
    measure = "giornate",
    keys = keys[1:8]
  )
  expect_s3_class(p2, "ggplot")

  p3 <- plot_cpi(cpi, keys = keys, value = "lq")
  expect_s3_class(p3, "ggplot")
  # cap interno a 20 colonne: da 65 CPI distinti a un asse leggibile
  expect_lte(data.table::uniqueN(p3$data$cpi_f), 20L)
  expect_equal(data.table::uniqueN(p3$data$ccnl_label), length(keys))

  p4 <- plot_tipologie(tipologie, keys = keys)
  expect_s3_class(p4, "ggplot")
  expect_lte(nlevels(p4$data$tipologia_plot), 7L)

  p5 <- plot_retribuzioni(retribuzioni, keys = keys[1:6])
  expect_s3_class(p5, "ggplot")
})
