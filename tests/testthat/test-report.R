# Test di render_report() e del template Quarto (R/report.R).
#
# Il rendering vero richiede il pacchetto `quarto` e la Quarto CLI: quel
# test viene saltato quando mancano. I controlli sugli argomenti e sulle
# etichette non hanno dipendenze esterne.

# 1. Fixture -----

.dir_report <- function() {
  dir_out <- file.path(tempfile("ccnlcob_report_test_"), "out")
  res <- analyze_ccnl(
    cob_esempio,
    lookup_cpi = cpi_esempio,
    top_n = 8,
    min_n = 10
  )
  write_results(res, dir = dir_out, overwrite = TRUE)
  dir_out
}

.etichette_report <- data.table::data.table(
  ccnl_key = c("A011", "A011", "H011"),
  ccnl_titolo = c("Agricoltura operai", "Duplicato", "Terziario")
)

# 2. Template -----

test_that("il template Quarto è installato nel pacchetto", {
  tpl <- system.file("quarto", "report_ccnl.qmd", package = "ccnlcob")
  expect_true(nzchar(tpl))
  expect_true(file.exists(tpl))
  righe <- readLines(tpl, warn = FALSE)
  expect_true(any(grepl("^params:", righe)))
  expect_true(any(grepl("plot_ranking\\(", righe)))
  expect_true(any(grepl("embed-resources: true", righe)))
})

# 3. Controlli sugli argomenti -----

test_that("render_report() rifiuta una directory assente o incompleta", {
  expect_error(render_report(1), "`dir` deve essere")
  expect_error(render_report(tempfile("assente_")), "Directory non trovata")
  vuota <- tempfile("vuota_")
  dir.create(vuota)
  on.exit(unlink(vuota, recursive = TRUE), add = TRUE)
  expect_error(render_report(vuota), "meta.rds, ranking.rds")
  saveRDS(list(), file.path(vuota, "meta.rds"))
  expect_error(render_report(vuota), "ranking.rds")
})

test_that("render_report() verifica gli argomenti scalari", {
  dir_out <- tempfile("report_arg_")
  dir.create(dir_out)
  on.exit(unlink(dir_out, recursive = TRUE), add = TRUE)
  saveRDS(list(), file.path(dir_out, "meta.rds"))
  saveRDS(data.table::data.table(), file.path(dir_out, "ranking.rds"))
  expect_error(render_report(dir_out, output_file = 1), "`output_file`")
  expect_error(render_report(dir_out, titolo = c("a", "b")), "`titolo`")
  expect_error(render_report(dir_out, top_n = 0), "`top_n`")
  expect_error(render_report(dir_out, top_n = 2.5), "`top_n`")
  expect_error(render_report(dir_out, note = 1), "`note`")
  expect_error(render_report(dir_out, quiet = NA), "`quiet`")
})

test_that("render_report() rifiuta etichette non valide", {
  dir_out <- tempfile("report_lab_")
  dir.create(dir_out)
  on.exit(unlink(dir_out, recursive = TRUE), add = TRUE)
  saveRDS(list(), file.path(dir_out, "meta.rds"))
  saveRDS(data.table::data.table(), file.path(dir_out, "ranking.rds"))
  expect_error(render_report(dir_out, labels = 1), "`labels` deve essere")
  expect_error(
    render_report(dir_out, labels = tempfile(fileext = ".rds")),
    "non trovato"
  )
  expect_error(
    render_report(dir_out, labels = data.frame(x = 1)),
    "ccnl_key"
  )
})

test_that(".normalize_labels() accetta codice_cnel, RDS e deduplica", {
  out <- ccnlcob:::.normalize_labels(.etichette_report)
  expect_identical(names(out), c("ccnl_key", "ccnl_titolo"))
  expect_identical(out$ccnl_key, c("A011", "H011"))
  expect_identical(out$ccnl_titolo[1L], "Agricoltura operai")

  cnel <- data.frame(
    codice_cnel = c("A011", NA),
    ccnl_titolo = c("Agricoltura", "senza chiave"),
    perimetro = "x"
  )
  out_cnel <- ccnlcob:::.normalize_labels(cnel)
  expect_identical(out_cnel$ccnl_key, "A011")

  f <- tempfile(fileext = ".rds")
  saveRDS(cnel, f)
  on.exit(unlink(f), add = TRUE)
  expect_identical(ccnlcob:::.normalize_labels(f), out_cnel)
  expect_null(ccnlcob:::.normalize_labels(NULL))
})

# 4. Rendering -----

test_that("render_report() produce un HTML autonomo con le sezioni attese", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("knitr")
  skip_if(is.null(quarto::quarto_path()), "Quarto CLI non disponibile")
  skip_on_cran()

  dir_out <- .dir_report()
  on.exit(unlink(dirname(dir_out), recursive = TRUE), add = TRUE)
  html <- file.path(dirname(dir_out), "report_test.html")
  titolo <- "Report di prova ccnlcob"

  out <- render_report(
    dir_out,
    output_file = html,
    titolo = titolo,
    labels = .etichette_report,
    top_n = 6,
    note = "Nota di prova."
  )
  expect_identical(
    normalizePath(out, winslash = "/"),
    normalizePath(html, winslash = "/")
  )
  expect_true(file.exists(html))
  expect_gt(file.size(html), 50000)
  expect_true(is.numeric(attr(out, "secondi")))

  contenuto <- paste(
    readLines(html, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  expect_true(grepl(titolo, contenuto, fixed = TRUE))
  expect_true(grepl("Classifica", contenuto, fixed = TRUE))
  expect_true(grepl("CPI", contenuto, fixed = TRUE))
  expect_true(grepl("Retribuzioni", contenuto, fixed = TRUE))
  expect_true(grepl("Nota di prova.", contenuto, fixed = TRUE))
  expect_true(grepl("Agricoltura operai", contenuto, fixed = TRUE))
  # nessun file di lavoro lasciato accanto ai risultati
  expect_false(file.exists(file.path(dir_out, "report_ccnl.qmd")))
})
