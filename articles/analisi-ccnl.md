# Analisi dei CCNL nei dati COB

## Obiettivo

Questa vignetta descrive il flusso di lavoro di `ccnlcob` per analizzare
un dataset di Comunicazioni Obbligatorie (COB) a livello di rapporto di
lavoro per contratto collettivo nazionale (CCNL). Il flusso risponde a
quattro domande: quali CCNL sono più rilevanti (persone avviate e
giornate di lavoro), come si distribuiscono per CPI (Centro per
l’Impiego), come si distribuiscono per tipologia contrattuale e come
evolve la retribuzione mediana dichiarata all’avviamento.

Nella versione 0.2.0 sono operative le prime due fasi del flusso:
validazione del contratto dati, preparazione dei rapporti, calcolo delle
giornate di contratto, ranking e selezione dei CCNL rilevanti (Fase 1),
distribuzione territoriale per CPI e distribuzione per tipologia
contrattuale (Fase 2). I blocchi di codice di queste sezioni vengono
eseguiti sul dataset sintetico `cob_esempio` incluso nel pacchetto, con
il lookup comune -\> CPI `cpi_esempio`. Le funzioni delle fasi
successive (retribuzioni, giornate effettive, orchestrazione, lettura
dei dati) sono documentate con la firma definitiva ma restituiscono un
errore esplicito; i relativi blocchi sono raccolti nella sezione finale
e non vengono eseguiti.

``` r

library(ccnlcob)
library(data.table)
#> 
#> Attaching package: 'data.table'
#> The following object is masked from 'package:base':
#> 
#>     %notin%
```

## 1. Validazione del contratto dati

[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)
verifica che il dataset sia un `data.table` e che contenga le colonne
del contratto dati. Il blocco `base` (`id`, `cf`, `inizio`, `fine`,
`cod_tipologia_contrattuale`, `prior` e almeno una colonna CCNL fra
`codice_cnel`, `ccnl` e `ccnl_warehouse`) è sempre controllato; i
blocchi `cpi`, `retribuzione` e `datore` vengono verificati solo se
richiesti. La funzione non modifica il dataset e, se il controllo passa,
lo restituisce invisibilmente.

Il dataset sintetico `cob_esempio` riproduce il contratto dati con
sovrapposizioni fra rapporti della stessa persona, sentinelle sulle date
di fine, codici CNEL mancanti per una quota di rapporti e retribuzioni
mancanti o anomale.

``` r

dt <- copy(cob_esempio)
validate_rapporti(dt)
validate_rapporti(dt, require = c("cpi", "retribuzione", "datore"))
str(dt)
#> Classes 'data.table' and 'data.frame':   5000 obs. of  18 variables:
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
#>  - attr(*, ".internal.selfref")=<pointer: 0x55a9f841ff20>
```

## 2. Preparazione

