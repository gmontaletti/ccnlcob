#' ccnlcob: analisi dei CCNL nei microdati delle Comunicazioni Obbligatorie
#'
#' @description
#' Il pacchetto analizza dataset COB (Comunicazioni Obbligatorie) a livello di
#' rapporto di lavoro per rispondere a quattro domande: quali CCNL (contratti
#' collettivi nazionali di lavoro) sono più rilevanti, misurando la rilevanza
#' per persone avviate e per giornate effettive di lavoro; come si
#' distribuiscono i rapporti di ciascun CCNL per CPI (Centro per l'Impiego);
#' come si distribuiscono per tipologia contrattuale; come evolve nel tempo la
#' retribuzione mediana dichiarata all'avviamento.
#'
#' Il pacchetto contiene solo calcolo. Consuma rapporti già classificati da
#' `cnelR` (colonna `codice_cnel`), delega il mapping comune → CPI a
#' `longworkR::add_cpi_via_belfiore()` e la segmentazione degli intervalli
#' sovrapposti a `vecshift::vecshift()`. Le funzioni analitiche accettano un
#' `data.table` e non aprono connessioni; l'I/O è isolato in
#' [read_rapporti()] e [write_results()].
#'
#' @section Flusso di lavoro:
#' 1. [read_rapporti()] e [validate_rapporti()] leggono e verificano il
#'    contratto dati.
#' 2. [prepare_rapporti()] normalizza i nomi, gestisce le sentinelle sulle
#'    date, aggiunge `ccnl_key`, `giornate`, periodo e macro-tipologia.
#' 3. [compute_giornate()] e [compute_giornate_effettive()] misurano i
#'    giorni-contratto e i giorni-persona allocati pro quota.
#' 4. [rank_ccnl()] e [select_ccnl_rilevanti()] ordinano i CCNL e selezionano
#'    quelli rilevanti per soglia di copertura o `top_n`.
#' 5. [add_cpi()], [ccnl_by_cpi()], [ccnl_by_tipologia()] distribuiscono i
#'    CCNL per territorio e per tipologia contrattuale.
#' 6. [clean_retribuzione()], [normalize_fte()], [median_retribuzione()] e
#'    [deflate_retribuzione()] stimano l'evoluzione della retribuzione
#'    mediana.
#' 7. [analyze_ccnl()] orchestra i passi precedenti e [write_results()]
#'    serializza le tabelle per dashboard e report.
#'
#' @section Terminologia:
#' - `CPI` indica sempre il Centro per l'Impiego; la deflazione usa
#'   l'argomento `indice` e il suffisso `_reale`.
#' - `ccnl` (colonna sorgente) è il codice warehouse delle Comunicazioni
#'   Obbligatorie; in ingresso viene rinominata `ccnl_warehouse`. La chiave
#'   di analisi è `ccnl_key` (default `codice_cnel`).
#' - `giornate` sono i giorni-contratto nella finestra; `giornate_effettive`
#'   sono i giorni-persona allocati pro quota (1/`arco`) fra rapporti
#'   concorrenti.
#' - `retribuzione` è la retribuzione annua lorda dichiarata all'avviamento;
#'   `retribuzione_fte` è normalizzata alle ore di riferimento del CCNL.
#'
#' @keywords internal
#' @importFrom data.table data.table setDT := .SD .N fifelse fcase uniqueN
#'   setnames setkey copy rbindlist
#' @importFrom fst read_fst write_fst
#' @importFrom stats mad median quantile
#' @importFrom utils globalVariables
"_PACKAGE"

# 1. Variabili globali per la NSE di data.table -----

utils::globalVariables(c(
  # identificativi e date
  "id",
  "cf",
  "datore",
  "inizio",
  "fine",
  "troncata",
  "attivo",
  # chiavi CCNL
  "codice_cnel",
  "ccnl",
  "ccnl_warehouse",
  "ccnl_key",
  "ccnl_titolo",
  "macro_settore_cnel",
  # tipologie e orario
  "cod_tipologia_contrattuale",
  "des_tipologia_contrattuale",
  "macro_tipologia",
  "esclusa_standard",
  "perimetro_ccnl",
  "tipologia",
  "prior",
  "orario",
  # territorio
  "comune_sede_lavoro",
  "comune_lavoratore",
  "cpi_code",
  "cpi_name",
  "belfiore",
  "i.cpi_code",
  "i.cpi_name",
  # tempo
  "anno",
  "trimestre",
  "periodo",
  "giornate",
  "giornate_effettive",
  "durata",
  "arco",
  "giorni_intersezione",
  "seg_inizio",
  "seg_fine",
  # misure e quote
  "n",
  "n_rapporti",
  "n_lavoratori",
  "n_datori",
  "stock",
  "valore",
  "quota",
  "quota_cum",
  "quota_riga",
  "quota_colonna",
  "lq",
  "rank",
  "copertura",
  # retribuzioni
  "retribuzione",
  "retribuzione_pulita",
  "flag_retribuzione",
  "retribuzione_fte",
  "flag_fte",
  "retribuzione_reale",
  "ore",
  "ore_riferimento",
  "mediana",
  "mediana_reale",
  "p25",
  "p75",
  "var_pct",
  "var_pct_reale",
  "indice",
  "indice_reale",
  # dimensioni aggiuntive
  "qualifica",
  "ateco_gruppo",
  "eta",
  "sesso",
  # simboli data.table
  ".",
  "..cols"
))
