# Test di integrazione della catena di Fase 1:
# generate_cob_sintetico() / cob_esempio -> prepare_rapporti() -> rank_ccnl()
# -> select_ccnl_rilevanti(). I risultati vengono confrontati con calcoli
# indipendenti in base R sui dati grezzi (sentinelle, finestra, giornate,
# misure per CCNL). I test unitari di ciascuna funzione stanno nei rispettivi
# file test-prepare.R, test-giornate.R e test-ranking.R.
#
# Le sezioni 2-9 usano `perimetro = "completo"`, che riproduce il
# comportamento delle versioni fino alla 0.2.0 (nessuna esclusione per
# tipologia): i calcoli indipendenti lavorano su tutte le righe grezze. Il
# perimetro CCNL di default e' verificato end to end nella sezione 10.

# 1. Fixture e calcoli indipendenti -----

cob <- .carica_dataset("cob_esempio")

.sent_min <- as.Date("1900-01-01")
.sent_max <- as.Date("9999-12-31")
.avvio_cob <- as.Date("2008-03-01")
.misure <- c("n_rapporti", "n_lavoratori", "giornate", "stock")

# Data di riferimento di default: massimo non sentinella fra inizio e fine.
.as_of_indipendente <- function(raw) {
  inizio <- as.Date(raw$inizio)
  fine <- as.Date(raw$fine)
  max(c(
    inizio[!is.na(inizio) & inizio > .sent_min],
    fine[!is.na(fine) & fine > .sent_min & fine < .sent_max]
  ))
}

# Applica in base R le regole documentate in prepare_rapporti(): sentinelle su
# fine, poi su inizio, poi fine < inizio sulle date già sostituite; quindi
# finestra (default: dal primo avviamento non sentinella ad as_of) e giornate
# con pmin/pmax sulle date tagliate.
.prepara_indipendente <- function(raw, as_of, window = NULL) {
  inizio <- as.Date(raw$inizio)
  fine <- as.Date(raw$fine)
  sent_fine <- is.na(fine) | fine <= .sent_min | fine > as_of
  fine[sent_fine] <- as_of
  sent_inizio <- is.na(inizio) | inizio <= .sent_min
  inizio[sent_inizio] <- .avvio_cob
  invertiti <- fine < inizio
  fine[invertiti] <- inizio[invertiti]
  if (is.null(window)) {
    window <- c(min(inizio[!sent_inizio]), as_of)
  }
  window <- as.Date(window)
  troncata_old <- if ("troncata" %in% names(raw)) {
    !is.na(raw$troncata) & raw$troncata == 1L
  } else {
    rep(FALSE, nrow(raw))
  }
  dentro <- inizio <= window[2] & fine >= window[1]
  giornate <- as.integer(pmin(fine, window[2]) - pmax(inizio, window[1])) + 1L
  righe <- data.frame(
    id = raw$id,
    cf = raw$cf,
    ccnl_key = raw$codice_cnel,
    inizio = inizio,
    fine = fine,
    troncata = as.integer(troncata_old | sent_fine),
    giornate = giornate,
    avviato = inizio >= window[1],
    attivo = inizio <= as_of & fine >= as_of,
    anno = as.integer(format(inizio, "%Y")),
    stringsAsFactors = FALSE
  )[dentro, ]
  list(
    as_of = as_of,
    window = window,
    n_sentinel_fine = sum(sent_fine),
    n_sentinel_inizio = sum(sent_inizio),
    n_fine_lt_inizio = sum(invertiti),
    n_dropped_window = sum(!dentro),
    righe = righe
  )
}

