# Test di prepare_rapporti() (R/prepare.R). Fase 1.

# 1. Fixture -----

fixture <- generate_cob_sintetico(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
)

.sent_min <- as.Date("1900-01-01")
.sent_max <- as.Date("9999-12-31")

# Tabella a 5 righe costruita a mano per avviato/attivo e finestra.
.mini <- function() {
  data.table::data.table(
    id = 1:5,
    cf = c("A", "B", "C", "D", "E"),
    inizio = as.Date(c(
      "2022-06-01", # prima della finestra, termina dentro
      "2023-03-01", # interamente dentro, chiuso prima di as_of
      "2023-10-01", # dentro, aperto ad as_of
      "2022-01-01", # termina prima della finestra
      "2024-02-01" # inizia dopo la finestra
    )),
    fine = as.Date(c(
      "2023-02-15",
      "2023-06-30",
      "2023-12-31",
      "2022-12-31",
      "2024-06-30"
    )),
    codice_cnel = c("A011", "A011", "B011", "B011", "C011"),
    cod_tipologia_contrattuale = c(
      "A.01.00",
      "A.02.00",
      "C.01.00",
      "A.01.00",
      "ZZZ"
    ),
    prior = c(1L, 0L, 1L, 0L, 1L)
  )
}

# 2. Comportamento atteso sulla fixture -----

test_that("prepare_rapporti() restituisce un nuovo data.table e non modifica l'input", {
  dt <- data.table::copy(fixture)
  originale <- data.table::copy(fixture)
  out <- prepare_rapporti(dt)
  expect_s3_class(out, "data.table")
  expect_identical(dt, originale)
  expect_false(identical(out, dt))
  expect_false("ccnl_key" %in% names(dt))
})

test_that("prepare_rapporti() rinomina ccnl in ccnl_warehouse e aggiunge le colonne derivate", {
  out <- prepare_rapporti(data.table::copy(fixture))
  expect_false("ccnl" %in% names(out))
  expect_true("ccnl_warehouse" %in% names(out))
  attese <- c(
    "ccnl_key",
    "troncata",
    "troncata_inizio",
    "giornate",
    "avviato",
    "attivo",
    "anno",
    "trimestre",
    "macro_tipologia",
    "orario"
  )
  expect_true(all(attese %in% names(out)))
  expect_type(out$ccnl_key, "character")
  expect_type(out$troncata, "integer")
  expect_type(out$troncata_inizio, "integer")
  expect_type(out$giornate, "integer")
  expect_type(out$avviato, "logical")
  expect_type(out$attivo, "logical")
  expect_type(out$anno, "integer")
  expect_type(out$trimestre, "character")
  expect_type(out$macro_tipologia, "character")
  expect_type(out$orario, "character")
  expect_identical(sort(unique(out$troncata)), c(0L, 1L))
  expect_true(all(out$troncata_inizio == 0L))
})

test_that("prepare_rapporti() usa codice_cnel come chiave di default e conserva i NA", {
  out <- prepare_rapporti(data.table::copy(fixture))
  expect_identical(out$ccnl_key, out$codice_cnel)
  expect_identical(attr(out, "ccnlcob_meta")$ccnl_key, "codice_cnel")
  expect_true(anyNA(out$ccnl_key))
})

