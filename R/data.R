# 1. Lookup delle tipologie contrattuali -----

#' Tipologie contrattuali MLPS con macro-classe
#'
#' Lookup delle tipologie contrattuali delle Comunicazioni Obbligatorie
#' (classificazioni standard del Ministero del Lavoro e delle Politiche
#' Sociali) con la macro-classe usata da [classify_tipologia()] e
#' [ccnl_by_tipologia()], il flag di appartenenza al perimetro CCNL usato da
#' [filter_perimetro()] e il flag di esclusione dal perimetro "standard"
#' adottato da `cnelR`. Oltre alle tipologie del foglio MLPS contiene due
#' codici usati dal solo warehouse CO (`AP-ULAV`, apprendistato, e
#' `AP-USOM`, apprendistato in somministrazione), distinti dalla colonna
#' `fonte_mlps`.
#'
#' @format Un `data.table` con una riga per codice di tipologia contrattuale
#'   e le colonne:
#' \describe{
#'   \item{cod_tipologia_contrattuale}{character. Codice MLPS della tipologia
#'     (es. `A.01.00`) oppure codice del warehouse CO (`AP-ULAV`,
#'     `AP-USOM`).}
#'   \item{des_tipologia_contrattuale}{character. Descrizione ufficiale MLPS
#'     della tipologia; per i codici warehouse una descrizione assegnata nel
#'     pacchetto.}
#'   \item{macro_tipologia}{character. Macro-classe di analisi, una fra:
#'     `Tempo indeterminato`, `Tempo determinato`, `Apprendistato`,
#'     `Somministrazione`, `Intermittente`, `Collaborazioni`, `Tirocinio`,
#'     `Domestico`, `Altro`.}
#'   \item{perimetro_ccnl}{logical. `TRUE` per le tipologie di lavoro
#'     subordinato alle quali si applica un CCNL: tutti i codici `A.`
#'     (incluso il lavoro domestico), `F.` (marittimo), `G.01.00` e
#'     `G.02.00` (spettacolo subordinato), `H.01.00` e `H.03.00`
#'     (agricoltura subordinata), `I.` (pubblica amministrazione) e `N.`
#'     (piattaforma). `FALSE` per `B.` (collaborazioni e parasubordinati),
#'     `C.` (tirocini, LSU e work experience), `G.03.00` (lavoro autonomo
#'     nello spettacolo), `H.02.00` (lavoro congiunto in agricoltura),
#'     `L.` (associazione in partecipazione) e `M.` (contratto di agenzia).
#'     Le regole complete sono in `data-raw/tipologie_contrattuali.R`.}
#'   \item{esclusa_standard}{logical. `TRUE` per le tipologie escluse dal
#'     perimetro "standard" di `cnelR` (`C.01.00`, `B.04.00`, `B.03.00`,
#'     `A.04.00`, `A.04.01`).}
#'   \item{fonte_mlps}{logical. `TRUE` per le righe del foglio MLPS, `FALSE`
#'     per i codici del solo warehouse CO (`AP-ULAV` con macro-classe
#'     `Apprendistato`, `AP-USOM` con macro-classe `Somministrazione`;
#'     entrambi con `perimetro_ccnl = TRUE` e `esclusa_standard = FALSE`).}
#' }
#' @source Ministero del Lavoro e delle Politiche Sociali, "Classificazioni
#'   Standard" delle Comunicazioni Obbligatorie, foglio ST-TIPO CONTRATTI,
#'   Rev.093 del 2026-04-26; codici warehouse aggiunti in
#'   `data-raw/tipologie_contrattuali.R`.
#' @seealso [classify_tipologia()], [filter_perimetro()],
#'   [ccnl_by_tipologia()]
#' @docType data
#' @name tipologie_contrattuali
#' @usage tipologie_contrattuali
#' @keywords datasets
#' @examples
#' head(tipologie_contrattuali)
NULL

# 2. Dataset sintetico di esempio -----

