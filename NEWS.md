# ccnlcob 0.6.0

## Nuove funzionalità

- `read_rapporti()` legge i rapporti da file FST o RDS, da un file DuckDB o
  da una connessione DBI (per esempio la slice `sl2_rapporti_36m_classificati`
  prodotta da `cnelR`), mappa i nomi del warehouse al contratto dati
  (`id_rapporto`, `codice_fiscale_lavoratore`, `ore_settim_medie`, ...),
  deriva `prior` da `cod_tipo_orario`, normalizza i tipi (factor, integer64,
  testo numerico) e, con sorgenti DB, spinge selezione di colonne e filtro
  `where` nella query.
- Prima esecuzione su dati reali: analisi della slice cnelR di 36 mesi
  (8 milioni di rapporti, 37 secondi per l'intera catena) documentata in
  `reference/ccnlcob/analisi_slice_reale.md`; i conteggi di rapporti,
  lavoratori e datori per `codice_cnel` coincidono con quelli pubblicati da
  `cnelR` per tutti i 274 codici.

## Modifiche al comportamento

- `attivo` (e quindi `stock`) indica ora il rapporto aperto alla data
  `as_of` (fine mancante, sentinella, successiva ad `as_of` o troncata a
  monte dalla pipeline), come `n_attivi` di `cnelR`; un rapporto la cui fine osservata coincide con
  `as_of` non è più conteggiato attivo.
- `prepare_rapporti()` e `analyze_ccnl()` hanno l'argomento
  `chiavi_non_classificate` (default `"CPUB"`): il codice di comodo del
  pubblico impiego non è un CCNL e viene trattato come non classificato,
  come in `cnelR`.
- `read_rapporti()` riconosce i codici orario `V` (part-time verticale) e
  `M` (part-time misto) come part-time nella derivazione di `prior`.
- Il lookup `tipologie_contrattuali` include i codici warehouse `AP-ULAV` e
  `AP-USOM` (apprendistato, anche in somministrazione) con la colonna
  `fonte_mlps`.
- Le misure `giornate` e `giornate_effettive` sono sommate in doppia
  precisione: sulle slice reali i totali superano il limite degli interi.
- Il default di `as_of` ignora le date di fine successive a oggi (fini
  presunte o valori errati come `2999-12-31`).

---

# ccnlcob 0.5.0

## Nuove funzionalità

- `compute_giornate_effettive()` ripartisce pro quota (1/`arco`) i giorni in
  cui la stessa persona ha più rapporti concorrenti, così che la somma per
  persona coincida con i giorni-persona occupati nella finestra; la
  segmentazione interna usa estremi inclusivi ed è verificata nei test
  contro i totali di `vecshift::vecshift()`.
- `analyze_ccnl()` esegue l'intero flusso (preparazione, giornate effettive,
  CPI, ranking per finestra e per periodo, selezione, distribuzioni per CPI
  e tipologia, retribuzioni con deflazione opzionale, tabella di qualità) e
  restituisce un oggetto `ccnlcob_result` con metadati e passi eseguiti o
  saltati; `print()` ne riassume il contenuto.
- `write_results()` serializza il risultato secondo il contratto di uscita
  (tabelle piccole in RDS, cubi in FST con compressione 85) e restituisce il
  manifesto dei file scritti.

---

# ccnlcob 0.4.0

## Nuove funzionalità

- `clean_retribuzione()` classifica la retribuzione annua lorda dichiarata
  all'avviamento (`flag_retribuzione`: valida, mancante, zero, sentinella,
  fuori_range) e produce `retribuzione_pulita` senza eliminare righe; la
  finestra di plausibilità è una regola mediana ± k·MAD su scala
  logaritmica per cella anno × macro-tipologia × orario, con pavimento sulla
  MAD e cella di ripiego. I default (`min_valore = 100`, `max_valore = 1e6`,
  `k = 4`, `mad_min = 0.15`) derivano dalla diagnostica su 32 milioni di
  rapporti COB reali.
- `normalize_fte()` riporta la retribuzione dei part-time all'equivalente a
  tempo pieno (`retribuzione_fte`, `flag_fte`) con ore di riferimento 40 e
  tabella opzionale per CCNL o macro-tipologia: sui dati reali i valori
  part-time risultano già proporzionali alle ore dichiarate.
- `median_retribuzione()` calcola per CCNL e coorte di avviamento la mediana
  e i quartili ponderati per giornate, con `n`, copertura, mascheramento
  sotto `min_n`, variazione percentuale e indice a base fissa.
- `deflate_retribuzione()` aggiunge le colonne `_reale` a partire da un
  indice dei prezzi fornito dall'utente e da un periodo base.
