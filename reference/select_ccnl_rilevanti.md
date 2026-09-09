# Seleziona i CCNL rilevanti da un ranking

Individua, entro ogni gruppo di un ranking prodotto da
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
i CCNL che coprono una quota cumulata della misura scelta e/o i primi
`top_n`, restituendo le chiavi selezionate oppure il ranking con i CCNL
non selezionati riassunti in una classe residua.

## Usage

``` r
select_ccnl_rilevanti(
  ranking,
  measure = "giornate",
  top_n = NULL,
  cum_share = 0.8,
  other_label = "Altri CCNL",
  return = c("keys", "table")
)
```

## Arguments

- ranking:

  Un `data.table` prodotto da
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md).

- measure:

  Misura su cui operare la selezione (es. `"giornate"`); nel ranking
  devono essere presenti `measure`, `quota_<measure>` e
  `rank_<measure>`.

- top_n:

  Numero massimo di CCNL da selezionare per gruppo; `NULL` per usare
  solo `cum_share`.

- cum_share:

  Soglia di quota cumulata in `(0, 1]`; `NULL` per usare solo `top_n`.
  Almeno uno fra `top_n` e `cum_share` deve essere fornito.

- other_label:

  Etichetta della classe residua nella tabella.

- return:

  `"keys"` per il vettore delle chiavi selezionate, `"table"` per il
  ranking con la classe residua.

## Value

Con `return = "keys"`, vettore character delle chiavi `ccnl_key`
selezionate (unione fra i gruppi, senza duplicati, gruppo per gruppo in
ordine di `rank_<measure>` e, a parità, di `ccnl_key`). Con
`return = "table"`, un `data.table` con le colonne del ranking più la
colonna logica `selezionato`, ordinato per gruppo con i CCNL selezionati
(in ordine di `rank_<measure>`), la classe residua e i non classificati;
l'attributo `ccnlcob_ranking` è conservato e l'attributo
`ccnlcob_selezione` riporta `measure`, `top_n`, `cum_share`,
`other_label` e le chiavi selezionate (`keys`). L'input non viene
modificato.

## Details

Entro ogni gruppo (`by` e `periodo` del ranking, letti dall'attributo
`ccnlcob_ranking` o, in sua assenza, dalle colonne che precedono
`ccnl_key`) i CCNL classificati sono scorsi in ordine di
`rank_<measure>` (a parità di rank, in ordine di `ccnl_key`). Un CCNL
viene selezionato finché la quota cumulata dei CCNL che lo precedono è
inferiore a `cum_share`: la selezione include quindi il CCNL con cui la
quota cumulata raggiunge o supera la soglia, ed è l'insieme minimo con
copertura `>= cum_share`. Le quote sono quelle del ranking, calcolate
sul totale del gruppo inclusi i non classificati. Se `top_n` è fornito
la selezione viene poi troncata ai primi `top_n` CCNL; con entrambi i
criteri prevale quindi il più restrittivo. La classe dei non
classificati non è mai selezionata. Entrambi i parametri sono espliciti:
il pacchetto non fissa soglie a priori.

Con `return = "table"` i CCNL classificati non selezionati di ogni
gruppo vengono aggregati in una riga con `ccnl_key = other_label` e
`classe = "Altri CCNL"`: le misure sono sommate, le quote `quota_*`
ricalcolate sul gruppo, `rank_*`, `quota_cum_*` ed etichette poste a
`NA`. La riga dei non classificati è conservata. Per le misure di
conteggio distinto (`n_lavoratori`, `n_datori`) la somma nella classe
residua è la somma dei conteggi per CCNL, non un conteggio distinto
sull'insieme.

## See also

[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
per la costruzione del ranking.

Other ranking:
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)

## Examples

