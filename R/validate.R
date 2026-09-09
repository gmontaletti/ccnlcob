# 1. Validazione del contratto dati -----

#' Valida il contratto dati dei rapporti di lavoro
#'
#' Verifica che `dt` sia un `data.table` e che contenga le colonne richieste
#' dal contratto dati del pacchetto. Il blocco `"base"` è sempre verificato;
#' i blocchi aggiuntivi (`"cpi"`, `"retribuzione"`, `"datore"`) vengono
#' controllati solo se richiesti tramite `require`.
#'
#' @param dt Un `data.table` con una riga per rapporto di lavoro.
#' @param require Vettore character con i blocchi di colonne da verificare.
#'   Valori ammessi: `"base"` (sempre incluso), `"cpi"`, `"retribuzione"`,
#'   `"datore"`; qualsiasi altro valore, anche in un vettore misto, produce
#'   un errore. Vedi Dettagli.
#'
#' @details
#' Blocchi e colonne richieste:
#' - `"base"`: `id`, `cf`, `inizio`, `fine`, `cod_tipologia_contrattuale`,
#'   `prior`, più almeno una fra `codice_cnel`, `ccnl` e `ccnl_warehouse`.
#'   Le colonne `inizio` e `fine` devono ereditare dalla classe `Date`
#'   (`IDate` è accettata).
#' - `"cpi"`: `comune_sede_lavoro` (codice Belfiore della sede di lavoro).
#' - `"retribuzione"`: `retribuzione` e `ore`.
#' - `"datore"`: `datore` (codice fiscale del datore di lavoro).
#'
#' La funzione non modifica `dt`. Le sentinelle sulle date (`1900-01-01`,
#' `9999-12-31`, `fine < inizio`) non vengono verificate qui: sono di
#' competenza di [prepare_rapporti()].
#'
#' @return `dt`, restituito invisibilmente, se tutte le verifiche passano.
#'   In caso contrario un errore che elenca le colonne mancanti
#'   (`Colonne mancanti: ...`), l'assenza di una colonna CCNL o le colonne
#'   data con classe non valida.
#' @family ingresso
#' @export
#' @examples
#' \dontrun{
#' library(data.table)
#' dt <- copy(cob_esempio)
#' validate_rapporti(dt)
#' validate_rapporti(dt, require = c("cpi", "retribuzione"))
#'
#' # errore: manca la colonna comune_sede_lavoro
#' validate_rapporti(dt[, !"comune_sede_lavoro"], require = "cpi")
#' }
validate_rapporti <- function(dt, require = "base") {
  .assert_rapporti(dt, require = require, caller = "validate_rapporti")
  invisible(dt)
}

# 2. Verifica interna -----

#' Verifica interna del contratto dati
#'
#' Esegue i controlli di [validate_rapporti()] e viene richiamata dalle
#' funzioni analitiche prima di operare su `dt`.
#'
#' @inheritParams validate_rapporti
#' @param caller Nome della funzione chiamante, usato nei messaggi di errore.
#' @return `invisible(TRUE)` se tutte le verifiche passano; altrimenti un
#'   errore.
#' @keywords internal
#' @noRd
.assert_rapporti <- function(
  dt,
  require = "base",
  caller = "validate_rapporti"
) {
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare ",
      caller,
      "().",
      call. = FALSE
    )
  }

  scelte <- c("base", "cpi", "retribuzione", "datore")
  if (!is.character(require) || length(require) == 0L || anyNA(require)) {
    stop(
      "`require` deve essere un vettore character non vuoto con valori fra: ",
      paste(scelte, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  non_ammessi <- setdiff(require, scelte)
  if (length(non_ammessi) > 0L) {
    stop(
      "Valori di `require` non ammessi: ",
      paste(non_ammessi, collapse = ", "),
      ". Ammessi: ",
      paste(scelte, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  require <- union("base", require)

  richieste <- list(
    base = c(
      "id",
      "cf",
      "inizio",
      "fine",
      "cod_tipologia_contrattuale",
      "prior"
    ),
    cpi = "comune_sede_lavoro",
    retribuzione = c("retribuzione", "ore"),
    datore = "datore"
  )
  ccnl_cols <- c("codice_cnel", "ccnl", "ccnl_warehouse")

  attese <- unique(unlist(richieste[require], use.names = FALSE))
  presenti <- names(dt)
  mancanti <- setdiff(attese, presenti)

  msg <- character(0)
  if (length(mancanti) > 0L) {
    msg <- c(
      msg,
      paste0("Colonne mancanti: ", paste(mancanti, collapse = ", "))
    )
  }
  if (!any(ccnl_cols %in% presenti)) {
    msg <- c(
      msg,
      paste0(
        "Nessuna colonna CCNL: \u00e8 richiesta almeno una fra ",
        paste(ccnl_cols, collapse = ", ")
      )
    )
  }
  if (length(msg) > 0L) {
    stop(paste(msg, collapse = "\n"), call. = FALSE)
  }

  date_cols <- c("inizio", "fine")
  is_date <- vapply(
    date_cols,
    function(col) inherits(dt[[col]], "Date"),
    logical(1)
  )
  if (!all(is_date)) {
    stop(
      "Le colonne ",
      paste(date_cols[!is_date], collapse = ", "),
      " devono essere di classe Date o IDate.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}
