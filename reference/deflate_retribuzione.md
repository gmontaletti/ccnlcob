# Deflaziona le colonne di retribuzione con un indice esterno

Aggiunge, in una copia di `dt`, una colonna `<col>_reale` per ciascuna
colonna di `value_cols`, calcolata come
`valore * indice[base] / indice[periodo]`. Il pacchetto non scarica
indici: `indice` è fornito dall'utente (per esempio l'IPCA via
`istatlab`).

## Usage

``` r
deflate_retribuzione(
  dt,
  indice,
  base = NULL,
  value_cols = c("p25", "mediana", "p75"),
  periodo_col = "anno"
)
```

## Arguments

- dt:

  Un `data.table` di risultati, di norma prodotto da
  [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md),
  con la colonna `periodo_col` e le colonne `value_cols`.

- indice:

  `data.table` con una colonna di periodo (chiamata come `periodo_col`
  oppure `periodo`) e la colonna numerica `indice` (\> 0), senza periodi
  duplicati. Tutti i periodi di `dt` devono essere presenti.

- base:

  Periodo base, presente in `indice`; `NULL` (default) usa l'ultimo
  periodo presente in `dt`, così che i valori reali siano espressi ai
  prezzi del periodo più recente.

- value_cols:

  Colonne da deflazionare.

- periodo_col:

  Nome della colonna di periodo in `dt`.

## Value

Un nuovo `data.table` con le colonne di `dt`, le colonne `<col>_reale`
e, se pertinenti, `var_pct_reale` e `indice_reale`; l'attributo
`ccnlcob_deflazione` riporta `base`, `periodo_col` e `value_cols`.
L'input non viene modificato.

## Details

Nel periodo base `valore_reale == valore`. Se fra le colonne prodotte
esiste `mediana_reale`, vengono aggiunte anche `var_pct_reale` e
`indice_reale`, ricalcolate come in
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
entro le serie (`by`, `ccnl_key`) lette dall'attributo
`ccnlcob_retribuzione_mediana` o, in sua assenza, dalle colonne che
precedono `ccnl_key` (tutta la tabella come una sola serie se `ccnl_key`
manca). Nessuna colonna esistente viene sovrascritta.

## See also

[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
per la tabella di partenza.

Other retribuzioni:
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
clean_retribuzione(dt, min_n = 30)
#> clean_retribuzione(): 3463 retribuzioni valide su 4746 (73.0%).
normalize_fte(dt)
ret <- median_retribuzione(dt, periodo = "anno", min_n = 10)
ipca <- data.table::data.table(
  anno = 2019:2024,
  indice = c(100, 99.8, 101.7, 110.5, 116.9, 118.2)
)
reale <- deflate_retribuzione(ret, indice = ipca, base = 2024)
reale[ccnl_key == "A011", .(anno, mediana, mediana_reale, indice_reale)]
#>     anno  mediana mediana_reale indice_reale
#>    <int>    <num>         <num>        <num>
#> 1:  2019 20760.00      24538.32    100.00000
#> 2:  2020 21512.00      25478.14    103.83001
#> 3:  2021 24354.67      28306.01    115.35433
#> 4:  2022 20121.00      21523.10     87.71219
#> 5:  2023 23346.00      23605.62     96.19901
#> 6:  2024 24088.00      24088.00     98.16483
```
