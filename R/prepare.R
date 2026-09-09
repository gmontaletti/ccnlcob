# 1. Preparazione dei rapporti -----

#' Prepara i rapporti di lavoro per l'analisi
#'
#' Normalizza un dataset di rapporti di lavoro conforme al contratto dati:
#' rinomina le colonne (varianti maiuscole della pipeline e `ccnl` in
#' `ccnl_warehouse`), applica il perimetro contrattuale, risolve le
#' sentinelle sulle date, esclude i rapporti esterni alla finestra di
#' analisi e aggiunge le colonne derivate usate dalle funzioni analitiche.
#' L'input non viene mai modificato: la funzione lavora su una copia e
#' restituisce un nuovo `data.table`.
#'
#' @param dt Un `data.table` con una riga per rapporto di lavoro; vedi
#'   [validate_rapporti()] per il contratto dati. Le colonne `inizio` e
#'   `fine` devono ereditare dalla classe `Date` (`IDate` accettata: la
#'   classe viene conservata in uscita).
#' @param as_of Data di riferimento (`Date` o stringa convertibile) per lo
#'   stato dei rapporti (`attivo`) e per la chiusura dei rapporti aperti;
#'   `NULL` (default) usa la data massima non sentinella osservata fra
#'   `inizio` e `fine`, cioè la data di riferimento dei dati.
#' @param window Vettore di due `Date` (o stringhe convertibili),
#'   `c(inizio, fine)`, che delimita l'analisi; `NULL` (default) usa
#'   `c(min(inizio), as_of)`, dove il minimo è calcolato sugli avviamenti
#'   non sentinella.
#' @param ccnl_key Colonna da usare come chiave CCNL di analisi:
#'   `"codice_cnel"` (codice CNEL a 4 caratteri prodotto da `cnelR`) oppure
#'   `"ccnl_warehouse"` (codice warehouse CO). Con il default (entrambe)
#'   viene usata la prima colonna presente in `dt`; se una colonna richiesta
#'   esplicitamente è assente la funzione produce un errore.
#' @param perimetro Perimetro contrattuale applicato da [filter_perimetro()]
#'   prima di ogni altro trattamento: `"ccnl"` (default) conserva solo le
#'   tipologie di lavoro subordinato alle quali si applica un CCNL;
#'   `"standard"` conserva il perimetro "standard" di `cnelR`;
#'   `"completo"` non esclude nulla. Vedi Dettagli.
#' @param tipologie Lookup delle tipologie contrattuali con le colonne
#'   `cod_tipologia_contrattuale`, `macro_tipologia`, `perimetro_ccnl` e
#'   `esclusa_standard`; default [tipologie_contrattuali].
#'
#' @details
#' ## Normalizzazione dei nomi
#' Le varianti maiuscole prodotte dalla pipeline COB vengono rinominate solo
#' se la colonna minuscola corrispondente è assente: `INIZIO`, `FINE`,
#' `COD_TIPOLOGIA_CONTRATTUALE`, `COMUNE_SEDE_LAVORO`, `COMUNE_LAVORATORE`,
#' `RETRIBUZIONE`, `ORE_SETTIM_MEDIE` (in `ore`), `ETA_LAV_INIZIO` (in
#' `eta`), `SESSO_LAV` (in `sesso`). La colonna sorgente `ccnl` (codice
#' warehouse) viene rinominata `ccnl_warehouse` se quest'ultima è assente.
#' Il contratto dati viene verificato dopo la rinomina.
#'
#' ## Conversione di `retribuzione` e `ore`
#' Nel file `rap.fst` della pipeline COB `retribuzione` e `ore` sono factor
#' con livelli zero-padded (es. `"000023671"`, `"05"`). Se presenti come
#' factor o character, le due colonne vengono convertite in numeric sui
#' livelli (`as.numeric(levels(f))[f]`) senza avvisi; i valori che non
#' rappresentano un numero diventano `NA` e sono conteggiati nei metadati
#' `n_retribuzione_non_numerica` e `n_ore_non_numeriche` (0 quando le
#' colonne sono già numeriche o assenti). I valori numerici non vengono
#' alterati: la pulizia della retribuzione è compito di
#' [clean_retribuzione()], quella delle ore di [normalize_fte()].
#'
#' ## Perimetro contrattuale
#' Subito dopo la verifica del contratto dati la funzione richiama
#' [filter_perimetro()] con il `perimetro` scelto:
#' - `"ccnl"` (default) conserva i rapporti con `perimetro_ccnl == TRUE`
#'   nel lookup, cioè il lavoro subordinato al quale si applica un CCNL
#'   (codici `A.`, `F.`, `G.01.00`, `G.02.00`, `H.01.00`, `H.03.00`, `I.`,
#'   `N.`); esclude collaborazioni e parasubordinati (`B.`), tirocini e
#'   work experience (`C.`), lavoro autonomo nello spettacolo (`G.03.00`),
#'   lavoro congiunto in agricoltura (`H.02.00`), associazione in
#'   partecipazione (`L.`), contratti di agenzia (`M.`) e i codici ignoti;
#' - `"standard"` conserva i rapporti con `esclusa_standard == FALSE`
#'   (perimetro di `cnelR`), codici ignoti inclusi;
#' - `"completo"` conserva tutte le righe e riproduce il comportamento
#'   delle versioni fino alla 0.2.0, che non applicavano alcun perimetro.
#'
#' Le righe escluse sono conteggiate in `n_dropped_perimetro` e dettagliate
#' per tipologia in `esclusi_perimetro`; [filter_perimetro()] emette un
#' `message()` riassuntivo, sopprimibile. La data di riferimento di default
#' (`as_of = NULL`) è calcolata prima del filtro, su tutti i rapporti, così
#' da non dipendere dal perimetro; la finestra di default parte invece dal
#' primo avviamento interno al perimetro.
#'
#' ## Sentinelle sulle date
#' Questa è l'unica funzione del pacchetto che interviene sulle sentinelle,
#' con le regole di `cnelR` 0.6.0:
#' - `fine` mancante, `<= 1900-01-01` o `> as_of` (incluso `9999-12-31`)
#'   identifica un rapporto aperto: `fine` diventa `as_of` e `troncata`
#'   vale `1`;
#' - `inizio` mancante o `<= 1900-01-01` diventa `2008-03-01` (avvio del
#'   sistema delle Comunicazioni Obbligatorie) e `troncata_inizio` vale `1`;
#' - dopo le sostituzioni, `fine < inizio` viene riportata a `inizio`
#'   (rapporto di un giorno) e conteggiata nei metadati.
#'
#' Se `dt` contiene già `troncata`, il flag esistente viene combinato in OR
#' con quello calcolato; `troncata` e `troncata_inizio` sono integer 0/1.
#'
#' ## Finestra di analisi
#' I rapporti con `inizio > window[2]` o `fine < window[1]` non
#' intersecano la finestra e vengono rimossi (conteggiati in
#' `n_dropped_window`). Per i rapporti rimanenti `giornate` conta i giorni
#' interni alla finestra, estremi inclusi, ed è quindi sempre `>= 1`.
#'
#' ## Colonne aggiunte
#' - `ccnl_key` (character): chiave di analisi scelta; `NA` resta `NA`;
#' - `perimetro_ccnl` (logical): appartenenza al perimetro CCNL secondo
#'   `tipologie`, `FALSE` per i codici ignoti; con `perimetro = "ccnl"` è
#'   sempre `TRUE`;
#' - `troncata`, `troncata_inizio` (integer 0/1): flag delle sentinelle;
#' - `giornate` (integer): giorni-contratto nella finestra, vedi
#'   [compute_giornate()];
#' - `avviato` (logical): `inizio >= window[1]`, cioè avviamento interno
#'   alla finestra;
#' - `attivo` (logical): rapporto in essere alla data `as_of`
#'   (`inizio <= as_of & fine >= as_of`). Con una finestra esplicita che
#'   termina prima di `as_of`, lo stock misurato da [rank_ccnl()] si
#'   riferisce comunque ad `as_of`: per uno stock alla fine della finestra
#'   passare `as_of = window[2]`;
#' - `anno` (integer) e `trimestre` (character `"YYYY-Qn"`): coorte di
#'   avviamento da `inizio`;
#' - `macro_tipologia` (character): macro-classe da `tipologie`, vedi
#'   [classify_tipologia()]; `NA` per i codici ignoti;
#' - `orario` (character): `"FT"` se `prior == 1`, `"PT"` se `prior == 0`,
#'   `NA` altrimenti.
#'
#' ## Metadati
#' L'attributo `ccnlcob_meta` del risultato è una lista con `as_of`,
#' `window`, `ccnl_key` (nome della colonna usata), `perimetro`, `n_input`
#' (righe di `dt`), `n_dropped_perimetro`, `n_tipologia_ignota`,
#' `n_dropped_window`, `n_sentinel_fine`, `n_sentinel_inizio`,
#' `n_fine_lt_inizio`, `n_retribuzione_non_numerica`, `n_ore_non_numeriche`
#' e `esclusi_perimetro` (la tabella `esclusi` di [filter_perimetro()]).
#'
#' @return Un nuovo `data.table` con le colonne di `dt` (rinominate come
#'   descritto) e le colonne derivate elencate nei Dettagli, limitato ai
#'   rapporti interni al perimetro che intersecano la finestra; l'attributo
#'   `ccnlcob_meta` riporta i parametri e i conteggi. L'input non viene
#'   modificato.
#' @family ingresso
#' @export
#' @examples
#' library(data.table)
#' dt <- prepare_rapporti(cob_esempio)
#' attr(dt, "ccnlcob_meta")[c("as_of", "n_sentinel_fine", "n_fine_lt_inizio")]
#' attr(dt, "ccnlcob_meta")$esclusi_perimetro
#' dt[, .N, by = .(anno, macro_tipologia)][order(anno, -N)][1:5]
#'
#' # finestra esplicita, chiave warehouse e nessun filtro di perimetro
#' dt24 <- prepare_rapporti(
#'   cob_esempio,
#'   as_of = as.Date("2024-12-31"),
#'   window = as.Date(c("2024-01-01", "2024-12-31")),
#'   ccnl_key = "ccnl_warehouse",
#'   perimetro = "completo"
#' )
#' dt24[, .(n = .N, giornate = sum(giornate)), by = ccnl_key][order(-giornate)]
prepare_rapporti <- function(
  dt,
  as_of = NULL,
  window = NULL,
  ccnl_key = c("codice_cnel", "ccnl_warehouse"),
  perimetro = c("ccnl", "standard", "completo"),
  tipologie = ccnlcob::tipologie_contrattuali
) {
  # 1.1 Controlli preliminari e copia -----
  if (!data.table::is.data.table(dt)) {
    .assert_rapporti(dt, require = "base", caller = "prepare_rapporti")
  }
  ccnl_key <- match.arg(ccnl_key, several.ok = TRUE)
  perimetro <- match.arg(perimetro)
  as_of <- .as_as_of(as_of, caller = "prepare_rapporti")
  window <- .as_window(window, caller = "prepare_rapporti")
  n_input <- nrow(dt)

  out <- data.table::copy(dt)
  .normalize_names(out)
  .assert_rapporti(out, require = "base", caller = "prepare_rapporti")
  conversioni <- .coerce_numeric_cols(out, c("retribuzione", "ore"))

  # 1.2 Perimetro contrattuale -----
  # as_of di default è calcolata su tutti i rapporti, prima del filtro.
  if (is.null(as_of)) {
    as_of <- .default_as_of(out)
  }
  out <- filter_perimetro(out, perimetro = perimetro, tipologie = tipologie)
  info_perimetro <- attr(out, "ccnlcob_perimetro")
  data.table::setattr(out, "ccnlcob_perimetro", NULL)

  # 1.3 Chiave CCNL -----
  key_col <- .select_ccnl_key(out, ccnl_key)
  data.table::set(out, j = "ccnl_key", value = as.character(out[[key_col]]))

  # 1.4 Sentinelle sulle date e finestra -----
  conteggi <- .clamp_dates(out, as_of = as_of)
  if (is.null(window)) {
    window <- .default_window(out, as_of = as_of)
  }
  fuori <- out[["inizio"]] > window[2L] | out[["fine"]] < window[1L]
  n_dropped_window <- sum(fuori)
  if (n_dropped_window > 0L) {
    out <- out[!fuori]
  }

  # 1.5 Colonne derivate -----
  compute_giornate(out, window = window)
  data.table::set(out, j = "avviato", value = out[["inizio"]] >= window[1L])
  data.table::set(
    out,
    j = "attivo",
    value = out[["inizio"]] <= as_of & out[["fine"]] >= as_of
  )
  .add_periodo(out)
  data.table::set(
    out,
    j = "macro_tipologia",
    value = classify_tipologia(
      out[["cod_tipologia_contrattuale"]],
      tipologie = tipologie
    )
  )
  prior <- out[["prior"]]
  orario <- data.table::fifelse(
    prior == 1,
    "FT",
    data.table::fifelse(prior == 0, "PT", NA_character_)
  )
  data.table::set(out, j = "orario", value = orario)

  # 1.6 Metadati -----
  meta <- list(
    as_of = as_of,
    window = window,
    ccnl_key = key_col,
    perimetro = perimetro,
    n_input = as.integer(n_input),
    n_dropped_perimetro = info_perimetro$n_dropped,
    n_tipologia_ignota = info_perimetro$n_tipologia_ignota,
    n_dropped_window = as.integer(n_dropped_window),
    n_sentinel_fine = conteggi$n_sentinel_fine,
    n_sentinel_inizio = conteggi$n_sentinel_inizio,
    n_fine_lt_inizio = conteggi$n_fine_lt_inizio,
    n_retribuzione_non_numerica = conversioni[["retribuzione"]],
    n_ore_non_numeriche = conversioni[["ore"]],
    esclusi_perimetro = info_perimetro$esclusi
  )
  data.table::setattr(out, "ccnlcob_meta", meta)
  out[]
}

