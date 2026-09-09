# Palette Okabe-Ito per ccnlcob

Restituisce i primi `n` colori della palette Okabe-Ito (8 colori,
incluso il nero), sicura per le forme più comuni di daltonismo
(protanopia, deuteranopia, tritanopia): arancio `#E69F00`, azzurro
`#56B4E9`, verde `#009E73`, giallo `#F0E442`, blu `#0072B2`, vermiglio
`#D55E00`, porpora `#CC79A7`, nero `#000000` (Okabe & Ito, 2008,
<https://jfly.uni-koeln.de/color/>).

## Usage

``` r
palette_ccnlcob(n)
```

## Arguments

- n:

  Numero di colori richiesti, fra 1 e 8.

## Value

Vettore character di `n` codici esadecimali.

## See also

[`scale_colour_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/scale_colour_ccnlcob.md),
[`scale_fill_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/scale_colour_ccnlcob.md).

Other grafici:
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_ranking_periodo()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking_periodo.md),
[`plot_retribuzioni()`](https://gmontaletti.github.io/ccnlcob/reference/plot_retribuzioni.md),
[`plot_tipologie()`](https://gmontaletti.github.io/ccnlcob/reference/plot_tipologie.md),
[`scale_colour_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/scale_colour_ccnlcob.md),
[`theme_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/theme_ccnlcob.md)

## Examples

``` r
palette_ccnlcob(4)
#> [1] "#E69F00" "#56B4E9" "#009E73" "#F0E442"
```
