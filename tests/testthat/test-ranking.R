# Test di rank_ccnl() e select_ccnl_rilevanti() (R/ranking.R). Fase 1.
#
# Le tabelle "preparate" sono costruite a mano (senza prepare_rapporti())
# aggiungendo le colonne del contratto di ingresso con regole semplici.

# 1. Fixture -----

.as_of <- as.Date("2024-12-31")

# Tabella preparata dalla fixture sintetica: solo rapporti senza sentinelle.
# `attivo` segue la regola di prepare_rapporti(): rapporto aperto ad as_of,
# cioè fine non osservata; nella fixture sono le righe con `troncata = 1`
# (fine chiusa a monte alla data di stabilizzazione, che coincide con
# `.as_of`), mentre una fine osservata uguale ad as_of chiude il rapporto.
.prepara_fixture <- function(...) {
  dt <- generate_cob_sintetico(...)
  dt <- dt[fine >= inizio & fine <= .as_of]
  dt[, `:=`(
    ccnl_key = codice_cnel,
    giornate = as.integer(pmin(fine, .as_of) - inizio + 1L),
    avviato = TRUE,
    attivo = troncata == 1L,
    anno = as.integer(data.table::year(inizio)),
    trimestre = paste0(
      data.table::year(inizio),
      "-Q",
      data.table::quarter(inizio)
    )
  )]
  dt[]
}

fixture <- .prepara_fixture(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
)

# Sei rapporti costruiti a mano: un pari merito (B, C), un CCNL con due
# rapporti della stessa persona (A) e una riga non classificata.
.sei_rapporti <- function() {
  data.table::data.table(
    cf = c("P1", "P2", "P3", "P4", "P5", "P1"),
    datore = c("D1", "D2", "D3", "D4", "D5", "D1"),
    ccnl_key = c("A", "B", "C", "D", NA, "A"),
    giornate = c(100L, 50L, 50L, 10L, 40L, 20L),
    avviato = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE),
    attivo = c(TRUE, FALSE, TRUE, TRUE, TRUE, FALSE),
    anno = c(2023L, 2023L, 2024L, 2024L, 2024L, 2023L),
    sesso = c("F", "M", "F", "M", "F", "F")
  )
}

# Ranking a mano su quattro CCNL con quote 0.5, 0.3, 0.15, 0.05 e una riga
# non classificata (quota 0 sul totale: giornate = 0).
.ranking_mano <- function(con_na = FALSE) {
  dt <- data.table::data.table(
    cf = c("P1", "P2", "P3", "P4"),
    ccnl_key = c("A", "B", "C", "D"),
    giornate = c(50L, 30L, 15L, 5L),
    avviato = TRUE
  )
  if (con_na) {
    dt <- data.table::rbindlist(list(
      dt,
      data.table::data.table(
        cf = "P5",
        ccnl_key = NA_character_,
        giornate = 100L,
        avviato = TRUE
      )
    ))
  }
  rank_ccnl(dt, measures = c("giornate", "n_lavoratori"))
}

# Quote di una misura raggruppate: ogni gruppo deve sommare a 1.
.somme_quote <- function(ranking, misura, grp = character(0)) {
  qcol <- paste0("quota_", misura)
  ranking[, list(s = sum(.SD[[qcol]])), by = grp, .SDcols = qcol][["s"]]
}

# 2. rank_ccnl(): struttura -----

test_that("rank_ccnl() restituisce una riga per CCNL con le colonne attese", {
  r <- rank_ccnl(.sei_rapporti(), measures = c("giornate", "n_lavoratori"))
  expect_s3_class(r, "data.table")
  expect_identical(
    names(r),
    c(
      "ccnl_key",
      "classe",
      "giornate",
      "quota_giornate",
      "rank_giornate",
      "quota_cum_giornate",
      "n_lavoratori",
      "quota_n_lavoratori",
      "rank_n_lavoratori",
      "quota_cum_n_lavoratori"
    )
  )
  expect_identical(nrow(r), 5L)
  expect_identical(r$ccnl_key, c("A", "B", "C", "D", NA))
  expect_identical(
    r$classe,
    c("CCNL", "CCNL", "CCNL", "CCNL", "Non classificati")
  )
  expect_equal(
    attr(r, "ccnlcob_ranking"),
    list(measures = c("giornate", "n_lavoratori"), by = NULL, periodo = NULL)
  )
})

