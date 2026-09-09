# Calcola la retribuzione mediana per CCNL e periodo di avviamento

Aggrega una colonna di retribuzione (di norma `retribuzione_fte`) per
`ccnl_key` e periodo di avviamento, con quantili ponderati per giornate,
numerosità, copertura, variazione sul periodo precedente e indice a base
fissa. L'input non viene modificato.

## Usage

``` r
median_retribuzione(
  dt,
  periodo = c("anno", "trimestre"),
  by = NULL,
  ccnl = NULL,
  weights = c("giornate", "none"),
  value_col = "retribuzione_fte",
  probs = c(0.25, 0.5, 0.75),
  min_n = 30L,
  solo_avviati = TRUE
)
```

## Arguments

- dt:

  Un `data.table` di rapporti già passato da
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
  [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
  e
  [`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md),
  con le colonne `ccnl_key`, `periodo`, `value_col`, `giornate` (se
  `weights = "giornate"`) e `avviato` (se `solo_avviati = TRUE`).

- periodo:

  Periodo di avviamento: `"anno"` (default) o `"trimestre"`.

- by:

  Colonne aggiuntive di raggruppamento; `NULL` per il solo CCNL.

- ccnl:

  `NULL` per tutte le chiavi, altrimenti vettore character delle chiavi
  `ccnl_key` da conservare in uscita (`NA` incluso conserva i non
  classificati); il filtro è applicato dopo il calcolo.

- weights:

  Pesi dei quantili: `"giornate"` (default) o `"none"`.

- value_col:

  Colonna di retribuzione da aggregare.

- probs:

  Quantili da riportare, in `[0, 1]`; il valore 0.5 viene sempre
  incluso.

- min_n:

  Numero minimo di valori validi nella cella sotto il quale i quantili
  vengono mascherati con `NA` (la riga resta, con `n`, `n_valide` e
  `copertura`).

- solo_avviati:

  Se `TRUE` (default) considera solo i rapporti con `avviato == TRUE`.

## Value

Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`), inclusa
la classe `"Non classificati"` per `ccnl_key` mancante, con le colonne
di `by`, `periodo`, `ccnl_key`, `classe`, `n`, `n_valide`, `copertura`,
`giornate`, una colonna per quantile (`p25`, `mediana`, `p75` con i
default; `p<int>` per gli altri), `var_pct` e `indice`; ordinato per
`by`, `ccnl_key` (`NA` in coda) e periodo. L'attributo
`ccnlcob_retribuzione_mediana` conserva i parametri.

## Details

La retribuzione è dichiarata all'avviamento del rapporto e non viene
aggiornata: la coorte di avviamento (`anno` o `trimestre` di `inizio`) è
quindi la dimensione temporale corretta. I rapporti avviati prima della
finestra di analisi appartengono a coorti più vecchie sopravvissute fino
alla finestra e risentono della selezione per sopravvivenza (restano in
vita i rapporti più stabili, in genere meglio retribuiti): con
`solo_avviati = TRUE` vengono esclusi.

I quantili sono calcolati con la mediana ponderata a gradini (vedi
`.wquantile()`): con `weights = "giornate"` ogni rapporto pesa per i
giorni-contratto nella finestra, così che un contratto di un anno conti
più di uno di una settimana, in modo coerente con la mediana ponderata
per durata di `longworkR`; con pesi uniformi il risultato coincide con
[`stats::median()`](https://rdrr.io/r/stats/median.html). `n` conta le
righe della cella, `n_valide` quelle con valore non mancante,
`copertura = n_valide / n`, `giornate` è la somma delle giornate delle
righe valide. Le celle con `n_valide < min_n` sono mascherate, non
eliminate.

`var_pct` è la variazione percentuale della mediana rispetto al periodo
precedente entro (`by`, `ccnl_key`), `NA` per il primo periodo o quando
uno dei due è mascherato; `indice` è la mediana rapportata alla prima
mediana non mascherata della stessa serie, per 100. Entrambe sono
calcolate sui periodi presenti in tabella: un periodo assente non
produce un salto vuoto.

Sui dati reali la copertura del campo è affidabile solo dal 2020 (oltre
il 96% di valori validi), utilizzabile con `copertura` a fianco nel
2014-2019 e inutilizzabile prima (vedi
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)).

## See also

[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md)
per i valori reali.

Other retribuzioni:
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
clean_retribuzione(dt, min_n = 30)
#> clean_retribuzione(): 3463 retribuzioni valide su 4746 (73.0%).
normalize_fte(dt)
ret <- median_retribuzione(dt, periodo = "anno", min_n = 10)
ret[ccnl_key == "A011"]
#>     anno ccnl_key classe     n n_valide copertura giornate      p25  mediana
#>    <int>   <char> <char> <int>    <int>     <num>    <num>    <num>    <num>
#> 1:  2019     A011   CCNL   149      102 0.6845638    31010 16384.00 20760.00
#> 2:  2020     A011   CCNL   164      124 0.7560976    27298 17318.26 21512.00
#> 3:  2021     A011   CCNL   148      113 0.7635135    29040 18883.00 24354.67
#> 4:  2022     A011   CCNL   155      119 0.7677419    28691 17123.00 20121.00
#> 5:  2023     A011   CCNL   137      102 0.7445255    20230 18566.00 23346.00
#> 6:  2024     A011   CCNL   151      117 0.7748344    12756 18795.00 24088.00
#>      p75    var_pct    indice
#>    <num>      <num>     <num>
#> 1: 26415         NA 100.00000
#> 2: 27410   3.622351 103.62235
#> 3: 28500  13.214330 117.31535
#> 4: 28371 -17.383390  96.92197
#> 5: 28661  16.028030 112.45665
#> 6: 30739   3.178275 116.03083

# per orario, senza pesi
median_retribuzione(dt, by = "orario", weights = "none", min_n = 10)[1:6]
#>    orario  anno ccnl_key classe     n n_valide copertura giornate   p25 mediana
#>    <char> <int>   <char> <char> <int>    <int>     <num>    <num> <num>   <num>
#> 1:     FT  2019     A011   CCNL   115       81 0.7043478    23465 16747   21307
#> 2:     FT  2020     A011   CCNL   112       87 0.7767857    21941 17396   21512
#> 3:     FT  2021     A011   CCNL   103       75 0.7281553    17835 16904   25015
#> 4:     FT  2022     A011   CCNL   108       85 0.7870370    19328 16900   21063
#> 5:     FT  2023     A011   CCNL   100       73 0.7300000    14812 18766   23353
#> 6:     FT  2024     A011   CCNL   108       85 0.7870370     9110 18661   22442
#>      p75     var_pct    indice
#>    <num>       <num>     <num>
#> 1: 27306          NA 100.00000
#> 2: 26732   0.9621251 100.96213
#> 3: 32397  16.2839345 117.40273
#> 4: 29768 -15.7985209  98.85484
#> 5: 28020  10.8721455 109.60248
#> 6: 28415  -3.9009977 105.32689
```
