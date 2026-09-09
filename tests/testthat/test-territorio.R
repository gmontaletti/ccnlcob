# Test di add_cpi() e ccnl_by_cpi() (R/territorio.R). Fase 2.
#
# Il lookup comune -> CPI è il dataset `cpi_esempio` (12 capoluoghi
# lombardi); i comuni fuori regione della fixture (H501, L219, F952, G535)
# non vi compaiono e devono ricevere il residuo FUORI. longworkR non viene
# mai chiamato, salvo un test guardato da skip_if_not_installed().

# 1. Fixture -----

fixture <- prepare_rapporti(generate_cob_sintetico(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
))

lookup_cpi <- .carica_dataset("cpi_esempio")

.fuori <- c("H501", "L219", "F952", "G535")

# Totali della misura `giornate` ricalcolati in modo indipendente.
.totali_giornate <- function(dt, dims, grp = character(0)) {
  list(
    ccnl = dt[, list(t = sum(giornate)), by = c(grp, "ccnl_key")],
    dim = dt[, list(t = sum(giornate)), by = c(grp, dims)],
    tot = dt[, list(t = sum(giornate)), by = grp]
  )
}

# Tabella con CPI di sede di lavoro già calcolato.
.con_cpi <- function(geo = "sede_lavoro") {
  dt <- data.table::copy(fixture)
  add_cpi(dt, geo = geo, lookup = lookup_cpi)
  dt
}

# 2. add_cpi(): comportamento per riferimento -----

test_that("add_cpi() aggiunge cpi_code e cpi_name per riferimento e restituisce dt invisibilmente", {
  dt <- data.table::copy(fixture)
  id_prima <- dt$id
  n_prima <- nrow(dt)
  out <- expect_invisible(add_cpi(dt, lookup = lookup_cpi))
  expect_identical(data.table::address(out), data.table::address(dt))
  expect_true(all(c("cpi_code", "cpi_name") %in% names(dt)))
  expect_type(dt$cpi_code, "character")
  expect_type(dt$cpi_name, "character")
  expect_identical(nrow(dt), n_prima)
  expect_identical(dt$id, id_prima)
  expect_false(anyNA(dt$cpi_code))
  expect_false(anyNA(dt$cpi_name))
})

test_that("add_cpi() con geo = sede_lavoro mappa i comuni del lookup e FUORI per gli altri", {
  dt <- .con_cpi("sede_lavoro")
  atteso_code <- lookup_cpi$cpi_code[match(
    dt$comune_sede_lavoro,
    lookup_cpi$belfiore
  )]
  atteso_name <- lookup_cpi$cpi_name[match(
    dt$comune_sede_lavoro,
    lookup_cpi$belfiore
  )]
  in_lookup <- !is.na(atteso_code)
  expect_true(any(in_lookup))
  expect_true(any(!in_lookup))
  expect_identical(dt$cpi_code[in_lookup], atteso_code[in_lookup])
  expect_identical(dt$cpi_name[in_lookup], atteso_name[in_lookup])
  expect_true(all(dt$comune_sede_lavoro[!in_lookup] %in% .fuori))
  expect_true(all(dt$cpi_code[!in_lookup] == "FUORI"))
  expect_true(all(dt$cpi_name[!in_lookup] == "Fuori Lombardia"))
  expect_identical(
    attr(dt, "ccnlcob_cpi"),
    list(geo = "sede_lavoro", source = "lookup")
  )
})

test_that("add_cpi() con geo = residenza usa comune_lavoratore", {
  dt <- .con_cpi("residenza")
  atteso <- lookup_cpi$cpi_code[match(
    dt$comune_lavoratore,
    lookup_cpi$belfiore
  )]
  atteso[is.na(atteso)] <- "FUORI"
  expect_identical(dt$cpi_code, atteso)
  expect_identical(attr(dt, "ccnlcob_cpi")$geo, "residenza")
  # la sede di lavoro non conta
  sede <- .con_cpi("sede_lavoro")
  expect_false(identical(dt$cpi_code, sede$cpi_code))
})

