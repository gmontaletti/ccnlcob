# Test di ccnl_by_tipologia() e classify_tipologia() (R/tipologie.R).
# Fase 1 (classify_tipologia) e Fase 2 (ccnl_by_tipologia).

# 1. Fixture -----

fixture <- generate_cob_sintetico(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
)

tipologie <- .carica_dataset("tipologie_contrattuali")

# 2. classify_tipologia() -----

test_that("classify_tipologia() traduce i codici noti nella macro-classe del lookup", {
  expect_identical(classify_tipologia("A.01.00"), "Tempo indeterminato")
  expect_identical(classify_tipologia("C.01.00"), "Tirocinio")
  out <- classify_tipologia(c(
    "A.01.00",
    "A.02.00",
    "A.03.09",
    "A.06.01",
    "C.01.00"
  ))
  expect_identical(
    out,
    c(
      "Tempo indeterminato",
      "Tempo determinato",
      "Apprendistato",
      "Somministrazione",
      "Tirocinio"
    )
  )
})

test_that("classify_tipologia() conserva lunghezza e ordine e restituisce NA per codici ignoti o NA", {
  codici <- c("C.01.00", "ZZZ", NA, "A.01.00", "", "a.01.00")
  out <- classify_tipologia(codici)
  expect_type(out, "character")
  expect_identical(length(out), length(codici))
  expect_identical(out, c("Tirocinio", NA, NA, "Tempo indeterminato", NA, NA))
  expect_identical(classify_tipologia(character(0)), character(0))
  expect_identical(classify_tipologia(NA), NA_character_)
})

test_that("classify_tipologia() copre tutti i codici del lookup e quelli della fixture", {
  out <- classify_tipologia(
    tipologie$cod_tipologia_contrattuale,
    tipologie = tipologie
  )
  expect_identical(out, tipologie$macro_tipologia)
  expect_false(anyNA(classify_tipologia(fixture$cod_tipologia_contrattuale)))
})

test_that("classify_tipologia() accetta factor e un lookup alternativo", {
  lookup <- data.frame(
    cod_tipologia_contrattuale = c("X.01", "X.02", "X.01"),
    macro_tipologia = c("Classe X1", "Classe X2", "Duplicato"),
    stringsAsFactors = FALSE
  )
  out <- classify_tipologia(c("X.02", "X.01", "A.01.00"), tipologie = lookup)
  expect_identical(out, c("Classe X2", "Classe X1", NA))
  out_dt <- classify_tipologia(
    "X.02",
    tipologie = data.table::as.data.table(lookup)
  )
  expect_identical(out_dt, "Classe X2")
  out_factor <- classify_tipologia(factor(c("A.01.00", "C.01.00")))
  expect_identical(out_factor, c("Tempo indeterminato", "Tirocinio"))
})

test_that("classify_tipologia() rifiuta un lookup senza le colonne richieste e codici non character", {
  expect_error(
    classify_tipologia(
      "A.01.00",
      tipologie = data.frame(cod_tipologia_contrattuale = "A.01.00")
    ),
    "macro_tipologia"
  )
  expect_error(
    classify_tipologia("A.01.00", tipologie = list(a = 1)),
    "data.frame"
  )
  expect_error(classify_tipologia(1:3), "character")
})

# 3. Fixture preparata per ccnl_by_tipologia() -----

preparata <- prepare_rapporti(fixture)

# 4. ccnl_by_tipologia(): struttura -----

test_that("ccnl_by_tipologia() restituisce le colonne attese, l'attributo e non modifica dt", {
  dt <- data.table::copy(preparata)
  out <- ccnl_by_tipologia(dt)
  expect_s3_class(out, "data.table")
  expect_identical(
    names(out),
    c(
      "ccnl_key",
      "classe",
      "tipologia",
      "orario",
      "n_rapporti",
      "quota_riga",
      "quota_colonna",
      "lq"
    )
  )
  expect_identical(dt, preparata)
  expect_identical(
    attr(out, "ccnlcob_crosstab"),
    list(
      measure = "n_rapporti",
      dims = c("tipologia", "orario"),
      by = NULL,
      periodo = NULL,
      min_n = 30L,
      level = "macro",
      orario = TRUE
    )
  )
  expect_true(all(out$tipologia %in% tipologie$macro_tipologia))
  expect_true(all(out$orario %in% c("FT", "PT")))
  expect_identical(unique(out$classe[is.na(out$ccnl_key)]), "Non classificati")
  expect_false(anyDuplicated(out, by = c("ccnl_key", "tipologia", "orario")) > 0L)
  expect_true(all(which(is.na(out$ccnl_key)) > max(which(!is.na(out$ccnl_key)))))
  expect_true(all(out[, diff(n_rapporti) <= 0, by = ccnl_key]$V1))
})

