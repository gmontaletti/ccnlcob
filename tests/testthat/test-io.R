# Test di read_rapporti() e write_results() (R/io.R). Fase 4 e Fase 5.

# 1. Fixture -----

percorso_fst <- tempfile(fileext = ".fst")
cob <- .carica_dataset("cob_esempio")
cpi_lookup <- .carica_dataset("cpi_esempio")
res <- analyze_ccnl(cob, lookup_cpi = cpi_lookup, min_n = 10)

# Directory temporanea per test, rimossa all'uscita dal test chiamante.
.dir_temporanea <- function(env = parent.frame()) {
  d <- tempfile("ccnlcob_")
  dir.create(d, recursive = TRUE)
  eval(substitute(on.exit(unlink(d, recursive = TRUE), add = TRUE)), envir = env)
  d
}

.senza_attributi <- function(x) {
  x <- data.table::as.data.table(x)
  for (a in grep("^ccnlcob_", names(attributes(x)), value = TRUE)) {
    data.table::setattr(x, a, NULL)
  }
  x
}

.file_attesi <- c(
  "meta.rds",
  "ranking.rds",
  "ranking_periodo.rds",
  "rilevanti.rds",
  "keys.rds",
  "cpi.fst",
  "tipologie.fst",
  "retribuzioni.rds",
  "qualita.rds"
)

# 2. Stub -----

test_that("read_rapporti() segnala che la funzione non è ancora implementata", {
  expect_error(read_rapporti(percorso_fst), "non ancora implementata")
})

# 3. write_results() -----

test_that("write_results() crea la directory e scrive i file del contratto di uscita", {
  d <- file.path(.dir_temporanea(), "sotto", "ccnl")
  expect_false(dir.exists(d))
  manifesto <- write_results(res, dir = d)
  expect_true(dir.exists(d))
  expect_identical(sort(list.files(d)), sort(.file_attesi))
  expect_true(data.table::is.data.table(manifesto))
  expect_named(manifesto, c("oggetto", "file", "formato", "righe", "byte"))
  expect_identical(manifesto$oggetto, sub("[.].*$", "", .file_attesi))
  expect_identical(basename(manifesto$file), .file_attesi)
  expect_identical(manifesto$formato, sub("^.*[.]", "", .file_attesi))
  expect_true(all(file.exists(manifesto$file)))
  expect_true(all(manifesto$byte > 0))
  expect_identical(manifesto[oggetto == "ranking", righe], nrow(res$ranking))
  expect_true(is.na(manifesto[oggetto == "meta", righe]))
  expect_true(is.na(manifesto[oggetto == "keys", righe]))
})

test_that("write_results() restituisce il manifesto invisibilmente", {
  d <- .dir_temporanea()
  expect_invisible(write_results(res, dir = d))
})

test_that("i file RDS riletti coincidono con le tabelle in memoria", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  for (nm in c(
    "ranking",
    "ranking_periodo",
    "rilevanti",
    "retribuzioni",
    "qualita"
  )) {
    riletto <- readRDS(file.path(d, paste0(nm, ".rds")))
    expect_equal(riletto, res[[nm]], info = nm)
  }
  expect_identical(readRDS(file.path(d, "keys.rds")), res$keys)
})

test_that("i file FST riletti coincidono con i cubi a meno degli attributi", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  for (nm in c("cpi", "tipologie")) {
    riletto <- fst::read_fst(
      file.path(d, paste0(nm, ".fst")),
      as.data.table = TRUE
    )
    expect_equal(riletto, .senza_attributi(res[[nm]]), info = nm)
  }
})

test_that("meta.rds conserva i metadati, gli attributi delle tabelle e il manifesto", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  meta <- readRDS(file.path(d, "meta.rds"))
  for (nm in names(res$meta)) {
    expect_identical(meta[[nm]], res$meta[[nm]], info = nm)
  }
  expect_identical(
    names(meta$attributi),
    c(
      "ranking",
      "ranking_periodo",
      "rilevanti",
      "cpi",
      "tipologie",
      "retribuzioni",
      "qualita"
    )
  )
  expect_identical(
    meta$attributi$cpi$ccnlcob_crosstab,
    attr(res$cpi, "ccnlcob_crosstab")
  )
  expect_identical(
    meta$attributi$ranking$ccnlcob_ranking,
    attr(res$ranking, "ccnlcob_ranking")
  )
  expect_identical(meta$oggetti_assenti, character(0))
  expect_identical(meta$file$file, .file_attesi)
  # gli attributi permettono di ricostruire il cubo
  cubo <- fst::read_fst(file.path(d, "cpi.fst"), as.data.table = TRUE)
  for (a in names(meta$attributi$cpi)) {
    data.table::setattr(cubo, a, meta$attributi$cpi[[a]])
  }
  expect_equal(cubo, res$cpi)
})

test_that("write_results() salta gli elementi NULL e li elenca in meta", {
  parziale <- analyze_ccnl(
    cob[, !c("retribuzione", "comune_sede_lavoro")],
    min_n = 10
  )
  d <- .dir_temporanea()
  manifesto <- write_results(parziale, dir = d)
  expect_false(any(c("cpi.fst", "retribuzioni.rds") %in% list.files(d)))
  expect_identical(
    sort(list.files(d)),
    sort(setdiff(.file_attesi, c("cpi.fst", "retribuzioni.rds")))
  )
  expect_false(any(c("cpi", "retribuzioni") %in% manifesto$oggetto))
  meta <- readRDS(file.path(d, "meta.rds"))
  expect_identical(meta$oggetti_assenti, c("cpi", "retribuzioni"))
  expect_false("cpi" %in% names(meta$attributi))
})

test_that("overwrite = FALSE ferma la scrittura su file esistenti, TRUE la consente", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  prima <- file.mtime(file.path(d, "ranking.rds"))
  expect_error(write_results(res, dir = d), "overwrite = TRUE")
  expect_error(write_results(res, dir = d), "ranking.rds")
  Sys.sleep(1.1)
  manifesto <- write_results(res, dir = d, overwrite = TRUE)
  expect_true(file.mtime(file.path(d, "ranking.rds")) > prima)
  expect_identical(nrow(manifesto), length(.file_attesi))
})

test_that("write_results() rispetta formats personalizzati; meta e keys restano RDS", {
  d <- .dir_temporanea()
  manifesto <- write_results(
    res,
    dir = d,
    formats = c(cube = "rds", small = "fst")
  )
  attesi <- c(
    "meta.rds",
    "ranking.fst",
    "ranking_periodo.fst",
    "rilevanti.fst",
    "keys.rds",
    "cpi.rds",
    "tipologie.rds",
    "retribuzioni.fst",
    "qualita.fst"
  )
  expect_identical(sort(list.files(d)), sort(attesi))
  expect_identical(basename(manifesto$file), attesi)
  expect_equal(readRDS(file.path(d, "cpi.rds")), res$cpi)
  riletto <- fst::read_fst(file.path(d, "ranking.fst"), as.data.table = TRUE)
  expect_equal(riletto, .senza_attributi(res$ranking))
})

test_that("write_results() rifiuta input non validi", {
  d <- .dir_temporanea()
  expect_error(write_results(list(meta = list()), dir = d), "ccnlcob_result")
  expect_error(write_results(res, dir = c(d, d)), "percorso")
  expect_error(
    write_results(res, dir = d, formats = c(small = "csv", cube = "fst")),
    "csv"
  )
  expect_error(write_results(res, dir = d, formats = c("rds", "fst")), "small")
  expect_error(write_results(res, dir = d, overwrite = NA), "overwrite")
  expect_identical(list.files(d), character(0))
})