test_that("rank_ccnl() non modifica l'input", {
  dt <- .sei_rapporti()
  prima <- data.table::copy(dt)
  rank_ccnl(dt, measures = c("giornate", "stock", "n_datori"))
  expect_identical(dt, prima)
})

# 3. rank_ccnl(): misure, quote e rank -----

test_that("rank_ccnl() assegna rank decrescenti con pari merito e NA sui non classificati", {
  r <- rank_ccnl(.sei_rapporti(), measures = "giornate")
  expect_equal(r$giornate, c(120L, 50L, 50L, 10L, 40L))
  expect_equal(r$rank_giornate, c(1L, 2L, 2L, 4L, NA_integer_))
  expect_type(r$rank_giornate, "integer")
  expect_equal(
    r$quota_giornate,
    c(120, 50, 50, 10, 40) / 270,
    tolerance = 1e-12
  )
  expect_equal(
    r$quota_cum_giornate,
    c(120, 170, 220, 230, NA) / 270,
    tolerance = 1e-12
  )
  expect_equal(sum(r$quota_giornate), 1, tolerance = 1e-12)
})

test_that("rank_ccnl() calcola n_rapporti e n_lavoratori sui soli avviati e con cf distinti", {
  r <- rank_ccnl(.sei_rapporti(), measures = c("n_rapporti", "n_lavoratori"))
  # A ha due rapporti di P1, uno non avviato: 1 rapporto, 1 lavoratore.
  expect_identical(r[ccnl_key == "A"]$n_rapporti, 1L)
  expect_identical(r[ccnl_key == "A"]$n_lavoratori, 1L)
  expect_identical(r[is.na(ccnl_key)]$n_lavoratori, 1L)
  expect_identical(sum(r$n_rapporti), 5L)

  dt <- .sei_rapporti()
  dt[ccnl_key == "A", avviato := TRUE]
  dt[ccnl_key == "B", cf := "P1"]
  r2 <- rank_ccnl(dt, measures = "n_lavoratori")
  expect_identical(r2[ccnl_key == "A"]$n_lavoratori, 1L)
  expect_identical(sum(r2$n_lavoratori), 5L)
})

test_that("rank_ccnl() calcola stock sugli attivi e n_datori sui datori distinti", {
  r <- rank_ccnl(.sei_rapporti(), measures = c("stock", "n_datori"))
  expect_identical(r[ccnl_key == "A"]$stock, 1L)
  expect_identical(r[ccnl_key == "B"]$stock, 0L)
  expect_identical(sum(r$stock), 4L)
  expect_identical(r[ccnl_key == "A"]$n_datori, 1L)
  expect_identical(r[ccnl_key %in% "B"]$rank_stock, 4L)
})

test_that("rank_ccnl() considera avviato e attivo TRUE quando mancano, con messaggio", {
  dt <- .sei_rapporti()[, c("avviato", "attivo") := NULL]
  expect_message(
    expect_message(
      r <- rank_ccnl(dt, measures = c("n_rapporti", "stock")),
      "avviato"
    ),
    "attivo"
  )
  expect_message(rank_ccnl(dt, measures = "stock"), "attivo")
  expect_equal(r[ccnl_key == "A"]$n_rapporti, 2L)
  expect_equal(sum(r$stock), 6L)
  expect_silent(rank_ccnl(dt, measures = "giornate"))
})

test_that("rank_ccnl() tratta NA in avviato e attivo come FALSE", {
  dt <- .sei_rapporti()
  dt[1L, `:=`(avviato = NA, attivo = NA)]
  r <- rank_ccnl(dt, measures = c("n_rapporti", "n_lavoratori", "stock"))
  expect_identical(r[ccnl_key == "A"]$n_rapporti, 0L)
  expect_identical(r[ccnl_key == "A"]$n_lavoratori, 0L)
  expect_identical(r[ccnl_key == "A"]$stock, 0L)
})