test_that("add_cpi() assegna ND ai codici Belfiore mancanti e sovrascrive colonne esistenti", {
  dt <- data.table::copy(fixture)
  dt[1:5, comune_sede_lavoro := NA_character_]
  dt[, cpi_code := "VECCHIO"]
  dt[, cpi_name := "Vecchio"]
  add_cpi(dt, lookup = lookup_cpi)
  expect_identical(dt$cpi_code[1:5], rep("ND", 5L))
  expect_identical(dt$cpi_name[1:5], rep("Non disponibile", 5L))
  expect_false(any(dt$cpi_code == "VECCHIO"))
  expect_identical(dt$id, fixture$id)
})

test_that("add_cpi() non duplica né riordina le righe con un lookup non ordinato", {
  dt <- data.table::copy(fixture)
  data.table::setorder(dt, -id)
  id_prima <- dt$id
  lookup_disordinato <- lookup_cpi[sample.int(nrow(lookup_cpi))]
  add_cpi(dt, lookup = lookup_disordinato)
  expect_identical(nrow(dt), nrow(fixture))
  expect_identical(dt$id, id_prima)
  expect_identical(
    dt$cpi_code,
    .con_cpi()[match(dt$id, id)]$cpi_code
  )
})

test_that("add_cpi() accetta un lookup senza cpi_name e come data.frame", {
  lk <- as.data.frame(lookup_cpi[, list(belfiore, cpi_code)])
  dt <- data.table::copy(fixture)
  add_cpi(dt, lookup = lk)
  in_lookup <- dt$comune_sede_lavoro %in% lk$belfiore
  expect_identical(dt$cpi_name[in_lookup], dt$cpi_code[in_lookup])
  expect_true(all(dt$cpi_name[!in_lookup] == "Fuori Lombardia"))
})

test_that("add_cpi() funziona su una tabella vuota", {
  dt <- fixture[0]
  add_cpi(dt, lookup = lookup_cpi)
  expect_identical(nrow(dt), 0L)
  expect_true(all(c("cpi_code", "cpi_name") %in% names(dt)))
})

# 3. add_cpi(): errori -----

test_that("add_cpi() rifiuta input non data.table e colonne geografiche assenti", {
  expect_error(
    add_cpi(as.data.frame(fixture), lookup = lookup_cpi),
    "data.table"
  )
  expect_error(
    add_cpi(
      data.table::copy(fixture)[, !"comune_sede_lavoro"],
      lookup = lookup_cpi
    ),
    "comune_sede_lavoro"
  )
  expect_error(
    add_cpi(
      data.table::copy(fixture)[, !"comune_lavoratore"],
      geo = "residenza",
      lookup = lookup_cpi
    ),
    "comune_lavoratore"
  )
  expect_error(add_cpi(data.table::copy(fixture), geo = "provincia"), "arg")
  expect_error(
    add_cpi(data.table::copy(fixture), lookup = lookup_cpi, quiet = NA),
    "quiet"
  )
})

test_that("add_cpi() valida il lookup", {
  dt <- data.table::copy(fixture)
  expect_error(add_cpi(dt, lookup = list(a = 1)), "lookup")
  expect_error(
    add_cpi(
      dt,
      lookup = data.table::data.table(comune = "F205", cpi_code = "X")
    ),
    "belfiore"
  )
  expect_error(
    add_cpi(dt, lookup = data.table::data.table(belfiore = "F205")),
    "cpi_code"
  )
  duplicato <- data.table::rbindlist(list(lookup_cpi, lookup_cpi[1]))
  expect_error(add_cpi(dt, lookup = duplicato), "duplicati")
  # l'input resta intatto dopo un errore
  expect_false("cpi_code" %in% names(dt))
})

# 4. add_cpi(): percorso longworkR -----

test_that("add_cpi() senza lookup coincide con cpi_esempio sui codici della fixture", {
  # longworkR < 0.10.1 chiamava fread() senza importarlo e falliva se
  # data.table non era attaccato: il test richiede la versione corretta e
  # gira senza attaccare data.table.
  skip_if_not_installed("longworkR", "0.10.1")
  skip_if_not(file.exists(file.path(
    Sys.getenv("SHARED_DATA_DIR", "~/Documents/funzioni/shared_data"),
    "maps",
    "comune_cpi_lookup.rds"
  )))
  skip_if("package:data.table" %in% search())
  dt <- data.table::copy(fixture)
  expect_silent(add_cpi(dt, quiet = TRUE))
  expect_identical(attr(dt, "ccnlcob_cpi")$source, "longworkR")
  expect_identical(dt$id, fixture$id)
  atteso <- .con_cpi()
  expect_identical(dt$cpi_code, atteso$cpi_code)
  expect_identical(dt$cpi_name, atteso$cpi_name)
})

