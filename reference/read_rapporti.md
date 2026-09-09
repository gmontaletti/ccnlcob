# Legge i rapporti di lavoro da file, da DuckDB o da connessione DBI

Carica un dataset di rapporti di lavoro da un file `.fst`, `.rds` o
`.duckdb`, da una connessione `DBI` aperta oppure da un `data.frame` già
in memoria; porta i nomi delle colonne al contratto dati, normalizza i
tipi e restituisce un `data.table` pronto per
[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)
e
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

## Usage

``` r
read_rapporti(
  source,
  table = NULL,
  columns = NULL,
  where = NULL,
  validate = TRUE
)
```

## Arguments

- source:

  Una fra: il percorso di un file `.fst`, `.rds` o `.duckdb` (aperto in
  sola lettura con `duckdb::duckdb()`); una connessione
  `DBI::DBIConnection` (DuckDB o PostgreSQL); un `data.frame` o
  `data.table` (convertito con
  [`data.table::as.data.table()`](https://rdrr.io/pkg/data.table/man/as.data.table.html),
  l'input non viene modificato).

- table:

  Nome della tabella o vista da leggere quando `source` è un file
  `.duckdb` o una connessione DBI; obbligatorio in quei casi, ignorato
  altrimenti. Per la slice prodotta da `cnelR` il nome è
  `"sl2_rapporti_36m_classificati"`. Sono ammessi nomi qualificati con
  lo schema (`"schema.tabella"`).

- columns:

  Vettore character con le colonne da leggere, con i nomi della sorgente
  oppure quelli del contratto dati (per esempio `"id"` e `"id_rapporto"`
  sono equivalenti). `NULL` (default) legge tutte le colonne del
  contratto dati presenti nella sorgente; vedi Dettagli.

- where:

  Predicato SQL (character di lunghezza 1, senza la parola chiave
  `WHERE`) applicato alla lettura da DuckDB o DBI, per esempio
  `"inizio >= DATE '2023-02-01'"`. Deve essere `NULL` per i file e per i
  `data.frame`.

- validate:

  Se `TRUE` (default) il risultato viene verificato con
  [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)
  (blocco `"base"`) e la funzione si ferma con un errore che elenca le
  colonne mancanti. Con `FALSE` la tabella viene restituita anche se
  incompleta, per esempio per leggere un sottoinsieme di colonne.

## Value

Un `data.table` con una riga per rapporto di lavoro e le colonne
richieste con i nomi del contratto dati; attributo `ccnlcob_source` come
descritto nei Dettagli.

## Details

### Colonne lette

Le colonne del contratto dati sono `id`, `cf`, `inizio`, `fine`,
`codice_cnel`, `ccnl`, `ccnl_warehouse`, `rappres`,
`cod_tipologia_contrattuale`, `cod_tipo_orario`, `prior`,
`comune_sede_lavoro`, `comune_lavoratore`, `datore`, `retribuzione`,
`ore`, `troncata`, `qualifica`, `ateco_gruppo`, `eta`, `sesso` e
`liv_istruzione_lav`. Con `columns = NULL` vengono lette quelle presenti
nella sorgente; le altre colonne (per esempio `ini_*` della slice
`cnelR`) vengono ignorate. Per le sorgenti DuckDB e DBI la selezione
delle colonne e il predicato `where` sono inseriti nella `SELECT`, così
che in R arrivino solo i dati richiesti; per i file `.fst` la selezione
avviene in lettura, per `.rds` e `data.frame` dopo il caricamento.

### Rinomina

I nomi della sorgente vengono portati al contratto dati solo quando la
colonna di destinazione è assente. Nomi della slice `cnelR` (warehouse
CO): `id_rapporto` in `id`, `codice_fiscale_lavoratore` in `cf`,
`codice_fiscale_datore` in `datore`, `ore_settim_medie` in `ore`,
`cod_qualifica_prof_istat_3dgt` in `qualifica`, `sesso_lav` in `sesso`,
`eta_lav_inizio` in `eta`. Varianti maiuscole della pipeline COB:
`INIZIO`, `FINE`, `COD_TIPOLOGIA_CONTRATTUALE`, `COMUNE_SEDE_LAVORO`,
`COMUNE_LAVORATORE`, `RETRIBUZIONE`, `ORE_SETTIM_MEDIE`,
`ETA_LAV_INIZIO`, `SESSO_LAV`. La colonna `ccnl` (codice warehouse) non
viene rinominata: la rinomina in `ccnl_warehouse` resta di competenza di
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

Se `prior` è assente e `cod_tipo_orario` è presente, `prior` viene
derivata dai codici MLPS della tabella "ST-TIPO ORARIO": `"F"` (tempo
pieno) vale `1`; `"P"` (part-time orizzontale), `"V"` (part-time
verticale) e `"M"` (part-time misto) valgono `0`; `"N"` (non definito),
i valori mancanti e ogni altro codice danno `NA`. Il confronto ignora
spazi e maiuscole; `cod_tipo_orario` viene conservata e il metadato
`prior_derivato` registra l'avvenuta derivazione.

### Tipi

I `factor` diventano character; gli interi a 64 bit (`integer64`, per
esempio `id` nel file `rap.fst` della pipeline) diventano character per
`id` e integer per le altre colonne (richiede il pacchetto `bit64`).
`retribuzione`, `ore` ed `eta`, se character o factor, vengono
convertite in numeric accettando solo valori che rappresentano un numero
(virgola ammessa come separatore decimale, zero-padding ammesso): gli
altri valori non mancanti e non vuoti diventano `NA` e sono conteggiati
in `n_non_numerici`. `inizio` e `fine` diventano `Date` da character o
`POSIXct` (`IDate` viene conservata); `prior` e `troncata` diventano
integer 0/1; `rappres` diventa logical. Le sentinelle sulle date non
vengono toccate.

### Metadati

L'attributo `ccnlcob_source` del risultato è una lista con `source`
(percorso, `"DBI"` o `"data.frame"`), `table`, `n` (righe lette),
`colonne_mappate` (character nominato: nome sorgente = nome di
contratto, per le sole colonne rinominate), `prior_derivato` (logical),
`n_non_numerici` (integer nominato per `retribuzione`, `ore`, `eta`) e
`where`. La funzione emette un
[`message()`](https://rdrr.io/r/base/message.html) con il numero di
righe lette.

## See also

Other ingresso:
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
[`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)

## Examples

``` r
# da data.frame in memoria (nomi del contratto dati)
dt <- read_rapporti(cob_esempio)
#> read_rapporti(): lette 5.000 righe da data.frame.
attr(dt, "ccnlcob_source")$n
#> [1] 5000

# da file RDS o FST
f <- tempfile(fileext = ".rds")
saveRDS(cob_esempio, f)
dt <- read_rapporti(f, columns = c("id", "cf", "inizio", "fine"),
                    validate = FALSE)
#> read_rapporti(): lette 5.000 righe da /tmp/RtmprvmIrN/file185c498518ad.rds.
unlink(f)

if (FALSE) { # \dontrun{
# slice classificata da cnelR, con selezione spinta in SQL
dt <- read_rapporti(
  "~/data/cnel/rapporti_azure.duckdb",
  table = "sl2_rapporti_36m_classificati",
  where = "inizio >= DATE '2023-02-01'"
)

# connessione DBI già aperta
con <- DBI::dbConnect(duckdb::duckdb(), "cob.duckdb", read_only = TRUE)
dt <- read_rapporti(con, table = "sl2_rapporti_36m_classificati")
DBI::dbDisconnect(con, shutdown = TRUE)
} # }
```
