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
  expect_equal(res$value, dt)
  expect_true("giornate" %in% names(dt))
  expect_type(dt$giornate, "integer")
  expect_false(inherits(dt$giornate, "difftime"))
})

test_that("compute_giornate() taglia alla finestra: 0 fuori, intera durata dentro, parte interna a cavallo", {
  dt <- compute_giornate(.rapporti(), window = .w2023)
  expect_equal(dt$giornate, c(31L, 28L, 31L, 0L, 0L, 365L))
})

test_that("compute_giornate() con window = NULL conta l'intera durata del rapporto", {
  dt <- compute_giornate(.rapporti())
  attese <- as.integer(dt$fine - dt$inizio) + 1L
  expect_equal(dt$giornate, attese)
  expect_equal(dt$giornate[2L], 28L)
})

test_that("compute_giornate() accetta la finestra come stringhe e sovrascrive una colonna esistente", {
  dt <- .rapporti()
  compute_giornate(dt)
  prima <- data.table::copy(dt$giornate)
  compute_giornate(dt, window = c("2023-01-01", "2023-12-31"))
  expect_false(identical(dt$giornate, prima))
  expect_equal(dt$giornate, c(31L, 28L, 31L, 0L, 0L, 365L))
})

test_that("compute_giornate() lavora su IDate e su un giorno singolo", {
  dt <- .rapporti()[, `:=`(
    inizio = data.table::as.IDate(inizio),
    fine = data.table::as.IDate(fine)
  )]
  compute_giornate(dt, window = .w2023)
  expect_type(dt$giornate, "integer")
  expect_equal(dt$giornate, c(31L, 28L, 31L, 0L, 0L, 365L))

  uno <- data.table::data.table(
    inizio = as.Date("2023-05-05"),
    fine = as.Date("2023-05-05")
  )
  compute_giornate(uno, window = .w2023)
  expect_equal(uno$giornate, 1L)
  compute_giornate(uno, window = as.Date(c("2023-05-05", "2023-05-05")))
  expect_equal(uno$giornate, 1L)
})

test_that("compute_giornate() restituisce 0 se fine < inizio e NA su date mancanti", {
  dt <- data.table::data.table(
    inizio = as.Date(c("2023-05-10", "2023-05-10", NA)),
    fine = as.Date(c("2023-05-01", NA, "2023-05-20"))
  )
  compute_giornate(dt)
  expect_equal(dt$giornate, c(0L, NA_integer_, NA_integer_))
})

