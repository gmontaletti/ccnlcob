# Filtra i rapporti per perimetro contrattuale

Restringe un dataset di rapporti di lavoro alle tipologie contrattuali
alle quali si applica un contratto collettivo, oppure al perimetro
"standard" di `cnelR`, e riporta nei metadati quante righe sono state
escluse e per quale tipologia. Alcuni avviamenti presenti nelle
Comunicazioni Obbligatorie non sono rapporti di lavoro subordinato
(collaborazioni e parasubordinati, contratti di agenzia, tirocini e work
experience, associazione in partecipazione, lavoro autonomo nello
spettacolo, lavoro congiunto in agricoltura): includerli nelle
classifiche dei CCNL distorce le misure di rilevanza. L'esclusione è
sempre conteggiata e segnalata, mai silenziosa.

## Usage

``` r
filter_perimetro(
  dt,
  perimetro = c("ccnl", "standard", "completo"),
  tipologie = ccnlcob::tipologie_contrattuali
)
```

## Arguments

- dt:

  Un `data.table` con la colonna `cod_tipologia_contrattuale` (codice
  MLPS); può essere il dato grezzo o l'uscita di
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).
  Non viene modificato.

- perimetro:

  Perimetro da applicare:

  - `"ccnl"` (default): conserva i rapporti con `perimetro_ccnl == TRUE`
    nel lookup; i codici ignoti vengono esclusi;

  - `"standard"`: conserva i rapporti con `esclusa_standard == FALSE`
    (perimetro di `cnelR`); i codici ignoti vengono conservati;

  - `"completo"`: conserva tutte le righe.

- tipologie:

  Lookup delle tipologie contrattuali con le colonne
  `cod_tipologia_contrattuale`, `perimetro_ccnl` e `esclusa_standard`
  (le colonne `des_tipologia_contrattuale` e `macro_tipologia`, se
  presenti, arricchiscono la tabella degli esclusi); default
  [tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).

## Value

Un nuovo `data.table` con le righe di `dt` interne al perimetro, la
colonna `perimetro_ccnl` e l'attributo `ccnlcob_perimetro`. L'input non
viene modificato.

## Details

### Regole del perimetro CCNL

Il flag `perimetro_ccnl` di
[tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md)
è derivato dal prefisso del codice MLPS. Appartengono al perimetro tutti
i codici `A.` (tempo indeterminato e determinato, apprendistato inclusi
il contratto di formazione lavoro `A.03.04` e l'inserimento `A.03.07`,
lavoro domestico `A.04.*`, intermittente, somministrazione, ripartito, a
domicilio), i codici `F.` (lavoro marittimo), `G.01.00` e `G.02.00`
(spettacolo subordinato), `H.01.00` e `H.03.00` (agricoltura
subordinata), `I.` (pubblica amministrazione) e `N.` (lavoro con
piattaforma). Restano fuori i codici `B.` (collaborazioni, lavoro
occasionale, parasubordinati), `C.` (tirocini, LSU, borsa lavoro e work
experience), `G.03.00` (lavoro autonomo nello spettacolo), `H.02.00`
(lavoro congiunto in agricoltura), `L.` (associazione in partecipazione)
e `M.` (contratto di agenzia). Un codice assente dal lookup è trattato
come fuori perimetro e conteggiato in `n_tipologia_ignota`.

### Perimetro standard

Il perimetro `"standard"` riproduce quello di `cnelR`: esclude solo i
codici con `esclusa_standard == TRUE` (`C.01.00`, `B.04.00`, `B.03.00`,
`A.04.00`, `A.04.01`). I codici ignoti vengono conservati e conteggiati.

### Colonna e metadati

Il risultato porta sempre la colonna logica `perimetro_ccnl`, aggiunta
se assente (una colonna già presente viene conservata così com'è; il
filtro usa comunque il lookup). L'attributo `ccnlcob_perimetro` è una
lista con `perimetro`, `n_input`, `n_kept`, `n_dropped`,
`n_tipologia_ignota` e `esclusi`, un `data.table` con le colonne
`cod_tipologia_contrattuale`, `des_tipologia_contrattuale`,
`macro_tipologia` e `n` (righe escluse per tipologia, in ordine
decrescente di `n`; zero righe se nulla è stato escluso). Quando vengono
escluse righe o compaiono codici ignoti la funzione emette un
[`message()`](https://rdrr.io/r/base/message.html) riassuntivo,
sopprimibile con
[`suppressMessages()`](https://rdrr.io/r/base/message.html).

## See also

[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
che applica il filtro in ingresso;
[tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md)
per le regole.

Other tipologie:
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md),
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)

## Examples

``` r
library(data.table)
dt <- filter_perimetro(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
nrow(cob_esempio)
#> [1] 5000
nrow(dt)
#> [1] 4746
info <- attr(dt, "ccnlcob_perimetro")
info[c("perimetro", "n_input", "n_kept", "n_dropped", "n_tipologia_ignota")]
#> $perimetro
#> [1] "ccnl"
#> 
#> $n_input
#> [1] 5000
#> 
#> $n_kept
#> [1] 4746
#> 
#> $n_dropped
#> [1] 254
#> 
#> $n_tipologia_ignota
#> [1] 0
#> 
info$esclusi
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

# perimetro standard di cnelR e dataset completo
std <- filter_perimetro(cob_esempio, perimetro = "standard")
#> filter_perimetro(): perimetro "standard", esclusi 235 rapporti su 5000 (4,7%) in 3 tipologie; 0 con tipologia ignota.
attr(std, "ccnlcob_perimetro")$esclusi
#>    cod_tipologia_contrattuale
#>                        <char>
#> 1:                    C.01.00
#> 2:                    B.03.00
#> 3:                    B.04.00
#>                                           des_tipologia_contrattuale
#>                                                               <char>
#> 1:                                                         TIROCINIO
#> 2:                          COLLABORAZIONE COORDINATA E CONTINUATIVA
#> 3: COLLABORAZIONE OCCASIONALE SPORTIVA EX ART. 28 DEL D.LGS. 36/2021
#>    macro_tipologia     n
#>             <char> <int>
#> 1:       Tirocinio   110
#> 2:  Collaborazioni    90
#> 3:  Collaborazioni    35
tutto <- filter_perimetro(cob_esempio, perimetro = "completo")
tutto[, .N, by = perimetro_ccnl]
#>    perimetro_ccnl     N
#>            <lgcl> <int>
#> 1:           TRUE  4746
#> 2:          FALSE   254
```
