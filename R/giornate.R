# 1. Giornate contrattuali -----

#' Calcola le giornate di contratto nella finestra di analisi
#'
#' Aggiunge (o sovrascrive) per riferimento la colonna `giornate`, cioè il
#' numero di giorni di ciascun rapporto compresi nella finestra di analisi,
#' estremi inclusi. La misura è additiva e conta ogni rapporto per intero,
#' senza correggere le sovrapposizioni fra rapporti della stessa persona
#' (per quello vedi [compute_giornate_effettive()]).
#'
#' @param dt Un `data.table` con le colonne `inizio` e `fine` di classe
#'   `Date` (`IDate` accettata), tipicamente l'output di
#'   [prepare_rapporti()]. Viene modificato per riferimento.
#' @param window Vettore di due `Date` (o stringhe convertibili),
#'   `c(inizio, fine)`, ordinate; `NULL` (default) non applica alcun taglio
#'   e conta l'intera durata del rapporto.
#'
#' @details
#' Per ogni rapporto
#' `giornate = max(0, min(fine, window[2]) - max(inizio, window[1]) + 1)`.
#' Un rapporto interamente fuori finestra ha `giornate = 0`; un rapporto
#' interamente dentro ha `giornate = fine - inizio + 1`; con `window = NULL`
#' vale sempre `fine - inizio + 1` (0 se `fine < inizio`). Il calcolo avviene
#' su giorni interi: la colonna è di tipo integer, mai `difftime`. Date
#' mancanti producono `giornate = NA`; le sentinelle non vengono trattate
#' qui ma in [prepare_rapporti()].
#'
#' @return `dt` con la colonna `giornate` (integer) aggiunta per riferimento,
#'   restituito invisibilmente.
#' @family giornate
#' @export
#' @examples
#' library(data.table)
#' dt <- prepare_rapporti(cob_esempio)
#' compute_giornate(dt, window = as.Date(c("2023-01-01", "2023-12-31")))
#' dt[giornate > 0, sum(giornate), by = ccnl_key][order(-V1)][1:5]
#'
#' # senza finestra: intera durata del rapporto
#' compute_giornate(dt)
#' dt[, summary(giornate)]
compute_giornate <- function(dt, window = NULL) {
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare compute_giornate().",
      call. = FALSE
    )
  }
  date_cols <- c("inizio", "fine")
  mancanti <- setdiff(date_cols, names(dt))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti: ",
      paste(mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
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
  window <- .as_window(window, caller = "compute_giornate")

  inizio <- as.integer(dt[["inizio"]])
  fine <- as.integer(dt[["fine"]])
  if (!is.null(window)) {
    inizio <- pmax(inizio, as.integer(window[1L]))
    fine <- pmin(fine, as.integer(window[2L]))
  }
  giornate <- pmax(0L, fine - inizio + 1L)
  data.table::set(dt, j = "giornate", value = as.integer(giornate))
  invisible(dt)
}

# 2. Giornate effettive -----

#' Calcola le giornate effettive allocate pro quota fra rapporti concorrenti
#'
#' Aggiunge la colonna `giornate_effettive`: i giorni-persona che ciascun
#' rapporto riceve dopo aver ripartito i giorni in cui la stessa persona ha
#' più rapporti concorrenti. La somma per persona coincide con i giorni-persona
#' occupati; la somma per CCNL è la misura di rilevanza usata da
#' [rank_ccnl()].
#'
#' @inheritParams compute_giornate
#'
#' @details
#' Algoritmo:
#' 1. per ciascuna persona `vecshift::vecshift()` produce segmenti disgiunti
#'    con `arco` = numero di rapporti concorrenti nel segmento;
#' 2. un join non-equi associa ogni rapporto ai segmenti della stessa
#'    persona che interseca;
#' 3. `giornate_effettive = sum(giorni_intersezione / arco)` per rapporto.
#'
#' Quando due CCNL diversi si sovrappongono, ciascuno riceve metà dei giorni.
#' Invariante: `sum(giornate_effettive)` per `cf` è uguale ai giorni-persona
#' occupati nella finestra. Il passo è l'unico non lineare del pacchetto e
#' viene eseguito a blocchi di persone.
#'
#' @return `dt` con la colonna `giornate_effettive` (numeric) aggiunta per
#'   riferimento, restituito invisibilmente.
#' @family giornate
#' @export
#' @examples
#' \dontrun{
#' dt <- prepare_rapporti(cob_esempio)
#' compute_giornate_effettive(dt, window = as.Date(c("2023-01-01", "2023-12-31")))
#' dt[, .(giornate = sum(giornate), effettive = sum(giornate_effettive)), by = ccnl_key]
#' }
compute_giornate_effettive <- function(dt, window = NULL) {
  stop(
    "Funzione non ancora implementata (Fase 4 del piano di sviluppo).",
    call. = FALSE
  )
}
