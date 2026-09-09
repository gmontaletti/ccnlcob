# 1. Costanti e simboli -----

utils::globalVariables(c("avviato", "classe", "selezionato", ".row_id", ".ord"))

# Misure ammesse da rank_ccnl(), nell'ordine di documentazione.
.ranking_measures <- c(
  "n_rapporti",
  "n_lavoratori",
  "n_datori",
  "giornate",
  "giornate_effettive",
  "stock"
)

# Colonne obbligatorie per ciascuna misura (oltre a ccnl_key e giornate).
.ranking_required <- list(
  n_rapporti = character(0),
  n_lavoratori = "cf",
  n_datori = "datore",
  giornate = "giornate",
  giornate_effettive = "giornate_effettive",
  stock = character(0)
)

# Espressioni di aggregazione, valutate per gruppo da .aggregate_misure()
# (R/crosstab.R), condivise da rank_ccnl(), ccnl_by_cpi() e
# ccnl_by_tipologia().
.ranking_exprs <- list(
  n_rapporti = quote(sum(avviato)),
  n_lavoratori = quote(data.table::uniqueN(cf[avviato])),
  n_datori = quote(data.table::uniqueN(datore[avviato])),
  giornate = quote(sum(as.numeric(giornate), na.rm = TRUE)),
  giornate_effettive = quote(sum(as.numeric(giornate_effettive), na.rm = TRUE)),
  stock = quote(sum(attivo))
)

# Etichette della colonna `classe`.
.classe_ccnl <- "CCNL"
.classe_non_classificati <- "Non classificati"
.classe_altri <- "Altri CCNL"

# 2. Ranking dei CCNL -----