[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
lavora su una copia e restituisce un nuovo `data.table`. In sequenza:

- rinomina le varianti maiuscole prodotte dalla pipeline COB e la
  colonna sorgente `ccnl` (codice warehouse) in `ccnl_warehouse`;
- sceglie la chiave di analisi `ccnl_key`: per default `codice_cnel` se
  presente, altrimenti `ccnl_warehouse`;
- risolve le sentinelle sulle date. Una `fine` mancante, non successiva
  a `1900-01-01` o successiva ad `as_of` (incluso `9999-12-31`)
  identifica un rapporto aperto: la data viene sostituita con `as_of` e
  `troncata` vale 1. Un `inizio` mancante o non successivo a
  `1900-01-01` viene portato al `2008-03-01` (avvio del sistema COB) con
  `troncata_inizio` pari a 1. Dopo le sostituzioni, un rapporto con
  `fine < inizio` viene riportato a un giorno;
- rimuove i rapporti che non intersecano la finestra `window` e conta le
  giornate di contratto interne alla finestra;
- aggiunge le colonne derivate `avviato`, `attivo`, `anno`, `trimestre`,
  `macro_tipologia` e `orario`.

Se `as_of` è `NULL` viene usata la data massima non sentinella osservata
fra `inizio` e `fine`; se `window` è `NULL` la finestra va dal primo
avviamento non sentinella ad `as_of`. Nell’esempio entrambi i parametri
sono espliciti: la finestra copre il triennio 2022-2024 e lo stato dei
rapporti è valutato al 31 dicembre 2024.

``` r

dt <- prepare_rapporti(
  dt,
  as_of = as.Date("2024-12-31"),
  window = as.Date(c("2022-01-01", "2024-12-31")),
  ccnl_key = "codice_cnel"
)
```

L’attributo `ccnlcob_meta` conserva i parametri usati e i conteggi delle
correzioni: rapporti in ingresso, rapporti esclusi perché esterni alla
finestra, sentinelle su `fine` e su `inizio`, intervalli con
`fine < inizio`.

``` r

attr(dt, "ccnlcob_meta")
#> $as_of
#> [1] "2024-12-31"
#> 
#> $window
#> [1] "2022-01-01" "2024-12-31"
#> 
#> $ccnl_key
#> [1] "codice_cnel"
#> 
#> $n_input
#> [1] 5000
#> 
#> $n_dropped_window
#> [1] 1935
#> 
#> $n_sentinel_fine
#> [1] 155
#> 
#> $n_sentinel_inizio
#> [1] 0
#> 
#> $n_fine_lt_inizio
#> [1] 2
```

Le colonne aggiunte hanno il seguente significato:

- `giornate` (integer): giorni di contratto compresi nella finestra,
  estremi inclusi. Un rapporto iniziato prima di `window[1]` o terminato
  dopo `window[2]` conta solo la parte interna alla finestra; poiché i
  rapporti esterni sono già stati rimossi, `giornate` è sempre maggiore
  o uguale a 1;
- `avviato` (logical): `inizio >= window[1]`, cioè avviamento interno
  alla finestra. I rapporti iniziati prima della finestra restano nel
  dataset con `avviato = FALSE`: contribuiscono alle giornate ma non ai
  conteggi di avviamenti e persone avviate;
- `attivo` (logical): rapporto in essere alla data `as_of`;
- `anno` (integer) e `trimestre` (character, `YYYY-Qn`): coorte di
  avviamento calcolata da `inizio`;
- `macro_tipologia` (character): macro-classe della tipologia
  contrattuale, `NA` per i codici assenti dal lookup;
- `orario` (character): `FT` per `prior == 1`, `PT` per `prior == 0`.

``` r

knitr::kable(
  dt[1:6, .(
    id, inizio, fine, ccnl_key, giornate, avviato, attivo,
    anno, trimestre, macro_tipologia, orario
  )]
)
```

| id | inizio | fine | ccnl_key | giornate | avviato | attivo | anno | trimestre | macro_tipologia | orario |
|---:|:---|:---|:---|---:|:---|:---|---:|:---|:---|:---|
| 1 | 2024-08-18 | 2024-12-09 | Q011 | 114 | TRUE | FALSE | 2024 | 2024-Q3 | Somministrazione | PT |
| 2 | 2024-02-05 | 2024-04-28 | D011 | 84 | TRUE | FALSE | 2024 | 2024-Q1 | Intermittente | PT |
| 6 | 2023-07-03 | 2023-08-15 | H011 | 44 | TRUE | FALSE | 2023 | 2023-Q3 | Tempo determinato | FT |
| 7 | 2024-03-20 | 2024-12-31 | A011 | 287 | TRUE | TRUE | 2024 | 2024-Q1 | Tempo indeterminato | FT |
| 8 | 2020-02-10 | 2023-07-22 | B011 | 568 | FALSE | FALSE | 2020 | 2020-Q1 | Tempo determinato | FT |
| 10 | 2023-07-01 | 2024-02-02 | IC91 | 217 | TRUE | FALSE | 2023 | 2023-Q3 | Tempo determinato | FT |

``` r

dt[, .(rapporti = .N, giornate = sum(giornate)), by = avviato]
#>    avviato rapporti giornate
#>     <lgcl>    <int>    <int>
#> 1:    TRUE     2550   452820
#> 2:   FALSE      515   197646
```

La macro-tipologia deriva dal lookup `tipologie_contrattuali`, incluso
nel pacchetto, tramite
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md).
La funzione è vettorizzata, conserva ordine e lunghezza dell’input e
restituisce `NA` per i codici ignoti.

``` r

classify_tipologia(c("A.01.00", "A.02.00", "A.03.00", "C.01.00", "ZZZ", NA))
#> [1] "Tempo indeterminato" "Tempo determinato"   "Apprendistato"      
#> [4] "Tirocinio"           NA                    NA
dt[, .N, by = .(macro_tipologia, orario)][order(-N)]
#>         macro_tipologia orario     N
#>                  <char> <char> <int>
#>  1:   Tempo determinato     FT   808
#>  2: Tempo indeterminato     FT   635
#>  3:   Tempo determinato     PT   311
#>  4:    Somministrazione     FT   277
#>  5: Tempo indeterminato     PT   232
#>  6:       Apprendistato     FT   173
#>  7:       Intermittente     PT   167
#>  8:    Somministrazione     PT   111
#>  9:       Intermittente     FT    93
#> 10:       Apprendistato     PT    63
#> 11:           Tirocinio     FT    50
#> 12:      Collaborazioni     FT    44
#> 13:           Domestico     PT    31
#> 14:           Domestico     FT    26
#> 15:      Collaborazioni     PT    20
#> 16:           Tirocinio     PT    17
#> 17:               Altro     FT     7
```