# 2. Costanti interne -----

# Data minima ammessa: valori uguali o precedenti sono sentinelle.
.data_sentinella_min <- as.Date("1900-01-01")

# Data massima usata come sentinella per i rapporti aperti.
.data_sentinella_max <- as.Date("9999-12-31")

# Avvio del sistema delle Comunicazioni Obbligatorie: sostituisce gli
# avviamenti sentinella.
.data_avvio_cob <- as.Date("2008-03-01")

# Varianti maiuscole prodotte dalla pipeline COB e nome normalizzato.
.nomi_pipeline <- c(
  INIZIO = "inizio",
  FINE = "fine",
  COD_TIPOLOGIA_CONTRATTUALE = "cod_tipologia_contrattuale",
  COMUNE_SEDE_LAVORO = "comune_sede_lavoro",
  COMUNE_LAVORATORE = "comune_lavoratore",
  RETRIBUZIONE = "retribuzione",
  ORE_SETTIM_MEDIE = "ore",
  ETA_LAV_INIZIO = "eta",
  SESSO_LAV = "sesso",
  ccnl = "ccnl_warehouse"
)

# 3. Helper interni -----

#' Normalizza i nomi delle colonne per riferimento
#'
#' Rinomina le varianti maiuscole della pipeline e `ccnl` in
#' `ccnl_warehouse`, solo quando la colonna di destinazione è assente.
#'
#' @param dt Un `data.table`, modificato per riferimento.
#' @return `dt`, invisibilmente.
#' @keywords internal
#' @noRd
.normalize_names <- function(dt) {
  presenti <- names(dt)
  da_rinominare <- names(.nomi_pipeline)[
    names(.nomi_pipeline) %in% presenti & !(.nomi_pipeline %in% presenti)
  ]
  if (length(da_rinominare) > 0L) {
    data.table::setnames(
      dt,
      old = da_rinominare,
      new = unname(.nomi_pipeline[da_rinominare])
    )
  }
  invisible(dt)
}

