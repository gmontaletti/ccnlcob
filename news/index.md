# Changelog

## ccnlcob 0.3.0

### Nuove funzionalità

- Perimetro contrattuale: il lookup `tipologie_contrattuali` porta il
  flag `perimetro_ccnl`, vero per i rapporti di lavoro subordinato cui
  si applica un CCNL e falso per collaborazioni e lavoro occasionale,
  tirocini e work experience, associazione in partecipazione, contratto
  di agenzia, lavoro autonomo nello spettacolo e lavoro congiunto in
  agricoltura.
- [`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md)
  applica uno dei perimetri `"ccnl"`, `"standard"` (quello di `cnelR`,
  flag `esclusa_standard`) o `"completo"` e riporta nei metadati le
  righe escluse per tipologia.

### Modifiche al comportamento

- [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
  ha il nuovo argomento `perimetro`, con default `"ccnl"`: gli
  avviamenti fuori perimetro vengono esclusi prima delle sentinelle e
  della finestra, e contati in `ccnlcob_meta` (`n_dropped_perimetro`,
  `esclusi_perimetro`). Il comportamento precedente si ottiene con
  `perimetro = "completo"`. L’output porta sempre la colonna
  `perimetro_ccnl`.

------------------------------------------------------------------------

## ccnlcob 0.2.0

### Nuove funzionalità

- [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
  aggiunge per riferimento `cpi_code` e `cpi_name` (Centro per
  l’Impiego) dal codice Belfiore della sede di lavoro o della residenza,
  tramite un `lookup` esplicito oppure
  `longworkR::add_cpi_via_belfiore()`; i comuni fuori Lombardia ricevono
  `FUORI`, i codici mancanti `ND`.
- [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md)
  distribuisce una misura per CCNL e CPI con `quota_riga`,
  `quota_colonna` e quoziente di localizzazione `lq`, mascherato con
  `NA` sotto `min_n`; i totali includono i rapporti non classificati.
- [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)
  distribuisce una misura per CCNL e tipologia contrattuale
  (macro-classe o codice MLPS), con orario full-time/part-time
  opzionale, stesse quote e `lq`.
- Dataset `cpi_esempio`: lookup Belfiore → CPI per i comuni di
  `cob_esempio`.
- La vignetta `analisi-ccnl` esegue anche le sezioni territoriali e per
  tipologia.

------------------------------------------------------------------------

## ccnlcob 0.1.0

### Nuove funzionalità

- [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
  normalizza i nomi di colonna della pipeline, risolve le sentinelle
  sulle date (`1900-01-01`, `9999-12-31`, `fine < inizio`), applica la
  finestra di analisi e aggiunge `ccnl_key`, `giornate`, `avviato`,
  `attivo`, `anno`, `trimestre`, `macro_tipologia` e `orario`; i
  conteggi delle correzioni sono nell’attributo `ccnlcob_meta`.
- [`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)
  calcola le giornate-contratto (estremi inclusi) ritagliate sulla
  finestra, per riferimento.
- [`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)
  assegna la macro-tipologia contrattuale a partire dal lookup
  `tipologie_contrattuali`.
- [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md)
  produce, per gruppo e periodo, le misure `n_rapporti`, `n_lavoratori`,
  `n_datori`, `giornate`, `giornate_effettive` e `stock` con quote,
  quote cumulate e rank; la riga `Non classificati` rende visibile la
  copertura del codice CCNL.
- [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)
  seleziona i CCNL per quota cumulata e/o `top_n` e, in forma tabellare,
  aggrega i restanti in `Altri CCNL`.
- La vignetta `analisi-ccnl` esegue il flusso della Fase 1 su
  `cob_esempio`.

------------------------------------------------------------------------

## ccnlcob 0.0.0.9000

- Scheletro iniziale del pacchetto (Fase 0 del piano di sviluppo):
  struttura CRAN, documentazione roxygen2 in italiano, vignetta
  introduttiva e sito pkgdown configurato.
- Contratto dati in ingresso formalizzato in
  [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md):
  blocchi `base`, `cpi`, `retribuzione`, `datore` con elenco esplicito
  delle colonne mancanti.
- Interfaccia documentata per tutte le funzioni analitiche
  (preparazione, giornate, ranking, territorio, tipologie, retribuzioni,
  orchestrazione): le firme sono definitive, i corpi restano stub fino
  alle fasi successive.
- Dataset sintetico `cob_esempio` e lookup `tipologie_contrattuali`
  (MLPS, foglio ST-TIPO CONTRATTI, Rev.093) inclusi come dati del
  pacchetto.