test_that("ccnl_by_tipologia(): orario = FALSE omette la dimensione e conserva i totali", {
  con <- ccnl_by_tipologia(preparata)
  senza <- ccnl_by_tipologia(preparata, orario = FALSE)
  expect_false("orario" %in% names(senza))
  expect_identical(attr(senza, "ccnlcob_crosstab")$dims, "tipologia")
  expect_false(attr(senza, "ccnlcob_crosstab")$orario)
  somme <- con[, list(n_rapporti = sum(n_rapporti)), by = list(ccnl_key, tipologia)]
  confronto <- merge(somme, senza, by = c("ccnl_key", "tipologia"))
  expect_identical(nrow(confronto), nrow(senza))
  expect_identical(confronto$n_rapporti.x, confronto$n_rapporti.y)
})

test_that("ccnl_by_tipologia(): level = codice usa il codice MLPS con la descrizione del lookup", {
  out <- ccnl_by_tipologia(preparata, level = "codice", orario = FALSE)
  expect_identical(
    names(out)[3:4],
    c("tipologia", "des_tipologia_contrattuale")
  )
  expect_identical(attr(out, "ccnlcob_crosstab")$level, "codice")
  expect_true(all(out$tipologia %in% preparata$cod_tipologia_contrattuale))
  attese <- tipologie$des_tipologia_contrattuale[match(
    out$tipologia,
    tipologie$cod_tipologia_contrattuale
  )]
  expect_identical(out$des_tipologia_contrattuale, attese)
  expect_false(anyNA(out$des_tipologia_contrattuale))
  # codice mancante -> "ND" senza descrizione; codice ignoto -> descrizione NA
  dt <- data.table::copy(preparata)
  dt[1:3, cod_tipologia_contrattuale := NA_character_]
  dt[4:6, cod_tipologia_contrattuale := "ZZZ"]
  out_na <- ccnl_by_tipologia(dt, level = "codice", orario = FALSE)
  expect_true("ND" %in% out_na$tipologia)
  expect_true("ZZZ" %in% out_na$tipologia)
  expect_true(all(is.na(out_na[tipologia %in% c("ND", "ZZZ")]$des_tipologia_contrattuale)))
  expect_identical(sum(out_na$n_rapporti), sum(preparata$avviato))
})

test_that("ccnl_by_tipologia(): tipologie ignote formano 'Non classificata' e orario mancante 'ND'", {
  dt <- data.table::copy(preparata)
  dt[1:4, cod_tipologia_contrattuale := "ZZZ"]
  dt[, macro_tipologia := classify_tipologia(cod_tipologia_contrattuale)]
  dt[5:6, prior := NA_integer_]
  dt[5:6, orario := NA_character_]
  out <- ccnl_by_tipologia(dt)
  expect_true("Non classificata" %in% out$tipologia)
  expect_true("ND" %in% out$orario)
  expect_identical(sum(out$n_rapporti), sum(preparata$avviato))
})

test_that("ccnl_by_tipologia() ricalcola macro_tipologia e orario se assenti", {
  atteso <- ccnl_by_tipologia(preparata)
  ridotta <- data.table::copy(preparata)[, c("macro_tipologia", "orario") := NULL]
  out <- ccnl_by_tipologia(ridotta)
  expect_identical(out$tipologia, atteso$tipologia)
  expect_identical(out$orario, atteso$orario)
  expect_identical(out$n_rapporti, atteso$n_rapporti)
  expect_error(
    ccnl_by_tipologia(data.table::copy(ridotta)[, prior := NULL]),
    "prior"
  )
  expect_error(
    ccnl_by_tipologia(data.table::copy(ridotta)[, cod_tipologia_contrattuale := NULL]),
    "cod_tipologia_contrattuale"
  )
})