## 3. Giornate di contratto

[`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)
è la funzione richiamata da
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
per calcolare `giornate`. Per ogni rapporto

    giornate = max(0, min(fine, window[2]) - max(inizio, window[1]) + 1)

con `window = NULL` la misura coincide con l’intera durata del rapporto.
La colonna è di tipo integer e viene aggiunta per riferimento, quindi la
funzione modifica il `data.table` passato come argomento. La misura è
additiva: ogni rapporto conta per intero e le sovrapposizioni fra
rapporti della stessa persona non vengono corrette. La correzione pro
quota è demandata a
[`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md),
prevista nella Fase 4.

La funzione può essere richiamata direttamente per ricalcolare le
giornate su una finestra diversa da quella di preparazione, per esempio
il solo anno 2024. I rapporti che non intersecano la nuova finestra
ricevono zero giornate e restano nel dataset.

``` r

dt24 <- copy(dt)
compute_giornate(dt24, window = as.Date(c("2024-01-01", "2024-12-31")))
dt24[, .(rapporti = .N, giornate = sum(giornate)), by = .(nel_2024 = giornate > 0)]
#>    nel_2024 rapporti giornate
#>      <lgcl>    <int>    <int>
#> 1:     TRUE     1458   231464
#> 2:    FALSE     1607        0
```

## 4. Ranking dei CCNL