#' Sceglie la colonna da usare come chiave CCNL
#'
#' @param dt Un `data.table` già normalizzato.
#' @param ccnl_key Vettore di nomi ammessi, nell'ordine di preferenza.
#' @return Il nome della colonna scelta (character di lunghezza 1).
#' @keywords internal
#' @noRd
.select_ccnl_key <- function(dt, ccnl_key) {
  disponibili <- ccnl_key[ccnl_key %in% names(dt)]
  if (length(disponibili) == 0L) {
    stop(
      "Colonna `",
      paste(ccnl_key, collapse = "`, `"),
      "` assente da `dt`: impossibile costruire `ccnl_key`.",
      call. = FALSE
    )
  }
  disponibili[1L]
}

#' Converte e verifica la data di riferimento
#'
#' @param as_of `NULL`, una `Date` o una stringa convertibile.
#' @param caller Nome della funzione chiamante per i messaggi di errore.
#' @return `NULL` oppure una `Date` di lunghezza 1.
#' @keywords internal
#' @noRd
.as_as_of <- function(as_of, caller = "prepare_rapporti") {
  if (is.null(as_of)) {
    return(NULL)
  }
  if (
    length(as_of) != 1L || !(inherits(as_of, "Date") || is.character(as_of))
  ) {
    stop(
      "`as_of` deve essere una singola data (Date o stringa) in ",
      caller,
      "().",
      call. = FALSE
    )
  }
  out <- tryCatch(as.Date(as_of), error = function(e) NA)
  if (is.na(out)) {
    stop(
      "`as_of` non \u00e8 una data valida in ",
      caller,
      "().",
      call. = FALSE
    )
  }
  as.Date(out)
}

