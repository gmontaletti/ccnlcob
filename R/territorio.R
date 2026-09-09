# 1. Costanti -----

#' Codice e nome del CPI residuo per i comuni fuori Lombardia
#'
#' Assegnati da [add_cpi()] ai codici Belfiore validi ma assenti dal lookup
#' comune -> CPI (tipicamente comuni fuori regione). Vettore character con
#' elementi `code` e `name`.
#' @keywords internal
#' @noRd
.cpi_fuori <- c(code = "FUORI", name = "Fuori Lombardia")

#' Codice e nome del CPI residuo per i comuni non disponibili
#'
#' Assegnati da [add_cpi()] ai rapporti con codice Belfiore mancante (`NA`).
#' Vettore character con elementi `code` e `name`.
#' @keywords internal
#' @noRd
.cpi_nd <- c(code = "ND", name = "Non disponibile")

# Colonna sorgente del codice Belfiore per ciascuna geografia.
.cpi_geo_cols <- c(
  sede_lavoro = "comune_sede_lavoro",
  residenza = "comune_lavoratore"
)

# 2. Mapping comune -> CPI -----

#' Aggiunge il CPI (Centro per l'Impiego) ai rapporti di lavoro
#'
#' Associa a ciascun rapporto il codice e il nome del CPI a partire dal
#' codice Belfiore della sede di lavoro (`comune_sede_lavoro`) o della
#' residenza del lavoratore (`comune_lavoratore`). Il mapping è fornito da un
#' `lookup` esplicito oppure, in sua assenza, dalle utilità geografiche di
#' `longworkR` (`longworkR::add_cpi_via_belfiore()`), che il pacchetto non
#' reimplementa. Le colonne sono aggiunte a `dt` per riferimento.
#'
#' @param dt Un `data.table` di rapporti con la colonna geografica richiesta
#'   da `geo`. Viene modificato per riferimento.
#' @param geo Geografia di riferimento: `"sede_lavoro"` (default, colonna
#'   `comune_sede_lavoro`) o `"residenza"` (colonna `comune_lavoratore`).
#' @param lookup `data.table` o `data.frame` opzionale con le colonne
#'   `belfiore` (codice Belfiore del comune, univoco), `cpi_code` e,
#'   facoltativa, `cpi_name` (se assente viene riempita con `cpi_code`).
#'   `NULL` (default) usa `longworkR`, che deve essere installato e deve
#'   trovare i file di mapping in `SHARED_DATA_DIR/maps`. Vedi
#'   [cpi_esempio] per un lookup di esempio.
#' @param quiet Se `TRUE` (default) l'output a console di `longworkR` viene
#'   soppresso; ignorato con un `lookup` esplicito.
#'
#' @details
#' Con `lookup = NULL` il mapping viene costruito una sola volta sui codici
#' Belfiore distinti e non mancanti della colonna sorgente, non sull'intera
#' tabella, e poi agganciato ai rapporti. Il join è un aggiornamento per
#' riferimento: il numero e l'ordine delle righe di `dt` non cambiano.
#'
#' Convenzioni sui residui, così che ogni rapporto resti visibile nelle
#' distribuzioni territoriali:
#' - codice Belfiore presente ma assente dal lookup (tipicamente comune
#'   fuori Lombardia): `cpi_code = "FUORI"`, `cpi_name = "Fuori Lombardia"`;
#' - codice Belfiore mancante (`NA`): `cpi_code = "ND"`,
#'   `cpi_name = "Non disponibile"`.
#'
#' Colonne `cpi_code` e `cpi_name` già presenti in `dt` vengono sovrascritte.
#'
#' @return `dt`, restituito invisibilmente, con le colonne character
#'   `cpi_code` e `cpi_name` aggiunte o sovrascritte per riferimento.
#'   L'attributo `ccnlcob_cpi` è una lista con `geo` e `source`
#'   (`"lookup"` oppure `"longworkR"`).
#' @family territorio
#' @seealso [ccnl_by_cpi()] per la distribuzione dei CCNL per CPI;
#'   [cpi_esempio] per il lookup dei comuni di [cob_esempio].
#' @export
#' @examples
#' library(data.table)
#' dt <- prepare_rapporti(cob_esempio)
#' add_cpi(dt, geo = "sede_lavoro", lookup = cpi_esempio)
#' dt[, .N, by = .(cpi_code, cpi_name)][order(-N)]
#' attr(dt, "ccnlcob_cpi")
#'
#' # CPI di residenza del lavoratore
#' add_cpi(dt, geo = "residenza", lookup = cpi_esempio)
#' dt[, .N, by = cpi_name][order(-N)][1:5]
add_cpi <- function(
  dt,
  geo = c("sede_lavoro", "residenza"),
  lookup = NULL,
  quiet = TRUE
) {
  # 2.1 Controlli -----
  geo <- match.arg(geo)
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare add_cpi().",
      call. = FALSE
    )
  }
  src_col <- .cpi_geo_cols[[geo]]
  if (!src_col %in% names(dt)) {
    stop(
      "Colonna `",
      src_col,
      "` assente da `dt`: richiesta da add_cpi() con geo = \"",
      geo,
      "\".",
      call. = FALSE
    )
  }
  if (!is.logical(quiet) || length(quiet) != 1L || is.na(quiet)) {
    stop("`quiet` deve essere TRUE o FALSE.", call. = FALSE)
  }
  codici <- as.character(dt[[src_col]])

  # 2.2 Lookup -----
  if (is.null(lookup)) {
    source <- "longworkR"
    lookup <- .cpi_lookup_longworkR(unique(codici[!is.na(codici)]), quiet)
  } else {
    source <- "lookup"
    lookup <- .check_cpi_lookup(lookup)
  }

  # 2.3 Join per riferimento e residui -----
  data.table::set(dt, j = "cpi_code", value = rep(NA_character_, nrow(dt)))
  data.table::set(dt, j = "cpi_name", value = rep(NA_character_, nrow(dt)))
  if (nrow(lookup) > 0L && nrow(dt) > 0L) {
    join_on <- "belfiore"
    names(join_on) <- src_col
    dt[
      lookup,
      on = join_on,
      c("cpi_code", "cpi_name") := list(i.cpi_code, i.cpi_name)
    ]
  }
  fuori <- which(!is.na(codici) & is.na(dt[["cpi_code"]]))
  if (length(fuori) > 0L) {
    data.table::set(dt, i = fuori, j = "cpi_code", value = .cpi_fuori[["code"]])
    data.table::set(dt, i = fuori, j = "cpi_name", value = .cpi_fuori[["name"]])
  }
  nd <- which(is.na(codici))
  if (length(nd) > 0L) {
    data.table::set(dt, i = nd, j = "cpi_code", value = .cpi_nd[["code"]])
    data.table::set(dt, i = nd, j = "cpi_name", value = .cpi_nd[["name"]])
  }
  data.table::setattr(dt, "ccnlcob_cpi", list(geo = geo, source = source))
  invisible(dt)
}

