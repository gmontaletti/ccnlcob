# Test di read_rapporti() e write_results() (R/io.R). Fase 4 e Fase 5.

# 1. Fixture -----

cob <- .carica_dataset("cob_esempio")
cpi_lookup <- .carica_dataset("cpi_esempio")
res <- analyze_ccnl(cob, lookup_cpi = cpi_lookup, min_n = 10)

# Directory temporanea per test, rimossa all'uscita dal test chiamante.
.dir_temporanea <- function(env = parent.frame()) {
  d <- tempfile("ccnlcob_")
  dir.create(d, recursive = TRUE)
  eval(
    substitute(on.exit(unlink(d, recursive = TRUE), add = TRUE)),
    envir = env
  )
  d
}

.senza_attributi <- function(x) {
  x <- data.table::as.data.table(x)
  for (a in grep("^ccnlcob_", names(attributes(x)), value = TRUE)) {
    data.table::setattr(x, a, NULL)
  }
  x
}

.file_attesi <- c(
  "meta.rds",
  "ranking.rds",
  "ranking_periodo.rds",
  "rilevanti.rds",
  "keys.rds",
  "cpi.fst",
  "tipologie.fst",
  "retribuzioni.rds",
  "qualita.rds"
)

# 2. read_rapporti() -----

# 2.1 Fixture in stile warehouse (slice cnelR) -----

# Trasforma un dataset con i nomi del contratto in una tabella con i nomi
# della slice DuckDB di cnelR: id_rapporto, codice_fiscale_*, cod_tipo_orario
# al posto di prior, retribuzione e ore zero-padded con valori non numerici,
# rappres logical e colonne ini_* superflue.
.fixture_warehouse <- function(n_rapporti = 400L) {
  base <- generate_cob_sintetico(
    n_persone = 60,
    n_rapporti = n_rapporti,
    n_ccnl = 8,
    seed = 20260909
  )
  wh <- data.table::copy(base)
  data.table::setnames(
    wh,
    old = c("id", "cf", "datore", "ore", "qualifica", "sesso", "eta"),
    new = c(
      "id_rapporto",
      "codice_fiscale_lavoratore",
      "codice_fiscale_datore",
      "ore_settim_medie",
      "cod_qualifica_prof_istat_3dgt",
      "sesso_lav",
      "eta_lav_inizio"
    )
  )
  wh[, id_rapporto := as.character(id_rapporto)]
  # codici MLPS "ST-TIPO ORARIO": F tempo pieno; P, V, M part-time
  # (orizzontale, verticale, misto); N non definito
  wh[, cod_tipo_orario := data.table::fifelse(prior == 1L, "F", "P")]
  wh[c(1L, 2L, 3L, 4L), cod_tipo_orario := c("N", NA_character_, "V", "M")]
  wh[, prior := NULL]
  wh[, troncata := NULL]
  wh[, eta_lav_inizio := as.numeric(eta_lav_inizio)]
  wh[,
    retribuzione := data.table::fifelse(
      is.na(retribuzione),
      NA_character_,
      sprintf("%09.0f", retribuzione)
    )
  ]
  wh[,
    ore_settim_medie := data.table::fifelse(
      is.na(ore_settim_medie),
      NA_character_,
      sprintf("%02.0f", ore_settim_medie)
    )
  ]
  # valori non numerici: 3 in retribuzione, 2 in ore
  wh[c(3L, 4L, 5L), retribuzione := c("n.d.", "ABC", "")]
  wh[c(6L, 7L), ore_settim_medie := c("xx", "38,5")]
  wh[, rappres := seq_len(.N) %% 3L != 0L]
  wh[, liv_istruzione_lav := sample(c("1", "2", "3", "4"), .N, replace = TRUE)]
  wh[, ini_data_inizio := as.character(inizio)]
  wh[, ini_ccnl := ccnl]
  wh[, ini_retribuzione := retribuzione]
  data.table::setcolorder(wh, c("id_rapporto", "inizio", "fine"))
  wh[]
}

.wh <- .fixture_warehouse()
.n_wh <- nrow(.wh)

# Valori attesi dopo la lettura della fixture warehouse.
.retribuzione_attesa <- suppressWarnings(as.numeric(.wh$retribuzione))
.ore_attese <- suppressWarnings(as.numeric(sub(",", ".", .wh$ore_settim_medie)))

