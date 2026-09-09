# Normalizza la retribuzione alle ore di riferimento del CCNL

Aggiunge `retribuzione_fte`, la retribuzione riportata all'orario di
riferimento del CCNL, e la colonna `ore_riferimento` usata per il
calcolo.

## Usage

``` r
normalize_fte(dt, ore_riferimento = NULL, fallback_ore = 40)
```

## Arguments

- dt:

  Un `data.table` di rapporti con le colonne `retribuzione_clean` (da
  [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)),
  `ore`, `prior` e `ccnl_key`.

- ore_riferimento:

  `data.table` opzionale con `ccnl_key` e `ore_riferimento`; se `NULL`
  le ore di riferimento vengono stimate dai dati.

- fallback_ore:

  Ore di riferimento usate quando la stima dai dati non è disponibile
  per un CCNL.

## Value

`dt` con le colonne `ore_riferimento` e `retribuzione_fte` aggiunte per
riferimento, restituito invisibilmente.

## Details

`retribuzione_fte = retribuzione_clean * ore_riferimento / ore`, dove
`ore_riferimento` è la mediana di `ore` fra i rapporti a tempo pieno
(`prior == 1`) dello stesso CCNL: un parametro derivato dai dati, non
fissato a priori. Il valore di `fallback_ore` è usato solo per i CCNL
senza rapporti a tempo pieno con `ore` valide. Se `ore` manca,
`retribuzione_fte` è uguale a `retribuzione_clean` per i tempi pieni e
`NA` per i tempi parziali.

## See also

Other retribuzioni:
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)

## Examples

``` r
if (FALSE) { # \dontrun{
normalize_fte(dt)
dt[prior == 1 & ore == ore_riferimento, all.equal(retribuzione_fte, retribuzione_clean)]
} # }
```
