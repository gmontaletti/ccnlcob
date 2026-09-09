# Ordina i CCNL per misure di rilevanza

Calcola, per ciascun CCNL (ed eventualmente per gruppo e periodo), le
misure di rilevanza richieste, la quota sul totale, il rank e la quota
cumulata lungo il rank. Non viene costruito alcun indice composito: ogni
misura produce il proprio ordinamento e la selezione dei CCNL rilevanti
avviene a valle con
[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).

## Usage

``` r
rank_ccnl(
  dt,
  measures = c("n_lavoratori", "giornate"),
  by = NULL,
  periodo = NULL,
  ccnl_labels = NULL
)
```

## Arguments

- dt:

  Un `data.table` di rapporti già passato da
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
  con almeno le colonne `ccnl_key` e `giornate`; vedi i Dettagli per le
  colonne richieste da ciascuna misura.

- measures:

  Vettore character con le misure da calcolare, fra `"n_rapporti"`,
  `"n_lavoratori"`, `"n_datori"`, `"giornate"`, `"giornate_effettive"`,
  `"stock"`. La prima misura determina l'ordinamento delle righe in
  uscita.

- by:

  Vettore character con colonne aggiuntive di raggruppamento (es.
  `"macro_tipologia"`, `"sesso"`); `NULL` per il solo CCNL.

- periodo:

  Colonna temporale (`"anno"` o `"trimestre"`, prodotte da
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md))
  per un ranking per coorte di avviamento; `NULL` per l'intera finestra.
  Viene accodata alle colonne di `by`.

- ccnl_labels:

  `data.table` opzionale con la colonna `ccnl_key` e colonne di
  etichetta (es. `ccnl_titolo`, `macro_settore_cnel`) da agganciare al
  risultato con un left join; le chiavi devono essere univoche.

## Value

Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`), ordinato
per gruppo e per `rank_` della prima misura, con la riga dei non
classificati in coda a ogni gruppo. Colonne: quelle di `by` e `periodo`,
`ccnl_key`, `classe` (`"CCNL"` o `"Non classificati"`), le eventuali
etichette di `ccnl_labels` e, per ciascuna misura `m`, `m`, `quota_m`,
`rank_m` (integer, `NA` per i non classificati) e `quota_cum_m`.
L'attributo `ccnlcob_ranking` conserva `measures`, `by` e `periodo`.
L'input non viene modificato.

## Details

Le misure sono definite sulle righe di `dt` così:

- `n_rapporti`: numero di rapporti con `avviato == TRUE` (avviamento
  nella finestra di analisi);

- `n_lavoratori`: numero di `cf` distinti fra i rapporti avviati;

- `n_datori`: numero di `datore` distinti fra i rapporti avviati;

- `giornate`: somma di `giornate` (giorni-contratto nella finestra);

- `giornate_effettive`: somma di `giornate_effettive` (giorni-persona
  allocati pro quota, vedi
  [`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md));

- `stock`: numero di rapporti con `attivo == TRUE`, cioè aperti alla
  data `as_of` fissata in
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
  (fine originale mancante, sentinella o successiva ad `as_of`);
  coincide con `n_attivi` di `cnelR`.

Se `avviato` o `attivo` mancano vengono considerati `TRUE` per tutte le
righe, con un messaggio; un valore `NA` equivale a `FALSE`. Le colonne
`datore` e `giornate_effettive` sono richieste solo dalle misure che le
usano.

I rapporti con `ccnl_key` mancante formano la classe esplicita
`"Non classificati"` e non vengono scartati: la quota `quota_m` di ogni
riga è calcolata sul totale del gruppo inclusa questa classe, così che
le quote sommino a 1 entro ogni combinazione di `by` e `periodo`. Il
rank `rank_m` è assegnato solo ai CCNL classificati, in ordine
decrescente della misura, con i pari merito che ricevono il rank minimo
comune; la quota cumulata `quota_cum_m` segue l'ordine del rank (a
parità di valore, l'ordine alfabetico di `ccnl_key`) ed è `NA` per la
classe non classificata. Se il totale del gruppo è zero le quote sono
`NA`.

## See also

