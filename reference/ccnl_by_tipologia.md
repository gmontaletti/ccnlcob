# Distribuisce i CCNL per tipologia contrattuale

Calcola la tabella `ccnl_key` x tipologia (x orario) con il valore della
misura scelta, la quota di riga (entro CCNL), la quota di colonna (entro
tipologia) e il quoziente di localizzazione, eventualmente per gruppo
(`by`) e per coorte di avviamento (`periodo`). La tipologia può essere
la macro-classe di
[tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md)
o il codice MLPS di dettaglio.

## Usage

``` r
ccnl_by_tipologia(
  dt,
  measure = "n_rapporti",
  ccnl = NULL,
  level = c("macro", "codice"),
  orario = TRUE,
  periodo = NULL,
  by = NULL,
  min_n = 30L,
  tipologie = ccnlcob::tipologie_contrattuali
)
```

## Arguments

- dt:

  Un `data.table` di rapporti già passato da
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
  (colonne `ccnl_key`, `giornate`, `avviato`, `attivo`, `anno`,
  `trimestre`, `macro_tipologia`, `orario`). Se `macro_tipologia` o
  `orario` mancano vengono ricalcolate su una copia da
  `cod_tipologia_contrattuale` (con
  [`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md))
  e da `prior`. `dt` non viene modificato.

- measure:

  Misura da distribuire, una fra `"n_rapporti"` (default),
  `"n_lavoratori"`, `"n_datori"`, `"giornate"`, `"giornate_effettive"`,
  `"stock"`, con le definizioni di
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md).

- ccnl:

  `NULL` (default) per tutte le chiavi, altrimenti vettore character
  delle `ccnl_key` da conservare in uscita; `NA` conserva i non
  classificati. Le chiavi assenti da `dt` producono un avviso. Il filtro
  agisce dopo il calcolo dei totali (vedi Dettagli).

- level:

  Livello della tipologia: `"macro"` (macro-classe di `tipologie`) o
  `"codice"` (codice MLPS `cod_tipologia_contrattuale`, con la
  descrizione `des_tipologia_contrattuale` letta da `tipologie`).

- orario:

  Se `TRUE` (default) la distribuzione è incrociata anche con l'orario
  (`"FT"`/`"PT"`); con `FALSE` la dimensione è omessa.

- periodo:

  Colonna temporale (`"anno"` o `"trimestre"`) per una distribuzione per
  coorte di avviamento; `NULL` per l'intera finestra.

- by:

  Vettore character con colonne aggiuntive di raggruppamento (es.
  `"sesso"`); `NULL` per il solo CCNL.

- min_n:

  Soglia sul totale della tipologia (per gruppo) sotto la quale il
  quoziente di localizzazione è mascherato con `NA`.

- tipologie:

  Lookup delle tipologie contrattuali con le colonne
  `cod_tipologia_contrattuale`, `macro_tipologia` e, per
  `level = "codice"`, `des_tipologia_contrattuale`; default
  [tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).

## Value

Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`,
`tipologia`, eventualmente `orario`) e le colonne: quelle di `by` e
`periodo`, `ccnl_key`, `classe` (`"CCNL"` o `"Non classificati"`),
`tipologia`, `des_tipologia_contrattuale` (solo con `level = "codice"`),
`orario` (solo con `orario = TRUE`), `<measure>`, `quota_riga`,
`quota_colonna`, `lq`; ordinato per gruppo, `ccnl_key` (non classificati
in coda) e misura decrescente. L'attributo `ccnlcob_crosstab` riporta
`measure`, `dims`, `by`, `periodo`, `min_n`, `level` e `orario`. L'input
non viene modificato.

## Details

Per ogni gruppo `g` (combinazione di `by` e `periodo`), CCNL `c` e cella
di dimensione `d` (tipologia, eventualmente incrociata con l'orario),
detto `v` il valore della misura nella cella e `T` il totale del gruppo:

- `quota_riga = v[c,d] / T[c]`: composizione contrattuale del CCNL,
  somma a 1 entro ogni (`g`, `ccnl_key`);

- `quota_colonna = v[c,d] / T[d]`: peso del CCNL entro la tipologia,
  somma a 1 entro ogni (`g`, `d`);

- `lq = quota_colonna / (T[c] / T)`: quoziente di localizzazione; valori
  maggiori di 1 indicano che il CCNL ricorre alla tipologia più della
  media del gruppo. Entro ogni CCNL la media di `lq` ponderata con
  `T[d] / T` è pari a 1.

I totali `T[c]`, `T[d]` e `T` sono calcolati su tutte le righe di `dt`,
inclusi i rapporti con `ccnl_key` mancante (classe `"Non classificati"`,
conservata in uscita) e prima dell'eventuale filtro `ccnl`: le quote dei
CCNL conservati non cambiano filtrando. Le celle con `T[d] < min_n`
hanno `lq = NA` ma non vengono eliminate. Se un totale è zero le quote
corrispondenti sono `NA`.

I rapporti con tipologia non riconducibile a una macro-classe formano la
tipologia `"Non classificata"` (`level = "macro"`); i codici MLPS
mancanti formano la tipologia `"ND"` (`level = "codice"`), con
`des_tipologia_contrattuale` `NA` per i codici ignoti al lookup.
L'orario mancante forma la classe `"ND"`. Nessun rapporto viene
scartato. Per le misure di conteggio distinto (`n_lavoratori`,
`n_datori`) la somma delle celle di un CCNL può superare il conteggio
del CCNL in
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
perché una persona può comparire in più tipologie.

## See also

[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md),
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md).

Other tipologie:
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
tip <- ccnl_by_tipologia(dt, measure = "n_rapporti", level = "macro")
tip[ccnl_key == "A011"]
#>     ccnl_key classe           tipologia orario n_rapporti  quota_riga
#>       <char> <char>              <char> <char>      <int>       <num>
#>  1:     A011   CCNL   Tempo determinato     FT        275 0.285269710
#>  2:     A011   CCNL Tempo indeterminato     FT        209 0.216804979
#>  3:     A011   CCNL   Tempo determinato     PT         95 0.098547718
#>  4:     A011   CCNL    Somministrazione     FT         88 0.091286307
#>  5:     A011   CCNL Tempo indeterminato     PT         71 0.073651452
#>  6:     A011   CCNL       Apprendistato     FT         44 0.045643154
#>  7:     A011   CCNL       Intermittente     PT         38 0.039419087
#>  8:     A011   CCNL    Somministrazione     PT         26 0.026970954
#>  9:     A011   CCNL       Intermittente     FT         24 0.024896266
#> 10:     A011   CCNL      Collaborazioni     FT         22 0.022821577
#> 11:     A011   CCNL       Apprendistato     PT         20 0.020746888
#> 12:     A011   CCNL           Tirocinio     FT         20 0.020746888
#> 13:     A011   CCNL      Collaborazioni     PT         10 0.010373444
#> 14:     A011   CCNL           Domestico     PT          8 0.008298755
#> 15:     A011   CCNL           Domestico     FT          6 0.006224066
#> 16:     A011   CCNL           Tirocinio     PT          4 0.004149378
#> 17:     A011   CCNL               Altro     FT          3 0.003112033
#> 18:     A011   CCNL               Altro     PT          1 0.001037344
#>     quota_colonna        lq
#>             <num>     <num>
#>  1:     0.2099237 1.0888157
#>  2:     0.2019324 1.0473670
#>  3:     0.1958763 1.0159559
#>  4:     0.1929825 1.0009463
#>  5:     0.1955923 1.0144828
#>  6:     0.1471572 0.7632634
#>  7:     0.1328671 0.6891449
#>  8:     0.1547619 0.8027070
#>  9:     0.1610738 0.8354452
#> 10:     0.2417582 1.2539328
#> 11:     0.2000000 1.0373444
#> 12:     0.2531646 1.3130942
#> 13:     0.2941176 1.5255065
#> 14:     0.1379310 0.7154099
#> 15:     0.1621622 0.8410901
#> 16:     0.1290323 0.6692545
#> 17:     0.1875000        NA
#> 18:     0.3333333        NA

# Quote per macro-tipologia senza orario, in forma larga
largo <- ccnl_by_tipologia(dt, orario = FALSE)
data.table::dcast(largo, ccnl_key ~ tipologia, value.var = "quota_riga")[1:5]
#> Key: <ccnl_key>
#>    ccnl_key       Altro Apprendistato Collaborazioni   Domestico Intermittente
#>      <char>       <num>         <num>          <num>       <num>         <num>
#> 1:     <NA>          NA    0.08533333     0.01866667 0.022666667    0.08666667
#> 2:     A011 0.004149378    0.06639004     0.03319502 0.014522822    0.06431535
#> 3:     A012          NA    0.07065217     0.02173913 0.016304348    0.06521739
#> 4:     B011 0.012195122    0.08536585     0.01829268 0.006097561    0.13414634
#> 5:     C011          NA    0.06273063     0.02952030 0.014760148    0.07011070
#>    Somministrazione Tempo determinato Tempo indeterminato  Tirocinio
#>               <num>             <num>               <num>      <num>
#> 1:        0.1226667         0.3400000           0.3013333 0.02266667
#> 2:        0.1182573         0.3838174           0.2904564 0.02489627
#> 3:        0.1141304         0.4402174           0.2391304 0.03260870
#> 4:        0.1158537         0.3109756           0.2987805 0.01829268
#> 5:        0.1402214         0.3431734           0.3173432 0.02214022

# Codici MLPS con descrizione, giornate per anno, solo due CCNL
ccnl_by_tipologia(
  dt,
  measure = "giornate", ccnl = c("A011", "H011"),
  level = "codice", orario = FALSE, periodo = "anno"
)[anno == 2024L]
#>      anno ccnl_key classe tipologia
#>     <int>   <char> <char>    <char>
#>  1:  2024     A011   CCNL   A.01.00
#>  2:  2024     A011   CCNL   A.02.00
#>  3:  2024     A011   CCNL   A.06.01
#>  4:  2024     A011   CCNL   A.02.01
#>  5:  2024     A011   CCNL   A.05.02
#>  6:  2024     A011   CCNL   B.03.00
#>  7:  2024     A011   CCNL   A.03.09
#>  8:  2024     A011   CCNL   A.06.00
#>  9:  2024     A011   CCNL   C.01.00
#> 10:  2024     A011   CCNL   A.03.08
#> 11:  2024     A011   CCNL   B.04.00
#> 12:  2024     A011   CCNL   A.04.02
#> 13:  2024     H011   CCNL   A.02.00
#> 14:  2024     H011   CCNL   A.01.00
#> 15:  2024     H011   CCNL   A.06.01
#> 16:  2024     H011   CCNL   C.01.00
#> 17:  2024     H011   CCNL   A.03.09
#> 18:  2024     H011   CCNL   A.02.01
#> 19:  2024     H011   CCNL   A.04.02
#> 20:  2024     H011   CCNL   A.05.02
#> 21:  2024     H011   CCNL   B.03.00
#> 22:  2024     H011   CCNL   A.06.00
#> 23:  2024     H011   CCNL   B.04.00
#> 24:  2024     H011   CCNL   A.03.08
#>      anno ccnl_key classe tipologia
#>     <int>   <char> <char>    <char>
#>                                                                                                                                              des_tipologia_contrattuale
#>                                                                                                                                                                  <char>
#>  1:                                                                                                                                        LAVORO A TEMPO INDETERMINATO
#>  2:                                                                                                                                          LAVORO A TEMPO DETERMINATO
#>  3:                                                                                               LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO DETERMINATO
#>  4:                                                                                                                         LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE
#>  5:                                                                                                                                                LAVORO INTERMITTENTE
#>  6:                                                                                                                            COLLABORAZIONE COORDINATA E CONTINUATIVA
#>  7:                                                                                                           APPRENDISTATO PROFESSIONALIZZANTE O CONTRATTO DI MESTIERE
#>  8:                                                                                             LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO INDETERMINATO
#>  9:                                                                                                                                                           TIROCINIO
#> 10: APPRENDISTATO PER LA QUALIFICA E PER IL DIPLOMA PROFESSIONALE, IL DIPLOMA DI ISTRUZIONE SECONDARIA SUPERIORE E IL CERTIFICATO DI SPECIALIZZAZIONE TECNICA SUPERIORE
#> 11:                                                                                                   COLLABORAZIONE OCCASIONALE SPORTIVA EX ART. 28 DEL D.LGS. 36/2021
#> 12:                                                                                                                                                    LAVORO DOMESTICO
#> 13:                                                                                                                                          LAVORO A TEMPO DETERMINATO
#> 14:                                                                                                                                        LAVORO A TEMPO INDETERMINATO
#> 15:                                                                                               LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO DETERMINATO
#> 16:                                                                                                                                                           TIROCINIO
#> 17:                                                                                                           APPRENDISTATO PROFESSIONALIZZANTE O CONTRATTO DI MESTIERE
#> 18:                                                                                                                         LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE
#> 19:                                                                                                                                                    LAVORO DOMESTICO
#> 20:                                                                                                                                                LAVORO INTERMITTENTE
#> 21:                                                                                                                            COLLABORAZIONE COORDINATA E CONTINUATIVA
#> 22:                                                                                             LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO INDETERMINATO
#> 23:                                                                                                   COLLABORAZIONE OCCASIONALE SPORTIVA EX ART. 28 DEL D.LGS. 36/2021
#> 24: APPRENDISTATO PER LA QUALIFICA E PER IL DIPLOMA PROFESSIONALE, IL DIPLOMA DI ISTRUZIONE SECONDARIA SUPERIORE E IL CERTIFICATO DI SPECIALIZZAZIONE TECNICA SUPERIORE
#>                                                                                                                                              des_tipologia_contrattuale
#>                                                                                                                                                                  <char>
#>     giornate   quota_riga quota_colonna         lq
#>        <int>        <num>         <num>      <num>
#>  1:     5521 0.3004298852   0.232512108 1.18728322
#>  2:     4376 0.2381237416   0.148404382 0.75780153
#>  3:     2250 0.1224356533   0.192917774 0.98510154
#>  4:     1833 0.0997442455   0.377393453 1.92709497
#>  5:     1230 0.0669314905   0.162698413 0.83079155
#>  6:     1191 0.0648092725   0.459136469 2.34450166
#>  7:      847 0.0460902215   0.161548732 0.82492090
#>  8:      471 0.0256298634   0.221647059 1.13180271
#>  9:      366 0.0199161996   0.136567164 0.69735681
#> 10:      170 0.0092506938   0.291095890 1.48643126
#> 11:      113 0.0061489906   0.131855309 0.67329653
#> 12:        9 0.0004897426   0.005142857 0.02626112
#> 13:     3963 0.3801438849   0.134398209 1.20976437
#> 14:     2826 0.2710791367   0.119014529 1.07129059
#> 15:      811 0.0777937650   0.069536140 0.62591864
#> 16:      694 0.0665707434   0.258955224 2.33094477
#> 17:      567 0.0543884892   0.108144192 0.97344296
#> 18:      329 0.0315587530   0.067737286 0.60972654
#> 19:      318 0.0305035971   0.181714286 1.63567260
#> 20:      301 0.0288729017   0.039814815 0.35838680
#> 21:      255 0.0244604317   0.098303778 0.88486602
#> 22:      204 0.0195683453   0.096000000 0.86412892
#> 23:      152 0.0145803357   0.177362894 1.59650423
#> 24:        5 0.0004796163   0.008561644 0.07706629
#>     giornate   quota_riga quota_colonna         lq
#>        <int>        <num>         <num>      <num>
```
