# Calcola le giornate effettive allocate pro quota fra rapporti concorrenti

Aggiunge la colonna `giornate_effettive`: i giorni-persona che ciascun
rapporto riceve dopo aver ripartito i giorni in cui la stessa persona ha
più rapporti concorrenti. La somma per persona coincide con i
giorni-persona occupati; la somma per CCNL è la misura di rilevanza
usata da
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md).

## Usage

``` r
compute_giornate_effettive(dt, window = NULL)
```

## Arguments

- dt:

  Un `data.table` con le colonne `inizio` e `fine` di classe `Date`
  (`IDate` accettata), tipicamente l'output di
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).
  Viene modificato per riferimento.

- window:

  Vettore di due `Date` (o stringhe convertibili), `c(inizio, fine)`,
  ordinate; `NULL` (default) non applica alcun taglio e conta l'intera
  durata del rapporto.

## Value

`dt` con la colonna `giornate_effettive` (numeric) aggiunta per
riferimento, restituito invisibilmente.

## Details

Algoritmo:

1.  per ciascuna persona `vecshift::vecshift()` produce segmenti
    disgiunti con `arco` = numero di rapporti concorrenti nel segmento;

2.  un join non-equi associa ogni rapporto ai segmenti della stessa
    persona che interseca;

3.  `giornate_effettive = sum(giorni_intersezione / arco)` per rapporto.

Quando due CCNL diversi si sovrappongono, ciascuno riceve metà dei
giorni. Invariante: `sum(giornate_effettive)` per `cf` è uguale ai
giorni-persona occupati nella finestra. Il passo è l'unico non lineare
del pacchetto e viene eseguito a blocchi di persone.

## See also

Other giornate:
[`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
dt <- prepare_rapporti(cob_esempio)
compute_giornate_effettive(dt, window = as.Date(c("2023-01-01", "2023-12-31")))
dt[, .(giornate = sum(giornate), effettive = sum(giornate_effettive)), by = ccnl_key]
} # }
```
