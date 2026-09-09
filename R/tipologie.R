# 1. Costanti -----

# Etichette residue delle dimensioni di ccnl_by_tipologia().
.tipologia_non_classificata <- "Non classificata"
.tipologia_nd <- "ND"
.orario_nd <- "ND"

# 2. Distribuzione per tipologia contrattuale -----

#' Distribuisce i CCNL per tipologia contrattuale
#'
#' Calcola la tabella `ccnl_key` x tipologia (x orario) con il valore della
#' misura scelta, la quota di riga (entro CCNL), la quota di colonna (entro
#' tipologia) e il quoziente di localizzazione, eventualmente per gruppo
#' (`by`) e per coorte di avviamento (`periodo`). La tipologia può essere la
#' macro-classe di [tipologie_contrattuali] o il codice MLPS di dettaglio.
#'
#' @param dt Un `data.table` di rapporti già passato da [prepare_rapporti()]
#'   (colonne `ccnl_key`, `giornate`, `avviato`, `attivo`, `anno`,
#'   `trimestre`, `macro_tipologia`, `orario`). Se `macro_tipologia` o
#'   `orario` mancano vengono ricalcolate su una copia da
#'   `cod_tipologia_contrattuale` (con [classify_tipologia()]) e da `prior`.
#'   `dt` non viene modificato.
#' @param measure Misura da distribuire, una fra `"n_rapporti"` (default),
#'   `"n_lavoratori"`, `"n_datori"`, `"giornate"`, `"giornate_effettive"`,
#'   `"stock"`, con le definizioni di [rank_ccnl()].
#' @param ccnl `NULL` (default) per tutte le chiavi, altrimenti vettore
#'   character delle `ccnl_key` da conservare in uscita; `NA` conserva i non
#'   classificati. Le chiavi assenti da `dt` producono un avviso. Il filtro
#'   agisce dopo il calcolo dei totali (vedi Dettagli).
#' @param level Livello della tipologia: `"macro"` (macro-classe di
#'   `tipologie`) o `"codice"` (codice MLPS `cod_tipologia_contrattuale`,
#'   con la descrizione `des_tipologia_contrattuale` letta da `tipologie`).
#' @param orario Se `TRUE` (default) la distribuzione è incrociata anche con
#'   l'orario (`"FT"`/`"PT"`); con `FALSE` la dimensione è omessa.
#' @param periodo Colonna temporale (`"anno"` o `"trimestre"`) per una
#'   distribuzione per coorte di avviamento; `NULL` per l'intera finestra.
#' @param by Vettore character con colonne aggiuntive di raggruppamento
#'   (es. `"sesso"`); `NULL` per il solo CCNL.
#' @param min_n Soglia sul totale della tipologia (per gruppo) sotto la
#'   quale il quoziente di localizzazione è mascherato con `NA`.
#' @param tipologie Lookup delle tipologie contrattuali con le colonne
#'   `cod_tipologia_contrattuale`, `macro_tipologia` e, per
#'   `level = "codice"`, `des_tipologia_contrattuale`; default
#'   [tipologie_contrattuali].
#'
#' @details
#' Per ogni gruppo `g` (combinazione di `by` e `periodo`), CCNL `c` e cella
#' di dimensione `d` (tipologia, eventualmente incrociata con l'orario),
#' detto `v` il valore della misura nella cella e `T` il totale del gruppo:
#' - `quota_riga = v[c,d] / T[c]`: composizione contrattuale del CCNL,
#'   somma a 1 entro ogni (`g`, `ccnl_key`);
#' - `quota_colonna = v[c,d] / T[d]`: peso del CCNL entro la tipologia,
#'   somma a 1 entro ogni (`g`, `d`);
#' - `lq = quota_colonna / (T[c] / T)`: quoziente di localizzazione; valori
#'   maggiori di 1 indicano che il CCNL ricorre alla tipologia più della
#'   media del gruppo. Entro ogni CCNL la media di `lq` ponderata con
#'   `T[d] / T` è pari a 1.
#'
#' I totali `T[c]`, `T[d]` e `T` sono calcolati su tutte le righe di `dt`,
#' inclusi i rapporti con `ccnl_key` mancante (classe `"Non classificati"`,
#' conservata in uscita) e prima dell'eventuale filtro `ccnl`: le quote dei
#' CCNL conservati non cambiano filtrando. Le celle con `T[d] < min_n` hanno
#' `lq = NA` ma non vengono eliminate. Se un totale è zero le quote
#' corrispondenti sono `NA`.
#'
#' I rapporti con tipologia non riconducibile a una macro-classe formano la
#' tipologia `"Non classificata"` (`level = "macro"`); i codici MLPS
#' mancanti formano la tipologia `"ND"` (`level = "codice"`), con
#' `des_tipologia_contrattuale` `NA` per i codici ignoti al lookup.
#' L'orario mancante forma la classe `"ND"`. Nessun rapporto viene scartato.
#' Per le misure di conteggio distinto (`n_lavoratori`, `n_datori`) la somma
#' delle celle di un CCNL può superare il conteggio del CCNL in
#' [rank_ccnl()], perché una persona può comparire in più tipologie.
#'
#' @return Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`,
#'   `tipologia`, eventualmente `orario`) e le colonne: quelle di `by` e
#'   `periodo`, `ccnl_key`, `classe` (`"CCNL"` o `"Non classificati"`),
#'   `tipologia`, `des_tipologia_contrattuale` (solo con
#'   `level = "codice"`), `orario` (solo con `orario = TRUE`), `<measure>`,
#'   `quota_riga`, `quota_colonna`, `lq`; ordinato per gruppo, `ccnl_key`
#'   (non classificati in coda) e misura decrescente. L'attributo
#'   `ccnlcob_crosstab` riporta `measure`, `dims`, `by`, `periodo`, `min_n`,
#'   `level` e `orario`. L'input non viene modificato.
#' @family tipologie
#' @seealso [classify_tipologia()], [rank_ccnl()], [ccnl_by_cpi()].
#' @export
#' @examples
#' dt <- prepare_rapporti(cob_esempio)
#' tip <- ccnl_by_tipologia(dt, measure = "n_rapporti", level = "macro")
#' tip[ccnl_key == "A011"]
#'
#' # Quote per macro-tipologia senza orario, in forma larga
#' largo <- ccnl_by_tipologia(dt, orario = FALSE)
#' data.table::dcast(largo, ccnl_key ~ tipologia, value.var = "quota_riga")[1:5]
#'
#' # Codici MLPS con descrizione, giornate per anno, solo due CCNL
#' ccnl_by_tipologia(
#'   dt,
#'   measure = "giornate", ccnl = c("A011", "H011"),
#'   level = "codice", orario = FALSE, periodo = "anno"
#' )[anno == 2024L]
ccnl_by_tipologia <- function(
  dt,
  measure = "n_rapporti",
  ccnl = NULL,
  level = c("macro", "codice"),
  orario = TRUE,
  periodo = NULL,
  by = NULL,
  min_n = 30L,
  tipologie = ccnlcob::tipologie_contrattuali
) {
  # 2.1 Controlli e proiezione -----
  level <- match.arg(level)
  if (!is.data.frame(dt)) {
    stop("`dt` deve essere un data.table di rapporti.", call. = FALSE)
  }
  if (!is.logical(orario) || length(orario) != 1L || is.na(orario)) {
    stop("`orario` deve essere TRUE o FALSE.", call. = FALSE)
  }
  measure <- .check_measure(measure)
  richieste_lookup <- c(
    "cod_tipologia_contrattuale",
    if (level == "macro") "macro_tipologia" else "des_tipologia_contrattuale"
  )
  if (!is.data.frame(tipologie) || !all(richieste_lookup %in% names(tipologie))) {
    stop(
      "`tipologie` deve essere un data.frame con le colonne ",
      paste(richieste_lookup, collapse = " e "),
      ".",
      call. = FALSE
    )
  }
  ha_macro <- "macro_tipologia" %in% names(dt)
  ha_orario <- "orario" %in% names(dt)
  sorgente_tipologia <- if (level == "macro" && ha_macro) {
    "macro_tipologia"
  } else {
    "cod_tipologia_contrattuale"
  }
  if (!sorgente_tipologia %in% names(dt)) {
    stop(
      "Colonna `",
      sorgente_tipologia,
      "` assente da `dt`. Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  if (orario && !ha_orario && !"prior" %in% names(dt)) {
    stop(
      "Colonne `orario` e `prior` assenti da `dt`: impossibile determinare ",
      "l'orario. Applicare prima prepare_rapporti() o usare orario = FALSE.",
      call. = FALSE
    )
  }
  cols <- unique(c(
    by,
    periodo,
    "ccnl_key",
    "giornate",
    .ranking_required[[measure]],
    "avviato",
    "attivo",
    sorgente_tipologia,
    if (orario) if (ha_orario) "orario" else "prior"
  ))
  work <- .project_cols(dt, intersect(cols, names(dt)))

  # 2.2 Dimensioni -----
  if (level == "macro") {
    macro <- if (ha_macro) {
      as.character(work[["macro_tipologia"]])
    } else {
      classify_tipologia(
        work[["cod_tipologia_contrattuale"]],
        tipologie = tipologie
      )
    }
    macro[is.na(macro)] <- .tipologia_non_classificata
    data.table::set(work, j = "tipologia", value = macro)
    dim_cols <- "tipologia"
  } else {
    codice <- as.character(work[["cod_tipologia_contrattuale"]])
    idx <- match(
      codice,
      as.character(tipologie[["cod_tipologia_contrattuale"]])
    )
    descrizione <- as.character(tipologie[["des_tipologia_contrattuale"]])[idx]
    codice[is.na(codice)] <- .tipologia_nd
    data.table::set(work, j = "tipologia", value = codice)
    data.table::set(work, j = "des_tipologia_contrattuale", value = descrizione)
    dim_cols <- c("tipologia", "des_tipologia_contrattuale")
  }
  if (orario) {
    fascia <- if (ha_orario) {
      as.character(work[["orario"]])
    } else {
      prior <- work[["prior"]]
      data.table::fifelse(
        prior == 1,
        "FT",
        data.table::fifelse(prior == 0, "PT", NA_character_)
      )
    }
    fascia[is.na(fascia)] <- .orario_nd
    data.table::set(work, j = "orario", value = fascia)
    dim_cols <- c(dim_cols, "orario")
  }

  # 2.3 Tabella incrociata -----
  out <- .crosstab_ccnl(
    work,
    dim_cols = dim_cols,
    measure = measure,
    by = by,
    periodo = periodo,
    ccnl = ccnl,
    min_n = min_n
  )
  meta <- attr(out, "ccnlcob_crosstab")
  meta$level <- level
  meta$orario <- orario
  data.table::setattr(out, "ccnlcob_crosstab", meta)
  out[]
}

# 3. Classificazione in macro-classi -----

#' Classifica i codici di tipologia contrattuale in macro-classi
#'
#' Traduce un vettore di codici MLPS (`cod_tipologia_contrattuale`) nella
#' macro-classe definita dal lookup [tipologie_contrattuali]. La traduzione
#' è vettorizzata (`match()`), conserva lunghezza e ordine di `codici` e
#' non modifica i codici in ingresso (nessuna normalizzazione di maiuscole o
#' spazi).
#'
#' @param codici Vettore character di codici MLPS (es. `"A.01.00"`); i
#'   factor vengono convertiti in character.
#' @param tipologie Lookup con le colonne `cod_tipologia_contrattuale` e
#'   `macro_tipologia`; default [tipologie_contrattuali]. Con codici
#'   duplicati nel lookup vale la prima occorrenza.
#'
#' @return Vettore character della stessa lunghezza di `codici` con la
#'   macro-classe; `NA` per i codici `NA` e per quelli non presenti nel
#'   lookup. Errore se `tipologie` non contiene le due colonne richieste.
#' @family tipologie
#' @export
#' @examples
#' classify_tipologia(c("A.01.00", "A.02.00", "C.01.00", "ZZZ", NA))
#'
#' # lookup alternativo
#' lookup <- data.frame(
#'   cod_tipologia_contrattuale = c("X.01", "X.02"),
#'   macro_tipologia = c("Classe X1", "Classe X2")
#' )
#' classify_tipologia(c("X.02", "X.01", "A.01.00"), tipologie = lookup)
classify_tipologia <- function(
  codici,
  tipologie = ccnlcob::tipologie_contrattuali
) {
  richieste <- c("cod_tipologia_contrattuale", "macro_tipologia")
  if (!is.data.frame(tipologie) || !all(richieste %in% names(tipologie))) {
    stop(
      "`tipologie` deve essere un data.frame con le colonne ",
      paste(richieste, collapse = " e "),
      ".",
      call. = FALSE
    )
  }
  if (is.factor(codici)) {
    codici <- as.character(codici)
  }
  if (is.null(codici)) {
    return(character(0))
  }
  if (!is.character(codici) && !(is.logical(codici) && all(is.na(codici)))) {
    stop("`codici` deve essere un vettore character.", call. = FALSE)
  }
  idx <- match(codici, as.character(tipologie[["cod_tipologia_contrattuale"]]))
  as.character(tipologie[["macro_tipologia"]])[idx]
}