# 5. ccnl_by_tipologia(): invarianti -----

test_that("ccnl_by_tipologia(): quota_riga somma a 1 entro CCNL e quota_colonna entro cella", {
  out <- ccnl_by_tipologia(preparata, measure = "giornate")
  righe <- out[, list(s = sum(quota_riga)), by = ccnl_key]$s
  colonne <- out[, list(s = sum(quota_colonna)), by = list(tipologia, orario)]$s
  expect_equal(righe, rep(1, length(righe)), tolerance = 1e-12)
  expect_equal(colonne, rep(1, length(colonne)), tolerance = 1e-12)
})

test_that("ccnl_by_tipologia(): lq coerente con i totali ricalcolati e media ponderata pari a 1", {
  out <- ccnl_by_tipologia(preparata, measure = "giornate", orario = FALSE, min_n = 0L)
  tot_ccnl <- preparata[, list(t = sum(giornate)), by = ccnl_key]
  tot_dim <- preparata[, list(t = sum(giornate)), by = list(tipologia = macro_tipologia)]
  totale <- sum(preparata$giornate)
  out[tot_ccnl, on = "ccnl_key", totale_ccnl := i.t]
  out[tot_dim, on = "tipologia", totale_dim := i.t]
  atteso <- (out$giornate / out$totale_dim) / (out$totale_ccnl / totale)
  expect_equal(out$lq, atteso, tolerance = 1e-12)
  expect_false(anyNA(out$lq))
  media <- out[, list(m = sum(lq * totale_dim / totale)), by = ccnl_key]$m
  expect_equal(media, rep(1, length(media)), tolerance = 1e-12)
})

test_that("ccnl_by_tipologia(): min_n maschera lq senza eliminare righe", {
  tutto <- ccnl_by_tipologia(preparata, min_n = 0L)
  mascherato <- ccnl_by_tipologia(preparata, min_n = 1e9)
  expect_identical(nrow(mascherato), nrow(tutto))
  expect_true(all(is.na(mascherato$lq)))
  expect_identical(mascherato$n_rapporti, tutto$n_rapporti)
  tot_dim <- preparata[avviato == TRUE, .N, by = list(macro_tipologia, orario)]
  soglia <- stats::median(tot_dim$N)
  parziale <- ccnl_by_tipologia(preparata, min_n = soglia)
  sotto <- tot_dim[N < soglia]
  attesi_na <- paste(parziale$tipologia, parziale$orario) %in%
    paste(sotto$macro_tipologia, sotto$orario)
  expect_equal(is.na(parziale$lq), attesi_na)
})

test_that("ccnl_by_tipologia(): giornate per CCNL sommate sulle tipologie coincidono con rank_ccnl()", {
  # Vale per le misure additive; non per n_lavoratori e n_datori, perché la
  # stessa persona può comparire in più tipologie ed è contata in ciascuna.
  out <- ccnl_by_tipologia(preparata, measure = "giornate")
  ranking <- rank_ccnl(preparata, measures = "giornate")
  somme <- out[, list(giornate = sum(giornate)), by = ccnl_key]
  confronto <- merge(somme, ranking[, list(ccnl_key, giornate)], by = "ccnl_key")
  expect_equal(nrow(confronto), nrow(ranking))
  expect_equal(confronto$giornate.x, confronto$giornate.y)
  # n_lavoratori: la somma sulle celle è >= al conteggio distinto del ranking
  out_lav <- ccnl_by_tipologia(preparata, measure = "n_lavoratori")
  rank_lav <- rank_ccnl(preparata, measures = "n_lavoratori")
  somme_lav <- out_lav[, list(n = sum(n_lavoratori)), by = ccnl_key]
  confronto_lav <- merge(somme_lav, rank_lav[, list(ccnl_key, n_lavoratori)], by = "ccnl_key")
  expect_true(all(confronto_lav$n >= confronto_lav$n_lavoratori))
})

# 6. ccnl_by_tipologia(): filtro ccnl, periodo e by -----

