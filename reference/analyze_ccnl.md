# Esegue l'analisi completa dei CCNL su un dataset di rapporti

Orchestra, su una copia di `dt`, l'intera catena del pacchetto:
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
[`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md),
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md),
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md),
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md),
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md),
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
e
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md).
Restituisce un oggetto di classe `ccnlcob_result` con le tabelle
precomputate per dashboard e report, da serializzare con
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md).
I blocchi facoltativi (giornate effettive, CPI, retribuzioni,
deflazione) vengono saltati, con motivazione registrata in
`meta$passi_saltati`, quando le colonne o le risorse necessarie non sono
disponibili; un input non valido produce invece un errore.

## Usage

``` r
analyze_ccnl(
  dt,
  as_of = NULL,
  window = NULL,
  perimetro = c("ccnl", "standard", "completo"),
  ccnl_key = c("codice_cnel", "ccnl_warehouse"),
  measure = "giornate",
  top_n = 20,
  cum_share = 0.8,
  geo = c("sede_lavoro", "residenza"),
  lookup_cpi = NULL,
  periodo = c("anno", "trimestre"),
  indice = NULL,
  base = NULL,
  effettive = TRUE,
  min_n = 30L,
  tipologie = ccnlcob::tipologie_contrattuali,
  quiet = TRUE
)
```

## Arguments

- dt:

  Un `data.table` di rapporti conforme a
  [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md).
  Non viene modificato.

- as_of:

  Data di riferimento (`Date` o stringa convertibile) per lo stato dei
  rapporti (`attivo`) e per la chiusura dei rapporti aperti; `NULL`
  (default) usa la data massima non sentinella osservata fra `inizio` e
  `fine`, cioè la data di riferimento dei dati.

- window:

  Vettore di due `Date` (o stringhe convertibili), `c(inizio, fine)`,
  che delimita l'analisi; `NULL` (default) usa `c(min(inizio), as_of)`,
  dove il minimo è calcolato sugli avviamenti non sentinella.

- perimetro:

  Perimetro contrattuale applicato da
  [`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)
  prima di ogni altro trattamento: `"ccnl"` (default) conserva solo le
  tipologie di lavoro subordinato alle quali si applica un CCNL;
  `"standard"` conserva il perimetro "standard" di `cnelR`; `"completo"`
  non esclude nulla. Vedi Dettagli.

- ccnl_key:

  Colonna da usare come chiave CCNL di analisi: `"codice_cnel"` (codice
  CNEL a 4 caratteri prodotto da `cnelR`) oppure `"ccnl_warehouse"`
  (codice warehouse CO). Con il default (entrambe) viene usata la prima
  colonna presente in `dt`; se una colonna richiesta esplicitamente è
  assente la funzione produce un errore.

- measure:

  Misura di rilevanza usata per selezionare i CCNL e per la
  distribuzione per CPI: una fra `"n_rapporti"`, `"n_lavoratori"`,
  `"n_datori"`, `"giornate"` (default), `"giornate_effettive"`,
  `"stock"`.

- top_n:

  Numero massimo di CCNL rilevanti; vedi
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).

- cum_share:

  Soglia di quota cumulata per la selezione dei CCNL rilevanti; vedi
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).

- geo:

  Geografia per il CPI (`"sede_lavoro"` o `"residenza"`); vedi
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md).

- lookup_cpi:

  Lookup esplicito comune -\> CPI (colonne `belfiore`, `cpi_code`,
  `cpi_name`) passato ad
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md);
  `NULL` usa `longworkR` se installato e se i file di mapping in
  `SHARED_DATA_DIR` sono presenti, altrimenti il blocco CPI viene
  saltato.

- periodo:

  Periodo di avviamento per le serie temporali (`"anno"` o
  `"trimestre"`).

- indice:

  `data.table` opzionale con la colonna di periodo (chiamata come
  `periodo` oppure `periodo`) e la colonna `indice` per la deflazione
  delle retribuzioni; `NULL` per omettere i valori reali.

