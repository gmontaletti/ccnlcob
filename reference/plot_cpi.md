# Mappa di calore CCNL per CPI

Griglia CCNL (righe) per CPI (colonne) colorata su `lq` (quoziente di
localizzazione, scala divergente centrata su 1), `quota_colonna` o
`quota_riga` (scala sequenziale su un'unica tinta); in ogni caso la
scala è costruita sulla palette Okabe-Ito. Le colonne CPI sono ordinate
per totale decrescente, con `FUORI`/`ND` sempre in coda; oltre 20
colonne l'asse diventa illeggibile, quindi vengono mostrate solo le
prime (più `FUORI`/`ND` se presenti). Le celle grigie sono combinazioni
assenti dai dati oppure, per `lq`, mascherate da `min_n` in
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md);
una didascalia lo ricorda.

## Usage

``` r
plot_cpi(
  x,
  keys = NULL,
  value = c("lq", "quota_colonna", "quota_riga"),
  labels = NULL,
  cpi_labels = TRUE
)
```

## Arguments

- x:

  Una tabella di
  [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md),
  oppure un oggetto `ccnlcob_result` prodotto da
  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
  (viene usato `x$cpi`).

- keys:

  Vettore character delle chiavi `ccnl_key` da mostrare come righe;
  `NULL` (default) usa `x$keys` per un `ccnlcob_result`, altrimenti i
  primi 15 CCNL per totale della misura.

- value:

  Colonna da colorare: `"lq"` (default), `"quota_colonna"` o
  `"quota_riga"`.

- labels:

  `data.table` opzionale con le colonne `ccnl_key` e `ccnl_titolo` per
  etichette di riga leggibili; `NULL` usa `ccnl_key`.

- cpi_labels:

  Se `TRUE` (default) le colonne sono etichettate con `cpi_name`; se
  `FALSE` con `cpi_code`.

## Value

Un oggetto `ggplot`.

## See also

[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md).

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_ranking_periodo()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking_periodo.md),
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
  p <- plot_cpi(res, value = "lq")
}
```
