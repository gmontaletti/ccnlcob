# 1. Simboli -----

utils::globalVariables(c(
  "totale_ccnl",
  "totale_dim",
  "totale",
  "i.totale_ccnl",
  "i.totale_dim",
  "i.totale"
))

# 2. Aggregazione delle misure -----

#' Aggrega le misure di rilevanza per gruppo
#'
#' Calcola, per ciascuna combinazione di `grp_cols`, le misure richieste con
#' le definizioni di [rank_ccnl()]: `n_rapporti` (righe con `avviato`),
#' `n_lavoratori` e `n_datori` (`cf` e `datore` distinti fra gli avviati),
#' `giornate` e `giornate_effettive` (somme) e `stock` (righe con `attivo`).
#' Se `avviato` o `attivo` mancano vengono considerati `TRUE` con un
#' messaggio; `NA` equivale a `FALSE`. L'input non viene modificato.
#'
#' @param dt Un `data.table` (o `data.frame`) con le colonne di `grp_cols` e
#'   quelle richieste dalle misure (vedi `.ranking_required`).
#' @param grp_cols Vettore character delle colonne di gruppo, anche vuoto.
#' @param measures Vettore character di misure fra `.ranking_measures`.
#' @return Un `data.table` con una riga per gruppo, le colonne di `grp_cols`
#'   e una colonna per misura; con chiave `grp_cols` se non vuoto.
#' @keywords internal
#' @noRd
.aggregate_misure <- function(dt, grp_cols, measures) {
  work <- .work_misure(dt, grp_cols, measures)
  j <- as.call(c(quote(list), .ranking_exprs[measures]))
  if (length(grp_cols) == 0L) {
    return(work[, eval(j)][])
  }
  agg <- work[, eval(j), by = grp_cols]
  data.table::setkeyv(agg, grp_cols)
  agg[]
}

