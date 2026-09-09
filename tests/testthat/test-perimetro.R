# Test di filter_perimetro() (R/perimetro.R).

# 1. Fixture -----

cob <- .carica_dataset("cob_esempio")
tipologie <- .carica_dataset("tipologie_contrattuali")

.codici_esclusi_standard <- c(
  "C.01.00",
  "B.04.00",
  "B.03.00",
  "A.04.00",
  "A.04.01"
)

# Tabella costruita a mano: una riga per ciascuna regola di esclusione, alcune
# regole di inclusione e un codice ignoto.
.mini_perimetro <- function() {
  data.table::data.table(
    id = 1:12,
    cod_tipologia_contrattuale = c(
      "A.01.00", # subordinato standard
      "A.04.00", # domestico: nel perimetro CCNL, escluso dallo standard
      "F.01.00", # marittimo
      "G.02.00", # spettacolo subordinato
      "H.03.00", # agricoltura subordinata
      "I.01.00", # pubblica amministrazione
      "N.01.00", # piattaforma
      "B.03.00", # collaborazione: fuori, escluso anche dallo standard
      "C.03.00", # LSU: fuori, ma dentro lo standard
      "G.03.00", # lavoro autonomo nello spettacolo
      "H.02.00", # lavoro congiunto in agricoltura
      "ZZZ" # codice ignoto
    ),
    valore = seq(10, 120, by = 10)
  )
}

.attesi_ccnl <- c(
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE
)

# Conteggi indipendenti sul dataset di esempio.
.fuori_ccnl <- grepl("^[BC]\\.", cob$cod_tipologia_contrattuale)
.fuori_standard <- cob$cod_tipologia_contrattuale %in% .codici_esclusi_standard

# 2. Perimetri sul dataset di esempio -----

test_that("perimetro 'ccnl' esclude le tipologie B. e C. di cob_esempio e le conteggia", {
  expect_message(out <- filter_perimetro(cob), "esclusi")
  info <- attr(out, "ccnlcob_perimetro")
  expect_s3_class(out, "data.table")
  expect_identical(info$perimetro, "ccnl")
  expect_identical(info$n_input, nrow(cob))
  expect_identical(info$n_dropped, sum(.fuori_ccnl))
  expect_identical(info$n_kept, sum(!.fuori_ccnl))
  expect_identical(info$n_kept + info$n_dropped, info$n_input)
  expect_identical(nrow(out), info$n_kept)
  expect_identical(info$n_tipologia_ignota, 0L)
  expect_identical(sort(out$id), sort(cob$id[!.fuori_ccnl]))
  expect_true(all(out$perimetro_ccnl))
  expect_false(any(grepl("^[BC]\\.", out$cod_tipologia_contrattuale)))
})

test_that("la tabella esclusi somma a n_dropped ed è ordinata per n decrescente", {
  out <- suppressMessages(filter_perimetro(cob))
  esclusi <- attr(out, "ccnlcob_perimetro")$esclusi
  expect_s3_class(esclusi, "data.table")
  expect_identical(
    names(esclusi),
    c(
      "cod_tipologia_contrattuale",
      "des_tipologia_contrattuale",
      "macro_tipologia",
      "n"
    )
  )
  expect_identical(sum(esclusi$n), sum(.fuori_ccnl))
  expect_identical(esclusi$n, sort(esclusi$n, decreasing = TRUE))
  attesi <- cob[.fuori_ccnl, .N, by = cod_tipologia_contrattuale]
  expect_identical(
    esclusi[
      order(cod_tipologia_contrattuale),
      .(cod_tipologia_contrattuale, n = as.integer(n))
    ],
    attesi[
      order(cod_tipologia_contrattuale),
      .(cod_tipologia_contrattuale, n = N)
    ]
  )
  expect_false(anyNA(esclusi$des_tipologia_contrattuale))
  expect_identical(
    esclusi$macro_tipologia,
    classify_tipologia(esclusi$cod_tipologia_contrattuale)
  )
})

test_that("perimetro 'standard' esclude solo i codici esclusa_standard", {
  out <- suppressMessages(filter_perimetro(cob, perimetro = "standard"))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(info$perimetro, "standard")
  expect_identical(info$n_dropped, sum(.fuori_standard))
  expect_identical(info$n_kept + info$n_dropped, info$n_input)
  expect_identical(sort(out$id), sort(cob$id[!.fuori_standard]))
  expect_true(all(
    info$esclusi$cod_tipologia_contrattuale %in% .codici_esclusi_standard
  ))
  expect_identical(sum(info$esclusi$n), info$n_dropped)
  # C.03.00 (LSU) resta nello standard ma non nel perimetro CCNL
  expect_true("C.03.00" %in% out$cod_tipologia_contrattuale)
  expect_false(all(out$perimetro_ccnl))
  expect_identical(
    out$perimetro_ccnl,
    !grepl("^[BC]\\.", out$cod_tipologia_contrattuale)
  )
})

