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
#' Aggiunge (o sovrascrive) per riferimento la colonna `giornate_effettive`:
#' i giorni-persona che ciascun rapporto riceve dopo aver ripartito i giorni
#' in cui la stessa persona ha più rapporti concorrenti. Ogni giorno-persona
#' compreso nella finestra viene diviso in parti uguali (1/`arco`) fra i
#' rapporti attivi in quel giorno, così che la somma di `giornate_effettive`
#' sui rapporti di una persona coincida con i giorni in cui la persona è
#' occupata (unione degli intervalli, tagliata alla finestra). La somma per
#' CCNL è la misura `giornate_effettive` di [rank_ccnl()].
#'
#' @param dt Un `data.table` con le colonne `id`, `cf`, `inizio` e `fine`
#'   (`Date` o `IDate`), tipicamente l'output di [prepare_rapporti()], che
#'   ha già risolto le sentinelle sulle date. Viene modificato per
#'   riferimento.
#' @inheritParams compute_giornate
#'
#' @details
#' Algoritmo, esatto su date intere con estremi inclusi e interamente
#' vettorizzato con `data.table`:
#' 1. gli intervalli sono tagliati alla finestra; i rapporti interamente
#'    fuori finestra ricevono 0;
#' 2. le persone con un solo rapporto (o con `cf` mancante) ricevono
#'    `giornate_effettive = giornate` senza ulteriori calcoli;
#' 3. per le altre persone i punti di rottura sono le date `inizio` e
#'    `fine + 1` dei rapporti; ogni coppia di punti consecutivi definisce un
#'    segmento `[b_k, b_(k+1) - 1]` e `arco` è il numero di rapporti della
#'    persona che coprono il segmento (somma cumulata degli eventi di
#'    apertura e chiusura);
#' 4. un join non-equi associa ogni rapporto ai segmenti che copre e gli
#'    assegna `giorni_segmento / arco`; la somma per rapporto è
#'    `giornate_effettive`.
#'
#' Quando due CCNL diversi si sovrappongono, ciascuno riceve metà dei
#' giorni. Invariante: la somma di `giornate_effettive` per `cf` è uguale ai
#' giorni-persona occupati nella finestra; per le persone senza
#' sovrapposizioni `giornate_effettive == giornate`. Righe con date mancanti
#' ricevono `NA`.
#'
#' Rispetto a `vecshift::vecshift()`, che assegna il giorno di transizione
#' al segmento precedente, la suddivisione in segmenti differisce di un
#' giorno per ogni transizione; il totale per persona coincide
#' (`sum(durata[arco > 0])` di `vecshift`). Il pacchetto non dipende da
#' `vecshift` per questo calcolo.
#'
#' @return `dt` con la colonna `giornate_effettive` (numeric) aggiunta per
#'   riferimento, restituito invisibilmente. L'attributo
#'   `ccnlcob_giornate_effettive` è una lista con `window`,
#'   `n_persone_sovrapposizioni` (persone con almeno un giorno in cui hanno
#'   più di un rapporto), `giornate_totali` (somma dei giorni-contratto
#'   nella finestra) e `giornate_effettive_totali` (somma dei giorni-persona).
#' @family giornate
#' @export
#' @examples
#' library(data.table)
#' dt <- prepare_rapporti(cob_esempio)
#' compute_giornate_effettive(dt, window = as.Date(c("2023-01-01", "2023-12-31")))
#' dt[, .(giornate = sum(giornate), effettive = sum(giornate_effettive)), by = ccnl_key][
#'   order(-effettive)
#' ][1:5]
#' attr(dt, "ccnlcob_giornate_effettive")$n_persone_sovrapposizioni
#'
#' # invariante: per persona, la somma coincide con i giorni occupati
#' compute_giornate_effettive(dt)
#' dt[cf == dt$cf[1], .(id, inizio, fine, giornate, giornate_effettive)]
compute_giornate_effettive <- function(dt, window = NULL) {
  # 2.1 Controlli -----
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare compute_giornate_effettive().",
      call. = FALSE
    )
  }
  richieste <- c("id", "cf", "inizio", "fine")
  mancanti <- setdiff(richieste, names(dt))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti: ",
      paste(mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
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
  window <- .as_window(window, caller = "compute_giornate_effettive")

  # 2.2 Intervalli tagliati alla finestra -----
  n <- nrow(dt)
  s <- as.integer(dt[["inizio"]])
  e <- as.integer(dt[["fine"]])
  if (!is.null(window)) {
    s <- pmax(s, as.integer(window[1L]))
    e <- pmin(e, as.integer(window[2L]))
  }
  giornate <- pmax(0L, e - s + 1L)
  eff <- as.numeric(giornate)
  cf <- dt[["cf"]]
  if (!is.character(cf)) {
    cf <- as.character(cf)
  }

  # 2.3 Persone con più rapporti in finestra -----
  attivo <- !is.na(giornate) & giornate > 0L & !is.na(cf)
  n_persone_sovrapposizioni <- 0L
  if (any(attivo)) {
    work <- data.table::data.table(
      .riga = which(attivo),
      cf = cf[attivo],
      s = s[attivo],
      e = e[attivo]
    )
    work[, n_cf := .N, by = cf]
    work <- work[n_cf > 1L]
    if (nrow(work) > 0L) {
      alloc <- .alloca_segmenti(work)
      eff[alloc[[".riga"]]] <- alloc[["giornate_effettive"]]
      n_persone_sovrapposizioni <- attr(alloc, "n_persone_sovrapposizioni")
    }
  }

  data.table::set(dt, j = "giornate_effettive", value = eff)
  data.table::setattr(
    dt,
    "ccnlcob_giornate_effettive",
    list(
      window = window,
      n_persone_sovrapposizioni = as.integer(n_persone_sovrapposizioni),
      giornate_totali = sum(as.numeric(giornate), na.rm = TRUE),
      giornate_effettive_totali = sum(eff, na.rm = TRUE)
    )
  )
  invisible(dt)
}

