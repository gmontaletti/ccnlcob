# Test dei dataset del pacchetto: tipologie_contrattuali e cob_esempio.

# 1. Caricamento -----

tipologie <- .carica_dataset("tipologie_contrattuali")
cob <- .carica_dataset("cob_esempio")

.macro_ammesse <- c(
  "Tempo indeterminato",
  "Tempo determinato",
  "Apprendistato",
  "Somministrazione",
  "Intermittente",
  "Collaborazioni",
  "Tirocinio",
  "Domestico",
  "Altro"
)
.codici_esclusi <- c("C.01.00", "B.04.00", "B.03.00", "A.04.00", "A.04.01")

# 2. tipologie_contrattuali -----

test_that("tipologie_contrattuali ha la struttura documentata", {
  expect_true(data.table::is.data.table(tipologie))
  expect_identical(
    names(tipologie),
    c(
      "cod_tipologia_contrattuale",
      "des_tipologia_contrattuale",
      "macro_tipologia",
      "perimetro_ccnl",
      "esclusa_standard"
    )
  )
  expect_type(tipologie$cod_tipologia_contrattuale, "character")
  expect_type(tipologie$des_tipologia_contrattuale, "character")
  expect_type(tipologie$macro_tipologia, "character")
  expect_type(tipologie$perimetro_ccnl, "logical")
  expect_type(tipologie$esclusa_standard, "logical")
  expect_gte(nrow(tipologie), 20L)
})

test_that("i codici tipologia sono univoci, nel formato MLPS e ordinati", {
  codici <- tipologie$cod_tipologia_contrattuale
  expect_identical(anyDuplicated(codici), 0L)
  expect_true(all(grepl("^[A-Z]\\.[0-9]{2}\\.[0-9]{2}$", codici)))
  expect_identical(codici, sort(codici))
  expect_false(anyNA(tipologie$des_tipologia_contrattuale))
  expect_true(all(nzchar(tipologie$des_tipologia_contrattuale)))
})

test_that("macro_tipologia è sempre nell'insieme ammesso", {
  expect_false(anyNA(tipologie$macro_tipologia))
  expect_true(all(tipologie$macro_tipologia %in% .macro_ammesse))
  expect_true(all(
    c(
      "Tempo indeterminato",
      "Tempo determinato",
      "Apprendistato",
      "Somministrazione",
      "Intermittente",
      "Collaborazioni",
      "Tirocinio",
      "Domestico"
    ) %in%
      tipologie$macro_tipologia
  ))
})

test_that("esclusa_standard è TRUE esattamente per i cinque codici del perimetro cnelR", {
  expect_false(anyNA(tipologie$esclusa_standard))
  esclusi <- tipologie[esclusa_standard == TRUE, cod_tipologia_contrattuale]
  expect_identical(sort(esclusi), sort(.codici_esclusi))
})

test_that("perimetro_ccnl è logical senza NA e segue le regole per prefisso", {
  expect_type(tipologie$perimetro_ccnl, "logical")
  expect_false(anyNA(tipologie$perimetro_ccnl))
  perim <- function(cod) {
    tipologie[cod_tipologia_contrattuale == cod, perimetro_ccnl]
  }
  # lavoro subordinato con CCNL
  expect_true(perim("A.01.00"))
  expect_true(perim("A.04.00"))
  expect_true(perim("I.01.00"))
  expect_true(perim("N.01.00"))
  # fuori perimetro
  expect_false(perim("B.03.00"))
  expect_false(perim("C.01.00"))
  expect_false(perim("M.01.00"))
  expect_false(perim("L.01.00"))
  expect_false(perim("G.03.00"))
  expect_false(perim("H.02.00"))
  # regole per prefisso: B., C., L., M. sempre fuori; A., F., I., N. sempre dentro
  codici <- tipologie$cod_tipologia_contrattuale
  expect_true(any(grepl("^[BCLM]\\.", codici)))
  expect_false(any(tipologie[grepl("^[BCLM]\\.", codici), perimetro_ccnl]))
  expect_true(all(tipologie[grepl("^[AFIN]\\.", codici), perimetro_ccnl]))
  # il perimetro CCNL è più ampio del perimetro standard di cnelR sui domestici
  expect_true(all(tipologie[
    esclusa_standard == TRUE & grepl("^A\\.", codici),
    perimetro_ccnl
  ]))
})

test_that("i codici principali hanno la macro-tipologia attesa", {
  macro <- function(cod) {
    tipologie[cod_tipologia_contrattuale == cod, macro_tipologia]
  }
  expect_identical(macro("A.01.00"), "Tempo indeterminato")
  expect_identical(macro("A.02.00"), "Tempo determinato")
  expect_identical(macro("A.02.01"), "Tempo determinato")
  expect_identical(macro("A.03.09"), "Apprendistato")
  expect_identical(macro("A.04.02"), "Domestico")
  expect_identical(macro("A.05.02"), "Intermittente")
  expect_identical(macro("A.06.01"), "Somministrazione")
  expect_identical(macro("B.03.00"), "Collaborazioni")
  expect_identical(macro("B.02.00"), "Collaborazioni")
  expect_identical(macro("C.01.00"), "Tirocinio")
  expect_identical(macro("H.03.00"), "Tempo determinato")
  expect_identical(macro("N.02.00"), "Tempo determinato")
})

# 3. cob_esempio -----

test_that("cob_esempio ha le colonne del contratto dati e circa 5000 righe", {
  expect_true(data.table::is.data.table(cob))
  expect_identical(
    names(cob),
    c(
      "id",
      "cf",
      "inizio",
      "fine",
      "codice_cnel",
      "ccnl",
      "cod_tipologia_contrattuale",
      "prior",
      "comune_sede_lavoro",
      "comune_lavoratore",
      "datore",
      "retribuzione",
      "ore",
      "troncata",
      "qualifica",
      "ateco_gruppo",
      "eta",
      "sesso"
    )
  )
  expect_identical(nrow(cob), 5000L)
  expect_identical(anyDuplicated(cob$id), 0L)
  expect_s3_class(cob$inizio, "Date")
  expect_s3_class(cob$fine, "Date")
})

test_that("cob_esempio coincide con generate_cob_sintetico() con i default", {
  atteso <- generate_cob_sintetico()
  expect_identical(names(cob), names(atteso))
  expect_equal(cob, atteso)
})

test_that("cob_esempio contiene NA, sentinelle e sovrapposizioni", {
  expect_gt(mean(is.na(cob$retribuzione)), 0.1)
  expect_gt(mean(is.na(cob$codice_cnel)), 0.05)
  expect_gte(sum(cob$fine == as.Date("9999-12-31")), 1L)
  expect_gte(sum(cob$fine == as.Date("1900-01-01")), 1L)
  expect_true(all(
    cob$cod_tipologia_contrattuale %in% tipologie$cod_tipologia_contrattuale
  ))
})

test_that("cob_esempio contiene tipologie fuori dal perimetro CCNL", {
  fuori <- cob[
    grepl("^[BC]\\.", cod_tipologia_contrattuale),
    .N,
    by = cod_tipologia_contrattuale
  ]
  expect_gt(nrow(fuori), 0L)
  expect_true(all(c("B.03.00", "C.01.00") %in% fuori$cod_tipologia_contrattuale))
  expect_false(any(grepl("^[GHLM]\\.", cob$cod_tipologia_contrattuale)))
})