test_that("compute_giornate() sulla fixture preparata coincide con fine - inizio + 1 nella finestra", {
  dt <- prepare_rapporti(data.table::copy(fixture))
  w <- as.Date(c("2021-01-01", "2021-12-31"))
  compute_giornate(dt, window = w)
  attese <- pmax(
    0L,
    as.integer(pmin(dt$fine, w[2L]) - pmax(dt$inizio, w[1L])) + 1L
  )
  expect_equal(dt$giornate, attese)
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

# 3. compute_giornate_effettive() -----

# Unione degli intervalli (giorni-persona occupati) calcolata in modo
# indipendente, per persona.
.giorni_unione <- function(dt, window = NULL) {
  inizio <- as.integer(dt$inizio)
  fine <- as.integer(dt$fine)
  if (!is.null(window)) {
    inizio <- pmax(inizio, as.integer(window[1L]))
    fine <- pmin(fine, as.integer(window[2L]))
  }
  ok <- fine >= inizio
  giorni <- Map(seq, inizio[ok], fine[ok])
  data.table::data.table(cf = dt$cf[ok], giorni = giorni)[
    ,
    .(unione = length(unique(unlist(giorni)))),
    by = cf
  ]
}

test_that("compute_giornate_effettive() ripartisce a meta' i 6 giorni di sovrapposizione fra due rapporti", {
  dt <- data.table::data.table(
    id = 1:2,
    cf = "A",
    inizio = as.Date(c("2023-01-01", "2023-01-10")),
    fine = as.Date(c("2023-01-15", "2023-01-20"))
  )
  out <- compute_giornate_effettive(dt)
  expect_equal(out, dt)
  # rapporto 1: 9 giorni esclusivi (1-9) + 6/2; rapporto 2: 5 esclusivi (16-20) + 6/2
  expect_equal(dt$giornate_effettive, c(9 + 3, 5 + 3))
  expect_type(dt$giornate_effettive, "double")
  expect_equal(sum(dt$giornate_effettive), 20)
  info <- attr(dt, "ccnlcob_giornate_effettive")
  expect_named(
    info,
    c(
      "window",
      "n_persone_sovrapposizioni",
      "giornate_totali",
      "giornate_effettive_totali"
    )
  )
  expect_null(info$window)
  expect_equal(info$n_persone_sovrapposizioni, 1L)
  expect_equal(info$giornate_totali, 15 + 11)
  expect_equal(info$giornate_effettive_totali, 20)
})

test_that("compute_giornate_effettive() con tre rapporti concorrenti alloca 1/3 nel tratto comune", {
  dt <- data.table::data.table(
    id = 1:3,
    cf = "A",
    inizio = as.Date(c("2023-01-01", "2023-01-05", "2023-01-08")),
    fine = as.Date(c("2023-01-10", "2023-01-12", "2023-01-09"))
  )
  compute_giornate_effettive(dt)
  # segmenti: 1-4 (arco 1), 5-7 (arco 2), 8-9 (arco 3), 10 (arco 2), 11-12 (arco 1)
  expect_equal(
    dt$giornate_effettive,
    c(4 + 3 / 2 + 2 / 3 + 1 / 2, 3 / 2 + 2 / 3 + 1 / 2 + 2, 2 / 3)
  )
  expect_equal(sum(dt$giornate_effettive), 12)
})

test_that("compute_giornate_effettive() assegna meta' a ciascuno di due intervalli identici", {
  dt <- data.table::data.table(
    id = 1:2,
    cf = "A",
    inizio = as.Date("2023-03-01"),
    fine = as.Date("2023-03-10")
  )
  compute_giornate_effettive(dt)
  expect_equal(dt$giornate_effettive, c(5, 5))
})

test_that("compute_giornate_effettive() non toglie nulla a intervalli contigui o a persone diverse", {
  dt <- data.table::data.table(
    id = 1:4,
    cf = c("A", "A", "B", "C"),
    inizio = as.Date(c("2023-01-01", "2023-01-11", "2023-01-05", "2023-01-05")),
    fine = as.Date(c("2023-01-10", "2023-01-20", "2023-01-09", "2023-01-09"))
  )
  compute_giornate(dt)
  compute_giornate_effettive(dt)
  expect_equal(dt$giornate_effettive, as.numeric(dt$giornate))
  expect_equal(
    attr(dt, "ccnlcob_giornate_effettive")$n_persone_sovrapposizioni,
    0L
  )
})

test_that("compute_giornate_effettive() taglia alla finestra e azzera i rapporti esterni", {
  dt <- data.table::data.table(
    id = 1:3,
    cf = "A",
    inizio = as.Date(c("2022-12-01", "2023-01-10", "2024-02-01")),
    fine = as.Date(c("2023-01-31", "2023-02-10", "2024-03-01"))
  )
  compute_giornate_effettive(dt, window = .w2023)
  # in finestra: 1-31 gennaio e 10 gen-10 feb; sovrapposti 10-31 gennaio (22 giorni)
  expect_equal(dt$giornate_effettive, c(9 + 11, 11 + 10, 0))
  expect_equal(sum(dt$giornate_effettive), 41)
  info <- attr(dt, "ccnlcob_giornate_effettive")
  expect_equal(info$window, .w2023)
  expect_equal(info$giornate_totali, 31 + 32)
})

test_that("compute_giornate_effettive() accetta la finestra come stringhe e restituisce NA su date mancanti", {
  dt <- data.table::data.table(
    id = 1:3,
    cf = c("A", "A", "B"),
    inizio = as.Date(c("2023-01-01", "2023-01-10", NA)),
    fine = as.Date(c("2023-01-15", "2023-01-20", "2023-02-01"))
  )
  compute_giornate_effettive(dt, window = c("2023-01-01", "2023-12-31"))
  expect_equal(dt$giornate_effettive[1:2], c(12, 8))
  expect_true(is.na(dt$giornate_effettive[3]))
})

test_that("compute_giornate_effettive() tratta i cf mancanti come persone isolate", {
  dt <- data.table::data.table(
    id = 1:2,
    cf = NA_character_,
    inizio = as.Date("2023-01-01"),
    fine = as.Date("2023-01-10")
  )
  compute_giornate_effettive(dt)
  expect_equal(dt$giornate_effettive, c(10, 10))
})

test_that("compute_giornate_effettive() modifica per riferimento, sovrascrive e lavora su IDate", {
  dt <- data.table::data.table(
    id = 1:2,
    cf = "A",
    inizio = data.table::as.IDate(c("2023-01-01", "2023-01-10")),
    fine = data.table::as.IDate(c("2023-01-15", "2023-01-20")),
    giornate_effettive = -1
  )
  alias <- dt
  out <- compute_giornate_effettive(dt)
  expect_equal(alias$giornate_effettive, c(12, 8))
  expect_true(inherits(dt$inizio, "IDate"))
  expect_invisible(compute_giornate_effettive(dt))
})

test_that("compute_giornate_effettive() rispetta l'invariante dei giorni-persona sulla fixture", {
  dt <- prepare_rapporti(fixture)
  w <- attr(dt, "ccnlcob_meta")$window
  compute_giornate_effettive(dt, window = w)
  eff <- dt[, .(effettive = sum(giornate_effettive)), by = cf]
  unione <- .giorni_unione(dt, window = w)
  confronto <- merge(eff, unione, by = "cf")
  expect_equal(nrow(confronto), nrow(eff))
  expect_equal(confronto$effettive, as.numeric(confronto$unione))
  expect_true(all(dt$giornate_effettive <= dt$giornate + 1e-9))
  # persone con un solo rapporto: nessuna riallocazione
  singoli <- dt[, .N, by = cf][N == 1L, cf]
  expect_equal(
    dt[cf %in% singoli, giornate_effettive],
    as.numeric(dt[cf %in% singoli, giornate])
  )
  info <- attr(dt, "ccnlcob_giornate_effettive")
  expect_equal(info$giornate_totali, sum(dt$giornate))
  expect_equal(info$giornate_effettive_totali, sum(unione$unione))
  expect_true(info$n_persone_sovrapposizioni <= data.table::uniqueN(dt$cf))
})

test_that("compute_giornate_effettive() e' additivo rispetto alla misura di rank_ccnl()", {
  dt <- prepare_rapporti(fixture)
  compute_giornate_effettive(dt, window = attr(dt, "ccnlcob_meta")$window)
  rk <- rank_ccnl(dt, measures = c("giornate", "giornate_effettive"))
  expect_equal(sum(rk$giornate_effettive), sum(dt$giornate_effettive))
  expect_true(all(rk$giornate_effettive <= rk$giornate + 1e-9))
})

test_that("compute_giornate_effettive() rifiuta input non validi", {
  df <- data.frame(id = 1L, cf = "A", inizio = Sys.Date(), fine = Sys.Date())
  expect_error(compute_giornate_effettive(df), "data.table")
  dt <- data.table::data.table(id = 1L, inizio = Sys.Date(), fine = Sys.Date())
  expect_error(compute_giornate_effettive(dt), "Colonne mancanti: cf")
  dt <- data.table::data.table(
    id = 1L,
    cf = "A",
    inizio = "2023-01-01",
    fine = Sys.Date()
  )
  expect_error(compute_giornate_effettive(dt), "classe Date")
  dt <- data.table::data.table(
    id = 1L,
    cf = "A",
    inizio = Sys.Date(),
    fine = Sys.Date()
  )
  expect_error(
    compute_giornate_effettive(dt, window = as.Date("2023-01-01")),
    "due date"
  )
  expect_error(
    compute_giornate_effettive(dt, window = as.Date(c("2023-12-31", "2023-01-01"))),
    "ordinata"
  )
})

test_that("compute_giornate_effettive() coincide con i totali per persona di vecshift", {
  skip_if_not_installed("vecshift")
  dt <- prepare_rapporti(fixture)
  compute_giornate_effettive(dt)
  eff <- dt[, .(effettive = sum(giornate_effettive)), by = cf]
  seg <- data.table::as.data.table(
    vecshift::vecshift(dt[, .(id, cf, inizio, fine, prior)])
  )
  vs <- seg[arco > 0, .(vecshift = sum(as.numeric(durata))), by = cf]
  confronto <- merge(eff, vs, by = "cf")
  expect_identical(nrow(confronto), nrow(eff))
  expect_equal(confronto$effettive, confronto$vecshift)
})

test_that("compute_giornate_effettive() elabora cob_esempio in tempi contenuti", {
  cob <- .carica_dataset("cob_esempio")
  dt <- prepare_rapporti(cob)
  tempo <- system.time(
    compute_giornate_effettive(dt, window = attr(dt, "ccnlcob_meta")$window)
  )[["elapsed"]]
  expect_lt(tempo, 5)
  expect_false(anyNA(dt$giornate_effettive))
  expect_true(attr(dt, "ccnlcob_giornate_effettive")$n_persone_sovrapposizioni > 0L)
})
