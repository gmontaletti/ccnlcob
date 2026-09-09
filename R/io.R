# 1. Lettura dei rapporti -----

#' Legge i rapporti di lavoro da file o da connessione DBI
#'
#' Carica un dataset di rapporti di lavoro da un file `.fst`/`.rds` oppure da
#' una tabella raggiungibile tramite una connessione DBI (DuckDB o
#' PostgreSQL), normalizza i tipi delle colonne e restituisce un `data.table`
#' conforme al contratto dati atteso da [validate_rapporti()].
#'
#' @param source Percorso di un file `.fst` o `.rds`, oppure una connessione
#'   `DBI::DBIConnection` (in tal caso è richiesto `table`).
#' @param table Nome della tabella o vista da leggere quando `source` è una
#'   connessione DBI; ignorato per i file. Per la slice prodotta da `cnelR`
#'   il valore tipico è `"sl2_rapporti_36m_classificati"`.
#' @param columns Vettore character con le colonne da leggere; `NULL` legge
#'   tutte le colonne disponibili.
#'
#' @details
#' La normalizzazione dei tipi converte i `factor` in character, gli interi a
#' 64 bit in integer e le date in `IDate`; i nomi delle colonne vengono
#' portati in minuscolo. La funzione chiama `data.table::setDT()` sul
#' risultato e non applica alcuna trasformazione analitica: le sentinelle
#' sulle date e la rinomina di `ccnl` in `ccnl_warehouse` restano di
#' competenza di [prepare_rapporti()].
#'
#' @return Un `data.table` con una riga per rapporto di lavoro.
#' @family ingresso
#' @export
#' @examples
#' \dontrun{
#' # da file FST
#' dt <- read_rapporti("output/rapporti_classificati.fst")
#'
#' # da DuckDB (slice classificata da cnelR)
#' con <- DBI::dbConnect(duckdb::duckdb(), "cob.duckdb", read_only = TRUE)
#' dt <- read_rapporti(con, table = "sl2_rapporti_36m_classificati")
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
read_rapporti <- function(source, table = NULL, columns = NULL) {
  stop(
    "Funzione non ancora implementata (Fase 5 del piano di sviluppo).",
    call. = FALSE
  )
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
