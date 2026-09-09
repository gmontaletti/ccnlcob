# Calcola le giornate di contratto nella finestra di analisi

Aggiunge (o sovrascrive) per riferimento la colonna `giornate`, cioè il
numero di giorni di ciascun rapporto compresi nella finestra di analisi,
estremi inclusi. La misura è additiva e conta ogni rapporto per intero,
senza correggere le sovrapposizioni fra rapporti della stessa persona
(per quello vedi
[`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md)).

## Usage

``` r
compute_giornate(dt, window = NULL)
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

`dt` con la colonna `giornate` (integer) aggiunta per riferimento,
restituito invisibilmente.

## Details

Per ogni rapporto
`giornate = max(0, min(fine, window[2]) - max(inizio, window[1]) + 1)`.
Un rapporto interamente fuori finestra ha `giornate = 0`; un rapporto
interamente dentro ha `giornate = fine - inizio + 1`; con
`window = NULL` vale sempre `fine - inizio + 1` (0 se `fine < inizio`).
Il calcolo avviene su giorni interi: la colonna è di tipo integer, mai
`difftime`. Date mancanti producono `giornate = NA`; le sentinelle non
vengono trattate qui ma in
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

## See also

Other giornate:
[`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md)

## Examples

``` r
library(data.table)
dt <- prepare_rapporti(cob_esempio)
compute_giornate(dt, window = as.Date(c("2023-01-01", "2023-12-31")))
dt[giornate > 0, sum(giornate), by = ccnl_key][order(-V1)][1:5]
#>    ccnl_key    V1
#>      <char> <int>
#> 1:     A011 40566
#> 2:     <NA> 34978
#> 3:     H011 21573
#> 4:     T011 17382
#> 5:     C011 12895

# senza finestra: intera durata del rapporto
compute_giornate(dt)
dt[, summary(giornate)]
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>     1.0    52.0   128.0   216.6   256.0  2173.0 
```