- base:

  Periodo base per la deflazione; `NULL` usa l'ultimo periodo presente.
  Vedi
  [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md).

- effettive:

  Se `TRUE` (default) calcola `giornate_effettive` e la include fra le
  misure del ranking.

- min_n:

  Numerosità minima sotto la quale i quozienti di localizzazione e i
  quantili di retribuzione vengono mascherati.

- tipologie:

  Lookup delle tipologie contrattuali con le colonne
  `cod_tipologia_contrattuale`, `macro_tipologia`, `perimetro_ccnl` e
  `esclusa_standard`; default
  [tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).

- quiet:

  Se `TRUE` (default) sopprime i
  [`message()`](https://rdrr.io/r/base/message.html) dei passi
  intermedi.

## Value

Una lista di classe `ccnlcob_result` con gli elementi elencati nei
Dettagli.

## Details

Componenti del risultato:

- `meta`: lista con `versione`, `as_of`, `window`, `perimetro`,
  `ccnl_key`, `measure`, `n_input`, `n_finestra`, `n_rapporti`,
  `n_lavoratori`, `copertura_ccnl`, `copertura_retribuzione`, `passi`
  (passi eseguiti), `passi_saltati` (vettore nominato passo -\> motivo),
  `preparazione` (attributo `ccnlcob_meta` di
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md))
  e `tempi` (secondi per passo);

- `ranking` e `ranking_periodo`: output di
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
  sull'intera finestra e per `periodo`, con le misure `n_rapporti`,
  `n_lavoratori`, `n_datori` (se `datore` è presente), `giornate`,
  `giornate_effettive` (se calcolate) e `stock`;

- `rilevanti`: tabella di
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
  con il residuo "Altri CCNL"; `keys`: le chiavi selezionate;

