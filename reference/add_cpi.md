# Aggiunge il CPI (Centro per l'Impiego) ai rapporti di lavoro

Associa a ciascun rapporto il codice e il nome del CPI a partire dal
codice Belfiore della sede di lavoro (`comune_sede_lavoro`) o della
residenza del lavoratore (`comune_lavoratore`). Il mapping è fornito da
un `lookup` esplicito oppure, in sua assenza, dalle utilità geografiche
di `longworkR` (`longworkR::add_cpi_via_belfiore()`), che il pacchetto
non reimplementa. Le colonne sono aggiunte a `dt` per riferimento.

## Usage

``` r
add_cpi(dt, geo = c("sede_lavoro", "residenza"), lookup = NULL, quiet = TRUE)
```

## Arguments

- dt:

  Un `data.table` di rapporti con la colonna geografica richiesta da
  `geo`. Viene modificato per riferimento.

- geo:

  Geografia di riferimento: `"sede_lavoro"` (default, colonna
  `comune_sede_lavoro`) o `"residenza"` (colonna `comune_lavoratore`).

- lookup:

  `data.table` o `data.frame` opzionale con le colonne `belfiore`
  (codice Belfiore del comune, univoco), `cpi_code` e, facoltativa,
  `cpi_name` (se assente viene riempita con `cpi_code`). `NULL`
  (default) usa `longworkR`, che deve essere installato e deve trovare i
  file di mapping in `SHARED_DATA_DIR/maps`. Vedi
  [cpi_esempio](https://gmontaletti.github.io/ccnlcob/reference/cpi_esempio.md)
  per un lookup di esempio.

- quiet:

  Se `TRUE` (default) l'output a console di `longworkR` viene soppresso;
  ignorato con un `lookup` esplicito.

## Value

`dt`, restituito invisibilmente, con le colonne character `cpi_code` e
`cpi_name` aggiunte o sovrascritte per riferimento. L'attributo
`ccnlcob_cpi` è una lista con `geo` e `source` (`"lookup"` oppure
`"longworkR"`).

## Details

Con `lookup = NULL` il mapping viene costruito una sola volta sui codici
Belfiore distinti e non mancanti della colonna sorgente, non sull'intera
tabella, e poi agganciato ai rapporti. Il join è un aggiornamento per
riferimento: il numero e l'ordine delle righe di `dt` non cambiano.

Convenzioni sui residui, così che ogni rapporto resti visibile nelle
distribuzioni territoriali:

- codice Belfiore presente ma assente dal lookup (tipicamente comune
  fuori Lombardia): `cpi_code = "FUORI"`,
  `cpi_name = "Fuori Lombardia"`;

- codice Belfiore mancante (`NA`): `cpi_code = "ND"`,
  `cpi_name = "Non disponibile"`.

Colonne `cpi_code` e `cpi_name` già presenti in `dt` vengono
sovrascritte.

## See also

[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
per la distribuzione dei CCNL per CPI;
[cpi_esempio](https://gmontaletti.github.io/ccnlcob/reference/cpi_esempio.md)
per il lookup dei comuni di
[cob_esempio](https://gmontaletti.github.io/ccnlcob/reference/cob_esempio.md).

Other territorio:
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)

## Examples

``` r
library(data.table)
#> 
#> Attaching package: ‘data.table’
#> The following object is masked from ‘package:base’:
#> 
#>     %notin%
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
add_cpi(dt, geo = "sede_lavoro", lookup = cpi_esempio)
dt[, .N, by = .(cpi_code, cpi_name)][order(-N)]
#>        cpi_code        cpi_name     N
#>          <char>          <char> <int>
#>  1: F205C000169      CPI MILANO  1522
#>  2: L682C000600      CPI VARESE   694
#>  3: B157C000683     CPI BRESCIA   450
#>  4: F704C000581       CPI MONZA   418
#>  5: A794C000060     CPI BERGAMO   366
#>  6: C933C000073        CPI COMO   252
#>  7:       FUORI Fuori Lombardia   236
#>  8: G388C000070       CPI PAVIA   211
#>  9: E507C000578       CPI LECCO   146
#> 10: D150C000030     CPI CREMONA   145
#> 11: E897C000034     CPI MANTOVA   126
#> 12: E648C000580        CPI LODI    97
#> 13: I829C000043     CPI SONDRIO    83
attr(dt, "ccnlcob_cpi")
#> $geo
#> [1] "sede_lavoro"
#> 
#> $source
#> [1] "lookup"
#> 

# CPI di residenza del lavoratore
add_cpi(dt, geo = "residenza", lookup = cpi_esempio)
dt[, .N, by = cpi_name][order(-N)][1:5]
#>       cpi_name     N
#>         <char> <int>
#> 1:  CPI MILANO  1362
#> 2:  CPI VARESE   700
#> 3: CPI BRESCIA   568
#> 4:   CPI MONZA   431
#> 5: CPI BERGAMO   295
```