test_that("perimetro 'completo' conserva tutte le righe e aggiunge la colonna", {
  expect_no_message(out <- filter_perimetro(cob, perimetro = "completo"))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(info$perimetro, "completo")
  expect_identical(nrow(out), nrow(cob))
  expect_identical(info$n_kept, nrow(cob))
  expect_identical(info$n_dropped, 0L)
  expect_identical(nrow(info$esclusi), 0L)
  expect_identical(
    names(info$esclusi),
    c(
      "cod_tipologia_contrattuale",
      "des_tipologia_contrattuale",
      "macro_tipologia",
      "n"
    )
  )
  expect_identical(names(out), c(names(cob), "perimetro_ccnl"))
  expect_type(out$perimetro_ccnl, "logical")
  expect_identical(out$perimetro_ccnl, !.fuori_ccnl)
  expect_identical(out$id, cob$id)
})

test_that("filter_perimetro() non modifica l'input e restituisce un nuovo oggetto", {
  dt <- data.table::copy(cob)
  originale <- data.table::copy(cob)
  out <- suppressMessages(filter_perimetro(dt))
  expect_identical(dt, originale)
  expect_false("perimetro_ccnl" %in% names(dt))
  expect_null(attr(dt, "ccnlcob_perimetro"))
  expect_false(identical(out, dt))
  # anche con 'completo' l'oggetto restituito è una copia
  out2 <- filter_perimetro(dt, perimetro = "completo")
  data.table::set(out2, j = "valore_test", value = 1L)
  expect_false("valore_test" %in% names(dt))
})

test_that("filter_perimetro() accetta l'uscita di prepare_rapporti() ed è idempotente", {
  prep <- suppressMessages(prepare_rapporti(cob))
  expect_no_message(out <- filter_perimetro(prep))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(info$n_dropped, 0L)
  expect_identical(nrow(out), nrow(prep))
  expect_identical(names(out), names(prep))
  # la colonna già presente viene conservata così com'è
  prep2 <- suppressMessages(prepare_rapporti(cob, perimetro = "completo"))
  data.table::set(prep2, j = "perimetro_ccnl", value = NA)
  out2 <- suppressMessages(filter_perimetro(prep2))
  expect_true(all(is.na(out2$perimetro_ccnl)))
  expect_identical(attr(out2, "ccnlcob_perimetro")$n_dropped, sum(.fuori_ccnl))
})

# 3. Tabella a mano: ogni regola e un codice ignoto -----

test_that("sulla tabella a mano 'ccnl' esclude ogni regola FALSE e il codice ignoto", {
  dt <- .mini_perimetro()
  expect_message(out <- filter_perimetro(dt), "1 con tipologia ignota")
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(out$id, which(.attesi_ccnl))
  expect_identical(info$n_input, 12L)
  expect_identical(info$n_kept, 7L)
  expect_identical(info$n_dropped, 5L)
  expect_identical(info$n_tipologia_ignota, 1L)
  expect_true(all(out$perimetro_ccnl))
  expect_identical(nrow(info$esclusi), 5L)
  expect_identical(sum(info$esclusi$n), 5L)
  expect_true(all(info$esclusi$n == 1L))
  # ordinamento per n decrescente e poi per codice
  expect_identical(
    info$esclusi$cod_tipologia_contrattuale,
    c("B.03.00", "C.03.00", "G.03.00", "H.02.00", "ZZZ")
  )
  riga_ignota <- info$esclusi[cod_tipologia_contrattuale == "ZZZ"]
  expect_identical(riga_ignota$des_tipologia_contrattuale, NA_character_)
  expect_identical(riga_ignota$macro_tipologia, NA_character_)
  expect_identical(
    info$esclusi[cod_tipologia_contrattuale == "B.03.00", macro_tipologia],
    "Collaborazioni"
  )
})

