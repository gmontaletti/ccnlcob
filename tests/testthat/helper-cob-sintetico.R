# Generatore di dataset COB sintetici per i test di ccnlcob.
#
# generate_cob_sintetico() produce una tabella a livello di rapporto di lavoro
# con lo schema del contratto dati (piano_sviluppo.md, §4): anagrafica persone,
# CCNL con codice CNEL e codice warehouse, tipologie contrattuali MLPS,
# territorio (codici Belfiore), retribuzione con NA e valori anomali,
# sovrapposizioni intenzionali e sentinelle su `fine`. È deterministico dato
# `seed`. Lo stesso file viene letto da data-raw/cob_esempio.R per costruire
# il dataset `cob_esempio`.

.datatable.aware <- TRUE

# 1. Costanti di dominio -----

# Capoluoghi lombardi (codice Belfiore) con peso approssimativo di estrazione.
.cob_belfiore_lombardia <- c(
  F205 = 0.34, # Milano
  A794 = 0.08, # Bergamo
  B157 = 0.10, # Brescia
  C933 = 0.05, # Como
  D150 = 0.03, # Cremona
  E507 = 0.03, # Lecco
  E648 = 0.02, # Lodi
  E897 = 0.03, # Mantova
  F704 = 0.10, # Monza
  G388 = 0.05, # Pavia
  I829 = 0.02, # Sondrio
  L682 = 0.15  # Varese
)

# Comuni fuori Lombardia usati per la quota `share_fuori_lombardia`.
.cob_belfiore_fuori <- c("H501", "L219", "F952", "G535") # Roma, Torino, Novara, Piacenza

# Codici CNEL a 4 caratteri (stile cnelR); `CPUB` rappresenta il pubblico impiego.
.cob_pool_cnel <- c(
  "A011", "H011", "T011", "C011", "IC91", "A012", "B011", "D011", "E011",
  "F011", "G011", "H012", "I011", "K011", "L011", "M011", "N011", "P011",
  "Q011", "S011", "T012", "V011", "H013", "C012", "CPUB", "B012", "D012",
  "E012", "F012", "G012", "I012", "K012", "L012", "M012", "N012", "P012",
  "Q012", "S012", "T013", "V012"
)

# Tipologie contrattuali MLPS (ST-TIPO CONTRATTI) con pesi di estrazione.
# I codici A.06.xx (somministrazione) sono chiusi nella classificazione
# corrente ma presenti nello storico del warehouse.
.cob_tipologie_pesi <- c(
  "A.01.00" = 0.280, # lavoro a tempo indeterminato
  "A.02.00" = 0.300, # lavoro a tempo determinato
  "A.02.01" = 0.030, # tempo determinato per sostituzione
  "A.06.01" = 0.100, # somministrazione a tempo determinato
  "A.06.00" = 0.020, # somministrazione a tempo indeterminato
  "A.03.09" = 0.070, # apprendistato professionalizzante
  "A.03.08" = 0.010, # apprendistato per la qualifica e il diploma
  "A.03.10" = 0.005, # apprendistato di alta formazione e ricerca
  "A.05.02" = 0.080, # lavoro intermittente
  "A.04.02" = 0.020, # lavoro domestico
  "B.03.00" = 0.020, # collaborazione coordinata e continuativa
  "C.01.00" = 0.020, # tirocinio
  "B.04.00" = 0.005, # collaborazione occasionale sportiva
  "C.03.00" = 0.005, # lavoro socialmente utile
  "N.02.00" = 0.005  # tempo determinato con piattaforma
)

# Tipologie con quota di part-time più alta (prior = 0 più frequente).
.cob_tipologie_pt <- c("A.04.02", "A.05.02")

# Gruppi ATECO (2 cifre + 1) assegnati a livello di datore.
.cob_ateco <- c(
  "10.7", "13.2", "22.2", "25.6", "28.2", "41.2", "43.3", "45.2", "46.1",
  "47.1", "47.7", "49.4", "52.2", "55.1", "56.1", "56.3", "62.0", "69.2",
  "78.2", "81.2", "85.5", "86.1", "87.3", "88.9", "96.0"
)

# Qualifiche professionali a 3 cifre.
.cob_qualifiche <- sprintf("%03d", c(
  111, 132, 211, 253, 311, 332, 341, 411, 422, 431, 512, 522, 531, 541,
  611, 632, 712, 721, 742, 811, 813, 832, 842, 843
))

