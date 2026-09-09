# Prepara i rapporti di lavoro per l'analisi

Normalizza un dataset di rapporti di lavoro conforme al contratto dati:
rinomina le colonne (varianti maiuscole della pipeline e `ccnl` in
`ccnl_warehouse`), applica il perimetro contrattuale, risolve le
sentinelle sulle date, esclude i rapporti esterni alla finestra di
analisi e aggiunge le colonne derivate usate dalle funzioni analitiche.
L'input non viene mai modificato: la funzione lavora su una copia e
restituisce un nuovo `data.table`.

## Usage

``` r
prepare_rapporti(
  dt,
  as_of = NULL,
  window = NULL,
  ccnl_key = c("codice_cnel", "ccnl_warehouse"),
  perimetro = c("ccnl", "standard", "completo"),
  tipologie = ccnlcob::tipologie_contrattuali
)
```

## Arguments

- dt:

  Un `data.table` con una riga per rapporto di lavoro; vedi
  [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)
  per il contratto dati. Le colonne `inizio` e `fine` devono ereditare
  dalla classe `Date` (`IDate` accettata: la classe viene conservata in
  uscita).

- as_of:

  Data di riferimento (`Date` o stringa convertibile) per lo stato dei
  rapporti (`attivo`) e per la chiusura dei rapporti aperti; `NULL`
  (default) usa la data massima non sentinella osservata fra `inizio` e
  `fine`, cioè la data di riferimento dei dati.

- window:

  Vettore di due `Date` (o stringhe convertibili), `c(inizio, fine)`,
  che delimita l'analisi; `NULL` (default) usa `c(min(inizio), as_of)`,
  dove il minimo è calcolato sugli avviamenti non sentinella.

- ccnl_key:

  Colonna da usare come chiave CCNL di analisi: `"codice_cnel"` (codice
  CNEL a 4 caratteri prodotto da `cnelR`) oppure `"ccnl_warehouse"`
  (codice warehouse CO). Con il default (entrambe) viene usata la prima
  colonna presente in `dt`; se una colonna richiesta esplicitamente è
  assente la funzione produce un errore.