# 3. Distribuzione territoriale -----

#' Distribuisce i CCNL per CPI
#'
#' Calcola la tabella `ccnl_key` x CPI con il valore della misura scelta, la
#' quota di riga (entro CCNL), la quota di colonna (entro CPI) e il
#' quoziente di localizzazione, eventualmente per gruppo (`by`) e per coorte
#' di avviamento (`periodo`).
#'
#' @param dt Un `data.table` di rapporti già passato da [prepare_rapporti()]
#'   (colonne `ccnl_key`, `giornate`, `avviato`, `attivo`, `anno`,
#'   `trimestre`). Se contiene già `cpi_code` (ed eventualmente `cpi_name`)
#'   la colonna viene usata così com'è e `geo`, `lookup` sono ignorati;
#'   altrimenti il CPI viene calcolato con [add_cpi()] su una copia delle
#'   colonne necessarie. `dt` non viene modificato.
#' @param measure Misura da distribuire, una fra `"giornate"` (default),
#'   `"giornate_effettive"`, `"n_rapporti"`, `"n_lavoratori"`, `"n_datori"`,
#'   `"stock"`, con le definizioni di [rank_ccnl()].
#' @param ccnl `NULL` (default) per tutte le chiavi, altrimenti vettore
#'   character delle `ccnl_key` da conservare in uscita; `NA` conserva i non
#'   classificati. Le chiavi assenti da `dt` producono un avviso. Il filtro
#'   agisce dopo il calcolo dei totali (vedi Dettagli).
#' @param geo Geografia usata da [add_cpi()]: `"sede_lavoro"` (default) o
#'   `"residenza"`. Riportata nell'attributo del risultato.
#' @param lookup Lookup comune -> CPI passato ad [add_cpi()]; `NULL` usa
#'   `longworkR`.
#' @param periodo Colonna temporale (`"anno"` o `"trimestre"`) per una
#'   distribuzione per coorte di avviamento; `NULL` per l'intera finestra.
#' @param by Vettore character con colonne aggiuntive di raggruppamento
#'   (es. `"macro_tipologia"`); `NULL` per il solo CCNL.
#' @param min_n Soglia sul totale del CPI (per gruppo) sotto la quale il
#'   quoziente di localizzazione è mascherato con `NA`.
#'
#' @details
#' Per ogni gruppo `g` (combinazione di `by` e `periodo`), CCNL `c` e CPI
#' `d`, detto `v` il valore della misura nella cella e `T` il totale del
#' gruppo:
#' - `quota_riga = v[c,d] / T[c]`: distribuzione territoriale del CCNL,
#'   somma a 1 entro ogni (`g`, `ccnl_key`);
#' - `quota_colonna = v[c,d] / T[d]`: composizione contrattuale del CPI,
#'   somma a 1 entro ogni (`g`, CPI);
#' - `lq = quota_colonna / (T[c] / T)`: quoziente di localizzazione; valori
#'   maggiori di 1 indicano concentrazione del CCNL nel CPI rispetto alla
#'   media del gruppo. Entro ogni CCNL la media di `lq` ponderata con
#'   `T[d] / T` è pari a 1.
#'
#' I totali `T[c]`, `T[d]` e `T` sono calcolati su tutte le righe di `dt`,
#' inclusi i rapporti con `ccnl_key` mancante (classe `"Non classificati"`,
#' conservata in uscita) e prima dell'eventuale filtro `ccnl`: le quote dei
#' CCNL conservati non cambiano filtrando. Le celle dei CPI con
#' `T[d] < min_n` hanno `lq = NA` ma non vengono eliminate. Se un totale è
#' zero le quote corrispondenti sono `NA`.
#'
#' I CPI seguono le convenzioni di [add_cpi()]: `"FUORI"` per i comuni fuori
#' Lombardia e `"ND"` per i codici mancanti. Per le misure di conteggio
#' distinto (`n_lavoratori`, `n_datori`) la somma delle celle di un CCNL può
#' superare il conteggio del CCNL in [rank_ccnl()], perché una persona può
#' comparire in più CPI.
#'
#' @return Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`,
#'   `cpi_code`) e le colonne: quelle di `by` e `periodo`, `ccnl_key`,
#'   `classe` (`"CCNL"` o `"Non classificati"`), `cpi_code`, `cpi_name`,
#'   `<measure>`, `quota_riga`, `quota_colonna`, `lq`; ordinato per gruppo,
#'   `ccnl_key` (non classificati in coda) e misura decrescente. L'attributo
#'   `ccnlcob_crosstab` riporta `measure`, `dims`, `by`, `periodo`, `min_n`
#'   e `geo`; se `cpi_code` era già presente, `geo` è quello registrato da
#'   [add_cpi()] nell'attributo `ccnlcob_cpi` di `dt` (`NA` se assente).
#'   L'input non viene modificato.
#' @family territorio
#' @seealso [add_cpi()], [rank_ccnl()], [ccnl_by_tipologia()].
#' @export
#' @examples
#' dt <- prepare_rapporti(cob_esempio)
#' cpi <- ccnl_by_cpi(dt, measure = "giornate", lookup = cpi_esempio)
#' cpi[ccnl_key == "A011"]
#'
#' # Concentrazioni territoriali più marcate (lq è NA sotto min_n giornate)
#' cpi[order(-lq)][1:5]
#'
#' # Rapporti avviati per CPI di residenza, solo due CCNL, per anno
#' ccnl_by_cpi(
#'   dt,
#'   measure = "n_rapporti", ccnl = c("A011", "H011"),
#'   geo = "residenza", lookup = cpi_esempio, periodo = "anno"
#' )[anno == 2024L]
ccnl_by_cpi <- function(
  dt,
  measure = "giornate",
  ccnl = NULL,
  geo = c("sede_lavoro", "residenza"),
  lookup = NULL,
  periodo = NULL,
  by = NULL,
  min_n = 30L
) {
  # 3.1 Controlli e proiezione -----
  geo <- match.arg(geo)
  if (!is.data.frame(dt)) {
    stop("`dt` deve essere un data.table di rapporti.", call. = FALSE)
  }
  measure <- .check_measure(measure)
  base_cols <- c(
    by,
    periodo,
    "ccnl_key",
    "giornate",
    .ranking_required[[measure]],
    "avviato",
    "attivo"
  )
  ha_cpi <- "cpi_code" %in% names(dt)
  if (ha_cpi) {
    cpi_attr <- attr(dt, "ccnlcob_cpi")
    geo <- if (is.list(cpi_attr) && is.character(cpi_attr$geo)) {
      cpi_attr$geo
    } else {
      NA_character_
    }
    extra_cols <- c("cpi_code", "cpi_name")
  } else {
    extra_cols <- .cpi_geo_cols[[geo]]
  }
  cols <- unique(c(base_cols, extra_cols))
  work <- .project_cols(dt, intersect(cols, names(dt)))

  # 3.2 CPI -----
  if (ha_cpi) {
    cpi_code <- as.character(work[["cpi_code"]])
    cpi_name <- if ("cpi_name" %in% names(work)) {
      as.character(work[["cpi_name"]])
    } else {
      cpi_code
    }
    nd <- is.na(cpi_code)
    cpi_code[nd] <- .cpi_nd[["code"]]
    cpi_name[nd] <- .cpi_nd[["name"]]
    cpi_name[is.na(cpi_name)] <- cpi_code[is.na(cpi_name)]
    data.table::set(work, j = "cpi_code", value = cpi_code)
    data.table::set(work, j = "cpi_name", value = cpi_name)
  } else {
    add_cpi(work, geo = geo, lookup = lookup, quiet = TRUE)
  }

  # 3.3 Tabella incrociata -----
  out <- .crosstab_ccnl(
    work,
    dim_cols = c("cpi_code", "cpi_name"),
    measure = measure,
    by = by,
    periodo = periodo,
    ccnl = ccnl,
    min_n = min_n
  )
  meta <- attr(out, "ccnlcob_crosstab")
  meta$geo <- geo
  data.table::setattr(out, "ccnlcob_crosstab", meta)
  out[]
}