- `prepare_rapporti()` converte `retribuzione` e `ore` da factor o character
  (come nel file `rap.fst`) e conta i valori non numerici nei metadati.

---

# ccnlcob 0.3.0

## Nuove funzionalità

- Perimetro contrattuale: il lookup `tipologie_contrattuali` porta il flag
  `perimetro_ccnl`, vero per i rapporti di lavoro subordinato cui si applica
  un CCNL e falso per collaborazioni e lavoro occasionale, tirocini e work
  experience, associazione in partecipazione, contratto di agenzia, lavoro
  autonomo nello spettacolo e lavoro congiunto in agricoltura.
- `filter_perimetro()` applica uno dei perimetri `"ccnl"`, `"standard"`
  (quello di `cnelR`, flag `esclusa_standard`) o `"completo"` e riporta nei
  metadati le righe escluse per tipologia.

## Modifiche al comportamento

- `prepare_rapporti()` ha il nuovo argomento `perimetro`, con default
  `"ccnl"`: gli avviamenti fuori perimetro vengono esclusi prima delle
  sentinelle e della finestra, e contati in `ccnlcob_meta`
  (`n_dropped_perimetro`, `esclusi_perimetro`). Il comportamento precedente
  si ottiene con `perimetro = "completo"`. L'output porta sempre la colonna
  `perimetro_ccnl`.

---

# ccnlcob 0.2.0

## Nuove funzionalità

- `add_cpi()` aggiunge per riferimento `cpi_code` e `cpi_name` (Centro per
  l'Impiego) dal codice Belfiore della sede di lavoro o della residenza,
  tramite un `lookup` esplicito oppure `longworkR::add_cpi_via_belfiore()`;
  i comuni fuori Lombardia ricevono `FUORI`, i codici mancanti `ND`.
- `ccnl_by_cpi()` distribuisce una misura per CCNL e CPI con `quota_riga`,
  `quota_colonna` e quoziente di localizzazione `lq`, mascherato con `NA`
  sotto `min_n`; i totali includono i rapporti non classificati.
- `ccnl_by_tipologia()` distribuisce una misura per CCNL e tipologia
  contrattuale (macro-classe o codice MLPS), con orario full-time/part-time
  opzionale, stesse quote e `lq`.
- Dataset `cpi_esempio`: lookup Belfiore → CPI per i comuni di `cob_esempio`.
- La vignetta `analisi-ccnl` esegue anche le sezioni territoriali e per
  tipologia.

---

# ccnlcob 0.1.0

## Nuove funzionalità

- `prepare_rapporti()` normalizza i nomi di colonna della pipeline, risolve le
  sentinelle sulle date (`1900-01-01`, `9999-12-31`, `fine < inizio`), applica
  la finestra di analisi e aggiunge `ccnl_key`, `giornate`, `avviato`,
  `attivo`, `anno`, `trimestre`, `macro_tipologia` e `orario`; i conteggi
  delle correzioni sono nell'attributo `ccnlcob_meta`.
- `compute_giornate()` calcola le giornate-contratto (estremi inclusi)
  ritagliate sulla finestra, per riferimento.
- `classify_tipologia()` assegna la macro-tipologia contrattuale a partire dal
  lookup `tipologie_contrattuali`.
- `rank_ccnl()` produce, per gruppo e periodo, le misure `n_rapporti`,
  `n_lavoratori`, `n_datori`, `giornate`, `giornate_effettive` e `stock` con
  quote, quote cumulate e rank; la riga `Non classificati` rende visibile la
  copertura del codice CCNL.
- `select_ccnl_rilevanti()` seleziona i CCNL per quota cumulata e/o `top_n`
  e, in forma tabellare, aggrega i restanti in `Altri CCNL`.
- La vignetta `analisi-ccnl` esegue il flusso della Fase 1 su `cob_esempio`.

---

# ccnlcob 0.0.0.9000

* Scheletro iniziale del pacchetto (Fase 0 del piano di sviluppo): struttura
  CRAN, documentazione roxygen2 in italiano, vignetta introduttiva e sito
  pkgdown configurato.
* Contratto dati in ingresso formalizzato in `validate_rapporti()`: blocchi
  `base`, `cpi`, `retribuzione`, `datore` con elenco esplicito delle colonne
  mancanti.
* Interfaccia documentata per tutte le funzioni analitiche (preparazione,
  giornate, ranking, territorio, tipologie, retribuzioni, orchestrazione):
  le firme sono definitive, i corpi restano stub fino alle fasi successive.
* Dataset sintetico `cob_esempio` e lookup `tipologie_contrattuali` (MLPS,
  foglio ST-TIPO CONTRATTI, Rev.093) inclusi come dati del pacchetto.
