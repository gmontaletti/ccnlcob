# Classifica i codici di tipologia contrattuale in macro-classi

Traduce un vettore di codici MLPS (`cod_tipologia_contrattuale`) nella
macro-classe definita dal lookup
[tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).
La traduzione è vettorizzata
([`match()`](https://rdrr.io/r/base/match.html)), conserva lunghezza e
ordine di `codici` e non modifica i codici in ingresso (nessuna
normalizzazione di maiuscole o spazi).

## Usage

``` r
classify_tipologia(codici, tipologie = ccnlcob::tipologie_contrattuali)
```

## Arguments

- codici:

  Vettore character di codici MLPS (es. `"A.01.00"`); i factor vengono
  convertiti in character.

- tipologie:

  Lookup con le colonne `cod_tipologia_contrattuale` e
  `macro_tipologia`; default
  [tipologie_contrattuali](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md).
  Con codici duplicati nel lookup vale la prima occorrenza.

## Value

Vettore character della stessa lunghezza di `codici` con la
macro-classe; `NA` per i codici `NA` e per quelli non presenti nel
lookup. Errore se `tipologie` non contiene le due colonne richieste.

## See also

Other tipologie:
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md),
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)

## Examples

``` r
classify_tipologia(c("A.01.00", "A.02.00", "C.01.00", "ZZZ", NA))
#> [1] "Tempo indeterminato" "Tempo determinato"   "Tirocinio"          
#> [4] NA                    NA                   

# lookup alternativo
lookup <- data.frame(
  cod_tipologia_contrattuale = c("X.01", "X.02"),
  macro_tipologia = c("Classe X1", "Classe X2")
)
classify_tipologia(c("X.02", "X.01", "A.01.00"), tipologie = lookup)
#> [1] "Classe X2" "Classe X1" NA         
```
