# Dataset COB sintetico a livello di rapporto di lavoro

Dataset sintetico che riproduce il contratto dati in ingresso del
pacchetto (una riga per rapporto di lavoro, circa 5.000 rapporti). I
codici fiscali, i datori, i codici Belfiore e le retribuzioni sono
generati in modo deterministico e non corrispondono a persone, imprese o
comunicazioni reali.

## Usage

``` r
cob_esempio
```

## Format

Un `data.table` con una riga per rapporto di lavoro e le colonne:

- id:

  integer. Identificativo univoco del rapporto.

- cf:

  character. Identificativo sintetico della persona.

- inizio:

  Date. Data di avviamento.

- fine:

  Date. Data di cessazione; include le sentinelle `9999-12-31` e
  `1900-01-01` per i rapporti aperti.

- codice_cnel:

  character. Codice CNEL a 4 caratteri; `NA` per i rapporti non
  raccordati.

- ccnl:

  character. Codice warehouse CO del contratto collettivo (3-4
  caratteri).

- cod_tipologia_contrattuale:

  character. Codice MLPS della tipologia contrattuale (es. `A.01.00`).

- prior:

  integer. 1 per tempo pieno, 0 per tempo parziale.

- comune_sede_lavoro:

  character. Codice Belfiore del comune della sede di lavoro.

- comune_lavoratore:

  character. Codice Belfiore del comune di residenza del lavoratore.

- datore:

  character. Identificativo sintetico del datore di lavoro.

- retribuzione:

  numeric. Retribuzione annua lorda dichiarata all'avviamento; contiene
  `NA` e valori implausibili.

- ore:

  numeric. Ore settimanali medie.

- troncata:

  integer. 1 se `fine` è stata clampata alla data di stabilizzazione, 0
  altrimenti.

- qualifica:

  character. Codice della qualifica professionale.

- ateco_gruppo:

  character. Gruppo ATECO della sede di lavoro.

- eta:

  integer. Età del lavoratore all'avviamento.

- sesso:

  character. Sesso del lavoratore (`F`/`M`).

## Source

Generato da `data-raw/cob_esempio.R` con un generatore deterministico
(`generate_cob_sintetico()`); nessun dato reale.

## Details

Il dataset contiene intenzionalmente: rapporti sovrapposti per la stessa
persona (per
[`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md)),
date di fine sentinella `9999-12-31` e `1900-01-01` (rapporti aperti,
gestiti da
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)),
retribuzioni mancanti e valori implausibili (per
[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)),
codici CNEL mancanti per una quota di rapporti non raccordati e una
quota di sedi di lavoro fuori regione.

## See also

[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md),
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)

## Examples

``` r
str(cob_esempio)
#> Classes ‘data.table’ and 'data.frame':   5000 obs. of  18 variables:
#>  $ id                        : int  1 2 3 4 5 6 7 8 9 10 ...
#>  $ cf                        : chr  "CF00001" "CF00002" "CF00003" "CF00004" ...
#>  $ inizio                    : Date, format: "2024-08-18" "2024-02-05" ...
#>  $ fine                      : Date, format: "2024-12-09" "2024-04-28" ...
#>  $ codice_cnel               : chr  "Q011" "D011" "E011" "B011" ...
#>  $ ccnl                      : chr  "2875" "0752" "1729" "1489" ...
#>  $ cod_tipologia_contrattuale: chr  "A.06.01" "A.05.02" "A.02.00" "A.06.01" ...
#>  $ prior                     : int  0 0 1 1 1 1 1 1 1 1 ...
#>  $ comune_sede_lavoro        : chr  "L682" "C933" "B157" "E507" ...
#>  $ comune_lavoratore         : chr  "F205" "A794" "F704" "F205" ...
#>  $ datore                    : chr  "DAT00517" "DAT00164" "DAT00478" "DAT00564" ...
#>  $ retribuzione              : num  NA 8645 NA 10776 NA ...
#>  $ ore                       : num  17 20 38 36 40 40 40 36 36 40 ...
#>  $ troncata                  : int  0 0 0 0 0 0 1 0 0 0 ...
#>  $ qualifica                 : chr  "253" "541" "712" "813" ...
#>  $ ateco_gruppo              : chr  "41.2" "10.7" "43.3" "81.2" ...
#>  $ eta                       : int  40 47 49 27 27 51 56 56 59 22 ...
#>  $ sesso                     : chr  "F" "F" "M" "F" ...
#>  - attr(*, ".internal.selfref")=<pointer: (nil)> 
```
