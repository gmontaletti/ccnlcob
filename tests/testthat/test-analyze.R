# Test di analyze_ccnl() e del metodo print.ccnlcob_result (R/analyze.R). Fase 4.

# 1. Fixture -----

cob <- .carica_dataset("cob_esempio")
cpi_lookup <- .carica_dataset("cpi_esempio")
fixture <- generate_cob_sintetico(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
)

.indice_anni <- function(dt) {
  anni <- sort(unique(data.table::year(dt$inizio)))
  data.table::data.table(anno = anni, indice = 100 + 2 * seq_along(anni))
}

.elementi <- c(
  "meta",
  "ranking",
  "ranking_periodo",
  "rilevanti",
  "keys",
  "cpi",
  "tipologie",
  "retribuzioni",
  "qualita"
)

res <- analyze_ccnl(cob, lookup_cpi = cpi_lookup, min_n = 10)

# 2. Struttura del risultato -----

test_that("analyze_ccnl() restituisce un ccnlcob_result completo con lookup CPI esplicito", {
  expect_s3_class(res, "ccnlcob_result")
  expect_named(res, .elementi)
  expect_true(all(vapply(
    res[c(
      "ranking",
      "ranking_periodo",
      "rilevanti",
      "cpi",
      "tipologie",
      "retribuzioni",
      "qualita"
    )],
    data.table::is.data.table,
    logical(1)
  )))
  expect_length(res$meta$passi_saltati, 1L)
  expect_named(res$meta$passi_saltati, "deflate_retribuzione")
  expect_true("add_cpi" %in% res$meta$passi)
  expect_true("compute_giornate_effettive" %in% res$meta$passi)
})

test_that("analyze_ccnl() non modifica l'input", {
  copia <- data.table::copy(cob)
  analyze_ccnl(copia, lookup_cpi = cpi_lookup, min_n = 10)
  expect_identical(copia, cob)
})

test_that("meta riporta versione, finestra, numerosita' e coperture coerenti", {
  meta <- res$meta
  expect_identical(
    meta$versione,
    as.character(utils::packageVersion("ccnlcob"))
  )
  expect_s3_class(meta$as_of, "Date")
  expect_length(meta$window, 2L)
  expect_equal(meta$perimetro, "ccnl")
  expect_equal(meta$ccnl_key, "codice_cnel")
  expect_equal(meta$measure, "giornate")
  expect_identical(meta$n_input, nrow(cob))
  expect_true(meta$n_finestra <= meta$n_input)
  expect_identical(meta$n_rapporti, as.integer(sum(res$ranking$n_rapporti)))
  expect_identical(meta$n_lavoratori, as.integer(data.table::uniqueN(cob$cf)))
  expect_true(meta$copertura_ccnl > 0 && meta$copertura_ccnl < 1)
  expect_true(
    meta$copertura_retribuzione > 0 && meta$copertura_retribuzione < 1
  )
  expect_identical(meta$keys, res$keys)
  expect_true(is.list(meta$preparazione))
  expect_identical(meta$preparazione$as_of, meta$as_of)
  expect_identical(names(meta$tempi), meta$passi)
})

test_that("keys, ranking e rilevanti sono coerenti fra loro", {
  expect_true(all(res$keys %in% res$ranking$ccnl_key))
  expect_true(length(res$keys) <= 20L)
  expect_true(all(
    c("giornate", "giornate_effettive", "n_datori", "stock") %in%
      names(res$ranking)
  ))
  expect_true("anno" %in% names(res$ranking_periodo))
  expect_identical(
    sort(res$rilevanti[selezionato == TRUE, ccnl_key]),
    sort(res$keys)
  )
  expect_equal(sum(res$rilevanti$quota_giornate), 1)
  expect_true("Altri CCNL" %in% res$rilevanti$ccnl_key)
})

test_that("cpi, tipologie e retribuzioni sono ristrette ai CCNL rilevanti", {
  expect_true(all(res$cpi$ccnl_key %in% res$keys))
  expect_true(all(res$tipologie$ccnl_key %in% res$keys))
  expect_true(all(res$retribuzioni$ccnl_key %in% res$keys))
  expect_equal(attr(res$cpi, "ccnlcob_crosstab")$measure, "giornate")
  expect_identical(attr(res$cpi, "ccnlcob_crosstab")$geo, "sede_lavoro")
  expect_identical(attr(res$tipologie, "ccnlcob_crosstab")$level, "macro")
  expect_true(all(
    c("tipologia", "orario", "n_rapporti") %in% names(res$tipologie)
  ))
  expect_true(all(
    c("anno", "mediana", "copertura") %in% names(res$retribuzioni)
  ))
  expect_false("mediana_reale" %in% names(res$retribuzioni))
})

