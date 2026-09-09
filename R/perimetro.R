# 1. Perimetro CCNL -----

#' Filtra i rapporti per perimetro contrattuale
#'
#' Restringe un dataset di rapporti di lavoro alle tipologie contrattuali
#' alle quali si applica un contratto collettivo, oppure al perimetro
#' "standard" di `cnelR`, e riporta nei metadati quante righe sono state
#' escluse e per quale tipologia. Alcuni avviamenti presenti nelle
#' Comunicazioni Obbligatorie non sono rapporti di lavoro subordinato
#' (collaborazioni e parasubordinati, contratti di agenzia, tirocini e work
#' experience, associazione in partecipazione, lavoro autonomo nello
#' spettacolo, lavoro congiunto in agricoltura): includerli nelle
#' classifiche dei CCNL distorce le misure di rilevanza. L'esclusione è
#' sempre conteggiata e segnalata, mai silenziosa.
#'
#' @param dt Un `data.table` con la colonna `cod_tipologia_contrattuale`
#'   (codice MLPS); può essere il dato grezzo o l'uscita di
#'   [prepare_rapporti()]. Non viene modificato.
#' @param perimetro Perimetro da applicare:
#'   - `"ccnl"` (default): conserva i rapporti con `perimetro_ccnl == TRUE`
#'     nel lookup; i codici ignoti vengono esclusi;
#'   - `"standard"`: conserva i rapporti con `esclusa_standard == FALSE`
#'     (perimetro di `cnelR`); i codici ignoti vengono conservati;
#'   - `"completo"`: conserva tutte le righe.
#' @param tipologie Lookup delle tipologie contrattuali con le colonne
#'   `cod_tipologia_contrattuale`, `perimetro_ccnl` e `esclusa_standard`
#'   (le colonne `des_tipologia_contrattuale` e `macro_tipologia`, se
#'   presenti, arricchiscono la tabella degli esclusi); default
#'   [tipologie_contrattuali].
#'
#' @details
#' ## Regole del perimetro CCNL
#' Il flag `perimetro_ccnl` di [tipologie_contrattuali] è derivato dal
#' prefisso del codice MLPS. Appartengono al perimetro tutti i codici `A.`
#' (tempo indeterminato e determinato, apprendistato inclusi il contratto di
#' formazione lavoro `A.03.04` e l'inserimento `A.03.07`, lavoro domestico
#' `A.04.*`, intermittente, somministrazione, ripartito, a domicilio), i
#' codici `F.` (lavoro marittimo), `G.01.00` e `G.02.00` (spettacolo
#' subordinato), `H.01.00` e `H.03.00` (agricoltura subordinata), `I.`
#' (pubblica amministrazione) e `N.` (lavoro con piattaforma). Restano
#' fuori i codici `B.` (collaborazioni, lavoro occasionale,
#' parasubordinati), `C.` (tirocini, LSU, borsa lavoro e work experience),
#' `G.03.00` (lavoro autonomo nello spettacolo), `H.02.00` (lavoro
#' congiunto in agricoltura), `L.` (associazione in partecipazione) e `M.`
#' (contratto di agenzia). Un codice assente dal lookup è trattato come
#' fuori perimetro e conteggiato in `n_tipologia_ignota`.
#'
#' ## Perimetro standard
#' Il perimetro `"standard"` riproduce quello di `cnelR`: esclude solo i
#' codici con `esclusa_standard == TRUE` (`C.01.00`, `B.04.00`, `B.03.00`,
#' `A.04.00`, `A.04.01`). I codici ignoti vengono conservati e conteggiati.
#'
#' ## Colonna e metadati
#' Il risultato porta sempre la colonna logica `perimetro_ccnl`, aggiunta
#' se assente (una colonna già presente viene conservata così com'è; il
#' filtro usa comunque il lookup). L'attributo `ccnlcob_perimetro` è una
#' lista con `perimetro`, `n_input`, `n_kept`, `n_dropped`,
#' `n_tipologia_ignota` e `esclusi`, un `data.table` con le colonne
#' `cod_tipologia_contrattuale`, `des_tipologia_contrattuale`,
#' `macro_tipologia` e `n` (righe escluse per tipologia, in ordine
#' decrescente di `n`; zero righe se nulla è stato escluso). Quando
#' vengono escluse righe o compaiono codici ignoti la funzione emette un
#' `message()` riassuntivo, sopprimibile con [suppressMessages()].
#'
#' @return Un nuovo `data.table` con le righe di `dt` interne al perimetro,
#'   la colonna `perimetro_ccnl` e l'attributo `ccnlcob_perimetro`. L'input
#'   non viene modificato.
#' @family tipologie
#' @seealso [prepare_rapporti()], che applica il filtro in ingresso;
#'   [tipologie_contrattuali] per le regole.
#' @export
#' @examples
#' library(data.table)
#' dt <- filter_perimetro(cob_esempio)
#' nrow(cob_esempio)
#' nrow(dt)
#' info <- attr(dt, "ccnlcob_perimetro")
#' info[c("perimetro", "n_input", "n_kept", "n_dropped", "n_tipologia_ignota")]
#' info$esclusi
#'
#' # perimetro standard di cnelR e dataset completo
#' std <- filter_perimetro(cob_esempio, perimetro = "standard")
#' attr(std, "ccnlcob_perimetro")$esclusi
#' tutto <- filter_perimetro(cob_esempio, perimetro = "completo")
#' tutto[, .N, by = perimetro_ccnl]
filter_perimetro <- function(
  dt,
  perimetro = c("ccnl", "standard", "completo"),
  tipologie = ccnlcob::tipologie_contrattuali
) {
  # 1.1 Controlli -----
  perimetro <- match.arg(perimetro)
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare filter_perimetro().",
      call. = FALSE
    )
  }
  if (!"cod_tipologia_contrattuale" %in% names(dt)) {
    stop(
      "Colonna `cod_tipologia_contrattuale` assente da `dt`: impossibile ",
      "applicare il perimetro.",
      call. = FALSE
    )
  }
  .assert_tipologie_perimetro(tipologie)

  # 1.2 Flag dal lookup -----
  flags <- .perimetro_flags(
    dt[["cod_tipologia_contrattuale"]],
    tipologie = tipologie,
    perimetro = perimetro
  )
  n_input <- nrow(dt)
  n_kept <- sum(flags$keep)
  n_dropped <- n_input - n_kept

  # 1.3 Tabella degli esclusi -----
  esclusi <- .tabella_esclusi(
    dt[["cod_tipologia_contrattuale"]][!flags$keep],
    tipologie = tipologie
  )

  # 1.4 Nuovo data.table -----
  out <- dt[flags$keep]
  if (!"perimetro_ccnl" %in% names(out)) {
    data.table::set(
      out,
      j = "perimetro_ccnl",
      value = flags$perimetro_ccnl[flags$keep]
    )
  }

  info <- list(
    perimetro = perimetro,
    n_input = as.integer(n_input),
    n_kept = as.integer(n_kept),
    n_dropped = as.integer(n_dropped),
    n_tipologia_ignota = as.integer(flags$n_ignota),
    esclusi = esclusi
  )
  data.table::setattr(out, "ccnlcob_perimetro", info)

  if (n_dropped > 0L || flags$n_ignota > 0L) {
    message(.messaggio_perimetro(info))
  }
  out[]
}

