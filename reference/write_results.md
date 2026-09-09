# Serializza i risultati di analyze_ccnl()

Scrive su disco le tabelle contenute in un oggetto `ccnlcob_result`
seguendo la convenzione dell'ecosistema: RDS per le tabelle piccole
(`ranking`, `ranking_periodo`, `rilevanti`, `retribuzioni`, `qualita`) e
FST con compressione 85 per i cubi (`cpi`, `tipologie`). `meta` e `keys`
non sono tabelle e vengono sempre scritti in RDS.

## Usage

``` r
write_results(
  result,
  dir,
  formats = c(small = "rds", cube = "fst"),
  overwrite = FALSE
)
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

- overwrite:

  Se `FALSE` (default) la funzione si ferma con un errore quando uno dei
  file di destinazione esiste già.

## Value

Un `data.table` con una riga per file scritto e le colonne `oggetto`,
`file` (percorso), `formato`, `righe` (`NA` per gli oggetti non
tabellari) e `byte`, restituito invisibilmente.

## Details

I file sono `meta.rds`, `ranking.<f>`, `ranking_periodo.<f>`,
`rilevanti.<f>`, `keys.rds`, `cpi.<f>`, `tipologie.<f>`,
`retribuzioni.<f>` e `qualita.<f>`, con `<f>` pari al formato della
famiglia. Gli elementi `NULL` del risultato (passi saltati) non
producono file e sono elencati in `meta$oggetti_assenti`. Il formato FST
non conserva gli attributi delle tabelle (`ccnlcob_ranking`,
`ccnlcob_crosstab`, ...): per ogni tabella scritta essi vengono salvati
in `meta$attributi[[nome]]`, così che `meta.rds` permetta di
ricostruirli con [`attr()`](https://rdrr.io/r/base/attr.html).
`meta$file` riporta il manifesto dei file scritti.

## See also

[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
per la produzione del risultato.

Other orchestrazione:
[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md),
[`print.ccnlcob_result()`](https://gmontaletti.github.io/ccnlcob/reference/print.ccnlcob_result.md)

## Examples

``` r
res <- analyze_ccnl(cob_esempio, lookup_cpi = cpi_esempio, min_n = 10)
dir_out <- file.path(tempdir(), "ccnl")
manifesto <- write_results(res, dir = dir_out, overwrite = TRUE)
manifesto
#>            oggetto                                     file formato righe  byte
#>             <char>                                   <char>  <char> <int> <num>
#> 1:            meta            /tmp/Rtmp73P9L7/ccnl/meta.rds     rds    NA  1704
#> 2:         ranking         /tmp/Rtmp73P9L7/ccnl/ranking.rds     rds    26  3420
#> 3: ranking_periodo /tmp/Rtmp73P9L7/ccnl/ranking_periodo.rds     rds   156 14626
#> 4:       rilevanti       /tmp/Rtmp73P9L7/ccnl/rilevanti.rds     rds    22  3084
#> 5:            keys            /tmp/Rtmp73P9L7/ccnl/keys.rds     rds    NA   115
#> 6:             cpi             /tmp/Rtmp73P9L7/ccnl/cpi.fst     fst   254 14992
#> 7:       tipologie       /tmp/Rtmp73P9L7/ccnl/tipologie.fst     fst   225 10811
#> 8:    retribuzioni    /tmp/Rtmp73P9L7/ccnl/retribuzioni.rds     rds   120  4117
#> 9:         qualita         /tmp/Rtmp73P9L7/ccnl/qualita.rds     rds    26  1044
readRDS(file.path(dir_out, "meta.rds"))$versione
#> [1] "0.5.0"
unlink(dir_out, recursive = TRUE)
```