[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
calcola, per ciascun valore di `ccnl_key`, le misure di rilevanza
richieste e, per ognuna, la quota sul totale (`quota_<misura>`), il rank
in ordine decrescente (`rank_<misura>`) e la quota cumulata lungo il
rank (`quota_cum_<misura>`). Le misure disponibili sono `n_rapporti`,
`n_lavoratori`, `n_datori`, `giornate`, `giornate_effettive` e `stock`;
le prime tre contano solo i rapporti con `avviato = TRUE`, `stock` conta
i rapporti con `attivo = TRUE`. Non viene costruito alcun indice
composito: ogni misura produce il proprio ordinamento e la prima misura
in `measures` determina l’ordine delle righe.

I rapporti con `ccnl_key` mancante non vengono scartati: formano la riga
`Non classificati`, con `classe` dedicata, rank `NA` e quota cumulata
`NA`. Le quote di tutte le righe sono calcolate sul totale che include
questa riga, così che sommino a 1 e la copertura del codice CCNL resti
visibile direttamente nella tabella.

``` r

ranking <- rank_ccnl(dt, measures = c("n_lavoratori", "giornate"))
names(ranking)
#>  [1] "ccnl_key"               "classe"                 "n_lavoratori"          
#>  [4] "quota_n_lavoratori"     "rank_n_lavoratori"      "quota_cum_n_lavoratori"
#>  [7] "giornate"               "quota_giornate"         "rank_giornate"         
#> [10] "quota_cum_giornate"
knitr::kable(
  ranking[1:10, .(
    ccnl_key, n_lavoratori, quota_n_lavoratori, rank_n_lavoratori,
    giornate, quota_giornate, rank_giornate, quota_cum_giornate
  )],
  digits = 3
)
```

| ccnl_key | n_lavoratori | quota_n_lavoratori | rank_n_lavoratori | giornate | quota_giornate | rank_giornate | quota_cum_giornate |
|:---|---:|---:|---:|---:|---:|---:|---:|
| A011 | 226 | 0.124 | 1 | 125537 | 0.193 | 1 | 0.193 |
| H011 | 174 | 0.095 | 2 | 65546 | 0.101 | 2 | 0.294 |
| T011 | 141 | 0.077 | 3 | 50943 | 0.078 | 3 | 0.372 |
| C011 | 112 | 0.061 | 4 | 33494 | 0.051 | 4 | 0.424 |
| IC91 | 90 | 0.049 | 5 | 30765 | 0.047 | 5 | 0.471 |
| A012 | 80 | 0.044 | 6 | 24034 | 0.037 | 6 | 0.508 |
| B011 | 66 | 0.036 | 7 | 20667 | 0.032 | 7 | 0.540 |
| F011 | 61 | 0.033 | 8 | 17180 | 0.026 | 10 | 0.622 |
| D011 | 60 | 0.033 | 9 | 17999 | 0.028 | 9 | 0.595 |
| E011 | 58 | 0.032 | 10 | 18284 | 0.028 | 8 | 0.568 |

La riga dei non classificati chiude la tabella; la sua quota misura la
parte del fenomeno che il raccordo dei codici CCNL non copre.

``` r

knitr::kable(
  ranking[, .(giornate = sum(giornate), quota = sum(quota_giornate)), by = classe],
  digits = 3
)
```

| classe           | giornate | quota |
|:-----------------|---------:|------:|
| CCNL             |   545848 | 0.839 |
| Non classificati |   104618 | 0.161 |

Con l’argomento `periodo` il ranking è calcolato entro ciascuna coorte
di avviamento (`anno` o `trimestre`): quote, rank e quote cumulate sono
ricalcolati per gruppo. L’argomento `by` permette di aggiungere altre
colonne di raggruppamento, per esempio `macro_tipologia`.

``` r

per_anno <- rank_ccnl(dt, measures = "giornate", periodo = "anno")
knitr::kable(per_anno[rank_giornate <= 3L], digits = 3)
```

| anno | ccnl_key | classe | giornate | quota_giornate | rank_giornate | quota_cum_giornate |
|-----:|:---------|:-------|---------:|---------------:|--------------:|-------------------:|
| 2019 | T011     | CCNL   |     5376 |          0.127 |             1 |              0.127 |
| 2019 | A011     | CCNL   |     3526 |          0.083 |             2 |              0.210 |
| 2019 | B011     | CCNL   |     3288 |          0.077 |             3 |              0.287 |
| 2020 | A011     | CCNL   |    10477 |          0.214 |             1 |              0.214 |
| 2020 | H011     | CCNL   |     8329 |          0.170 |             2 |              0.383 |
| 2020 | T011     | CCNL   |     3710 |          0.076 |             3 |              0.459 |
| 2021 | A011     | CCNL   |    23528 |          0.222 |             1 |              0.222 |
| 2021 | H011     | CCNL   |     8549 |          0.081 |             2 |              0.302 |
| 2021 | C011     | CCNL   |     7105 |          0.067 |             3 |              0.369 |
| 2022 | A011     | CCNL   |    40045 |          0.199 |             1 |              0.199 |
| 2022 | H011     | CCNL   |    18487 |          0.092 |             2 |              0.291 |
| 2022 | T011     | CCNL   |    16842 |          0.084 |             3 |              0.375 |
| 2023 | A011     | CCNL   |    29584 |          0.187 |             1 |              0.187 |
| 2023 | H011     | CCNL   |    17496 |          0.111 |             2 |              0.298 |
| 2023 | T011     | CCNL   |    12155 |          0.077 |             3 |              0.375 |
| 2024 | A011     | CCNL   |    18377 |          0.196 |             1 |              0.196 |
| 2024 | H011     | CCNL   |    10425 |          0.111 |             2 |              0.307 |
| 2024 | T011     | CCNL   |     8626 |          0.092 |             3 |              0.399 |

## 5. Selezione dei CCNL rilevanti

[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
individua, entro ogni gruppo del ranking, i CCNL che coprono una quota
cumulata della misura scelta (`cum_share`) e/o i primi `top_n`. La
selezione scorre i CCNL classificati in ordine di rank e include un CCNL
finché la quota cumulata dei precedenti è inferiore alla soglia: è
quindi l’insieme minimo con copertura maggiore o uguale a `cum_share`.
Se entrambi i criteri sono forniti prevale il più restrittivo. Il
pacchetto non fissa soglie a priori: i due parametri sono espliciti.

Le quote usate sono quelle del ranking, calcolate sul totale del gruppo
inclusi i non classificati. Una soglia `cum_share = 0.8` indica quindi
l’80% delle giornate totali, non l’80% delle giornate con codice CCNL
noto. Quando la copertura del codice è inferiore a 1, raggiungere la
soglia richiede una quota più ampia dei CCNL classificati; se la
copertura è inferiore alla soglia stessa, la selezione include tutti i
CCNL classificati senza raggiungerla.

Con `return = "keys"` (default) la funzione restituisce il vettore delle
chiavi selezionate.

``` r

rilevanti <- select_ccnl_rilevanti(ranking, measure = "giornate", cum_share = 0.8)
rilevanti
#>  [1] "A011" "H011" "T011" "C011" "IC91" "A012" "B011" "E011" "D011" "F011"
#> [11] "M011" "H012" "I011" "K011" "G011" "L011" "Q011" "N011" "V011" "P011"
#> [21] "T012"
length(rilevanti)
#> [1] 21
ranking[ccnl_key %in% rilevanti, max(quota_cum_giornate)]
#> [1] 0.8017375
```

Nel dataset di esempio la copertura del codice CNEL è pari a 0.839 delle
giornate, per cui la soglia dell’80% del totale seleziona 21 dei 25 CCNL
classificati.

Con `return = "table"` la funzione restituisce il ranking con la colonna
logica `selezionato`; i CCNL classificati non selezionati sono aggregati
in una riga `Altri CCNL` (etichetta modificabile con `other_label`) con
le misure sommate e le quote ricalcolate sul gruppo, mentre la riga dei
non classificati è conservata. Nell’esempio `top_n = 5` si combina con
il default `cum_share = 0.8`; per usare il solo `top_n` occorre
impostare `cum_share = NULL`.

``` r

tabella <- select_ccnl_rilevanti(
  ranking,
  measure = "giornate",
  top_n = 5,
  return = "table"
)
knitr::kable(
  tabella[, .(
    ccnl_key, classe, selezionato, n_lavoratori, quota_n_lavoratori,
    giornate, quota_giornate
  )],
  digits = 3
)
```

| ccnl_key | classe | selezionato | n_lavoratori | quota_n_lavoratori | giornate | quota_giornate |
|:---|:---|:---|---:|---:|---:|---:|
| A011 | CCNL | TRUE | 226 | 0.124 | 125537 | 0.193 |
| H011 | CCNL | TRUE | 174 | 0.095 | 65546 | 0.101 |
| T011 | CCNL | TRUE | 141 | 0.077 | 50943 | 0.078 |
| C011 | CCNL | TRUE | 112 | 0.061 | 33494 | 0.051 |
| IC91 | CCNL | TRUE | 90 | 0.049 | 30765 | 0.047 |
| Altri CCNL | Altri CCNL | FALSE | 877 | 0.481 | 239563 | 0.368 |
| NA | Non classificati | FALSE | 204 | 0.112 | 104618 | 0.161 |

``` r

attr(tabella, "ccnlcob_selezione")[c("measure", "top_n", "cum_share")]
#> $measure
#> [1] "giornate"
#> 
#> $top_n
#> [1] 5
#> 
#> $cum_share
#> [1] 0.8
```

Le sezioni seguenti usano i primi cinque CCNL per giornate come
sottoinsieme di lavoro. Con `cum_share = NULL` la selezione dipende dal
solo `top_n`.

``` r

top5 <- select_ccnl_rilevanti(
  ranking,
  measure = "giornate",
  top_n = 5,
  cum_share = NULL
)
top5
#> [1] "A011" "H011" "T011" "C011" "IC91"
```

## 6. Distribuzione territoriale per CPI

[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
associa a ogni rapporto il codice e il nome del CPI a partire dal codice
Belfiore della sede di lavoro (`comune_sede_lavoro`, con
`geo = "sede_lavoro"`, default) o della residenza del lavoratore
(`comune_lavoratore`, con `geo = "residenza"`). Le colonne `cpi_code` e
`cpi_name` vengono aggiunte per riferimento; l’attributo `ccnlcob_cpi`
registra la geografia usata e l’origine del mapping.

Il mapping comune -\> CPI non è reimplementato nel pacchetto. In
produzione, con `lookup = NULL`, la funzione delega a
`longworkR::add_cpi_via_belfiore()`, che legge i file di mapping dalla
directory `SHARED_DATA_DIR/maps`; il mapping viene costruito una sola
volta sui codici Belfiore distinti e poi agganciato ai rapporti. In
questa vignetta si usa invece il lookup `cpi_esempio` incluso nel
pacchetto, che copre i dodici capoluoghi lombardi presenti in
`cob_esempio`. Un lookup esplicito richiede le colonne `belfiore`
(univoca), `cpi_code` e, facoltativa, `cpi_name`.

Nessun rapporto viene scartato. Un codice Belfiore presente ma assente
dal lookup, tipicamente un comune fuori regione, riceve
`cpi_code = "FUORI"` e `cpi_name = "Fuori Lombardia"`; un codice
mancante riceve `cpi_code = "ND"` e `cpi_name = "Non disponibile"`. Nel
dataset di esempio i quattro codici non lombardi confluiscono nella
classe `FUORI` e nessun codice è mancante.

``` r

add_cpi(dt, geo = "sede_lavoro", lookup = cpi_esempio)
attr(dt, "ccnlcob_cpi")
#> $geo
#> [1] "sede_lavoro"
#> 
#> $source
#> [1] "lookup"
dt[, .N, by = .(cpi_code, cpi_name)][order(-N)]
#>        cpi_code        cpi_name     N
#>          <char>          <char> <int>
#>  1: F205C000169      CPI MILANO   954
#>  2: L682C000600      CPI VARESE   437
#>  3: B157C000683     CPI BRESCIA   314
#>  4: F704C000581       CPI MONZA   287
#>  5: A794C000060     CPI BERGAMO   244
#>  6: C933C000073        CPI COMO   163
#>  7:       FUORI Fuori Lombardia   151
#>  8: G388C000070       CPI PAVIA   145
#>  9: D150C000030     CPI CREMONA    97
#> 10: E507C000578       CPI LECCO    91
#> 11: E897C000034     CPI MANTOVA    78
#> 12: I829C000043     CPI SONDRIO    56
#> 13: E648C000580        CPI LODI    48
```

[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
calcola la tabella `ccnl_key` x CPI per la misura scelta (le stesse di
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
default `giornate`). Se `dt` contiene già `cpi_code`, come in questo
caso, la colonna viene usata così com’è e gli argomenti `geo` e `lookup`
sono ignorati; altrimenti il CPI viene calcolato con
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
su una copia delle colonne necessarie, senza modificare `dt`.
L’argomento `ccnl` limita l’uscita alle chiavi indicate.

``` r

cpi <- ccnl_by_cpi(dt, measure = "giornate", ccnl = top5)
names(cpi)
#> [1] "ccnl_key"      "classe"        "cpi_code"      "cpi_name"     
#> [5] "giornate"      "quota_riga"    "quota_colonna" "lq"
knitr::kable(
  cpi[ccnl_key == top5[1], .(cpi_name, giornate, quota_riga, quota_colonna, lq)],
  digits = 3
)
```

| cpi_name        | giornate | quota_riga | quota_colonna |    lq |
|:----------------|---------:|-----------:|--------------:|------:|
| CPI MILANO      |    38886 |      0.310 |         0.186 | 0.964 |
| CPI BRESCIA     |    16218 |      0.129 |         0.254 | 1.318 |
| CPI VARESE      |    13295 |      0.106 |         0.143 | 0.742 |
| CPI BERGAMO     |    11677 |      0.093 |         0.217 | 1.123 |
| CPI MONZA       |    10016 |      0.080 |         0.182 | 0.944 |
| Fuori Lombardia |     8524 |      0.068 |         0.249 | 1.291 |
| CPI PAVIA       |     8410 |      0.067 |         0.264 | 1.365 |
| CPI SONDRIO     |     4272 |      0.034 |         0.273 | 1.417 |
| CPI COMO        |     3816 |      0.030 |         0.120 | 0.622 |
| CPI LODI        |     3497 |      0.028 |         0.371 | 1.920 |
| CPI MANTOVA     |     2960 |      0.024 |         0.200 | 1.034 |
| CPI LECCO       |     2476 |      0.020 |         0.127 | 0.656 |
| CPI CREMONA     |     1490 |      0.012 |         0.079 | 0.411 |

Per ogni cella (CCNL `c`, CPI `d`), detto `v` il valore della misura e
`T` il totale, la tabella riporta tre grandezze:

- `quota_riga = v[c,d] / T[c]`: distribuzione territoriale del CCNL fra
  i CPI; somma a 1 entro ogni CCNL;
- `quota_colonna = v[c,d] / T[d]`: peso del CCNL all’interno del CPI;
  somma a 1 entro ogni CPI;
- `lq = quota_colonna / (T[c] / T)`: quoziente di localizzazione, cioè
  la quota di colonna rapportata alla quota complessiva del CCNL. Un
  valore maggiore di 1 indica che il CCNL è concentrato nel CPI più
  della media del gruppo; entro ogni CCNL la media di `lq` ponderata con
  `T[d] / T` è pari a 1.

I totali `T[c]`, `T[d]` e `T` sono calcolati su tutte le righe di `dt`,
inclusi i rapporti con `ccnl_key` mancante (riga `Non classificati`), e
prima del filtro `ccnl`: le quote dei CCNL conservati non cambiano
filtrando. Il filtro esclude la riga dei non classificati, che resta in
uscita includendo `NA` in `ccnl` oppure con `ccnl = NULL`. Il quoziente
`lq` è mascherato con `NA` nelle celle dei CPI il cui totale `T[d]` è
inferiore a `min_n` (default 30 unità della misura); le celle restano
nella tabella. Nel dataset di esempio tutti i CPI superano la soglia
sulle giornate.

``` r

cpi[, .(quota_riga = sum(quota_riga), lq_min = min(lq), lq_max = max(lq)), by = ccnl_key]
#>    ccnl_key quota_riga      lq_min   lq_max
#>      <char>      <num>       <num>    <num>
#> 1:     A011          1 0.411293375 1.920262
#> 2:     C011          1 0.334628590 1.814877
#> 3:     H011          1 0.459591420 1.386507
#> 4:     IC91          1 0.009937513 3.093907
#> 5:     T011          1 0.094811592 1.587235
cpi[order(-lq)][1:5, .(ccnl_key, cpi_name, giornate, quota_colonna, lq)]
#>    ccnl_key        cpi_name giornate quota_colonna       lq
#>      <char>          <char>    <int>         <num>    <num>
#> 1:     IC91     CPI SONDRIO     2286    0.14633210 3.093907
#> 2:     A011        CPI LODI     3497    0.37060195 1.920262
#> 3:     C011 Fuori Lombardia     3197    0.09345221 1.814877
#> 4:     IC91       CPI LECCO     1605    0.08206361 1.735075
#> 5:     IC91        CPI COMO     2514    0.07907401 1.671866
```

Gli argomenti `periodo` (`anno` o `trimestre`) e `by` producono la
distribuzione entro ciascuna coorte di avviamento o entro gruppi
aggiuntivi, con quote e quozienti ricalcolati per gruppo; l’attributo
`ccnlcob_crosstab` riporta misura, dimensioni, soglia e geografia.

## 7. Distribuzione per tipologia contrattuale

[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
calcola con la stessa struttura la tabella `ccnl_key` x tipologia, per
default incrociata anche con l’orario (`FT`/`PT`). Con `level = "macro"`
la tipologia è la macro-classe di `tipologie_contrattuali`, già presente
in `dt` come `macro_tipologia` dopo
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md);
i codici senza macro-classe formano la tipologia `Non classificata` e
l’orario mancante la classe `ND`. La misura di default è `n_rapporti`.

``` r

tipologie <- ccnl_by_tipologia(
  dt,
  measure = "n_rapporti",
  ccnl = top5,
  level = "macro"
)
names(tipologie)
#> [1] "ccnl_key"      "classe"        "tipologia"     "orario"       
#> [5] "n_rapporti"    "quota_riga"    "quota_colonna" "lq"
knitr::kable(
  tipologie[ccnl_key == top5[1], .(tipologia, orario, n_rapporti, quota_riga, lq)],
  digits = 3
)
```

| tipologia           | orario | n_rapporti | quota_riga |    lq |
|:--------------------|:-------|-----------:|-----------:|------:|
| Tempo determinato   | FT     |        131 |      0.275 | 1.044 |
| Tempo indeterminato | FT     |        110 |      0.231 | 1.122 |
| Tempo determinato   | PT     |         48 |      0.101 | 1.033 |
| Somministrazione    | FT     |         39 |      0.082 | 0.882 |
| Tempo indeterminato | PT     |         34 |      0.071 | 0.911 |
| Intermittente       | PT     |         19 |      0.040 | 0.722 |
| Apprendistato       | FT     |         18 |      0.038 | 0.694 |
| Intermittente       | FT     |         14 |      0.029 | 0.949 |
| Collaborazioni      | FT     |         12 |      0.025 | 1.692 |
| Tirocinio           | FT     |         12 |      0.025 | 1.531 |
| Apprendistato       | PT     |         11 |      0.023 | 1.155 |
| Somministrazione    | PT     |         11 |      0.023 | 0.614 |
| Collaborazioni      | PT     |          6 |      0.013 |    NA |
| Domestico           | FT     |          4 |      0.008 |    NA |
| Domestico           | PT     |          4 |      0.008 |    NA |
| Tirocinio           | PT     |          3 |      0.006 |    NA |

`quota_riga` descrive la composizione contrattuale del CCNL,
`quota_colonna` il peso del CCNL entro la tipologia e `lq` il ricorso
del CCNL alla tipologia rispetto alla media del gruppo; le regole sui
totali e sul filtro `ccnl` sono quelle della sezione precedente. Qui la
soglia `min_n` agisce sul totale della cella tipologia x orario: nel
dataset di esempio le combinazioni meno frequenti restano sotto i 30
rapporti e mostrano `lq = NA`. Con `level = "codice"` la dimensione è il
codice MLPS `cod_tipologia_contrattuale` con la descrizione
`des_tipologia_contrattuale`, mentre `orario = FALSE` omette l’incrocio
con l’orario e restituisce una riga per CCNL e tipologia.

``` r

larga <- ccnl_by_tipologia(dt, measure = "n_rapporti", ccnl = top5, orario = FALSE)
knitr::kable(
  dcast(larga, ccnl_key ~ tipologia, value.var = "quota_riga", fill = 0),
  digits = 3
)
```

| ccnl_key | Altro | Apprendistato | Collaborazioni | Domestico | Intermittente | Somministrazione | Tempo determinato | Tempo indeterminato | Tirocinio |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A011 | 0.000 | 0.061 | 0.038 | 0.017 | 0.069 | 0.105 | 0.376 | 0.303 | 0.032 |
| C011 | 0.000 | 0.063 | 0.014 | 0.014 | 0.056 | 0.162 | 0.324 | 0.352 | 0.014 |
| H011 | 0.000 | 0.080 | 0.018 | 0.022 | 0.066 | 0.146 | 0.350 | 0.270 | 0.047 |
| IC91 | 0.000 | 0.117 | 0.018 | 0.000 | 0.108 | 0.135 | 0.315 | 0.279 | 0.027 |
| T011 | 0.005 | 0.077 | 0.015 | 0.036 | 0.097 | 0.122 | 0.378 | 0.255 | 0.015 |

## Fasi successive

Le funzioni seguenti sono esportate e documentate ma non ancora
implementate: nella versione corrente restituiscono un errore che indica
la fase prevista. I blocchi di questa sezione non vengono eseguiti e
mostrano l’uso previsto sul dataset preparato nelle sezioni precedenti.

[`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md)
(Fase 4) userà i segmenti di `vecshift::vecshift()` per ripartire pro
quota (1/`arco`) i giorni in cui la stessa persona ha più rapporti
concorrenti, in modo che la somma per persona coincida con i
giorni-persona occupati.

``` r

compute_giornate_effettive(dt)
dt[, .(giornate = sum(giornate), effettive = sum(giornate_effettive)), by = cf]
```

[`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
(Fase 3) segnalerà le retribuzioni non valide senza eliminare righe;
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)
(Fase 3) riporterà la retribuzione alle ore di riferimento del CCNL
stimate dai dati;
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
(Fase 3) calcolerà la mediana ponderata per giornate per coorte di
avviamento;
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md)
(Fase 3) applicherà un indice fornito dall’utente.

``` r

clean_retribuzione(dt, method = "mad", k = 5)
normalize_fte(dt)
retribuzioni <- median_retribuzione(dt, periodo = "anno", min_n = 30)

ipca <- data.table(
  periodo = 2022:2024,
  indice = c(100, 105.9, 107.1)
)
deflate_retribuzione(retribuzioni, indice = ipca, base = 2024, value_col = "mediana")
```

[`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
(Fase 4) eseguirà l’intero flusso restituendo un oggetto
`ccnlcob_result`, e
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)
(Fase 4) serializzerà le tabelle piccole in RDS e i cubi in FST.

``` r

res <- analyze_ccnl(
  cob_esempio,
  as_of = as.Date("2024-12-31"),
  window = as.Date(c("2022-01-01", "2024-12-31")),
  top_n = 20,
  cum_share = 0.8,
  geo = "sede_lavoro",
  periodo = "anno"
)
res
write_results(res, dir = "output/ccnl")
```

[`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md)
(Fase 5) caricherà i rapporti da un file FST/RDS o da una connessione
DBI, per esempio la slice DuckDB `sl2_rapporti_36m_classificati`
prodotta da `cnelR`.

``` r

dt <- read_rapporti("output/rapporti_classificati.fst")
validate_rapporti(dt, require = c("cpi", "retribuzione", "datore"))
```

## Riferimenti

- Contratto dati in ingresso:
  [`?validate_rapporti`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md).
- Regole sulle sentinelle e colonne derivate:
  [`?prepare_rapporti`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).
- Misure e quote del ranking:
  [`?rank_ccnl`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
  [`?select_ccnl_rilevanti`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).
- Mapping comune -\> CPI e distribuzione territoriale:
  [`?add_cpi`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md),
  [`?ccnl_by_cpi`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md).
- Distribuzione per tipologia:
  [`?ccnl_by_tipologia`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md).
- Lookup delle tipologie:
  [`?tipologie_contrattuali`](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).
- Dataset sintetico e lookup CPI di esempio:
  [`?cob_esempio`](https://gmontaletti.github.io/ccnlcob/reference/cob_esempio.md),
  [`?cpi_esempio`](https://gmontaletti.github.io/ccnlcob/reference/cpi_esempio.md).
