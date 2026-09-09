# 1. Report Quarto -----

# File del contratto di uscita che devono esistere in `dir` per il report.
.file_report_richiesti <- c("meta.rds", "ranking.rds")

#' Genera il report HTML dei risultati di analyze_ccnl()
#'
#' Esegue il template Quarto parametrico del pacchetto
#' (`inst/quarto/report_ccnl.qmd`) sulla directory prodotta da
#' [write_results()] e produce un file HTML autonomo (risorse incorporate)
#' con classifica dei CCNL, andamento per periodo, distribuzione per CPI e
#' per tipologia contrattuale, retribuzioni mediane, indicatori di qualità
#' e note metodologiche. Le sezioni i cui dati non sono presenti nella
#' directory (per esempio `cpi` quando il passo è stato saltato) vengono
#' sostituite da una frase esplicativa.
#'
#' @param dir Directory scritta da [write_results()]; devono esistere almeno
#'   `meta.rds` e `ranking.rds`.
#' @param output_file Percorso del file HTML da produrre; `NULL` (default)
#'   scrive `report_ccnl.html` dentro `dir`. La directory di destinazione
#'   viene creata se assente.
#' @param titolo Titolo del report.
#' @param labels Etichette leggibili dei CCNL: `NULL` (default, usa le
#'   chiavi), un `data.frame` con le colonne `ccnl_key` (o `codice_cnel`) e
#'   `ccnl_titolo`, oppure il percorso di un file RDS con la stessa
#'   struttura. Le chiavi duplicate vengono ridotte alla prima occorrenza.
#' @param top_n Numero massimo di CCNL nelle classifiche e nelle tabelle;
#'   i grafici a linee ne mostrano al più 8 (capienza della palette).
#' @param note Testo libero (character di lunghezza 1) mostrato in apertura
#'   come nota; `NULL` per ometterlo.
#' @param quiet Se `TRUE` (default) sopprime l'output di Quarto; altrimenti
#'   la funzione emette anche un `message()` con il tempo impiegato.
#'
#' @details
#' La funzione richiede il pacchetto R `quarto` e la Quarto CLI (individuata
#' con `quarto::quarto_path()`), oltre a `ggplot2` e `knitr` per i grafici e
#' le tabelle; sono tutti in `Suggests`. Il template viene copiato in una
#' directory temporanea, perché Quarto scrive l'HTML accanto al file `.qmd`,
#' e il risultato viene poi spostato in `output_file`. Il template legge le
#' tabelle con [readRDS()] o `fst::read_fst()` e ripristina gli attributi
#' `ccnlcob_*` da `meta$attributi`.
#'
#' @return Il percorso di `output_file`, invisibilmente, con l'attributo
#'   `secondi` (tempo di esecuzione).
#' @family report
#' @seealso [write_results()] per produrre `dir`; [plot_ranking()],
#'   [plot_cpi()], [plot_tipologie()], [plot_retribuzioni()] per i grafici
#'   usati dal template.
#' @export
#' @examples
#' # il template usato dal report
#' system.file("quarto", "report_ccnl.qmd", package = "ccnlcob")
#'
#' \dontrun{
#' # richiede la Quarto CLI
#' res <- analyze_ccnl(cob_esempio, lookup_cpi = cpi_esempio, min_n = 10)
#' dir_out <- file.path(tempdir(), "ccnl_report")
#' write_results(res, dir = dir_out, overwrite = TRUE)
#' html <- render_report(dir_out, titolo = "CCNL: dati di esempio")
#' browseURL(html)
#' }
render_report <- function(
  dir,
  output_file = NULL,
  titolo = "Analisi dei CCNL sui dati COB",
  labels = NULL,
  top_n = 15,
  note = NULL,
  quiet = TRUE
) {
  # 1.1 Controlli sugli argomenti -----
  if (!is.character(dir) || length(dir) != 1L || is.na(dir) || dir == "") {
    stop("`dir` deve essere un singolo percorso.", call. = FALSE)
  }
  if (!dir.exists(dir)) {
    stop("Directory non trovata: ", dir, call. = FALSE)
  }
  mancanti <- .file_report_richiesti[
    !file.exists(file.path(dir, .file_report_richiesti))
  ]
  if (length(mancanti) > 0L) {
    stop(
      "`dir` non contiene i file richiesti (prodotti da write_results()): ",
      paste(mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (is.null(output_file)) {
    output_file <- file.path(dir, "report_ccnl.html")
  }
  if (
    !is.character(output_file) ||
      length(output_file) != 1L ||
      is.na(output_file) ||
      output_file == ""
  ) {
    stop("`output_file` deve essere NULL o un singolo percorso.", call. = FALSE)
  }
  if (!is.character(titolo) || length(titolo) != 1L || is.na(titolo)) {
    stop("`titolo` deve essere una singola stringa.", call. = FALSE)
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
  if (
    !is.null(note) &&
      (!is.character(note) || length(note) != 1L || is.na(note))
  ) {
    stop("`note` deve essere NULL o una singola stringa.", call. = FALSE)
  }
  if (!is.logical(quiet) || length(quiet) != 1L || is.na(quiet)) {
    stop("`quiet` deve essere TRUE o FALSE.", call. = FALSE)
  }
  labels <- .normalize_labels(labels)

  # 1.2 Dipendenze -----
  for (pkg in c("quarto", "knitr", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Il pacchetto `",
        pkg,
        "` \u00e8 richiesto da render_report() e non risulta installato: ",
        "install.packages(\"",
        pkg,
        "\").",
        call. = FALSE
      )
    }
  }
  if (is.null(quarto::quarto_path())) {
    stop(
      "La Quarto CLI non \u00e8 stata trovata (quarto::quarto_path() ",
      "restituisce NULL). Installarla da <https://quarto.org/> o impostare ",
      "la variabile d'ambiente QUARTO_PATH.",
      call. = FALSE
    )
  }
  template <- system.file("quarto", "report_ccnl.qmd", package = "ccnlcob")
  if (!nzchar(template)) {
    stop(
      "Template `quarto/report_ccnl.qmd` non trovato nel pacchetto ccnlcob.",
      call. = FALSE
    )
  }

  # 1.3 Rendering in una directory temporanea -----
  t0 <- proc.time()[["elapsed"]]
  work <- tempfile("ccnlcob_report_")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  qmd <- file.path(work, "report_ccnl.qmd")
  file.copy(template, qmd)

  labels_file <- ""
  if (!is.null(labels)) {
    labels_file <- file.path(work, "labels.rds")
    saveRDS(labels, labels_file)
  }
  parametri <- list(
    dir = normalizePath(dir, winslash = "/", mustWork = TRUE),
    titolo = titolo,
    labels = labels_file,
    top_n = as.integer(top_n),
    note = if (is.null(note)) "" else note,
    pkg_dev = .pkg_dev_root()
  )
  quarto::quarto_render(
    input = qmd,
    output_format = "html",
    execute_params = parametri,
    quiet = quiet
  )
  html <- file.path(work, "report_ccnl.html")
  if (!file.exists(html)) {
    stop(
      "Quarto non ha prodotto il file HTML atteso: ",
      html,
      ".",
      call. = FALSE
    )
  }

  # 1.4 Spostamento nel percorso di destinazione -----
  dest_dir <- dirname(output_file)
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
  }
  if (!file.copy(html, output_file, overwrite = TRUE)) {
    stop("Impossibile scrivere il report in ", output_file, ".", call. = FALSE)
  }
  secondi <- proc.time()[["elapsed"]] - t0
  if (!quiet) {
    message(
      "render_report(): report scritto in ",
      output_file,
      " (",
      format(round(secondi, 1), nsmall = 1),
      " s)."
    )
  }
  out <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
  attr(out, "secondi") <- secondi
  invisible(out)
}

# 2. Helper interni -----

#' Radice del pacchetto quando è caricato con pkgload::load_all()
#'
#' Quarto esegue il template in un processo R separato, dove un pacchetto
#' caricato con `devtools::load_all()` non è visibile: in quel caso il
#' template lo ricarica dalla sorgente. Con il pacchetto installato la
#' funzione restituisce `""` e il template usa `library(ccnlcob)`.
#'
#' @return Percorso della radice della sorgente, oppure `""`.
#' @keywords internal
#' @noRd
.pkg_dev_root <- function() {
  if (
    requireNamespace("pkgload", quietly = TRUE) &&
      isTRUE(pkgload::is_dev_package("ccnlcob"))
  ) {
    # sotto pkgload system.file(package = ) restituisce <radice>/inst
    return(normalizePath(
      dirname(system.file(package = "ccnlcob")),
      winslash = "/",
      mustWork = FALSE
    ))
  }
  ""
}

#' Normalizza l'argomento `labels` di render_report()
#'
#' @param labels `NULL`, un `data.frame` con `ccnl_key` (o `codice_cnel`) e
#'   `ccnl_titolo`, oppure il percorso di un file RDS.
#' @return `NULL` oppure un `data.table` con le sole colonne `ccnl_key` e
#'   `ccnl_titolo`, una riga per chiave.
#' @keywords internal
#' @noRd
.normalize_labels <- function(labels) {
  if (is.null(labels)) {
    return(NULL)
  }
  if (is.character(labels)) {
    if (length(labels) != 1L || is.na(labels)) {
      stop(
        "`labels` deve essere NULL, un data.frame o il percorso di un file RDS.",
        call. = FALSE
      )
    }
    if (!file.exists(labels)) {
      stop("File `labels` non trovato: ", labels, call. = FALSE)
    }
    labels <- readRDS(labels)
  }
  if (!is.data.frame(labels)) {
    stop(
      "`labels` deve essere NULL, un data.frame o il percorso di un file RDS.",
      call. = FALSE
    )
  }
  dt <- data.table::as.data.table(labels)
  if (!"ccnl_key" %in% names(dt) && "codice_cnel" %in% names(dt)) {
    data.table::setnames(dt, "codice_cnel", "ccnl_key")
  }
  if (!all(c("ccnl_key", "ccnl_titolo") %in% names(dt))) {
    stop(
      "`labels` deve contenere le colonne `ccnl_key` (o `codice_cnel`) e ",
      "`ccnl_titolo`.",
      call. = FALSE
    )
  }
  dt <- dt[, c("ccnl_key", "ccnl_titolo"), with = FALSE]
  dt[, ccnl_key := as.character(ccnl_key)]
  dt[, ccnl_titolo := as.character(ccnl_titolo)]
  dt <- dt[!is.na(ccnl_key)]
  unique(dt, by = "ccnl_key")[]
}