test_that("rank_ccnl() sulla fixture: quote a 1, rank coerenti, ordinamento per la prima misura", {
  r <- rank_ccnl(fixture, measures = c("n_lavoratori", "giornate", "stock"))
  expect_equal(nrow(r), data.table::uniqueN(fixture$ccnl_key))
  for (m in c("n_lavoratori", "giornate", "stock")) {
    expect_equal(.somme_quote(r, m), 1, tolerance = 1e-12)
    cls <- r[classe == "CCNL"]
    attesi <- as.integer(rank(-cls[[m]], ties.method = "min"))
    expect_identical(cls[[paste0("rank_", m)]], attesi)
    # quota cumulata monotona lungo il rank della misura, non lungo le righe
    lungo_rank <- cls[order(cls[[paste0("rank_", m)]], ccnl_key)]
    cum <- lungo_rank[[paste0("quota_cum_", m)]]
    expect_true(all(diff(cum) >= -1e-12))
    expect_equal(
      cum,
      cumsum(lungo_rank[[paste0("quota_", m)]]),
      tolerance = 1e-12
    )
  }
  expect_identical(
    r$rank_n_lavoratori[-nrow(r)],
    sort(r$rank_n_lavoratori[-nrow(r)])
  )
  expect_true(is.na(r$ccnl_key[nrow(r)]))
  expect_identical(
    r[classe == "CCNL"]$n_lavoratori,
    r[classe == "CCNL"][,
      data.table::uniqueN(
        fixture[ccnl_key == .BY$ccnl_key & avviato == TRUE]$cf
      ),
      by = ccnl_key
    ]$V1
  )
})

# 4. rank_ccnl(): periodo, by, etichette -----

test_that("rank_ccnl() con periodo = 'anno' aggiunge la colonna e raggruppa per anno", {
  r <- rank_ccnl(.sei_rapporti(), measures = "giornate", periodo = "anno")
  expect_equal(names(r)[1:3], c("anno", "ccnl_key", "classe"))
  expect_equal(r$anno, c(2023L, 2023L, 2024L, 2024L, 2024L))
  expect_equal(r$ccnl_key, c("A", "B", "C", "D", NA))
  expect_equal(r$giornate, c(120L, 50L, 50L, 10L, 40L))
  expect_equal(r$rank_giornate, c(1L, 2L, 1L, 2L, NA_integer_))
  expect_equal(.somme_quote(r, "giornate", "anno"), c(1, 1), tolerance = 1e-12)
  expect_equal(attr(r, "ccnlcob_ranking")$periodo, "anno")

  rf <- rank_ccnl(fixture, measures = "giornate", periodo = "trimestre")
  expect_equal(
    .somme_quote(rf, "giornate", "trimestre"),
    rep(1, data.table::uniqueN(fixture$trimestre)),
    tolerance = 1e-12
  )
  expect_identical(nrow(rf), nrow(unique(fixture[, list(trimestre, ccnl_key)])))
})

test_that("rank_ccnl() con by raggruppa e ordina entro gruppo", {
  r <- rank_ccnl(
    .sei_rapporti(),
    measures = "giornate",
    by = "sesso",
    periodo = "anno"
  )
  expect_equal(names(r)[1:4], c("sesso", "anno", "ccnl_key", "classe"))
  expect_equal(nrow(r), 5L)
  expect_equal(r$sesso, c("F", "F", "F", "M", "M"))
  expect_equal(r$rank_giornate, c(1L, 1L, NA, 1L, 1L))
  expect_equal(
    .somme_quote(r, "giornate", c("sesso", "anno")),
    rep(1, 4),
    tolerance = 1e-12
  )

  rf <- rank_ccnl(fixture, measures = c("giornate", "n_rapporti"), by = "sesso")
  expect_equal(
    .somme_quote(rf, "n_rapporti", "sesso"),
    c(1, 1),
    tolerance = 1e-12
  )
  attesi <- rf[
    classe == "CCNL",
    list(
      ok = identical(
        rank_giornate,
        as.integer(rank(-giornate, ties.method = "min"))
      )
    ),
    by = sesso
  ]
  expect_true(all(attesi$ok))
})

