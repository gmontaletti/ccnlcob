# Andamento del ranking dei CCNL per periodo

Linee con punti dell'andamento di `measure` (o della sua quota) per
periodo di avviamento, una per CCNL selezionato. Colore, tratteggio e
forma del punto codificano insieme il CCNL (codifica ridondante), con
un'etichetta diretta a fine linea al posto della legenda.

## Usage

``` r
plot_ranking_periodo(
  x,
  measure = "giornate",
  keys = NULL,
  labels = NULL,
  quota = TRUE
)
```

## Arguments

- x:

  Una tabella di
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
  calcolata con `periodo`, oppure un oggetto `ccnlcob_result` prodotto
  da
  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
  (viene usato `x$ranking_periodo`). Deve contenere esattamente una
  colonna di periodo (`anno` o `trimestre`) e non più di una riga per
  CCNL e periodo.

- measure:

  Misura da rappresentare; devono essere presenti le colonne `measure` e
  `quota_measure`.

- keys:

  Vettore character delle chiavi `ccnl_key` da tracciare, al massimo 8
  (limite della palette Okabe-Ito); `NULL` (default) usa `x$keys` per un
  `ccnlcob_result`, altrimenti i primi 6 CCNL per somma di `measure` sui
  periodi.

- labels:

  `data.table` opzionale con le colonne `ccnl_key` e `ccnl_titolo` per
  etichette leggibili; `NULL` usa `ccnl_key`.

- quota:

  Se `TRUE` (default) traccia `quota_measure` (asse in percentuale); se
  `FALSE` traccia il valore grezzo di `measure`.

## Value

Un oggetto `ggplot`.

## See also

[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md).

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_retribuzioni()`](https://gmontaletti.github.io/ccnlcob/reference/plot_retribuzioni.md),
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
  p <- plot_ranking_periodo(res, measure = "giornate")
}
```