# 2. Helper interni -----

#' Verifica il lookup delle tipologie per il perimetro
#'
#' @param tipologie Lookup da verificare.
#' @return `invisible(TRUE)` oppure un errore.
#' @keywords internal
#' @noRd
.assert_tipologie_perimetro <- function(tipologie) {
  richieste <- c(
    "cod_tipologia_contrattuale",
    "perimetro_ccnl",
    "esclusa_standard"
  )
  if (!is.data.frame(tipologie) || !all(richieste %in% names(tipologie))) {
    stop(
      "`tipologie` deve essere un data.frame con le colonne ",
      paste(richieste, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (
    !is.logical(tipologie[["perimetro_ccnl"]]) ||
      !is.logical(tipologie[["esclusa_standard"]])
  ) {
    stop(
      "Le colonne `perimetro_ccnl` e `esclusa_standard` di `tipologie` ",
      "devono essere logical.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Calcola i flag di perimetro per un vettore di codici
#'
#' @param codici Vettore di codici MLPS (character o factor).
#' @param tipologie Lookup già verificato.
#' @param perimetro Uno fra `"ccnl"`, `"standard"`, `"completo"`.
#' @return Lista con `keep` (logical, righe da conservare),
#'   `perimetro_ccnl` (logical, `FALSE` per i codici ignoti) e `n_ignota`
#'   (integer, codici assenti dal lookup, `NA` inclusi).
#' @keywords internal
#' @noRd
.perimetro_flags <- function(codici, tipologie, perimetro) {
  codici <- as.character(codici)
  idx <- match(codici, as.character(tipologie[["cod_tipologia_contrattuale"]]))
  ignota <- is.na(idx)

  perimetro_ccnl <- tipologie[["perimetro_ccnl"]][idx]
  perimetro_ccnl[ignota | is.na(perimetro_ccnl)] <- FALSE

  keep <- switch(
    perimetro,
    ccnl = perimetro_ccnl,
    standard = {
      esclusa <- tipologie[["esclusa_standard"]][idx]
      ignota | (!is.na(esclusa) & !esclusa)
    },
    completo = rep(TRUE, length(codici))
  )

  list(
    keep = keep,
    perimetro_ccnl = perimetro_ccnl,
    n_ignota = as.integer(sum(ignota))
  )
}

#' Costruisce la tabella delle tipologie escluse
#'
#' @param codici_esclusi Codici delle righe escluse (character, con
#'   eventuali `NA`).
#' @param tipologie Lookup; `des_tipologia_contrattuale` e
#'   `macro_tipologia` sono usate se presenti.
#' @return `data.table` con `cod_tipologia_contrattuale`,
#'   `des_tipologia_contrattuale`, `macro_tipologia`, `n`, in ordine
#'   decrescente di `n`; zero righe se `codici_esclusi` è vuoto.
#' @keywords internal
#' @noRd
.tabella_esclusi <- function(codici_esclusi, tipologie) {
  conteggi <- data.table::data.table(
    cod_tipologia_contrattuale = as.character(codici_esclusi)
  )[, list(n = .N), by = cod_tipologia_contrattuale]

  lookup_cod <- as.character(tipologie[["cod_tipologia_contrattuale"]])
  idx <- match(conteggi[["cod_tipologia_contrattuale"]], lookup_cod)
  des <- if ("des_tipologia_contrattuale" %in% names(tipologie)) {
    as.character(tipologie[["des_tipologia_contrattuale"]])[idx]
  } else {
    rep(NA_character_, length(idx))
  }
  macro <- if ("macro_tipologia" %in% names(tipologie)) {
    as.character(tipologie[["macro_tipologia"]])[idx]
  } else {
    rep(NA_character_, length(idx))
  }
  data.table::set(conteggi, j = "des_tipologia_contrattuale", value = des)
  data.table::set(conteggi, j = "macro_tipologia", value = macro)
  data.table::setcolorder(
    conteggi,
    c(
      "cod_tipologia_contrattuale",
      "des_tipologia_contrattuale",
      "macro_tipologia",
      "n"
    )
  )
  data.table::setorderv(
    conteggi,
    c("n", "cod_tipologia_contrattuale"),
    c(-1L, 1L)
  )
  conteggi[]
}

#' Testo del messaggio riassuntivo del filtro
#'
#' @param info Lista `ccnlcob_perimetro`.
#' @return Stringa.
#' @keywords internal
#' @noRd
.messaggio_perimetro <- function(info) {
  quota <- if (info$n_input > 0L) {
    100 * info$n_dropped / info$n_input
  } else {
    0
  }
  paste0(
    "filter_perimetro(): perimetro \"",
    info$perimetro,
    "\", esclusi ",
    info$n_dropped,
    " rapporti su ",
    info$n_input,
    " (",
    formatC(quota, format = "f", digits = 1, decimal.mark = ","),
    "%) in ",
    nrow(info$esclusi),
    " tipologie; ",
    info$n_tipologia_ignota,
    " con tipologia ignota."
  )
}
