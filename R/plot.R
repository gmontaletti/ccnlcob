# 1. Costanti e palette -----

# Palette Okabe & Ito (2008): 8 colori distinguibili sotto protanopia,
# deuteranopia e tritanopia. Usata sia per le scale discrete esportate sia,
# internamente, per le funzioni di plottaggio del pacchetto.
.okabe_ito <- c(
  arancio = "#E69F00",
  azzurro = "#56B4E9",
  verde = "#009E73",
  giallo = "#F0E442",
  blu = "#0072B2",
  vermiglio = "#D55E00",
  porpora = "#CC79A7",
  nero = "#000000"
)

# Numero massimo di colonne CPI mostrate da plot_cpi(): oltre questa soglia
# le etichette dell'asse diventano illeggibili (verificato sui 65 CPI della
# Lombardia nello slice reale a 36 mesi).
.cpi_max_col <- 20L

# Forme di punto per plot_ranking_periodo(): ggplot2::scale_shape_discrete()
# si ferma a 6 forme (con avviso oltre), qui ne servono fino a 8 per restare
# allineati alla capienza della palette Okabe-Ito.
.shape_vals <- c(16, 17, 15, 3, 8, 4, 18, 1)

# 2. Tema e scale -----

#' Tema grafico minimale per ccnlcob
#'
#' Tema `ggplot2` condiviso da tutte le funzioni di plottaggio del
#' pacchetto: sfondo chiaro, griglia minore assente, legenda in basso,
#' dimensioni del testo mai sotto i 9 punti con `base_size` di default. Le
#' singole funzioni di plottaggio rimuovono inoltre la griglia maggiore
#' sull'asse categoriale quando pertinente (non gestito qui perché dipende
#' dall'orientamento del grafico).
#'
#' @param base_size Dimensione del testo di base, in punti.
#' @return Un oggetto `theme` di `ggplot2`.
#' @family grafici
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
#'     ggplot2::geom_point() +
#'     theme_ccnlcob()
#' }
theme_ccnlcob <- function(base_size = 11) {
  .check_ggplot2()
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.title = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.background = ggplot2::element_rect(fill = "#FAFAFA", colour = NA),
      plot.background = ggplot2::element_rect(fill = "#FAFAFA", colour = NA),
      plot.title = ggplot2::element_text(
        face = "bold",
        size = ggplot2::rel(1.05)
      ),
      plot.subtitle = ggplot2::element_text(colour = "grey30"),
      plot.caption = ggplot2::element_text(
        colour = "grey40",
        size = ggplot2::rel(0.75),
        hjust = 0
      ),
      strip.background = ggplot2::element_rect(fill = "grey90", colour = NA),
      strip.text = ggplot2::element_text(
        face = "bold",
        size = ggplot2::rel(0.9)
      ),
      axis.text = ggplot2::element_text(size = ggplot2::rel(0.85))
    )
}

#' Palette Okabe-Ito per ccnlcob
#'
#' Restituisce i primi `n` colori della palette Okabe-Ito (8 colori, incluso
#' il nero), sicura per le forme più comuni di daltonismo (protanopia,
#' deuteranopia, tritanopia): arancio `#E69F00`, azzurro `#56B4E9`, verde
#' `#009E73`, giallo `#F0E442`, blu `#0072B2`, vermiglio `#D55E00`, porpora
#' `#CC79A7`, nero `#000000` (Okabe & Ito, 2008,
#' <https://jfly.uni-koeln.de/color/>).
#'
#' @param n Numero di colori richiesti, fra 1 e 8.
#' @return Vettore character di `n` codici esadecimali.
#' @family grafici
#' @seealso [scale_colour_ccnlcob()], [scale_fill_ccnlcob()].
#' @export
#' @examples
#' palette_ccnlcob(4)
palette_ccnlcob <- function(n) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != round(n)) {
    stop("`n` deve essere un intero positivo.", call. = FALSE)
  }
  n <- as.integer(n)
  if (n > length(.okabe_ito)) {
    stop(
      "Richiesti ",
      n,
      " colori: la palette Okabe-Ito ne offre solo ",
      length(.okabe_ito),
      ". Ridurre il numero di livelli (per esempio con `top_n` o `keys`).",
      call. = FALSE
    )
  }
  unname(.okabe_ito[seq_len(n)])
}

# Funzione di palette per ggplot2::discrete_scale(): riceve il numero di
# livelli e restituisce i colori, con lo stesso errore di palette_ccnlcob()
# quando i livelli superano la palette.
.ccnlcob_pal <- function(n) palette_ccnlcob(n)

#' Scale colore e riempimento sulla palette Okabe-Ito
#'
#' Scale discrete di `ggplot2` per le estetiche `colour` e `fill` sulla
#' palette [palette_ccnlcob()]. Con più di 8 livelli nei dati la
#' costruzione del grafico genera un errore: ridurre i livelli (per esempio
#' filtrando con `top_n` o `keys` nelle funzioni di plottaggio del
#' pacchetto) invece di allargare la palette.
#'
#' @param ... Argomenti passati a `ggplot2::discrete_scale()` (`name`,
#'   `breaks`, `labels`, `guide`, ...).
#' @return Un oggetto `Scale` di `ggplot2`.
#' @family grafici
#' @seealso [palette_ccnlcob()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   d <- data.frame(x = 1:3, y = 1:3, g = c("a", "b", "c"))
#'   p <- ggplot2::ggplot(d, ggplot2::aes(x, y, colour = g)) +
#'     ggplot2::geom_point(size = 3) +
#'     scale_colour_ccnlcob()
#' }
scale_colour_ccnlcob <- function(...) {
  .check_ggplot2()
  ggplot2::discrete_scale(aesthetics = "colour", palette = .ccnlcob_pal, ...)
}

#' @rdname scale_colour_ccnlcob
#' @export
scale_fill_ccnlcob <- function(...) {
  .check_ggplot2()
  ggplot2::discrete_scale(aesthetics = "fill", palette = .ccnlcob_pal, ...)
}

# 3. Ranking dei CCNL -----

