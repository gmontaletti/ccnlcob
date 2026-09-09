# Lookup comune -\> CPI per i comuni di cob_esempio

Tabella di raccordo fra i codici Belfiore usati in
[cob_esempio](https://gmontaletti.github.io/ccnlcob/reference/cob_esempio.md)
(sede di lavoro e residenza) e il CPI (Centro per l'Impiego) di
competenza, risolta con le utilità geografiche di `longworkR`. Contiene
solo i comuni lombardi risolti (i dodici capoluoghi); i quattro codici
fuori regione presenti in
[cob_esempio](https://gmontaletti.github.io/ccnlcob/reference/cob_esempio.md)
(`F952`, `G535`, `H501`, `L219`) non compaiono e con
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
ricevono il residuo `FUORI`. Consente di eseguire gli esempi di
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
e
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
senza `longworkR` e senza i file di mapping.

## Usage

``` r
cpi_esempio
```

## Format

Un `data.table` con una riga per comune e le colonne:

- belfiore:

  character. Codice Belfiore (catastale) del comune, chiave univoca.

- cpi_code:

  character. Codice del CPI di competenza (codice Belfiore del comune
  sede del CPI seguito dal codice ufficio).

- cpi_name:

  character. Denominazione del CPI (es. `CPI MILANO`).

## Source

Generato da `data-raw/cpi_esempio.R` con
`longworkR::add_cpi_via_belfiore()` (utilità geografiche di `longworkR`
sui file `belfiore_istat_mapping.csv` e `comune_cpi_lookup.rds` in
`SHARED_DATA_DIR/maps`), 2026-09-09.

## See also

[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md),
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md),
[cob_esempio](https://gmontaletti.github.io/ccnlcob/reference/cob_esempio.md)

## Examples

``` r
cpi_esempio
#>     belfiore    cpi_code    cpi_name
#>       <char>      <char>      <char>
#>  1:     A794 A794C000060 CPI BERGAMO
#>  2:     B157 B157C000683 CPI BRESCIA
#>  3:     C933 C933C000073    CPI COMO
#>  4:     D150 D150C000030 CPI CREMONA
#>  5:     E507 E507C000578   CPI LECCO
#>  6:     E648 E648C000580    CPI LODI
#>  7:     E897 E897C000034 CPI MANTOVA
#>  8:     F205 F205C000169  CPI MILANO
#>  9:     F704 F704C000581   CPI MONZA
#> 10:     G388 G388C000070   CPI PAVIA
#> 11:     I829 I829C000043 CPI SONDRIO
#> 12:     L682 L682C000600  CPI VARESE
```
