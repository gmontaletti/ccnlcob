# Calcola le giornate effettive allocate pro quota fra rapporti concorrenti

Aggiunge (o sovrascrive) per riferimento la colonna
`giornate_effettive`: i giorni-persona che ciascun rapporto riceve dopo
aver ripartito i giorni in cui la stessa persona ha più rapporti
concorrenti. Ogni giorno-persona compreso nella finestra viene diviso in
parti uguali (1/`arco`) fra i rapporti attivi in quel giorno, così che
la somma di `giornate_effettive` sui rapporti di una persona coincida
con i giorni in cui la persona è occupata (unione degli intervalli,
tagliata alla finestra). La somma per CCNL è la misura
`giornate_effettive` di
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md).

## Usage

``` r
compute_giornate_effettive(dt, window = NULL)
```

## Arguments

- dt:

  Un `data.table` con le colonne `id`, `cf`, `inizio` e `fine` (`Date` o
  `IDate`), tipicamente l'output di
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
  che ha già risolto le sentinelle sulle date. Viene modificato per
  riferimento.

- window:

  Vettore di due `Date` (o stringhe convertibili), `c(inizio, fine)`,
  ordinate; `NULL` (default) non applica alcun taglio e conta l'intera
  durata del rapporto.

## Value

`dt` con la colonna `giornate_effettive` (numeric) aggiunta per
riferimento, restituito invisibilmente. L'attributo
`ccnlcob_giornate_effettive` è una lista con `window`,
`n_persone_sovrapposizioni` (persone con almeno un giorno in cui hanno
più di un rapporto), `giornate_totali` (somma dei giorni-contratto nella
finestra) e `giornate_effettive_totali` (somma dei giorni-persona).

## Details

Algoritmo, esatto su date intere con estremi inclusi e interamente
vettorizzato con `data.table`:

1.  gli intervalli sono tagliati alla finestra; i rapporti interamente
    fuori finestra ricevono 0;

2.  le persone con un solo rapporto (o con `cf` mancante) ricevono
    `giornate_effettive = giornate` senza ulteriori calcoli;

3.  per le altre persone i punti di rottura sono le date `inizio` e
    `fine + 1` dei rapporti; ogni coppia di punti consecutivi definisce
    un segmento `[b_k, b_(k+1) - 1]` e `arco` è il numero di rapporti
    della persona che coprono il segmento (somma cumulata degli eventi
    di apertura e chiusura);

4.  un join non-equi associa ogni rapporto ai segmenti che copre e gli
    assegna `giorni_segmento / arco`; la somma per rapporto è
    `giornate_effettive`.

Quando due CCNL diversi si sovrappongono, ciascuno riceve metà dei
giorni. Invariante: la somma di `giornate_effettive` per `cf` è uguale
ai giorni-persona occupati nella finestra; per le persone senza
sovrapposizioni `giornate_effettive == giornate`. Righe con date
mancanti ricevono `NA`.

Rispetto a `vecshift::vecshift()`, che assegna il giorno di transizione
al segmento precedente, la suddivisione in segmenti differisce di un
giorno per ogni transizione; il totale per persona coincide
(`sum(durata[arco > 0])` di `vecshift`). Il pacchetto non dipende da
`vecshift` per questo calcolo.

## See also

Other giornate:
[`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)

## Examples

``` r
library(data.table)
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
compute_giornate_effettive(dt, window = as.Date(c("2023-01-01", "2023-12-31")))
dt[, .(giornate = sum(giornate), effettive = sum(giornate_effettive)), by = ccnl_key][
  order(-effettive)
][1:5]
#>    ccnl_key giornate effettive
#>      <char>    <int>     <num>
#> 1:     A011   201712 16799.999
#> 2:     <NA>   187177 16437.284
#> 3:     H011   100535 10827.786
#> 4:     T011    85544  8237.873
#> 5:     C011    49655  5424.802
attr(dt, "ccnlcob_giornate_effettive")$n_persone_sovrapposizioni
#> [1] 245

# invariante: per persona, la somma coincide con i giorni occupati
compute_giornate_effettive(dt)
dt[cf == dt$cf[1], .(id, inizio, fine, giornate, giornate_effettive)]
#>       id     inizio       fine giornate giornate_effettive
#>    <int>     <Date>     <Date>    <int>              <num>
#> 1:     1 2024-08-18 2024-12-09      114               53.5
#> 2:   657 2022-04-22 2022-08-23      124              124.0
#> 3:  2150 2024-06-26 2024-09-07       74               43.0
#> 4:  2902 2021-01-10 2021-06-06      148              148.0
#> 5:  4471 2024-07-15 2024-12-31      170               92.5
```