``` r
dt <- data.table::copy(cob_esempio)[
  fine >= inizio & fine <= as.Date("2024-12-31")
]
dt[, `:=`(
  ccnl_key = codice_cnel,
  giornate = as.integer(fine - inizio + 1L),
  avviato = TRUE
)]
#>          id      cf     inizio       fine codice_cnel   ccnl
#>       <int>  <char>     <Date>     <Date>      <char> <char>
#>    1:     1 CF00001 2024-08-18 2024-12-09        Q011   2875
#>    2:     2 CF00002 2024-02-05 2024-04-28        D011   0752
#>    3:     3 CF00003 2020-01-12 2020-04-12        E011   1729
#>    4:     4 CF00004 2020-04-20 2021-07-15        B011   1489
#>    5:     5 CF00005 2019-08-08 2019-09-19        S011   1204
#>   ---                                                       
#> 4839:  4996 CF00363 2024-03-05 2024-04-25        H011   2614
#> 4840:  4997 CF00098 2022-03-19 2022-10-01        L011   1048
#> 4841:  4998 CF00340 2024-07-24 2024-12-31        G011   1883
#> 4842:  4999 CF00270 2023-10-05 2023-11-14        A011   2638
#> 4843:  5000 CF00098 2023-09-23 2024-12-31        H011   2614
#>       cod_tipologia_contrattuale prior comune_sede_lavoro comune_lavoratore
#>                           <char> <int>             <char>            <char>
#>    1:                    A.06.01     0               L682              F205
#>    2:                    A.05.02     0               C933              A794
#>    3:                    A.02.00     1               B157              F704
#>    4:                    A.06.01     1               E507              F205
#>    5:                    A.01.00     1               B157              B157
#>   ---                                                                      
#> 4839:                    C.01.00     0               F205              C933
#> 4840:                    A.02.00     1               B157              E507
#> 4841:                    A.06.01     1               F205              G388
#> 4842:                    A.02.00     1               A794              F205
#> 4843:                    A.01.00     1               L682              E507
#>         datore retribuzione   ore troncata qualifica ateco_gruppo   eta  sesso
#>         <char>        <num> <num>    <int>    <char>       <char> <int> <char>
#>    1: DAT00517           NA    17        0       253         41.2    40      F
#>    2: DAT00164         8645    20        0       541         10.7    47      F
#>    3: DAT00478           NA    38        0       712         43.3    49      M
#>    4: DAT00564        10776    36        0       813         81.2    27      F
#>    5: DAT00231           NA    40        0       813         85.5    27      M
#>   ---                                                                         
#> 4839: DAT00478        14161    28        0       132         43.3    47      M
#> 4840: DAT00427        54213    40        0       332         56.3    54      M
#> 4841: DAT00250        20852    40        1       341         25.6    40      F
#> 4842: DAT00458        18541    40        0       712         69.2    25      F
#> 4843: DAT00028           NA    40        1       332         87.3    55      M
#>       ccnl_key giornate avviato
#>         <char>    <int>  <lgcl>
#>    1:     Q011      114    TRUE
#>    2:     D011       84    TRUE
#>    3:     E011       92    TRUE
#>    4:     B011      452    TRUE
#>    5:     S011       43    TRUE
#>   ---                          
#> 4839:     H011       52    TRUE
#> 4840:     L011      197    TRUE
#> 4841:     G011      161    TRUE
#> 4842:     A011       41    TRUE
#> 4843:     H011      466    TRUE
ranking <- rank_ccnl(dt, measures = "giornate")

# Chiavi che coprono almeno l'80% delle giornate
select_ccnl_rilevanti(ranking, measure = "giornate", cum_share = 0.8)
#>  [1] "A011" "H011" "T011" "IC91" "C011" "A012" "B011" "E011" "D011" "F011"
#> [11] "H012" "I011" "M011" "L011" "K011" "G011" "N011" "H013" "T012" "Q011"
#> [21] "V011" "P011"

# Primi 5 CCNL e tabella con la classe residua
select_ccnl_rilevanti(
  ranking,
  measure = "giornate", top_n = 5, cum_share = NULL, return = "table"
)
#>      ccnl_key           classe selezionato giornate quota_giornate
#>        <char>           <char>      <lgcl>    <num>          <num>
#> 1:       A011             CCNL        TRUE   185093     0.19915257
#> 2:       H011             CCNL        TRUE    87403     0.09404209
#> 3:       T011             CCNL        TRUE    74687     0.08036019
#> 4:       IC91             CCNL        TRUE    51889     0.05583046
#> 5:       C011             CCNL        TRUE    41122     0.04424561
#> 6: Altri CCNL       Altri CCNL       FALSE   341664     0.36761663
#> 7:       <NA> Non classificati       FALSE   147545     0.15875245
#>    rank_giornate quota_cum_giornate
#>            <int>              <num>
#> 1:             1          0.1991526
#> 2:             2          0.2931947
#> 3:             3          0.3735549
#> 4:             4          0.4293853
#> 5:             5          0.4736309
#> 6:            NA                 NA
#> 7:            NA                 NA
```
