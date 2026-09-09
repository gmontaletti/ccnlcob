# Test del generatore di fixture sintetiche generate_cob_sintetico()
# (tests/testthat/helper-cob-sintetico.R).

# 1. Costanti e funzioni di supporto -----

.colonne_attese <- c(
  "id", "cf", "inizio", "fine", "codice_cnel", "ccnl",
  "cod_tipologia_contrattuale", "prior", "comune_sede_lavoro",
  "comune_lavoratore", "datore", "retribuzione", "ore", "troncata",
  "qualifica", "ateco_gruppo", "eta", "sesso"
)

.classi_attese <- c(
  id = "integer", cf = "character", inizio = "Date", fine = "Date",
  codice_cnel = "character", ccnl = "character",
  cod_tipologia_contrattuale = "character", prior = "integer",
  comune_sede_lavoro = "character", comune_lavoratore = "character",
  datore = "character", retribuzione = "numeric", ore = "numeric",
  troncata = "integer", qualifica = "character", ateco_gruppo = "character",
  eta = "integer", sesso = "character"
)

.belfiore_lombardia <- c(
  "F205", "A794", "B157", "C933", "D150", "E507", "E648", "E897", "F704",
  "G388", "I829", "L682"
)
.belfiore_fuori <- c("H501", "L219", "F952", "G535")

.sentinella_9999 <- as.Date("9999-12-31")
.sentinella_1900 <- as.Date("1900-01-01")

# Righe con date regolari: senza sentinelle e con fine >= inizio.
.righe_regolari <- function(dt) {
  dt[fine >= inizio & fine != .sentinella_9999 & fine != .sentinella_1900]
}

# Per ogni cf: TRUE se almeno un rapporto inizia prima della fine massima dei
# rapporti precedenti (ordinati per inizio).
.persone_con_sovrapposizioni <- function(dt) {
  x <- data.table::copy(.righe_regolari(dt))
  data.table::setorder(x, cf, inizio, fine)
  x[, fine_prec := data.table::shift(cummax(as.integer(fine))), by = cf]
  x[, list(sovrapposta = any(!is.na(fine_prec) & as.integer(inizio) < fine_prec)), by = cf]
}

cob <- generate_cob_sintetico()

# 2. Schema -----

test_that("generate_cob_sintetico() restituisce un data.table con le colonne attese", {
  expect_true(data.table::is.data.table(cob))
  expect_identical(names(cob), .colonne_attese)
})

test_that("le colonne hanno i tipi del contratto dati", {
  classi <- vapply(cob, function(x) class(x)[1], character(1))
  expect_identical(classi, .classi_attese)
})

test_that("dimensioni di default: 5000 rapporti, 400 persone, 25 CCNL", {
  expect_identical(nrow(cob), 5000L)
  expect_identical(data.table::uniqueN(cob$cf), 400L)
  expect_identical(data.table::uniqueN(cob$codice_cnel[!is.na(cob$codice_cnel)]), 25L)
})

test_that("id è univoco e progressivo", {
  expect_identical(anyDuplicated(cob$id), 0L)
  expect_identical(sort(cob$id), seq_len(nrow(cob)))
})

# 3. Determinismo -----

test_that("stesso seed produce lo stesso output", {
  a <- generate_cob_sintetico(n_persone = 50, n_rapporti = 300, n_ccnl = 6, seed = 7)
  b <- generate_cob_sintetico(n_persone = 50, n_rapporti = 300, n_ccnl = 6, seed = 7)
  expect_identical(a, b)
})

test_that("seed diversi producono output diversi", {
  a <- generate_cob_sintetico(n_persone = 50, n_rapporti = 300, n_ccnl = 6, seed = 7)
  b <- generate_cob_sintetico(n_persone = 50, n_rapporti = 300, n_ccnl = 6, seed = 8)
  expect_false(identical(a, b))
  expect_false(identical(a$retribuzione, b$retribuzione))
})

test_that("la chiamata non altera lo stato del generatore in modo dipendente dal contesto", {
  set.seed(1)
  a <- generate_cob_sintetico(n_persone = 20, n_rapporti = 100, seed = 3)
  set.seed(99)
  b <- generate_cob_sintetico(n_persone = 20, n_rapporti = 100, seed = 3)
  expect_identical(a, b)
})

# 4. Sovrapposizioni e sentinelle -----

