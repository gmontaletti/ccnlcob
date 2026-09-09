# Segnala le retribuzioni non valide o implausibili

Aggiunge il flag `retribuzione_valida` e la colonna `retribuzione_clean`
(uguale a `retribuzione` dove valida, `NA` altrove). Nessuna riga viene
eliminata: la copertura del campo resta misurabile.

## Usage

``` r
clean_retribuzione(
  dt,
  min_value = 0,
  method = c("mad", "quantile", "none"),
  k = 5,
  by = c("anno", "macro_tipologia")
)
```

## Arguments

- dt:

  Un `data.table` di rapporti con le colonne `retribuzione`, `anno` e
  `macro_tipologia` (vedi
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)).

- min_value:

  Valore minimo (escluso) perché una retribuzione sia considerata
  valida.

- method:

  Metodo per la finestra di plausibilità: `"mad"` (mediana più o meno
  `k` volte la deviazione assoluta mediana sul logaritmo), `"quantile"`
  (esclusione delle code oltre i quantili estremi) o `"none"` (solo
  `min_value` e `NA`).

- k:

  Ampiezza della finestra in unità di MAD (per `method = "mad"`).

- by:

  Colonne che definiscono i gruppi entro cui calcolare la finestra di
  plausibilità.

## Value

`dt` con le colonne `retribuzione_valida` (logical) e
`retribuzione_clean` (numeric) aggiunte per riferimento, restituito
invisibilmente.

## Details

La retribuzione dichiarata all'avviamento è un campo di qualità
disomogenea (testuale in origine, molti valori mancanti). La finestra di
plausibilità è calcolata sul logaritmo della retribuzione entro ciascun
gruppo `by`, così da adattarsi a livelli diversi fra anni e tipologie
senza soglie fissate a priori. I default vanno confrontati con una
diagnostica descrittiva sui dati reali prima dell'uso in produzione.

## See also

Other retribuzioni:
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)

## Examples

``` r
if (FALSE) { # \dontrun{
dt <- prepare_rapporti(cob_esempio)
clean_retribuzione(dt, method = "mad", k = 5)
dt[, .(copertura = mean(retribuzione_valida)), by = anno]
} # }
```