- `cpi`: output di
  [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
  sui CCNL rilevanti (`NULL` se saltato);

- `tipologie`: output di
  [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
  (macro-tipologia per orario, misura `n_rapporti`) sui CCNL rilevanti;

- `retribuzioni`: output di
  [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
  sui CCNL rilevanti, con le colonne `_reale` se `indice` è fornito
  (`NULL` se la colonna `retribuzione` manca);

- `qualita`: per `ccnl_key` (inclusi i non classificati) `n` righe,
  `n_rapporti` avviati, `quota_troncata`, `copertura_retribuzione`,
  `copertura_ore` (part-time con ore valide), `copertura_cpi` (righe con
  CPI lombardo); `NA` dove il blocco non è stato calcolato.

## See also

[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)
per la serializzazione.

Other orchestrazione:
[`print.ccnlcob_result()`](https://gmontaletti.github.io/ccnlcob/reference/print.ccnlcob_result.md),
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)

## Examples

``` r
res <- analyze_ccnl(
  cob_esempio,
  window = as.Date(c("2022-01-01", "2024-12-31")),
  lookup_cpi = cpi_esempio,
  top_n = 10,
  min_n = 10
)
res
#> <ccnlcob_result>
#>   versione:                0.5.0
#>   as_of:                   2024-12-31
#>   window:                  2022-01-01 / 2024-12-31
#>   perimetro:               ccnl
#>   ccnl_key:                codice_cnel
#>   rapporti:                input 5.000, in finestra 2.927, avviati 2.436
#>   lavoratori avviati:      371
#>   copertura codice CCNL:   84,8%
#>   copertura retribuzione:  73,1%
#>   CCNL rilevanti:          10 (misura: giornate)
#>   primi CCNL:
#>      1. A011     19,1%
#>      2. H011     10,0%
#>      3. T011     7,9%
#>      4. C011     5,1%
#>      5. IC91     4,8%
#>   passi saltati:
#>     - deflate_retribuzione: nessun `indice` fornito
res$rilevanti[, .(ccnl_key, classe, giornate, quota_giornate)]
#>       ccnl_key           classe giornate quota_giornate
#>         <char>           <char>    <int>          <num>
#>  1:       A011             CCNL   118854     0.19057010
#>  2:       H011             CCNL    62233     0.09978418
#>  3:       T011             CCNL    49468     0.07931682
#>  4:       C011             CCNL    31713     0.05084852
#>  5:       IC91             CCNL    29904     0.04794797
#>  6:       A012             CCNL    23667     0.03794759
#>  7:       B011             CCNL    18770     0.03009575
#>  8:       E011             CCNL    18163     0.02912249
#>  9:       D011             CCNL    17326     0.02778045
#> 10:       F011             CCNL    17180     0.02754635
#> 11: Altri CCNL       Altri CCNL   135466     0.21720573
#> 12:       <NA> Non classificati   100932     0.16183403
res$qualita
#>     ccnl_key     n n_rapporti quota_troncata copertura_retribuzione
#>       <char> <int>      <int>          <num>                  <num>
#>  1:     A011   534        443      0.2041199              0.7677903
#>  2:     A012   111         93      0.1621622              0.7837838
#>  3:     B011    91         74      0.2087912              0.6593407
#>  4:     C011   163        138      0.1779141              0.7546012
#>  5:     C012    27         24      0.1851852              0.7777778
#>  6:     CPUB    32         28      0.2812500              0.6875000
#>  7:     D011    81         66      0.2098765              0.7530864
#>  8:     E011    75         62      0.2800000              0.7333333
#>  9:     F011    82         72      0.1951220              0.6951220
#> 10:     G011    60         53      0.2166667              0.7166667
#> 11:     H011   308        256      0.2305195              0.7305195
#> 12:     H012    64         55      0.2656250              0.7031250
#> 13:     H013    34         29      0.2647059              0.7647059
#> 14:     I011    68         58      0.2058824              0.6764706
#> 15:     IC91   136        106      0.1985294              0.6911765
#> 16:     K011    51         43      0.1372549              0.7254902
#> 17:     L011    59         50      0.2033898              0.7288136
#> 18:     M011    51         43      0.2549020              0.8431373
#> 19:     N011    51         47      0.2156863              0.6470588
#> 20:     P011    34         29      0.2058824              0.7058824
#> 21:     Q011    37         31      0.2162162              0.7567568
#> 22:     S011    32         29      0.1250000              0.6875000
#> 23:     T011   224        189      0.2321429              0.7410714
#> 24:     T012    44         38      0.2045455              0.7500000
#> 25:     V011    34         25      0.1764706              0.9117647
#> 26:     <NA>   444        355      0.2274775              0.6846847
#>     ccnl_key     n n_rapporti quota_troncata copertura_retribuzione
#>       <char> <int>      <int>          <num>                  <num>
#>     copertura_ore copertura_cpi
#>             <num>         <num>
#>  1:     1.0000000     0.9569288
#>  2:     0.9687500     0.9549550
#>  3:     0.9411765     0.9340659
#>  4:     0.9772727     0.9325153
#>  5:     1.0000000     0.9629630
#>  6:     0.9090909     1.0000000
#>  7:     1.0000000     0.9506173
#>  8:     1.0000000     0.9600000
#>  9:     0.9615385     0.9756098
#> 10:     1.0000000     0.9666667
#> 11:     0.9878049     0.9448052
#> 12:     0.9473684     0.9375000
#> 13:     1.0000000     0.9117647
#> 14:     0.9565217     0.9705882
#> 15:     0.9302326     0.9558824
#> 16:     1.0000000     0.9803922
#> 17:     0.9333333     0.9322034
#> 18:     1.0000000     0.9215686
#> 19:     1.0000000     0.9607843
#> 20:     1.0000000     0.9705882
#> 21:     0.9444444     1.0000000
#> 22:     1.0000000     0.9375000
#> 23:     0.9651163     0.9732143
#> 24:     1.0000000     0.9318182
#> 25:     1.0000000     0.9117647
#> 26:     0.9714286     0.9436937
#>     copertura_ore copertura_cpi
#>             <num>         <num>
```