test_that("prepare_rapporti() risolve le sentinelle su fine e le conteggia", {
  dt <- data.table::copy(fixture)
  n_9999 <- sum(dt$fine == .sent_max)
  n_1900 <- sum(dt$fine == .sent_min)
  n_neg <- sum(dt$fine < dt$inizio & dt$fine > .sent_min)
  expect_gt(n_9999, 0L)
  expect_gt(n_1900, 0L)
  expect_gt(n_neg, 0L)

  out <- prepare_rapporti(dt, perimetro = "completo")
  meta <- attr(out, "ccnlcob_meta")
  as_of_atteso <- max(c(
    dt$inizio,
    dt$fine[dt$fine < .sent_max & dt$fine > .sent_min]
  ))
  expect_identical(meta$as_of, as_of_atteso)
  expect_identical(meta$n_sentinel_fine, n_9999 + n_1900)
  expect_identical(meta$n_sentinel_inizio, 0L)
  expect_identical(meta$n_fine_lt_inizio, n_neg)
  expect_identical(meta$n_dropped_window, 0L)
  expect_identical(meta$n_input, nrow(dt))
  expect_identical(nrow(out), nrow(dt))

  expect_false(anyNA(out$fine))
  expect_true(all(out$fine <= meta$as_of))
  expect_true(all(out$fine >= out$inizio))
  id_9999 <- dt[fine == .sent_max, id]
  id_1900 <- dt[fine == .sent_min, id]
  expect_true(all(out[id %in% c(id_9999, id_1900), fine] == meta$as_of))
  expect_true(all(out[id %in% c(id_9999, id_1900), troncata] == 1L))
  id_neg <- dt[fine < inizio & fine > .sent_min, id]
  expect_identical(out[id %in% id_neg, fine], out[id %in% id_neg, inizio])
  expect_identical(out[id %in% id_neg, giornate], rep(1L, length(id_neg)))
})

test_that("prepare_rapporti() combina in OR un flag troncata preesistente", {
  dt <- data.table::copy(fixture)
  id_gia_troncati <- dt[troncata == 1L & fine < .sent_max, id]
  expect_gt(length(id_gia_troncati), 0L)
  out <- prepare_rapporti(dt)
  expect_true(all(out[id %in% id_gia_troncati, troncata] == 1L))

  # flag logico e NA in ingresso
  dt2 <- data.table::copy(fixture)[, troncata := as.logical(troncata)]
  dt2[1:3, troncata := NA]
  out2 <- prepare_rapporti(dt2)
  expect_type(out2$troncata, "integer")
  expect_false(anyNA(out2$troncata))
  expect_identical(out2$troncata, out$troncata)

  # senza colonna troncata in ingresso
  dt3 <- data.table::copy(fixture)[, troncata := NULL]
  out3 <- prepare_rapporti(dt3)
  expect_type(out3$troncata, "integer")
  id_sent <- dt3[fine == .sent_max | fine == .sent_min, id]
  expect_true(all(out3[id %in% id_sent, troncata] == 1L))
  expect_true(all(out3[!id %in% id_sent, troncata] == 0L))
})

test_that("prepare_rapporti() risolve le sentinelle su inizio", {
  dt <- data.table::copy(fixture)
  dt[1:2, inizio := .sent_min]
  dt[3L, inizio := as.Date(NA)]
  dt[1:3, fine := as.Date("2020-06-30")]
  out <- prepare_rapporti(dt, as_of = as.Date("2024-12-31"))
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(meta$n_sentinel_inizio, 3L)
  expect_identical(out[id %in% 1:3, inizio], rep(as.Date("2008-03-01"), 3L))
  expect_identical(out[id %in% 1:3, troncata_inizio], rep(1L, 3L))
  expect_true(all(out[!id %in% 1:3, troncata_inizio] == 0L))
  # la finestra di default parte dal primo avviamento non sentinella
  expect_identical(meta$window[1L], min(dt[!id %in% 1:3, inizio]))
  expect_true(all(out[id %in% 1:3, avviato] == FALSE))
})

test_that("giornate coincide con fine - inizio + 1 nella finestra di default", {
  out <- prepare_rapporti(data.table::copy(fixture))
  attese <- as.integer(out$fine - out$inizio) + 1L
  expect_identical(out$giornate, attese)
  expect_true(all(out$giornate >= 1L))
})

test_that("prepare_rapporti() taglia le giornate ai bordi della finestra e rimuove le righe esterne", {
  dt <- data.table::copy(fixture)
  w <- as.Date(c("2022-01-01", "2022-12-31"))
  out <- prepare_rapporti(
    dt,
    as_of = as.Date("2024-12-31"),
    window = w,
    perimetro = "completo"
  )
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(meta$window, w)
  expect_true(all(out$inizio <= w[2L]))
  expect_true(all(out$fine >= w[1L]))
  expect_identical(meta$n_dropped_window, nrow(dt) - nrow(out))
  expect_gt(meta$n_dropped_window, 0L)

  attese <- as.integer(pmin(out$fine, w[2L]) - pmax(out$inizio, w[1L])) + 1L
  expect_identical(out$giornate, attese)
  expect_true(all(out$giornate >= 1L))
  expect_true(all(out$giornate <= 365L))

  # finestra come stringhe
  out2 <- prepare_rapporti(
    dt,
    as_of = "2024-12-31",
    window = c("2022-01-01", "2022-12-31"),
    perimetro = "completo"
  )
  expect_identical(out2$giornate, out$giornate)
  expect_identical(attr(out2, "ccnlcob_meta")$as_of, as.Date("2024-12-31"))
})