test_that("almeno il 10% delle persone ha rapporti sovrapposti", {
  sov <- .persone_con_sovrapposizioni(cob)
  expect_gte(mean(sov$sovrapposta), 0.10)
})

test_that("le sentinelle su fine sono presenti nelle quote richieste", {
  n_9999 <- sum(cob$fine == .sentinella_9999)
  n_1900 <- sum(cob$fine == .sentinella_1900)
  n_neg <- sum(cob$fine < cob$inizio & cob$fine != .sentinella_1900)
  expect_identical(n_9999, 150L)
  expect_gte(n_1900, 1L)
  expect_lte(n_1900, 10L)
  expect_true(n_neg %in% 1:2)
})

test_that("le righe con sentinella non sono marcate troncata", {
  expect_true(all(cob[fine == .sentinella_9999, troncata] == 0L))
  expect_true(all(cob[fine == .sentinella_1900, troncata] == 0L))
})

# 5. Quote di NA e anomalie -----

test_that("le quote di NA e anomalie rispettano i parametri di default (±0.05)", {
  expect_lt(abs(mean(is.na(cob$retribuzione)) - 0.25), 0.05)
  expect_lt(abs(mean(is.na(cob$codice_cnel)) - 0.15), 0.05)
  anomali <- !is.na(cob$retribuzione) & (cob$retribuzione < 1000 | cob$retribuzione > 1e6)
  expect_lt(abs(mean(anomali) - 0.02), 0.05)
  expect_lt(abs(mean(!cob$comune_sede_lavoro %in% .belfiore_lombardia) - 0.05), 0.05)
  expect_lt(abs(mean(cob$fine == .sentinella_9999) - 0.03), 0.05)
})

test_that("i parametri di quota vengono rispettati con valori non di default", {
  x <- generate_cob_sintetico(
    n_persone = 30, n_rapporti = 400, n_ccnl = 5,
    share_na_retribuzione = 0.5, share_outlier = 0,
    share_fuori_lombardia = 0, share_sentinel = 0, share_ccnl_na = 0,
    seed = 3
  )
  expect_identical(nrow(x), 400L)
  expect_identical(data.table::uniqueN(x$cf), 30L)
  expect_identical(data.table::uniqueN(x$codice_cnel), 5L)
  expect_false(anyNA(x$codice_cnel))
  expect_identical(sum(x$fine == .sentinella_9999), 0L)
  expect_true(all(x$comune_sede_lavoro %in% .belfiore_lombardia))
  expect_equal(mean(is.na(x$retribuzione)), 0.5, tolerance = 0.05)
  regolari <- x$retribuzione[!is.na(x$retribuzione)]
  expect_true(all(regolari >= 1000 & regolari <= 1e6))
})

test_that("ccnl (warehouse) non è mai NA e ha 3 o 4 cifre", {
  expect_false(anyNA(cob$ccnl))
  expect_true(all(grepl("^[0-9]{3,4}$", cob$ccnl)))
})

# 6. Coerenza dei codici CCNL -----

test_that("codice_cnel e ccnl sono in corrispondenza uno a uno dove raccordati", {
  coppie <- unique(cob[!is.na(codice_cnel), list(codice_cnel, ccnl)])
  expect_identical(nrow(coppie), data.table::uniqueN(coppie$codice_cnel))
  expect_identical(nrow(coppie), data.table::uniqueN(coppie$ccnl))
})

test_that("le righe senza codice_cnel usano codici warehouse non raccordati", {
  raccordati <- cob[!is.na(codice_cnel), unique(ccnl)]
  non_raccordati <- cob[is.na(codice_cnel), unique(ccnl)]
  expect_length(intersect(raccordati, non_raccordati), 0L)
  expect_gte(length(non_raccordati), 1L)
})

test_that("i codici CNEL hanno 4 caratteri e includono CPUB", {
  codici <- unique(cob$codice_cnel[!is.na(cob$codice_cnel)])
  expect_true(all(nchar(codici) == 4L))
  expect_true("CPUB" %in% codici)
})

# 7. Date e durate -----

test_that("gli avviamenti cadono nella finestra richiesta", {
  expect_true(all(cob$inizio >= as.Date("2019-01-01")))
  expect_true(all(cob$inizio <= as.Date("2024-12-31")))
  x <- generate_cob_sintetico(
    n_persone = 20, n_rapporti = 100,
    date_range = c("2021-06-01", "2021-12-31"), seed = 1
  )
  expect_true(all(x$inizio >= as.Date("2021-06-01") & x$inizio <= as.Date("2021-12-31")))
})