# Nomi di contratto attesi dalla lettura di .wh con columns = NULL.
.colonne_wh_attese <- c(
  "id",
  "cf",
  "inizio",
  "fine",
  "codice_cnel",
  "ccnl",
  "rappres",
  "cod_tipologia_contrattuale",
  "cod_tipo_orario",
  "prior",
  "comune_sede_lavoro",
  "comune_lavoratore",
  "datore",
  "retribuzione",
  "ore",
  "qualifica",
  "ateco_gruppo",
  "eta",
  "sesso",
  "liv_istruzione_lav"
)

.leggi <- function(...) suppressMessages(read_rapporti(...))

.senza_source <- function(x) {
  x <- data.table::copy(x)
  data.table::setattr(x, "ccnlcob_source", NULL)
  x
}

# Scrive la fixture warehouse in un file .duckdb e chiude la connessione.
.scrivi_duckdb <- function(dt, path, table = "sl2_rapporti_36m_classificati") {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbWriteTable(con, table, as.data.frame(dt))
  invisible(path)
}

# 2.2 data.frame e RDS con i nomi del contratto -----

test_that("read_rapporti() accetta un data.frame con i nomi del contratto senza modificarlo", {
  df <- as.data.frame(cob)
  prima <- data.table::copy(df)
  expect_message(dt <- read_rapporti(df), "lette 5.000 righe da data.frame")
  expect_identical(df, prima)
  expect_true(data.table::is.data.table(dt))
  expect_identical(nrow(dt), nrow(cob))
  expect_identical(names(dt), intersect(.colonne_contratto, names(cob)))
  expect_equal(.senza_source(dt), cob[, names(dt), with = FALSE])
  info <- attr(dt, "ccnlcob_source")
  expect_identical(info$source, "data.frame")
  expect_null(info$table)
  expect_identical(info$n, nrow(cob))
  expect_identical(
    info$colonne_mappate,
    stats::setNames(character(0), character(0))
  )
  expect_false(info$prior_derivato)
  expect_identical(
    info$n_non_numerici,
    c(retribuzione = 0L, ore = 0L, eta = 0L)
  )
  expect_null(info$where)
})

test_that("read_rapporti() accetta un data.table senza modificarlo per riferimento", {
  orig <- data.table::copy(cob)
  dt <- .leggi(orig)
  expect_identical(orig, cob)
  data.table::set(dt, j = "cf", value = "X")
  expect_identical(orig$cf, cob$cf)
})

test_that("RDS con i nomi del contratto: roundtrip fedele", {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  saveRDS(cob, f)
  expect_message(dt <- read_rapporti(f), "lette 5.000 righe")
  expect_equal(.senza_source(dt), cob[, names(dt), with = FALSE])
  expect_identical(attr(dt, "ccnlcob_source")$source, f)
  expect_true(inherits(dt$inizio, "Date"))
  expect_identical(class(dt$prior), "integer")
  expect_identical(class(dt$troncata), "integer")
  expect_true(is.numeric(dt$retribuzione))
})

test_that("RDS conserva IDate e converte le date character in Date", {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  x <- data.table::copy(cob)
  x[, inizio := data.table::as.IDate(inizio)]
  x[, fine := as.character(fine)]
  saveRDS(x, f)
  dt <- .leggi(f)
  expect_s3_class(dt$inizio, "IDate")
  expect_identical(class(dt$fine), "Date")
  expect_identical(dt$fine, cob$fine)
})

test_that("RDS che non contiene un data.frame produce un errore", {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  saveRDS(list(a = 1), f)
  expect_error(.leggi(f), "non contiene un data.frame")
})

# 2.3 FST: factor e integer64 -----

test_that("FST con factor zero-padded (stile rap.fst) viene normalizzato", {
  f <- tempfile(fileext = ".fst")
  on.exit(unlink(f), add = TRUE)
  x <- data.table::copy(cob)
  x[, cf := factor(cf)]
  x[, datore := factor(datore)]
  x[, cod_tipologia_contrattuale := factor(cod_tipologia_contrattuale)]
  x[,
    retribuzione := factor(data.table::fifelse(
      is.na(retribuzione),
      NA_character_,
      sprintf("%09.0f", retribuzione)
    ))
  ]
  x[,
    ore := factor(data.table::fifelse(
      is.na(ore),
      NA_character_,
      sprintf("%02.0f", ore)
    ))
  ]
  fst::write_fst(x, f)
  dt <- .leggi(f)
  expect_identical(names(dt), names(cob))
  expect_identical(class(dt$cf), "character")
  expect_identical(class(dt$datore), "character")
  expect_identical(class(dt$cod_tipologia_contrattuale), "character")
  expect_identical(dt$cf, cob$cf)
  expect_equal(dt$retribuzione, cob$retribuzione)
  expect_equal(dt$ore, cob$ore)
  expect_identical(
    attr(dt, "ccnlcob_source")$n_non_numerici[["retribuzione"]],
    0L
  )
  expect_true(all(vapply(dt, function(col) !is.factor(col), logical(1))))
})

