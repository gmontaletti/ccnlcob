# 1. Orchestrazione -----

utils::globalVariables(c("quota_troncata", "copertura_ore", "copertura_cpi"))

#' Esegue l'analisi completa dei CCNL su un dataset di rapporti
#'
#' Orchestra, su una copia di `dt`, l'intera catena del pacchetto:
#' [prepare_rapporti()], [compute_giornate_effettive()], [add_cpi()],
#' [rank_ccnl()], [select_ccnl_rilevanti()], [ccnl_by_cpi()],
#' [ccnl_by_tipologia()], [clean_retribuzione()], [normalize_fte()],
#' [median_retribuzione()] e [deflate_retribuzione()]. Restituisce un
#' oggetto di classe `ccnlcob_result` con le tabelle precomputate per
#' dashboard e report, da serializzare con [write_results()]. I blocchi
#' facoltativi (giornate effettive, CPI, retribuzioni, deflazione) vengono
#' saltati, con motivazione registrata in `meta$passi_saltati`, quando le
#' colonne o le risorse necessarie non sono disponibili; un input non valido
#' produce invece un errore.
#'
#' @param dt Un `data.table` di rapporti conforme a [validate_rapporti()].
#'   Non viene modificato.
#' @inheritParams prepare_rapporti
#' @param measure Misura di rilevanza usata per selezionare i CCNL e per la
#'   distribuzione per CPI: una fra `"n_rapporti"`, `"n_lavoratori"`,
#'   `"n_datori"`, `"giornate"` (default), `"giornate_effettive"`,
#'   `"stock"`.
#' @param top_n Numero massimo di CCNL rilevanti; vedi
#'   [select_ccnl_rilevanti()].
#' @param cum_share Soglia di quota cumulata per la selezione dei CCNL
#'   rilevanti; vedi [select_ccnl_rilevanti()].
#' @param geo Geografia per il CPI (`"sede_lavoro"` o `"residenza"`); vedi
#'   [add_cpi()].
#' @param lookup_cpi Lookup esplicito comune -> CPI (colonne `belfiore`,
#'   `cpi_code`, `cpi_name`) passato ad [add_cpi()]; `NULL` usa `longworkR`
#'   se installato e se i file di mapping in `SHARED_DATA_DIR` sono
#'   presenti, altrimenti il blocco CPI viene saltato.
#' @param periodo Periodo di avviamento per le serie temporali (`"anno"` o
#'   `"trimestre"`).
#' @param indice `data.table` opzionale con la colonna di periodo (chiamata
#'   come `periodo` oppure `periodo`) e la colonna `indice` per la
#'   deflazione delle retribuzioni; `NULL` per omettere i valori reali.
#' @param base Periodo base per la deflazione; `NULL` usa l'ultimo periodo
#'   presente. Vedi [deflate_retribuzione()].
#' @param effettive Se `TRUE` (default) calcola `giornate_effettive` e la
#'   include fra le misure del ranking.
#' @param min_n Numerosità minima sotto la quale i quozienti di
#'   localizzazione e i quantili di retribuzione vengono mascherati.
#' @param quiet Se `TRUE` (default) sopprime i `message()` dei passi
#'   intermedi.
#'
#' @details
#' Componenti del risultato:
#' - `meta`: lista con `versione`, `as_of`, `window`, `perimetro`,
#'   `ccnl_key`, `chiavi_non_classificate`, `measure`, `n_input`,
#'   `n_finestra`, `n_rapporti`,
#'   `n_lavoratori`, `copertura_ccnl`, `copertura_retribuzione`, `passi`
#'   (passi eseguiti), `passi_saltati` (vettore nominato passo -> motivo),
#'   `preparazione` (attributo `ccnlcob_meta` di [prepare_rapporti()]) e
#'   `tempi` (secondi per passo);
#' - `ranking` e `ranking_periodo`: output di [rank_ccnl()] sull'intera
#'   finestra e per `periodo`, con le misure `n_rapporti`, `n_lavoratori`,
#'   `n_datori` (se `datore` è presente), `giornate`, `giornate_effettive`
#'   (se calcolate) e `stock`;
#' - `rilevanti`: tabella di [select_ccnl_rilevanti()] con il residuo
#'   "Altri CCNL"; `keys`: le chiavi selezionate;
#' - `cpi`: output di [ccnl_by_cpi()] sui CCNL rilevanti (`NULL` se
#'   saltato);
#' - `tipologie`: output di [ccnl_by_tipologia()] (macro-tipologia per
#'   orario, misura `n_rapporti`) sui CCNL rilevanti;
#' - `retribuzioni`: output di [median_retribuzione()] sui CCNL rilevanti,
#'   con le colonne `_reale` se `indice` è fornito (`NULL` se la colonna
#'   `retribuzione` manca);
#' - `qualita`: per `ccnl_key` (inclusi i non classificati) `n` righe,
#'   `n_rapporti` avviati, `quota_troncata`, `copertura_retribuzione`,
#'   `copertura_ore` (part-time con ore valide), `copertura_cpi` (righe con
#'   CPI lombardo); `NA` dove il blocco non è stato calcolato.
#'
#' @return Una lista di classe `ccnlcob_result` con gli elementi elencati nei
#'   Dettagli.
#' @family orchestrazione
#' @seealso [write_results()] per la serializzazione.
#' @export
#' @examples
#' res <- analyze_ccnl(
#'   cob_esempio,
#'   window = as.Date(c("2022-01-01", "2024-12-31")),
#'   lookup_cpi = cpi_esempio,
#'   top_n = 10,
#'   min_n = 10
#' )
#' res
#' res$rilevanti[, .(ccnl_key, classe, giornate, quota_giornate)]
#' res$qualita
analyze_ccnl <- function(
  dt,
  as_of = NULL,
  window = NULL,
  perimetro = c("ccnl", "standard", "completo"),
  ccnl_key = c("codice_cnel", "ccnl_warehouse"),
  chiavi_non_classificate = "CPUB",
  measure = "giornate",
  top_n = 20,
  cum_share = 0.8,
  geo = c("sede_lavoro", "residenza"),
  lookup_cpi = NULL,
  periodo = c("anno", "trimestre"),
  indice = NULL,
  base = NULL,
  effettive = TRUE,
  min_n = 30L,
  tipologie = ccnlcob::tipologie_contrattuali,
  quiet = TRUE
) {
  # 1.1 Controlli -----
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare analyze_ccnl().",
      call. = FALSE
    )
  }
  perimetro <- match.arg(perimetro)
  ccnl_key <- match.arg(ccnl_key, several.ok = TRUE)
  chiavi_non_classificate <- .check_chiavi_non_classificate(
    chiavi_non_classificate,
    caller = "analyze_ccnl"
  )
  geo <- match.arg(geo)
  periodo <- match.arg(periodo)
  measure <- .check_measure(measure)
  for (flag in c("effettive", "quiet")) {
    valore <- get(flag)
    if (!is.logical(valore) || length(valore) != 1L || is.na(valore)) {
      stop("`", flag, "` deve essere TRUE o FALSE.", call. = FALSE)
    }
  }
  if (measure == "giornate_effettive" && !effettive) {
    stop(
      "`measure = \"giornate_effettive\"` richiede `effettive = TRUE`.",
      call. = FALSE
    )
  }
  if (!is.numeric(min_n) || length(min_n) != 1L || is.na(min_n) || min_n < 0) {
    stop("`min_n` deve essere un numero non negativo.", call. = FALSE)
  }
  if (!is.null(lookup_cpi)) {
    .check_cpi_lookup(lookup_cpi)
  }
  if (!is.null(indice) && !is.data.frame(indice)) {
    stop(
      "`indice` deve essere NULL o un data.table con le colonne di periodo ",
      "e `indice`.",
      call. = FALSE
    )
  }
  .check_selezione(top_n, cum_share)

  passi <- character(0)
  saltati <- character(0)
  tempi <- numeric(0)
  esegui <- function(nome, expr) {
    t0 <- proc.time()[["elapsed"]]
    out <- if (quiet) suppressMessages(expr) else expr
    tempi[[nome]] <<- proc.time()[["elapsed"]] - t0
    passi <<- c(passi, nome)
    out
  }
  salta <- function(nome, motivo) {
    saltati[[nome]] <<- motivo
    invisible(NULL)
  }

  # 1.2 Preparazione e giornate -----
  prep <- esegui(
    "prepare_rapporti",
    prepare_rapporti(
      dt,
      as_of = as_of,
      window = window,
      ccnl_key = ccnl_key,
      chiavi_non_classificate = chiavi_non_classificate,
      perimetro = perimetro,
      tipologie = tipologie
    )
  )
  meta_prep <- attr(prep, "ccnlcob_meta")
  as_of <- meta_prep$as_of
  window <- meta_prep$window

  if (effettive) {
    esegui(
      "compute_giornate_effettive",
      compute_giornate_effettive(prep, window = window)
    )
  } else {
    salta("compute_giornate_effettive", "disattivato (`effettive = FALSE`)")
  }

  # 1.3 CPI -----
  geo_col <- .cpi_geo_cols[[geo]]
  ha_cpi <- FALSE
  if (!geo_col %in% names(prep)) {
    salta("add_cpi", paste0("colonna `", geo_col, "` assente"))
  } else if (!is.null(lookup_cpi)) {
    esegui("add_cpi", add_cpi(prep, geo = geo, lookup = lookup_cpi))
    ha_cpi <- TRUE
  } else if (!.cpi_longworkR_disponibile()) {
    salta(
      "add_cpi",
      "nessun `lookup_cpi` e mapping di longworkR non disponibile"
    )
  } else {
    esito <- tryCatch(
      {
        esegui("add_cpi", add_cpi(prep, geo = geo, lookup = NULL, quiet = TRUE))
        TRUE
      },
      error = function(e) conditionMessage(e)
    )
    if (isTRUE(esito)) {
      ha_cpi <- TRUE
    } else {
      salta("add_cpi", paste0("errore in longworkR: ", esito))
    }
  }

  # 1.4 Ranking e selezione -----
  measures <- c(
    "n_rapporti",
    "n_lavoratori",
    if ("datore" %in% names(prep)) "n_datori",
    "giornate",
    if (effettive) "giornate_effettive",
    "stock"
  )
  ranking <- esegui("rank_ccnl", rank_ccnl(prep, measures = measures))
  ranking_periodo <- esegui(
    "rank_ccnl_periodo",
    rank_ccnl(prep, measures = measures, periodo = periodo)
  )
  rilevanti <- esegui(
    "select_ccnl_rilevanti",
    select_ccnl_rilevanti(
      ranking,
      measure = measure,
      top_n = top_n,
      cum_share = cum_share,
      return = "table"
    )
  )
  keys <- attr(rilevanti, "ccnlcob_selezione")$keys

  # 1.5 Distribuzioni -----
  cpi <- NULL
  if (ha_cpi) {
    cpi <- esegui(
      "ccnl_by_cpi",
      ccnl_by_cpi(prep, measure = measure, ccnl = keys, min_n = min_n)
    )
  } else {
    salta("ccnl_by_cpi", "CPI non disponibile")
  }
  tab_tipologie <- esegui(
    "ccnl_by_tipologia",
    ccnl_by_tipologia(
      prep,
      measure = "n_rapporti",
      ccnl = keys,
      level = "macro",
      min_n = min_n,
      tipologie = tipologie
    )
  )

  # 1.6 Retribuzioni -----
  retribuzioni <- NULL
  if ("retribuzione" %in% names(prep)) {
    esegui("clean_retribuzione", clean_retribuzione(prep))
    esegui("normalize_fte", normalize_fte(prep))
    retribuzioni <- esegui(
      "median_retribuzione",
      median_retribuzione(
        prep,
        periodo = periodo,
        ccnl = keys,
        min_n = min_n
      )
    )
    if (!is.null(indice)) {
      retribuzioni <- esegui(
        "deflate_retribuzione",
        deflate_retribuzione(
          retribuzioni,
          indice = indice,
          base = base,
          periodo_col = periodo
        )
      )
    } else {
      salta("deflate_retribuzione", "nessun `indice` fornito")
    }
  } else {
    salta("retribuzioni", "colonna `retribuzione` assente")
  }

  # 1.7 Qualita' e metadati -----
  qualita <- esegui("qualita", .tabella_qualita(prep))
  avviato <- prep[["avviato"]] %in% TRUE
  copertura_retribuzione <- if ("flag_retribuzione" %in% names(prep)) {
    mean(prep[["flag_retribuzione"]] == "valida")
  } else {
    NA_real_
  }
  meta <- list(
    versione = .versione_pacchetto(),
    as_of = as_of,
    window = window,
    perimetro = perimetro,
    ccnl_key = meta_prep$ccnl_key,
    chiavi_non_classificate = chiavi_non_classificate,
    measure = measure,
    top_n = top_n,
    cum_share = cum_share,
    geo = geo,
    periodo = periodo,
    n_input = as.integer(nrow(dt)),
    n_finestra = as.integer(nrow(prep)),
    n_rapporti = as.integer(sum(avviato)),
    n_lavoratori = as.integer(data.table::uniqueN(prep[["cf"]][avviato])),
    copertura_ccnl = if (nrow(prep) > 0L) {
      mean(!is.na(prep[["ccnl_key"]]))
    } else {
      NA_real_
    },
    copertura_retribuzione = copertura_retribuzione,
    keys = keys,
    passi = passi,
    passi_saltati = saltati,
    preparazione = meta_prep,
    tempi = tempi
  )

  structure(
    list(
      meta = meta,
      ranking = ranking,
      ranking_periodo = ranking_periodo,
      rilevanti = rilevanti,
      keys = keys,
      cpi = cpi,
      tipologie = tab_tipologie,
      retribuzioni = retribuzioni,
      qualita = qualita
    ),
    class = "ccnlcob_result"
  )
}