#' Grafico a barre del ranking dei CCNL
#'
#' Barre orizzontali dei primi `top_n` CCNL per `measure`, ordinate per
#' valore decrescente, con la quota sul totale stampata come etichetta
#' diretta alla fine di ogni barra (nessuna legenda necessaria). I CCNL non
#' classificati e, con `other = TRUE`, il residuo dei CCNL esclusi dal
#' `top_n` sono ricalcolati dalla tabella e disegnati come barre distinte,
#' in grigio neutro anziché nella palette categoriale: la distinzione non
#' dipende quindi solo dal colore, ma anche dall'etichetta testuale
#' sull'asse e dalla posizione (sempre in coda al grafico).
#'
#' @param x Una tabella di [rank_ccnl()] o di [select_ccnl_rilevanti()]
#'   (`return = "table"`), oppure un oggetto `ccnlcob_result` prodotto da
#'   [analyze_ccnl()] (viene usato `x$ranking`). Se la tabella è
#'   raggruppata per `by` o `periodo` deve contenere un solo gruppo:
#'   filtrare a monte, altrimenti la funzione segnala un errore.
#' @param measure Misura da rappresentare; devono essere presenti le
#'   colonne `measure` e `quota_measure`.
#' @param top_n Numero massimo di CCNL classificati da mostrare.
#' @param labels `data.table` opzionale con le colonne `ccnl_key` e
#'   `ccnl_titolo`, per etichette leggibili sull'asse (titolo troncato a
#'   circa 45 caratteri, con la chiave fra parentesi); `NULL` (default) usa
#'   direttamente `ccnl_key`.
#' @param other Se `TRUE` (default) aggiunge una barra col residuo dei CCNL
#'   classificati esclusi dal `top_n`; se `FALSE` quei CCNL non compaiono.
#' @return Un oggetto `ggplot`.
#' @family grafici
#' @seealso [rank_ccnl()], [select_ccnl_rilevanti()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   res <- analyze_ccnl(
#'     cob_esempio,
#'     window = as.Date(c("2022-01-01", "2024-12-31")),
#'     lookup_cpi = cpi_esempio,
#'     top_n = 8,
#'     min_n = 10
#'   )
#'   p <- plot_ranking(res, measure = "giornate", top_n = 6)
#' }
plot_ranking <- function(
  x,
  measure = "giornate",
  top_n = 15,
  labels = NULL,
  other = TRUE
) {
  .check_ggplot2()
  if (inherits(x, "ccnlcob_result")) {
    x <- x[["ranking"]]
    if (is.null(x)) {
      stop("`x$ranking` \u00e8 NULL: eseguire prima analyze_ccnl().", call. = FALSE)
    }
  }
  if (!is.data.frame(x) || !"ccnl_key" %in% names(x)) {
    stop(
      "`x` deve essere una tabella di rank_ccnl()/select_ccnl_rilevanti() ",
      "o un `ccnlcob_result`.",
      call. = FALSE
    )
  }
  if (!is.character(measure) || length(measure) != 1L || is.na(measure)) {
    stop("`measure` deve essere una singola stringa.", call. = FALSE)
  }
  qcol <- paste0("quota_", measure)
  cols_misura <- c(measure, qcol)
  mancanti <- setdiff(c("classe", cols_misura), names(x))
  if (length(mancanti) > 0L) {
    stop(
      "Misura `",
      measure,
      "` assente da `x`: servono le colonne ",
      paste(cols_misura, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (
    !is.numeric(top_n) ||
      length(top_n) != 1L ||
      is.na(top_n) ||
      top_n < 1 ||
      top_n != round(top_n)
  ) {
    stop("`top_n` deve essere un intero positivo.", call. = FALSE)
  }
  top_n <- as.integer(top_n)
  if (!is.logical(other) || length(other) != 1L || is.na(other)) {
    stop("`other` deve essere TRUE o FALSE.", call. = FALSE)
  }

  dt <- data.table::as.data.table(x)
  classificati <- dt[dt[["classe"]] == .classe_ccnl]
  if (anyDuplicated(classificati[["ccnl_key"]]) > 0L) {
    stop(
      "`x` contiene pi\u00f9 righe per CCNL (probabile raggruppamento per ",
      "`by` o `periodo`): filtrare a un solo gruppo prima di chiamare ",
      "plot_ranking().",
      call. = FALSE
    )
  }
  non_class <- dt[dt[["classe"]] == .classe_non_classificati]
  data.table::setorderv(classificati, qcol, order = -1L)
  n_top <- min(top_n, nrow(classificati))
  top <- classificati[seq_len(n_top)]
  resto <- if (n_top < nrow(classificati)) {
    classificati[(n_top + 1L):nrow(classificati)]
  } else {
    classificati[0L]
  }

  disp <- .apply_labels(top[["ccnl_key"]], labels)
  piano_top <- data.table::data.table(
    label = unname(disp[top[["ccnl_key"]]]),
    valore = top[[measure]],
    quota = top[[qcol]],
    gruppo = "CCNL"
  )
  extra <- list()
  if (isTRUE(other) && nrow(resto) > 0L) {
    extra$altri <- data.table::data.table(
      label = .classe_altri,
      valore = sum(resto[[measure]], na.rm = TRUE),
      quota = sum(resto[[qcol]], na.rm = TRUE),
      gruppo = "Altro"
    )
  }
  if (nrow(non_class) > 0L) {
    extra$non_class <- data.table::data.table(
      label = .classe_non_classificati,
      valore = sum(non_class[[measure]], na.rm = TRUE),
      quota = sum(non_class[[qcol]], na.rm = TRUE),
      gruppo = "Altro"
    )
  }
  piano <- data.table::rbindlist(c(list(piano_top), extra))
  livelli <- c(
    if (!is.null(extra[["non_class"]])) .classe_non_classificati,
    if (!is.null(extra[["altri"]])) .classe_altri,
    rev(piano_top[["label"]])
  )
  piano[, label := factor(label, levels = livelli)]

  ggplot2::ggplot(piano, ggplot2::aes(x = label, y = valore, fill = gruppo)) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.1f%%", quota * 100)),
      hjust = -0.12,
      size = 3.2,
      colour = "grey20"
    ) +
    ggplot2::scale_fill_manual(
      values = c(CCNL = .okabe_ito[["blu"]], Altro = "grey65"),
      guide = "none"
    ) +
    ggplot2::scale_y_continuous(
      labels = function(v) {
        format(
          round(v),
          big.mark = ".",
          decimal.mark = ",",
          scientific = FALSE,
          trim = TRUE
        )
      },
      expand = ggplot2::expansion(mult = c(0, 0.18))
    ) +
    ggplot2::coord_flip(clip = "off") +
    ggplot2::labs(x = NULL, y = .cap1(gsub("_", " ", measure))) +
    theme_ccnlcob() +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      legend.position = "none"
    )
}

# 4. Ranking per periodo -----

#' Andamento del ranking dei CCNL per periodo
#'
#' Linee con punti dell'andamento di `measure` (o della sua quota) per
#' periodo di avviamento, una per CCNL selezionato. Colore, tratteggio e
#' forma del punto codificano insieme il CCNL (codifica ridondante), con
#' un'etichetta diretta a fine linea al posto della legenda.
#'
#' @param x Una tabella di [rank_ccnl()] calcolata con `periodo`, oppure un
#'   oggetto `ccnlcob_result` prodotto da [analyze_ccnl()] (viene usato
#'   `x$ranking_periodo`). Deve contenere esattamente una colonna di
#'   periodo (`anno` o `trimestre`) e non più di una riga per CCNL e
#'   periodo.
#' @param measure Misura da rappresentare; devono essere presenti le
#'   colonne `measure` e `quota_measure`.
#' @param keys Vettore character delle chiavi `ccnl_key` da tracciare, al
#'   massimo 8 (limite della palette Okabe-Ito); `NULL` (default) usa
#'   `x$keys` per un `ccnlcob_result`, altrimenti i primi 6 CCNL per somma
#'   di `measure` sui periodi.
#' @param labels `data.table` opzionale con le colonne `ccnl_key` e
#'   `ccnl_titolo` per etichette leggibili; `NULL` usa `ccnl_key`.
#' @param quota Se `TRUE` (default) traccia `quota_measure` (asse in
#'   percentuale); se `FALSE` traccia il valore grezzo di `measure`.
#' @return Un oggetto `ggplot`.
#' @family grafici
#' @seealso [rank_ccnl()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   res <- analyze_ccnl(
#'     cob_esempio,
#'     window = as.Date(c("2022-01-01", "2024-12-31")),
#'     lookup_cpi = cpi_esempio,
#'     top_n = 8,
#'     min_n = 10
#'   )
#'   p <- plot_ranking_periodo(res, measure = "giornate")
#' }
plot_ranking_periodo <- function(
  x,
  measure = "giornate",
  keys = NULL,
  labels = NULL,
  quota = TRUE
) {
  .check_ggplot2()
  if (inherits(x, "ccnlcob_result")) {
    if (is.null(keys)) {
      keys <- x[["keys"]]
    }
    x <- x[["ranking_periodo"]]
    if (is.null(x)) {
      stop(
        "`x$ranking_periodo` \u00e8 NULL: eseguire prima analyze_ccnl().",
        call. = FALSE
      )
    }
  }
  if (!is.data.frame(x) || !"ccnl_key" %in% names(x)) {
    stop(
      "`x` deve essere una tabella di rank_ccnl(periodo = ...) o un ",
      "`ccnlcob_result`.",
      call. = FALSE
    )
  }
  if (!is.character(measure) || length(measure) != 1L || is.na(measure)) {
    stop("`measure` deve essere una singola stringa.", call. = FALSE)
  }
  if (!is.logical(quota) || length(quota) != 1L || is.na(quota)) {
    stop("`quota` deve essere TRUE o FALSE.", call. = FALSE)
  }
  periodo_col <- .periodo_column(x)
  qcol <- paste0("quota_", measure)
  cols_misura <- c(measure, qcol)
  mancanti <- setdiff(c("classe", cols_misura), names(x))
  if (length(mancanti) > 0L) {
    stop(
      "Misura `",
      measure,
      "` assente da `x`: servono le colonne ",
      paste(cols_misura, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  value_col <- if (isTRUE(quota)) qcol else measure

  dt <- data.table::as.data.table(x)
  dt <- dt[dt[["classe"]] == .classe_ccnl]

  if (is.null(keys)) {
    tot <- dt[, list(tot = sum(get(measure), na.rm = TRUE)), by = ccnl_key]
    data.table::setorderv(tot, "tot", order = -1L)
    keys <- utils::head(tot[["ccnl_key"]], 6L)
  }
  keys <- unique(as.character(keys))
  if (length(keys) > length(.okabe_ito)) {
    stop(
      "Troppe chiavi (",
      length(keys),
      ") per la palette Okabe-Ito (massimo ",
      length(.okabe_ito),
      "): ridurre `keys`.",
      call. = FALSE
    )
  }
  sel <- dt[dt[["ccnl_key"]] %in% keys]
  if (nrow(sel) == 0L) {
    stop("Nessuna riga per le chiavi indicate in `keys`.", call. = FALSE)
  }
  if (anyDuplicated(sel[, c("ccnl_key", periodo_col), with = FALSE]) > 0L) {
    stop(
      "`x` contiene pi\u00f9 righe per CCNL e periodo (probabile ",
      "raggruppamento aggiuntivo per `by`): filtrare a un solo gruppo ",
      "prima di chiamare plot_ranking_periodo().",
      call. = FALSE
    )
  }

  disp <- .apply_labels(keys, labels)
  sel[, ccnl_label := disp[ccnl_key]]
  sel[, valore_serie := get(value_col)]
  sel[,
    periodo_f := factor(
      get(periodo_col),
      levels = sort(unique(get(periodo_col)))
    )
  ]
  data.table::setorderv(sel, c("ccnl_label", periodo_col))
  ultimo <- sel[, .SD[.N], by = ccnl_label]
  gap_y <- 0.05 * diff(range(sel[["valore_serie"]], na.rm = TRUE))
  ultimo[, y_label := .spread_y(valore_serie, gap_y)]
  livelli_lab <- sort(unique(as.character(sel[["ccnl_label"]])))
  sel[, ccnl_label := factor(as.character(ccnl_label), levels = livelli_lab)]
  col_lab <- .text_safe(palette_ccnlcob(length(livelli_lab)))[
    match(as.character(ultimo[["ccnl_label"]]), livelli_lab)
  ]

  etichetta_y <- if (isTRUE(quota)) {
    paste0("Quota di ", gsub("_", " ", measure))
  } else {
    .cap1(gsub("_", " ", measure))
  }
  formato_y <- if (isTRUE(quota)) {
    function(v) sprintf("%.0f%%", v * 100)
  } else {
    function(v) {
      format(
        round(v),
        big.mark = ".",
        decimal.mark = ",",
        scientific = FALSE,
        trim = TRUE
      )
    }
  }

  ggplot2::ggplot(
    sel,
    ggplot2::aes(
      x = periodo_f,
      y = valore_serie,
      colour = ccnl_label,
      group = ccnl_label,
      linetype = ccnl_label,
      shape = ccnl_label
    )
  ) +
    ggplot2::geom_line(linewidth = 0.7, na.rm = TRUE) +
    ggplot2::geom_point(size = 1.9, na.rm = TRUE) +
    ggplot2::geom_text(
      data = ultimo,
      ggplot2::aes(y = y_label, label = ccnl_label),
      colour = col_lab,
      hjust = -0.08,
      size = 3.1,
      fontface = "bold",
      show.legend = FALSE
    ) +
    scale_colour_ccnlcob(guide = "none") +
    ggplot2::scale_linetype_discrete(guide = "none") +
    ggplot2::scale_shape_manual(values = .shape_vals, guide = "none") +
    ggplot2::scale_y_continuous(labels = formato_y) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = c(0.6, 2.4))) +
    ggplot2::labs(x = NULL, y = etichetta_y) +
    theme_ccnlcob() +
    ggplot2::theme(legend.position = "none")
}

# 5. Distribuzione per CPI -----

#' Mappa di calore CCNL per CPI
#'
#' Griglia CCNL (righe) per CPI (colonne) colorata su `lq` (quoziente di
#' localizzazione, scala divergente centrata su 1), `quota_colonna` o
#' `quota_riga` (scala sequenziale su un'unica tinta); in ogni caso la
#' scala è costruita sulla palette Okabe-Ito. Le colonne CPI sono
#' ordinate per totale decrescente, con `FUORI`/`ND` sempre in coda; oltre
#' `r .cpi_max_col` colonne l'asse diventa illeggibile, quindi vengono
#' mostrate solo le prime (più `FUORI`/`ND` se presenti). Le celle
#' grigie sono combinazioni assenti dai dati oppure, per `lq`, mascherate
#' da `min_n` in [ccnl_by_cpi()]; una didascalia lo ricorda.
#'
#' @param x Una tabella di [ccnl_by_cpi()], oppure un oggetto
#'   `ccnlcob_result` prodotto da [analyze_ccnl()] (viene usato `x$cpi`).
#' @param keys Vettore character delle chiavi `ccnl_key` da mostrare come
#'   righe; `NULL` (default) usa `x$keys` per un `ccnlcob_result`,
#'   altrimenti i primi 15 CCNL per totale della misura.
#' @param value Colonna da colorare: `"lq"` (default), `"quota_colonna"` o
#'   `"quota_riga"`.
#' @param labels `data.table` opzionale con le colonne `ccnl_key` e
#'   `ccnl_titolo` per etichette di riga leggibili; `NULL` usa `ccnl_key`.
#' @param cpi_labels Se `TRUE` (default) le colonne sono etichettate con
#'   `cpi_name`; se `FALSE` con `cpi_code`.
#' @return Un oggetto `ggplot`.
#' @family grafici
#' @seealso [ccnl_by_cpi()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   res <- analyze_ccnl(
#'     cob_esempio,
#'     window = as.Date(c("2022-01-01", "2024-12-31")),
#'     lookup_cpi = cpi_esempio,
#'     top_n = 8,
#'     min_n = 10
#'   )
#'   p <- plot_cpi(res, value = "lq")
#' }
plot_cpi <- function(
  x,
  keys = NULL,
  value = c("lq", "quota_colonna", "quota_riga"),
  labels = NULL,
  cpi_labels = TRUE
) {
  .check_ggplot2()
  value <- match.arg(value)
  if (
    !is.logical(cpi_labels) || length(cpi_labels) != 1L || is.na(cpi_labels)
  ) {
    stop("`cpi_labels` deve essere TRUE o FALSE.", call. = FALSE)
  }
  if (inherits(x, "ccnlcob_result")) {
    if (is.null(keys)) {
      keys <- x[["keys"]]
    }
    x <- x[["cpi"]]
    if (is.null(x)) {
      stop(
        "`x$cpi` \u00e8 NULL: la distribuzione per CPI non \u00e8 stata ",
        "calcolata da analyze_ccnl().",
        call. = FALSE
      )
    }
  }
  richieste <- c("ccnl_key", "classe", "cpi_code", "cpi_name", value)
  if (!is.data.frame(x) || !all(richieste %in% names(x))) {
    stop(
      "`x` deve essere una tabella di ccnl_by_cpi() con le colonne ",
      paste(richieste, collapse = ", "),
      ", oppure un `ccnlcob_result`.",
      call. = FALSE
    )
  }
  min_n_attr <- attr(x, "ccnlcob_crosstab")[["min_n"]]

  dt <- data.table::as.data.table(x)
  dt <- dt[dt[["classe"]] == .classe_ccnl]
  misura <- .detect_measure_col(dt)

  if (is.null(keys)) {
    if (is.na(misura)) {
      stop(
        "Impossibile determinare le chiavi di default (colonna di misura ",
        "non riconosciuta): fornire `keys` esplicitamente.",
        call. = FALSE
      )
    }
    tot_key <- dt[, list(tot = sum(get(misura), na.rm = TRUE)), by = ccnl_key]
    data.table::setorderv(tot_key, "tot", order = -1L)
    keys <- utils::head(tot_key[["ccnl_key"]], 15L)
  }
  keys <- unique(as.character(keys))
  dt <- dt[dt[["ccnl_key"]] %in% keys]
  if (nrow(dt) == 0L) {
    stop("Nessuna riga per le chiavi indicate in `keys`.", call. = FALSE)
  }

  colonna_tot <- if (!is.na(misura)) misura else value
  tot_cpi <- dt[,
    list(tot = sum(get(colonna_tot), na.rm = TRUE)),
    by = list(cpi_code, cpi_name)
  ]
  speciali <- tot_cpi[tot_cpi[["cpi_code"]] %in% c("FUORI", "ND")]
  normali <- tot_cpi[!tot_cpi[["cpi_code"]] %in% c("FUORI", "ND")]
  data.table::setorderv(normali, "tot", order = -1L)
  n_normali <- max(1L, .cpi_max_col - nrow(speciali))
  normali <- utils::head(normali, n_normali)
  tot_cpi_sel <- data.table::rbindlist(list(normali, speciali))
  ordine_cpi <- tot_cpi_sel[["cpi_code"]]

  griglia <- data.table::CJ(
    ccnl_key = keys,
    cpi_code = ordine_cpi,
    unique = TRUE,
    sorted = FALSE
  )
  celle <- dt[
    dt[["cpi_code"]] %in% ordine_cpi,
    c("ccnl_key", "cpi_code", value),
    with = FALSE
  ]
  data.table::setnames(celle, value, "valore_cella")
  griglia[celle, on = c("ccnl_key", "cpi_code"), valore_cella := i.valore_cella]

  disp <- .apply_labels(keys, labels)
  griglia[,
    ccnl_label := factor(disp[ccnl_key], levels = rev(unname(disp[keys])))
  ]
  etichette_cpi <- stats::setNames(
    tot_cpi_sel[["cpi_name"]],
    tot_cpi_sel[["cpi_code"]]
  )
  griglia[,
    cpi_f := factor(
      cpi_code,
      levels = ordine_cpi,
      labels = if (isTRUE(cpi_labels)) {
        unname(etichette_cpi[ordine_cpi])
      } else {
        ordine_cpi
      }
    )
  ]

  etichetta_valore <- switch(
    value,
    lq = "Quoziente di\nlocalizzazione",
    quota_colonna = "Quota di\ncolonna",
    quota_riga = "Quota di\nriga"
  )
  scala_fill <- if (identical(value, "lq")) {
    ggplot2::scale_fill_gradient2(
      low = .okabe_ito[["blu"]],
      mid = "white",
      high = .okabe_ito[["vermiglio"]],
      midpoint = 1,
      na.value = "grey85",
      name = etichetta_valore
    )
  } else {
    ggplot2::scale_fill_gradient(
      low = "#F2F8FC",
      high = .okabe_ito[["blu"]],
      na.value = "grey85",
      labels = function(v) sprintf("%.0f%%", v * 100),
      name = etichetta_valore
    )
  }
  didascalia <- if (
    identical(value, "lq") && !is.null(min_n_attr) && !is.na(min_n_attr)
  ) {
    sprintf(
      "Celle grigie: combinazione assente oppure numerosit\u00e0 sotto la soglia min_n = %s.",
      format(min_n_attr)
    )
  } else {
    "Celle grigie: combinazione assente dai dati."
  }

  ggplot2::ggplot(
    griglia,
    ggplot2::aes(x = cpi_f, y = ccnl_label, fill = valore_cella)
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.3) +
    scala_fill +
    ggplot2::labs(x = NULL, y = NULL, caption = didascalia) +
    theme_ccnlcob() +
    ggplot2::theme(legend.title = ggplot2::element_text(size = ggplot2::rel(0.9))) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(
        angle = 45,
        hjust = 1,
        size = ggplot2::rel(0.8)
      )
    )
}

# 6. Distribuzione per tipologia -----

#' Barre impilate della distribuzione per tipologia contrattuale
#'
#' Barre orizzontali impilate di `quota_riga` per macro-tipologia
#' contrattuale, una per CCNL selezionato. Le nove macro-tipologie di
#' [tipologie_contrattuali] superano la capienza sicura di una palette
#' categoriale (8 colori): la funzione mantiene le 6 più rilevanti fra i
#' dati mostrati e accorpa le altre in `"Altre tipologie"`. Le percentuali
#' oltre l'8% sono stampate direttamente nel segmento, con un colore del
#' testo (bianco o quasi nero) scelto automaticamente per contrasto sullo
#' sfondo del segmento.
#'
#' @param x Una tabella di [ccnl_by_tipologia()], oppure un oggetto
#'   `ccnlcob_result` prodotto da [analyze_ccnl()] (viene usato
#'   `x$tipologie`).
#' @param keys Vettore character delle chiavi `ccnl_key` da mostrare;
#'   `NULL` (default) usa `x$keys` per un `ccnlcob_result`, altrimenti i
#'   primi 15 CCNL per totale della misura.
#' @param labels `data.table` opzionale con le colonne `ccnl_key` e
#'   `ccnl_titolo` per etichette leggibili; `NULL` usa `ccnl_key`.
#' @param orario Se `TRUE` sfaccetta il grafico per `orario` (richiede la
#'   colonna `orario` in `x`, prodotta da
#'   `ccnl_by_tipologia(orario = TRUE)`); se `FALSE` (default) somma le
#'   quote sull'orario.
#' @return Un oggetto `ggplot`.
#' @family grafici
#' @seealso [ccnl_by_tipologia()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   res <- analyze_ccnl(
#'     cob_esempio,
#'     window = as.Date(c("2022-01-01", "2024-12-31")),
#'     lookup_cpi = cpi_esempio,
#'     top_n = 8,
#'     min_n = 10
#'   )
#'   p <- plot_tipologie(res)
#' }
plot_tipologie <- function(x, keys = NULL, labels = NULL, orario = FALSE) {
  .check_ggplot2()
  if (!is.logical(orario) || length(orario) != 1L || is.na(orario)) {
    stop("`orario` deve essere TRUE o FALSE.", call. = FALSE)
  }
  if (inherits(x, "ccnlcob_result")) {
    if (is.null(keys)) {
      keys <- x[["keys"]]
    }
    x <- x[["tipologie"]]
    if (is.null(x)) {
      stop(
        "`x$tipologie` \u00e8 NULL: la distribuzione per tipologia non \u00e8 ",
        "stata calcolata da analyze_ccnl().",
        call. = FALSE
      )
    }
  }
  richieste <- c("ccnl_key", "classe", "tipologia", "quota_riga")
  if (!is.data.frame(x) || !all(richieste %in% names(x))) {
    stop(
      "`x` deve essere una tabella di ccnl_by_tipologia() con le colonne ",
      paste(richieste, collapse = ", "),
      ", oppure un `ccnlcob_result`.",
      call. = FALSE
    )
  }
  if (isTRUE(orario) && !"orario" %in% names(x)) {
    stop(
      "`x` non contiene la colonna `orario`: richiamare ",
      "ccnl_by_tipologia(orario = TRUE) oppure usare orario = FALSE.",
      call. = FALSE
    )
  }

  dt <- data.table::as.data.table(x)
  dt <- dt[dt[["classe"]] == .classe_ccnl]
  misura <- .detect_measure_col(dt)
  colonna_tot <- if (!is.na(misura)) misura else "quota_riga"

  if (is.null(keys)) {
    tot_key <- dt[,
      list(tot = sum(get(colonna_tot), na.rm = TRUE)),
      by = ccnl_key
    ]
    data.table::setorderv(tot_key, "tot", order = -1L)
    keys <- utils::head(tot_key[["ccnl_key"]], 15L)
  }
  keys <- unique(as.character(keys))
  dt <- dt[dt[["ccnl_key"]] %in% keys]
  if (nrow(dt) == 0L) {
    stop("Nessuna riga per le chiavi indicate in `keys`.", call. = FALSE)
  }

  tot_tip <- dt[,
    list(tot = sum(get(colonna_tot), na.rm = TRUE)),
    by = tipologia
  ]
  data.table::setorderv(tot_tip, "tot", order = -1L)
  top_tip <- utils::head(tot_tip[["tipologia"]], 6L)
  dt[,
    tipologia_plot := data.table::fifelse(
      tipologia %in% top_tip,
      tipologia,
      "Altre tipologie"
    )
  ]

  grp_cols <- c("ccnl_key", if (isTRUE(orario)) "orario", "tipologia_plot")
  agg <- dt[, list(quota_riga = sum(quota_riga, na.rm = TRUE)), by = grp_cols]

  disp <- .apply_labels(keys, labels)
  agg[, ccnl_label := factor(disp[ccnl_key], levels = rev(unname(disp[keys])))]
  livelli_tip <- c(
    top_tip[top_tip %in% agg[["tipologia_plot"]]],
    if ("Altre tipologie" %in% agg[["tipologia_plot"]]) "Altre tipologie"
  )
  agg[, tipologia_plot := factor(tipologia_plot, levels = livelli_tip)]
  if (isTRUE(orario)) {
    livelli_orario <- intersect(c("FT", "PT", "ND"), unique(agg[["orario"]]))
    livelli_orario <- union(livelli_orario, sort(unique(agg[["orario"]])))
    agg[, orario := factor(orario, levels = livelli_orario)]
  }

  pal <- palette_ccnlcob(length(livelli_tip))
  names(pal) <- livelli_tip
  agg[, fill_hex := pal[as.character(tipologia_plot)]]
  agg[, txt_col := .text_contrast(fill_hex)]
  agg[,
    testo := data.table::fifelse(
      quota_riga > 0.08,
      sprintf("%.0f%%", quota_riga * 100),
      ""
    )
  ]

  p <- ggplot2::ggplot(
    agg,
    ggplot2::aes(x = ccnl_label, y = quota_riga, fill = tipologia_plot)
  ) +
    ggplot2::geom_col(width = 0.72, position = "stack") +
    ggplot2::geom_text(
      ggplot2::aes(label = testo, colour = txt_col),
      position = ggplot2::position_stack(vjust = 0.5),
      size = 3.0,
      fontface = "bold"
    ) +
    ggplot2::scale_fill_manual(values = pal, name = "Tipologia") +
    ggplot2::scale_colour_identity(guide = "none") +
    ggplot2::scale_y_continuous(labels = function(v) {
      sprintf("%.0f%%", v * 100)
    }) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "Quota di riga") +
    theme_ccnlcob() +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

  if (isTRUE(orario)) {
    p <- p + ggplot2::facet_wrap(~orario)
  }
  p
}

