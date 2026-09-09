# 1. Lettura dei rapporti -----

# Colonne del contratto dati (§4 del piano) lette per default quando presenti
# nella sorgente, direttamente o tramite un nome sorgente equivalente.
.colonne_contratto <- c(
  "id",
  "cf",
  "inizio",
  "fine",
  "codice_cnel",
  "ccnl",
  "ccnl_warehouse",
  "rappres",
  "cod_tipologia_contrattuale",
  "cod_tipo_orario",
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
  "sesso",
  "liv_istruzione_lav"
)

# Nomi della slice DuckDB di cnelR (warehouse CO) e nome di contratto.
.nomi_warehouse <- c(
  id_rapporto = "id",
  codice_fiscale_lavoratore = "cf",
  codice_fiscale_datore = "datore",
  ore_settim_medie = "ore",
  cod_qualifica_prof_istat_3dgt = "qualifica",
  sesso_lav = "sesso",
  eta_lav_inizio = "eta"
)

# Mappa completa nome sorgente -> nome di contratto usata da read_rapporti():
# varianti maiuscole della pipeline (senza `ccnl`, che resta di competenza di
# prepare_rapporti()) e nomi warehouse.
.nomi_sorgente <- function() {
  c(.nomi_pipeline[names(.nomi_pipeline) != "ccnl"], .nomi_warehouse)
}

# Estensioni di file riconosciute da read_rapporti().
.estensioni_ammesse <- c("fst", "rds", "duckdb")

# Codici MLPS "ST-TIPO ORARIO" (workbook "Classificazioni Standard") usati
# per derivare `prior`: F tempo pieno; P orizzontale, V verticale, M misto
# sono part-time; N (non definito) resta NA.
.codici_tempo_pieno <- "F"
.codici_part_time <- c("P", "V", "M")

# Espressione regolare che identifica un numero (virgola ammessa come
# separatore decimale).
.regex_numero <- "^-?[0-9]+([.,][0-9]+)?$"