#' Converte e verifica la finestra di analisi
#'
#' @param window `NULL` oppure un vettore di due `Date` (o stringhe
#'   convertibili) ordinate.
#' @param caller Nome della funzione chiamante per i messaggi di errore.
#' @return `NULL` oppure un vettore `Date` di lunghezza 2.
#' @keywords internal
#' @noRd
.as_window <- function(window, caller = "prepare_rapporti") {
  if (is.null(window)) {
    return(NULL)
  }
  if (
    length(window) != 2L || !(inherits(window, "Date") || is.character(window))
  ) {
    stop(
      "`window` deve essere un vettore di due date (Date o stringhe) in ",
      caller,
      "().",
      call. = FALSE
    )
  }
  out <- tryCatch(as.Date(window), error = function(e) as.Date(c(NA, NA)))
  if (anyNA(out)) {
    stop(
      "`window` contiene date non valide o mancanti in ",
      caller,
      "().",
      call. = FALSE
    )
  }
  if (out[1L] > out[2L]) {
    stop(
      "`window` deve essere ordinata: window[1] <= window[2] in ",
      caller,
      "().",
      call. = FALSE
    )
  }
  as.Date(out)
}

#' Data di riferimento di default: massimo non sentinella fra inizio e fine
#'
#' @param dt Un `data.table` con `inizio` e `fine` di classe `Date`.
#' @return Una `Date` di lunghezza 1.
#' @keywords internal
#' @noRd
.default_as_of <- function(dt) {
  inizio <- as.Date(dt[["inizio"]])
  fine <- as.Date(dt[["fine"]])
  ok_inizio <- !is.na(inizio) & inizio > .data_sentinella_min
  ok_fine <- !is.na(fine) &
    fine > .data_sentinella_min &
    fine < .data_sentinella_max
  candidate <- c(inizio[ok_inizio], fine[ok_fine])
  if (length(candidate) == 0L) {
    stop(
      "Impossibile determinare `as_of`: nessuna data valida in `inizio` o ",
      "`fine`. Specificare `as_of` esplicitamente.",
      call. = FALSE
    )
  }
  max(candidate)
}

