# Tema grafico minimale per ccnlcob

Tema `ggplot2` condiviso da tutte le funzioni di plottaggio del
pacchetto: sfondo chiaro, griglia minore assente, legenda in basso,
dimensioni del testo mai sotto i 9 punti con `base_size` di default. Le
singole funzioni di plottaggio rimuovono inoltre la griglia maggiore
sull'asse categoriale quando pertinente (non gestito qui perché dipende
dall'orientamento del grafico).

## Usage

``` r
theme_ccnlcob(base_size = 11)
```

## Arguments

- base_size:

  Dimensione del testo di base, in punti.

## Value

Un oggetto `theme` di `ggplot2`.

## See also

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_ranking_periodo()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking_periodo.md),
[`plot_retribuzioni()`](https://gmontaletti.github.io/ccnlcob/reference/plot_retribuzioni.md),
[`plot_tipologie()`](https://gmontaletti.github.io/ccnlcob/reference/plot_tipologie.md),
[`scale_colour_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/scale_colour_ccnlcob.md)

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    theme_ccnlcob()
}
```