test_that("ccnl_by_tipologia(): il filtro ccnl conserva le quote e avvisa sulle chiavi ignote", {
  tutto <- ccnl_by_tipologia(preparata)
  chiavi <- head(unique(stats::na.omit(preparata$ccnl_key)), 2L)
  parziale <- ccnl_by_tipologia(preparata, ccnl = chiavi)
  expect_identical(sort(unique(parziale$ccnl_key)), sort(chiavi))
  attese <- tutto[ccnl_key %in% chiavi]
  data.table::setorder(attese, ccnl_key, tipologia, orario)
  data.table::setorder(parziale, ccnl_key, tipologia, orario)
  expect_identical(parziale$n_rapporti, attese$n_rapporti)
  expect_equal(parziale$quota_riga, attese$quota_riga, tolerance = 1e-12)
  expect_equal(parziale$quota_colonna, attese$quota_colonna, tolerance = 1e-12)
  expect_equal(parziale$lq, attese$lq, tolerance = 1e-12)
  expect_warning(
    ignoto <- ccnl_by_tipologia(preparata, ccnl = c(chiavi[1L], "ZZZZ")),
    "ZZZZ"
  )
  expect_identical(unique(ignoto$ccnl_key), chiavi[1L])
})

test_that("ccnl_by_tipologia(): periodo e by raggruppano con quote entro gruppo", {
  per_anno <- ccnl_by_tipologia(preparata, periodo = "anno", orario = FALSE)
  expect_identical(names(per_anno)[1:4], c("anno", "ccnl_key", "classe", "tipologia"))
  righe <- per_anno[, list(s = sum(quota_riga)), by = list(anno, ccnl_key)]$s
  colonne <- per_anno[, list(s = sum(quota_colonna)), by = list(anno, tipologia)]$s
  expect_equal(righe, rep(1, length(righe)), tolerance = 1e-12)
  expect_equal(colonne, rep(1, length(colonne)), tolerance = 1e-12)
  tot <- preparata[avviato == TRUE, .N, by = list(anno, ccnl_key)]
  somme <- per_anno[, list(N = sum(n_rapporti)), by = list(anno, ccnl_key)]
  confronto <- merge(tot, somme, by = c("anno", "ccnl_key"))
  expect_identical(nrow(confronto), nrow(tot))
  expect_identical(confronto$N.x, confronto$N.y)

  per_sesso <- ccnl_by_tipologia(preparata, by = "sesso")
  expect_identical(names(per_sesso)[1], "sesso")
  expect_identical(attr(per_sesso, "ccnlcob_crosstab")$by, "sesso")
  righe <- per_sesso[, list(s = sum(quota_riga)), by = list(sesso, ccnl_key)]$s
  expect_equal(righe, rep(1, length(righe)), tolerance = 1e-12)

  expect_error(ccnl_by_tipologia(preparata, periodo = "mese"), "periodo")
  expect_error(ccnl_by_tipologia(preparata, by = "tipologia"), "dimensioni")
  expect_error(ccnl_by_tipologia(preparata, by = "orario"), "dimensioni")
})

# 7. ccnl_by_tipologia(): errori -----

test_that("ccnl_by_tipologia() segnala misure, livelli, lookup e colonne non validi", {
  expect_error(ccnl_by_tipologia(preparata, measure = "quota"), "Misura non ammessa")
  expect_error(ccnl_by_tipologia(preparata, measure = c("giornate", "stock")), "singola")
  expect_error(ccnl_by_tipologia(preparata, level = "dettaglio"), "arg")
  expect_error(ccnl_by_tipologia(preparata, orario = NA), "orario")
  expect_error(
    ccnl_by_tipologia(preparata, tipologie = data.frame(cod_tipologia_contrattuale = "A.01.00")),
    "macro_tipologia"
  )
  expect_error(
    ccnl_by_tipologia(
      preparata,
      level = "codice",
      tipologie = tipologie[, list(cod_tipologia_contrattuale, macro_tipologia)]
    ),
    "des_tipologia_contrattuale"
  )
  expect_error(
    ccnl_by_tipologia(data.table::copy(preparata)[, ccnl_key := NULL]),
    "prepare_rapporti"
  )
  expect_error(
    ccnl_by_tipologia(data.table::copy(preparata)[, giornate := NULL]),
    "giornate"
  )
  expect_error(
    ccnl_by_tipologia(data.table::copy(preparata)[, datore := NULL], measure = "n_datori"),
    "datore"
  )
  expect_error(ccnl_by_tipologia(list(a = 1)), "data.table")
})