test_that("rank_ccnl() aggancia le etichette senza alterare le righe", {
  etichette <- data.table::data.table(
    ccnl_key = c("A", "B", "Z"),
    ccnl_titolo = c("Titolo A", "Titolo B", "Titolo Z"),
    macro_settore_cnel = c("S1", "S1", "S9")
  )
  r <- rank_ccnl(
    .sei_rapporti(),
    measures = "giornate",
    ccnl_labels = etichette
  )
  expect_identical(nrow(r), 5L)
  expect_identical(
    names(r)[1:4],
    c("ccnl_key", "classe", "ccnl_titolo", "macro_settore_cnel")
  )
  expect_equal(r$ccnl_titolo, c("Titolo A", "Titolo B", NA, NA, NA))
  expect_equal(r$rank_giornate, c(1L, 2L, 2L, 4L, NA_integer_))

  duplicate <- etichette[c(1L, 1L, 2L)]
  expect_error(
    rank_ccnl(.sei_rapporti(), ccnl_labels = duplicate),
    "duplicate"
  )
  expect_error(
    rank_ccnl(.sei_rapporti(), ccnl_labels = etichette[, list(ccnl_titolo)]),
    "ccnl_key"
  )
  expect_error(
    rank_ccnl(
      .sei_rapporti(),
      measures = "giornate",
      ccnl_labels = data.table::data.table(ccnl_key = "A", giornate = 1L)
    ),
    "presenti"
  )
})

# 5. rank_ccnl(): errori -----

test_that("rank_ccnl() segnala colonne mancanti suggerendo prepare_rapporti()", {
  expect_error(
    rank_ccnl(.sei_rapporti()[, ccnl_key := NULL]),
    "prepare_rapporti"
  )
  expect_error(
    rank_ccnl(.sei_rapporti()[, giornate := NULL]),
    "giornate"
  )
  expect_error(rank_ccnl(list(a = 1)), "data.table")
})

test_that("rank_ccnl() rifiuta misure, by e periodo non validi", {
  dt <- .sei_rapporti()
  expect_error(rank_ccnl(dt, measures = "retribuzione"), "non ammesse")
  expect_error(rank_ccnl(dt, measures = character(0)), "measures")
  expect_error(rank_ccnl(dt, by = "cpi_code"), "cpi_code")
  expect_error(rank_ccnl(dt, by = "ccnl_key"), "ccnl_key")
  expect_error(rank_ccnl(dt, periodo = "mese"), "periodo")
  expect_error(
    rank_ccnl(data.table::copy(dt)[, anno := NULL], periodo = "anno"),
    "prepare_rapporti"
  )
  expect_error(rank_ccnl(dt, by = "anno", periodo = "anno"), "periodo")
})

test_that("rank_ccnl() richiede datore e giornate_effettive solo per le misure che le usano", {
  dt <- .sei_rapporti()[, datore := NULL]
  expect_error(rank_ccnl(dt, measures = "n_datori"), "datore")
  expect_error(
    rank_ccnl(dt, measures = "giornate_effettive"),
    "giornate_effettive"
  )
  expect_silent(rank_ccnl(dt, measures = c("n_rapporti", "giornate")))

  dt[, giornate_effettive := giornate / 2]
  r <- rank_ccnl(dt, measures = "giornate_effettive")
  expect_equal(r$giornate_effettive, c(60, 25, 25, 5, 20), tolerance = 1e-12)
})

# 6. select_ccnl_rilevanti(): chiavi -----

test_that("select_ccnl_rilevanti() include il CCNL con cui la quota cumulata raggiunge la soglia", {
  r <- .ranking_mano()
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.8), c("A", "B"))
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.7), c("A", "B"))
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.5), "A")
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.9), c("A", "B", "C"))
  expect_identical(
    select_ccnl_rilevanti(r, cum_share = 1),
    c("A", "B", "C", "D")
  )
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.01), "A")
})

test_that("select_ccnl_rilevanti() usa le quote sul totale inclusi i non classificati", {
  r <- .ranking_mano(con_na = TRUE)
  # quote: A 0.25, B 0.15, C 0.075, D 0.025, NA 0.5
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.3), c("A", "B"))
  expect_identical(
    select_ccnl_rilevanti(r, cum_share = 0.8),
    c("A", "B", "C", "D")
  )
  expect_false(anyNA(select_ccnl_rilevanti(r, cum_share = 1)))
})

