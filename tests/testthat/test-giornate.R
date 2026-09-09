# Test di compute_giornate() e compute_giornate_effettive() (R/giornate.R).
# Fase 1 (giornate) e Fase 4 (giornate effettive con vecshift).

# 1. Fixture -----

fixture <- generate_cob_sintetico(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
)

# Rapporti senza sentinelle, con casi a cavallo della finestra 2023.
.rapporti <- function() {
  data.table::data.table(
    id = 1:6,
    inizio = as.Date(c(
      "2022-11-01", # a cavallo dell'inizio finestra
      "2023-02-01", # interamente dentro
      "2023-12-01", # a cavallo della fine finestra
      "2022-01-01", # interamente prima
      "2024-03-01", # interamente dopo
      "2022-06-01" # copre l'intera finestra
    )),
    fine = as.Date(c(
      "2023-01-31",
      "2023-02-28",
      "2024-01-31",
      "2022-06-30",
      "2024-04-30",
      "2024-12-31"
    ))
  )
}

.w2023 <- as.Date(c("2023-01-01", "2023-12-31"))

# 2. compute_giornate() -----

test_that("compute_giornate() aggiunge giornate per riferimento e restituisce dt invisibilmente", {
  dt <- .rapporti()
  res <- withVisible(compute_giornate(dt, window = .w2023))
  expect_false(res$visible)
  expect_identical(res$value, dt)
  expect_true("giornate" %in% names(dt))
  expect_type(dt$giornate, "integer")
  expect_false(inherits(dt$giornate, "difftime"))
})

test_that("compute_giornate() taglia alla finestra: 0 fuori, intera durata dentro, parte interna a cavallo", {
  dt <- compute_giornate(.rapporti(), window = .w2023)
  expect_identical(dt$giornate, c(31L, 28L, 31L, 0L, 0L, 365L))
})

test_that("compute_giornate() con window = NULL conta l'intera durata del rapporto", {
  dt <- compute_giornate(.rapporti())
  attese <- as.integer(dt$fine - dt$inizio) + 1L
  expect_identical(dt$giornate, attese)
  expect_identical(dt$giornate[2L], 28L)
})

test_that("compute_giornate() accetta la finestra come stringhe e sovrascrive una colonna esistente", {
  dt <- .rapporti()
  compute_giornate(dt)
  prima <- data.table::copy(dt$giornate)
  compute_giornate(dt, window = c("2023-01-01", "2023-12-31"))
  expect_false(identical(dt$giornate, prima))
  expect_identical(dt$giornate, c(31L, 28L, 31L, 0L, 0L, 365L))
})

test_that("compute_giornate() lavora su IDate e su un giorno singolo", {
  dt <- .rapporti()[, `:=`(
    inizio = data.table::as.IDate(inizio),
    fine = data.table::as.IDate(fine)
  )]
  compute_giornate(dt, window = .w2023)
  expect_type(dt$giornate, "integer")
  expect_identical(dt$giornate, c(31L, 28L, 31L, 0L, 0L, 365L))

  uno <- data.table::data.table(
    inizio = as.Date("2023-05-05"),
    fine = as.Date("2023-05-05")
  )
  compute_giornate(uno, window = .w2023)
  expect_identical(uno$giornate, 1L)
  compute_giornate(uno, window = as.Date(c("2023-05-05", "2023-05-05")))
  expect_identical(uno$giornate, 1L)
})

test_that("compute_giornate() restituisce 0 se fine < inizio e NA su date mancanti", {
  dt <- data.table::data.table(
    inizio = as.Date(c("2023-05-10", "2023-05-10", NA)),
    fine = as.Date(c("2023-05-01", NA, "2023-05-20"))
  )
  compute_giornate(dt)
  expect_identical(dt$giornate, c(0L, NA_integer_, NA_integer_))
})

test_that("compute_giornate() sulla fixture preparata coincide con fine - inizio + 1 nella finestra", {
  dt <- prepare_rapporti(data.table::copy(fixture))
  w <- as.Date(c("2021-01-01", "2021-12-31"))
  compute_giornate(dt, window = w)
  attese <- pmax(
    0L,
    as.integer(pmin(dt$fine, w[2L]) - pmax(dt$inizio, w[1L])) + 1L
  )
  expect_identical(dt$giornate, attese)
  expect_true(any(dt$giornate == 0L))
  expect_true(all(dt$giornate <= 365L))
})

test_that("compute_giornate() rifiuta input non validi", {
  expect_error(compute_giornate(as.data.frame(.rapporti())), "setDT")
  expect_error(compute_giornate(.rapporti()[, fine := NULL]), "fine")
  expect_error(
    compute_giornate(.rapporti()[, inizio := as.character(inizio)]),
    "Date"
  )
  expect_error(
    compute_giornate(
      .rapporti(),
      window = as.Date(c("2023-12-31", "2023-01-01"))
    ),
    "ordinata"
  )
  expect_error(
    compute_giornate(.rapporti(), window = as.Date("2023-01-01")),
    "due date"
  )
  expect_error(
    compute_giornate(.rapporti(), window = c(19000, 19365)),
    "due date"
  )
  expect_error(
    compute_giornate(.rapporti(), window = c("2023-01-01", NA)),
    "valid"
  )
})

# 3. Stub -----

test_that("compute_giornate_effettive() segnala che la funzione non è ancora implementata", {
  expect_error(
    compute_giornate_effettive(data.table::copy(fixture)),
    "non ancora implementata"
  )
})

# TODO Fase 4 (compute_giornate_effettive):
# - `sum(giornate_effettive)` per `cf` uguale ai giorni-persona occupati,
#   calcolati indipendentemente con `seq` di date (unione degli intervalli)
# - due rapporti identici e sovrapposti: metà giornate ciascuno (1/`arco`)
# - rapporto isolato: `giornate_effettive == giornate`
# - `skip_if_not_installed("vecshift")` sui test che chiamano vecshift
# - coerenza con `compute_giornate()` quando non ci sono sovrapposizioni
