# CLAUDE.md

Guida per Claude Code nel pacchetto `ccnlcob` (directory `contratti_collettivi/`).

## Scope

`ccnlcob` analizza dataset COB (Comunicazioni Obbligatorie) a livello di
rapporto di lavoro per: (1) classificare i CCNL per rilevanza (persone avviate,
giornate effettive), (2) distribuirli per CPI (Centro per l'Impiego),
(3) distribuirli per tipologia contrattuale, (4) stimare l'evoluzione della
retribuzione mediana per CCNL. Solo calcolo: nessun codice Shiny, nessuna
pipeline `targets` nel pacchetto.

Le convenzioni di ecosistema stanno in `../CLAUDE.md` (data.table obbligatorio,
roxygen2 markdown, SemVer, prosa italiana accentata, sezioni `# 1. nome -----`).
Questo file le estende. La directory `.claude/` non va spostata durante le
operazioni di pulizia.

Piano di sviluppo dettagliato: `../reference/ccnlcob/piano_sviluppo.md`
(contratto dati, firme, metodologia, fasi). Script di sviluppo ed esplorazioni:
`../test/ccnlcob/`. Artefatti temporanei: `../reference/ccnlcob/`.

## Confini con gli altri pacchetti

- Raccordo dei codici CCNL (warehouse CO → INPS → CNEL): `cnelR` in `../CCNL/`.
  Non reimplementare il bridge; consumare `codice_cnel` già prodotto.
- Mapping comune → CPI: `longworkR::add_cpi_via_belfiore()`. Non copiare le
  utilità geografiche.
- Segmentazione intervalli e giornate: `vecshift::vecshift()` (colonne `arco`,
  `durata`).
- `data_pipeline` non porta la colonna `ccnl`: la lineage con CCNL è la slice
  DuckDB di `cnelR` (`sl2_rapporti_36m_classificati`).

## Terminologia vincolante

- `CPI` = Centro per l'Impiego, mai indice dei prezzi. La deflazione usa
  `indice` come nome di argomento e `_reale` come suffisso.
- `ccnl` (colonna sorgente) è un codice warehouse a 3–4 caratteri, non il
  codice CNEL. In ingresso viene rinominata `ccnl_warehouse`; la chiave di
  analisi è `ccnl_key` (default `codice_cnel`). Vedi
  `../CCNL/CLASSIFICATORI_CCNL.md`.
- `giornate` = giorni-contratto nella finestra; `giornate_effettive` =
  giorni-persona allocati pro quota (1/`arco`) fra rapporti concorrenti.
- `retribuzione` = retribuzione annua lorda dichiarata all'avviamento;
  `retribuzione_fte` = normalizzata alle ore di riferimento del CCNL.

## Convenzioni del pacchetto

- Funzioni: verbo inglese + sostantivo di dominio italiano
  (`rank_ccnl()`, `compute_giornate()`, `median_retribuzione()`), come `cnelR`.
- Colonne di dominio in italiano (`giornate`, `retribuzione`, `tipologia`),
  tecniche in inglese (`ccnl_key`, `window`, `as_of`).
- Le funzioni analitiche accettano `data.table` e non aprono connessioni;
  l'I/O sta in `R/io.R`.
- Nessun parametro analitico fissato a priori: soglie e ore di riferimento
  derivano dai dati o sono argomenti espliciti documentati.
- Le tabelle di uscita riportano sempre `n` e copertura accanto a quote e
  mediane; i gruppi sotto `min_n` vengono mascherati, non eliminati.
- Sentinelle su `fine` (`1900-01-01`, `9999-12-31`, `fine < inizio`) gestite
  solo in `prepare_rapporti()`.
- Test: fixture sintetiche da `generate_cob_sintetico()`; niente DB; lookup
  CPI esplicito nei test; `expect_equal(tolerance)` per valori continui.

## Comandi

```r
devtools::load_all()
devtools::document()
devtools::test()
devtools::check(args = c("--no-manual", "--as-cran"))
```

## Stato

Versione 0.3.0: Fasi 1, 2 e 2 bis completate (`validate_rapporti()`,
`prepare_rapporti()`, `compute_giornate()`, `classify_tipologia()`, `rank_ccnl()`,
`select_ccnl_rilevanti()`, `add_cpi()`, `ccnl_by_cpi()`, `ccnl_by_tipologia()`,
`filter_perimetro()`); le altre funzioni esportate sono stub.
`prepare_rapporti()` esclude per default gli avviamenti fuori dal perimetro CCNL
(`perimetro = "ccnl"`, flag `perimetro_ccnl` in `tipologie_contrattuali`). Le misure per gruppo sono calcolate
da `.aggregate_misure()` (`R/crosstab.R`), usato sia da `rank_ccnl()` sia dalle
tabelle incrociate.
Le fasi successive sono elencate in `../reference/ccnlcob/piano_sviluppo.md` §8.
Verificare sempre il check con `R CMD check` sul tarball o leggendo
`00check.log`: `devtools::check()` può riportare "0 errors" su un run
interrotto (caso osservato con una copia non installata di `longworkR` nella
libreria di sistema, risolto il 2026-09-08; vedi piano §9).
