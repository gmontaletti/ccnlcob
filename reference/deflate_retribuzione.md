# Deflaziona una colonna di retribuzione con un indice esterno

Aggiunge la colonna `*_reale` calcolata come
`valore * indice[base] / indice[periodo]`. Il pacchetto non scarica
indici: `indice` è fornito dall'utente (per esempio l'IPCA via
`istatlab`).

## Usage

``` r
deflate_retribuzione(
  dt,
  indice,
  base,
  value_col = "retribuzione_fte",
  periodo_col = "anno"
)
```

## Arguments

- dt:

  Un `data.table` con la colonna `value_col` e la colonna di periodo
  `periodo_col`.

- indice:

  `data.table` con le colonne `periodo` e `indice`.

- base:

  Valore di `periodo` usato come base (identità nel periodo base).

- value_col:

  Nome della colonna da deflazionare.

- periodo_col:

  Nome della colonna di periodo in `dt`.

## Value

`dt` con la colonna `paste0(value_col, "_reale")` aggiunta per
riferimento, restituito invisibilmente. I periodi assenti in `indice`
producono `NA`.

## See also

Other retribuzioni:
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ipca <- data.table::data.table(periodo = 2019:2024,
                               indice = c(100, 99.8, 101.7, 110.5, 116.9, 118.2))
deflate_retribuzione(ret, indice = ipca, base = 2024, value_col = "mediana")
} # }
```