test_that("FST: la selezione delle colonne avviene in lettura", {
  f <- tempfile(fileext = ".fst")
  on.exit(unlink(f), add = TRUE)
  fst::write_fst(cob, f)
  dt <- .leggi(f, columns = c("id", "inizio"), validate = FALSE)
  expect_identical(names(dt), c("id", "inizio"))
  expect_identical(dt$id, cob$id)
})

test_that("FST con id integer64 restituisce id character e interi per i flag", {
  skip_if_not_installed("bit64")
  as64 <- get("as.integer64", envir = asNamespace("bit64"))
  f <- tempfile(fileext = ".fst")
  on.exit(unlink(f), add = TRUE)
  x <- data.table::copy(cob)
  x[, id := as64(id)]
  x[, troncata := as64(troncata)]
  fst::write_fst(x, f)
  dt <- .leggi(f)
  expect_identical(class(dt$id), "character")
  expect_identical(dt$id, as.character(cob$id))
  expect_identical(class(dt$troncata), "integer")
  expect_identical(dt$troncata, cob$troncata)
})

# 2.4 Fixture warehouse via RDS: mapping, prior, tipi -----

test_that("i nomi warehouse vengono mappati sul contratto e le ini_* ignorate", {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  saveRDS(.wh, f)
  dt <- .leggi(f)
  expect_identical(names(dt), .colonne_wh_attese)
  expect_false(any(grepl("^ini_", names(dt))))
  info <- attr(dt, "ccnlcob_source")
  expect_identical(
    info$colonne_mappate,
    c(
      id_rapporto = "id",
      codice_fiscale_lavoratore = "cf",
      codice_fiscale_datore = "datore",
      ore_settim_medie = "ore",
      cod_qualifica_prof_istat_3dgt = "qualifica",
      sesso_lav = "sesso",
      eta_lav_inizio = "eta"
    )
  )
  expect_identical(dt$id, .wh$id_rapporto)
  expect_identical(dt$cf, .wh$codice_fiscale_lavoratore)
  expect_identical(dt$datore, .wh$codice_fiscale_datore)
  expect_identical(dt$qualifica, .wh$cod_qualifica_prof_istat_3dgt)
  expect_identical(dt$sesso, .wh$sesso_lav)
  expect_identical(dt$eta, .wh$eta_lav_inizio)
  expect_identical(dt$ccnl, .wh$ccnl)
  expect_identical(dt$liv_istruzione_lav, .wh$liv_istruzione_lav)
})

test_that("prior viene derivata da cod_tipo_orario, che resta nella tabella", {
  dt <- .leggi(.wh)
  expect_true(attr(dt, "ccnlcob_source")$prior_derivato)
  expect_true("cod_tipo_orario" %in% names(dt))
  expect_identical(class(dt$prior), "integer")
  # F -> 1; P, V, M -> 0; N e NA -> NA
  attesa <- data.table::fifelse(
    .wh$cod_tipo_orario == "F",
    1L,
    data.table::fifelse(
      .wh$cod_tipo_orario %in% c("P", "V", "M"),
      0L,
      NA_integer_
    )
  )
  expect_identical(dt$prior, attesa)
  expect_true(is.na(dt$prior[1L]))
  expect_true(is.na(dt$prior[2L]))
  expect_identical(dt$prior[3:4], c(0L, 0L))
  expect_identical(.wh$cod_tipo_orario[3:4], c("V", "M"))
  expect_true(all(dt$prior[.wh$cod_tipo_orario %in% "F"] == 1L))
  expect_true(all(dt$prior[.wh$cod_tipo_orario %in% "P"] == 0L))
  # spazi e minuscole vengono ignorati
  x <- data.table::copy(.wh)
  x[1:5, cod_tipo_orario := c(" f", "v ", "m", "p", "n")]
  dt3 <- .leggi(x)
  expect_identical(dt3$prior[1:5], c(1L, 0L, 0L, 0L, NA_integer_))
  # prior presente nella sorgente: nessuna derivazione
  x <- data.table::copy(.wh)
  x[, prior := 1L]
  dt2 <- .leggi(x)
  expect_false(attr(dt2, "ccnlcob_source")$prior_derivato)
  expect_true(all(dt2$prior == 1L))
})