test_that("anno e trimestre derivano da inizio", {
  out <- prepare_rapporti(data.table::copy(fixture))
  expect_identical(out$anno, as.integer(format(out$inizio, "%Y")))
  q <- (as.integer(format(out$inizio, "%m")) - 1L) %/% 3L + 1L
  expect_identical(out$trimestre, paste0(out$anno, "-Q", q))
  expect_true(all(grepl("^[0-9]{4}-Q[1-4]$", out$trimestre)))
})

test_that("macro_tipologia e orario derivano da tipologie e prior", {
  out <- prepare_rapporti(data.table::copy(fixture))
  attese <- classify_tipologia(out$cod_tipologia_contrattuale)
  expect_identical(out$macro_tipologia, attese)
  expect_false(anyNA(out$macro_tipologia))
  expect_identical(out[prior == 1L, unique(orario)], "FT")
  expect_identical(out[prior == 0L, unique(orario)], "PT")
})

test_that("prepare_rapporti() conserva la classe IDate delle date", {
  dt <- data.table::copy(fixture)
  dt[, `:=`(
    inizio = data.table::as.IDate(inizio),
    fine = data.table::as.IDate(fine)
  )]
  out <- prepare_rapporti(dt)
  expect_s3_class(out$inizio, "IDate")
  expect_s3_class(out$fine, "IDate")
  expect_type(out$giornate, "integer")
  riferimento <- prepare_rapporti(data.table::copy(fixture))
  expect_identical(out$giornate, riferimento$giornate)
  expect_identical(as.integer(out$fine), as.integer(riferimento$fine))
  expect_identical(as.integer(out$inizio), as.integer(riferimento$inizio))
})

# 3. Tabella a mano: avviato, attivo, finestra -----

test_that("avviato e attivo seguono la finestra e as_of sulla tabella a mano", {
  out <- prepare_rapporti(
    .mini(),
    as_of = as.Date("2023-12-31"),
    window = as.Date(c("2023-01-01", "2023-12-31")),
    perimetro = "completo"
  )
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(out$id, 1:3)
  expect_identical(meta$n_dropped_window, 2L)
  expect_identical(meta$n_sentinel_fine, 1L) # fine 2024-06-30 > as_of
  expect_identical(out$avviato, c(FALSE, TRUE, TRUE))
  expect_identical(out$attivo, c(FALSE, FALSE, TRUE))
  expect_identical(out$giornate, c(46L, 122L, 92L))
  expect_identical(out$anno, c(2022L, 2023L, 2023L))
  expect_identical(out$trimestre, c("2022-Q2", "2023-Q1", "2023-Q4"))
  expect_identical(
    out$macro_tipologia,
    c("Tempo indeterminato", "Tempo determinato", "Tirocinio")
  )
  expect_identical(out$orario, c("FT", "PT", "FT"))
})