# Misure per CCNL in base R su una tabella con cf, ccnl_key, giornate,
# avviato, attivo; la chiave NA forma un gruppo a sé. Ordinata per chiave con
# NA in coda.
.misure_base <- function(tab) {
  chiavi <- unique(tab$ccnl_key)
  righe <- lapply(chiavi, function(k) {
    idx <- which(tab$ccnl_key %in% k)
    avviati <- idx[tab$avviato[idx]]
    data.frame(
      ccnl_key = k,
      n_rapporti = length(avviati),
      n_lavoratori = length(unique(tab$cf[avviati])),
      giornate = sum(tab$giornate[idx]),
      stock = sum(tab$attivo[idx]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, righe)
  out[order(out$ccnl_key, na.last = TRUE), ]
}

# Confronta chiave per chiave le misure di un ranking senza gruppi con quelle
# calcolate da .misure_base().
.expect_misure_uguali <- function(ranking, base, misure = .misure) {
  o <- order(ranking$ccnl_key, na.last = TRUE)
  expect_identical(ranking$ccnl_key[o], base$ccnl_key)
  for (m in misure) {
    expect_identical(as.integer(ranking[[m]][o]), as.integer(base[[m]]))
  }
  invisible(TRUE)
}

# Chiavi dei CCNL classificati nell'ordine usato dalla selezione:
# rank della misura, poi ccnl_key (base::order come in .select_group()).
.ordine_selezione <- function(ranking, measure) {
  cl <- ranking[ranking$classe == "CCNL", ]
  cl$ccnl_key[order(cl[[paste0("rank_", measure)]], cl$ccnl_key)]
}

prep <- prepare_rapporti(cob, perimetro = "completo")
ranking <- rank_ccnl(prep, measures = .misure)

# 2. prepare_rapporti() su cob_esempio -----

test_that("i metadati di prepare_rapporti() coincidono con i conteggi indipendenti sui dati grezzi", {
  meta <- attr(prep, "ccnlcob_meta")
  as_of <- .as_of_indipendente(cob)
  ind <- .prepara_indipendente(cob, as_of)

  expect_identical(meta$as_of, as_of)
  expect_identical(meta$window, ind$window)
  expect_identical(meta$ccnl_key, "codice_cnel")
  expect_identical(meta$perimetro, "completo")
  expect_identical(meta$n_input, nrow(cob))
  expect_identical(meta$n_dropped_perimetro, 0L)
  expect_identical(meta$n_tipologia_ignota, 0L)
  expect_identical(nrow(meta$esclusi_perimetro), 0L)
  expect_identical(meta$n_sentinel_fine, ind$n_sentinel_fine)
  expect_identical(meta$n_sentinel_inizio, ind$n_sentinel_inizio)
  expect_identical(meta$n_fine_lt_inizio, ind$n_fine_lt_inizio)
  expect_identical(meta$n_dropped_window, ind$n_dropped_window)
  expect_identical(nrow(prep), meta$n_input - meta$n_dropped_window)

  # conteggio diretto sulle sentinelle presenti nella fixture
  expect_identical(
    meta$n_sentinel_fine,
    sum(cob$fine == .sent_max | cob$fine == .sent_min | cob$fine > as_of)
  )
  expect_identical(
    meta$n_fine_lt_inizio,
    sum(cob$fine < cob$inizio & cob$fine > .sent_min)
  )
  expect_gt(meta$n_sentinel_fine, 0L)
  expect_gt(meta$n_fine_lt_inizio, 0L)
})

test_that("date, giornate e flag di prepare_rapporti() coincidono riga per riga con il calcolo indipendente", {
  meta <- attr(prep, "ccnlcob_meta")
  ind <- .prepara_indipendente(cob, .as_of_indipendente(cob))
  expect_identical(sort(prep$id), sort(ind$righe$id))
  righe <- ind$righe[match(prep$id, ind$righe$id), ]

  expect_identical(as.Date(prep$inizio), righe$inizio)
  expect_identical(as.Date(prep$fine), righe$fine)
  expect_identical(prep$giornate, righe$giornate)
  expect_identical(sum(prep$giornate), sum(righe$giornate))
  expect_identical(prep$troncata, righe$troncata)
  expect_identical(prep$avviato, righe$avviato)
  expect_identical(prep$attivo, righe$attivo)
  expect_identical(prep$anno, righe$anno)

  expect_true(all(prep$fine <= meta$as_of))
  expect_true(all(prep$fine >= prep$inizio))
  expect_true(all(
    prep$inizio <= meta$window[2] & prep$fine >= meta$window[1]
  ))
  expect_true(all(prep$giornate >= 1L))
  expect_identical(
    sum(prep$troncata),
    sum(cob$troncata == 1L) + meta$n_sentinel_fine
  )
})

# 3. rank_ccnl() contro i totali del microdato -----

test_that("i totali di rank_ccnl() coincidono con quelli del microdato preparato, riga non classificata inclusa", {
  expect_identical(sum(is.na(ranking$ccnl_key)), 1L)
  expect_identical(ranking[is.na(ccnl_key)]$classe, "Non classificati")
  for (m in .misure) {
    expect_type(ranking[[m]], "integer")
  }

  expect_identical(sum(ranking$n_rapporti), sum(prep$avviato))
  expect_identical(sum(ranking$giornate), sum(prep$giornate))
  expect_identical(sum(ranking$stock), sum(prep$attivo))

  # n_lavoratori: somma dei distinti per chiave, non distinti globali
  base <- .misure_base(prep)
  expect_identical(sum(ranking$n_lavoratori), sum(base$n_lavoratori))
  expect_gt(
    sum(ranking$n_lavoratori),
    length(unique(prep$cf[prep$avviato]))
  )

  # le quote sommano a 1 sull'intero gruppo, non classificati compresi
  for (m in .misure) {
    expect_equal(sum(ranking[[paste0("quota_", m)]]), 1, tolerance = 1e-12)
  }
})

test_that("le misure per CCNL di rank_ccnl() coincidono con il calcolo indipendente per chiave", {
  .expect_misure_uguali(ranking, .misure_base(prep))

  # tre chiavi: prima, centrale e ultima per giornate
  ordine <- .ordine_selezione(ranking, "giornate")
  n_cl <- length(ordine)
  scelte <- ordine[c(1L, (n_cl + 1L) %/% 2L, n_cl)]
  expect_identical(length(unique(scelte)), 3L)
  for (k in scelte) {
    riga <- ranking[ccnl_key == k]
    expect_identical(nrow(riga), 1L)
    righe_k <- prep[ccnl_key == k]
    avviati_k <- righe_k[avviato == TRUE]
    expect_identical(riga$n_lavoratori, length(unique(avviati_k$cf)))
    expect_identical(riga$n_rapporti, nrow(avviati_k))
    expect_identical(riga$giornate, sum(righe_k$giornate))
    expect_identical(riga$stock, sum(righe_k$attivo))
  }
  expect_identical(ranking[ccnl_key == scelte[1L]]$rank_giornate, 1L)
  expect_identical(ranking[ccnl_key == scelte[3L]]$rank_giornate, n_cl)
})

# 4. Ranking per coorte annuale -----

test_that("con periodo = 'anno' le quote sommano a 1 per anno e le giornate si ricompongono nel totale", {
  per_anno <- rank_ccnl(
    prep,
    measures = c("giornate", "n_rapporti"),
    periodo = "anno"
  )
  somme <- per_anno[,
    list(
      q_giornate = sum(quota_giornate),
      q_rapporti = sum(quota_n_rapporti),
      giornate = sum(giornate),
      n_rapporti = sum(n_rapporti),
      n_na = sum(is.na(ccnl_key)),
      rank_min = min(rank_giornate, na.rm = TRUE)
    ),
    by = anno
  ][order(anno)]

  expect_equal(somme$q_giornate, rep(1, nrow(somme)), tolerance = 1e-12)
  expect_equal(somme$q_rapporti, rep(1, nrow(somme)), tolerance = 1e-12)
  expect_identical(sum(somme$giornate), sum(prep$giornate))
  expect_identical(sum(somme$giornate), sum(ranking$giornate))
  expect_identical(sum(somme$n_rapporti), sum(ranking$n_rapporti))
  expect_identical(somme$n_na, rep(1L, nrow(somme)))
  expect_identical(somme$rank_min, rep(1L, nrow(somme)))

  # giornate per anno contro tapply in base R
  atteso <- tapply(prep$giornate, prep$anno, sum)
  atteso <- atteso[order(as.integer(names(atteso)))]
  expect_identical(somme$anno, as.integer(names(atteso)))
  expect_identical(somme$giornate, as.integer(atteso))
})

# 5. Selezione dei CCNL rilevanti -----

test_that("select_ccnl_rilevanti() seleziona un prefisso dell'ordine di rank con copertura minima", {
  # ranking con giornate come prima misura: l'ordine delle righe coincide con
  # l'ordine di selezione
  ranking_g <- rank_ccnl(prep, measures = c("giornate", "n_lavoratori"))
  ordine <- .ordine_selezione(ranking_g, "giornate")
  cl <- ranking_g[classe == "CCNL"]
  quota <- cl$quota_giornate[match(ordine, cl$ccnl_key)]
  cum <- cumsum(quota)
  expect_equal(
    cum,
    cl$quota_cum_giornate[match(ordine, cl$ccnl_key)],
    tolerance = 1e-12
  )
  tol <- sqrt(.Machine$double.eps)

  for (soglia in c(0.5, 0.8)) {
    keys <- select_ccnl_rilevanti(
      ranking_g,
      measure = "giornate",
      cum_share = soglia
    )
    k <- length(keys)
    expect_gt(k, 1L)
    expect_identical(keys, ordine[seq_len(k)])
    expect_identical(k, which(cum >= soglia - tol)[1L])
    expect_gte(cum[k], soglia - tol)
    expect_lt(cum[k - 1L], soglia)
  }

  # soglia oltre la copertura massima: tutti i classificati, mai i non
  # classificati
  expect_lt(cum[length(cum)], 1)
  tutti <- select_ccnl_rilevanti(ranking_g, measure = "giornate", cum_share = 1)
  expect_identical(tutti, ordine)
  expect_false(anyNA(tutti))
})

test_that("con più misure le chiavi selezionate sono il prefisso dell'ordine di rank_<measure>", {
  ordine <- .ordine_selezione(ranking, "giornate")
  keys <- select_ccnl_rilevanti(ranking, measure = "giornate", cum_share = 0.8)
  expect_identical(keys, ordine[seq_along(keys)])

  # selezione su un'altra misura: prefisso del rank di quella misura
  ordine_lav <- .ordine_selezione(ranking, "n_lavoratori")
  keys_lav <- select_ccnl_rilevanti(
    ranking,
    measure = "n_lavoratori",
    top_n = 4,
    cum_share = NULL
  )
  expect_setequal(keys_lav, ordine_lav[1:4])
})

test_that("select_ccnl_rilevanti() rispetta il tetto top_n e applica il criterio più restrittivo", {
  ranking_g <- rank_ccnl(prep, measures = "giornate")
  ordine <- .ordine_selezione(ranking_g, "giornate")

  keys5 <- select_ccnl_rilevanti(
    ranking_g,
    measure = "giornate",
    top_n = 5,
    cum_share = NULL
  )
  expect_identical(keys5, ordine[1:5])

  keys80 <- select_ccnl_rilevanti(
    ranking_g,
    measure = "giornate",
    cum_share = 0.8
  )
  expect_gt(length(keys80), 3L)
  keys3 <- select_ccnl_rilevanti(
    ranking_g,
    measure = "giornate",
    top_n = 3,
    cum_share = 0.8
  )
  expect_identical(keys3, ordine[1:3])

  keys_largo <- select_ccnl_rilevanti(
    ranking_g,
    measure = "giornate",
    top_n = 100,
    cum_share = 0.8
  )
  expect_identical(keys_largo, keys80)

  tab3 <- select_ccnl_rilevanti(
    ranking_g,
    measure = "giornate",
    top_n = 3,
    cum_share = 0.8,
    return = "table"
  )
  expect_identical(sum(tab3$selezionato), 3L)
  expect_identical(nrow(tab3), 5L)
})

test_that("la tabella di select_ccnl_rilevanti() riassume i CCNL esclusi in una riga residua coerente", {
  keys <- select_ccnl_rilevanti(ranking, measure = "giornate", cum_share = 0.5)
  tab <- select_ccnl_rilevanti(
    ranking,
    measure = "giornate",
    cum_share = 0.5,
    return = "table"
  )
  esclusi <- ranking[classe == "CCNL" & !ccnl_key %in% keys]
  altri <- tab[classe == "Altri CCNL"]
  expect_gt(nrow(esclusi), 0L)
  expect_identical(nrow(altri), 1L)
  expect_identical(altri$ccnl_key, "Altri CCNL")
  expect_false(altri$selezionato)
  expect_identical(nrow(tab), length(keys) + 2L)

  for (m in .misure) {
    expect_identical(altri[[m]], sum(esclusi[[m]]))
    expect_identical(sum(tab[[m]]), sum(ranking[[m]]))
    expect_equal(sum(tab[[paste0("quota_", m)]]), 1, tolerance = 1e-12)
    expect_true(is.na(altri[[paste0("rank_", m)]]))
    expect_true(is.na(altri[[paste0("quota_cum_", m)]]))
  }
  # la quota residua è la quota persa dai CCNL esclusi
  expect_equal(
    altri$quota_giornate,
    sum(esclusi$quota_giornate),
    tolerance = 1e-12
  )

  # righe selezionate e non classificati invariati rispetto al ranking
  sel <- tab[selezionato == TRUE]
  expect_identical(sel$ccnl_key, keys)
  expect_identical(attr(tab, "ccnlcob_selezione")$keys, keys)
  for (m in .misure) {
    expect_identical(sel[[m]], ranking[match(keys, ranking$ccnl_key)][[m]])
  }
  nc <- tab[classe == "Non classificati"]
  expect_identical(nrow(nc), 1L)
  expect_identical(nc$giornate, ranking[is.na(ccnl_key)]$giornate)
  expect_identical(nc$n_lavoratori, ranking[is.na(ccnl_key)]$n_lavoratori)
  expect_identical(
    attr(tab, "ccnlcob_ranking"),
    attr(ranking, "ccnlcob_ranking")
  )
})

# 6. Finestra esplicita end to end -----

test_that("con una finestra esplicita la catena rispetta i limiti e ricompone i giorni tagliati", {
  finestra <- as.Date(c("2021-01-01", "2022-12-31"))
  prep_w <- prepare_rapporti(
    cob,
    window = c("2021-01-01", "2022-12-31"),
    perimetro = "completo"
  )
  meta <- attr(prep_w, "ccnlcob_meta")
  ind <- .prepara_indipendente(cob, .as_of_indipendente(cob), window = finestra)

  expect_identical(meta$window, finestra)
  expect_identical(meta$as_of, ind$as_of)
  expect_identical(meta$n_dropped_window, ind$n_dropped_window)
  expect_gt(meta$n_dropped_window, 0L)
  expect_identical(nrow(prep_w), nrow(ind$righe))
  expect_identical(nrow(prep_w), nrow(cob) - meta$n_dropped_window)
  expect_true(all(prep_w$inizio <= finestra[2] & prep_w$fine >= finestra[1]))
  expect_true(all(prep_w$giornate >= 1L & prep_w$giornate <= 730L))
  expect_true(any(prep_w$giornate == 730L))
  expect_true(any(!prep_w$avviato))
  expect_identical(prep_w$avviato, prep_w$inizio >= finestra[1])

  expect_identical(sort(prep_w$id), sort(ind$righe$id))
  righe <- ind$righe[match(prep_w$id, ind$righe$id), ]
  expect_identical(prep_w$giornate, righe$giornate)
  expect_identical(prep_w$avviato, righe$avviato)
  expect_identical(prep_w$attivo, righe$attivo)

  ranking_w <- rank_ccnl(prep_w, measures = .misure)
  expect_identical(sum(ranking_w$giornate), sum(righe$giornate))
  expect_identical(sum(ranking_w$n_rapporti), sum(righe$avviato))
  expect_identical(sum(ranking_w$stock), sum(righe$attivo))
  expect_lt(sum(ranking_w$n_rapporti), nrow(prep_w))
  .expect_misure_uguali(ranking_w, .misure_base(ind$righe))
  for (m in .misure) {
    expect_equal(sum(ranking_w[[paste0("quota_", m)]]), 1, tolerance = 1e-12)
  }

  keys <- select_ccnl_rilevanti(
    ranking_w,
    measure = "giornate",
    cum_share = 0.8
  )
  expect_gt(length(keys), 0L)
  expect_true(all(keys %in% prep_w$ccnl_key))
  # prefisso dell'ordine per rank_giornate (e chiave a parita'), anche se
  # il ranking e' ordinato sulla prima misura (n_rapporti)
  expect_identical(
    keys,
    .ordine_selezione(ranking_w, "giornate")[seq_along(keys)]
  )
})

# 7. Determinismo -----

test_that("la catena è deterministica e non modifica i propri input", {
  p1 <- prepare_rapporti(cob, perimetro = "completo")
  p2 <- prepare_rapporti(cob, perimetro = "completo")
  expect_identical(p1, p2)
  expect_identical(p1, prep)

  r1 <- rank_ccnl(p1, measures = .misure)
  r2 <- rank_ccnl(p2, measures = .misure)
  expect_identical(r1, r2)
  expect_identical(r1, ranking)
  # rank_ccnl() non ha toccato il microdato preparato
  expect_identical(p1, p2)

  expect_identical(
    select_ccnl_rilevanti(r1, measure = "giornate", cum_share = 0.8),
    select_ccnl_rilevanti(r2, measure = "giornate", cum_share = 0.8)
  )
  expect_identical(
    select_ccnl_rilevanti(
      r1,
      measure = "giornate",
      cum_share = 0.8,
      return = "table"
    ),
    select_ccnl_rilevanti(
      r2,
      measure = "giornate",
      cum_share = 0.8,
      return = "table"
    )
  )
  # select_ccnl_rilevanti() non ha toccato il ranking
  expect_identical(r1, r2)
})

# 8. Fixture nuova attraverso l'intera catena -----

test_that("una fixture nuova attraversa l'intera catena senza errori e con totali coerenti", {
  raw <- generate_cob_sintetico(n_persone = 60, n_rapporti = 400, seed = 7)
  expect_no_error({
    prep_f <- prepare_rapporti(raw, perimetro = "completo")
    ranking_f <- rank_ccnl(prep_f, measures = .misure)
    keys_f <- select_ccnl_rilevanti(
      ranking_f,
      measure = "giornate",
      cum_share = 0.8
    )
    tab_f <- select_ccnl_rilevanti(
      ranking_f,
      measure = "n_lavoratori",
      top_n = 5,
      cum_share = NULL,
      return = "table"
    )
  })

  meta <- attr(prep_f, "ccnlcob_meta")
  ind <- .prepara_indipendente(raw, .as_of_indipendente(raw))
  expect_identical(meta$n_input, 400L)
  expect_identical(meta$as_of, ind$as_of)
  expect_identical(meta$window, ind$window)
  expect_identical(meta$n_sentinel_fine, ind$n_sentinel_fine)
  expect_identical(meta$n_fine_lt_inizio, ind$n_fine_lt_inizio)
  expect_identical(meta$n_dropped_window, ind$n_dropped_window)
  expect_identical(sum(prep_f$giornate), sum(ind$righe$giornate))

  .expect_misure_uguali(ranking_f, .misure_base(ind$righe))
  expect_identical(sum(ranking_f$giornate), sum(prep_f$giornate))
  expect_identical(sum(ranking_f$n_rapporti), sum(prep_f$avviato))

  ordine <- .ordine_selezione(ranking_f, "giornate")
  expect_setequal(keys_f, ordine[seq_along(keys_f)])
  expect_gt(length(keys_f), 0L)
  expect_identical(sum(tab_f$selezionato), 5L)
  expect_identical(sum(tab_f$giornate), sum(ranking_f$giornate))
  expect_equal(sum(tab_f$quota_giornate), 1, tolerance = 1e-12)
})

test_that("la catena funziona con la chiave warehouse, senza classe non classificata", {
  raw <- generate_cob_sintetico(n_persone = 60, n_rapporti = 400, seed = 7)
  prep_wh <- prepare_rapporti(
    raw,
    ccnl_key = "ccnl_warehouse",
    perimetro = "completo"
  )
  expect_identical(attr(prep_wh, "ccnlcob_meta")$ccnl_key, "ccnl_warehouse")
  expect_false(anyNA(prep_wh$ccnl_key))
  expect_identical(prep_wh$ccnl_key, raw$ccnl[match(prep_wh$id, raw$id)])

  ranking_wh <- rank_ccnl(prep_wh, measures = c("giornate", "n_lavoratori"))
  expect_false(anyNA(ranking_wh$ccnl_key))
  expect_true(all(ranking_wh$classe == "CCNL"))
  expect_identical(sum(ranking_wh$giornate), sum(prep_wh$giornate))

  tutti <- select_ccnl_rilevanti(
    ranking_wh,
    measure = "giornate",
    cum_share = 1
  )
  expect_identical(tutti, .ordine_selezione(ranking_wh, "giornate"))
  expect_equal(
    sum(ranking_wh$quota_giornate[ranking_wh$ccnl_key %in% tutti]),
    1,
    tolerance = 1e-12
  )
})

# 9. Fase 2: territorio e tipologie -----

# Catena prepare_rapporti() -> add_cpi() -> rank_ccnl() ->
# select_ccnl_rilevanti() -> ccnl_by_cpi() / ccnl_by_tipologia(), confrontata
# con tabelle incrociate ricostruite in base R (tapply su indici di riga).
# I test unitari di ciascuna funzione stanno in test-territorio.R e
# test-tipologie.R. La fixture condivisa `prep` non viene modificata: il CPI
# viene aggiunto a una copia.

.codici_fuori <- c("F952", "G535", "H501", "L219")
.macro_classi <- c(
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

# Chiave CCNL come stringa, con "<NA>" per i non classificati.
.chiave_chr <- function(x) ifelse(is.na(x), "<NA>", as.character(x))

# Funzione di cella per una misura: riceve gli indici di riga di `tab`.
.fun_misura <- function(tab, measure) {
  switch(
    measure,
    giornate = function(i) sum(tab$giornate[i]),
    n_rapporti = function(i) sum(tab$avviato[i]),
    stock = function(i) sum(tab$attivo[i]),
    n_lavoratori = function(i) length(unique(tab$cf[i][tab$avviato[i]]))
  )
}

# Tabella incrociata indipendente: per ogni cella (gruppo, ccnl_key, dims)
# applica `fun` agli indici di riga e ricava i totali per chiave, per
# dimensione e complessivo con la stessa `fun`; quindi quota_riga,
# quota_colonna e lq (NA dove il totale della dimensione è sotto min_n).
.celle_indipendenti <- function(tab, dims, fun, grp = NULL, min_n = 30) {
  g <- if (is.null(grp)) rep("tutti", nrow(tab)) else as.character(tab[[grp]])
  key <- .chiave_chr(tab$ccnl_key)
  dim_id <- do.call(
    paste,
    c(lapply(dims, function(d) as.character(tab[[d]])), sep = "\r")
  )
  id_cella <- paste(g, key, dim_id, sep = "\r")
  id_key <- paste(g, key, sep = "\r")
  id_dim <- paste(g, dim_id, sep = "\r")
  righe <- seq_len(nrow(tab))
  u <- !duplicated(id_cella)
  celle <- data.frame(
    id = id_cella[u],
    grp = g[u],
    key = key[u],
    dim = dim_id[u],
    stringsAsFactors = FALSE
  )
  v <- tapply(righe, id_cella, fun)
  t_key <- tapply(righe, id_key, fun)
  t_dim <- tapply(righe, id_dim, fun)
  t_all <- tapply(righe, g, fun)
  celle$valore <- as.numeric(v[celle$id])
  celle$totale_key <- as.numeric(t_key[paste(celle$grp, celle$key, sep = "\r")])
  celle$totale_dim <- as.numeric(t_dim[paste(celle$grp, celle$dim, sep = "\r")])
  celle$totale <- as.numeric(t_all[celle$grp])
  celle$quota_riga <- celle$valore / celle$totale_key
  celle$quota_colonna <- celle$valore / celle$totale_dim
  celle$lq <- celle$quota_colonna / (celle$totale_key / celle$totale)
  celle$lq[celle$totale_dim < min_n] <- NA_real_
  celle
}

# Confronta cella per cella una tabella di ccnl_by_cpi() / ccnl_by_tipologia()
# con il calcolo indipendente; restituisce invisibilmente le celle
# indipendenti (con i totali) per controlli ulteriori.
.expect_crosstab_uguale <- function(
  out,
  tab,
  dims,
  fun,
  measure,
  grp = NULL,
  min_n = 30
) {
  ind <- .celle_indipendenti(tab, dims, fun, grp = grp, min_n = min_n)
  g_out <- if (is.null(grp)) {
    rep("tutti", nrow(out))
  } else {
    as.character(out[[grp]])
  }
  dim_out <- do.call(
    paste,
    c(lapply(dims, function(d) as.character(out[[d]])), sep = "\r")
  )
  id_out <- paste(g_out, .chiave_chr(out$ccnl_key), dim_out, sep = "\r")
  expect_identical(anyDuplicated(id_out), 0L)
  expect_setequal(id_out, ind$id)
  m <- match(id_out, ind$id)
  expect_identical(as.integer(out[[measure]]), as.integer(ind$valore[m]))
  expect_equal(out$quota_riga, ind$quota_riga[m], tolerance = 1e-12)
  expect_equal(out$quota_colonna, ind$quota_colonna[m], tolerance = 1e-12)
  expect_equal(out$lq, ind$lq[m], tolerance = 1e-12)
  expect_identical(
    out$classe,
    ifelse(is.na(out$ccnl_key), "Non classificati", "CCNL")
  )
  invisible(ind)
}

# CPI atteso in base R da un vettore di codici Belfiore e dal lookup.
.cpi_atteso <- function(codici, lookup, col = "cpi_code") {
  atteso <- lookup[[col]][match(codici, lookup$belfiore)]
  atteso[is.na(atteso) & !is.na(codici)] <- if (col == "cpi_code") {
    "FUORI"
  } else {
    "Fuori Lombardia"
  }
  atteso
}

cpi_lookup <- .carica_dataset("cpi_esempio")
tipologie_lookup <- .carica_dataset("tipologie_contrattuali")
prep_cpi <- data.table::copy(prep)
ret_cpi <- add_cpi(prep_cpi, lookup = cpi_lookup)
cpi_tab <- ccnl_by_cpi(prep_cpi, measure = "giornate")

test_that("add_cpi() con lookup esplicito mappa i capoluoghi, isola i comuni fuori regione e non tocca righe e ordine", {
  # per riferimento: stesso oggetto, stesse righe, stesso ordine
  expect_identical(data.table::address(ret_cpi), data.table::address(prep_cpi))
  expect_identical(nrow(prep_cpi), nrow(prep))
  expect_identical(prep_cpi$id, prep$id)
  expect_identical(
    attr(prep_cpi, "ccnlcob_cpi"),
    list(geo = "sede_lavoro", source = "lookup")
  )

  # mapping riga per riga contro il lookup
  expect_identical(
    prep_cpi$cpi_code,
    .cpi_atteso(prep_cpi$comune_sede_lavoro, cpi_lookup)
  )
  expect_identical(
    prep_cpi$cpi_name,
    .cpi_atteso(prep_cpi$comune_sede_lavoro, cpi_lookup, "cpi_name")
  )
  expect_false(anyNA(prep_cpi$cpi_code))

  # ogni capoluogo del lookup è presente e mappa al proprio CPI
  for (i in seq_len(nrow(cpi_lookup))) {
    righe <- prep_cpi$comune_sede_lavoro == cpi_lookup$belfiore[i]
    expect_gt(sum(righe), 0L)
    expect_identical(unique(prep_cpi$cpi_code[righe]), cpi_lookup$cpi_code[i])
  }
  # i quattro comuni fuori regione, e solo quelli, danno FUORI
  expect_setequal(
    unique(prep_cpi$comune_sede_lavoro[prep_cpi$cpi_code == "FUORI"]),
    .codici_fuori
  )
  expect_identical(
    sum(prep_cpi$cpi_code == "FUORI"),
    sum(prep_cpi$comune_sede_lavoro %in% .codici_fuori)
  )
  expect_false("ND" %in% prep_cpi$cpi_code)

  # geografia di residenza su una copia: stesse righe, distribuzione diversa
  prep_res <- data.table::copy(prep)
  add_cpi(prep_res, geo = "residenza", lookup = cpi_lookup)
  expect_identical(nrow(prep_res), nrow(prep_cpi))
  expect_identical(prep_res$id, prep_cpi$id)
  expect_identical(attr(prep_res, "ccnlcob_cpi")$geo, "residenza")
  expect_identical(
    prep_res$cpi_code,
    .cpi_atteso(prep_res$comune_lavoratore, cpi_lookup)
  )
  expect_setequal(unique(prep_res$cpi_code), unique(prep_cpi$cpi_code))
  expect_false(identical(prep_res$cpi_code, prep_cpi$cpi_code))
  distr_sede <- tapply(rep(1L, nrow(prep_cpi)), prep_cpi$cpi_code, sum)
  distr_res <- tapply(rep(1L, nrow(prep_res)), prep_res$cpi_code, sum)
  expect_false(identical(
    as.integer(distr_sede),
    as.integer(distr_res[names(distr_sede)])
  ))
  expect_identical(sum(distr_sede), sum(distr_res))
})

test_that("ccnl_by_cpi() riproduce totali, quote e quozienti di localizzazione calcolati in base R", {
  meta <- attr(cpi_tab, "ccnlcob_crosstab")
  expect_identical(meta$measure, "giornate")
  expect_identical(meta$geo, "sede_lavoro")
  expect_identical(meta$min_n, 30L)

  ind <- .expect_crosstab_uguale(
    cpi_tab,
    prep_cpi,
    dims = "cpi_code",
    fun = .fun_misura(prep_cpi, "giornate"),
    measure = "giornate"
  )
  # nessun CPI sotto min_n su questa fixture: nessun lq mascherato
  expect_gt(min(ind$totale_dim), 30)
  expect_false(anyNA(cpi_tab$lq))

  # totali per chiave (NA inclusa) e per CPI contro tapply sul microdato
  tot_key <- tapply(prep_cpi$giornate, .chiave_chr(prep_cpi$ccnl_key), sum)
  somma_key <- tapply(cpi_tab$giornate, .chiave_chr(cpi_tab$ccnl_key), sum)
  expect_setequal(names(somma_key), names(tot_key))
  expect_identical(as.integer(somma_key), as.integer(tot_key[names(somma_key)]))
  expect_true("<NA>" %in% names(somma_key))
  tot_cpi <- tapply(prep_cpi$giornate, prep_cpi$cpi_code, sum)
  somma_cpi <- tapply(cpi_tab$giornate, cpi_tab$cpi_code, sum)
  expect_setequal(names(somma_cpi), names(tot_cpi))
  expect_identical(as.integer(somma_cpi), as.integer(tot_cpi[names(somma_cpi)]))
  expect_identical(sum(cpi_tab$giornate), sum(prep_cpi$giornate))
  expect_identical(
    sort(unique(cpi_tab$cpi_code)),
    sort(c(cpi_lookup$cpi_code, "FUORI"))
  )
  nome_atteso <- cpi_lookup$cpi_name[match(
    cpi_tab$cpi_code,
    cpi_lookup$cpi_code
  )]
  nome_atteso[cpi_tab$cpi_code == "FUORI"] <- "Fuori Lombardia"
  expect_identical(cpi_tab$cpi_name, nome_atteso)

  # quote: somma 1 per chiave e per CPI
  q_riga <- tapply(cpi_tab$quota_riga, .chiave_chr(cpi_tab$ccnl_key), sum)
  expect_equal(as.numeric(q_riga), rep(1, length(q_riga)), tolerance = 1e-12)
  q_col <- tapply(cpi_tab$quota_colonna, cpi_tab$cpi_code, sum)
  expect_equal(as.numeric(q_col), rep(1, length(q_col)), tolerance = 1e-12)

  # lq ricalcolato: (v / T_cpi) / (T_key / T)
  tot <- sum(prep_cpi$giornate)
  lq_atteso <- (cpi_tab$giornate / tot_cpi[cpi_tab$cpi_code]) /
    (tot_key[.chiave_chr(cpi_tab$ccnl_key)] / tot)
  expect_equal(cpi_tab$lq, as.numeric(lq_atteso), tolerance = 1e-12)
  # media di lq ponderata con T_cpi / T pari a 1 entro ogni chiave
  peso <- tot_cpi[cpi_tab$cpi_code] / tot
  lq_medio <- tapply(cpi_tab$lq * peso, .chiave_chr(cpi_tab$ccnl_key), sum)
  expect_equal(
    as.numeric(lq_medio),
    rep(1, length(lq_medio)),
    tolerance = 1e-12
  )

  # ordinamento: chiavi non decrescenti con NA in coda, misura decrescente
  # entro chiave
  expect_identical(
    cpi_tab$ccnl_key,
    cpi_tab$ccnl_key[order(cpi_tab$ccnl_key, na.last = TRUE)]
  )
  expect_true(all(unlist(tapply(
    cpi_tab$giornate,
    .chiave_chr(cpi_tab$ccnl_key),
    function(x) !is.unsorted(rev(x))
  ))))
})

test_that("le misure per CCNL di ccnl_by_cpi() sono coerenti con rank_ccnl()", {
  per_key <- function(tab, measure) {
    s <- tapply(tab[[measure]], .chiave_chr(tab$ccnl_key), sum)
    as.integer(s[.chiave_chr(ranking$ccnl_key)])
  }
  # misure additive: somma sui CPI uguale al ranking, riga NA inclusa
  ranking_g <- rank_ccnl(prep, measures = "giornate")
  expect_identical(
    per_key(cpi_tab, "giornate"),
    ranking_g$giornate[match(ranking$ccnl_key, ranking_g$ccnl_key)]
  )
  expect_identical(per_key(cpi_tab, "giornate"), ranking$giornate)
  for (m in c("n_rapporti", "stock")) {
    tab_m <- ccnl_by_cpi(prep_cpi, measure = m)
    expect_identical(attr(tab_m, "ccnlcob_crosstab")$measure, m)
    expect_identical(per_key(tab_m, m), ranking[[m]])
    .expect_crosstab_uguale(
      tab_m,
      prep_cpi,
      dims = "cpi_code",
      fun = .fun_misura(prep_cpi, m),
      measure = m
    )
  }

  # conteggio distinto: la somma sui CPI è >= del distinto del ranking,
  # perché un lavoratore avviato in due CPI conta due volte
  tab_lav <- ccnl_by_cpi(prep_cpi, measure = "n_lavoratori")
  somma_lav <- per_key(tab_lav, "n_lavoratori")
  expect_true(all(somma_lav >= ranking$n_lavoratori))
  expect_gt(sum(somma_lav), sum(ranking$n_lavoratori))
  # per cella coincide con il distinto calcolato in base R
  .expect_crosstab_uguale(
    tab_lav,
    prep_cpi,
    dims = "cpi_code",
    fun = .fun_misura(prep_cpi, "n_lavoratori"),
    measure = "n_lavoratori"
  )
  # i totali del ranking sono i distinti per chiave, non la somma
  distinti <- tapply(
    seq_len(nrow(prep_cpi)),
    .chiave_chr(prep_cpi$ccnl_key),
    .fun_misura(prep_cpi, "n_lavoratori")
  )
  expect_identical(
    as.integer(distinti[.chiave_chr(ranking$ccnl_key)]),
    ranking$n_lavoratori
  )
})

test_that("ccnl_by_cpi() per anno rispetta le quote entro anno e si ricompone nella finestra intera", {
  per_anno <- ccnl_by_cpi(prep_cpi, measure = "giornate", periodo = "anno")
  expect_identical(attr(per_anno, "ccnlcob_crosstab")$periodo, "anno")
  expect_true("anno" %in% names(per_anno))
  expect_setequal(unique(per_anno$anno), unique(prep_cpi$anno))

  ind <- .expect_crosstab_uguale(
    per_anno,
    prep_cpi,
    dims = "cpi_code",
    fun = .fun_misura(prep_cpi, "giornate"),
    measure = "giornate",
    grp = "anno"
  )
  expect_gt(min(ind$totale_dim), 30)
  expect_false(anyNA(per_anno$lq))

  # quote a 1 entro (anno, chiave) e (anno, CPI)
  q_riga <- tapply(
    per_anno$quota_riga,
    paste(per_anno$anno, .chiave_chr(per_anno$ccnl_key)),
    sum
  )
  expect_equal(as.numeric(q_riga), rep(1, length(q_riga)), tolerance = 1e-12)
  q_col <- tapply(
    per_anno$quota_colonna,
    paste(per_anno$anno, per_anno$cpi_code),
    sum
  )
  expect_equal(as.numeric(q_col), rep(1, length(q_col)), tolerance = 1e-12)

  # somma sugli anni di ogni cella = cella della finestra intera
  cella <- paste(.chiave_chr(per_anno$ccnl_key), per_anno$cpi_code)
  somma_anni <- tapply(per_anno$giornate, cella, sum)
  cella_tot <- paste(.chiave_chr(cpi_tab$ccnl_key), cpi_tab$cpi_code)
  expect_setequal(names(somma_anni), cella_tot)
  expect_identical(as.integer(somma_anni[cella_tot]), cpi_tab$giornate)
  expect_identical(sum(per_anno$giornate), sum(prep_cpi$giornate))
  # giornate per anno contro tapply sul microdato
  g_anno <- tapply(per_anno$giornate, per_anno$anno, sum)
  atteso <- tapply(prep_cpi$giornate, prep_cpi$anno, sum)
  expect_identical(as.integer(g_anno), as.integer(atteso[names(g_anno)]))
})

test_that("il filtro ccnl di ccnl_by_cpi() conserva solo le chiavi selezionate senza alterare quote e lq", {
  keys <- select_ccnl_rilevanti(
    rank_ccnl(prep),
    measure = "giornate",
    top_n = 5,
    cum_share = NULL
  )
  expect_identical(length(keys), 5L)
  filtrata <- ccnl_by_cpi(prep_cpi, measure = "giornate", ccnl = keys)
  # nota: `prep` e' la fixture con perimetro "completo" (sezione 1)

  expect_setequal(unique(filtrata$ccnl_key), keys)
  expect_false(anyNA(filtrata$ccnl_key))
  expect_true(all(filtrata$classe == "CCNL"))
  expect_identical(nrow(filtrata), sum(cpi_tab$ccnl_key %in% keys))

  id_f <- paste(filtrata$ccnl_key, filtrata$cpi_code)
  id_full <- paste(.chiave_chr(cpi_tab$ccnl_key), cpi_tab$cpi_code)
  m <- match(id_f, id_full)
  expect_false(anyNA(m))
  # stesse righe: i totali sono calcolati prima del filtro
  expect_identical(filtrata$giornate, cpi_tab$giornate[m])
  expect_identical(filtrata$quota_riga, cpi_tab$quota_riga[m])
  expect_identical(filtrata$quota_colonna, cpi_tab$quota_colonna[m])
  expect_identical(filtrata$lq, cpi_tab$lq[m])
  expect_identical(filtrata$cpi_name, cpi_tab$cpi_name[m])
  # le quote di colonna dei soli selezionati non sommano a 1
  q_col <- tapply(filtrata$quota_colonna, filtrata$cpi_code, sum)
  expect_true(all(q_col < 1))
  # le quote di riga dei selezionati restano complete
  q_riga <- tapply(filtrata$quota_riga, filtrata$ccnl_key, sum)
  expect_equal(as.numeric(q_riga), rep(1, 5), tolerance = 1e-12)
  # con NA fra le chiavi i non classificati restano
  con_na <- ccnl_by_cpi(prep_cpi, measure = "giornate", ccnl = c(keys, NA))
  expect_identical(nrow(con_na), nrow(filtrata) + sum(is.na(cpi_tab$ccnl_key)))
  expect_identical(
    sum(con_na[is.na(ccnl_key)]$giornate),
    sum(prep_cpi[is.na(ccnl_key)]$giornate)
  )
})

test_that("ccnl_by_tipologia() riproduce la distribuzione per macro-classe e orario calcolata in base R", {
  # tabella indipendente: macro-classe dal lookup sul codice MLPS, orario da prior
  tab_tip <- data.frame(
    ccnl_key = prep$ccnl_key,
    cf = prep$cf,
    giornate = prep$giornate,
    avviato = prep$avviato,
    attivo = prep$attivo,
    anno = prep$anno,
    tipologia = tipologie_lookup$macro_tipologia[
      match(
        prep$cod_tipologia_contrattuale,
        tipologie_lookup$cod_tipologia_contrattuale
      )
    ],
    orario = ifelse(prep$prior == 1L, "FT", ifelse(prep$prior == 0L, "PT", NA)),
    stringsAsFactors = FALSE
  )
  tab_tip$tipologia[is.na(tab_tip$tipologia)] <- "Non classificata"
  tab_tip$orario[is.na(tab_tip$orario)] <- "ND"

  tip <- ccnl_by_tipologia(prep, measure = "n_rapporti", level = "macro")
  meta <- attr(tip, "ccnlcob_crosstab")
  expect_identical(meta$level, "macro")
  expect_true(meta$orario)
  expect_identical(meta$dims, c("tipologia", "orario"))
  expect_true(all(tip$tipologia %in% c(.macro_classi, "Non classificata")))
  expect_true(all(tip$orario %in% c("FT", "PT", "ND")))
  expect_setequal(unique(tip$tipologia), unique(tab_tip$tipologia))
  expect_setequal(unique(tip$orario), c("FT", "PT"))

  .expect_crosstab_uguale(
    tip,
    tab_tip,
    dims = c("tipologia", "orario"),
    fun = .fun_misura(tab_tip, "n_rapporti"),
    measure = "n_rapporti"
  )
  # per chiave: somma su tipologia x orario = rapporti avviati della chiave
  somma_key <- tapply(tip$n_rapporti, .chiave_chr(tip$ccnl_key), sum)
  avviati_key <- tapply(prep$avviato, .chiave_chr(prep$ccnl_key), sum)
  expect_setequal(names(somma_key), names(avviati_key))
  expect_identical(
    as.integer(somma_key),
    as.integer(avviati_key[names(somma_key)])
  )
  expect_identical(sum(tip$n_rapporti), sum(prep$avviato))
  expect_identical(
    as.integer(somma_key[.chiave_chr(ranking$ccnl_key)]),
    ranking$n_rapporti
  )

  # level = "codice": descrizione MLPS dal lookup
  tip_cod <- ccnl_by_tipologia(prep, measure = "n_rapporti", level = "codice")
  expect_identical(attr(tip_cod, "ccnlcob_crosstab")$level, "codice")
  expect_true("des_tipologia_contrattuale" %in% names(tip_cod))
  expect_true(all(
    tip_cod$tipologia %in% c(prep$cod_tipologia_contrattuale, "ND")
  ))
  expect_identical(
    tip_cod$des_tipologia_contrattuale,
    tipologie_lookup$des_tipologia_contrattuale[
      match(tip_cod$tipologia, tipologie_lookup$cod_tipologia_contrattuale)
    ]
  )
  expect_false(anyNA(tip_cod$des_tipologia_contrattuale))
  tab_cod <- tab_tip
  tab_cod$tipologia <- prep$cod_tipologia_contrattuale
  .expect_crosstab_uguale(
    tip_cod,
    tab_cod,
    dims = c("tipologia", "orario"),
    fun = .fun_misura(tab_cod, "n_rapporti"),
    measure = "n_rapporti"
  )
  expect_identical(sum(tip_cod$n_rapporti), sum(prep$avviato))

  # orario = FALSE: le righe FT/PT collassano nella macro-classe
  senza <- ccnl_by_tipologia(
    prep,
    measure = "n_rapporti",
    level = "macro",
    orario = FALSE
  )
  expect_false("orario" %in% names(senza))
  expect_identical(attr(senza, "ccnlcob_crosstab")$dims, "tipologia")
  collassata <- tapply(
    tip$n_rapporti,
    paste(.chiave_chr(tip$ccnl_key), tip$tipologia, sep = "\r"),
    sum
  )
  id_senza <- paste(.chiave_chr(senza$ccnl_key), senza$tipologia, sep = "\r")
  expect_setequal(id_senza, names(collassata))
  expect_identical(senza$n_rapporti, as.integer(collassata[id_senza]))
  .expect_crosstab_uguale(
    senza,
    tab_tip,
    dims = "tipologia",
    fun = .fun_misura(tab_tip, "n_rapporti"),
    measure = "n_rapporti"
  )
  q_riga <- tapply(senza$quota_riga, .chiave_chr(senza$ccnl_key), sum)
  expect_equal(as.numeric(q_riga), rep(1, length(q_riga)), tolerance = 1e-12)
  # anche con giornate la somma per chiave torna al ranking
  tip_g <- ccnl_by_tipologia(prep, measure = "giornate", orario = FALSE)
  somma_g <- tapply(tip_g$giornate, .chiave_chr(tip_g$ccnl_key), sum)
  expect_identical(
    as.integer(somma_g[.chiave_chr(ranking$ccnl_key)]),
    ranking$giornate
  )
})

test_that("una fixture nuova attraversa la catena di Fase 2 senza errori e con totali coerenti", {
  raw <- generate_cob_sintetico(n_persone = 80, n_rapporti = 600, seed = 11)
  expect_no_error({
    prep_f <- prepare_rapporti(raw, perimetro = "completo")
    add_cpi(prep_f, lookup = cpi_lookup)
    ranking_f <- rank_ccnl(prep_f, measures = c("giornate", "n_rapporti"))
    keys_f <- select_ccnl_rilevanti(
      ranking_f,
      measure = "giornate",
      cum_share = 0.8
    )
    cpi_f <- ccnl_by_cpi(prep_f, measure = "giornate")
    cpi_sel_f <- ccnl_by_cpi(prep_f, measure = "giornate", ccnl = keys_f)
    tip_f <- ccnl_by_tipologia(prep_f, measure = "n_rapporti", ccnl = keys_f)
  })
  expect_identical(
    nrow(prep_f),
    600L - attr(prep_f, "ccnlcob_meta")$n_dropped_window
  )
  expect_identical(
    prep_f$cpi_code,
    .cpi_atteso(prep_f$comune_sede_lavoro, cpi_lookup)
  )

  ind <- .expect_crosstab_uguale(
    cpi_f,
    prep_f,
    dims = "cpi_code",
    fun = .fun_misura(prep_f, "giornate"),
    measure = "giornate"
  )
  tot_key <- tapply(prep_f$giornate, .chiave_chr(prep_f$ccnl_key), sum)
  somma_key <- tapply(cpi_f$giornate, .chiave_chr(cpi_f$ccnl_key), sum)
  expect_identical(as.integer(somma_key), as.integer(tot_key[names(somma_key)]))
  tot_cpi <- tapply(prep_f$giornate, prep_f$cpi_code, sum)
  somma_cpi <- tapply(cpi_f$giornate, cpi_f$cpi_code, sum)
  expect_identical(as.integer(somma_cpi), as.integer(tot_cpi[names(somma_cpi)]))
  expect_identical(sum(cpi_f$giornate), sum(prep_f$giornate))
  expect_identical(
    as.integer(somma_key[.chiave_chr(ranking_f$ccnl_key)]),
    ranking_f$giornate
  )
  q_riga <- tapply(cpi_f$quota_riga, .chiave_chr(cpi_f$ccnl_key), sum)
  expect_equal(as.numeric(q_riga), rep(1, length(q_riga)), tolerance = 1e-12)
  q_col <- tapply(cpi_f$quota_colonna, cpi_f$cpi_code, sum)
  expect_equal(as.numeric(q_col), rep(1, length(q_col)), tolerance = 1e-12)
  # lq medio ponderato pari a 1 sulle chiavi senza celle mascherate
  mascherate <- is.na(cpi_f$lq)
  expect_identical(
    mascherate,
    ind$totale_dim[match(
      paste("tutti", .chiave_chr(cpi_f$ccnl_key), cpi_f$cpi_code, sep = "\r"),
      ind$id
    )] <
      30
  )
  chiavi_ok <- setdiff(
    .chiave_chr(cpi_f$ccnl_key),
    .chiave_chr(cpi_f$ccnl_key[mascherate])
  )
  ok <- .chiave_chr(cpi_f$ccnl_key) %in% chiavi_ok
  peso <- tot_cpi[cpi_f$cpi_code] / sum(prep_f$giornate)
  lq_medio <- tapply(
    (cpi_f$lq * peso)[ok],
    .chiave_chr(cpi_f$ccnl_key)[ok],
    sum
  )
  expect_gt(length(lq_medio), 0L)
  expect_equal(
    as.numeric(lq_medio),
    rep(1, length(lq_medio)),
    tolerance = 1e-12
  )

  # selezione e tipologie
  expect_setequal(unique(cpi_sel_f$ccnl_key), keys_f)
  expect_setequal(unique(tip_f$ccnl_key), keys_f)
  expect_identical(
    sum(tip_f$n_rapporti),
    sum(prep_f$avviato[prep_f$ccnl_key %in% keys_f])
  )
  expect_identical(
    sum(cpi_sel_f$giornate),
    sum(prep_f$giornate[prep_f$ccnl_key %in% keys_f])
  )
})

test_that("min_n maschera lq senza eliminare righe né alterare le quote", {
  mascherata <- ccnl_by_cpi(prep_cpi, min_n = 1e9)
  expect_identical(attr(mascherata, "ccnlcob_crosstab")$min_n, 1e9)
  expect_identical(nrow(mascherata), nrow(cpi_tab))
  expect_identical(mascherata$ccnl_key, cpi_tab$ccnl_key)
  expect_identical(mascherata$cpi_code, cpi_tab$cpi_code)
  expect_true(all(is.na(mascherata$lq)))
  expect_false(anyNA(cpi_tab$lq))
  expect_identical(mascherata$giornate, cpi_tab$giornate)
  expect_identical(mascherata$quota_riga, cpi_tab$quota_riga)
  expect_identical(mascherata$quota_colonna, cpi_tab$quota_colonna)

  # soglia intermedia: mascherati esattamente i CPI sotto soglia
  tot_cpi <- tapply(prep_cpi$giornate, prep_cpi$cpi_code, sum)
  soglia <- stats::median(tot_cpi)
  parziale <- ccnl_by_cpi(prep_cpi, min_n = soglia)
  expect_identical(
    is.na(parziale$lq),
    as.logical(tot_cpi[parziale$cpi_code] < soglia)
  )
  expect_true(any(is.na(parziale$lq)) && !all(is.na(parziale$lq)))
  expect_identical(parziale$quota_riga, cpi_tab$quota_riga)
})

# 10. Perimetro CCNL -----

# Comportamento di default di prepare_rapporti() (perimetro = "ccnl") e di
# filter_perimetro(), confrontato con il flag ricostruito in base R dal lookup
# tipologie_contrattuali: righe escluse, metadati, sentinelle e finestra
# calcolate sulle sole righe conservate, totali di rank_ccnl() sul sottoinsieme.
# I test unitari di filter_perimetro() stanno in test-perimetro.R.

# Flag di perimetro indipendente: TRUE se il codice MLPS e' nel lookup con
# perimetro_ccnl == TRUE; i codici ignoti (NA da match) sono fuori perimetro.
.flag_perimetro <- function(raw, lookup = tipologie_lookup) {
  idx <- match(
    as.character(raw$cod_tipologia_contrattuale),
    as.character(lookup$cod_tipologia_contrattuale)
  )
  flag <- lookup$perimetro_ccnl[idx]
  flag[is.na(flag)] <- FALSE
  flag
}

# Flag del perimetro standard: escluse solo le righe con esclusa_standard TRUE;
# i codici ignoti restano.
.flag_standard <- function(raw, lookup = tipologie_lookup) {
  idx <- match(
    as.character(raw$cod_tipologia_contrattuale),
    as.character(lookup$cod_tipologia_contrattuale)
  )
  esclusa <- lookup$esclusa_standard[idx]
  is.na(esclusa) | !esclusa
}

.attesi_esclusi <- c(
  C.01.00 = 110L,
  B.03.00 = 90L,
  B.04.00 = 35L,
  C.03.00 = 19L
)

test_that("prepare_rapporti() di default esclude le righe fuori perimetro CCNL e le conteggia nei metadati", {
  prep_p <- suppressMessages(prepare_rapporti(cob))
  meta <- attr(prep_p, "ccnlcob_meta")
  keep <- .flag_perimetro(cob)

  # insieme delle righe escluse: esattamente quelle con flag FALSE
  expect_setequal(setdiff(cob$id, prep_p$id), cob$id[!keep])
  expect_true(all(prep_p$id %in% cob$id[keep]))
  expect_false(anyDuplicated(prep_p$id) > 0L)

  # metadati
  expect_identical(meta$perimetro, "ccnl")
  expect_identical(meta$n_input, 5000L)
  expect_identical(meta$n_input, nrow(cob))
  expect_identical(meta$n_dropped_perimetro, 254L)
  expect_identical(meta$n_dropped_perimetro, sum(!keep))
  expect_identical(meta$n_tipologia_ignota, 0L)
  expect_identical(
    nrow(prep_p),
    5000L - 254L - meta$n_dropped_window
  )
  expect_identical(
    nrow(prep_p),
    meta$n_input - meta$n_dropped_perimetro - meta$n_dropped_window
  )
  expect_true(all(prep_p$perimetro_ccnl))
  expect_type(prep_p$perimetro_ccnl, "logical")

  # tabella degli esclusi: quattro codici, conteggi attesi, somma 254
  esclusi <- meta$esclusi_perimetro
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
  expect_identical(nrow(esclusi), 4L)
  expect_setequal(esclusi$cod_tipologia_contrattuale, names(.attesi_esclusi))
  expect_identical(
    esclusi$n[match(
      names(.attesi_esclusi),
      esclusi$cod_tipologia_contrattuale
    )],
    unname(.attesi_esclusi)
  )
  expect_identical(sum(esclusi$n), 254L)
  expect_identical(sum(esclusi$n), meta$n_dropped_perimetro)
  # ordine decrescente di n
  expect_false(is.unsorted(rev(esclusi$n)))
  # conteggi contro table() sulle righe grezze escluse
  conteggio_raw <- table(cob$cod_tipologia_contrattuale[!keep])
  expect_identical(
    esclusi$n,
    as.integer(conteggio_raw[esclusi$cod_tipologia_contrattuale])
  )
  # macro-classe degli esclusi dal lookup
  expect_identical(
    esclusi$macro_tipologia,
    tipologie_lookup$macro_tipologia[match(
      esclusi$cod_tipologia_contrattuale,
      tipologie_lookup$cod_tipologia_contrattuale
    )]
  )
  # nessuna tipologia esclusa sopravvive nel microdato
  expect_false(any(
    prep_p$cod_tipologia_contrattuale %in% esclusi$cod_tipologia_contrattuale
  ))

  # sentinelle e finestra: conteggi indipendenti sulle sole righe conservate,
  # con as_of calcolata su tutte le righe (prima del filtro)
  as_of <- .as_of_indipendente(cob)
  ind <- .prepara_indipendente(cob[keep], as_of)
  expect_identical(meta$as_of, as_of)
  expect_identical(meta$window, ind$window)
  expect_identical(meta$n_sentinel_fine, ind$n_sentinel_fine)
  expect_identical(meta$n_sentinel_inizio, ind$n_sentinel_inizio)
  expect_identical(meta$n_fine_lt_inizio, ind$n_fine_lt_inizio)
  expect_identical(meta$n_dropped_window, ind$n_dropped_window)
  expect_identical(
    meta$n_sentinel_fine,
    sum(
      (cob$fine == .sent_max | cob$fine == .sent_min | cob$fine > as_of) & keep
    )
  )
  # le sentinelle sono contate dopo il filtro: meno di quelle sul dato intero
  meta_tot <- attr(prep, "ccnlcob_meta")
  expect_lte(meta$n_sentinel_fine, meta_tot$n_sentinel_fine)
  expect_lte(meta$n_fine_lt_inizio, meta_tot$n_fine_lt_inizio)
  expect_gt(meta$n_sentinel_fine, 0L)

  # riga per riga sul sottoinsieme
  expect_identical(sort(prep_p$id), sort(ind$righe$id))
  righe <- ind$righe[match(prep_p$id, ind$righe$id), ]
  expect_identical(as.Date(prep_p$inizio), righe$inizio)
  expect_identical(as.Date(prep_p$fine), righe$fine)
  expect_identical(prep_p$giornate, righe$giornate)
  expect_identical(prep_p$troncata, righe$troncata)
  expect_identical(prep_p$avviato, righe$avviato)
  expect_identical(prep_p$attivo, righe$attivo)

  # le righe conservate coincidono con quelle del dato completo, stesse
  # colonne derivate
  comuni <- prep[match(prep_p$id, prep$id)]
  expect_identical(prep_p$giornate, comuni$giornate)
  expect_identical(prep_p$ccnl_key, comuni$ccnl_key)
  expect_identical(prep_p$macro_tipologia, comuni$macro_tipologia)
  expect_identical(
    setdiff(names(prep_p), names(prep)),
    character(0)
  )
  expect_true("perimetro_ccnl" %in% names(prep))
  expect_identical(
    prep$perimetro_ccnl,
    .flag_perimetro(cob)[match(prep$id, cob$id)]
  )

  # l'input non e' stato modificato
  expect_false("perimetro_ccnl" %in% names(cob))
  expect_identical(nrow(cob), 5000L)
})

test_that("prepare_rapporti() segnala con un messaggio le righe escluse dal perimetro", {
  expect_message(prepare_rapporti(cob), "perimetro")
  expect_message(
    prepare_rapporti(cob),
    "esclusi 254 rapporti su 5000"
  )
  expect_message(prepare_rapporti(cob, perimetro = "standard"), "standard")
  expect_no_message(prepare_rapporti(cob, perimetro = "completo"))
  expect_message(filter_perimetro(cob), "4 tipologie")
  expect_no_message(filter_perimetro(cob, perimetro = "completo"))
})

test_that("con perimetro = 'standard' prepare_rapporti() esclude solo i codici esclusa_standard", {
  prep_s <- suppressMessages(prepare_rapporti(cob, perimetro = "standard"))
  meta <- attr(prep_s, "ccnlcob_meta")
  keep_s <- .flag_standard(cob)

  expect_identical(meta$perimetro, "standard")
  expect_identical(meta$n_dropped_perimetro, 235L)
  expect_identical(meta$n_dropped_perimetro, sum(!keep_s))
  expect_setequal(setdiff(cob$id, prep_s$id), cob$id[!keep_s])
  expect_identical(
    nrow(prep_s),
    meta$n_input - meta$n_dropped_perimetro - meta$n_dropped_window
  )
  expect_setequal(
    meta$esclusi_perimetro$cod_tipologia_contrattuale,
    c("C.01.00", "B.03.00", "B.04.00")
  )
  expect_identical(sum(meta$esclusi_perimetro$n), 235L)
  # C.03.00 (LSU) resta nello standard ma non nel perimetro CCNL: la colonna
  # perimetro_ccnl lo segnala senza eliminarlo
  expect_true("C.03.00" %in% prep_s$cod_tipologia_contrattuale)
  expect_identical(
    sum(!prep_s$perimetro_ccnl),
    sum(prep_s$cod_tipologia_contrattuale == "C.03.00")
  )
  expect_identical(
    prep_s$perimetro_ccnl,
    .flag_perimetro(cob)[match(prep_s$id, cob$id)]
  )
  # standard e ccnl: lo standard conserva 19 righe in piu' (C.03.00)
  prep_p <- suppressMessages(prepare_rapporti(cob))
  expect_identical(nrow(prep_s) - nrow(prep_p), 19L)
  expect_true(all(prep_p$id %in% prep_s$id))
})

test_that("filter_perimetro() e prepare_rapporti() escludono le stesse righe", {
  filtrato <- suppressMessages(filter_perimetro(cob))
  prep_p <- suppressMessages(prepare_rapporti(cob))
  info <- attr(filtrato, "ccnlcob_perimetro")
  meta <- attr(prep_p, "ccnlcob_meta")
  keep <- .flag_perimetro(cob)

  expect_setequal(setdiff(cob$id, filtrato$id), setdiff(cob$id, prep_p$id))
  expect_identical(filtrato$id, cob$id[keep])
  expect_identical(info$perimetro, "ccnl")
  expect_identical(info$n_input, 5000L)
  expect_identical(info$n_kept, sum(keep))
  expect_identical(info$n_dropped, meta$n_dropped_perimetro)
  expect_identical(info$n_tipologia_ignota, meta$n_tipologia_ignota)
  expect_identical(info$esclusi, meta$esclusi_perimetro)
  expect_identical(nrow(filtrato), info$n_kept)
  expect_identical(nrow(filtrato), info$n_input - info$n_dropped)
  expect_true(all(filtrato$perimetro_ccnl))
  # filter_perimetro() non tocca sentinelle e date
  expect_identical(filtrato$fine, cob$fine[keep])
  expect_identical(filtrato$inizio, cob$inizio[keep])
  # prepare_rapporti() non espone l'attributo di filter_perimetro()
  expect_null(attr(prep_p, "ccnlcob_perimetro"))

  # perimetro completo: tutte le righe, colonna aggiunta con il flag
  completo <- filter_perimetro(cob, perimetro = "completo")
  info_c <- attr(completo, "ccnlcob_perimetro")
  expect_identical(nrow(completo), nrow(cob))
  expect_identical(completo$id, cob$id)
  expect_identical(info_c$n_dropped, 0L)
  expect_identical(info_c$n_kept, 5000L)
  expect_identical(nrow(info_c$esclusi), 0L)
  expect_true("perimetro_ccnl" %in% names(completo))
  expect_identical(completo$perimetro_ccnl, keep)
  expect_identical(sum(!completo$perimetro_ccnl), 254L)
  expect_identical(
    setdiff(names(completo), names(cob)),
    "perimetro_ccnl"
  )
  # l'input non viene modificato
  expect_false("perimetro_ccnl" %in% names(cob))
})

test_that("i totali di rank_ccnl() sul perimetro CCNL coincidono con il calcolo indipendente sul sottoinsieme", {
  prep_p <- suppressMessages(prepare_rapporti(cob))
  ranking_p <- rank_ccnl(prep_p, measures = .misure)
  keep <- .flag_perimetro(cob)
  ind <- .prepara_indipendente(cob[keep], .as_of_indipendente(cob))

  .expect_misure_uguali(ranking_p, .misure_base(ind$righe))
  expect_identical(sum(ranking_p$giornate), sum(ind$righe$giornate))
  expect_identical(sum(ranking_p$n_rapporti), sum(ind$righe$avviato))
  expect_identical(sum(ranking_p$stock), sum(ind$righe$attivo))
  expect_identical(sum(ranking_p$giornate), sum(prep_p$giornate))
  for (m in .misure) {
    expect_equal(sum(ranking_p[[paste0("quota_", m)]]), 1, tolerance = 1e-12)
  }

  # rispetto al perimetro completo: meno giornate, mai di piu' per chiave
  expect_lt(sum(ranking_p$giornate), sum(ranking$giornate))
  expect_identical(
    sum(ranking$giornate) - sum(ranking_p$giornate),
    sum(prep$giornate[!prep$perimetro_ccnl])
  )
  m <- match(ranking_p$ccnl_key, ranking$ccnl_key)
  expect_false(anyNA(m))
  expect_true(all(ranking_p$giornate <= ranking$giornate[m]))
  expect_true(all(ranking_p$n_rapporti <= ranking$n_rapporti[m]))
  expect_true(all(ranking_p$n_lavoratori <= ranking$n_lavoratori[m]))
  expect_true(all(ranking_p$stock <= ranking$stock[m]))
  # le chiavi sparite dal ranking, se ce ne sono, avevano solo righe escluse
  sparite <- setdiff(
    .chiave_chr(ranking$ccnl_key),
    .chiave_chr(ranking_p$ccnl_key)
  )
  for (k in sparite) {
    righe_k <- prep[.chiave_chr(ccnl_key) == k]
    expect_false(any(righe_k$perimetro_ccnl))
  }

  # la selezione resta un prefisso dell'ordine di rank
  keys <- select_ccnl_rilevanti(
    ranking_p,
    measure = "giornate",
    cum_share = 0.8
  )
  expect_gt(length(keys), 0L)
  expect_identical(
    keys,
    .ordine_selezione(ranking_p, "giornate")[seq_along(keys)]
  )
  expect_true(all(keys %in% prep_p$ccnl_key))
})

test_that("una fixture nuova attraversa la catena con il perimetro di default e conteggi coerenti", {
  raw <- generate_cob_sintetico(n_persone = 60, n_rapporti = 400, seed = 7)
  keep <- .flag_perimetro(raw)
  expect_gt(sum(!keep), 0L)

  expect_no_error(suppressMessages({
    prep_f <- prepare_rapporti(raw)
    add_cpi(prep_f, lookup = cpi_lookup)
    ranking_f <- rank_ccnl(prep_f, measures = .misure)
    keys_f <- select_ccnl_rilevanti(
      ranking_f,
      measure = "giornate",
      cum_share = 0.8
    )
    cpi_f <- ccnl_by_cpi(prep_f, measure = "giornate")
    tip_f <- ccnl_by_tipologia(prep_f, measure = "n_rapporti")
  }))
  expect_message(prepare_rapporti(raw), "perimetro")

  meta <- attr(prep_f, "ccnlcob_meta")
  expect_identical(meta$perimetro, "ccnl")
  expect_identical(meta$n_input, 400L)
  expect_identical(meta$n_input, sum(keep) + meta$n_dropped_perimetro)
  expect_identical(meta$n_dropped_perimetro, sum(!keep))
  expect_identical(sum(meta$esclusi_perimetro$n), meta$n_dropped_perimetro)
  expect_identical(
    nrow(prep_f),
    400L - meta$n_dropped_perimetro - meta$n_dropped_window
  )
  expect_setequal(setdiff(raw$id, prep_f$id), raw$id[!keep])
  expect_true(all(prep_f$perimetro_ccnl))

  ind <- .prepara_indipendente(raw[keep], .as_of_indipendente(raw))
  expect_identical(meta$as_of, ind$as_of)
  expect_identical(meta$window, ind$window)
  expect_identical(meta$n_sentinel_fine, ind$n_sentinel_fine)
  expect_identical(meta$n_fine_lt_inizio, ind$n_fine_lt_inizio)
  expect_identical(meta$n_dropped_window, ind$n_dropped_window)
  expect_identical(sum(prep_f$giornate), sum(ind$righe$giornate))
  .expect_misure_uguali(ranking_f, .misure_base(ind$righe))

  expect_identical(sum(cpi_f$giornate), sum(prep_f$giornate))
  expect_identical(sum(tip_f$n_rapporti), sum(prep_f$avviato))
  # nessuna macro-classe fuori perimetro (Collaborazioni, Tirocinio) resta
  expect_false(any(tip_f$tipologia %in% c("Collaborazioni", "Tirocinio")))
  expect_setequal(
    keys_f,
    .ordine_selezione(ranking_f, "giornate")[seq_along(keys_f)]
  )
})
