# Stampa sintetica di un risultato ccnlcob_result

Mostra versione, finestra, perimetro, numerosità, coperture, i primi
CCNL rilevanti con la loro quota e i passi saltati di un oggetto
prodotto da
[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md).

## Usage

``` r
# S3 method for class 'ccnlcob_result'
print(x, n = 5L, ...)
```

## Arguments

- x:

  Oggetto di classe `ccnlcob_result`.

- n:

  Numero di CCNL rilevanti da elencare (default 5).

- ...:

  Ignorato; presente per coerenza con il generico
  [`print()`](https://rdrr.io/r/base/print.html).

## Value

`x`, restituito invisibilmente.

## See also

Other orchestrazione:
[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md),
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)

## Examples

``` r
res <- analyze_ccnl(cob_esempio, lookup_cpi = cpi_esempio, min_n = 10)
print(res)
#> <ccnlcob_result>
#>   versione:                0.7.0
#>   as_of:                   2024-12-31
#>   window:                  2019-01-01 / 2024-12-31
#>   perimetro:               ccnl
#>   ccnl_key:                codice_cnel
#>   rapporti:                input 5.000, in finestra 4.746, avviati 4.746
#>   lavoratori avviati:      400
#>   copertura codice CCNL:   83,7%
#>   copertura retribuzione:  73,2%
#>   CCNL rilevanti:          20 (misura: giornate)
#>   primi CCNL:
#>      1. A011     19,5%
#>      2. H011     9,7%
#>      3. T011     8,3%
#>      4. IC91     4,9%
#>      5. C011     4,8%
#>   passi saltati:
#>     - deflate_retribuzione: nessun `indice` fornito
```
