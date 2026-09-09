# 1. Quantile ponderato -----

#' Quantile ponderato
#'
#' Calcola uno o più quantili di `x` con pesi `w` a partire dalla funzione di
#' ripartizione ponderata a gradini: il quantile è il valore ordinato il cui
#' blocco di peso cumulato contiene `probs * sum(w)`; se il target cade
#' esattamente sul confine fra due blocchi viene restituita la media dei due
#' valori adiacenti. Proprietà: con pesi uniformi coincide con
#' `stats::quantile(type = 2)` e, per `probs = 0.5`, con `stats::median()`;
#' con pesi interi coincide con il quantile del campione espanso; il
#' risultato è invariante alla suddivisione del peso di un valore su più
#' righe. Equivale a `matrixStats::weightedMedian(interpolate = FALSE)`.
#'
#' @param x Vettore numerico.
#' @param w Vettore numerico di pesi non negativi della stessa lunghezza di
#'   `x`; `NULL` equivale a pesi uniformi.
#' @param probs Vettore di probabilità in `[0, 1]`.
#' @param na.rm Se `TRUE` (default) le coppie con `x` o `w` mancanti, o con
#'   peso nullo, vengono escluse; se `FALSE` la presenza di `NA` produce `NA`.
#' @return Vettore numerico della stessa lunghezza di `probs`; `NA` se non
#'   restano osservazioni valide.
#' @keywords internal
#' @noRd
.wquantile <- function(x, w = NULL, probs = 0.5, na.rm = TRUE) {
  if (!is.numeric(x)) {
    stop("`x` deve essere numerico.", call. = FALSE)
  }
  if (!is.numeric(probs) || any(probs < 0 | probs > 1, na.rm = TRUE)) {
    stop("`probs` deve essere numerico con valori in [0, 1].", call. = FALSE)
  }
  if (is.null(w)) {
    w <- rep(1, length(x))
  }
  if (length(w) != length(x)) {
    stop("`w` deve avere la stessa lunghezza di `x`.", call. = FALSE)
  }
  if (any(w < 0, na.rm = TRUE)) {
    stop("`w` non pu\u00f2 contenere pesi negativi.", call. = FALSE)
  }

  na_out <- rep(NA_real_, length(probs))
  if (!na.rm && anyNA(c(x, w))) {
    return(na_out)
  }
  ok <- !is.na(x) & !is.na(w) & w > 0
  x <- x[ok]
  w <- w[ok]
  n <- length(x)
  if (n == 0L) {
    return(na_out)
  }
  if (n == 1L) {
    return(rep(x, length(probs)))
  }

  o <- order(x)
  x <- x[o]
  w <- w[o]
  cw <- cumsum(w)
  tot <- cw[n]
  tol <- sqrt(.Machine$double.eps) * tot
  vapply(
    probs,
    function(p) {
      target <- p * tot
      k <- which(cw >= target - tol)[1L]
      if (k < n && abs(cw[k] - target) <= tol) {
        (x[k] + x[k + 1L]) / 2
      } else {
        x[k]
      }
    },
    numeric(1)
  )
}

# 2. Quote -----

#' Quota di ciascun elemento sul totale
#'
#' @param x Vettore numerico.
#' @param na.rm Se `TRUE` (default) i `NA` sono esclusi dal totale.
#' @return Vettore numerico della stessa lunghezza di `x`; `NA` dove `x` è
#'   `NA` e ovunque se il totale è zero o non finito.
#' @keywords internal
#' @noRd
.share <- function(x, na.rm = TRUE) {
  tot <- sum(x, na.rm = na.rm)
  if (!is.finite(tot) || tot == 0) {
    return(rep(NA_real_, length(x)))
  }
  x / tot
}

# 3. Periodo di avviamento -----

#' Periodo di avviamento da una data
#'
#' @param x Vettore di classe `Date` (o `IDate`).
#' @param periodo `"anno"` restituisce l'anno come integer; `"trimestre"`
#'   restituisce una stringa `YYYY-Qn` (es. `"2024-Q3"`), ordinabile
#'   lessicograficamente.
#' @return Vettore della stessa lunghezza di `x`.
#' @keywords internal
#' @noRd
.periodo <- function(x, periodo = c("anno", "trimestre")) {
  periodo <- match.arg(periodo)
  if (!inherits(x, "Date")) {
    stop("`x` deve essere di classe Date o IDate.", call. = FALSE)
  }
  anno <- data.table::year(x)
  if (periodo == "anno") {
    return(as.integer(anno))
  }
  trimestre <- data.table::quarter(x)
  out <- paste0(anno, "-Q", trimestre)
  out[is.na(x)] <- NA_character_
  out
}