test_that("select_ccnl_rilevanti() applica top_n da solo e combinato con cum_share", {
  r <- .ranking_mano()
  expect_identical(select_ccnl_rilevanti(r, top_n = 1, cum_share = NULL), "A")
  expect_identical(
    select_ccnl_rilevanti(r, top_n = 3, cum_share = NULL),
    c("A", "B", "C")
  )
  expect_identical(
    select_ccnl_rilevanti(r, top_n = 10, cum_share = NULL),
    c("A", "B", "C", "D")
  )
  expect_identical(select_ccnl_rilevanti(r, top_n = 1, cum_share = 0.9), "A")
  expect_identical(
    select_ccnl_rilevanti(r, top_n = 3, cum_share = 0.7),
    c("A", "B")
  )
})

test_that("select_ccnl_rilevanti() seleziona per gruppo e restituisce chiavi uniche in ordine", {
  r <- rank_ccnl(.sei_rapporti(), measures = "giornate", periodo = "anno")
  # 2023: A 0.71, B 0.29; 2024: C 0.5, D 0.1, NA 0.4
  expect_identical(select_ccnl_rilevanti(r, cum_share = 0.6), c("A", "C", "D"))
  expect_identical(
    select_ccnl_rilevanti(r, top_n = 1, cum_share = NULL),
    c("A", "C")
  )

  dt <- data.table::rbindlist(list(
    .sei_rapporti(),
    data.table::data.table(
      cf = "P9",
      datore = "D9",
      ccnl_key = "A",
      giornate = 5L,
      avviato = TRUE,
      attivo = FALSE,
      anno = 2024L,
      sesso = "M"
    )
  ))
  r2 <- rank_ccnl(dt, measures = "giornate", periodo = "anno")
  keys <- select_ccnl_rilevanti(r2, cum_share = 1)
  expect_identical(keys, c("A", "B", "C", "D"))
  expect_identical(anyDuplicated(keys), 0L)
})

test_that("select_ccnl_rilevanti() opera su una misura diversa dalla prima del ranking", {
  r <- .ranking_mano()
  expect_identical(
    select_ccnl_rilevanti(r, measure = "n_lavoratori", cum_share = 0.5),
    c("A", "B")
  )
  expect_identical(
    select_ccnl_rilevanti(
      r,
      measure = "n_lavoratori",
      top_n = 2,
      cum_share = NULL
    ),
    c("A", "B")
  )
})

# 7. select_ccnl_rilevanti(): tabella -----