#' Legge i rapporti di lavoro da file, da DuckDB o da connessione DBI
#'
#' Carica un dataset di rapporti di lavoro da un file `.fst`, `.rds` o
#' `.duckdb`, da una connessione `DBI` aperta oppure da un `data.frame` già
#' in memoria; porta i nomi delle colonne al contratto dati, normalizza i
#' tipi e restituisce un `data.table` pronto per [validate_rapporti()] e
#' [prepare_rapporti()].
#'
#' @param source Una fra: il percorso di un file `.fst`, `.rds` o `.duckdb`
#'   (aperto in sola lettura con `duckdb::duckdb()`); una connessione
#'   `DBI::DBIConnection` (DuckDB o PostgreSQL); un `data.frame` o
#'   `data.table` (convertito con [data.table::as.data.table()], l'input non
#'   viene modificato).
#' @param table Nome della tabella o vista da leggere quando `source` è un
#'   file `.duckdb` o una connessione DBI; obbligatorio in quei casi, ignorato
#'   altrimenti. Per la slice prodotta da `cnelR` il nome è
#'   `"sl2_rapporti_36m_classificati"`. Sono ammessi nomi qualificati con lo
#'   schema (`"schema.tabella"`).
#' @param columns Vettore character con le colonne da leggere, con i nomi
#'   della sorgente oppure quelli del contratto dati (per esempio `"id"` e
#'   `"id_rapporto"` sono equivalenti). `NULL` (default) legge tutte le
#'   colonne del contratto dati presenti nella sorgente; vedi Dettagli.
#' @param where Predicato SQL (character di lunghezza 1, senza la parola
#'   chiave `WHERE`) applicato alla lettura da DuckDB o DBI, per esempio
#'   `"inizio >= DATE '2023-02-01'"`. Deve essere `NULL` per i file e per i
#'   `data.frame`.
#' @param validate Se `TRUE` (default) il risultato viene verificato con
#'   [validate_rapporti()] (blocco `"base"`) e la funzione si ferma con un
#'   errore che elenca le colonne mancanti. Con `FALSE` la tabella viene
#'   restituita anche se incompleta, per esempio per leggere un sottoinsieme
#'   di colonne.
#'
#' @details
#' ## Colonne lette
#' Le colonne del contratto dati sono `id`, `cf`, `inizio`, `fine`,
#' `codice_cnel`, `ccnl`, `ccnl_warehouse`, `rappres`,
#' `cod_tipologia_contrattuale`, `cod_tipo_orario`, `prior`,
#' `comune_sede_lavoro`, `comune_lavoratore`, `datore`, `retribuzione`,
#' `ore`, `troncata`, `qualifica`, `ateco_gruppo`, `eta`, `sesso` e
#' `liv_istruzione_lav`. Con `columns = NULL` vengono lette quelle presenti
#' nella sorgente; le altre colonne (per esempio `ini_*` della slice
#' `cnelR`) vengono ignorate. Per le sorgenti DuckDB e DBI la selezione
#' delle colonne e il predicato `where` sono inseriti nella `SELECT`, così
#' che in R arrivino solo i dati richiesti; per i file `.fst` la selezione
#' avviene in lettura, per `.rds` e `data.frame` dopo il caricamento.
#'
#' ## Rinomina
#' I nomi della sorgente vengono portati al contratto dati solo quando la
#' colonna di destinazione è assente. Nomi della slice `cnelR` (warehouse
#' CO): `id_rapporto` in `id`, `codice_fiscale_lavoratore` in `cf`,
#' `codice_fiscale_datore` in `datore`, `ore_settim_medie` in `ore`,
#' `cod_qualifica_prof_istat_3dgt` in `qualifica`, `sesso_lav` in `sesso`,
#' `eta_lav_inizio` in `eta`. Varianti maiuscole della pipeline COB:
#' `INIZIO`, `FINE`, `COD_TIPOLOGIA_CONTRATTUALE`, `COMUNE_SEDE_LAVORO`,
#' `COMUNE_LAVORATORE`, `RETRIBUZIONE`, `ORE_SETTIM_MEDIE`, `ETA_LAV_INIZIO`,
#' `SESSO_LAV`. La colonna `ccnl` (codice warehouse) non viene rinominata:
#' la rinomina in `ccnl_warehouse` resta di competenza di
#' [prepare_rapporti()].
#'
#' Se `prior` è assente e `cod_tipo_orario` è presente, `prior` viene
#' derivata dai codici MLPS della tabella "ST-TIPO ORARIO": `"F"` (tempo
#' pieno) vale `1`; `"P"` (part-time orizzontale), `"V"` (part-time
#' verticale) e `"M"` (part-time misto) valgono `0`; `"N"` (non definito),
#' i valori mancanti e ogni altro codice danno `NA`. Il confronto ignora
#' spazi e maiuscole; `cod_tipo_orario` viene conservata e il metadato
#' `prior_derivato` registra l'avvenuta derivazione.
#'
#' ## Tipi
#' I `factor` diventano character; gli interi a 64 bit (`integer64`, per
#' esempio `id` nel file `rap.fst` della pipeline) diventano character per
#' `id` e integer per le altre colonne (richiede il pacchetto `bit64`).
#' `retribuzione`, `ore` ed `eta`, se character o factor, vengono convertite
#' in numeric accettando solo valori che rappresentano un numero (virgola
#' ammessa come separatore decimale, zero-padding ammesso): gli altri valori
#' non mancanti e non vuoti diventano `NA` e sono conteggiati in
#' `n_non_numerici`. `inizio` e `fine` diventano `Date` da character o
#' `POSIXct` (`IDate` viene conservata); `prior` e `troncata` diventano
#' integer 0/1; `rappres` diventa logical. Le sentinelle sulle date non
#' vengono toccate.
#'
#' ## Metadati
#' L'attributo `ccnlcob_source` del risultato è una lista con `source`
#' (percorso, `"DBI"` o `"data.frame"`), `table`, `n` (righe lette),
#' `colonne_mappate` (character nominato: nome sorgente = nome di
#' contratto, per le sole colonne rinominate), `prior_derivato` (logical),
#' `n_non_numerici` (integer nominato per `retribuzione`, `ore`, `eta`) e
#' `where`. La funzione emette un `message()` con il numero di righe lette.
#'
#' @return Un `data.table` con una riga per rapporto di lavoro e le colonne
#'   richieste con i nomi del contratto dati; attributo `ccnlcob_source`
#'   come descritto nei Dettagli.
#' @family ingresso
#' @export
#' @examples
#' # da data.frame in memoria (nomi del contratto dati)
#' dt <- read_rapporti(cob_esempio)
#' attr(dt, "ccnlcob_source")$n
#'
#' # da file RDS o FST
#' f <- tempfile(fileext = ".rds")
#' saveRDS(cob_esempio, f)
#' dt <- read_rapporti(f, columns = c("id", "cf", "inizio", "fine"),
#'                     validate = FALSE)
#' unlink(f)
#'
#' \dontrun{
#' # slice classificata da cnelR, con selezione spinta in SQL
#' dt <- read_rapporti(
#'   "~/data/cnel/rapporti_azure.duckdb",
#'   table = "sl2_rapporti_36m_classificati",
#'   where = "inizio >= DATE '2023-02-01'"
#' )
#'
#' # connessione DBI già aperta
#' con <- DBI::dbConnect(duckdb::duckdb(), "cob.duckdb", read_only = TRUE)
#' dt <- read_rapporti(con, table = "sl2_rapporti_36m_classificati")
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
read_rapporti <- function(
  source,
  table = NULL,
  columns = NULL,
  where = NULL,
  validate = TRUE
) {
  # 1.1 Controlli sugli argomenti -----
  if (!is.null(columns)) {
    if (!is.character(columns) || length(columns) == 0L || anyNA(columns)) {
      stop(
        "`columns` deve essere NULL o un vettore character non vuoto.",
        call. = FALSE
      )
    }
    columns <- unique(columns)
  }
  if (
    !is.null(where) &&
      (!is.character(where) || length(where) != 1L || is.na(where))
  ) {
    stop(
      "`where` deve essere NULL o un predicato SQL di lunghezza 1.",
      call. = FALSE
    )
  }
  if (!is.logical(validate) || length(validate) != 1L || is.na(validate)) {
    stop("`validate` deve essere TRUE o FALSE.", call. = FALSE)
  }
  tipo <- .tipo_sorgente(source)
  if (tipo %in% c("duckdb", "dbi")) {
    if (!is.character(table) || length(table) != 1L || is.na(table)) {
      stop(
        "`table` \u00e8 obbligatorio per le sorgenti DuckDB e DBI ",
        "(per la slice di cnelR: \"sl2_rapporti_36m_classificati\").",
        call. = FALSE
      )
    }
  } else if (!is.null(where)) {
    stop(
      "`where` \u00e8 ammesso solo per le sorgenti DuckDB e DBI; per i ",
      "file e i data.frame filtrare dopo la lettura.",
      call. = FALSE
    )
  }

  # 1.2 Lettura grezza -----
  dt <- switch(
    tipo,
    fst = .read_rapporti_fst(source, columns),
    rds = .read_rapporti_rds(source, columns),
    duckdb = .read_rapporti_duckdb(source, table, columns, where),
    dbi = .read_rapporti_dbi(source, table, columns, where),
    df = .read_rapporti_df(source, columns)
  )

  # 1.3 Nomi del contratto e prior -----
  mappate <- .normalize_names(dt, mapping = .nomi_sorgente())
  prior_derivato <- .derive_prior(dt)

  # 1.4 Tipi -----
  n_non_numerici <- .normalize_types(dt)

  # 1.5 Validazione, metadati, messaggio -----
  if (validate) {
    .assert_rapporti(dt, require = "base", caller = "read_rapporti")
  }
  descr <- switch(
    tipo,
    dbi = "DBI",
    df = "data.frame",
    source
  )
  data.table::setattr(
    dt,
    "ccnlcob_source",
    list(
      source = descr,
      table = if (tipo %in% c("duckdb", "dbi")) table else NULL,
      n = nrow(dt),
      colonne_mappate = mappate,
      prior_derivato = prior_derivato,
      n_non_numerici = n_non_numerici,
      where = where
    )
  )
  message(
    "read_rapporti(): lette ",
    format(nrow(dt), big.mark = ".", decimal.mark = ",", scientific = FALSE),
    " righe da ",
    if (tipo %in% c("duckdb", "dbi")) {
      paste0(descr, " (", table, ")")
    } else {
      descr
    },
    "."
  )
  dt[]
}