test_that("sulla tabella a mano 'standard' esclude solo A.04.00 e B.03.00 e conserva l'ignoto", {
  dt <- .mini_perimetro()
  out <- suppressMessages(filter_perimetro(dt, perimetro = "standard"))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(info$n_dropped, 2L)
  expect_identical(info$n_tipologia_ignota, 1L)
  expect_identical(
    sort(info$esclusi$cod_tipologia_contrattuale),
    c("A.04.00", "B.03.00")
  )
  expect_true("ZZZ" %in% out$cod_tipologia_contrattuale)
  expect_identical(out$id, setdiff(1:12, c(2L, 8L)))
  expect_identical(out$perimetro_ccnl, .attesi_ccnl[-c(2L, 8L)])
})

test_that("sulla tabella a mano 'completo' conserva tutto e classifica ogni riga", {
  dt <- .mini_perimetro()
  expect_message(
    out <- filter_perimetro(dt, perimetro = "completo"),
    "esclusi 0 rapporti"
  )
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(nrow(out), 12L)
  expect_identical(info$n_dropped, 0L)
  expect_identical(info$n_tipologia_ignota, 1L)
  expect_identical(out$perimetro_ccnl, .attesi_ccnl)
  expect_identical(out$valore, dt$valore)
})

test_that("un codice NA è trattato come tipologia ignota", {
  dt <- .mini_perimetro()
  dt[1L, cod_tipologia_contrattuale := NA_character_]
  out <- suppressMessages(filter_perimetro(dt))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(info$n_tipologia_ignota, 2L)
  expect_identical(info$n_dropped, 6L)
  expect_false(1L %in% out$id)
  expect_true(NA_character_ %in% info$esclusi$cod_tipologia_contrattuale)
  # factor accettato
  dt2 <- .mini_perimetro()
  dt2[, cod_tipologia_contrattuale := factor(cod_tipologia_contrattuale)]
  out2 <- suppressMessages(filter_perimetro(dt2))
  expect_identical(out2$id, which(.attesi_ccnl))
})

test_that("un lookup alternativo con le colonne richieste viene rispettato", {
  lookup <- data.frame(
    cod_tipologia_contrattuale = c("X.01", "X.02", "X.03"),
    perimetro_ccnl = c(TRUE, FALSE, TRUE),
    esclusa_standard = c(FALSE, FALSE, TRUE)
  )
  dt <- data.table::data.table(
    id = 1:4,
    cod_tipologia_contrattuale = c("X.01", "X.02", "X.03", "A.01.00")
  )
  out <- suppressMessages(filter_perimetro(dt, tipologie = lookup))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(out$id, c(1L, 3L))
  expect_identical(info$n_tipologia_ignota, 1L)
  # senza descrizione e macro nel lookup le colonne degli esclusi sono NA
  expect_true(all(is.na(info$esclusi$des_tipologia_contrattuale)))
  expect_true(all(is.na(info$esclusi$macro_tipologia)))
  out_std <- suppressMessages(
    filter_perimetro(dt, perimetro = "standard", tipologie = lookup)
  )
  expect_identical(out_std$id, c(1L, 2L, 4L))
})

test_that("un data.table vuoto attraversa il filtro senza errori", {
  dt <- .mini_perimetro()[0L]
  expect_no_message(out <- filter_perimetro(dt))
  info <- attr(out, "ccnlcob_perimetro")
  expect_identical(nrow(out), 0L)
  expect_identical(info$n_input, 0L)
  expect_identical(info$n_dropped, 0L)
  expect_identical(nrow(info$esclusi), 0L)
  expect_true("perimetro_ccnl" %in% names(out))
})

# 4. Errori -----

test_that("filter_perimetro() rifiuta input non validi", {
  expect_error(filter_perimetro(as.data.frame(cob)), "setDT")
  expect_error(
    filter_perimetro(cob[, !"cod_tipologia_contrattuale"]),
    "cod_tipologia_contrattuale"
  )
  expect_error(filter_perimetro(cob, perimetro = "altro"))
  expect_error(
    filter_perimetro(cob, tipologie = data.frame(x = 1)),
    "tipologie"
  )
  lookup_senza <- data.frame(
    cod_tipologia_contrattuale = "A.01.00",
    macro_tipologia = "Tempo indeterminato"
  )
  expect_error(
    filter_perimetro(cob, tipologie = lookup_senza),
    "perimetro_ccnl"
  )
  lookup_tipo <- data.frame(
    cod_tipologia_contrattuale = "A.01.00",
    perimetro_ccnl = "TRUE",
    esclusa_standard = FALSE
  )
  expect_error(filter_perimetro(cob, tipologie = lookup_tipo), "logical")
})
