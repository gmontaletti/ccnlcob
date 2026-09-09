# Valida il contratto dati dei rapporti di lavoro

Verifica che `dt` sia un `data.table` e che contenga le colonne
richieste dal contratto dati del pacchetto. Il blocco `"base"` è sempre
verificato; i blocchi aggiuntivi (`"cpi"`, `"retribuzione"`, `"datore"`)
vengono controllati solo se richiesti tramite `require`.

## Usage

``` r
validate_rapporti(dt, require = "base")
```

## Arguments

- dt:

  Un `data.table` con una riga per rapporto di lavoro.

- require:

  Vettore character con i blocchi di colonne da verificare. Valori
  ammessi: `"base"` (sempre incluso), `"cpi"`, `"retribuzione"`,
  `"datore"`; qualsiasi altro valore, anche in un vettore misto, produce
  un errore. Vedi Dettagli.

## Value

`dt`, restituito invisibilmente, se tutte le verifiche passano. In caso
contrario un errore che elenca le colonne mancanti
(`Colonne mancanti: ...`), l'assenza di una colonna CCNL o le colonne
data con classe non valida.

## Details

Blocchi e colonne richieste:

- `"base"`: `id`, `cf`, `inizio`, `fine`, `cod_tipologia_contrattuale`,
  `prior`, più almeno una fra `codice_cnel`, `ccnl` e `ccnl_warehouse`.
  Le colonne `inizio` e `fine` devono ereditare dalla classe `Date`
  (`IDate` è accettata).

- `"cpi"`: `comune_sede_lavoro` (codice Belfiore della sede di lavoro).

- `"retribuzione"`: `retribuzione` e `ore`.

- `"datore"`: `datore` (codice fiscale del datore di lavoro).

La funzione non modifica `dt`. Le sentinelle sulle date (`1900-01-01`,
`9999-12-31`, `fine < inizio`) non vengono verificate qui: sono di
competenza di
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

## See also

Other ingresso:
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
[`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(data.table)
dt <- copy(cob_esempio)
validate_rapporti(dt)
validate_rapporti(dt, require = c("cpi", "retribuzione"))

# errore: manca la colonna comune_sede_lavoro
validate_rapporti(dt[, !"comune_sede_lavoro"], require = "cpi")
} # }
```