#' Dataset COB sintetico a livello di rapporto di lavoro
#'
#' Dataset sintetico che riproduce il contratto dati in ingresso del pacchetto
#' (una riga per rapporto di lavoro, circa 5.000 rapporti). I codici fiscali,
#' i datori, i codici Belfiore e le retribuzioni sono generati in modo
#' deterministico e non corrispondono a persone, imprese o comunicazioni
#' reali.
#'
#' Il dataset contiene intenzionalmente: rapporti sovrapposti per la stessa
#' persona (per [compute_giornate_effettive()]), date di fine sentinella
#' `9999-12-31` e `1900-01-01` (rapporti aperti, gestiti da
#' [prepare_rapporti()]), retribuzioni mancanti e valori implausibili (per
#' [clean_retribuzione()]), codici CNEL mancanti per una quota di rapporti
#' non raccordati e una quota di sedi di lavoro fuori regione.
#'
#' @format Un `data.table` con una riga per rapporto di lavoro e le colonne:
#' \describe{
#'   \item{id}{integer. Identificativo univoco del rapporto.}
#'   \item{cf}{character. Identificativo sintetico della persona.}
#'   \item{inizio}{Date. Data di avviamento.}
#'   \item{fine}{Date. Data di cessazione; include le sentinelle `9999-12-31`
#'     e `1900-01-01` per i rapporti aperti.}
#'   \item{codice_cnel}{character. Codice CNEL a 4 caratteri; `NA` per i
#'     rapporti non raccordati.}
#'   \item{ccnl}{character. Codice warehouse CO del contratto collettivo
#'     (3-4 caratteri).}
#'   \item{cod_tipologia_contrattuale}{character. Codice MLPS della tipologia
#'     contrattuale (es. `A.01.00`).}
#'   \item{prior}{integer. 1 per tempo pieno, 0 per tempo parziale.}
#'   \item{comune_sede_lavoro}{character. Codice Belfiore del comune della
#'     sede di lavoro.}
#'   \item{comune_lavoratore}{character. Codice Belfiore del comune di
#'     residenza del lavoratore.}
#'   \item{datore}{character. Identificativo sintetico del datore di lavoro.}
#'   \item{retribuzione}{numeric. Retribuzione annua lorda dichiarata
#'     all'avviamento; contiene `NA` e valori implausibili.}
#'   \item{ore}{numeric. Ore settimanali medie.}
#'   \item{troncata}{integer. 1 se `fine` è stata clampata alla data di
#'     stabilizzazione, 0 altrimenti.}
#'   \item{qualifica}{character. Codice della qualifica professionale.}
#'   \item{ateco_gruppo}{character. Gruppo ATECO della sede di lavoro.}
#'   \item{eta}{integer. Età del lavoratore all'avviamento.}
#'   \item{sesso}{character. Sesso del lavoratore (`F`/`M`).}
#' }
#' @source Generato da `data-raw/cob_esempio.R` con un generatore
#'   deterministico (`generate_cob_sintetico()`); nessun dato reale.
#' @seealso [validate_rapporti()], [prepare_rapporti()]
#' @docType data
#' @name cob_esempio
#' @usage cob_esempio
#' @keywords datasets
#' @examples
#' str(cob_esempio)
NULL

# 3. Lookup CPI di esempio -----

#' Lookup comune -> CPI per i comuni di cob_esempio
#'
#' Tabella di raccordo fra i codici Belfiore usati in [cob_esempio] (sede di
#' lavoro e residenza) e il CPI (Centro per l'Impiego) di competenza,
#' risolta con le utilità geografiche di `longworkR`. Contiene solo i comuni
#' lombardi risolti (i dodici capoluoghi); i quattro codici fuori regione
#' presenti in [cob_esempio] (`F952`, `G535`, `H501`, `L219`) non compaiono
#' e con [add_cpi()] ricevono il residuo `FUORI`. Consente di eseguire gli
#' esempi di [add_cpi()] e [ccnl_by_cpi()] senza `longworkR` e senza i file
#' di mapping.
#'
#' @format Un `data.table` con una riga per comune e le colonne:
#' \describe{
#'   \item{belfiore}{character. Codice Belfiore (catastale) del comune, chiave
#'     univoca.}
#'   \item{cpi_code}{character. Codice del CPI di competenza (codice
#'     Belfiore del comune sede del CPI seguito dal codice ufficio).}
#'   \item{cpi_name}{character. Denominazione del CPI (es. `CPI MILANO`).}
#' }
#' @source Generato da `data-raw/cpi_esempio.R` con
#'   `longworkR::add_cpi_via_belfiore()` (utilità geografiche di `longworkR`
#'   sui file `belfiore_istat_mapping.csv` e `comune_cpi_lookup.rds` in
#'   `SHARED_DATA_DIR/maps`), 2026-09-09.
#' @seealso [add_cpi()], [ccnl_by_cpi()], [cob_esempio]
#' @docType data
#' @name cpi_esempio
#' @usage cpi_esempio
#' @keywords datasets
#' @examples
#' cpi_esempio
NULL