test_that("senza filtro di perimetro la tabella a mano non perde righe e as_of è la data massima", {
  out <- prepare_rapporti(.mini(), perimetro = "completo")
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(meta$as_of, as.Date("2024-06-30"))
  expect_identical(meta$window, as.Date(c("2022-01-01", "2024-06-30")))
  expect_identical(nrow(out), 5L)
  expect_identical(meta$n_dropped_window, 0L)
  expect_identical(meta$n_sentinel_fine, 0L)
  expect_true(all(out$avviato))
  expect_identical(out$attivo, c(FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_identical(out$macro_tipologia[5L], NA_character_)
})

test_that("prior non 0/1 produce orario NA", {
  dt <- .mini()[, prior := c(1L, 0L, NA_integer_, 2L, 1L)]
  out <- prepare_rapporti(dt, perimetro = "completo")
  expect_identical(out$orario, c("FT", "PT", NA, NA, "FT"))
})

test_that("con il default il perimetro CCNL esclude il tirocinio e il codice ignoto della tabella a mano", {
  expect_message(out <- prepare_rapporti(.mini()), "esclusi 2 rapporti su 5")
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(out$id, c(1L, 2L, 4L))
  expect_identical(meta$perimetro, "ccnl")
  expect_identical(meta$n_input, 5L)
  expect_identical(meta$n_dropped_perimetro, 2L)
  expect_identical(meta$n_tipologia_ignota, 1L)
  expect_identical(meta$n_dropped_window, 0L)
  expect_true(all(out$perimetro_ccnl))
  expect_identical(
    meta$esclusi_perimetro$cod_tipologia_contrattuale,
    c("C.01.00", "ZZZ")
  )
  expect_identical(meta$esclusi_perimetro$n, c(1L, 1L))
  # as_of di default resta la data massima di tutti i rapporti, anche esclusi
  expect_identical(meta$as_of, as.Date("2024-06-30"))
  # la finestra parte dal primo avviamento nel perimetro
  expect_identical(meta$window, as.Date(c("2022-01-01", "2024-06-30")))
})

# 4. Nomi delle colonne e chiave CCNL -----

test_that("prepare_rapporti() normalizza le varianti maiuscole della pipeline", {
  dt <- data.table::copy(fixture)
  data.table::setnames(
    dt,
    old = c(
      "inizio",
      "fine",
      "cod_tipologia_contrattuale",
      "comune_sede_lavoro",
      "comune_lavoratore",
      "retribuzione",
      "ore",
      "eta",
      "sesso"
    ),
    new = c(
      "INIZIO",
      "FINE",
      "COD_TIPOLOGIA_CONTRATTUALE",
      "COMUNE_SEDE_LAVORO",
      "COMUNE_LAVORATORE",
      "RETRIBUZIONE",
      "ORE_SETTIM_MEDIE",
      "ETA_LAV_INIZIO",
      "SESSO_LAV"
    )
  )
  out <- prepare_rapporti(dt)
  attese <- c(
    "inizio",
    "fine",
    "cod_tipologia_contrattuale",
    "comune_sede_lavoro",
    "comune_lavoratore",
    "retribuzione",
    "ore",
    "eta",
    "sesso"
  )
  expect_true(all(attese %in% names(out)))
  expect_false(any(
    c("INIZIO", "FINE", "ORE_SETTIM_MEDIE", "SESSO_LAV") %in% names(out)
  ))
  riferimento <- prepare_rapporti(data.table::copy(fixture))
  expect_identical(out$giornate, riferimento$giornate)
  expect_identical(out$ore, riferimento$ore)
})

test_that("prepare_rapporti() non rinomina se la colonna minuscola esiste già", {
  dt <- data.table::copy(fixture)
  dt[, SESSO_LAV := "X"]
  out <- prepare_rapporti(dt, perimetro = "completo")
  expect_identical(out$sesso, fixture$sesso)
  expect_true("SESSO_LAV" %in% names(out))

  dt2 <- data.table::copy(fixture)
  dt2[, ccnl_warehouse := "W"]
  out2 <- prepare_rapporti(dt2)
  expect_true(all(c("ccnl", "ccnl_warehouse") %in% names(out2)))
  expect_identical(unique(out2$ccnl_warehouse), "W")
})

test_that("ccnl_key = 'ccnl_warehouse' usa il codice warehouse", {
  out <- prepare_rapporti(
    data.table::copy(fixture),
    ccnl_key = "ccnl_warehouse"
  )
  expect_identical(out$ccnl_key, out$ccnl_warehouse)
  expect_identical(attr(out, "ccnlcob_meta")$ccnl_key, "ccnl_warehouse")
  expect_false(anyNA(out$ccnl_key))
})

test_that("con il default ccnl_key ripiega su ccnl_warehouse se codice_cnel manca", {
  dt <- data.table::copy(fixture)[, codice_cnel := NULL]
  out <- prepare_rapporti(dt)
  expect_identical(out$ccnl_key, out$ccnl_warehouse)
  expect_identical(attr(out, "ccnlcob_meta")$ccnl_key, "ccnl_warehouse")
})

test_that("l'attributo ccnlcob_meta ha i campi attesi", {
  out <- prepare_rapporti(data.table::copy(fixture))
  meta <- attr(out, "ccnlcob_meta")
  expect_type(meta, "list")
  expect_identical(
    names(meta),
    c(
      "as_of",
      "window",
      "ccnl_key",
      "perimetro",
      "n_input",
      "n_dropped_perimetro",
      "n_tipologia_ignota",
      "n_dropped_window",
      "n_sentinel_fine",
      "n_sentinel_inizio",
      "n_fine_lt_inizio",
      "esclusi_perimetro"
    )
  )
  expect_s3_class(meta$as_of, "Date")
  expect_s3_class(meta$window, "Date")
  expect_identical(length(meta$window), 2L)
  expect_type(meta$n_input, "integer")
  expect_type(meta$perimetro, "character")
  expect_type(meta$n_dropped_perimetro, "integer")
  expect_type(meta$n_tipologia_ignota, "integer")
  expect_s3_class(meta$esclusi_perimetro, "data.table")
  expect_identical(
    names(meta$esclusi_perimetro),
    c(
      "cod_tipologia_contrattuale",
      "des_tipologia_contrattuale",
      "macro_tipologia",
      "n"
    )
  )
})

# 4b. Perimetro contrattuale -----

test_that("con il default prepare_rapporti() esclude esattamente le tipologie B. e C. della fixture", {
  dt <- data.table::copy(fixture)
  fuori <- grepl("^[BC]\\.", dt$cod_tipologia_contrattuale)
  expect_gt(sum(fuori), 0L)
  expect_message(out <- prepare_rapporti(dt), "filter_perimetro")
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(meta$perimetro, "ccnl")
  expect_identical(meta$n_input, nrow(dt))
  expect_identical(meta$n_dropped_perimetro, sum(fuori))
  expect_identical(meta$n_tipologia_ignota, 0L)
  expect_identical(nrow(out), nrow(dt) - sum(fuori) - meta$n_dropped_window)
  expect_identical(sort(out$id), sort(dt$id[!fuori]))
  expect_true("perimetro_ccnl" %in% names(out))
  expect_true(all(out$perimetro_ccnl))
  expect_false(any(grepl("^[BC]\\.", out$cod_tipologia_contrattuale)))
  expect_identical(sum(meta$esclusi_perimetro$n), meta$n_dropped_perimetro)
  expect_identical(
    sort(meta$esclusi_perimetro$cod_tipologia_contrattuale),
    sort(unique(dt$cod_tipologia_contrattuale[fuori]))
  )
  # l'attributo di filter_perimetro() non resta sul risultato
  expect_null(attr(out, "ccnlcob_perimetro"))
  # i conteggi delle sentinelle riguardano solo le righe nel perimetro
  expect_identical(
    meta$n_sentinel_fine,
    sum(dt$fine[!fuori] == .sent_max | dt$fine[!fuori] == .sent_min)
  )
})

test_that("perimetro = 'standard' esclude solo i codici esclusa_standard", {
  dt <- data.table::copy(fixture)
  esclusi_std <- c("C.01.00", "B.04.00", "B.03.00", "A.04.00", "A.04.01")
  fuori <- dt$cod_tipologia_contrattuale %in% esclusi_std
  expect_gt(sum(fuori), 0L)
  out <- suppressMessages(prepare_rapporti(dt, perimetro = "standard"))
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(meta$perimetro, "standard")
  expect_identical(meta$n_dropped_perimetro, sum(fuori))
  expect_identical(sort(out$id), sort(dt$id[!fuori]))
  expect_true(all(
    meta$esclusi_perimetro$cod_tipologia_contrattuale %in% esclusi_std
  ))
  # C.03.00 resta nello standard ma è fuori dal perimetro CCNL
  expect_true("C.03.00" %in% out$cod_tipologia_contrattuale)
  expect_identical(
    out$perimetro_ccnl,
    !grepl("^[BC]\\.", out$cod_tipologia_contrattuale)
  )
})

test_that("perimetro = 'completo' riproduce il comportamento precedente e aggiunge perimetro_ccnl", {
  dt <- data.table::copy(fixture)
  expect_no_message(out <- prepare_rapporti(dt, perimetro = "completo"))
  meta <- attr(out, "ccnlcob_meta")
  expect_identical(meta$perimetro, "completo")
  expect_identical(meta$n_dropped_perimetro, 0L)
  expect_identical(nrow(meta$esclusi_perimetro), 0L)
  expect_identical(nrow(out), nrow(dt))
  expect_identical(
    out$perimetro_ccnl,
    !grepl("^[BC]\\.", out$cod_tipologia_contrattuale)
  )
  # il risultato di default coincide con il completo ristretto al perimetro
  rif <- suppressMessages(prepare_rapporti(dt))
  sotto <- out[perimetro_ccnl == TRUE]
  expect_identical(sotto$id, rif$id)
  expect_identical(sotto$giornate, rif$giornate)
  expect_identical(sotto$fine, rif$fine)
  expect_identical(sotto$troncata, rif$troncata)
})

test_that("prepare_rapporti() rifiuta un perimetro non ammesso", {
  expect_error(prepare_rapporti(data.table::copy(fixture), perimetro = "altro"))
})

# 5. Errori -----

test_that("prepare_rapporti() rifiuta input non data.table e contratto dati incompleto", {
  expect_error(prepare_rapporti(as.data.frame(fixture)), "setDT")
  dt <- data.table::copy(fixture)[, cf := NULL]
  expect_error(prepare_rapporti(dt), "Colonne mancanti")
  dt2 <- data.table::copy(fixture)[, inizio := as.character(inizio)]
  expect_error(prepare_rapporti(dt2), "Date")
})

test_that("prepare_rapporti() rifiuta una chiave CCNL non ammessa o assente", {
  expect_error(prepare_rapporti(data.table::copy(fixture), ccnl_key = "altro"))
  expect_error(prepare_rapporti(
    data.table::copy(fixture),
    ccnl_key = character(0)
  ))
  # match.arg: "ccnl" completa in modo univoco "ccnl_warehouse"
  out <- prepare_rapporti(data.table::copy(fixture), ccnl_key = "ccnl")
  expect_identical(attr(out, "ccnlcob_meta")$ccnl_key, "ccnl_warehouse")
  dt <- data.table::copy(fixture)[, codice_cnel := NULL]
  expect_error(prepare_rapporti(dt, ccnl_key = "codice_cnel"), "codice_cnel")
})

test_that("prepare_rapporti() rifiuta window e as_of non validi", {
  dt <- data.table::copy(fixture)
  expect_error(
    prepare_rapporti(dt, window = as.Date(c("2023-12-31", "2023-01-01"))),
    "ordinata"
  )
  expect_error(prepare_rapporti(dt, window = as.Date("2023-01-01")), "due date")
  expect_error(
    prepare_rapporti(dt, window = c("2023-01-01", "non-data")),
    "valid"
  )
  expect_error(prepare_rapporti(dt, window = c(1, 2)), "due date")
  expect_error(
    prepare_rapporti(dt, as_of = c("2023-01-01", "2023-12-31")),
    "singola"
  )
  expect_error(prepare_rapporti(dt, as_of = "non-data"), "valid")
  expect_error(prepare_rapporti(dt, as_of = 20231231), "singola")
})

test_that("prepare_rapporti() rifiuta un lookup tipologie privo delle colonne richieste", {
  expect_error(
    prepare_rapporti(data.table::copy(fixture), tipologie = data.frame(x = 1)),
    "tipologie"
  )
  # senza macro_tipologia il filtro passa ma la classificazione fallisce
  solo_perimetro <- data.frame(
    cod_tipologia_contrattuale = "A.01.00",
    perimetro_ccnl = TRUE,
    esclusa_standard = FALSE
  )
  expect_error(
    suppressMessages(
      prepare_rapporti(data.table::copy(fixture), tipologie = solo_perimetro)
    ),
    "macro_tipologia"
  )
})

test_that("prepare_rapporti() richiede as_of esplicito se non esistono date valide", {
  dt <- .mini()[, `:=`(inizio = as.Date(NA), fine = as.Date(NA))]
  expect_error(prepare_rapporti(dt), "as_of")
})
