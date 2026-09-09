# Genera il report HTML dei risultati di analyze_ccnl()

Esegue il template Quarto parametrico del pacchetto
(`inst/quarto/report_ccnl.qmd`) sulla directory prodotta da
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)
e produce un file HTML autonomo (risorse incorporate) con classifica dei
CCNL, andamento per periodo, distribuzione per CPI e per tipologia
contrattuale, retribuzioni mediane, indicatori di qualità e note
metodologiche. Le sezioni i cui dati non sono presenti nella directory
(per esempio `cpi` quando il passo è stato saltato) vengono sostituite
da una frase esplicativa.

## Usage

``` r
render_report(
  dir,
  output_file = NULL,
  titolo = "Analisi dei CCNL sui dati COB",
  labels = NULL,
  top_n = 15,
  note = NULL,
  quiet = TRUE
)
```

## Arguments

- dir:

  Directory scritta da
  [`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md);
  devono esistere almeno `meta.rds` e `ranking.rds`.

- output_file:

  Percorso del file HTML da produrre; `NULL` (default) scrive
  `report_ccnl.html` dentro `dir`. La directory di destinazione viene
  creata se assente.

- titolo:

  Titolo del report.

- labels:

  Etichette leggibili dei CCNL: `NULL` (default, usa le chiavi), un
  `data.frame` con le colonne `ccnl_key` (o `codice_cnel`) e
  `ccnl_titolo`, oppure il percorso di un file RDS con la stessa
  struttura. Le chiavi duplicate vengono ridotte alla prima occorrenza.

- top_n:

  Numero massimo di CCNL nelle classifiche e nelle tabelle; i grafici a
  linee ne mostrano al più 8 (capienza della palette).

- note:

  Testo libero (character di lunghezza 1) mostrato in apertura come
  nota; `NULL` per ometterlo.

- quiet:

  Se `TRUE` (default) sopprime l'output di Quarto; altrimenti la
  funzione emette anche un
  [`message()`](https://rdrr.io/r/base/message.html) con il tempo
  impiegato.

## Value

Il percorso di `output_file`, invisibilmente, con l'attributo `secondi`
(tempo di esecuzione).

## Details

La funzione richiede il pacchetto R `quarto` e la Quarto CLI
(individuata con `quarto::quarto_path()`), oltre a `ggplot2` e `knitr`
per i grafici e le tabelle; sono tutti in `Suggests`. Il template viene
copiato in una directory temporanea, perché Quarto scrive l'HTML accanto
al file `.qmd`, e il risultato viene poi spostato in `output_file`. Il
template legge le tabelle con
[`readRDS()`](https://rdrr.io/r/base/readRDS.html) o
[`fst::read_fst()`](http://www.fstpackage.org/reference/write_fst.md) e
ripristina gli attributi `ccnlcob_*` da `meta$attributi`.

## See also

[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)
per produrre `dir`;
[`plot_ranking()`](https://gmontaletti.github.io/ccnlcob/reference/plot_ranking.md),
[`plot_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/plot_cpi.md),
[`plot_tipologie()`](https://gmontaletti.github.io/ccnlcob/reference/plot_tipologie.md),
[`plot_retribuzioni()`](https://gmontaletti.github.io/ccnlcob/reference/plot_retribuzioni.md)
per i grafici usati dal template.

## Examples

``` r
# il template usato dal report
system.file("quarto", "report_ccnl.qmd", package = "ccnlcob")
#> [1] "/home/runner/work/_temp/Library/ccnlcob/quarto/report_ccnl.qmd"

if (FALSE) { # \dontrun{
# richiede la Quarto CLI
res <- analyze_ccnl(cob_esempio, lookup_cpi = cpi_esempio, min_n = 10)
dir_out <- file.path(tempdir(), "ccnl_report")
write_results(res, dir = dir_out, overwrite = TRUE)
html <- render_report(dir_out, titolo = "CCNL: dati di esempio")
browseURL(html)
} # }
```