test_that("le durate hanno mediana attorno a 120 giorni e code pluriennali", {
  reg <- .righe_regolari(cob)
  durata <- as.integer(reg$fine - reg$inizio) + 1L
  expect_true(all(durata >= 1L))
  expect_equal(stats::median(durata), 120, tolerance = 0.3)
  expect_gte(sum(durata > 730L), 10L)
})

test_that("troncata vale 1 solo per rapporti clampati alla fine della finestra", {
  expect_true(all(cob$troncata %in% c(0L, 1L)))
  expect_true(all(cob[troncata == 1L, fine] == as.Date("2024-12-31")))
  expect_gte(sum(cob$troncata), 1L)
})

# 8. Valori di dominio -----

test_that("i codici e le categorie sono nel dominio atteso", {
  expect_true(all(cob$prior %in% c(0L, 1L)))
  expect_lt(abs(mean(cob$prior) - 0.70), 0.10)
  expect_true(all(cob$sesso %in% c("F", "M")))
  expect_true(all(cob$eta >= 18L & cob$eta <= 64L))
  expect_true(all(grepl("^[A-Z]\\.[0-9]{2}\\.[0-9]{2}$", cob$cod_tipologia_contrattuale)))
  expect_true(all(grepl("^[0-9]{2}\\.[0-9]$", cob$ateco_gruppo)))
  expect_true(all(grepl("^[0-9]{3}$", cob$qualifica)))
  expect_true(all(cob$comune_sede_lavoro %in% c(.belfiore_lombardia, .belfiore_fuori)))
  expect_true(all(cob$comune_lavoratore %in% c(.belfiore_lombardia, .belfiore_fuori)))
  expect_true(all(grepl("^DAT[0-9]{5}$", cob$datore)))
  expect_true(all(grepl("^CF[0-9]{5}$", cob$cf)))
})

test_that("le tipologie principali sono tutte rappresentate", {
  attese <- c("A.01.00", "A.02.00", "A.06.01", "A.03.09", "A.05.02")
  expect_true(all(attese %in% cob$cod_tipologia_contrattuale))
  quota_principali <- mean(cob$cod_tipologia_contrattuale %in% attese)
  expect_gte(quota_principali, 0.7)
})

test_that("ore: full-time su valori contrattuali, part-time fra 15 e 30, pochi NA", {
  ft <- cob[prior == 1L & !is.na(ore), ore]
  pt <- cob[prior == 0L & !is.na(ore), ore]
  expect_true(all(ft %in% c(36, 38, 40)))
  expect_true(all(pt >= 15 & pt <= 30))
  expect_lt(mean(is.na(cob$ore)), 0.05)
  expect_gte(sum(is.na(cob$ore)), 1L)
})

test_that("ogni CCNL ha un solo orario full-time di riferimento", {
  ore_per_ccnl <- cob[prior == 1L & !is.na(ore) & !is.na(codice_cnel),
    list(n_ore = data.table::uniqueN(ore)), by = codice_cnel]
  expect_true(all(ore_per_ccnl$n_ore == 1L))
})

test_that("la retribuzione regolare è log-normale attorno a 22000", {
  reg <- cob$retribuzione[!is.na(cob$retribuzione)]
  reg <- reg[reg >= 1000 & reg <= 1e6]
  expect_equal(stats::median(reg), 22000, tolerance = 0.25)
  expect_lt(stats::quantile(reg, 0.05), 12000)
  expect_gt(stats::quantile(reg, 0.95), 32000)
})

test_that("la distribuzione dei rapporti per persona è asimmetrica", {
  per_persona <- cob[, .N, by = cf]$N
  expect_gt(max(per_persona), 3 * stats::median(per_persona))
  expect_gte(sum(per_persona >= 2L), 0.8 * length(per_persona))
})

# 9. Errori -----

test_that("parametri non validi producono errore", {
  expect_error(generate_cob_sintetico(n_persone = 1))
  expect_error(generate_cob_sintetico(share_na_retribuzione = 1.2))
  expect_error(generate_cob_sintetico(share_sentinel = -0.1))
  expect_error(generate_cob_sintetico(date_range = c("2024-12-31", "2019-01-01")))
  expect_error(generate_cob_sintetico(date_range = "2019-01-01"))
})