#' Finestra di default: dal primo avviamento non sentinella ad as_of
#'
#' @param dt Un `data.table` già passato da `.clamp_dates()`.
#' @param as_of Data di riferimento.
#' @return Un vettore `Date` di lunghezza 2.
#' @keywords internal
#' @noRd
.default_window <- function(dt, as_of) {
  inizio <- as.Date(dt[["inizio"]])
  valido <- dt[["troncata_inizio"]] == 0L
  if (!any(valido)) {
    valido <- rep(TRUE, length(inizio))
  }
  if (length(inizio) == 0L) {
    stop(
      "Impossibile determinare `window`: `dt` non contiene righe. ",
      "Specificare `window` esplicitamente.",
      call. = FALSE
    )
  }
  c(min(inizio[valido]), as_of)
}

#' Riporta un valore alla classe data della colonna di destinazione
#'
#' @param value Valore `Date`.
#' @param template Colonna di destinazione (`Date` o `IDate`).
#' @return `value` come `IDate` se `template` è `IDate`, altrimenti `Date`.
#' @keywords internal
#' @noRd
.as_date_like <- function(value, template) {
  if (inherits(template, "IDate")) {
    return(data.table::as.IDate(value))
  }
  as.Date(value)
}

#' Risolve le sentinelle su inizio e fine
#'
#' Applica, per riferimento, le regole documentate in [prepare_rapporti()]:
#' `fine` mancante, `<= 1900-01-01` o `> as_of` diventa `as_of` con
#' `troncata = 1`; `inizio` mancante o `<= 1900-01-01` diventa
#' `2008-03-01` con `troncata_inizio = 1`; infine `fine < inizio` viene
#' riportata a `inizio`. Un flag `troncata` preesistente viene combinato in
#' OR con quello calcolato.
#'
#' @param dt Un `data.table` con `inizio` e `fine` di classe `Date`.
#' @param as_of Data di riferimento (`Date` di lunghezza 1).
#' @return Lista con i conteggi integer `n_sentinel_fine`,
#'   `n_sentinel_inizio` e `n_fine_lt_inizio`.
#' @keywords internal
#' @noRd
.clamp_dates <- function(dt, as_of) {
  inizio <- dt[["inizio"]]
  fine <- dt[["fine"]]

  # 3.1 fine -----
  sent_fine <- is.na(fine) | fine <= .data_sentinella_min | fine > as_of
  if ("troncata" %in% names(dt)) {
    troncata_old <- dt[["troncata"]]
    troncata_old <- !is.na(troncata_old) & as.integer(troncata_old) == 1L
  } else {
    troncata_old <- rep(FALSE, nrow(dt))
  }
  data.table::set(
    dt,
    j = "troncata",
    value = as.integer(troncata_old | sent_fine)
  )
  if (any(sent_fine)) {
    data.table::set(
      dt,
      i = which(sent_fine),
      j = "fine",
      value = .as_date_like(as_of, fine)
    )
  }

  # 3.2 inizio -----
  sent_inizio <- is.na(inizio) | inizio <= .data_sentinella_min
  data.table::set(dt, j = "troncata_inizio", value = as.integer(sent_inizio))
  if (any(sent_inizio)) {
    data.table::set(
      dt,
      i = which(sent_inizio),
      j = "inizio",
      value = .as_date_like(.data_avvio_cob, inizio)
    )
  }

  # 3.3 fine < inizio -----
  inizio <- dt[["inizio"]]
  fine <- dt[["fine"]]
  invertiti <- fine < inizio
  if (any(invertiti)) {
    idx <- which(invertiti)
    data.table::set(
      dt,
      i = idx,
      j = "fine",
      value = .as_date_like(as.Date(inizio[idx]), fine)
    )
  }

  list(
    n_sentinel_fine = as.integer(sum(sent_fine)),
    n_sentinel_inizio = as.integer(sum(sent_inizio)),
    n_fine_lt_inizio = as.integer(sum(invertiti))
  )
}