# 5. ccnl_by_cpi(): struttura -----

test_that("ccnl_by_cpi() restituisce le colonne attese, l'attributo e non modifica dt", {
  dt <- data.table::copy(fixture)
  out <- ccnl_by_cpi(dt, lookup = lookup_cpi)
  expect_s3_class(out, "data.table")
  expect_identical(
    names(out),
    c(
      "ccnl_key",
      "classe",
      "cpi_code",
      "cpi_name",
      "giornate",
      "quota_riga",
      "quota_colonna",
      "lq"
    )
  )
  expect_identical(dt, fixture)
  expect_false("cpi_code" %in% names(dt))
  expect_identical(
    attr(out, "ccnlcob_crosstab"),
    list(
      measure = "giornate",
      dims = c("cpi_code", "cpi_name"),
      by = NULL,
      periodo = NULL,
      min_n = 30L,
      geo = "sede_lavoro"
    )
  )
  expect_identical(unique(out$classe[!is.na(out$ccnl_key)]), "CCNL")
  expect_identical(unique(out$classe[is.na(out$ccnl_key)]), "Non classificati")
  expect_true("FUORI" %in% out$cpi_code)
  # una riga per (ccnl_key, cpi_code)
  expect_false(anyDuplicated(out, by = c("ccnl_key", "cpi_code")) > 0L)
  # non classificati in coda, misura decrescente entro chiave
  expect_true(all(
    which(is.na(out$ccnl_key)) > max(which(!is.na(out$ccnl_key)))
  ))
  expect_true(all(out[, diff(giornate) <= 0, by = ccnl_key]$V1))
})

test_that("ccnl_by_cpi() accetta tutte le misure e rifiuta le altre", {
  dt <- .con_cpi()
  for (m in c("n_rapporti", "n_lavoratori", "n_datori", "giornate", "stock")) {
    out <- ccnl_by_cpi(dt, measure = m)
    expect_true(m %in% names(out))
    expect_identical(attr(out, "ccnlcob_crosstab")$measure, m)
  }
  expect_error(ccnl_by_cpi(dt, measure = "retribuzione"), "Misura non ammessa")
  expect_error(ccnl_by_cpi(dt, measure = c("giornate", "stock")), "singola")
  expect_error(
    ccnl_by_cpi(dt, measure = "giornate_effettive"),
    "giornate_effettive"
  )
})

# 6. ccnl_by_cpi(): invarianti -----

test_that("ccnl_by_cpi(): quota_riga somma a 1 entro CCNL e quota_colonna entro CPI", {
  out <- ccnl_by_cpi(fixture, lookup = lookup_cpi)
  righe <- out[, list(s = sum(quota_riga)), by = ccnl_key]$s
  colonne <- out[, list(s = sum(quota_colonna)), by = cpi_code]$s
  expect_equal(righe, rep(1, length(righe)), tolerance = 1e-12)
  expect_equal(colonne, rep(1, length(colonne)), tolerance = 1e-12)
})

test_that("ccnl_by_cpi(): lq coerente con i totali ricalcolati e media ponderata pari a 1", {
  dt <- .con_cpi()
  out <- ccnl_by_cpi(dt, min_n = 0L)
  tot <- .totali_giornate(dt, "cpi_code")
  out[tot$ccnl, on = "ccnl_key", totale_ccnl := i.t]
  out[tot$dim, on = "cpi_code", totale_dim := i.t]
  out[, totale := tot$tot$t]
  atteso <- (out$giornate / out$totale_dim) / (out$totale_ccnl / out$totale)
  expect_equal(out$lq, atteso, tolerance = 1e-12)
  expect_false(anyNA(out$lq))
  media <- out[, list(m = sum(lq * totale_dim / totale)), by = ccnl_key]$m
  expect_equal(media, rep(1, length(media)), tolerance = 1e-12)
})