test_that("qualita ha una riga per ccnl_key, NA incluso, con coperture in [0, 1]", {
  q <- res$qualita
  expect_named(
    q,
    c(
      "ccnl_key",
      "n",
      "n_rapporti",
      "quota_troncata",
      "copertura_retribuzione",
      "copertura_ore",
      "copertura_cpi"
    )
  )
  expect_true(anyNA(q$ccnl_key))
  expect_identical(nrow(q), nrow(res$ranking))
  expect_identical(sum(q$n), res$meta$n_finestra)
  for (col in c(
    "quota_troncata",
    "copertura_retribuzione",
    "copertura_ore",
    "copertura_cpi"
  )) {
    expect_true(all(q[[col]] >= 0 & q[[col]] <= 1), info = col)
  }
  expect_true(is.na(q$ccnl_key[nrow(q)]))
})

# 3. Deflazione -----

test_that("analyze_ccnl() deflaziona le retribuzioni quando indice e' fornito", {
  ipca <- .indice_anni(cob)
  out <- analyze_ccnl(cob, lookup_cpi = cpi_lookup, indice = ipca, min_n = 10)
  expect_true(all(
    c("mediana_reale", "p25_reale", "p75_reale") %in% names(out$retribuzioni)
  ))
  expect_true("deflate_retribuzione" %in% out$meta$passi)
  expect_length(out$meta$passi_saltati, 0L)
  base <- max(ipca$anno)
  ultimo <- out$retribuzioni[anno == base]
  expect_equal(ultimo$mediana_reale, ultimo$mediana)
})

test_that("analyze_ccnl() propaga base e periodo trimestrale alla deflazione", {
  ipca <- .indice_anni(cob)
  out <- analyze_ccnl(
    cob,
    lookup_cpi = cpi_lookup,
    indice = ipca,
    base = min(ipca$anno),
    min_n = 10
  )
  primo <- out$retribuzioni[anno == min(ipca$anno)]
  expect_equal(primo$mediana_reale, primo$mediana)
  trim <- analyze_ccnl(
    fixture,
    lookup_cpi = cpi_lookup,
    periodo = "trimestre",
    min_n = 5
  )
  expect_true("trimestre" %in% names(trim$retribuzioni))
  expect_true("trimestre" %in% names(trim$ranking_periodo))
})

# 4. Blocchi facoltativi -----

test_that("effettive = FALSE elimina la misura e registra il passo saltato", {
  out <- analyze_ccnl(
    cob,
    lookup_cpi = cpi_lookup,
    effettive = FALSE,
    min_n = 10
  )
  expect_false("giornate_effettive" %in% names(out$ranking))
  expect_false("compute_giornate_effettive" %in% out$meta$passi)
  expect_true("compute_giornate_effettive" %in% names(out$meta$passi_saltati))
  expect_error(
    analyze_ccnl(cob, measure = "giornate_effettive", effettive = FALSE),
    "effettive = TRUE"
  )
})

test_that("senza retribuzione il blocco retributivo viene saltato", {
  senza <- cob[, !"retribuzione"]
  out <- analyze_ccnl(senza, lookup_cpi = cpi_lookup, min_n = 10)
  expect_null(out$retribuzioni)
  expect_true("retribuzioni" %in% names(out$meta$passi_saltati))
  expect_match(out$meta$passi_saltati[["retribuzioni"]], "retribuzione")
  expect_true(is.na(out$meta$copertura_retribuzione))
  expect_true(all(is.na(out$qualita$copertura_retribuzione)))
  expect_false(is.na(out$qualita$copertura_cpi[1L]))
})

test_that("senza colonna geografica il blocco CPI viene saltato anche senza lookup", {
  senza <- cob[, !"comune_sede_lavoro"]
  out <- analyze_ccnl(senza, min_n = 10)
  expect_null(out$cpi)
  expect_true(all(
    c("add_cpi", "ccnl_by_cpi") %in% names(out$meta$passi_saltati)
  ))
  expect_match(out$meta$passi_saltati[["add_cpi"]], "comune_sede_lavoro")
  expect_true(all(is.na(out$qualita$copertura_cpi)))
  expect_false(is.null(out$tipologie))
  expect_false(is.null(out$retribuzioni))
})

