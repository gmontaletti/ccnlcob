# Esegue l'analisi completa dei CCNL su un dataset di rapporti

Orchestra i passi del pacchetto (preparazione, giornate, ranking,
selezione, distribuzione per CPI e per tipologia, retribuzioni) e
restituisce un oggetto di classe `ccnlcob_result` con le tabelle
precomputate per dashboard e report.

## Usage

``` r
analyze_ccnl(
  dt,
  as_of = NULL,
  window = NULL,
  top_n = 20,
  cum_share = 0.8,
  geo = "sede_lavoro",
  periodo = "anno",
  indice = NULL,
  ...
)
```

## Arguments

- dt:

  Un `data.table` di rapporti conforme a
  [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md).

- as_of:

  Data di riferimento (`Date`) per lo stock e i rapporti aperti; vedi
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

- window:

  Vettore di due `Date` che delimita l'analisi; vedi
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md).

- top_n:

  Numero massimo di CCNL rilevanti; vedi
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).

- cum_share:

  Soglia di quota cumulata per la selezione dei CCNL rilevanti; vedi
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md).

- geo:

  Geografia per il CPI (`"sede_lavoro"` o `"residenza"`); vedi
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md).

- periodo:

  Periodo di avviamento per le serie temporali (`"anno"` o
  `"trimestre"`).

- indice:

  `data.table` opzionale con `periodo` e `indice` per la deflazione;
  `NULL` per omettere i valori reali.

- ...:

  Argomenti aggiuntivi passati a
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
  (`lookup`),
  [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
  (`method`, `k`) e
  [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
  (`min_n`, `weights`).

## Value

Una lista di classe `ccnlcob_result` con gli elementi elencati nei
Dettagli.

## Details

Componenti del risultato:

- `meta`: `as_of`, `window`, `n_rapporti`, `n_lavoratori`,
  `copertura_ccnl`, `copertura_retribuzione`, `versione`;

- `ranking`: output di
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md);

- `rilevanti`: output di
  [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
  con etichette;

- `cpi`: output di
  [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
  sui CCNL rilevanti;

- `tipologie`: output di
  [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
  sui CCNL rilevanti;

- `retribuzioni`: output di
  [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
  ed eventuale
  [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md);

- `qualita`: per CCNL, copertura del codice, copertura della
  retribuzione e quota di rapporti con `troncata == 1`.

## See also

Other orchestrazione:
[`print.ccnlcob_result()`](https://gmontaletti.github.io/ccnlcob/reference/print.ccnlcob_result.md),
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- analyze_ccnl(
  cob_esempio,
  as_of = as.Date("2024-12-31"),
  window = as.Date(c("2022-01-01", "2024-12-31")),
  top_n = 20,
  cum_share = 0.8
)
res
res$ranking
} # }
```