test_that("ccnl_by_cpi(): min_n maschera lq con NA senza eliminare righe", {
  dt <- .con_cpi()
  tutto <- ccnl_by_cpi(dt, min_n = 0L)
  mascherato <- ccnl_by_cpi(dt, min_n = 1e9)
  expect_identical(nrow(mascherato), nrow(tutto))
  expect_true(all(is.na(mascherato$lq)))
  expect_equal(mascherato$quota_riga, tutto$quota_riga, tolerance = 1e-12)
  # soglia intermedia: NA esattamente dove il totale del CPI è sotto soglia
  tot_dim <- dt[, list(t = sum(giornate)), by = cpi_code]
  soglia <- stats::median(tot_dim$t)
  parziale <- ccnl_by_cpi(dt, min_n = soglia)
  sotto <- tot_dim$cpi_code[tot_dim$t < soglia]
  expect_identical(is.na(parziale$lq), parziale$cpi_code %in% sotto)
  expect_error(ccnl_by_cpi(dt, min_n = -1), "min_n")
  expect_error(ccnl_by_cpi(dt, min_n = NA), "min_n")
})

test_that("ccnl_by_cpi(): giornate per CCNL sommate sui CPI coincidono con rank_ccnl()", {
  # Vale per le misure additive (giornate, n_rapporti, stock); non per
  # n_lavoratori e n_datori, perché la stessa persona (o datore) può comparire
  # in più CPI e viene contata in ciascuno.
  dt <- .con_cpi()
  out <- ccnl_by_cpi(dt, measure = "giornate")
  ranking <- rank_ccnl(dt, measures = "giornate")
  somme <- out[, list(giornate = sum(giornate)), by = ccnl_key]
  confronto <- merge(
    somme,
    ranking[, list(ccnl_key, giornate)],
    by = "ccnl_key"
  )
  expect_identical(nrow(confronto), nrow(ranking))
  expect_identical(confronto$giornate.x, confronto$giornate.y)
})

# 7. ccnl_by_cpi(): filtro ccnl, periodo e by -----

test_that("ccnl_by_cpi(): il filtro ccnl conserva i totali e avvisa sulle chiavi ignote", {
  dt <- .con_cpi()
  tutto <- ccnl_by_cpi(dt)
  chiavi <- head(unique(stats::na.omit(dt$ccnl_key)), 2L)
  parziale <- ccnl_by_cpi(dt, ccnl = chiavi)
  expect_identical(sort(unique(parziale$ccnl_key)), sort(chiavi))
  attese <- tutto[ccnl_key %in% chiavi]
  data.table::setorder(attese, ccnl_key, cpi_code)
  data.table::setorder(parziale, ccnl_key, cpi_code)
  expect_identical(parziale$giornate, attese$giornate)
  expect_equal(parziale$quota_riga, attese$quota_riga, tolerance = 1e-12)
  expect_equal(parziale$quota_colonna, attese$quota_colonna, tolerance = 1e-12)
  expect_equal(parziale$lq, attese$lq, tolerance = 1e-12)
  # NA fra le chiavi conserva i non classificati
  con_na <- ccnl_by_cpi(dt, ccnl = c(chiavi[1L], NA))
  expect_true(any(is.na(con_na$ccnl_key)))
  expect_identical(
    sort(unique(con_na$ccnl_key), na.last = TRUE),
    c(chiavi[1L], NA)
  )
  expect_warning(
    ignoto <- ccnl_by_cpi(dt, ccnl = c(chiavi[1L], "ZZZZ")),
    "ZZZZ"
  )
  expect_identical(unique(ignoto$ccnl_key), chiavi[1L])
  expect_error(ccnl_by_cpi(dt, ccnl = 1:3), "ccnl")
})

