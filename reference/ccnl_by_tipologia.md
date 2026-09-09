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
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md),
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
tip <- ccnl_by_tipologia(dt, measure = "n_rapporti", level = "macro")
tip[ccnl_key == "A011"]
#>     ccnl_key classe           tipologia orario n_rapporti  quota_riga
#>       <char> <char>              <char> <char>      <int>       <num>
#>  1:     A011   CCNL   Tempo determinato     FT        275 0.304203540
#>  2:     A011   CCNL Tempo indeterminato     FT        209 0.231194690
#>  3:     A011   CCNL   Tempo determinato     PT         95 0.105088496
#>  4:     A011   CCNL    Somministrazione     FT         88 0.097345133
#>  5:     A011   CCNL Tempo indeterminato     PT         71 0.078539823
#>  6:     A011   CCNL       Apprendistato     FT         44 0.048672566
#>  7:     A011   CCNL       Intermittente     PT         38 0.042035398
#>  8:     A011   CCNL    Somministrazione     PT         26 0.028761062
#>  9:     A011   CCNL       Intermittente     FT         24 0.026548673
#> 10:     A011   CCNL       Apprendistato     PT         20 0.022123894
#> 11:     A011   CCNL           Domestico     PT          8 0.008849558
#> 12:     A011   CCNL           Domestico     FT          6 0.006637168
#>     quota_colonna        lq
#>             <num>     <num>
#>  1:     0.2099237 1.1020992
#>  2:     0.2019324 1.0601449
#>  3:     0.1958763 1.0283505
#>  4:     0.1929825 1.0131579
#>  5:     0.1955923 1.0268595
#>  6:     0.1471572 0.7725753
#>  7:     0.1328671 0.6975524
#>  8:     0.1547619 0.8125000
#>  9:     0.1610738 0.8456376
#> 10:     0.2000000 1.0500000
#> 11:     0.1379310 0.7241379
#> 12:     0.1621622 0.8513514

# Quote per macro-tipologia senza orario, in forma larga
largo <- ccnl_by_tipologia(dt, orario = FALSE)
data.table::dcast(largo, ccnl_key ~ tipologia, value.var = "quota_riga")[1:5]
#> Key: <ccnl_key>
#>    ccnl_key Apprendistato   Domestico Intermittente Somministrazione
#>      <char>         <num>       <num>         <num>            <num>
#> 1:     <NA>    0.09032258 0.023225806    0.09161290        0.1277419
#> 2:     A011    0.07079646 0.015486726    0.06858407        0.1261062
#> 3:     A012    0.07471264 0.017241379    0.06896552        0.1206897
#> 4:     B011    0.08974359 0.006410256    0.14102564        0.1217949
#> 5:     C011    0.06614786 0.015564202    0.07392996        0.1478599
#>    Tempo determinato Tempo indeterminato
#>                <num>               <num>
#> 1:         0.3574194           0.3096774
#> 2:         0.4092920           0.3097345
#> 3:         0.4655172           0.2528736
#> 4:         0.3269231           0.3141026
#> 5:         0.3618677           0.3346304

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
#>  6:  2024     A011   CCNL   A.03.09
#>  7:  2024     A011   CCNL   A.06.00
#>  8:  2024     A011   CCNL   A.03.08
#>  9:  2024     A011   CCNL   A.04.02
#> 10:  2024     H011   CCNL   A.02.00
#> 11:  2024     H011   CCNL   A.01.00
#> 12:  2024     H011   CCNL   A.06.01
#> 13:  2024     H011   CCNL   A.03.09
#> 14:  2024     H011   CCNL   A.02.01
#> 15:  2024     H011   CCNL   A.04.02
#> 16:  2024     H011   CCNL   A.05.02
#> 17:  2024     H011   CCNL   A.06.00
#> 18:  2024     H011   CCNL   A.03.08
#>                                                                                                                                              des_tipologia_contrattuale
#>                                                                                                                                                                  <char>
#>  1:                                                                                                                                        LAVORO A TEMPO INDETERMINATO
#>  2:                                                                                                                                          LAVORO A TEMPO DETERMINATO
#>  3:                                                                                               LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO DETERMINATO
#>  4:                                                                                                                         LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE
#>  5:                                                                                                                                                LAVORO INTERMITTENTE
#>  6:                                                                                                           APPRENDISTATO PROFESSIONALIZZANTE O CONTRATTO DI MESTIERE
#>  7:                                                                                             LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO INDETERMINATO
#>  8: APPRENDISTATO PER LA QUALIFICA E PER IL DIPLOMA PROFESSIONALE, IL DIPLOMA DI ISTRUZIONE SECONDARIA SUPERIORE E IL CERTIFICATO DI SPECIALIZZAZIONE TECNICA SUPERIORE
#>  9:                                                                                                                                                    LAVORO DOMESTICO
#> 10:                                                                                                                                          LAVORO A TEMPO DETERMINATO
#> 11:                                                                                                                                        LAVORO A TEMPO INDETERMINATO
#> 12:                                                                                               LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO DETERMINATO
#> 13:                                                                                                           APPRENDISTATO PROFESSIONALIZZANTE O CONTRATTO DI MESTIERE
#> 14:                                                                                                                         LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE
#> 15:                                                                                                                                                    LAVORO DOMESTICO
#> 16:                                                                                                                                                LAVORO INTERMITTENTE
#> 17:                                                                                             LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO INDETERMINATO
#> 18: APPRENDISTATO PER LA QUALIFICA E PER IL DIPLOMA PROFESSIONALE, IL DIPLOMA DI ISTRUZIONE SECONDARIA SUPERIORE E IL CERTIFICATO DI SPECIALIZZAZIONE TECNICA SUPERIORE
#>     giornate   quota_riga quota_colonna         lq
#>        <num>        <num>         <num>      <num>
#>  1:     5521 0.3304602861   0.232512108 1.21654477
#>  2:     4376 0.2619261387   0.148404382 0.77647816
#>  3:     2250 0.1346740887   0.192917774 1.00938016
#>  4:     1833 0.1097144909   0.377393453 1.97458977
#>  5:     1230 0.0736218352   0.162698413 0.85126708
#>  6:      847 0.0506973125   0.161548732 0.84525174
#>  7:      471 0.0281917759   0.221647059 1.15969689
#>  8:      170 0.0101753756   0.291095890 1.52306555
#>  9:        9 0.0005386964   0.005142857 0.02690834
#> 10:     3963 0.4250321750   0.134398209 1.26000483
#> 11:     2826 0.3030888031   0.119014529 1.11578036
#> 12:      811 0.0869798370   0.069536140 0.65191250
#> 13:      567 0.0608108108   0.108144192 1.01386920
#> 14:      329 0.0352852853   0.067737286 0.63504796
#> 15:      318 0.0341055341   0.181714286 1.70360066
#> 16:      301 0.0322822823   0.039814815 0.37327029
#> 17:      204 0.0218790219   0.096000000 0.90001544
#> 18:        5 0.0005362505   0.008561644 0.08026679
```