# 2. Metodo print -----

#' Stampa sintetica di un risultato ccnlcob_result
#'
#' Mostra versione, finestra, perimetro, numerosità, coperture, i primi
#' CCNL rilevanti con la loro quota e i passi saltati di un oggetto prodotto
#' da [analyze_ccnl()].
#'
#' @param x Oggetto di classe `ccnlcob_result`.
#' @param n Numero di CCNL rilevanti da elencare (default 5).
#' @param ... Ignorato; presente per coerenza con il generico [print()].
#'
#' @return `x`, restituito invisibilmente.
#' @family orchestrazione
#' @export
#' @examples
#' res <- analyze_ccnl(cob_esempio, lookup_cpi = cpi_esempio, min_n = 10)
#' print(res)
print.ccnlcob_result <- function(x, n = 5L, ...) {
  riga <- function(label, value) {
    cat(sprintf("  %-24s %s\n", paste0(label, ":"), value))
  }
  conta <- function(v) {
    if (is.null(v) || length(v) == 0L || is.na(v)) {
      return("NA")
    }
    format(v, big.mark = ".", decimal.mark = ",", scientific = FALSE)
  }
  pct <- function(v) {
    if (is.null(v) || length(v) == 0L || is.na(v)) {
      return("NA")
    }
    paste0(format(round(100 * v, 1), decimal.mark = ",", nsmall = 1), "%")
  }
  meta <- x[["meta"]]
  if (is.null(meta)) {
    meta <- list()
  }
  cat("<ccnlcob_result>\n")
  riga("versione", if (is.null(meta$versione)) "NA" else meta$versione)
  if (!is.null(meta$as_of)) {
    riga("as_of", format(meta$as_of))
  }
  if (!is.null(meta$window)) {
    riga("window", paste(format(meta$window), collapse = " / "))
  }
  if (!is.null(meta$perimetro)) {
    riga("perimetro", meta$perimetro)
  }
  if (!is.null(meta$ccnl_key)) {
    riga("ccnl_key", meta$ccnl_key)
  }
  riga(
    "rapporti",
    paste0(
      "input ",
      conta(meta$n_input),
      ", in finestra ",
      conta(meta$n_finestra),
      ", avviati ",
      conta(meta$n_rapporti)
    )
  )
  riga("lavoratori avviati", conta(meta$n_lavoratori))
  riga("copertura codice CCNL", pct(meta$copertura_ccnl))
  riga("copertura retribuzione", pct(meta$copertura_retribuzione))

  keys <- x[["keys"]]
  rilevanti <- x[["rilevanti"]]
  measure <- meta$measure
  if (!is.null(keys) && !is.null(measure)) {
    riga(
      "CCNL rilevanti",
      paste0(length(keys), " (misura: ", measure, ")")
    )
    qcol <- paste0("quota_", measure)
    if (is.data.frame(rilevanti) && qcol %in% names(rilevanti)) {
      sel <- rilevanti[["selezionato"]] %in% TRUE
      top <- rilevanti[sel, c("ccnl_key", qcol), with = FALSE]
      top <- top[seq_len(min(n, nrow(top)))]
      if (nrow(top) > 0L) {
        cat("  primi CCNL:\n")
        for (i in seq_len(nrow(top))) {
          cat(sprintf(
            "    %2d. %-8s %s\n",
            i,
            top[["ccnl_key"]][i],
            pct(top[[qcol]][i])
          ))
        }
      }
    }
  }
  saltati <- meta$passi_saltati
  if (length(saltati) > 0L) {
    cat("  passi saltati:\n")
    for (nm in names(saltati)) {
      cat("    - ", nm, ": ", saltati[[nm]], "\n", sep = "")
    }
  }
  invisible(x)
}

