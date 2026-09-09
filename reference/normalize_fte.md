# Normalizza la retribuzione alle ore di riferimento

Aggiunge per riferimento `ore_riferimento` (ore settimanali di
riferimento della riga), `retribuzione_fte` (retribuzione riportata alle
ore di riferimento) e `flag_fte` (esito della normalizzazione).

## Usage

``` r
normalize_fte(
  dt,
  ore_riferimento = 40,
  ore_riferimento_tabella = NULL,
  ore_min = 1,
  value_col = "retribuzione_pulita"
)
```

## Arguments

- dt:

  Un `data.table` di rapporti con le colonne `prior`, `ore` e
  `value_col` (di norma `retribuzione_pulita` da
  [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)).
  Viene modificato per riferimento.

- ore_riferimento:

  Ore settimanali di riferimento a tempo pieno usate per tutte le righe
  non coperte da `ore_riferimento_tabella`.

- ore_riferimento_tabella:

  `data.table` opzionale con una colonna chiave (`ccnl_key` oppure
  `macro_tipologia`, rilevata automaticamente) e la colonna
  `ore_riferimento`; le righe di `dt` non abbinate usano il valore
  scalare.

- ore_min:

  Ore minime perché un part-time venga riproporzionato; sotto questa
  soglia (o con `ore` mancante o pari a 0) il flag è `"ore_mancanti"`.

- value_col:

  Colonna da normalizzare; `"retribuzione"` è ammessa in modo esplicito
  per saltare la pulizia.

## Value

`dt`, restituito invisibilmente, con le colonne `ore_riferimento`
(numeric), `retribuzione_fte` (numeric) e `flag_fte` (character)
aggiunte per riferimento. L'attributo `ccnlcob_fte` è una lista con
`params` (`ore_riferimento`, `ore_min`, `value_col`, `tabella_key`) e
`riepilogo` (`data.table` con `flag_fte`, `n`, `quota`).

## Details

La diagnostica del 2026-09-09
(`reference/ccnlcob/diagnostica_retribuzione.md`, §5-6) mostra che:

- la retribuzione dichiarata per il tempo parziale è già proporzionata
  alle ore (il rapporto mediano part-time/full-time segue `ore/40` in
  tutte le fasce orarie), quindi la normalizzazione moltiplica per
  `ore_riferimento / ore`;

- `ore` è compilato quasi solo per il tempo parziale (mancante nel 95%
  dei tempo pieno e nel 30% dei part-time); fra i tempo pieno con `ore`
  compilato la moda e la mediana sono 40 in tutte le macro-tipologie
  salvo il lavoro domestico (54): `ore_riferimento = 40` è il default
  empiricamente giustificato e la tabella consente l'eccezione
  (`macro_tipologia = "Domestico"`, `ore_riferimento = 54`) o le ore
  contrattuali note per `ccnl_key` (36-39 ore);

- `ore == 0` è incompatibile con un rapporto attivo e viene trattato
  come mancante; per i part-time senza ore utilizzabili (32% delle
  righe) non esiste un valore di default difendibile (mediana 20, ma p10
  = 5 e p90 = 30): `retribuzione_fte` resta `NA`;

- `ore_min = 1` non esclude nulla: l'amplificazione dell'errore per ore
  molto basse è reale ma marginale in numerosità; l'argomento è esposto
  per chi vuole escluderle.

`flag_fte` e `retribuzione_fte` sono assegnati così, nell'ordine:

- `"non_valida"`: `value_col` mancante, `retribuzione_fte = NA`;

- `"full_time"`: `prior == 1`, valore invariato;

- `"ore_mancanti"`: `prior == 0` e `ore` mancante, 0 o `< ore_min`,
  `retribuzione_fte = NA`;

- `"ore_oltre_riferimento"`: `prior == 0` e `ore >= ore_riferimento`,
  valore invariato;

- `"riproporzionata"`: `prior == 0` e
  `ore_min <= ore < ore_riferimento`,
  `retribuzione_fte = valore * ore_riferimento / ore`;

- `"orario_ignoto"`: `prior` diverso da 0 e 1, `retribuzione_fte = NA`.

Se `ore` arriva come factor o character viene convertita come in
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md);
i valori della colonna non vengono altrimenti alterati. Applicare
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
prima di questa funzione: la regola MAD è tarata sui valori grezzi per
`prior`.

## See also

[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
per la pulizia preliminare.

Other retribuzioni:
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
clean_retribuzione(dt, min_n = 30)
#> clean_retribuzione(): 3463 retribuzioni valide su 4746 (73.0%).
normalize_fte(dt)
attr(dt, "ccnlcob_fte")$riepilogo
#>                 flag_fte     n       quota
#>                   <char> <int>       <num>
#> 1:             full_time  2369 0.499157185
#> 2:       riproporzionata  1069 0.225242309
#> 3: ore_oltre_riferimento     0 0.000000000
#> 4:          ore_mancanti    25 0.005267594
#> 5:            non_valida  1283 0.270332912
#> 6:         orario_ignoto     0 0.000000000

# ore di riferimento per macro-tipologia
tabella <- data.table::data.table(
  macro_tipologia = "Domestico",
  ore_riferimento = 54
)
normalize_fte(dt, ore_riferimento_tabella = tabella)
dt[, .N, by = .(macro_tipologia, ore_riferimento)]
#>        macro_tipologia ore_riferimento     N
#>                 <char>           <num> <int>
#> 1:    Somministrazione              40   624
#> 2:       Intermittente              40   435
#> 3:   Tempo determinato              40  1795
#> 4: Tempo indeterminato              40  1398
#> 5:       Apprendistato              40   399
#> 6:           Domestico              54    95
```