- perimetro:

  Perimetro contrattuale applicato da
  [`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)
  prima di ogni altro trattamento: `"ccnl"` (default) conserva solo le
  tipologie di lavoro subordinato alle quali si applica un CCNL;
  `"standard"` conserva il perimetro "standard" di `cnelR`; `"completo"`
  non esclude nulla. Vedi Dettagli.

- tipologie:

  Lookup delle tipologie contrattuali con le colonne
  `cod_tipologia_contrattuale`, `macro_tipologia`, `perimetro_ccnl` e
  `esclusa_standard`; default
  [tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).

## Value

Un nuovo `data.table` con le colonne di `dt` (rinominate come descritto)
e le colonne derivate elencate nei Dettagli, limitato ai rapporti
interni al perimetro che intersecano la finestra; l'attributo
`ccnlcob_meta` riporta i parametri e i conteggi. L'input non viene
modificato.

## Details

### Normalizzazione dei nomi

Le varianti maiuscole prodotte dalla pipeline COB vengono rinominate
solo se la colonna minuscola corrispondente è assente: `INIZIO`, `FINE`,
`COD_TIPOLOGIA_CONTRATTUALE`, `COMUNE_SEDE_LAVORO`, `COMUNE_LAVORATORE`,
`RETRIBUZIONE`, `ORE_SETTIM_MEDIE` (in `ore`), `ETA_LAV_INIZIO` (in
`eta`), `SESSO_LAV` (in `sesso`). La colonna sorgente `ccnl` (codice
warehouse) viene rinominata `ccnl_warehouse` se quest'ultima è assente.
Il contratto dati viene verificato dopo la rinomina.

### Perimetro contrattuale

Subito dopo la verifica del contratto dati la funzione richiama
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)
con il `perimetro` scelto:

- `"ccnl"` (default) conserva i rapporti con `perimetro_ccnl == TRUE`
  nel lookup, cioè il lavoro subordinato al quale si applica un CCNL
  (codici `A.`, `F.`, `G.01.00`, `G.02.00`, `H.01.00`, `H.03.00`, `I.`,
  `N.`); esclude collaborazioni e parasubordinati (`B.`), tirocini e
  work experience (`C.`), lavoro autonomo nello spettacolo (`G.03.00`),
  lavoro congiunto in agricoltura (`H.02.00`), associazione in
  partecipazione (`L.`), contratti di agenzia (`M.`) e i codici ignoti;

- `"standard"` conserva i rapporti con `esclusa_standard == FALSE`
  (perimetro di `cnelR`), codici ignoti inclusi;

- `"completo"` conserva tutte le righe e riproduce il comportamento
  delle versioni fino alla 0.2.0, che non applicavano alcun perimetro.

Le righe escluse sono conteggiate in `n_dropped_perimetro` e dettagliate
per tipologia in `esclusi_perimetro`;
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)
emette un [`message()`](https://rdrr.io/r/base/message.html)
riassuntivo, sopprimibile. La data di riferimento di default
(`as_of = NULL`) è calcolata prima del filtro, su tutti i rapporti, così
da non dipendere dal perimetro; la finestra di default parte invece dal
primo avviamento interno al perimetro.

### Sentinelle sulle date

Questa è l'unica funzione del pacchetto che interviene sulle sentinelle,
con le regole di `cnelR` 0.6.0:

- `fine` mancante, `<= 1900-01-01` o `> as_of` (incluso `9999-12-31`)
  identifica un rapporto aperto: `fine` diventa `as_of` e `troncata`
  vale `1`;

- `inizio` mancante o `<= 1900-01-01` diventa `2008-03-01` (avvio del
  sistema delle Comunicazioni Obbligatorie) e `troncata_inizio` vale
  `1`;

- dopo le sostituzioni, `fine < inizio` viene riportata a `inizio`
  (rapporto di un giorno) e conteggiata nei metadati.

Se `dt` contiene già `troncata`, il flag esistente viene combinato in OR
con quello calcolato; `troncata` e `troncata_inizio` sono integer 0/1.

### Finestra di analisi

I rapporti con `inizio > window[2]` o `fine < window[1]` non intersecano
la finestra e vengono rimossi (conteggiati in `n_dropped_window`). Per i
rapporti rimanenti `giornate` conta i giorni interni alla finestra,
estremi inclusi, ed è quindi sempre `>= 1`.

### Colonne aggiunte

- `ccnl_key` (character): chiave di analisi scelta; `NA` resta `NA`;

- `perimetro_ccnl` (logical): appartenenza al perimetro CCNL secondo
  `tipologie`, `FALSE` per i codici ignoti; con `perimetro = "ccnl"` è
  sempre `TRUE`;

- `troncata`, `troncata_inizio` (integer 0/1): flag delle sentinelle;

- `giornate` (integer): giorni-contratto nella finestra, vedi
  [`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md);

- `avviato` (logical): `inizio >= window[1]`, cioè avviamento interno
  alla finestra;

- `attivo` (logical): rapporto in essere alla data `as_of`
  (`inizio <= as_of & fine >= as_of`). Con una finestra esplicita che
  termina prima di `as_of`, lo stock misurato da
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
  si riferisce comunque ad `as_of`: per uno stock alla fine della
  finestra passare `as_of = window[2]`;

- `anno` (integer) e `trimestre` (character `"YYYY-Qn"`): coorte di
  avviamento da `inizio`;