# 1.6 Sorgenti -----

#' Estensione di un percorso, in minuscolo
#'
#' @param path Percorso di lunghezza 1.
#' @return Estensione senza punto (`""` se assente).
#' @keywords internal
#' @noRd
.file_ext <- function(path) {
  base <- basename(path)
  pos <- regexpr("\\.([[:alnum:]]+)$", base)
  if (pos < 0L) {
    return("")
  }
  tolower(substring(base, pos + 1L))
}

#' Classifica la sorgente di read_rapporti()
#'
#' @param source Valore dell'argomento `source`.
#' @return Una fra `"fst"`, `"rds"`, `"duckdb"`, `"dbi"`, `"df"`; errore per
#'   sorgenti non riconosciute o file assenti.
#' @keywords internal
#' @noRd
.tipo_sorgente <- function(source) {
  if (inherits(source, "DBIConnection")) {
    return("dbi")
  }
  if (is.data.frame(source)) {
    return("df")
  }
  if (!is.character(source) || length(source) != 1L || is.na(source)) {
    stop(
      "`source` deve essere un percorso (.fst, .rds, .duckdb), una ",
      "connessione DBI o un data.frame.",
      call. = FALSE
    )
  }
  ext <- .file_ext(source)
  if (!ext %in% .estensioni_ammesse) {
    stop(
      "Estensione non riconosciuta in `source`: \"",
      ext,
      "\". Ammesse: ",
      paste0(".", .estensioni_ammesse, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (!file.exists(source)) {
    stop("File non trovato: ", source, call. = FALSE)
  }
  ext
}

#' Risolve le colonne richieste sui nomi della sorgente
#'
#' Accetta nomi della sorgente e nomi del contratto; con `columns = NULL`
#' seleziona le colonne del contratto presenti (direttamente o tramite
#' alias). `prior` assente viene soddisfatta da `cod_tipo_orario`.
#'
#' @param nomi Nomi delle colonne disponibili nella sorgente.
#' @param columns Richiesta dell'utente o `NULL`.
#' @param descr Descrizione della sorgente per i messaggi.
#' @return Vettore character di nomi della sorgente da leggere, nell'ordine
#'   richiesto.
#' @keywords internal
#' @noRd
.resolve_columns <- function(nomi, columns = NULL, descr = "source") {
  alias <- .nomi_sorgente()
  # per ogni nome di contratto, il nome sorgente equivalente presente
  .sorgente_di <- function(col) {
    if (col %in% nomi) {
      return(col)
    }
    cand <- names(alias)[alias == col & names(alias) %in% nomi]
    if (length(cand) > 0L) {
      return(cand[1L])
    }
    if (col == "prior" && "cod_tipo_orario" %in% nomi) {
      return("cod_tipo_orario")
    }
    NA_character_
  }
  if (is.null(columns)) {
    out <- vapply(.colonne_contratto, .sorgente_di, character(1))
    out <- unique(out[!is.na(out)])
    if (length(out) == 0L) {
      stop(
        "Nessuna colonna del contratto dati trovata in ",
        descr,
        ". Colonne disponibili: ",
        paste(nomi, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    return(unname(out))
  }
  out <- vapply(columns, .sorgente_di, character(1))
  ignote <- columns[is.na(out)]
  if (length(ignote) > 0L) {
    stop(
      "Colonne non presenti in ",
      descr,
      ": ",
      paste(ignote, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  unique(unname(out))
}

#' Riduce un data.table alle colonne richieste, per riferimento
#'
#' @param dt Un `data.table`.
#' @param cols Colonne da conservare, nell'ordine desiderato.
#' @return `dt`, invisibilmente.
#' @keywords internal
#' @noRd
.keep_columns <- function(dt, cols) {
  extra <- setdiff(names(dt), cols)
  if (length(extra) > 0L) {
    data.table::set(dt, j = extra, value = NULL)
  }
  data.table::setcolorder(dt, cols)
  invisible(dt)
}

.read_rapporti_fst <- function(path, columns) {
  nomi <- fst::metadata_fst(path)$columnNames
  cols <- .resolve_columns(nomi, columns, descr = path)
  fst::read_fst(path, columns = cols, as.data.table = TRUE)
}

.read_rapporti_rds <- function(path, columns) {
  obj <- readRDS(path)
  if (!is.data.frame(obj)) {
    stop(
      "Il file ",
      path,
      " non contiene un data.frame (classe: ",
      paste(class(obj), collapse = "/"),
      ").",
      call. = FALSE
    )
  }
  cols <- .resolve_columns(names(obj), columns, descr = path)
  data.table::setDT(obj)
  .keep_columns(obj, cols)
  obj
}

.read_rapporti_df <- function(df, columns) {
  cols <- .resolve_columns(names(df), columns, descr = "data.frame")
  if (data.table::is.data.table(df)) {
    return(df[, cols, with = FALSE])
  }
  data.table::as.data.table(df[cols])
}

.read_rapporti_duckdb <- function(path, table, columns, where) {
  for (pkg in c("DBI", "duckdb")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Il pacchetto `",
        pkg,
        "` \u00e8 necessario per leggere un file .duckdb: ",
        "install.packages(\"",
        pkg,
        "\").",
        call. = FALSE
      )
    }
  }
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  .read_rapporti_dbi(con, table, columns, where, descr = path)
}

.read_rapporti_dbi <- function(con, table, columns, where, descr = "DBI") {
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop(
      "Il pacchetto `DBI` \u00e8 necessario per leggere da una connessione.",
      call. = FALSE
    )
  }
  tbl_sql <- .sql_table(con, table)
  nomi <- names(DBI::dbGetQuery(
    con,
    paste0("SELECT * FROM ", tbl_sql, " WHERE 1 = 0")
  ))
  cols <- .resolve_columns(
    nomi,
    columns,
    descr = paste0(descr, " (", table, ")")
  )
  cols_sql <- paste(
    vapply(
      cols,
      function(x) as.character(DBI::dbQuoteIdentifier(con, x)),
      character(1)
    ),
    collapse = ", "
  )
  sql <- paste0("SELECT ", cols_sql, " FROM ", tbl_sql)
  if (!is.null(where)) {
    sql <- paste0(sql, " WHERE ", where)
  }
  out <- DBI::dbGetQuery(con, sql)
  data.table::setDT(out)
  out
}

#' Nome di tabella quotato, con eventuale schema
#'
#' @param con Connessione DBI.
#' @param table Nome semplice o `schema.tabella`.
#' @return Stringa SQL con gli identificatori quotati.
#' @keywords internal
#' @noRd
.sql_table <- function(con, table) {
  parti <- strsplit(table, ".", fixed = TRUE)[[1L]]
  paste(
    vapply(
      parti,
      function(x) as.character(DBI::dbQuoteIdentifier(con, x)),
      character(1)
    ),
    collapse = "."
  )
}

# 1.7 Normalizzazione -----

#' Deriva `prior` da `cod_tipo_orario`, se necessario
#'
#' Codici MLPS "ST-TIPO ORARIO": `F` tempo pieno (`prior = 1`); `P`
#' orizzontale, `V` verticale e `M` misto sono part-time (`prior = 0`);
#' `N` non definito e ogni altro valore danno `NA`.
#'
#' @param dt Un `data.table`, modificato per riferimento.
#' @return `TRUE` se `prior` è stata derivata, altrimenti `FALSE`.
#' @keywords internal
#' @noRd
.derive_prior <- function(dt) {
  if ("prior" %in% names(dt) || !"cod_tipo_orario" %in% names(dt)) {
    return(FALSE)
  }
  orario <- toupper(trimws(as.character(dt[["cod_tipo_orario"]])))
  prior <- data.table::fifelse(
    orario %in% .codici_tempo_pieno,
    1L,
    data.table::fifelse(orario %in% .codici_part_time, 0L, NA_integer_)
  )
  data.table::set(dt, j = "prior", value = prior)
  # prior subito dopo cod_tipo_orario, come nel contratto dati
  nomi <- setdiff(names(dt), "prior")
  pos <- match("cod_tipo_orario", nomi)
  data.table::setcolorder(dt, append(nomi, "prior", after = pos))
  TRUE
}

#' Converte un vettore in numeric con controllo sul formato
#'
#' Accetta numeri interi o decimali con punto o virgola, anche zero-padded;
#' i factor sono convertiti sui livelli. I valori non mancanti, non vuoti e
#' non numerici diventano `NA` e vengono contati.
#'
#' @param x Vettore numeric, logical, factor o character.
#' @return Lista con `value` (numeric) e `n_non_numerici` (integer).
#' @keywords internal
#' @noRd
.parse_numeric <- function(x) {
  if (is.numeric(x)) {
    return(list(value = x, n_non_numerici = 0L))
  }
  if (is.logical(x)) {
    return(list(value = as.numeric(x), n_non_numerici = 0L))
  }
  .converti <- function(v) {
    v <- trimws(as.character(v))
    v[!is.na(v) & v == ""] <- NA_character_
    ok <- !is.na(v) & grepl(.regex_numero, v)
    out <- rep(NA_real_, length(v))
    out[ok] <- as.numeric(sub(",", ".", v[ok], fixed = TRUE))
    list(value = out, invalido = !is.na(v) & !ok)
  }
  if (is.factor(x)) {
    liv <- .converti(levels(x))
    idx <- as.integer(x)
    return(list(
      value = liv$value[idx],
      n_non_numerici = as.integer(sum(liv$invalido[idx], na.rm = TRUE))
    ))
  }
  conv <- .converti(x)
  list(
    value = conv$value,
    n_non_numerici = as.integer(sum(conv$invalido))
  )
}

#' Converte una colonna integer64 tramite bit64
#'
#' @param x Vettore di classe `integer64`.
#' @param to `"character"` oppure `"integer"`.
#' @param nome Nome della colonna per i messaggi.
#' @return Vettore convertito.
#' @keywords internal
#' @noRd
.from_integer64 <- function(x, to = c("character", "integer"), nome = "x") {
  to <- match.arg(to)
  if (!requireNamespace("bit64", quietly = TRUE)) {
    stop(
      "La colonna `",
      nome,
      "` \u00e8 integer64: il pacchetto `bit64` \u00e8 necessario per ",
      "convertirla.",
      call. = FALSE
    )
  }
  if (to == "character") as.character(x) else as.integer(x)
}

#' Converte un vettore in Date, se necessario
#'
#' @param x Vettore `Date`/`IDate` (restituito invariato), `POSIXt` o
#'   character.
#' @param nome Nome della colonna per i messaggi.
#' @return Vettore di classe `Date` (o `IDate` se già tale).
#' @keywords internal
#' @noRd
.as_date_col <- function(x, nome = "x") {
  if (inherits(x, "Date")) {
    return(x)
  }
  if (inherits(x, "POSIXt")) {
    return(as.Date(x))
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.character(x)) {
    x[!is.na(x) & trimws(x) == ""] <- NA_character_
    return(as.Date(x))
  }
  stop(
    "La colonna `",
    nome,
    "` deve essere Date, IDate, POSIXct o character (classe: ",
    paste(class(x), collapse = "/"),
    ").",
    call. = FALSE
  )
}

#' Converte un vettore in logical
#'
#' @param x Vettore logical, numeric, factor o character.
#' @return Vettore logical.
#' @keywords internal
#' @noRd
.as_logical_col <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  if (is.numeric(x)) {
    return(x != 0)
  }
  v <- tolower(trimws(as.character(x)))
  data.table::fifelse(
    v %in% c("true", "t", "1", "yes", "y", "si", "s\u00ec"),
    TRUE,
    data.table::fifelse(
      v %in% c("false", "f", "0", "no", "n"),
      FALSE,
      NA
    )
  )
}

#' Normalizza i tipi delle colonne per riferimento
#'
#' Applica le regole documentate in [read_rapporti()]: factor in character,
#' integer64 in character (`id`) o integer, colonne numeriche con controllo
#' del formato, date, flag integer e logical.
#'
#' @param dt Un `data.table`, modificato per riferimento.
#' @return Vettore integer nominato con i valori non numerici per
#'   `retribuzione`, `ore` ed `eta`.
#' @keywords internal
#' @noRd
.normalize_types <- function(dt) {
  nomi <- names(dt)

  # integer64
  for (col in nomi) {
    if (inherits(dt[[col]], "integer64")) {
      to <- if (col == "id") "character" else "integer"
      data.table::set(
        dt,
        j = col,
        value = .from_integer64(dt[[col]], to = to, nome = col)
      )
    }
  }

  # numeriche con controllo del formato
  num_cols <- c("retribuzione", "ore", "eta")
  n_non_numerici <- stats::setNames(integer(length(num_cols)), num_cols)
  for (col in intersect(num_cols, nomi)) {
    conv <- .parse_numeric(dt[[col]])
    if (!is.numeric(dt[[col]])) {
      data.table::set(dt, j = col, value = conv$value)
    }
    n_non_numerici[[col]] <- conv$n_non_numerici
  }

  # date
  for (col in intersect(c("inizio", "fine"), nomi)) {
    data.table::set(dt, j = col, value = .as_date_col(dt[[col]], nome = col))
  }

  # flag interi e logici
  for (col in intersect(c("prior", "troncata"), nomi)) {
    x <- dt[[col]]
    if (is.factor(x) || is.character(x)) {
      x <- .parse_numeric(x)$value
    }
    if (!is.integer(x)) {
      data.table::set(dt, j = col, value = as.integer(x))
    }
  }
  if ("rappres" %in% nomi) {
    data.table::set(dt, j = "rappres", value = .as_logical_col(dt[["rappres"]]))
  }

  # factor residui in character
  for (col in names(dt)) {
    if (is.factor(dt[[col]])) {
      data.table::set(dt, j = col, value = as.character(dt[[col]]))
    }
  }

  n_non_numerici
}

# 2. Scrittura dei risultati -----

# Oggetti del contratto di uscita (§5.3), nell'ordine di scrittura, con la
# famiglia di formato: "small" per le tabelle piccole, "cube" per i cubi,
# "rds" per gli oggetti non tabellari (sempre RDS).
.oggetti_risultato <- c(
  meta = "rds",
  ranking = "small",
  ranking_periodo = "small",
  rilevanti = "small",
  keys = "rds",
  cpi = "cube",
  tipologie = "cube",
  retribuzioni = "small",
  qualita = "small"
)

.formati_ammessi <- c("rds", "fst")

#' Serializza i risultati di analyze_ccnl()
#'
#' Scrive su disco le tabelle contenute in un oggetto `ccnlcob_result`
#' seguendo la convenzione dell'ecosistema: RDS per le tabelle piccole
#' (`ranking`, `ranking_periodo`, `rilevanti`, `retribuzioni`, `qualita`) e
#' FST con compressione 85 per i cubi (`cpi`, `tipologie`). `meta` e `keys`
#' non sono tabelle e vengono sempre scritti in RDS.
#'
#' @param result Oggetto di classe `ccnlcob_result` prodotto da
#'   [analyze_ccnl()].
#' @param dir Directory di destinazione; viene creata se non esiste.
#' @param formats Vettore character nominato con i formati per le tabelle
#'   piccole (`small`) e per i cubi (`cube`). Valori ammessi: `"rds"`,
#'   `"fst"`.
#' @param overwrite Se `FALSE` (default) la funzione si ferma con un errore
#'   quando uno dei file di destinazione esiste già.
#'
#' @details
#' I file sono `meta.rds`, `ranking.<f>`, `ranking_periodo.<f>`,
#' `rilevanti.<f>`, `keys.rds`, `cpi.<f>`, `tipologie.<f>`,
#' `retribuzioni.<f>` e `qualita.<f>`, con `<f>` pari al formato della
#' famiglia. Gli elementi `NULL` del risultato (passi saltati) non producono
#' file e sono elencati in `meta$oggetti_assenti`. Il formato FST non
#' conserva gli attributi delle tabelle (`ccnlcob_ranking`,
#' `ccnlcob_crosstab`, ...): per ogni tabella scritta essi vengono salvati
#' in `meta$attributi[[nome]]`, così che `meta.rds` permetta di ricostruirli
#' con [attr()]. `meta$file` riporta il manifesto dei file scritti.
#'
#' @return Un `data.table` con una riga per file scritto e le colonne
#'   `oggetto`, `file` (percorso), `formato`, `righe` (`NA` per gli oggetti
#'   non tabellari) e `byte`, restituito invisibilmente.
#' @family orchestrazione
#' @seealso [analyze_ccnl()] per la produzione del risultato.
#' @export
#' @examples
#' res <- analyze_ccnl(cob_esempio, lookup_cpi = cpi_esempio, min_n = 10)
#' dir_out <- file.path(tempdir(), "ccnl")
#' manifesto <- write_results(res, dir = dir_out, overwrite = TRUE)
#' manifesto
#' readRDS(file.path(dir_out, "meta.rds"))$versione
#' unlink(dir_out, recursive = TRUE)
write_results <- function(
  result,
  dir,
  formats = c(small = "rds", cube = "fst"),
  overwrite = FALSE
) {
  # 2.1 Controlli -----
  if (!inherits(result, "ccnlcob_result")) {
    stop(
      "`result` deve essere un oggetto di classe `ccnlcob_result` prodotto ",
      "da analyze_ccnl().",
      call. = FALSE
    )
  }
  if (!is.character(dir) || length(dir) != 1L || is.na(dir) || dir == "") {
    stop("`dir` deve essere un singolo percorso.", call. = FALSE)
  }
  if (
    !is.character(formats) ||
      is.null(names(formats)) ||
      !all(c("small", "cube") %in% names(formats))
  ) {
    stop(
      "`formats` deve essere un vettore character con i nomi `small` e ",
      "`cube`.",
      call. = FALSE
    )
  }
  formats <- formats[c("small", "cube")]
  non_ammessi <- setdiff(formats, .formati_ammessi)
  if (length(non_ammessi) > 0L) {
    stop(
      "Formati non ammessi: ",
      paste(non_ammessi, collapse = ", "),
      ". Valori ammessi: ",
      paste(.formati_ammessi, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    stop("`overwrite` deve essere TRUE o FALSE.", call. = FALSE)
  }

  # 2.2 Piano dei file -----
  nomi <- names(.oggetti_risultato)
  presenti <- vapply(
    nomi,
    function(nm) !is.null(result[[nm]]),
    logical(1)
  )
  formato <- vapply(
    .oggetti_risultato,
    function(f) {
      if (f == "rds") "rds" else unname(formats[[f]])
    },
    character(1)
  )
  tabellare <- vapply(
    nomi,
    function(nm) is.data.frame(result[[nm]]),
    logical(1)
  )
  formato[!tabellare] <- "rds"
  file <- file.path(dir, paste0(nomi, ".", formato))
  names(file) <- nomi
  da_scrivere <- nomi[presenti]

  esistenti <- file[da_scrivere][file.exists(file[da_scrivere])]
  if (length(esistenti) > 0L && !overwrite) {
    stop(
      "File gi\u00e0 presenti in `dir` (usare overwrite = TRUE): ",
      paste(basename(esistenti), collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }

  # 2.3 Metadati arricchiti -----
  meta <- result[["meta"]]
  if (is.null(meta)) {
    meta <- list()
  }
  attributi <- lapply(
    da_scrivere[tabellare[da_scrivere]],
    function(nm) .attributi_ccnlcob(result[[nm]])
  )
  names(attributi) <- da_scrivere[tabellare[da_scrivere]]
  meta$attributi <- attributi
  meta$oggetti_assenti <- nomi[!presenti]
  meta$file <- data.table::data.table(
    oggetto = da_scrivere,
    file = basename(file[da_scrivere]),
    formato = unname(formato[da_scrivere])
  )

  # 2.4 Scrittura -----
  righe <- rep(NA_integer_, length(da_scrivere))
  for (i in seq_along(da_scrivere)) {
    nm <- da_scrivere[i]
    obj <- if (nm == "meta") meta else result[[nm]]
    if (is.data.frame(obj)) {
      righe[i] <- nrow(obj)
    }
    if (formato[[nm]] == "fst") {
      fst::write_fst(obj, path = file[[nm]], compress = 85)
    } else {
      saveRDS(obj, file = file[[nm]])
    }
  }

  manifesto <- data.table::data.table(
    oggetto = da_scrivere,
    file = unname(file[da_scrivere]),
    formato = unname(formato[da_scrivere]),
    righe = righe,
    byte = as.numeric(file.size(file[da_scrivere]))
  )
  invisible(manifesto)
}

#' Attributi `ccnlcob_*` di una tabella
#'
#' @param x Un `data.frame`.
#' @return Lista nominata (eventualmente vuota) degli attributi il cui nome
#'   inizia per `ccnlcob_`.
#' @keywords internal
#' @noRd
.attributi_ccnlcob <- function(x) {
  a <- attributes(x)
  a[grepl("^ccnlcob_", names(a))]
}
