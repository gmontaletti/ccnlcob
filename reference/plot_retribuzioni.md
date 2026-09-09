# Andamento della retribuzione mediana per periodo

Linee della retribuzione mediana per periodo di avviamento, una per CCNL
selezionato, con banda p25-p75 opzionale. I periodi mascherati (mediana
`NA`) sono omessi; i periodi con `copertura` sotto `copertura_min` sono
disegnati con punto vuoto (contorno colorato, riempimento bianco) invece
che pieno, come codifica ridondante della bassa affidabilità del dato
rispetto al solo colore della serie. L'asse verticale è formattato in
euro con il punto come separatore delle migliaia.

## Usage

``` r
plot_retribuzioni(
  x,
  keys = NULL,
  labels = NULL,
  reale = FALSE,
  banda = TRUE,
  copertura_min = NULL
)
```

## Arguments

- x:

  Una tabella di
  [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
  o
  [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
  oppure un oggetto `ccnlcob_result` prodotto da
  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
  (viene usato `x$retribuzioni`).

- keys:

  Vettore character delle chiavi `ccnl_key` da tracciare, al massimo 8
  (limite della palette Okabe-Ito); `NULL` (default) usa `x$keys` per un
  `ccnlcob_result`, altrimenti i primi 6 CCNL per somma di `giornate`.

- labels:

  `data.table` opzionale con le colonne `ccnl_key` e `ccnl_titolo` per
  etichette leggibili; `NULL` usa `ccnl_key`.

- reale:

  Se `TRUE` usa le colonne `_reale` prodotte da
  [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md)
  (`p25_reale`, `mediana_reale`, `p75_reale`); se `FALSE` (default) usa
  i valori correnti.

- banda:

  Se `TRUE` (default) disegna la banda p25-p75 come area semitrasparente
  intorno alla mediana.

- copertura_min:

  Soglia di `copertura` sotto la quale un punto è disegnato vuoto;
  `NULL` (default) disegna tutti i punti pieni.

## Value

Un oggetto `ggplot`.

## See also

[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md),
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md).

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_ranking_periodo()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking_periodo.md),
[`plot_tipologie()`](https://gmontaletti.github.io/ccnlcob/reference/plot_tipologie.md),
[`scale_colour_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/scale_colour_ccnlcob.md),
[`theme_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/theme_ccnlcob.md)

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  res <- analyze_ccnl(
    cob_esempio,
    window = as.Date(c("2022-01-01", "2024-12-31")),
    lookup_cpi = cpi_esempio,
    top_n = 8,
    min_n = 10
  )
  p <- plot_retribuzioni(res, copertura_min = 0.5)
}
```