#' Ordina i CCNL per misure di rilevanza
#'
#' Calcola, per ciascun CCNL (ed eventualmente per gruppo e periodo), le
#' misure di rilevanza richieste, la quota sul totale, il rank e la quota
#' cumulata lungo il rank. Non viene costruito alcun indice composito: ogni
#' misura produce il proprio ordinamento e la selezione dei CCNL rilevanti
#' avviene a valle con [select_ccnl_rilevanti()].
#'
#' @param dt Un `data.table` di rapporti già passato da
#'   [prepare_rapporti()], con almeno le colonne `ccnl_key` e `giornate`;
#'   vedi i Dettagli per le colonne richieste da ciascuna misura.
#' @param measures Vettore character con le misure da calcolare, fra
#'   `"n_rapporti"`, `"n_lavoratori"`, `"n_datori"`, `"giornate"`,
#'   `"giornate_effettive"`, `"stock"`. La prima misura determina
#'   l'ordinamento delle righe in uscita.
#' @param by Vettore character con colonne aggiuntive di raggruppamento
#'   (es. `"macro_tipologia"`, `"sesso"`); `NULL` per il solo CCNL.
#' @param periodo Colonna temporale (`"anno"` o `"trimestre"`, prodotte da
#'   [prepare_rapporti()]) per un ranking per coorte di avviamento; `NULL`
#'   per l'intera finestra. Viene accodata alle colonne di `by`.
#' @param ccnl_labels `data.table` opzionale con la colonna `ccnl_key` e
#'   colonne di etichetta (es. `ccnl_titolo`, `macro_settore_cnel`) da
#'   agganciare al risultato con un left join; le chiavi devono essere
#'   univoche.
#'
#' @details
#' Le misure sono definite sulle righe di `dt` così:
#' - `n_rapporti`: numero di rapporti con `avviato == TRUE` (avviamento
#'   nella finestra di analisi);
#' - `n_lavoratori`: numero di `cf` distinti fra i rapporti avviati;
#' - `n_datori`: numero di `datore` distinti fra i rapporti avviati;
#' - `giornate`: somma di `giornate` (giorni-contratto nella finestra);
#' - `giornate_effettive`: somma di `giornate_effettive` (giorni-persona
#'   allocati pro quota, vedi [compute_giornate_effettive()]);
#' - `stock`: numero di rapporti con `attivo == TRUE`, cioè aperti alla
#'   data `as_of` fissata in [prepare_rapporti()] (fine originale mancante,
#'   sentinella o successiva ad `as_of`); coincide con `n_attivi` di
#'   `cnelR`.
#'
#' Se `avviato` o `attivo` mancano vengono considerati `TRUE` per tutte le
#' righe, con un messaggio; un valore `NA` equivale a `FALSE`. Le colonne
#' `datore` e `giornate_effettive` sono richieste solo dalle misure che le
#' usano.
#'
#' I rapporti con `ccnl_key` mancante formano la classe esplicita
#' `"Non classificati"` e non vengono scartati: la quota `quota_m` di ogni
#' riga è calcolata sul totale del gruppo inclusa questa classe, così
#' che le quote sommino a 1 entro ogni combinazione di `by` e `periodo`. Il
#' rank `rank_m` è assegnato solo ai CCNL classificati, in ordine
#' decrescente della misura, con i pari merito che ricevono il rank minimo
#' comune; la quota cumulata `quota_cum_m` segue l'ordine del rank (a parità
#' di valore, l'ordine alfabetico di `ccnl_key`) ed è `NA` per la classe non
#' classificata. Se il totale del gruppo è zero le quote sono `NA`.
#'
#' @return Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`),
#'   ordinato per gruppo e per `rank_` della prima misura, con la riga dei
#'   non classificati in coda a ogni gruppo. Colonne: quelle di `by` e
#'   `periodo`, `ccnl_key`, `classe` (`"CCNL"` o `"Non classificati"`), le
#'   eventuali etichette di `ccnl_labels` e, per ciascuna misura `m`, `m`,
#'   `quota_m`, `rank_m` (integer, `NA` per i non classificati) e
#'   `quota_cum_m`. L'attributo `ccnlcob_ranking` conserva `measures`, `by`
#'   e `periodo`. L'input non viene modificato.
#' @family ranking
#' @seealso [select_ccnl_rilevanti()] per la selezione dei CCNL rilevanti.
#' @export
#' @examples
#' # Tabella preparata a mano da cob_esempio (in uso reale: prepare_rapporti())
#' dt <- data.table::copy(cob_esempio)[
#'   fine >= inizio & fine <= as.Date("2024-12-31")
#' ]
#' # attivo: rapporto aperto ad as_of; nel dataset di esempio la fine non
#' # osservata e' stata chiusa a monte alla data di stabilizzazione
#' # (troncata = 1)
#' dt[, `:=`(
#'   ccnl_key = codice_cnel,
#'   giornate = as.integer(fine - inizio + 1L),
#'   avviato = TRUE,
#'   attivo = troncata == 1L,
#'   anno = data.table::year(inizio)
#' )]
#'
#' ranking <- rank_ccnl(dt, measures = c("n_lavoratori", "giornate"))
#' head(ranking)
#'
#' # Ranking per coorte annuale di avviamento
#' per_anno <- rank_ccnl(dt, measures = "giornate", periodo = "anno")
#' per_anno[anno == 2024L & rank_giornate <= 3L]
#'
#' # Etichette agganciate al risultato
#' etichette <- data.table::data.table(
#'   ccnl_key = c("A011", "H011"),
#'   ccnl_titolo = c("Titolo CCNL A011", "Titolo CCNL H011")
#' )
#' rank_ccnl(dt, measures = "giornate", ccnl_labels = etichette)[1:3]
rank_ccnl <- function(
  dt,
  measures = c("n_lavoratori", "giornate"),
  by = NULL,
  periodo = NULL,
  ccnl_labels = NULL
) {
  # 2.1 Controlli sugli argomenti -----
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
  if (!is.character(measures) || length(measures) == 0L || anyNA(measures)) {
    stop(
      "`measures` deve essere un vettore character non vuoto.",
      call. = FALSE
    )
  }
  measures <- unique(measures)
  non_ammesse <- setdiff(measures, .ranking_measures)
  if (length(non_ammesse) > 0L) {
    stop(
      "Misure non ammesse: ",
      paste(non_ammesse, collapse = ", "),
      ". Misure disponibili: ",
      paste(.ranking_measures, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
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
    if (periodo %in% by) {
      stop("`periodo` non pu\u00f2 comparire anche in `by`.", call. = FALSE)
    }
  }
  richieste <- unique(unlist(.ranking_required[measures], use.names = FALSE))
  richieste_mancanti <- setdiff(richieste, names(dt))
  if (length(richieste_mancanti) > 0L) {
    stop(
      "Le misure richieste necessitano delle colonne: ",
      paste(richieste_mancanti, collapse = ", "),
      ". Applicare prepare_rapporti() o compute_giornate_effettive().",
      call. = FALSE
    )
  }
  if (!is.null(ccnl_labels)) {
    .check_ccnl_labels(ccnl_labels)
  }

  # 2.2 Aggregazione per gruppo e CCNL -----
  group_cols <- c(by, periodo, "ccnl_key")
  agg <- .aggregate_misure(dt, group_cols, measures)
  data.table::setkey(agg, NULL)
  agg[,
    classe := data.table::fifelse(
      is.na(ccnl_key),
      .classe_non_classificati,
      .classe_ccnl
    )
  ]

  # 2.3 Quote, rank e quote cumulate -----
  grp <- c(by, periodo)
  .add_quote_rank(agg, measures, grp)

  # 2.4 Etichette -----
  label_cols <- character(0)
  if (!is.null(ccnl_labels)) {
    label_cols <- setdiff(names(ccnl_labels), "ccnl_key")
    in_conflitto <- intersect(label_cols, names(agg))
    if (length(in_conflitto) > 0L) {
      stop(
        "Colonne di `ccnl_labels` gi\u00e0 presenti nel ranking: ",
        paste(in_conflitto, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
    labels <- data.table::as.data.table(ccnl_labels)
    agg[labels, on = "ccnl_key", (label_cols) := mget(paste0("i.", label_cols))]
  }

  # 2.5 Ordinamento e uscita -----
  misure_cols <- unlist(lapply(measures, function(m) {
    c(m, paste0("quota_", m), paste0("rank_", m), paste0("quota_cum_", m))
  }))
  data.table::setcolorder(
    agg,
    c(grp, "ccnl_key", "classe", label_cols, misure_cols)
  )
  data.table::setorderv(
    agg,
    c(grp, paste0("rank_", measures[1L]), "ccnl_key"),
    na.last = TRUE
  )
  data.table::setattr(
    agg,
    "ccnlcob_ranking",
    list(measures = measures, by = by, periodo = periodo)
  )
  agg[]
}

# 3. Selezione dei CCNL rilevanti -----

#' Seleziona i CCNL rilevanti da un ranking
#'
#' Individua, entro ogni gruppo di un ranking prodotto da [rank_ccnl()], i
#' CCNL che coprono una quota cumulata della misura scelta e/o i primi
#' `top_n`, restituendo le chiavi selezionate oppure il ranking con i CCNL
#' non selezionati riassunti in una classe residua.
#'
#' @param ranking Un `data.table` prodotto da [rank_ccnl()].
#' @param measure Misura su cui operare la selezione (es. `"giornate"`); nel
#'   ranking devono essere presenti `measure`, `quota_<measure>` e
#'   `rank_<measure>`.
#' @param top_n Numero massimo di CCNL da selezionare per gruppo; `NULL` per
#'   usare solo `cum_share`.
#' @param cum_share Soglia di quota cumulata in `(0, 1]`; `NULL` per usare
#'   solo `top_n`. Almeno uno fra `top_n` e `cum_share` deve essere fornito.
#' @param other_label Etichetta della classe residua nella tabella.
#' @param return `"keys"` per il vettore delle chiavi selezionate, `"table"`
#'   per il ranking con la classe residua.
#'
#' @details
#' Entro ogni gruppo (`by` e `periodo` del ranking, letti dall'attributo
#' `ccnlcob_ranking` o, in sua assenza, dalle colonne che precedono
#' `ccnl_key`) i CCNL classificati sono scorsi in ordine di `rank_<measure>`
#' (a parità di rank, in ordine di `ccnl_key`). Un CCNL viene selezionato
#' finché la quota cumulata dei CCNL che lo precedono è inferiore a
#' `cum_share`: la selezione include quindi il CCNL con cui la quota cumulata
#' raggiunge o supera la soglia, ed è l'insieme minimo con copertura
#' `>= cum_share`. Le quote sono quelle del ranking, calcolate sul totale del
#' gruppo inclusi i non classificati. Se `top_n` è fornito la selezione
#' viene poi troncata ai primi `top_n` CCNL; con entrambi i criteri prevale
#' quindi il più restrittivo. La classe dei non classificati non è mai
#' selezionata. Entrambi i parametri sono espliciti: il pacchetto non fissa
#' soglie a priori.
#'
#' Con `return = "table"` i CCNL classificati non selezionati di ogni gruppo
#' vengono aggregati in una riga con `ccnl_key = other_label` e
#' `classe = "Altri CCNL"`: le misure sono sommate, le quote `quota_*`
#' ricalcolate sul gruppo, `rank_*`, `quota_cum_*` ed etichette poste a `NA`.
#' La riga dei non classificati è conservata. Per le misure di conteggio
#' distinto (`n_lavoratori`, `n_datori`) la somma nella classe residua è la
#' somma dei conteggi per CCNL, non un conteggio distinto sull'insieme.
#'
#' @return Con `return = "keys"`, vettore character delle chiavi `ccnl_key`
#'   selezionate (unione fra i gruppi, senza duplicati, gruppo per gruppo in
#'   ordine di `rank_<measure>` e, a parità, di `ccnl_key`). Con
#'   `return = "table"`, un `data.table` con le colonne del ranking più la
#'   colonna logica `selezionato`, ordinato per gruppo con i CCNL selezionati
#'   (in ordine di `rank_<measure>`), la classe residua e i non classificati;
#'   l'attributo `ccnlcob_ranking` è conservato e l'attributo
#'   `ccnlcob_selezione` riporta `measure`, `top_n`, `cum_share`,
#'   `other_label` e le chiavi selezionate (`keys`). L'input non viene
#'   modificato.
#' @family ranking
#' @seealso [rank_ccnl()] per la costruzione del ranking.
#' @export
#' @examples
#' dt <- data.table::copy(cob_esempio)[
#'   fine >= inizio & fine <= as.Date("2024-12-31")
#' ]
#' dt[, `:=`(
#'   ccnl_key = codice_cnel,
#'   giornate = as.integer(fine - inizio + 1L),
#'   avviato = TRUE
#' )]
#' ranking <- rank_ccnl(dt, measures = "giornate")
#'
#' # Chiavi che coprono almeno l'80% delle giornate
#' select_ccnl_rilevanti(ranking, measure = "giornate", cum_share = 0.8)
#'
#' # Primi 5 CCNL e tabella con la classe residua
#' select_ccnl_rilevanti(
#'   ranking,
#'   measure = "giornate", top_n = 5, cum_share = NULL, return = "table"
#' )
select_ccnl_rilevanti <- function(
  ranking,
  measure = "giornate",
  top_n = NULL,
  cum_share = 0.8,
  other_label = "Altri CCNL",
  return = c("keys", "table")
) {
  # 3.1 Controlli sugli argomenti -----
  return <- match.arg(return)
  if (!is.data.frame(ranking) || !"ccnl_key" %in% names(ranking)) {
    stop(
      "`ranking` deve essere un data.table prodotto da rank_ccnl().",
      call. = FALSE
    )
  }
  if (!is.character(measure) || length(measure) != 1L || is.na(measure)) {
    stop("`measure` deve essere una singola stringa.", call. = FALSE)
  }
  rcol <- paste0("rank_", measure)
  qcol <- paste0("quota_", measure)
  cols_misura <- c(measure, qcol, rcol)
  if (!all(cols_misura %in% names(ranking))) {
    stop(
      "Misura `",
      measure,
      "` assente dal ranking: servono le colonne ",
      paste(cols_misura, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
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
    top_n <- as.integer(top_n)
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
  if (
    !is.character(other_label) ||
      length(other_label) != 1L ||
      is.na(other_label)
  ) {
    stop("`other_label` deve essere una singola stringa.", call. = FALSE)
  }
  if (other_label %in% ranking[["ccnl_key"]]) {
    stop(
      "`other_label` coincide con una chiave `ccnl_key` presente nel ranking.",
      call. = FALSE
    )
  }

  # 3.2 Gruppi e misure del ranking -----
  grp <- .ranking_groups(ranking)
  measures <- sub("^rank_", "", grep("^rank_", names(ranking), value = TRUE))
  measures <- measures[measures %in% names(ranking)]

  # 3.3 Selezione entro gruppo -----
  work <- data.table::as.data.table(ranking)
  work[, .row_id := seq_len(.N)]
  work[, selezionato := FALSE]
  classificato <- !is.na(work[[rcol]])
  work[
    classificato,
    selezionato := .select_group(
      .SD[[rcol]],
      .SD[[qcol]],
      ccnl_key,
      top_n,
      cum_share
    ),
    by = grp,
    .SDcols = c(rcol, qcol)
  ]
  sel <- work[selezionato == TRUE]
  data.table::setorderv(sel, c(grp, rcol, "ccnl_key"))
  keys <- unique(sel[["ccnl_key"]])
  if (return == "keys") {
    return(keys)
  }

  # 3.4 Tabella con classe residua -----
  residui <- work[classificato & !work[["selezionato"]]]
  out <- work[!classificato | work[["selezionato"]]]
  out[, .ord := data.table::fifelse(selezionato, 0L, 2L)]
  if (nrow(residui) > 0L) {
    altri <- residui[, lapply(.SD, sum), by = grp, .SDcols = measures]
    altri[, `:=`(
      ccnl_key = other_label,
      classe = .classe_altri,
      selezionato = FALSE,
      .row_id = NA_integer_,
      .ord = 1L
    )]
    out <- data.table::rbindlist(
      list(out, altri),
      use.names = TRUE,
      fill = TRUE
    )
  }
  for (m in measures) {
    out[, (paste0("quota_", m)) := .share(.SD[[m]]), by = grp, .SDcols = m]
  }
  data.table::setorderv(out, c(grp, ".ord", rcol, "ccnl_key"), na.last = TRUE)
  out[, c(".ord", ".row_id") := NULL]
  data.table::setcolorder(
    out,
    c(intersect(c(grp, "ccnl_key", "classe"), names(out)), "selezionato")
  )
  data.table::setattr(out, "ccnlcob_ranking", attr(ranking, "ccnlcob_ranking"))
  data.table::setattr(
    out,
    "ccnlcob_selezione",
    list(
      measure = measure,
      top_n = top_n,
      cum_share = cum_share,
      other_label = other_label,
      keys = keys
    )
  )
  out[]
}

# 4. Helper interni -----

#' Aggiunge quota, rank e quota cumulata per ciascuna misura
#'
#' @param agg Un `data.table` aggregato con `ccnl_key` e le colonne delle
#'   misure; modificato per riferimento.
#' @param measures Vettore character delle misure.
#' @param grp Vettore character delle colonne di gruppo (anche vuoto).
#' @return `agg`, invisibilmente.
#' @keywords internal
#' @noRd
.add_quote_rank <- function(agg, measures, grp) {
  for (m in measures) {
    qcol <- paste0("quota_", m)
    rcol <- paste0("rank_", m)
    ccol <- paste0("quota_cum_", m)
    agg[, (qcol) := .share(.SD[[m]]), by = grp, .SDcols = m]
    agg[, (rcol) := NA_integer_]
    agg[, (ccol) := NA_real_]
    agg[
      !is.na(ccnl_key),
      (rcol) := data.table::frankv(
        .SD[[m]],
        order = -1L,
        ties.method = "min",
        na.last = "keep"
      ),
      by = grp,
      .SDcols = m
    ]
    agg[
      !is.na(ccnl_key),
      (ccol) := {
        o <- order(-.SD[[m]], ccnl_key, method = "radix")
        cumsum(.SD[[qcol]][o])[order(o)]
      },
      by = grp,
      .SDcols = c(m, qcol)
    ]
  }
  invisible(agg)
}

#' Seleziona i CCNL di un gruppo per quota cumulata e/o top_n
#'
#' @param rango Vettore integer dei rank (senza `NA`).
#' @param quota Vettore numerico delle quote sul totale del gruppo.
#' @param key Vettore character delle chiavi, per rompere i pari merito.
#' @param top_n Intero positivo o `NULL`.
#' @param cum_share Numero in `(0, 1]` o `NULL`.
#' @return Vettore logico della stessa lunghezza di `rango`.
#' @keywords internal
#' @noRd
.select_group <- function(rango, quota, key, top_n, cum_share) {
  n <- length(rango)
  o <- order(rango, key, method = "radix")
  keep <- rep(TRUE, n)
  if (!is.null(cum_share)) {
    q <- quota[o]
    prima <- cumsum(q) - q
    tol <- sqrt(.Machine$double.eps)
    keep <- keep & (prima < cum_share - tol) %in% TRUE
  }
  if (!is.null(top_n)) {
    keep <- keep & seq_len(n) <= top_n
  }
  keep[order(o)]
}

#' Colonne di gruppo di un ranking
#'
#' Legge `by` e `periodo` dall'attributo `ccnlcob_ranking`; in sua assenza
#' usa le colonne che precedono `ccnl_key`.
#'
#' @param ranking Un `data.table` prodotto da [rank_ccnl()].
#' @return Vettore character, eventualmente vuoto.
#' @keywords internal
#' @noRd
.ranking_groups <- function(ranking) {
  meta <- attr(ranking, "ccnlcob_ranking")
  if (is.list(meta)) {
    grp <- c(meta$by, meta$periodo)
  } else {
    nomi <- names(ranking)
    grp <- nomi[seq_len(match("ccnl_key", nomi) - 1L)]
  }
  grp <- intersect(grp, names(ranking))
  as.character(grp)
}

#' Controlla la tabella delle etichette CCNL
#'
#' @param ccnl_labels Oggetto passato come `ccnl_labels` a [rank_ccnl()].
#' @return `TRUE`, invisibilmente; errore altrimenti.
#' @keywords internal
#' @noRd
.check_ccnl_labels <- function(ccnl_labels) {
  if (!is.data.frame(ccnl_labels) || !"ccnl_key" %in% names(ccnl_labels)) {
    stop(
      "`ccnl_labels` deve essere un data.table con la colonna `ccnl_key`.",
      call. = FALSE
    )
  }
  if (ncol(ccnl_labels) < 2L) {
    stop(
      "`ccnl_labels` deve contenere almeno una colonna di etichetta oltre a ",
      "`ccnl_key`.",
      call. = FALSE
    )
  }
  if (anyDuplicated(ccnl_labels[["ccnl_key"]]) > 0L) {
    stop("`ccnl_labels` contiene chiavi `ccnl_key` duplicate.", call. = FALSE)
  }
  invisible(TRUE)
}