- `macro_tipologia` (character): macro-classe da `tipologie`, vedi
  [`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md);
  `NA` per i codici ignoti;

- `orario` (character): `"FT"` se `prior == 1`, `"PT"` se `prior == 0`,
  `NA` altrimenti.

### Metadati

L'attributo `ccnlcob_meta` del risultato è una lista con `as_of`,
`window`, `ccnl_key` (nome della colonna usata), `perimetro`, `n_input`
(righe di `dt`), `n_dropped_perimetro`, `n_tipologia_ignota`,
`n_dropped_window`, `n_sentinel_fine`, `n_sentinel_inizio`,
`n_fine_lt_inizio` e `esclusi_perimetro` (la tabella `esclusi` di
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)).

## See also

Other ingresso:
[`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md),
[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)

## Examples

``` r
library(data.table)
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
attr(dt, "ccnlcob_meta")[c("as_of", "n_sentinel_fine", "n_fine_lt_inizio")]
#> $as_of
#> [1] "2024-12-31"
#> 
#> $n_sentinel_fine
#> [1] 149
#> 
#> $n_fine_lt_inizio
#> [1] 2
#> 
attr(dt, "ccnlcob_meta")$esclusi_perimetro
#>    cod_tipologia_contrattuale
#>                        <char>
#> 1:                    C.01.00
#> 2:                    B.03.00
#> 3:                    B.04.00
#> 4:                    C.03.00
#>                                           des_tipologia_contrattuale
#>                                                               <char>
#> 1:                                                         TIROCINIO
#> 2:                          COLLABORAZIONE COORDINATA E CONTINUATIVA
#> 3: COLLABORAZIONE OCCASIONALE SPORTIVA EX ART. 28 DEL D.LGS. 36/2021
#> 4:                   LAVORO O ATTIVITÀ SOCIALMENTE UTILE (LSU - ASU)
#>    macro_tipologia     n
#>             <char> <int>
#> 1:       Tirocinio   110
#> 2:  Collaborazioni    90
#> 3:  Collaborazioni    35
#> 4:           Altro    19
dt[, .N, by = .(anno, macro_tipologia)][order(anno, -N)][1:5]
#>     anno     macro_tipologia     N
#>    <int>              <char> <int>
#> 1:  2019   Tempo determinato   291
#> 2:  2019 Tempo indeterminato   222
#> 3:  2019    Somministrazione   103
#> 4:  2019       Intermittente    69
#> 5:  2019       Apprendistato    65

# finestra esplicita, chiave warehouse e nessun filtro di perimetro
dt24 <- prepare_rapporti(
  cob_esempio,
  as_of = as.Date("2024-12-31"),
  window = as.Date(c("2024-01-01", "2024-12-31")),
  ccnl_key = "ccnl_warehouse",
  perimetro = "completo"
)
dt24[, .(n = .N, giornate = sum(giornate)), by = ccnl_key][order(-giornate)]
#>     ccnl_key     n giornate
#>       <char> <int>    <int>
#>  1:     2638   287    45329
#>  2:     2614   168    24931
#>  3:      387   115    19717
#>  4:     0942    63    10389
#>  5:      427    64     9719
#>  6:     2138    49     8120
#>  7:     1729    38     7590
#>  8:     1489    45     7317
#>  9:     0752    41     7006
#> 10:     2861    40     6558
#> 11:     1194    44     6253
#> 12:     0100    36     5752
#> 13:     1045    24     5072
#> 14:     1214    26     4862
#> 15:     1209    33     4718
#> 16:     2826    27     4665
#> 17:     2274    24     4257
#> 18:     1883    30     4108
#> 19:      271    22     4077
#> 20:     2312    32     4069
#> 21:     1081    26     3933
#> 22:     2407    25     3705
#> 23:     1408    24     3597
#> 24:     2875    20     3245
#> 25:     1048    22     3044
#> 26:     0557    18     2939
#> 27:     2262    20     2833
#> 28:     2463    18     2770
#> 29:      527    16     2535
#> 30:     1264    17     2349
#> 31:      552    18     2116
#> 32:     1204    13     2035
#> 33:     1458    13     1854
#>     ccnl_key     n giornate
#>       <char> <int>    <int>
```
