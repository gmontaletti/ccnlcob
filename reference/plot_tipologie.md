# Barre impilate della distribuzione per tipologia contrattuale

Barre orizzontali impilate di `quota_riga` per macro-tipologia
contrattuale, una per CCNL selezionato. Le nove macro-tipologie di
[tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md)
superano la capienza sicura di una palette categoriale (8 colori): la
funzione mantiene le 6 più rilevanti fra i dati mostrati e accorpa le
altre in `"Altre tipologie"`. Le percentuali oltre l'8% sono stampate
direttamente nel segmento, con un colore del testo (bianco o quasi nero)
scelto automaticamente per contrasto sullo sfondo del segmento.

## Usage

``` r
plot_tipologie(x, keys = NULL, labels = NULL, orario = FALSE)
```

## Arguments

- x:

  Una tabella di
  [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md),
  oppure un oggetto `ccnlcob_result` prodotto da
  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
  (viene usato `x$tipologie`).

- keys:

  Vettore character delle chiavi `ccnl_key` da mostrare; `NULL`
  (default) usa `x$keys` per un `ccnlcob_result`, altrimenti i primi 15
  CCNL per totale della misura.

- labels:

  `data.table` opzionale con le colonne `ccnl_key` e `ccnl_titolo` per
  etichette leggibili; `NULL` usa `ccnl_key`.

- orario:

  Se `TRUE` sfaccetta il grafico per `orario` (richiede la colonna
  `orario` in `x`, prodotta da `ccnl_by_tipologia(orario = TRUE)`); se
  `FALSE` (default) somma le quote sull'orario.

## Value

Un oggetto `ggplot`.

## See also

[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md).

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_ranking_periodo()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking_periodo.md),
[`plot_retribuzioni()`](https://gmontaletti.github.io/ccnlcob/reference/plot_retribuzioni.md),
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
  p <- plot_tipologie(res)
}
```
