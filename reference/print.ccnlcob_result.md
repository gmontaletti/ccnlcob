# Stampa sintetica di un risultato ccnlcob_result

Mostra i metadati principali e le dimensioni delle tabelle contenute in
un oggetto prodotto da
[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md).

## Usage

``` r
# S3 method for class 'ccnlcob_result'
print(x, ...)
```

## Arguments

- x:

  Oggetto di classe `ccnlcob_result`.

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
if (FALSE) { # \dontrun{
res <- analyze_ccnl(cob_esempio)
print(res)
} # }
```
