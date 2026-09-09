# Tipologie contrattuali MLPS con macro-classe

Lookup delle tipologie contrattuali delle Comunicazioni Obbligatorie
(classificazioni standard del Ministero del Lavoro e delle Politiche
Sociali) con la macro-classe usata da
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)
e
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md),
il flag di appartenenza al perimetro CCNL usato da
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)
e il flag di esclusione dal perimetro "standard" adottato da `cnelR`.
Oltre alle tipologie del foglio MLPS contiene due codici usati dal solo
warehouse CO (`AP-ULAV`, apprendistato, e `AP-USOM`, apprendistato in
somministrazione), distinti dalla colonna `fonte_mlps`.

## Usage

``` r
tipologie_contrattuali
```

## Format

Un `data.table` con una riga per codice di tipologia contrattuale e le
colonne:

- cod_tipologia_contrattuale:

  character. Codice MLPS della tipologia (es. `A.01.00`) oppure codice
  del warehouse CO (`AP-ULAV`, `AP-USOM`).

- des_tipologia_contrattuale:

  character. Descrizione ufficiale MLPS della tipologia; per i codici
  warehouse una descrizione assegnata nel pacchetto.

- macro_tipologia:

  character. Macro-classe di analisi, una fra: `Tempo indeterminato`,
  `Tempo determinato`, `Apprendistato`, `Somministrazione`,
  `Intermittente`, `Collaborazioni`, `Tirocinio`, `Domestico`, `Altro`.

- perimetro_ccnl:

  logical. `TRUE` per le tipologie di lavoro subordinato alle quali si
  applica un CCNL: tutti i codici `A.` (incluso il lavoro domestico),
  `F.` (marittimo), `G.01.00` e `G.02.00` (spettacolo subordinato),
  `H.01.00` e `H.03.00` (agricoltura subordinata), `I.` (pubblica
  amministrazione) e `N.` (piattaforma). `FALSE` per `B.`
  (collaborazioni e parasubordinati), `C.` (tirocini, LSU e work
  experience), `G.03.00` (lavoro autonomo nello spettacolo), `H.02.00`
  (lavoro congiunto in agricoltura), `L.` (associazione in
  partecipazione) e `M.` (contratto di agenzia). Le regole complete sono
  in `data-raw/tipologie_contrattuali.R`.

- esclusa_standard:

  logical. `TRUE` per le tipologie escluse dal perimetro "standard" di
  `cnelR` (`C.01.00`, `B.04.00`, `B.03.00`, `A.04.00`, `A.04.01`).

- fonte_mlps:

  logical. `TRUE` per le righe del foglio MLPS, `FALSE` per i codici del
  solo warehouse CO (`AP-ULAV` con macro-classe `Apprendistato`,
  `AP-USOM` con macro-classe `Somministrazione`; entrambi con
  `perimetro_ccnl = TRUE` e `esclusa_standard = FALSE`).

## Source

Ministero del Lavoro e delle Politiche Sociali, "Classificazioni
Standard" delle Comunicazioni Obbligatorie, foglio ST-TIPO CONTRATTI,
Rev.093 del 2026-04-26; codici warehouse aggiunti in
`data-raw/tipologie_contrattuali.R`.

## See also

[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md),
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md),
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)

## Examples

``` r
head(tipologie_contrattuali)
#>    cod_tipologia_contrattuale
#>                        <char>
#> 1:                    A.01.00
#> 2:                    A.02.00
#> 3:                    A.02.01
#> 4:                    A.03.00
#> 5:                    A.03.01
#> 6:                    A.03.02
#>                                                      des_tipologia_contrattuale
#>                                                                          <char>
#> 1:                                                 LAVORO A TEMPO INDETERMINATO
#> 2:                                                   LAVORO A TEMPO DETERMINATO
#> 3:                                  LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE
#> 4:                                            APPRENDISTATO EX ART.16 L. 196/97
#> 5: APPRENDISTATO PER L'ESPLETAMENTO DEL DIRITTO DOVERE DI ISTRUZIONE FORMAZIONE
#> 6:                                            APPRENDISTATO PROFESSIONALIZZANTE
#>        macro_tipologia perimetro_ccnl esclusa_standard fonte_mlps
#>                 <char>         <lgcl>           <lgcl>     <lgcl>
#> 1: Tempo indeterminato           TRUE            FALSE       TRUE
#> 2:   Tempo determinato           TRUE            FALSE       TRUE
#> 3:   Tempo determinato           TRUE            FALSE       TRUE
#> 4:       Apprendistato           TRUE            FALSE       TRUE
#> 5:       Apprendistato           TRUE            FALSE       TRUE
#> 6:       Apprendistato           TRUE            FALSE       TRUE
```