#' Converte in numeric le colonne indicate, se presenti, per riferimento
#'
#' @param dt Un `data.table`, modificato per riferimento.
#' @param cols Vettore character di colonne da convertire con
#'   `.as_numeric_quiet()`; le colonne assenti vengono ignorate.
#' @return Vettore integer con nome per ciascuna colonna di `cols`: numero
#'   di valori non mancanti diventati `NA` (0 se già numerica o assente).
#' @keywords internal
#' @noRd
.coerce_numeric_cols <- function(dt, cols) {
  out <- stats::setNames(integer(length(cols)), cols)
  for (col in cols) {
    if (!col %in% names(dt)) {
      next
    }
    conv <- .as_numeric_quiet(dt[[col]], nome = col)
    if (conv$convertito) {
      data.table::set(dt, j = col, value = conv$value)
    }
    out[[col]] <- conv$n_na
  }
  out
}

#' Aggiunge le colonne di periodo (anno, trimestre) dalla data di avviamento
#'
#' @param dt Un `data.table` con la colonna `inizio` di classe `Date`.
#' @return `dt` modificato per riferimento, invisibilmente.
#' @keywords internal
#' @noRd
.add_periodo <- function(dt) {
  inizio <- dt[["inizio"]]
  data.table::set(dt, j = "anno", value = .periodo(inizio, "anno"))
  data.table::set(dt, j = "trimestre", value = .periodo(inizio, "trimestre"))
  invisible(dt)
}
