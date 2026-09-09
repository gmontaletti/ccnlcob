# Scale colore e riempimento sulla palette Okabe-Ito

Scale discrete di `ggplot2` per le estetiche `colour` e `fill` sulla
palette
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md).
Con più di 8 livelli nei dati la costruzione del grafico genera un
errore: ridurre i livelli (per esempio filtrando con `top_n` o `keys`
nelle funzioni di plottaggio del pacchetto) invece di allargare la
palette.

## Usage

``` r
scale_colour_ccnlcob(...)

scale_fill_ccnlcob(...)
```

## Arguments

- ...:

  Argomenti passati a
  [`ggplot2::discrete_scale()`](https://ggplot2.tidyverse.org/reference/discrete_scale.html)
  (`name`, `breaks`, `labels`, `guide`, ...).

## Value

Un oggetto `Scale` di `ggplot2`.

## See also

[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md).

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_ranking_periodo()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking_periodo.md),
[`plot_retribuzioni()`](https://gmontaletti.github.io/ccnlcob/reference/plot_retribuzioni.md),
[`plot_tipologie()`](https://gmontaletti.github.io/ccnlcob/reference/plot_tipologie.md),
[`theme_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/theme_ccnlcob.md)

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  d <- data.frame(x = 1:3, y = 1:3, g = c("a", "b", "c"))
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y, colour = g)) +
    ggplot2::geom_point(size = 3) +
    scale_colour_ccnlcob()
}
```
