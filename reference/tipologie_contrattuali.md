# Tipologie contrattuali MLPS con macro-classe

Lookup delle tipologie contrattuali delle Comunicazioni Obbligatorie
(classificazioni standard del Ministero del Lavoro e delle Politiche
Sociali) con la macro-classe usata da
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)
e
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
e il flag di esclusione dal perimetro "standard" adottato da `cnelR`.

## Usage

``` r
tipologie_contrattuali
```

## Format

Un `data.table` con una riga per codice di tipologia contrattuale e le
colonne:

- cod_tipologia_contrattuale:

  character. Codice MLPS della tipologia (es. `A.01.00`).

- des_tipologia_contrattuale:

  character. Descrizione ufficiale MLPS della tipologia.

- macro_tipologia:

  character. Macro-classe di analisi, una fra: `Tempo indeterminato`,
  `Tempo determinato`, `Apprendistato`, `Somministrazione`,
  `Intermittente`, `Collaborazioni`, `Tirocinio`, `Domestico`, `Altro`.

- esclusa_standard:

  logical. `TRUE` per le tipologie escluse dal perimetro "standard" di
  `cnelR` (`C.01.00`, `B.04.00`, `B.03.00`, `A.04.00`, `A.04.01`).

## Source

Ministero del Lavoro e delle Politiche Sociali, "Classificazioni
Standard" delle Comunicazioni Obbligatorie, foglio ST-TIPO CONTRATTI,
Rev.093 del 2026-04-26.

## See also

[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md),
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
#>        macro_tipologia esclusa_standard
#>                 <char>           <lgcl>
#> 1: Tempo indeterminato            FALSE
#> 2:   Tempo determinato            FALSE
#> 3:   Tempo determinato            FALSE
#> 4:       Apprendistato            FALSE
#> 5:       Apprendistato            FALSE
#> 6:       Apprendistato            FALSE
```
