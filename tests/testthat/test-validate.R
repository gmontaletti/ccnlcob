# Test di validate_rapporti() (R/validate.R).

# 1. Fixture -----

fixture <- generate_cob_sintetico(n_persone = 60, n_rapporti = 400, n_ccnl = 8, seed = 1)

.senza <- function(colonne) {
  data.table::copy(fixture)[, (colonne) := NULL]
}

# 2. Comportamento atteso -----

test_that("validate_rapporti() accetta la fixture sintetica e la restituisce invisibilmente", {
  dt <- data.table::copy(fixture)
  res <- withVisible(validate_rapporti(dt, require = "base"))
  expect_false(res$visible)
  expect_identical(res$value, dt)
})

test_that("validate_rapporti() accetta inizio e fine di classe IDate", {
  dt <- data.table::copy(fixture)
  dt[, `:=`(inizio = data.table::as.IDate(inizio), fine = data.table::as.IDate(fine))]
  expect_no_error(validate_rapporti(dt, require = "base"))
})

test_that("validate_rapporti() accetta una sola chiave CCNL fra codice_cnel e ccnl", {
  expect_no_error(validate_rapporti(.senza("ccnl"), require = "base"))
  expect_no_error(validate_rapporti(.senza("codice_cnel"), require = "base"))
})

test_that("require = c('base', 'cpi') passa sulla fixture completa", {
  expect_no_error(validate_rapporti(data.table::copy(fixture), require = c("base", "cpi")))
  expect_no_error(validate_rapporti(
    data.table::copy(fixture),
    require = c("base", "cpi", "retribuzione", "datore")
  ))
})

# 3. Errori -----

test_that("validate_rapporti() rifiuta oggetti che non sono data.table e suggerisce setDT", {
  expect_error(validate_rapporti(as.data.frame(fixture), require = "base"), "setDT")
  expect_error(validate_rapporti(list(id = 1L), require = "base"), "setDT")
  expect_error(validate_rapporti(NULL, require = "base"), "setDT")
})

test_that("validate_rapporti() elenca le colonne mancanti", {
  dt <- .senza(c("cf", "prior"))
  expect_error(validate_rapporti(dt, require = "base"), "Colonne mancanti")
  expect_error(validate_rapporti(dt, require = "base"), "\\bcf\\b")
  expect_error(validate_rapporti(dt, require = "base"), "\\bprior\\b")
})

test_that("validate_rapporti() richiede almeno una chiave CCNL", {
  expect_error(validate_rapporti(.senza(c("codice_cnel", "ccnl")), require = "base"))
})

test_that("validate_rapporti() richiede inizio e fine di classe Date", {
  dt <- data.table::copy(fixture)[, inizio := as.character(inizio)]
  expect_error(validate_rapporti(dt, require = "base"), "inizio")
  dt <- data.table::copy(fixture)[, fine := as.numeric(fine)]
  expect_error(validate_rapporti(dt, require = "base"), "fine")
})

test_that("require = 'cpi' richiede comune_sede_lavoro", {
  expect_error(
    validate_rapporti(.senza("comune_sede_lavoro"), require = "cpi"),
    "comune_sede_lavoro"
  )
  expect_error(validate_rapporti(.senza("comune_sede_lavoro"), require = c("base", "cpi")))
})

test_that("require = 'retribuzione' richiede retribuzione e ore", {
  expect_error(
    validate_rapporti(.senza("retribuzione"), require = "retribuzione"),
    "retribuzione"
  )
  expect_error(validate_rapporti(.senza("ore"), require = "retribuzione"), "\\bore\\b")
})

test_that("require = 'datore' richiede datore", {
  expect_error(validate_rapporti(.senza("datore"), require = "datore"), "datore")
})

test_that("un valore di require non ammesso produce errore", {
  expect_error(validate_rapporti(data.table::copy(fixture), require = "territorio"), "non ammessi")
  expect_error(validate_rapporti(data.table::copy(fixture), require = c("base", "xyz")), "non ammessi")
  expect_error(validate_rapporti(data.table::copy(fixture), require = c("base", "retribuzioni")), "non ammessi")
  expect_error(validate_rapporti(data.table::copy(fixture), require = character(0)))
  expect_error(validate_rapporti(data.table::copy(fixture), require = NULL))
})