# 2. Funzioni di supporto -----

# Estrae `n` codici CNEL dal pool, estendendolo con codici fittizi se necessario.
.cob_codici_cnel <- function(n) {
  if (n <= length(.cob_pool_cnel)) {
    return(.cob_pool_cnel[seq_len(n)])
  }
  c(.cob_pool_cnel, sprintf("Z%03d", seq_len(n - length(.cob_pool_cnel))))
}

# Campiona `n` comuni lombardi, sostituendone una quota esatta con comuni
# fuori regione.
.cob_campiona_comuni <- function(n, share_fuori) {
  out <- sample(
    names(.cob_belfiore_lombardia), n,
    replace = TRUE, prob = .cob_belfiore_lombardia
  )
  n_fuori <- round(share_fuori * n)
  if (n_fuori > 0) {
    idx <- sample.int(n, n_fuori)
    out[idx] <- sample(.cob_belfiore_fuori, n_fuori, replace = TRUE)
  }
  out
}

# 3. Generatore -----

#' Genera un dataset COB sintetico a livello di rapporto di lavoro
#'
#' @param n_persone numero di persone (`cf`) distinte.
#' @param n_rapporti numero di rapporti (righe).
#' @param n_ccnl numero di CCNL distinti con codice CNEL.
#' @param date_range vettore di due date (o stringhe) che delimitano gli
#'   avviamenti.
#' @param share_na_retribuzione quota di righe con `retribuzione` NA.
#' @param share_outlier quota di righe con `retribuzione` implausibile.
#' @param share_fuori_lombardia quota di sedi di lavoro fuori Lombardia.
#' @param share_sentinel quota di righe con `fine = 9999-12-31`.
#' @param share_ccnl_na quota di righe con `codice_cnel` NA (solo codice
#'   warehouse).
#' @param seed seme per la riproducibilità.
#' @return `data.table` con le colonne del contratto dati (§4 del piano).
generate_cob_sintetico <- function(n_persone = 400,
                                   n_rapporti = 5000,
                                   n_ccnl = 25,
                                   date_range = c("2019-01-01", "2024-12-31"),
                                   share_na_retribuzione = 0.25,
                                   share_outlier = 0.02,
                                   share_fuori_lombardia = 0.05,
                                   share_sentinel = 0.03,
                                   share_ccnl_na = 0.15,
                                   seed = 20260908) {

  # 3.1 Parametri e controlli -----
  stopifnot(
    n_persone >= 2, n_rapporti >= 10, n_ccnl >= 1,
    length(date_range) == 2
  )
  quote <- c(
    share_na_retribuzione, share_outlier, share_fuori_lombardia,
    share_sentinel, share_ccnl_na
  )
  stopifnot(all(quote >= 0 & quote < 1))
  date_min <- as.Date(date_range[1])
  date_max <- as.Date(date_range[2])
  stopifnot(date_min < date_max)
  n_datori <- 600L
  set.seed(seed)

  # 3.2 Anagrafica persone -----
  persone <- data.table::data.table(
    person_idx = seq_len(n_persone),
    cf = sprintf("CF%05d", seq_len(n_persone)),
    eta_base = sample(18:58, n_persone, replace = TRUE),
    sesso = sample(c("F", "M"), n_persone, replace = TRUE, prob = c(0.47, 0.53)),
    comune_lavoratore = .cob_campiona_comuni(n_persone, share_fuori_lombardia),
    peso = stats::rexp(n_persone, rate = 1)
  )

  # 3.3 Anagrafica CCNL e codici warehouse -----
  n_unmatched <- max(3L, ceiling(n_ccnl * 0.3))
  wh_num <- sample(100:2999, n_ccnl + n_unmatched)
  wh_code <- data.table::fifelse(
    wh_num < 1000 & stats::runif(length(wh_num)) < 0.5,
    sprintf("%03d", wh_num),
    sprintf("%04d", wh_num)
  )
  ccnl_tab <- data.table::data.table(
    ccnl_idx = seq_len(n_ccnl),
    codice_cnel = .cob_codici_cnel(n_ccnl),
    ccnl = wh_code[seq_len(n_ccnl)],
    peso = 1 / seq_len(n_ccnl)^0.9,
    effetto = stats::rnorm(n_ccnl, mean = 0, sd = 0.15),
    ore_ft = sample(c(40, 38, 36), n_ccnl, replace = TRUE, prob = c(0.7, 0.2, 0.1))
  )
  ccnl_tab[codice_cnel == "CPUB", ore_ft := 36]
  wh_unmatched <- wh_code[n_ccnl + seq_len(n_unmatched)]

  # 3.4 Anagrafica datori -----
  datori <- data.table::data.table(
    datore_idx = seq_len(n_datori),
    datore = sprintf("DAT%05d", seq_len(n_datori)),
    ateco_gruppo = sample(.cob_ateco, n_datori, replace = TRUE),
    peso = stats::runif(n_datori)^(-1 / 1.5)
  )

  # 3.5 Assegnazione dei rapporti -----
  person_idx <- sample(n_persone, n_rapporti, replace = TRUE, prob = persone$peso)
  if (n_rapporti >= n_persone) {
    person_idx[seq_len(n_persone)] <- seq_len(n_persone)
  }
  ccnl_idx <- sample(n_ccnl, n_rapporti, replace = TRUE, prob = ccnl_tab$peso)
  datore_idx <- sample(n_datori, n_rapporti, replace = TRUE, prob = datori$peso)

  # 3.6 Date e durate -----
  giorni_finestra <- as.integer(date_max - date_min)
  inizio <- date_min + sample.int(giorni_finestra + 1L, n_rapporti, replace = TRUE) - 1L
  lunga <- stats::runif(n_rapporti) < 0.08
  durata <- data.table::fifelse(
    lunga,
    stats::rexp(n_rapporti, rate = 1 / 900),
    stats::rexp(n_rapporti, rate = log(2) / 125)
  )
  durata <- pmax(1L, as.integer(round(durata)))

  dt <- data.table::data.table(
    id = seq_len(n_rapporti),
    person_idx = person_idx,
    ccnl_idx = ccnl_idx,
    datore_idx = datore_idx,
    inizio = inizio,
    fine = inizio + durata - 1L
  )

  # 3.7 Sovrapposizioni per costruzione -----
  # Per almeno il 12% delle persone il secondo rapporto inizia prima della
  # fine del primo. I rapporti coinvolti sono esclusi dalle sentinelle.
  data.table::setorder(dt, person_idx, inizio, id)
  dt[, seq_persona := seq_len(.N), by = person_idx]
  dt[, overlap_flag := FALSE]
  con_due <- dt[seq_persona == 2L, person_idx]
  primi_ok <- dt[seq_persona == 1L & inizio <= date_max - 60L, person_idx]
  candidati <- intersect(con_due, primi_ok)
  n_target <- min(length(candidati), ceiling(0.12 * n_persone))
  if (n_target > 0) {
    scelti <- candidati[sample.int(length(candidati), n_target)]
    idx1 <- dt[seq_persona == 1L & person_idx %in% scelti, which = TRUE]
    idx2 <- dt[seq_persona == 2L & person_idx %in% scelti, which = TRUE]
    inizio_1 <- dt$inizio[idx1]
    durata_1 <- as.integer(dt$fine[idx1] - inizio_1) + 1L
    durata_1 <- pmin(pmax(durata_1, 30L), as.integer(date_max - inizio_1) + 1L)
    durata_2 <- pmax(as.integer(dt$fine[idx2] - dt$inizio[idx2]) + 1L, 10L)
    inizio_2 <- inizio_1 + durata_1 %/% 2L
    data.table::set(dt, i = idx1, j = "fine", value = inizio_1 + durata_1 - 1L)
    data.table::set(dt, i = idx2, j = "inizio", value = inizio_2)
    data.table::set(dt, i = idx2, j = "fine", value = inizio_2 + durata_2 - 1L)
    data.table::set(dt, i = c(idx1, idx2), j = "overlap_flag", value = TRUE)
  }

  # 3.8 Troncatura alla data di stabilizzazione -----
  dt[, troncata := as.integer(fine > date_max)]
  dt[troncata == 1L, fine := date_max]

  # 3.9 Tipologia contrattuale e orario -----
  dt[, cod_tipologia_contrattuale := sample(
    names(.cob_tipologie_pesi), .N,
    replace = TRUE, prob = .cob_tipologie_pesi
  )]
  dt[, p_ft := data.table::fifelse(cod_tipologia_contrattuale %in% .cob_tipologie_pt, 0.35, 0.74)]
  dt[, prior := as.integer(stats::runif(.N) < p_ft)]
  dt[ccnl_tab, on = "ccnl_idx", `:=`(
    ore_ft = i.ore_ft,
    effetto = i.effetto,
    codice_cnel = i.codice_cnel,
    ccnl = i.ccnl
  )]
  dt[, ore := data.table::fifelse(
    prior == 1L, ore_ft, as.numeric(sample(15:30, .N, replace = TRUE))
  )]
  idx_ore_na <- sample.int(n_rapporti, round(0.02 * n_rapporti))
  dt[idx_ore_na, ore := NA_real_]

  # 3.10 Retribuzione -----
  # Log-normale attorno a 22.000 euro annui lordi, con effetto CCNL, deriva
  # annua e riproporzionamento per i part-time.
  dt[, anno_rel := data.table::year(inizio) - data.table::year(date_min)]
  dt[, retribuzione := exp(
    log(22000) + effetto + 0.02 * anno_rel + stats::rnorm(.N, mean = 0, sd = 0.35)
  )]
  dt[prior == 0L, retribuzione := retribuzione *
    data.table::fifelse(is.na(ore), 0.55, ore / ore_ft)]
  dt[, retribuzione := round(retribuzione)]
  idx_na <- sample.int(n_rapporti, round(share_na_retribuzione * n_rapporti))
  dt[idx_na, retribuzione := NA_real_]
  resto <- setdiff(seq_len(n_rapporti), idx_na)
  n_out <- min(length(resto), round(share_outlier * n_rapporti))
  idx_out <- resto[sample.int(length(resto), n_out)]
  dt[idx_out, retribuzione := sample(
    c(0, 1, 12, 99, 350, 2.5e6, 5e6), .N, replace = TRUE
  )]

  # 3.11 Codice CNEL mancante -----
  # Le righe senza codice CNEL mantengono un codice warehouse non raccordato.
  idx_ccnl_na <- sample.int(n_rapporti, round(share_ccnl_na * n_rapporti))
  dt[idx_ccnl_na, `:=`(
    codice_cnel = NA_character_,
    ccnl = sample(wh_unmatched, .N, replace = TRUE)
  )]

  # 3.12 Territorio, datore e dimensioni aggiuntive -----
  dt[, comune_sede_lavoro := .cob_campiona_comuni(.N, share_fuori_lombardia)]
  dt[persone, on = "person_idx", `:=`(
    cf = i.cf,
    sesso = i.sesso,
    comune_lavoratore = i.comune_lavoratore,
    eta_base = i.eta_base
  )]
  dt[datori, on = "datore_idx", `:=`(datore = i.datore, ateco_gruppo = i.ateco_gruppo)]
  dt[, eta := pmin(64L, pmax(18L, eta_base + anno_rel))]
  dt[, qualifica := sample(.cob_qualifiche, .N, replace = TRUE)]

  # 3.13 Sentinelle e anomalie su fine -----
  disponibili <- dt[overlap_flag == FALSE, which = TRUE]
  n_9999 <- round(share_sentinel * n_rapporti)
  n_neg <- 2L
  n_1900 <- min(5L, max(0L, length(disponibili) - n_9999 - n_neg))
  stopifnot(length(disponibili) >= n_9999 + n_1900 + n_neg)
  scelti <- disponibili[sample.int(length(disponibili), n_9999 + n_1900 + n_neg)]
  idx_9999 <- scelti[seq_len(n_9999)]
  idx_1900 <- scelti[n_9999 + seq_len(n_1900)]
  idx_neg <- scelti[n_9999 + n_1900 + seq_len(n_neg)]
  dt[idx_9999, `:=`(fine = as.Date("9999-12-31"), troncata = 0L)]
  dt[idx_1900, `:=`(fine = as.Date("1900-01-01"), troncata = 0L)]
  dt[idx_neg, `:=`(fine = inizio - sample(5:60, .N, replace = TRUE), troncata = 0L)]

  # 3.14 Uscita -----
  data.table::setorder(dt, id)
  colonne <- c(
    "id", "cf", "inizio", "fine", "codice_cnel", "ccnl",
    "cod_tipologia_contrattuale", "prior", "comune_sede_lavoro",
    "comune_lavoratore", "datore", "retribuzione", "ore", "troncata",
    "qualifica", "ateco_gruppo", "eta", "sesso"
  )
  out <- dt[, colonne, with = FALSE]
  out[]
}