[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
per la selezione dei CCNL rilevanti.

Other ranking:
[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)

## Examples

``` r
# Tabella preparata a mano da cob_esempio (in uso reale: prepare_rapporti())
dt <- data.table::copy(cob_esempio)[
  fine >= inizio & fine <= as.Date("2024-12-31")
]
# attivo: rapporto aperto ad as_of; nel dataset di esempio la fine non
# osservata e' stata chiusa a monte alla data di stabilizzazione
# (troncata = 1)
dt[, `:=`(
  ccnl_key = codice_cnel,
  giornate = as.integer(fine - inizio + 1L),
  avviato = TRUE,
  attivo = troncata == 1L,
  anno = data.table::year(inizio)
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
#>       ccnl_key giornate avviato attivo  anno
#>         <char>    <int>  <lgcl> <lgcl> <int>
#>    1:     Q011      114    TRUE  FALSE  2024
#>    2:     D011       84    TRUE  FALSE  2024
#>    3:     E011       92    TRUE  FALSE  2020
#>    4:     B011      452    TRUE  FALSE  2020
#>    5:     S011       43    TRUE  FALSE  2019
#>   ---                                       
#> 4839:     H011       52    TRUE  FALSE  2024
#> 4840:     L011      197    TRUE  FALSE  2022
#> 4841:     G011      161    TRUE   TRUE  2024
#> 4842:     A011       41    TRUE  FALSE  2023
#> 4843:     H011      466    TRUE   TRUE  2023

ranking <- rank_ccnl(dt, measures = c("n_lavoratori", "giornate"))
head(ranking)
#>    ccnl_key classe n_lavoratori quota_n_lavoratori rank_n_lavoratori
#>      <char> <char>        <int>              <num>             <int>
#> 1:     A011   CCNL          311         0.10966150                 1
#> 2:     H011   CCNL          248         0.08744711                 2
#> 3:     T011   CCNL          198         0.06981664                 3
#> 4:     C011   CCNL          169         0.05959097                 4
#> 5:     IC91   CCNL          151         0.05324401                 5
#> 6:     A012   CCNL          126         0.04442877                 6
#>    quota_cum_n_lavoratori giornate quota_giornate rank_giornate
#>                     <num>    <num>          <num>         <int>
#> 1:              0.1096615   185093     0.19915257             1
#> 2:              0.1971086    87403     0.09404209             2
#> 3:              0.2669252    74687     0.08036019             3
#> 4:              0.3265162    41122     0.04424561             5
#> 5:              0.3797602    51889     0.05583046             4
#> 6:              0.4241890    33417     0.03595534             6
#>    quota_cum_giornate
#>                 <num>
#> 1:          0.1991526
#> 2:          0.2931947
#> 3:          0.3735549
#> 4:          0.4736309
#> 5:          0.4293853
#> 6:          0.5095863

# Ranking per coorte annuale di avviamento
per_anno <- rank_ccnl(dt, measures = "giornate", periodo = "anno")
per_anno[anno == 2024L & rank_giornate <= 3L]
#>     anno ccnl_key classe giornate quota_giornate rank_giornate
#>    <int>   <char> <char>    <num>          <num>         <int>
#> 1:  2024     A011   CCNL    16777     0.19332350             1
#> 2:  2024     H011   CCNL     8913     0.10270563             2
#> 3:  2024     T011   CCNL     7738     0.08916596             3
#>    quota_cum_giornate
#>                 <num>
#> 1:          0.1933235
#> 2:          0.2960291
#> 3:          0.3851951

# Etichette agganciate al risultato
etichette <- data.table::data.table(
  ccnl_key = c("A011", "H011"),
  ccnl_titolo = c("Titolo CCNL A011", "Titolo CCNL H011")
)
rank_ccnl(dt, measures = "giornate", ccnl_labels = etichette)[1:3]
#>    ccnl_key classe      ccnl_titolo giornate quota_giornate rank_giornate
#>      <char> <char>           <char>    <num>          <num>         <int>
#> 1:     A011   CCNL Titolo CCNL A011   185093     0.19915257             1
#> 2:     H011   CCNL Titolo CCNL H011    87403     0.09404209             2
#> 3:     T011   CCNL             <NA>    74687     0.08036019             3
#>    quota_cum_giornate
#>                 <num>
#> 1:          0.1991526
#> 2:          0.2931947
#> 3:          0.3735549
```
