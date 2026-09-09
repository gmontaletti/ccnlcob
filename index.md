# ccnlcob

[![pkgdown](https://github.com/gmontaletti/ccnlcob/actions/workflows/pkgdown.yml/badge.svg)](https://gmontaletti.github.io/ccnlcob/)
[![R-CMD-check](https://github.com/gmontaletti/ccnlcob/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/gmontaletti/ccnlcob/actions/workflows/R-CMD-check.yaml)

Analisi dei microdati delle Comunicazioni Obbligatorie (COB) per
contratto collettivo nazionale di lavoro (CCNL).

## Obiettivo

Il pacchetto parte da un dataset COB con una riga per rapporto di lavoro
e risponde a quattro domande:

1.  quali CCNL sono più rilevanti, misurando la rilevanza per numero di
    persone avviate e per giornate effettive di lavoro;
2.  come si distribuiscono territorialmente i rapporti di ciascun CCNL
    per CPI (Centro per l’Impiego);
3.  come si distribuiscono i rapporti di ciascun CCNL per tipologia
    contrattuale;
4.  come evolve nel tempo la retribuzione mediana dichiarata
    all’avviamento per CCNL.

`ccnlcob` contiene solo calcolo e analisi. Non include codice Shiny né
pipeline `targets`: produce tabelle precomputate (RDS e FST) consumabili
da dashboard e report Quarto.

## Posizione nell’ecosistema

Il pacchetto è un consumatore analitico a valle di altri pacchetti
dell’ecosistema:

- `cnelR` esegue il raccordo dei codici CCNL (warehouse CO → INPS →
  CNEL) e produce la colonna `codice_cnel`; `ccnlcob` consuma i rapporti
  già classificati senza reimplementare il bridge.
- `longworkR` fornisce il mapping comune → CPI tramite
  `add_cpi_via_belfiore()`; `ccnlcob` non copia le utilità geografiche.
- `vecshift` segmenta gli intervalli sovrapposti della stessa persona;
  `ccnlcob` lo usa per allocare le giornate effettive pro quota fra
  rapporti concorrenti.

Le funzioni analitiche accettano un `data.table` e non aprono
connessioni. L’I/O (file FST/RDS, DuckDB, PostgreSQL) è isolato in
[`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md)
e
[`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md).

## Installazione

``` r

# install.packages("remotes")
remotes::install_github("gmontaletti/ccnlcob")
```

Le dipendenze `vecshift`, `longworkR` e `cnelR` sono dichiarate in
`Remotes` e vengono installate dallo stesso account GitHub.

## Uso

L’esempio seguente esegue la parte del flusso disponibile nella versione
corrente sul dataset sintetico `cob_esempio`, incluso nel pacchetto. Il
dataset riproduce il contratto dati in ingresso (sovrapposizioni,
sentinelle sulle date, codici CNEL mancanti, retribuzioni mancanti o
anomale) e permette prove senza accesso ai dati reali.

``` r

library(ccnlcob)
library(data.table)

# 1. validazione del contratto dati
dt <- copy(cob_esempio)
validate_rapporti(dt, require = c("cpi", "retribuzione", "datore"))

# 2. preparazione: rinomina, sentinelle sulle date, finestra, chiave CCNL,
#    giornate di contratto, periodo di avviamento, macro-tipologia, orario;
#    il perimetro di default ("ccnl") esclude collaborazioni, tirocini e le
#    altre tipologie senza CCNL, conteggiandole in esclusi_perimetro
dt <- prepare_rapporti(
  dt,
  as_of = as.Date("2024-12-31"),
  window = as.Date(c("2022-01-01", "2024-12-31")),
  ccnl_key = "codice_cnel"
)
attr(dt, "ccnlcob_meta")$esclusi_perimetro
dt[, .(rapporti = .N, giornate = sum(giornate)), by = .(anno, macro_tipologia)]

# 3. ranking: per ogni misura valore, quota, rank e quota cumulata;
#    la riga "Non classificati" rende visibile la copertura del codice CCNL
ranking <- rank_ccnl(dt, measures = c("n_lavoratori", "giornate"))
head(ranking)
per_anno <- rank_ccnl(dt, measures = "giornate", periodo = "anno")

# 4. selezione: CCNL che coprono l'80% delle giornate totali, oppure i primi 5
rilevanti <- select_ccnl_rilevanti(ranking, measure = "giornate", cum_share = 0.8)
top5 <- select_ccnl_rilevanti(
  ranking,
  measure = "giornate",
  top_n = 5,
  cum_share = NULL
)

# 5. territorio: CPI della sede di lavoro da un lookup comune -> CPI;
#    con lookup = NULL il mapping è delegato a longworkR::add_cpi_via_belfiore()
add_cpi(dt, geo = "sede_lavoro", lookup = cpi_esempio)
dt[, .N, by = .(cpi_code, cpi_name)][order(-N)]

#    tabella CCNL x CPI: misura, quota di riga (entro CCNL), quota di colonna
#    (entro CPI) e quoziente di localizzazione lq (NA sotto min_n)
cpi <- ccnl_by_cpi(dt, measure = "giornate", ccnl = top5)
cpi[ccnl_key == top5[1]]

# 6. tipologie: tabella CCNL x macro-tipologia x orario con le stesse quote
tipologie <- ccnl_by_tipologia(dt, measure = "n_rapporti", ccnl = top5, level = "macro")
tipologie[ccnl_key == top5[1]]
```

La vignetta `analisi-ccnl`
([`vignette("analisi-ccnl", package = "ccnlcob")`](https://gmontaletti.github.io/ccnlcob/articles/analisi-ccnl.md))
esegue lo stesso flusso con la descrizione delle regole applicate e
mostra l’uso previsto delle funzioni delle fasi successive.

## Stato di sviluppo

Versione 0.3.0: le Fasi 1 e 2 del piano di sviluppo sono completate e il
pacchetto applica il perimetro CCNL in ingresso. Il pacchetto fornisce
il contratto dati
([`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md)),
il perimetro contrattuale (flag `perimetro_ccnl` in
`tipologie_contrattuali`,
[`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md),
argomento `perimetro` di
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
con default `"ccnl"`), la preparazione dei rapporti
([`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md),
[`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md)),
le giornate di contratto
([`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md)),
il ranking con selezione dei CCNL
([`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
[`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md)),
la distribuzione territoriale per CPI
([`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md),
[`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md),
lookup di esempio `cpi_esempio`) e la distribuzione per tipologia
contrattuale
([`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md)).
Le funzioni delle Fasi 3-6 sono esportate e documentate con la firma
definitiva ma restituiscono un errore esplicito con la fase di
implementazione prevista.

| Fase | Versione | Contenuto | Stato |
|----|----|----|----|
| 0 | 0.0.0.9000 | scheletro, contratto dati, stub documentati, fixture sintetica | completata |
| 1 | 0.1.0 | [`validate_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/validate_rapporti.md), [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md), [`compute_giornate()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate.md), [`classify_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/classify_tipologia.md), [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md), [`select_ccnl_rilevanti()`](https://gmontaletti.github.io/ccnlcob/reference/select_ccnl_rilevanti.md), vignetta | completata |
| 2 | 0.2.0 | [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md), [`ccnl_by_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_cpi.md), [`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md), dataset `cpi_esempio` | completata |
| 2 bis | 0.3.0 | perimetro CCNL: flag `perimetro_ccnl`, [`filter_perimetro()`](https://gmontaletti.github.io/ccnlcob/reference/filter_perimetro.md), argomento `perimetro` di [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md) | completata |
| 3 | 0.4.0 | [`clean_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/clean_retribuzione.md), [`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md), [`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md), [`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md) | prevista |
| 4 | 0.5.0 | [`compute_giornate_effettive()`](https://gmontaletti.github.io/ccnlcob/reference/compute_giornate_effettive.md), [`analyze_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/analyze_ccnl.md), [`write_results()`](https://gmontaletti.github.io/ccnlcob/reference/write_results.md) | prevista |
| 5 | 0.6.0 | [`read_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/read_rapporti.md) da DuckDB, pipeline `targets` esterna, sito pkgdown, CI | prevista |
| 6 | 0.7.0 | grafici opzionali e report Quarto | prevista |

## Citazione

Per citare ccnlcob nelle pubblicazioni:

Montaletti, G. (2026). *ccnlcob: Analysis of COB Microdata by National
Collective Labour Agreement (CCNL)* (Version 0.3.0) \[R package\].
<https://github.com/gmontaletti/ccnlcob>

Voce BibTeX:

``` bibtex
@software{montaletti2026ccnlcob,
  author = {Montaletti, Giampaolo},
  title = {ccnlcob: Analysis of COB Microdata by National Collective Labour Agreement (CCNL)},
  version = {0.3.0},
  year = {2026},
  url = {https://github.com/gmontaletti/ccnlcob}
}
```

## Licenza

MIT + file LICENSE
