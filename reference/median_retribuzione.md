# Calcola la retribuzione mediana per CCNL e periodo di avviamento

Aggrega la retribuzione (normalizzata FTE o dichiarata) per `ccnl_key` e
periodo di avviamento, con quartili, numerosità, copertura e variazione
sul periodo precedente.

## Usage

``` r
median_retribuzione(
  dt,
  periodo = c("anno", "trimestre"),
  by = NULL,
  weights = c("giornate", "none"),
  fte = TRUE,
  probs = c(0.25, 0.5, 0.75),
  min_n = 30
)
```

## Arguments

- dt:

  Un `data.table` di rapporti già passato da
  [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
  e, se `fte = TRUE`, da
  [`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md).

- periodo:

  Periodo di avviamento: `"anno"` (default) o `"trimestre"`.

- by:

  Colonne aggiuntive di raggruppamento; `NULL` per il solo CCNL.

- weights:

  Pesi per la mediana: `"giornate"` (default) o `"none"`.

- fte:

  Se `TRUE` (default) usa `retribuzione_fte`, altrimenti
  `retribuzione_clean`.

- probs:

  Quantili da riportare; il valore 0.5 è sempre incluso.

- min_n:

  Numerosità minima del gruppo sotto la quale le statistiche vengono
  mascherate con `NA` (la riga resta con `n` e `copertura`).

## Value

Un `data.table` con una riga per (`by`, `ccnl_key`, `periodo`) e le
colonne `n`, `copertura`, `p25`, `mediana`, `p75` (o i quantili
richiesti), `var_pct`, `indice_100`.

## Details

La retribuzione è dichiarata all'avviamento, quindi la coorte di
avviamento è la dimensione temporale corretta. La mediana e i quartili
sono ponderati per `giornate` (mediana ponderata a gradini, che con pesi
uniformi coincide con la mediana classica). `copertura` è la quota di
rapporti del gruppo con retribuzione valida. `var_pct` è la variazione
percentuale della mediana sul periodo precedente e `indice_100` l'indice
a base fissa (primo periodo = 100).

## See also

Other retribuzioni:
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ret <- median_retribuzione(dt, periodo = "anno", min_n = 30)
ret[ccnl_key == "H011"]
} # }
```