# 7. Retribuzioni -----

#' Andamento della retribuzione mediana per periodo
#'
#' Linee della retribuzione mediana per periodo di avviamento, una per CCNL
#' selezionato, con banda p25-p75 opzionale. I periodi mascherati (mediana
#' `NA`) sono omessi; i periodi con `copertura` sotto `copertura_min` sono
#' disegnati con punto vuoto (contorno colorato, riempimento bianco)
#' invece che pieno, come codifica ridondante della bassa affidabilità
#' del dato rispetto al solo colore della serie. L'asse verticale è
#' formattato in euro con il punto come separatore delle migliaia.
#'
#' @param x Una tabella di [median_retribuzione()] o
#'   [deflate_retribuzione()], oppure un oggetto `ccnlcob_result` prodotto
#'   da [analyze_ccnl()] (viene usato `x$retribuzioni`).
#' @param keys Vettore character delle chiavi `ccnl_key` da tracciare, al
#'   massimo 8 (limite della palette Okabe-Ito); `NULL` (default) usa
#'   `x$keys` per un `ccnlcob_result`, altrimenti i primi 6 CCNL per somma
#'   di `giornate`.
#' @param labels `data.table` opzionale con le colonne `ccnl_key` e
#'   `ccnl_titolo` per etichette leggibili; `NULL` usa `ccnl_key`.
#' @param reale Se `TRUE` usa le colonne `_reale` prodotte da
#'   [deflate_retribuzione()] (`p25_reale`, `mediana_reale`, `p75_reale`);
#'   se `FALSE` (default) usa i valori correnti.
#' @param banda Se `TRUE` (default) disegna la banda p25-p75 come area
#'   semitrasparente intorno alla mediana.
#' @param copertura_min Soglia di `copertura` sotto la quale un punto è
#'   disegnato vuoto; `NULL` (default) disegna tutti i punti pieni.
#' @return Un oggetto `ggplot`.
#' @family grafici
#' @seealso [median_retribuzione()], [deflate_retribuzione()].
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   res <- analyze_ccnl(
#'     cob_esempio,
#'     window = as.Date(c("2022-01-01", "2024-12-31")),
#'     lookup_cpi = cpi_esempio,
#'     top_n = 8,
#'     min_n = 10
#'   )
#'   p <- plot_retribuzioni(res, copertura_min = 0.5)
#' }
plot_retribuzioni <- function(
  x,
  keys = NULL,
  labels = NULL,
  reale = FALSE,
  banda = TRUE,
  copertura_min = NULL
) {
  .check_ggplot2()
  if (!is.logical(reale) || length(reale) != 1L || is.na(reale)) {
    stop("`reale` deve essere TRUE o FALSE.", call. = FALSE)
  }
  if (!is.logical(banda) || length(banda) != 1L || is.na(banda)) {
    stop("`banda` deve essere TRUE o FALSE.", call. = FALSE)
  }
  if (!is.null(copertura_min)) {
    if (
      !is.numeric(copertura_min) ||
        length(copertura_min) != 1L ||
        is.na(copertura_min) ||
        copertura_min < 0 ||
        copertura_min > 1
    ) {
      stop(
        "`copertura_min` deve essere NULL o un numero in [0, 1].",
        call. = FALSE
      )
    }
  }
  if (inherits(x, "ccnlcob_result")) {
    if (is.null(keys)) {
      keys <- x[["keys"]]
    }
    x <- x[["retribuzioni"]]
    if (is.null(x)) {
      stop(
        "`x$retribuzioni` \u00e8 NULL: le retribuzioni non sono state ",
        "calcolate da analyze_ccnl().",
        call. = FALSE
      )
    }
  }
  if (!is.data.frame(x)) {
    stop(
      "`x` deve essere una tabella di median_retribuzione()/",
      "deflate_retribuzione(), oppure un `ccnlcob_result`.",
      call. = FALSE
    )
  }
  periodo_col <- .periodo_column(x)
  suffisso <- if (isTRUE(reale)) "_reale" else ""
  cols_val <- paste0(c("p25", "mediana", "p75"), suffisso)
  richieste <- c("ccnl_key", "classe", "copertura", cols_val)
  mancanti <- setdiff(richieste, names(x))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti in `x`: ",
      paste(mancanti, collapse = ", "),
      if (isTRUE(reale)) {
        ". Applicare prima deflate_retribuzione()."
      } else {
        ". Applicare prima median_retribuzione()."
      },
      call. = FALSE
    )
  }

  dt <- data.table::as.data.table(x)
  dt <- dt[dt[["classe"]] == .classe_ccnl]

  if (is.null(keys)) {
    colonna_tot <- if ("giornate" %in% names(dt)) "giornate" else cols_val[2L]
    tot <- dt[, list(tot = sum(get(colonna_tot), na.rm = TRUE)), by = ccnl_key]
    data.table::setorderv(tot, "tot", order = -1L)
    keys <- utils::head(tot[["ccnl_key"]], 6L)
  }
  keys <- unique(as.character(keys))
  if (length(keys) > length(.okabe_ito)) {
    stop(
      "Troppe chiavi (",
      length(keys),
      ") per la palette Okabe-Ito (massimo ",
      length(.okabe_ito),
      "): ridurre `keys`.",
      call. = FALSE
    )
  }
  sel <- dt[dt[["ccnl_key"]] %in% keys]
  if (nrow(sel) == 0L) {
    stop("Nessuna riga per le chiavi indicate in `keys`.", call. = FALSE)
  }
  if (anyDuplicated(sel[, c("ccnl_key", periodo_col), with = FALSE]) > 0L) {
    stop(
      "`x` contiene pi\u00f9 righe per CCNL e periodo (probabile ",
      "raggruppamento aggiuntivo per `by`): filtrare a un solo gruppo ",
      "prima di chiamare plot_retribuzioni().",
      call. = FALSE
    )
  }

  sel[, mediana_v := get(cols_val[2L])]
  sel[, p25_v := get(cols_val[1L])]
  sel[, p75_v := get(cols_val[3L])]
  sel <- sel[!is.na(mediana_v)]
  if (nrow(sel) == 0L) {
    stop(
      "Tutti i periodi selezionati sono mascherati (mediana mancante).",
      call. = FALSE
    )
  }
  sel[,
    bassa_copertura := if (!is.null(copertura_min)) {
      copertura < copertura_min
    } else {
      FALSE
    }
  ]

  disp <- .apply_labels(keys, labels)
  sel[, ccnl_label := disp[ccnl_key]]
  sel[,
    periodo_f := factor(
      get(periodo_col),
      levels = sort(unique(get(periodo_col)))
    )
  ]
  data.table::setorderv(sel, c("ccnl_label", periodo_col))
  ultimo <- sel[, .SD[.N], by = ccnl_label]
  gap_y <- 0.05 * diff(range(sel[["mediana_v"]], na.rm = TRUE))
  ultimo[, y_label := .spread_y(mediana_v, gap_y)]
  livelli_lab <- sort(unique(as.character(sel[["ccnl_label"]])))
  sel[, ccnl_label := factor(as.character(ccnl_label), levels = livelli_lab)]
  col_lab <- .text_safe(palette_ccnlcob(length(livelli_lab)))[
    match(as.character(ultimo[["ccnl_label"]]), livelli_lab)
  ]

  p <- ggplot2::ggplot(
    sel,
    ggplot2::aes(
      x = periodo_f,
      y = mediana_v,
      colour = ccnl_label,
      group = ccnl_label
    )
  )
  if (isTRUE(banda)) {
    p <- p +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = p25_v, ymax = p75_v, fill = ccnl_label),
        alpha = 0.15,
        colour = NA,
        na.rm = TRUE
      )
  }
  p <- p +
    ggplot2::geom_line(
      ggplot2::aes(linetype = ccnl_label),
      linewidth = 0.7,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(
      data = sel[sel[["bassa_copertura"]] == FALSE],
      shape = 16,
      size = 1.9,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(
      data = sel[sel[["bassa_copertura"]] == TRUE],
      shape = 21,
      fill = "white",
      size = 1.9,
      stroke = 0.9,
      na.rm = TRUE
    ) +
    ggplot2::geom_text(
      data = ultimo,
      ggplot2::aes(y = y_label, label = ccnl_label),
      colour = col_lab,
      hjust = -0.06,
      size = 3.1,
      fontface = "bold",
      show.legend = FALSE
    ) +
    scale_colour_ccnlcob(guide = "none") +
    scale_fill_ccnlcob(guide = "none") +
    ggplot2::scale_linetype_discrete(guide = "none") +
    ggplot2::scale_y_continuous(labels = .formato_euro) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = c(0.6, 2.6))) +
    ggplot2::labs(
      x = NULL,
      y = if (isTRUE(reale)) {
        "Retribuzione mediana (valori reali)"
      } else {
        "Retribuzione mediana"
      },
      caption = if (!is.null(copertura_min)) {
        sprintf("Punti vuoti: copertura < %.0f%%.", copertura_min * 100)
      } else {
        NULL
      }
    ) +
    theme_ccnlcob() +
    ggplot2::theme(legend.position = "none")
  p
}