# 4. Helper interni -----

#' Verifica e normalizza un lookup comune -> CPI
#'
#' @param lookup Oggetto passato come `lookup` ad [add_cpi()].
#' @return Un `data.table` con le colonne character `belfiore`, `cpi_code`,
#'   `cpi_name`, senza codici Belfiore mancanti o duplicati.
#' @keywords internal
#' @noRd
.check_cpi_lookup <- function(lookup) {
  if (!is.data.frame(lookup)) {
    stop(
      "`lookup` deve essere un data.table con le colonne `belfiore`, ",
      "`cpi_code` e (facoltativa) `cpi_name`.",
      call. = FALSE
    )
  }
  mancanti <- setdiff(c("belfiore", "cpi_code"), names(lookup))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti in `lookup`: ",
      paste(mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  out <- data.table::data.table(
    belfiore = as.character(lookup[["belfiore"]]),
    cpi_code = as.character(lookup[["cpi_code"]])
  )
  if ("cpi_name" %in% names(lookup)) {
    data.table::set(
      out,
      j = "cpi_name",
      value = as.character(lookup[["cpi_name"]])
    )
  } else {
    data.table::set(out, j = "cpi_name", value = out[["cpi_code"]])
  }
  out <- out[!is.na(belfiore)]
  if (anyDuplicated(out[["belfiore"]]) > 0L) {
    stop(
      "`lookup` contiene codici `belfiore` duplicati: ",
      paste(
        unique(out[["belfiore"]][duplicated(out[["belfiore"]])]),
        collapse = ", "
      ),
      ".",
      call. = FALSE
    )
  }
  out
}

#' Costruisce il lookup comune -> CPI con longworkR
#'
#' Risolve i codici Belfiore distinti con
#' `longworkR::add_cpi_via_belfiore()` e conserva solo quelli con un CPI;
#' i codici non risolti restano fuori dal lookup e ricevono il residuo
#' `FUORI` in [add_cpi()].
#'
#' @param codici Vettore character di codici Belfiore distinti, senza `NA`.
#' @param quiet Se `TRUE` sopprime l'output a console di `longworkR`.
#' @return Un `data.table` con le colonne `belfiore`, `cpi_code`,
#'   `cpi_name`.
#' @keywords internal
#' @noRd
.cpi_lookup_longworkR <- function(codici, quiet = TRUE) {
  if (!requireNamespace("longworkR", quietly = TRUE)) {
    stop(
      "Il pacchetto `longworkR` non \u00e8 installato: installarlo oppure ",
      "passare un `lookup` esplicito ad add_cpi().",
      call. = FALSE
    )
  }
  vuoto <- data.table::data.table(
    belfiore = character(0),
    cpi_code = character(0),
    cpi_name = character(0)
  )
  if (length(codici) == 0L) {
    return(vuoto)
  }
  tmp <- data.table::data.table(belfiore = codici)
  if (quiet) {
    utils::capture.output(
      risolto <- longworkR::add_cpi_via_belfiore(
        tmp,
        belfiore_col = "belfiore",
        add_name = TRUE
      )
    )
  } else {
    risolto <- longworkR::add_cpi_via_belfiore(
      tmp,
      belfiore_col = "belfiore",
      add_name = TRUE
    )
  }
  data.table::setDT(risolto)
  if (!"cpi_name" %in% names(risolto)) {
    data.table::set(risolto, j = "cpi_name", value = risolto[["cpi_code"]])
  }
  out <- risolto[
    !is.na(cpi_code),
    list(
      belfiore = as.character(belfiore),
      cpi_code = as.character(cpi_code),
      cpi_name = as.character(cpi_name)
    )
  ]
  unique(out, by = "belfiore")
}