# 3. Helper interni -----

#' Tabella di qualità per CCNL
#'
#' @param prep `data.table` preparato, con le colonne eventualmente
#'   aggiunte dai passi facoltativi (`flag_retribuzione`, `cpi_code`).
#' @return `data.table` con una riga per `ccnl_key` (inclusi `NA`).
#' @keywords internal
#' @noRd
.tabella_qualita <- function(prep) {
  nomi <- names(prep)
  ha_retribuzione <- "flag_retribuzione" %in% nomi
  ha_ore <- all(c("ore", "prior") %in% nomi)
  ha_cpi <- "cpi_code" %in% nomi
  cpi_fuori <- c(.cpi_fuori[["code"]], .cpi_nd[["code"]])
  out <- prep[,
    list(
      n = .N,
      n_rapporti = sum(avviato %in% TRUE),
      quota_troncata = if ("troncata" %in% nomi) {
        mean(troncata %in% 1L)
      } else {
        NA_real_
      },
      copertura_retribuzione = if (ha_retribuzione) {
        mean(flag_retribuzione == "valida")
      } else {
        NA_real_
      },
      copertura_ore = if (ha_ore) {
        pt <- prior %in% 0
        if (any(pt)) mean(!is.na(ore[pt]) & ore[pt] > 0) else NA_real_
      } else {
        NA_real_
      },
      copertura_cpi = if (ha_cpi) {
        mean(!is.na(cpi_code) & !cpi_code %in% cpi_fuori)
      } else {
        NA_real_
      }
    ),
    by = "ccnl_key"
  ]
  data.table::setorderv(out, "ccnl_key", na.last = TRUE)
  out[]
}

