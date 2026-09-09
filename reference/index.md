# Package index

## Ingresso e preparazione

Lettura, validazione del contratto dati e preparazione dei rapporti.

- [`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md)
  : Legge i rapporti di lavoro da file o da connessione DBI
- [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)
  : Valida il contratto dati dei rapporti di lavoro
- [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
  : Prepara i rapporti di lavoro per l'analisi

## Giornate

Giorni-contratto nella finestra e giorni-persona allocati pro quota.

- [`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)
  : Calcola le giornate di contratto nella finestra di analisi
- [`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md)
  : Calcola le giornate effettive allocate pro quota fra rapporti
  concorrenti

## Ranking

Misure di rilevanza dei CCNL e selezione dei CCNL rilevanti.

- [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
  : Ordina i CCNL per misure di rilevanza
- [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
  : Seleziona i CCNL rilevanti da un ranking

## Territorio

Mapping comune -\> CPI e distribuzione territoriale dei CCNL.

- [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
  : Aggiunge il CPI (Centro per l'Impiego) ai rapporti di lavoro
- [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
  : Distribuisce i CCNL per CPI

## Tipologie

Macro-classi contrattuali e distribuzione dei CCNL per tipologia.

- [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
  : Distribuisce i CCNL per tipologia contrattuale
- [`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)
  : Classifica i codici di tipologia contrattuale in macro-classi

## Retribuzioni

Pulizia, normalizzazione FTE, mediana per coorte e deflazione.

- [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md)
  : Segnala le retribuzioni non valide o implausibili
- [`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)
  : Normalizza la retribuzione alle ore di riferimento del CCNL
- [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
  : Calcola la retribuzione mediana per CCNL e periodo di avviamento
- [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md)
  : Deflaziona una colonna di retribuzione con un indice esterno

## Orchestrazione

Analisi completa, stampa del risultato e serializzazione.

- [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
  : Esegue l'analisi completa dei CCNL su un dataset di rapporti
- [`print(`*`<ccnlcob_result>`*`)`](https://gmontaletti.github.io/ccnlcob/reference/print.ccnlcob_result.md)
  : Stampa sintetica di un risultato ccnlcob_result
- [`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)
  : Serializza i risultati di analyze_ccnl()

## Dati

Lookup delle tipologie contrattuali, dataset sintetico di esempio e
lookup CPI di esempio.

- [`tipologie_contrattuali`](https://gmontaletti.github.io/ccnlcob/reference/tipologie_contrattuali.md)
  : Tipologie contrattuali MLPS con macro-classe
- [`cob_esempio`](https://gmontaletti.github.io/ccnlcob/reference/cob_esempio.md)
  : Dataset COB sintetico a livello di rapporto di lavoro
- [`cpi_esempio`](https://gmontaletti.github.io/ccnlcob/reference/cpi_esempio.md)
  : Lookup comune -\> CPI per i comuni di cob_esempio

## Internal

Documentazione interna del pacchetto.

- [`ccnlcob`](https://gmontaletti.github.io/ccnlcob/reference/ccnlcob-package.md)
  [`ccnlcob-package`](https://gmontaletti.github.io/ccnlcob/reference/ccnlcob-package.md)
  : ccnlcob: analisi dei CCNL nei microdati delle Comunicazioni
  Obbligatorie