test_that("retribuzione e ore zero-padded diventano numeric; i valori non numerici sono contati", {
  dt <- .leggi(.wh)
  expect_true(is.numeric(dt$retribuzione))
  expect_true(is.numeric(dt$ore))
  expect_true(is.numeric(dt$eta))
  expect_equal(dt$retribuzione, .retribuzione_attesa)
  expect_equal(dt$ore, .ore_attese)
  expect_equal(dt$ore[7L], 38.5)
  expect_true(all(is.na(dt$retribuzione[3:5])))
  expect_true(is.na(dt$ore[6L]))
  info <- attr(dt, "ccnlcob_source")
  # la stringa vuota è trattata come mancante e non conteggiata
  expect_identical(
    info$n_non_numerici,
    c(retribuzione = 2L, ore = 1L, eta = 0L)
  )
  expect_identical(class(dt$rappres), "logical")
  expect_identical(dt$rappres, .wh$rappres)
})

test_that("rappres e i flag vengono convertiti da character e numeric", {
  x <- data.table::copy(.wh)
  x[, rappres := data.table::fifelse(rappres, "true", "false")]
  x[, prior := data.table::fifelse(cod_tipo_orario == "F", "1", "0")]
  x[, troncata := 0]
  dt <- .leggi(x)
  expect_identical(dt$rappres, .wh$rappres)
  expect_identical(class(dt$prior), "integer")
  expect_identical(class(dt$troncata), "integer")
  expect_true(all(dt$troncata == 0L))
})

# 2.5 columns: nomi sorgente e nomi di contratto -----

test_that("columns accetta nomi della sorgente e del contratto, nell'ordine richiesto", {
  dt <- .leggi(
    .wh,
    columns = c(
      "cf",
      "id_rapporto",
      "inizio",
      "fine",
      "codice_cnel",
      "cod_tipologia_contrattuale",
      "prior"
    ),
    validate = TRUE
  )
  expect_identical(
    names(dt),
    c(
      "cf",
      "id",
      "inizio",
      "fine",
      "codice_cnel",
      "cod_tipologia_contrattuale",
      "cod_tipo_orario",
      "prior"
    )
  )
  expect_true(attr(dt, "ccnlcob_source")$prior_derivato)
  # nomi duplicati (sorgente + contratto) vengono letti una sola volta
  dt2 <- .leggi(
    .wh,
    columns = c("id", "id_rapporto", "inizio"),
    validate = FALSE
  )
  expect_identical(names(dt2), c("id", "inizio"))
})

test_that("columns con nomi ignoti produce un errore che li elenca", {
  expect_error(.leggi(.wh, columns = c("id", "pippo", "pluto")), "pippo, pluto")
  expect_error(.leggi(.wh, columns = character(0)), "`columns`")
  expect_error(.leggi(.wh, columns = c("id", NA)), "`columns`")
})

test_that("validate = FALSE restituisce anche una tabella incompleta; TRUE elenca le colonne mancanti", {
  dt <- .leggi(.wh, columns = c("id", "inizio"), validate = FALSE)
  expect_identical(names(dt), c("id", "inizio"))
  expect_identical(attr(dt, "ccnlcob_source")$n, .n_wh)
  expect_error(
    .leggi(.wh, columns = c("id", "inizio")),
    "Colonne mancanti: cf, fine, cod_tipologia_contrattuale, prior"
  )
  expect_error(.leggi(.wh, columns = c("id", "inizio")), "Nessuna colonna CCNL")
  expect_error(.leggi(.wh, validate = NA), "`validate`")
})

# 2.6 DuckDB -----