test_that("select_ccnl_rilevanti(return = 'table') aggrega i residui e conserva i non classificati", {
  r <- .ranking_mano(con_na = TRUE)
  tab <- select_ccnl_rilevanti(r, cum_share = 0.3, return = "table")
  expect_s3_class(tab, "data.table")
  expect_identical(
    names(tab),
    c(
      "ccnl_key",
      "classe",
      "selezionato",
      setdiff(names(r), c("ccnl_key", "classe"))
    )
  )
  expect_identical(tab$ccnl_key, c("A", "B", "Altri CCNL", NA))
  expect_identical(
    tab$classe,
    c("CCNL", "CCNL", "Altri CCNL", "Non classificati")
  )
  expect_equal(tab$selezionato, c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(tab[classe == "Altri CCNL"]$giornate, 20L)
  expect_equal(tab[classe == "Altri CCNL"]$n_lavoratori, 2L)
  expect_true(is.na(tab[classe == "Altri CCNL"]$rank_giornate))
  expect_true(is.na(tab[classe == "Altri CCNL"]$quota_cum_giornate))
  expect_equal(tab[is.na(ccnl_key)]$giornate, 100L)
  expect_equal(tab[is.na(ccnl_key)]$classe, "Non classificati")
  expect_equal(sum(tab$quota_giornate), 1, tolerance = 1e-12)
  expect_equal(sum(tab$quota_n_lavoratori), 1, tolerance = 1e-12)
  expect_equal(
    tab[classe == "Altri CCNL"]$quota_giornate,
    20 / 200,
    tolerance = 1e-12
  )
  expect_equal(tab$rank_giornate[1:2], c(1L, 2L))
  expect_identical(attr(tab, "ccnlcob_ranking"), attr(r, "ccnlcob_ranking"))
  expect_identical(attr(tab, "ccnlcob_selezione")$keys, c("A", "B"))
  expect_identical(attr(tab, "ccnlcob_selezione")$cum_share, 0.3)
})

test_that("select_ccnl_rilevanti(return = 'table') rispetta other_label e i gruppi", {
  r <- rank_ccnl(
    .sei_rapporti(),
    measures = c("giornate", "n_lavoratori"),
    periodo = "anno"
  )
  tab <- select_ccnl_rilevanti(
    r,
    cum_share = 0.6,
    other_label = "Residuo",
    return = "table"
  )
  expect_equal(tab$anno, c(2023L, 2023L, 2024L, 2024L, 2024L))
  expect_equal(tab$ccnl_key, c("A", "Residuo", "C", "D", NA))
  expect_equal(tab[ccnl_key == "Residuo"]$giornate, 50L)
  expect_equal(tab[ccnl_key == "Residuo"]$classe, "Altri CCNL")
  expect_equal(
    .somme_quote(tab, "giornate", "anno"),
    c(1, 1),
    tolerance = 1e-12
  )
  expect_equal(
    .somme_quote(tab, "n_lavoratori", "anno"),
    c(1, 1),
    tolerance = 1e-12
  )
  expect_identical(attr(tab, "ccnlcob_selezione")$other_label, "Residuo")
})

test_that("select_ccnl_rilevanti(return = 'table') senza residui non aggiunge la classe residua", {
  r <- .ranking_mano()
  tab <- select_ccnl_rilevanti(r, cum_share = 1, return = "table")
  expect_identical(tab$ccnl_key, c("A", "B", "C", "D"))
  expect_true(all(tab$selezionato))
  expect_false("Altri CCNL" %in% tab$classe)
})

test_that("select_ccnl_rilevanti() non modifica il ranking in ingresso e conserva le etichette", {
  etichette <- data.table::data.table(
    ccnl_key = c("A", "B"),
    ccnl_titolo = c("Titolo A", "Titolo B")
  )
  r <- rank_ccnl(
    .sei_rapporti(),
    measures = "giornate",
    ccnl_labels = etichette
  )
  prima <- data.table::copy(r)
  tab <- select_ccnl_rilevanti(r, cum_share = 0.5, return = "table")
  expect_identical(r, prima)
  # A copre 0.44 < 0.5: anche B viene selezionato
  expect_identical(tab$ccnl_titolo, c("Titolo A", "Titolo B", NA, NA))
})

test_that("select_ccnl_rilevanti() ricava i gruppi dalle colonne se manca l'attributo", {
  r <- rank_ccnl(.sei_rapporti(), measures = "giornate", periodo = "anno")
  data.table::setattr(r, "ccnlcob_ranking", NULL)
  expect_identical(
    select_ccnl_rilevanti(r, top_n = 1, cum_share = NULL),
    c("A", "C")
  )
})

# 8. select_ccnl_rilevanti(): errori -----

test_that("select_ccnl_rilevanti() rifiuta misure assenti e parametri non validi", {
  r <- .ranking_mano()
  expect_error(select_ccnl_rilevanti(r, measure = "stock"), "assente")
  expect_error(select_ccnl_rilevanti(r, cum_share = 0), "cum_share")
  expect_error(select_ccnl_rilevanti(r, cum_share = 1.5), "cum_share")
  expect_error(select_ccnl_rilevanti(r, top_n = 0, cum_share = NULL), "top_n")
  expect_error(select_ccnl_rilevanti(r, top_n = 2.5), "top_n")
  expect_error(
    select_ccnl_rilevanti(r, top_n = NULL, cum_share = NULL),
    "almeno"
  )
  expect_error(select_ccnl_rilevanti(r, other_label = "A"), "other_label")
  expect_error(select_ccnl_rilevanti(r, return = "vector"), "keys")
  expect_error(
    select_ccnl_rilevanti(data.table::data.table(x = 1)),
    "rank_ccnl"
  )
})