#' Tabella di lavoro con i flag `avviato` e `attivo` normalizzati
#'
#' Restituisce `dt` stesso quando i flag richiesti dalle misure sono già
#' logici senza `NA`; altrimenti una proiezione delle sole colonne
#' necessarie con i flag ricostruiti (colonna assente → `TRUE` con
#' messaggio; `NA` → `FALSE`). Verifica la presenza delle colonne richieste.
#'
#' @inheritParams .aggregate_misure
#' @return Un `data.table` che contiene `grp_cols`, le colonne delle misure
#'   e i flag necessari.
#' @keywords internal
#' @noRd
.work_misure <- function(dt, grp_cols, measures) {
  usa_avviato <- any(measures %in% c("n_rapporti", "n_lavoratori", "n_datori"))
  usa_attivo <- "stock" %in% measures
  richieste <- unique(unlist(.ranking_required[measures], use.names = FALSE))
  mancanti <- setdiff(c(grp_cols, richieste), names(dt))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti in `dt`: ",
      paste(mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  flag_ok <- function(nome) {
    nome %in% names(dt) && is.logical(dt[[nome]]) && !anyNA(dt[[nome]])
  }
  if (
    data.table::is.data.table(dt) &&
      (!usa_avviato || flag_ok("avviato")) &&
      (!usa_attivo || flag_ok("attivo"))
  ) {
    return(dt)
  }
  cols <- unique(c(
    grp_cols,
    richieste,
    if (usa_avviato && "avviato" %in% names(dt)) "avviato",
    if (usa_attivo && "attivo" %in% names(dt)) "attivo"
  ))
  work <- .project_cols(dt, cols)
  if (usa_avviato) {
    if (!"avviato" %in% names(work)) {
      message(
        "Colonna `avviato` assente: tutti i rapporti sono considerati avviati ",
        "nella finestra."
      )
      data.table::set(work, j = "avviato", value = rep(TRUE, nrow(work)))
    } else {
      data.table::set(work, j = "avviato", value = work[["avviato"]] %in% TRUE)
    }
  }
  if (usa_attivo) {
    if (!"attivo" %in% names(work)) {
      message(
        "Colonna `attivo` assente: tutti i rapporti sono considerati attivi."
      )
      data.table::set(work, j = "attivo", value = rep(TRUE, nrow(work)))
    } else {
      data.table::set(work, j = "attivo", value = work[["attivo"]] %in% TRUE)
    }
  }
  work
}

#' Proiezione di colonne in un nuovo data.table
#'
#' @param dt Un `data.table` o `data.frame`.
#' @param cols Vettore character di colonne presenti in `dt`.
#' @return Un nuovo `data.table` con le sole colonne `cols`.
#' @keywords internal
#' @noRd
.project_cols <- function(dt, cols) {
  if (data.table::is.data.table(dt)) {
    return(dt[, cols, with = FALSE])
  }
  data.table::as.data.table(dt[cols])
}

# 3. Tabella incrociata CCNL x dimensioni -----

#' Distribuisce una misura per CCNL e dimensioni
#'
#' Costruisce la tabella (`by`, `periodo`) x `ccnl_key` x `dim_cols` con il
#' valore della misura, la quota di riga (entro CCNL), la quota di colonna
#' (entro dimensione) e il quoziente di localizzazione. I totali sono
#' calcolati su tutte le righe di `dt`, incluse quelle con `ccnl_key`
#' mancante e prima del filtro `ccnl`.
#'
#' @param dt Un `data.table` preparato con `ccnl_key`, `giornate`, le colonne
#'   di `dim_cols`, `by`, `periodo` e quelle richieste dalla misura.
#' @param dim_cols Vettore character non vuoto delle dimensioni di colonna.
#' @param measure Singola misura fra `.ranking_measures`.
#' @param by Colonne aggiuntive di raggruppamento o `NULL`.
#' @param periodo `NULL`, `"anno"` o `"trimestre"`.
#' @param ccnl `NULL` per tutte le chiavi, altrimenti vettore character delle
#'   chiavi da conservare (`NA` incluso conserva i non classificati).
#' @param min_n Soglia sul totale della dimensione sotto la quale `lq` è
#'   mascherato con `NA`.
#' @return Un `data.table` con le colonne di `by` e `periodo`, `ccnl_key`,
#'   `classe`, `dim_cols`, `<measure>`, `quota_riga`, `quota_colonna`, `lq`,
#'   ordinato per gruppo, `ccnl_key` (`NA` in coda), misura decrescente e
#'   dimensioni; attributo `ccnlcob_crosstab` con `measure`, `dims`, `by`,
#'   `periodo`, `min_n`. L'input non viene modificato.
#' @keywords internal
#' @noRd
.crosstab_ccnl <- function(
  dt,
  dim_cols,
  measure,
  by = NULL,
  periodo = NULL,
  ccnl = NULL,
  min_n = 30L
) {
  # 3.1 Controlli -----
  if (!is.data.frame(dt)) {
    stop("`dt` deve essere un data.table di rapporti.", call. = FALSE)
  }
  mancanti <- setdiff(c("ccnl_key", "giornate"), names(dt))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti in `dt`: ",
      paste(mancanti, collapse = ", "),
      ". Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  measure <- .check_measure(measure)
  if (!is.character(dim_cols) || length(dim_cols) == 0L || anyNA(dim_cols)) {
    stop(
      "`dim_cols` deve essere un vettore character non vuoto.",
      call. = FALSE
    )
  }
  dim_cols <- unique(dim_cols)
  dim_mancanti <- setdiff(dim_cols, names(dt))
  if (length(dim_mancanti) > 0L) {
    stop(
      "Dimensioni assenti da `dt`: ",
      paste(dim_mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if ("ccnl_key" %in% dim_cols) {
    stop("`dim_cols` non pu\u00f2 contenere `ccnl_key`.", call. = FALSE)
  }
  grp <- .check_grouping(dt, by = by, periodo = periodo, riservate = dim_cols)
  by <- grp$by
  periodo <- grp$periodo
  grp <- c(by, periodo)
  richieste_mancanti <- setdiff(.ranking_required[[measure]], names(dt))
  if (length(richieste_mancanti) > 0L) {
    stop(
      "La misura `",
      measure,
      "` richiede le colonne: ",
      paste(richieste_mancanti, collapse = ", "),
      ". Applicare prepare_rapporti() o compute_giornate_effettive().",
      call. = FALSE
    )
  }
  if (!is.numeric(min_n) || length(min_n) != 1L || is.na(min_n) || min_n < 0) {
    stop("`min_n` deve essere un numero non negativo.", call. = FALSE)
  }
  if (!is.null(ccnl)) {
    if (!is.character(ccnl) && !all(is.na(ccnl))) {
      stop("`ccnl` deve essere NULL o un vettore character.", call. = FALSE)
    }
    ccnl <- unique(as.character(ccnl))
    sconosciute <- ccnl[!ccnl %in% unique(dt[["ccnl_key"]])]
    if (length(sconosciute) > 0L) {
      warning(
        "Chiavi `ccnl` assenti da `dt`: ",
        paste(sconosciute, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
  }

  # 3.2 Celle e totali (su tutte le righe) -----
  cell_cols <- c(grp, "ccnl_key", dim_cols)
  work <- .work_misure(dt, cell_cols, measure)
  celle <- .aggregate_misure(work, cell_cols, measure)
  tot_ccnl <- .aggregate_misure(work, c(grp, "ccnl_key"), measure)
  data.table::setnames(tot_ccnl, measure, "totale_ccnl")
  tot_dim <- .aggregate_misure(work, c(grp, dim_cols), measure)
  data.table::setnames(tot_dim, measure, "totale_dim")
  tot <- .aggregate_misure(work, grp, measure)
  data.table::setnames(tot, measure, "totale")
  celle[tot_ccnl, on = c(grp, "ccnl_key"), totale_ccnl := i.totale_ccnl]
  celle[tot_dim, on = c(grp, dim_cols), totale_dim := i.totale_dim]
  if (length(grp) == 0L) {
    data.table::set(celle, j = "totale", value = tot[["totale"]])
  } else {
    celle[tot, on = grp, totale := i.totale]
  }

  # 3.3 Quote e quoziente di localizzazione -----
  valore <- celle[[measure]]
  data.table::set(
    celle,
    j = "quota_riga",
    value = .ratio(valore, celle[["totale_ccnl"]])
  )
  data.table::set(
    celle,
    j = "quota_colonna",
    value = .ratio(valore, celle[["totale_dim"]])
  )
  data.table::set(
    celle,
    j = "lq",
    value = .ratio(
      celle[["quota_colonna"]],
      .ratio(celle[["totale_ccnl"]], celle[["totale"]])
    )
  )
  mascherate <- which(celle[["totale_dim"]] < min_n)
  if (length(mascherate) > 0L) {
    data.table::set(celle, i = mascherate, j = "lq", value = NA_real_)
  }
  data.table::set(
    celle,
    j = "classe",
    value = data.table::fifelse(
      is.na(celle[["ccnl_key"]]),
      .classe_non_classificati,
      .classe_ccnl
    )
  )

  # 3.4 Filtro sulle chiavi, ordinamento e uscita -----
  if (!is.null(ccnl)) {
    celle <- celle[ccnl_key %in% ccnl]
  }
  celle[, c("totale_ccnl", "totale_dim", "totale") := NULL]
  data.table::setcolorder(
    celle,
    c(
      grp,
      "ccnl_key",
      "classe",
      dim_cols,
      measure,
      "quota_riga",
      "quota_colonna",
      "lq"
    )
  )
  data.table::setorderv(
    celle,
    c(grp, "ccnl_key", measure, dim_cols),
    order = c(rep(1L, length(grp) + 1L), -1L, rep(1L, length(dim_cols))),
    na.last = TRUE
  )
  data.table::setattr(
    celle,
    "ccnlcob_crosstab",
    list(
      measure = measure,
      dims = dim_cols,
      by = by,
      periodo = periodo,
      min_n = min_n
    )
  )
  celle[]
}

# 4. Helper di controllo -----

#' Verifica una singola misura
#'
#' @param measure Oggetto passato come `measure`.
#' @return `measure` (character di lunghezza 1); errore altrimenti.
#' @keywords internal
#' @noRd
.check_measure <- function(measure) {
  if (!is.character(measure) || length(measure) != 1L || is.na(measure)) {
    stop("`measure` deve essere una singola stringa.", call. = FALSE)
  }
  if (!measure %in% .ranking_measures) {
    stop(
      "Misura non ammessa: ",
      measure,
      ". Misure disponibili: ",
      paste(.ranking_measures, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  measure
}

#' Verifica le colonne di raggruppamento `by` e `periodo`
#'
#' Applica le stesse regole di [rank_ccnl()]: `by` character presente in
#' `dt` e senza `ccnl_key`; `periodo` `NULL`, `"anno"` o `"trimestre"`,
#' presente in `dt` e non contenuto in `by`.
#'
#' @param dt Un `data.frame`.
#' @param by `NULL` o vettore character.
#' @param periodo `NULL` o stringa.
#' @param riservate Colonne che `by` e `periodo` non possono contenere.
#' @return Lista con `by` (character, eventualmente vuoto) e `periodo`.
#' @keywords internal
#' @noRd
.check_grouping <- function(dt, by, periodo, riservate = character(0)) {
  if (!is.null(by)) {
    if (!is.character(by) || anyNA(by)) {
      stop("`by` deve essere NULL o un vettore character.", call. = FALSE)
    }
    by <- unique(by)
    by_mancanti <- setdiff(by, names(dt))
    if (length(by_mancanti) > 0L) {
      stop(
        "Colonne di `by` assenti da `dt`: ",
        paste(by_mancanti, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    if ("ccnl_key" %in% by) {
      stop("`by` non pu\u00f2 contenere `ccnl_key`.", call. = FALSE)
    }
    in_riservate <- intersect(by, riservate)
    if (length(in_riservate) > 0L) {
      stop(
        "`by` non pu\u00f2 contenere le dimensioni: ",
        paste(in_riservate, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
  }
  if (!is.null(periodo)) {
    if (
      !is.character(periodo) ||
        length(periodo) != 1L ||
        !periodo %in% c("anno", "trimestre")
    ) {
      stop(
        "`periodo` deve essere NULL, \"anno\" o \"trimestre\".",
        call. = FALSE
      )
    }
    if (!periodo %in% names(dt)) {
      stop(
        "Colonna `",
        periodo,
        "` assente da `dt`. ",
        "Applicare prima prepare_rapporti().",
        call. = FALSE
      )
    }
    if (periodo %in% c(by, riservate)) {
      stop(
        "`periodo` non pu\u00f2 comparire anche in `by` o fra le dimensioni.",
        call. = FALSE
      )
    }
  }
  list(by = by, periodo = periodo)
}

#' Rapporto fra vettori con denominatore nullo o mancante mappato a NA
#'
#' @param num Vettore numerico.
#' @param den Vettore numerico della stessa lunghezza (o di lunghezza 1).
#' @return Vettore numeric; `NA` dove `den` è `NA`, non finito o zero.
#' @keywords internal
#' @noRd
.ratio <- function(num, den) {
  out <- as.numeric(num) / as.numeric(den)
  out[!is.finite(den) | den == 0] <- NA_real_
  out
}