# 8. Helper interni -----

#' Verifica la disponibilità di ggplot2
#'
#' @return `TRUE`, invisibilmente; errore se `ggplot2` non è installato.
#' @keywords internal
#' @noRd
.check_ggplot2 <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop(
      "Il pacchetto `ggplot2` \u00e8 richiesto per le funzioni grafiche di ",
      "ccnlcob e non risulta installato. Installarlo con ",
      "install.packages(\"ggplot2\").",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Distanzia verticalmente le etichette di fine linea
#'
#' Respingimento monodimensionale: ordina i valori e impone una distanza
#' minima `gap` fra etichette consecutive, restituendo le posizioni
#' nell'ordine originale, ricentrate sulla media dei valori originali.
#'
#' @param y Vettore numerico delle posizioni originali.
#' @param gap Distanza minima fra etichette consecutive (unit\u00e0 di `y`).
#' @return Vettore numerico della stessa lunghezza di `y`.
#' @keywords internal
#' @noRd
.spread_y <- function(y, gap) {
  out <- y
  ok <- which(!is.na(y))
  if (length(ok) < 2L || !is.finite(gap) || gap <= 0) {
    return(out)
  }
  o <- ok[order(y[ok])]
  v <- y[o]
  for (i in seq_along(v)[-1L]) {
    if (v[i] - v[i - 1L] < gap) {
      v[i] <- v[i - 1L] + gap
    }
  }
  v <- v - (mean(v) - mean(y[o]))
  out[o] <- v
  out
}

#' Applica etichette leggibili a un vettore di chiavi CCNL
#'
#' @param keys Vettore character di `ccnl_key`.
#' @param labels `NULL`, oppure un `data.table` con le colonne `ccnl_key` e
#'   `ccnl_titolo`; il titolo è troncato a 44 caratteri (più ellissi) e
#'   seguito dalla chiave fra parentesi.
#' @return Vettore character con `names` uguali a `keys`, nello stesso
#'   ordine; senza `labels` coincide con `keys`.
#' @keywords internal
#' @noRd
.apply_labels <- function(keys, labels) {
  keys <- as.character(keys)
  out <- keys
  if (!is.null(labels)) {
    if (
      !is.data.frame(labels) ||
        !all(c("ccnl_key", "ccnl_titolo") %in% names(labels))
    ) {
      stop(
        "`labels` deve essere un data.table con le colonne `ccnl_key` e ",
        "`ccnl_titolo`.",
        call. = FALSE
      )
    }
    pos <- match(keys, as.character(labels[["ccnl_key"]]))
    trovati <- !is.na(pos)
    if (any(trovati)) {
      titolo <- as.character(labels[["ccnl_titolo"]])[pos[trovati]]
      troncato <- ifelse(
        nchar(titolo) > 45L,
        paste0(substr(titolo, 1L, 44L), "\u2026"),
        titolo
      )
      out[trovati] <- paste0(troncato, " (", keys[trovati], ")")
    }
  }
  stats::setNames(out, keys)
}

#' Individua la colonna di misura in una tabella di crosstab
#'
#' @param dt Un `data.table` prodotto da [ccnl_by_cpi()] o
#'   [ccnl_by_tipologia()].
#' @return La singola colonna di `dt` presente fra `.ranking_measures`;
#'   `NA_character_` se nessuna o più di una sono presenti.
#' @keywords internal
#' @noRd
.detect_measure_col <- function(dt) {
  trovate <- intersect(names(dt), .ranking_measures)
  if (length(trovate) == 1L) trovate else NA_character_
}

#' Individua la colonna di periodo di una tabella
#'
#' @param dt Un `data.frame`.
#' @return `"anno"` o `"trimestre"`; errore se non ne è presente
#'   esattamente una.
#' @keywords internal
#' @noRd
.periodo_column <- function(dt) {
  presenti <- intersect(c("anno", "trimestre"), names(dt))
  if (length(presenti) != 1L) {
    stop(
      "`x` deve contenere esattamente una colonna di periodo fra `anno` e ",
      "`trimestre`.",
      call. = FALSE
    )
  }
  presenti
}

#' Formatta un vettore numerico come importo in euro
#'
#' @param x Vettore numeric.
#' @return Vettore character, con punto come separatore delle migliaia e
#'   simbolo dell'euro; `""` dove `x` è `NA`.
#' @keywords internal
#' @noRd
.formato_euro <- function(x) {
  ifelse(
    is.na(x),
    "",
    paste0(
      format(
        round(x),
        big.mark = ".",
        decimal.mark = ",",
        scientific = FALSE,
        trim = TRUE
      ),
      " \u20ac"
    )
  )
}

#' Luminanza relativa di colori esadecimali
#' @param hex Vettore di colori `#RRGGBB`.
#' @return Vettore numerico in `[0, 1]`.
#' @keywords internal
#' @noRd
.luminanza <- function(hex) {
  componenti <- vapply(
    hex,
    function(h) {
      h <- sub("^#", "", h)
      c(
        strtoi(substr(h, 1L, 2L), base = 16L),
        strtoi(substr(h, 3L, 4L), base = 16L),
        strtoi(substr(h, 5L, 6L), base = 16L)
      ) /
        255
    },
    numeric(3)
  )
  rgb <- t(componenti)
  lin <- ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  unname(0.2126 * lin[, 1] + 0.7152 * lin[, 2] + 0.0722 * lin[, 3])
}

#' Scurisce i colori usati come testo finch\u00e9 il contrasto su bianco
#' raggiunge la soglia
#'
#' Il giallo della palette Okabe-Ito ha contrasto ~1,6:1 su bianco: come
#' colore di testo va scurito. Ogni colore viene ridotto in RGB del 8% per
#' passo fino a contrasto `>= target` (WCAG: (L1 + 0,05) / (L2 + 0,05)).
#'
#' @param hex Vettore di colori `#RRGGBB`.
#' @param target Contrasto minimo richiesto (default 4,5).
#' @return Vettore di colori `#RRGGBB` della stessa lunghezza.
#' @keywords internal
#' @noRd
.text_safe <- function(hex, target = 4.5) {
  vapply(
    hex,
    function(h) {
      rgb <- c(
        strtoi(substr(sub("^#", "", h), 1L, 2L), base = 16L),
        strtoi(substr(sub("^#", "", h), 3L, 4L), base = 16L),
        strtoi(substr(sub("^#", "", h), 5L, 6L), base = 16L)
      )
      out <- h
      for (i in seq_len(40L)) {
        if ((1 + 0.05) / (.luminanza(out) + 0.05) >= target) {
          break
        }
        rgb <- floor(rgb * 0.92)
        out <- sprintf("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
      }
      out
    },
    character(1),
    USE.NAMES = FALSE
  )
}

#' Colore del testo (bianco o quasi nero) a contrasto su uno sfondo
#'
#' Calcola la luminanza relativa WCAG dello sfondo e sceglie fra un testo
#' quasi nero e uno bianco, così che l'etichetta resti leggibile su
#' qualunque colore della palette Okabe-Ito.
#'
#' @param hex Vettore character di colori esadecimali (`"#RRGGBB"`).
#' @return Vettore character della stessa lunghezza, `"#1A1A1A"` o
#'   `"#FFFFFF"`.
#' @keywords internal
#' @noRd
.text_contrast <- function(hex) {
  componenti <- vapply(
    hex,
    function(h) {
      h <- sub("^#", "", h)
      c(
        strtoi(substr(h, 1L, 2L), base = 16L),
        strtoi(substr(h, 3L, 4L), base = 16L),
        strtoi(substr(h, 5L, 6L), base = 16L)
      ) /
        255
    },
    numeric(3)
  )
  rgb <- t(componenti)
  lin <- ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  lum <- 0.2126 * lin[, 1] + 0.7152 * lin[, 2] + 0.0722 * lin[, 3]
  ifelse(lum > 0.5, "#1A1A1A", "#FFFFFF")
}

#' Maiuscola la prima lettera di una stringa
#'
#' @param s Vettore character.
#' @return Vettore character con la prima lettera maiuscola.
#' @keywords internal
#' @noRd
.cap1 <- function(s) {
  paste0(toupper(substr(s, 1L, 1L)), substr(s, 2L, nchar(s)))
}