test_that("DuckDB: lettura da percorso e da connessione coincide con la lettura RDS", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  f_db <- tempfile(fileext = ".duckdb")
  f_rds <- tempfile(fileext = ".rds")
  on.exit(unlink(c(f_db, f_rds)), add = TRUE)
  .scrivi_duckdb(.wh, f_db)
  saveRDS(.wh, f_rds)

  expect_message(
    dt_path <- read_rapporti(f_db, table = "sl2_rapporti_36m_classificati"),
    "lette 400 righe da .*sl2_rapporti_36m_classificati"
  )
  dt_rds <- .leggi(f_rds)
  expect_identical(names(dt_path), names(dt_rds))
  expect_identical(lapply(dt_path, class), lapply(dt_rds, class))
  data.table::setorder(dt_path, id)
  data.table::setorder(dt_rds, id)
  expect_equal(.senza_source(dt_path), .senza_source(dt_rds))
  info <- attr(dt_path, "ccnlcob_source")
  expect_identical(info$source, f_db)
  expect_identical(info$table, "sl2_rapporti_36m_classificati")
  expect_identical(
    info$colonne_mappate,
    attr(dt_rds, "ccnlcob_source")$colonne_mappate
  )
  expect_identical(
    info$n_non_numerici,
    attr(dt_rds, "ccnlcob_source")$n_non_numerici
  )
  expect_true(info$prior_derivato)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = f_db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  dt_con <- .leggi(con, table = "sl2_rapporti_36m_classificati")
  data.table::setorder(dt_con, id)
  expect_equal(.senza_source(dt_con), .senza_source(dt_rds))
  expect_identical(attr(dt_con, "ccnlcob_source")$source, "DBI")
  # la connessione resta aperta dopo la lettura
  expect_true(DBI::dbIsValid(con))
})

test_that("DuckDB: columns e where vengono spinti nella SELECT", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  f_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(f_db), add = TRUE)
  .scrivi_duckdb(.wh, f_db)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = f_db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  where <- "inizio >= DATE '2022-01-01' AND cod_tipo_orario = 'F'"
  n_attese <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT count(*) AS n FROM sl2_rapporti_36m_classificati WHERE",
      where
    )
  )$n
  expect_true(n_attese > 0 && n_attese < .n_wh)

  dt <- .leggi(
    con,
    table = "sl2_rapporti_36m_classificati",
    columns = c(
      "id_rapporto",
      "cf",
      "inizio",
      "fine",
      "codice_cnel",
      "cod_tipologia_contrattuale",
      "prior"
    ),
    where = where
  )
  expect_identical(nrow(dt), as.integer(n_attese))
  expect_identical(
    names(dt),
    c(
      "id",
      "cf",
      "inizio",
      "fine",
      "codice_cnel",
      "cod_tipologia_contrattuale",
      "cod_tipo_orario",
      "prior"
    )
  )
  expect_true(all(dt$inizio >= as.Date("2022-01-01")))
  expect_true(all(dt$prior == 1L))
  expect_identical(attr(dt, "ccnlcob_source")$where, where)

  # stessa selezione via percorso
  dt_path <- .leggi(
    f_db,
    table = "sl2_rapporti_36m_classificati",
    columns = c("id", "inizio"),
    where = where,
    validate = FALSE
  )
  expect_identical(nrow(dt_path), as.integer(n_attese))
  expect_identical(names(dt_path), c("id", "inizio"))
  # nomi qualificati con lo schema
  dt_schema <- .leggi(
    con,
    table = "main.sl2_rapporti_36m_classificati",
    columns = c("id", "inizio"),
    validate = FALSE
  )
  expect_identical(nrow(dt_schema), .n_wh)
})

test_that("DuckDB: errori per table assente, tabella inesistente e colonne ignote", {
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  f_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(f_db), add = TRUE)
  .scrivi_duckdb(.wh, f_db)
  expect_error(.leggi(f_db), "`table`")
  expect_error(.leggi(f_db), "sl2_rapporti_36m_classificati")
  expect_error(.leggi(f_db, table = "non_esiste"))
  expect_error(
    .leggi(f_db, table = "sl2_rapporti_36m_classificati", columns = "pippo"),
    "pippo"
  )
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = f_db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  expect_error(.leggi(con), "`table`")
  expect_error(.leggi(con, table = c("a", "b")), "`table`")
})

# 2.7 Errori sulle sorgenti -----

test_that("read_rapporti() rifiuta sorgenti non valide", {
  expect_error(.leggi(tempfile(fileext = ".rds")), "File non trovato")
  expect_error(.leggi(tempfile(fileext = ".fst")), "File non trovato")
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  writeLines("a,b", f)
  expect_error(.leggi(f), "Estensione non riconosciuta")
  expect_error(.leggi(f), "csv")
  expect_error(.leggi(1:3), "`source`")
  expect_error(.leggi(c("a.rds", "b.rds")), "`source`")
  expect_error(.leggi(NULL), "`source`")
})

