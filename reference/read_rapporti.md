# Legge i rapporti di lavoro da file o da connessione DBI

Carica un dataset di rapporti di lavoro da un file `.fst`/`.rds` oppure
da una tabella raggiungibile tramite una connessione DBI (DuckDB o
PostgreSQL), normalizza i tipi delle colonne e restituisce un
`data.table` conforme al contratto dati atteso da
[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md).

## Usage

``` r
read_rapporti(source, table = NULL, columns = NULL)
```

## Arguments

- source:

  Percorso di un file `.fst` o `.rds`, oppure una connessione
  `DBI::DBIConnection` (in tal caso è richiesto `table`).

- table:

  Nome della tabella o vista da leggere quando `source` è una
  connessione DBI; ignorato per i file. Per la slice prodotta da `cnelR`
  il valore tipico è `"sl2_rapporti_36m_classificati"`.

- columns:

  Vettore character con le colonne da leggere; `NULL` legge tutte le
  colonne disponibili.

## Value

Un `data.table` con una riga per rapporto di lavoro.

## Details

La normalizzazione dei tipi converte i `factor` in character, gli interi
a 64 bit in integer e le date in `IDate`; i nomi delle colonne vengono
portati in minuscolo. La funzione chiama
[`data.table::setDT()`](https://rdrr.io/pkg/data.table/man/setDT.html)
sul risultato e non applica alcuna trasformazione analitica: le
sentinelle sulle date e la rinomina di `ccnl` in `ccnl_warehouse`
restano di competenza di
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

## See also

Other ingresso:
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# da file FST
dt <- read_rapporti("output/rapporti_classificati.fst")

# da DuckDB (slice classificata da cnelR)
con <- DBI::dbConnect(duckdb::duckdb(), "cob.duckdb", read_only = TRUE)
dt <- read_rapporti(con, table = "sl2_rapporti_36m_classificati")
DBI::dbDisconnect(con, shutdown = TRUE)
} # }
```
