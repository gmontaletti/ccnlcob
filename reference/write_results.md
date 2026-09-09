# Serializza i risultati di analyze_ccnl()

Scrive su disco le tabelle contenute in un oggetto `ccnlcob_result`
seguendo la convenzione dell'ecosistema: RDS per le tabelle piccole
(`meta`, `ranking`, `rilevanti`, `retribuzioni`, `qualita`) e FST con
compressione 85 per i cubi (`cpi`, `tipologie`).

## Usage

``` r
write_results(result, dir, formats = c(small = "rds", cube = "fst"))
```

## Arguments

- result:

  Oggetto di classe `ccnlcob_result` prodotto da
  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md).

- dir:

  Directory di destinazione; viene creata se non esiste.

- formats:

  Vettore character nominato con i formati per le tabelle piccole
  (`small`) e per i cubi (`cube`). Valori ammessi: `"rds"`, `"fst"`.

## Value

Vettore character nominato con i percorsi dei file scritti, restituito
invisibilmente.

## See also

Other orchestrazione:
[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md),
[`print.ccnlcob_result()`](https://gmontaletti.github.io/ccnlcob/reference/print.ccnlcob_result.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- analyze_ccnl(cob_esempio, window = as.Date(c("2022-01-01", "2024-12-31")))
write_results(res, dir = "output/ccnl")
} # }
```