test_that("where non è ammesso per file e data.frame", {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f), add = TRUE)
  saveRDS(cob, f)
  expect_error(.leggi(f, where = "inizio > DATE '2020-01-01'"), "`where`")
  expect_error(.leggi(cob, where = "1 = 1"), "`where`")
  expect_error(.leggi(cob, where = c("a", "b")), "`where`")
  expect_error(.leggi(cob, where = NA_character_), "`where`")
})

test_that("una sorgente senza colonne del contratto produce un errore", {
  expect_error(
    .leggi(data.frame(a = 1:3, b = letters[1:3])),
    "Nessuna colonna del contratto dati"
  )
})

# 2.8 Catena con prepare_rapporti() e rank_ccnl() -----

test_that("la tabella letta dalla fixture warehouse attraversa prepare_rapporti() e rank_ccnl()", {
  dt <- .leggi(.wh)
  prep <- suppressMessages(prepare_rapporti(dt))
  expect_true(all(c("ccnl_key", "giornate", "orario") %in% names(prep)))
  expect_identical(attr(prep, "ccnlcob_meta")$ccnl_key, "codice_cnel")
  expect_identical(attr(prep, "ccnlcob_meta")$n_input, .n_wh)
  # ccnl viene rinominata ccnl_warehouse da prepare_rapporti(), non prima
  expect_true("ccnl" %in% names(dt))
  expect_true("ccnl_warehouse" %in% names(prep))
  ranking <- rank_ccnl(prep)
  expect_true(data.table::is.data.table(ranking))
  expect_true(nrow(ranking) > 0L)
  expect_true(all(c("n_lavoratori", "giornate") %in% names(ranking)))
  # stessa catena da DuckDB
  skip_if_not_installed("duckdb")
  skip_if_not_installed("DBI")
  f_db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(f_db), add = TRUE)
  .scrivi_duckdb(.wh, f_db)
  dt_db <- .leggi(f_db, table = "sl2_rapporti_36m_classificati")
  prep_db <- suppressMessages(prepare_rapporti(dt_db))
  ranking_db <- rank_ccnl(prep_db)
  data.table::setorder(ranking, ccnl_key)
  data.table::setorder(ranking_db, ccnl_key)
  expect_equal(ranking_db, ranking)
})

# 3. write_results() -----

test_that("write_results() crea la directory e scrive i file del contratto di uscita", {
  d <- file.path(.dir_temporanea(), "sotto", "ccnl")
  expect_false(dir.exists(d))
  manifesto <- write_results(res, dir = d)
  expect_true(dir.exists(d))
  expect_identical(sort(list.files(d)), sort(.file_attesi))
  expect_true(data.table::is.data.table(manifesto))
  expect_named(manifesto, c("oggetto", "file", "formato", "righe", "byte"))
  expect_identical(manifesto$oggetto, sub("[.].*$", "", .file_attesi))
  expect_identical(basename(manifesto$file), .file_attesi)
  expect_identical(manifesto$formato, sub("^.*[.]", "", .file_attesi))
  expect_true(all(file.exists(manifesto$file)))
  expect_true(all(manifesto$byte > 0))
  expect_identical(manifesto[oggetto == "ranking", righe], nrow(res$ranking))
  expect_true(is.na(manifesto[oggetto == "meta", righe]))
  expect_true(is.na(manifesto[oggetto == "keys", righe]))
})

test_that("write_results() restituisce il manifesto invisibilmente", {
  d <- .dir_temporanea()
  expect_invisible(write_results(res, dir = d))
})

test_that("i file RDS riletti coincidono con le tabelle in memoria", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  for (nm in c(
    "ranking",
    "ranking_periodo",
    "rilevanti",
    "retribuzioni",
    "qualita"
  )) {
    riletto <- readRDS(file.path(d, paste0(nm, ".rds")))
    expect_equal(riletto, res[[nm]], info = nm)
  }
  expect_identical(readRDS(file.path(d, "keys.rds")), res$keys)
})