test_that("geo = residenza usa comune_lavoratore", {
  out <- analyze_ccnl(
    fixture,
    geo = "residenza",
    lookup_cpi = cpi_lookup,
    min_n = 5
  )
  expect_identical(attr(out$cpi, "ccnlcob_crosstab")$geo, "residenza")
})

test_that("measure, top_n e cum_share sono propagati alla selezione", {
  out <- analyze_ccnl(
    cob,
    lookup_cpi = cpi_lookup,
    measure = "n_lavoratori",
    top_n = 3,
    cum_share = 1,
    min_n = 10
  )
  expect_length(out$keys, 3L)
  expect_identical(out$meta$measure, "n_lavoratori")
  expect_identical(attr(out$cpi, "ccnlcob_crosstab")$measure, "n_lavoratori")
  expect_identical(attr(out$rilevanti, "ccnlcob_selezione")$top_n, 3L)
})

test_that("ccnl_key = ccnl_warehouse e perimetro completo sono accettati", {
  out <- analyze_ccnl(
    fixture,
    ccnl_key = "ccnl_warehouse",
    perimetro = "completo",
    lookup_cpi = cpi_lookup,
    min_n = 5
  )
  expect_identical(out$meta$ccnl_key, "ccnl_warehouse")
  expect_identical(out$meta$perimetro, "completo")
  expect_identical(
    out$meta$n_finestra,
    out$meta$preparazione$n_input - out$meta$preparazione$n_dropped_window
  )
})

test_that("quiet = FALSE lascia passare i messaggi dei passi intermedi", {
  msgs <- testthat::capture_messages(
    analyze_ccnl(fixture, lookup_cpi = cpi_lookup, min_n = 5, quiet = FALSE)
  )
  expect_true(any(grepl("filter_perimetro", msgs, fixed = TRUE)))
  expect_true(any(grepl("clean_retribuzione", msgs, fixed = TRUE)))
  expect_silent(analyze_ccnl(fixture, lookup_cpi = cpi_lookup, min_n = 5))
})

# 5. Errori -----

test_that("analyze_ccnl() rifiuta input non validi", {
  expect_error(analyze_ccnl(as.data.frame(cob)), "data.table")
  expect_error(analyze_ccnl(cob, measure = "altro"), "Misura non ammessa")
  expect_error(analyze_ccnl(cob, top_n = 0), "top_n")
  expect_error(analyze_ccnl(cob, cum_share = 2), "cum_share")
  expect_error(analyze_ccnl(cob, top_n = NULL, cum_share = NULL), "almeno uno")
  expect_error(analyze_ccnl(cob, min_n = -1), "min_n")
  expect_error(analyze_ccnl(cob, effettive = NA), "effettive")
  expect_error(analyze_ccnl(cob, lookup_cpi = list(a = 1)), "lookup")
  expect_error(analyze_ccnl(cob, indice = 1:3), "indice")
  expect_error(analyze_ccnl(cob, periodo = "mese"), "arg")
  expect_error(
    analyze_ccnl(cob, window = as.Date(c("2024-12-31", "2019-01-01"))),
    "ordinata"
  )
})

test_that("analyze_ccnl() propaga l'errore di un indice che non copre i periodi", {
  ipca <- data.table::data.table(anno = 2024L, indice = 100)
  expect_error(analyze_ccnl(
    cob,
    lookup_cpi = cpi_lookup,
    indice = ipca,
    min_n = 10
  ))
})

# 6. print -----

test_that("print.ccnlcob_result() mostra versione, finestra, primi CCNL e passi saltati", {
  testo <- capture.output(out <- print(res))
  expect_identical(out, res)
  expect_true(any(grepl("<ccnlcob_result>", testo, fixed = TRUE)))
  expect_true(any(grepl(res$meta$versione, testo, fixed = TRUE)))
  expect_true(any(grepl(format(res$meta$window[1L]), testo, fixed = TRUE)))
  expect_true(any(grepl(
    paste0(length(res$keys), " (misura: giornate)"),
    testo,
    fixed = TRUE
  )))
  for (k in res$keys[1:5]) {
    expect_true(any(grepl(k, testo, fixed = TRUE)), info = k)
  }
  expect_true(any(grepl("deflate_retribuzione", testo, fixed = TRUE)))
  expect_output(print(res, n = 2), "primi CCNL")
})

test_that("print.ccnlcob_result() regge un risultato minimo", {
  minimo <- structure(
    list(meta = list(versione = "0.0.0")),
    class = "ccnlcob_result"
  )
  expect_output(print(minimo), "0.0.0")
})