test_that("ccnl_by_cpi(): periodo e by aggiungono le colonne di gruppo con quote entro gruppo", {
  dt <- .con_cpi()
  per_anno <- ccnl_by_cpi(dt, periodo = "anno")
  expect_identical(names(per_anno)[1:3], c("anno", "ccnl_key", "classe"))
  expect_identical(attr(per_anno, "ccnlcob_crosstab")$periodo, "anno")
  righe <- per_anno[, list(s = sum(quota_riga)), by = list(anno, ccnl_key)]$s
  colonne <- per_anno[,
    list(s = sum(quota_colonna)),
    by = list(anno, cpi_code)
  ]$s
  expect_equal(righe, rep(1, length(righe)), tolerance = 1e-12)
  expect_equal(colonne, rep(1, length(colonne)), tolerance = 1e-12)
  # le giornate per anno e CCNL coincidono con i totali indipendenti
  tot <- dt[, list(t = sum(giornate)), by = list(anno, ccnl_key)]
  somme <- per_anno[, list(t = sum(giornate)), by = list(anno, ccnl_key)]
  expect_identical(
    merge(tot, somme, by = c("anno", "ccnl_key"))[, identical(t.x, t.y)],
    TRUE
  )

  per_sesso <- ccnl_by_cpi(dt, by = "sesso", periodo = "trimestre")
  expect_identical(names(per_sesso)[1:2], c("sesso", "trimestre"))
  expect_identical(attr(per_sesso, "ccnlcob_crosstab")$by, "sesso")
  righe <- per_sesso[,
    list(s = sum(quota_riga)),
    by = list(sesso, trimestre, ccnl_key)
  ]$s
  expect_equal(righe, rep(1, length(righe)), tolerance = 1e-12)

  expect_error(ccnl_by_cpi(dt, periodo = "mese"), "periodo")
  expect_error(ccnl_by_cpi(dt, by = "inesistente"), "inesistente")
  expect_error(ccnl_by_cpi(dt, by = "ccnl_key"), "ccnl_key")
  expect_error(ccnl_by_cpi(dt, by = "cpi_code"), "dimensioni")
  expect_error(ccnl_by_cpi(dt, by = "anno", periodo = "anno"), "periodo")
})

# 8. ccnl_by_cpi(): CPI preesistente e geo -----

test_that("ccnl_by_cpi() usa cpi_code se presente, altrimenti calcola il CPI con geo", {
  residenza <- .con_cpi("residenza")
  # con cpi_code presente, geo e lookup sono ignorati
  da_colonna <- ccnl_by_cpi(
    residenza,
    geo = "sede_lavoro",
    lookup = lookup_cpi[1]
  )
  da_geo <- ccnl_by_cpi(fixture, geo = "residenza", lookup = lookup_cpi)
  expect_identical(da_colonna$cpi_code, da_geo$cpi_code)
  expect_identical(da_colonna$giornate, da_geo$giornate)
  sede <- ccnl_by_cpi(fixture, geo = "sede_lavoro", lookup = lookup_cpi)
  expect_false(identical(sede$giornate, da_geo$giornate))
  expect_identical(attr(da_geo, "ccnlcob_crosstab")$geo, "residenza")
  # cpi_code con NA e senza cpi_name: ND e nome uguale al codice
  parziale <- data.table::copy(residenza)[, cpi_name := NULL]
  parziale[1:10, cpi_code := NA_character_]
  out <- ccnl_by_cpi(parziale)
  expect_true("ND" %in% out$cpi_code)
  nd <- out$cpi_code == "ND"
  expect_identical(unique(out$cpi_name[nd]), "Non disponibile")
  expect_identical(out$cpi_name[!nd], out$cpi_code[!nd])
})

test_that("ccnl_by_cpi() segnala colonne mancanti e lookup non validi", {
  expect_error(
    ccnl_by_cpi(data.table::copy(fixture)[, !"ccnl_key"], lookup = lookup_cpi),
    "prepare_rapporti"
  )
  expect_error(
    ccnl_by_cpi(data.table::copy(fixture)[, !"giornate"], lookup = lookup_cpi),
    "giornate"
  )
  expect_error(
    ccnl_by_cpi(
      data.table::copy(fixture)[, !"comune_sede_lavoro"],
      lookup = lookup_cpi
    ),
    "comune_sede_lavoro"
  )
  expect_error(
    ccnl_by_cpi(fixture, lookup = data.table::data.table(comune = "F205")),
    "belfiore"
  )
  expect_error(ccnl_by_cpi(list(a = 1)), "data.table")
})