#' Verifica i parametri di selezione dei CCNL rilevanti
#'
#' @keywords internal
#' @noRd
.check_selezione <- function(top_n, cum_share) {
  if (!is.null(top_n)) {
    if (
      !is.numeric(top_n) ||
        length(top_n) != 1L ||
        is.na(top_n) ||
        top_n < 1 ||
        top_n != round(top_n)
    ) {
      stop("`top_n` deve essere NULL o un intero positivo.", call. = FALSE)
    }
  }
  if (!is.null(cum_share)) {
    if (
      !is.numeric(cum_share) ||
        length(cum_share) != 1L ||
        is.na(cum_share) ||
        cum_share <= 0 ||
        cum_share > 1
    ) {
      stop("`cum_share` deve essere NULL o un numero in (0, 1].", call. = FALSE)
    }
  }
  if (is.null(top_n) && is.null(cum_share)) {
    stop("Fornire almeno uno fra `top_n` e `cum_share`.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Disponibilità del mapping CPI di longworkR
#'
#' `TRUE` se `longworkR` è installato e i file di mapping attesi da
#' `longworkR::add_cpi_via_belfiore()` esistono in `SHARED_DATA_DIR`.
#'
#' @keywords internal
#' @noRd
.cpi_longworkR_disponibile <- function() {
  if (!requireNamespace("longworkR", quietly = TRUE)) {
    return(FALSE)
  }
  dir <- path.expand(Sys.getenv(
    "SHARED_DATA_DIR",
    unset = "~/Documents/funzioni/shared_data"
  ))
  files <- file.path(
    dir,
    c("maps/belfiore_istat_mapping.csv", "maps/comune_cpi_lookup.rds")
  )
  all(file.exists(files))
}

#' Versione del pacchetto
#'
#' @keywords internal
#' @noRd
.versione_pacchetto <- function() {
  v <- tryCatch(
    as.character(utils::packageVersion("ccnlcob")),
    error = function(e) NA_character_
  )
  v
}
