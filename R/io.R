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

#' Serializza i risultati di analyze_ccnl()
#'
#' Scrive su disco le tabelle contenute in un oggetto `ccnlcob_result`
#' seguendo la convenzione dell'ecosistema: RDS per le tabelle piccole
#' (`meta`, `ranking`, `rilevanti`, `retribuzioni`, `qualita`) e FST con
#' compressione 85 per i cubi (`cpi`, `tipologie`).
#'
#' @param result Oggetto di classe `ccnlcob_result` prodotto da
#'   [analyze_ccnl()].
#' @param dir Directory di destinazione; viene creata se non esiste.
#' @param formats Vettore character nominato con i formati per le tabelle
#'   piccole (`small`) e per i cubi (`cube`). Valori ammessi: `"rds"`,
#'   `"fst"`.
#'
#' @return Vettore character nominato con i percorsi dei file scritti,
#'   restituito invisibilmente.
#' @family orchestrazione
#' @export
#' @examples
#' \dontrun{
#' res <- analyze_ccnl(cob_esempio, window = as.Date(c("2022-01-01", "2024-12-31")))
#' write_results(res, dir = "output/ccnl")
#' }
write_results <- function(
  result,
  dir,
  formats = c(small = "rds", cube = "fst")
) {
  stop(
    "Funzione non ancora implementata (Fase 4 del piano di sviluppo).",
    call. = FALSE
  )
}