test_that("i file FST riletti coincidono con i cubi a meno degli attributi", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  for (nm in c("cpi", "tipologie")) {
    riletto <- fst::read_fst(
      file.path(d, paste0(nm, ".fst")),
      as.data.table = TRUE
    )
    expect_equal(riletto, .senza_attributi(res[[nm]]), info = nm)
  }
})

test_that("meta.rds conserva i metadati, gli attributi delle tabelle e il manifesto", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  meta <- readRDS(file.path(d, "meta.rds"))
  for (nm in names(res$meta)) {
    expect_identical(meta[[nm]], res$meta[[nm]], info = nm)
  }
  expect_identical(
    names(meta$attributi),
    c(
      "ranking",
      "ranking_periodo",
      "rilevanti",
      "cpi",
      "tipologie",
      "retribuzioni",
      "qualita"
    )
  )
  expect_identical(
    meta$attributi$cpi$ccnlcob_crosstab,
    attr(res$cpi, "ccnlcob_crosstab")
  )
  expect_identical(
    meta$attributi$ranking$ccnlcob_ranking,
    attr(res$ranking, "ccnlcob_ranking")
  )
  expect_identical(meta$oggetti_assenti, character(0))
  expect_identical(meta$file$file, .file_attesi)
  # gli attributi permettono di ricostruire il cubo
  cubo <- fst::read_fst(file.path(d, "cpi.fst"), as.data.table = TRUE)
  for (a in names(meta$attributi$cpi)) {
    data.table::setattr(cubo, a, meta$attributi$cpi[[a]])
  }
  expect_equal(cubo, res$cpi)
})

test_that("write_results() salta gli elementi NULL e li elenca in meta", {
  parziale <- analyze_ccnl(
    cob[, !c("retribuzione", "comune_sede_lavoro")],
    min_n = 10
  )
  d <- .dir_temporanea()
  manifesto <- write_results(parziale, dir = d)
  expect_false(any(c("cpi.fst", "retribuzioni.rds") %in% list.files(d)))
  expect_identical(
    sort(list.files(d)),
    sort(setdiff(.file_attesi, c("cpi.fst", "retribuzioni.rds")))
  )
  expect_false(any(c("cpi", "retribuzioni") %in% manifesto$oggetto))
  meta <- readRDS(file.path(d, "meta.rds"))
  expect_identical(meta$oggetti_assenti, c("cpi", "retribuzioni"))
  expect_false("cpi" %in% names(meta$attributi))
})

test_that("overwrite = FALSE ferma la scrittura su file esistenti, TRUE la consente", {
  d <- .dir_temporanea()
  write_results(res, dir = d)
  prima <- file.mtime(file.path(d, "ranking.rds"))
  expect_error(write_results(res, dir = d), "overwrite = TRUE")
  expect_error(write_results(res, dir = d), "ranking.rds")
  Sys.sleep(1.1)
  manifesto <- write_results(res, dir = d, overwrite = TRUE)
  expect_true(file.mtime(file.path(d, "ranking.rds")) > prima)
  expect_identical(nrow(manifesto), length(.file_attesi))
})

test_that("write_results() rispetta formats personalizzati; meta e keys restano RDS", {
  d <- .dir_temporanea()
  manifesto <- write_results(
    res,
    dir = d,
    formats = c(cube = "rds", small = "fst")
  )
  attesi <- c(
    "meta.rds",
    "ranking.fst",
    "ranking_periodo.fst",
    "rilevanti.fst",
    "keys.rds",
    "cpi.rds",
    "tipologie.rds",
    "retribuzioni.fst",
    "qualita.fst"
  )
  expect_identical(sort(list.files(d)), sort(attesi))
  expect_identical(basename(manifesto$file), attesi)
  expect_equal(readRDS(file.path(d, "cpi.rds")), res$cpi)
  riletto <- fst::read_fst(file.path(d, "ranking.fst"), as.data.table = TRUE)
  expect_equal(riletto, .senza_attributi(res$ranking))
})

test_that("write_results() rifiuta input non validi", {
  d <- .dir_temporanea()
  expect_error(write_results(list(meta = list()), dir = d), "ccnlcob_result")
  expect_error(write_results(res, dir = c(d, d)), "percorso")
  expect_error(
    write_results(res, dir = d, formats = c(small = "csv", cube = "fst")),
    "csv"
  )
  expect_error(write_results(res, dir = d, formats = c("rds", "fst")), "small")
  expect_error(write_results(res, dir = d, overwrite = NA), "overwrite")
  expect_identical(list.files(d), character(0))
})