# 3. Helper interni -----

#' Alloca i giorni dei segmenti elementari fra i rapporti di ciascuna persona
#'
#' @param work `data.table` con `.riga` (indice di riga in `dt`), `cf`, `s`
#'   ed `e` (date come integer, già tagliate alla finestra, `e >= s`), solo
#'   per persone con almeno due rapporti.
#' @return `data.table` con `.riga` e `giornate_effettive` (numeric), una
#'   riga per rapporto di `work`; attributo `n_persone_sovrapposizioni`.
#' @keywords internal
#' @noRd
.alloca_segmenti <- function(work) {
  # 3.1 Eventi di apertura (+1 in `s`) e chiusura (-1 in `e + 1`) -----
  eventi <- data.table::rbindlist(list(
    work[, list(cf = cf, b = s, d = 1L)],
    work[, list(cf = cf, b = e + 1L, d = -1L)]
  ))
  eventi <- eventi[, list(d = sum(d)), by = c("cf", "b")]
  data.table::setorderv(eventi, c("cf", "b"))
  eventi[, arco := cumsum(d), by = cf]
  eventi[, seg_fine := data.table::shift(b, type = "lead") - 1L, by = cf]
  seg <- eventi[
    !is.na(seg_fine) & arco > 0L,
    list(cf = cf, seg_inizio = b, seg_fine = seg_fine, arco = arco)
  ]
  seg[, giorni_intersezione := as.numeric(seg_fine - seg_inizio + 1L) / arco]
  n_sovr <- seg[arco > 1L, data.table::uniqueN(cf)]

  # 3.2 Join non-equi rapporto x segmenti coperti -----
  # Un segmento elementare e' coperto per intero o per nulla da ciascun
  # rapporto: basta verificare che il suo inizio cada nell'intervallo.
  alloc <- seg[
    work,
    on = c("cf", "seg_inizio>=s", "seg_inizio<=e"),
    list(.riga = i..riga, quota = x.giorni_intersezione),
    nomatch = NULL
  ]
  out <- alloc[, list(giornate_effettive = sum(quota)), by = ".riga"]
  data.table::setattr(out, "n_persone_sovrapposizioni", as.integer(n_sovr))
  out
}
