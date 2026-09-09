# Grafico a barre del ranking dei CCNL

Barre orizzontali dei primi `top_n` CCNL per `measure`, ordinate per
valore decrescente, con la quota sul totale stampata come etichetta
diretta alla fine di ogni barra (nessuna legenda necessaria). I CCNL non
classificati e, con `other = TRUE`, il residuo dei CCNL esclusi dal
`top_n` sono ricalcolati dalla tabella e disegnati come barre distinte,
in grigio neutro anziché nella palette categoriale: la distinzione non
dipende quindi solo dal colore, ma anche dall'etichetta testuale
sull'asse e dalla posizione (sempre in coda al grafico).

## Usage

``` r
plot_ranking(x, measure = "giornate", top_n = 15, labels = NULL, other = TRUE)
```

## Arguments

- x:

  Una tabella di
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
  o di
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
  (`return = "table"`), oppure un oggetto `ccnlcob_result` prodotto da
  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
  (viene usato `x$ranking`). Se la tabella è raggruppata per `by` o
  `periodo` deve contenere un solo gruppo: filtrare a monte, altrimenti
  la funzione segnala un errore.

- measure:

  Misura da rappresentare; devono essere presenti le colonne `measure` e
  `quota_measure`.

- top_n:

  Numero massimo di CCNL classificati da mostrare.

- labels:

  `data.table` opzionale con le colonne `ccnl_key` e `ccnl_titolo`, per
  etichette leggibili sull'asse (titolo troncato a circa 45 caratteri,
  con la chiave fra parentesi); `NULL` (default) usa direttamente
  `ccnl_key`.

- other:

  Se `TRUE` (default) aggiunge una barra col residuo dei CCNL
  classificati esclusi dal `top_n`; se `FALSE` quei CCNL non compaiono.

## Value

Un oggetto `ggplot`.

## See also

[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).

Other grafici:
[`palette_ccnlcob()`](https://gmontaletti.github.io/ccnlcob/reference/palette_ccnlcob.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
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
  p <- plot_ranking(res, measure = "giornate", top_n = 6)
}
```
