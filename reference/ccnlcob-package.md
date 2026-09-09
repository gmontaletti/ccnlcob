# ccnlcob: analisi dei CCNL nei microdati delle Comunicazioni Obbligatorie

Il pacchetto analizza dataset COB (Comunicazioni Obbligatorie) a livello
di rapporto di lavoro per rispondere a quattro domande: quali CCNL
(contratti collettivi nazionali di lavoro) sono più rilevanti, misurando
la rilevanza per persone avviate e per giornate effettive di lavoro;
come si distribuiscono i rapporti di ciascun CCNL per CPI (Centro per
l'Impiego); come si distribuiscono per tipologia contrattuale; come
evolve nel tempo la retribuzione mediana dichiarata all'avviamento.

Il pacchetto contiene solo calcolo. Consuma rapporti già classificati da
`cnelR` (colonna `codice_cnel`), delega il mapping comune → CPI a
`longworkR::add_cpi_via_belfiore()` e la segmentazione degli intervalli
sovrapposti a `vecshift::vecshift()`. Le funzioni analitiche accettano
un `data.table` e non aprono connessioni; l'I/O è isolato in
[`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md)
e
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md).

## Flusso di lavoro

1.  [`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md)
    e
    [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)
    leggono e verificano il contratto dati.

2.  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
    normalizza i nomi, gestisce le sentinelle sulle date, aggiunge
    `ccnl_key`, `giornate`, periodo e macro-tipologia.

3.  [`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)
    e
    [`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md)
    misurano i giorni-contratto e i giorni-persona allocati pro quota.

4.  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
    e
    [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
    ordinano i CCNL e selezionano quelli rilevanti per soglia di
    copertura o `top_n`.

5.  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md),
    [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md),
    [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
    distribuiscono i CCNL per territorio e per tipologia contrattuale.

6.  [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md),
    [`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md),
    [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md)
    e
    [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md)
    stimano l'evoluzione della retribuzione mediana.

7.  [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md)
    orchestra i passi precedenti e
    [`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md)
    serializza le tabelle per dashboard e report.

## Terminologia

- `CPI` indica sempre il Centro per l'Impiego; la deflazione usa
  l'argomento `indice` e il suffisso `_reale`.

- `ccnl` (colonna sorgente) è il codice warehouse delle Comunicazioni
  Obbligatorie; in ingresso viene rinominata `ccnl_warehouse`. La chiave
  di analisi è `ccnl_key` (default `codice_cnel`).

- `giornate` sono i giorni-contratto nella finestra;
  `giornate_effettive` sono i giorni-persona allocati pro quota
  (1/`arco`) fra rapporti concorrenti.

- `retribuzione` è la retribuzione annua lorda dichiarata
  all'avviamento; `retribuzione_fte` è normalizzata alle ore di
  riferimento del CCNL.

## See also

Useful links:

- <https://github.com/gmontaletti/ccnlcob>

- <https://gmontaletti.github.io/ccnlcob/>

- Report bugs at <https://github.com/gmontaletti/ccnlcob/issues>

## Author

**Maintainer**: Giampaolo Montaletti <giampaolo.montaletti@gmail.com>
([ORCID](https://orcid.org/0009-0002-5327-1122))
