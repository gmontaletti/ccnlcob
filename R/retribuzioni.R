# 1. Costanti e simboli -----

utils::globalVariables(c(
  "lr",
  "mediana_log10",
  "mad_log10",
  "fallback",
  "n_fb",
  "mediana_fb",
  "mad_fb",
  "i.n_fb",
  "i.mediana_fb",
  "i.mad_fb",
  "i.mediana_log10",
  "i.mad_log10",
  "m",
  "s",
  "n_valide",
  "flag_retribuzione",
  "retribuzione_pulita",
  "flag_fte",
  ".w",
  ".ok",
  "var_pct_reale",
  "indice_reale"
))

# Livelli di `flag_retribuzione`, nell'ordine di valutazione.
.flag_retribuzione_livelli <- c(
  "mancante",
  "zero",
  "sentinella",
  "fuori_range",
  "valida"
)

# Livelli di `flag_fte`, nell'ordine di documentazione.
.flag_fte_livelli <- c(
  "full_time",
  "riproporzionata",
  "ore_oltre_riferimento",
  "ore_mancanti",
  "non_valida",
  "orario_ignoto"
)

# 2. Pulizia della retribuzione -----

#' Segnala le retribuzioni non valide o implausibili
#'
#' Aggiunge per riferimento le colonne `flag_retribuzione` (character) e
#' `retribuzione_pulita` (numeric, uguale a `retribuzione` dove il flag è
#' `"valida"`, `NA` altrove). Nessuna riga viene eliminata: la copertura del
#' campo resta misurabile a valle con `n` e `copertura`.
#'
#' @param dt Un `data.table` di rapporti con la colonna `retribuzione` e,
#'   per `method = "mad"`, le colonne di `by` e `by_fallback` (prodotte da
#'   [prepare_rapporti()]). Viene modificato per riferimento.
#' @param min_valore Soglia assoluta bassa: i valori positivi `<= min_valore`
#'   sono segnaposto e ricevono il flag `"sentinella"`.
#' @param max_valore Soglia assoluta alta: i valori `>= max_valore` ricevono
#'   il flag `"sentinella"`.
#' @param sentinelle Vettore numerico di valori puntuali da trattare come
#'   sentinella anche se compresi fra `min_valore` e `max_valore`.
#' @param method Metodo per la finestra di plausibilità: `"mad"` (default,
#'   mediana più o meno `k` volte la deviazione assoluta mediana di
#'   `log10(retribuzione)` per cella `by`) oppure `"none"` (solo soglie
#'   assolute e sentinelle).
#' @param k Ampiezza della finestra in unità di MAD (per `method = "mad"`).
#' @param mad_min Pavimento della MAD in unità log10: la MAD della cella
#'   viene portata a `max(mad, mad_min)` prima di applicare la finestra.
#' @param by Colonne che definiscono le celle entro cui calcolare mediana e
#'   MAD.
#' @param by_fallback Sottoinsieme di `by` che definisce la cella di
#'   ripiego per le celle di `by` con meno di `min_n` valori validi; `NULL`
#'   disattiva il ripiego.
#' @param min_n Numero minimo di valori validi perché una cella usi le
#'   proprie statistiche.
#'
#' @details
#' Il campo `retribuzione` è la retribuzione annua lorda dichiarata dal
#' datore di lavoro all'avviamento del rapporto. È un campo a compilazione
#' disomogenea (testuale in origine, zero-padded nel file della pipeline: se
#' arriva come factor o character viene convertito come in
#' [prepare_rapporti()]). Le regole e i default derivano dalla diagnostica
#' condotta il 2026-09-09 su 32,2 milioni di rapporti della Lombardia
#' (`reference/ccnlcob/diagnostica_retribuzione.md`):
#' - i valori in `(0, 100]` sono il 4,5-11% dei non mancanti e sono
#'   segnaposto (1, 50, 100); da qui `min_valore = 100`;
#' - i "nove ripetuti" (999, 9 999, 99 999, 999 999, ...) sono rari
#'   (0,03%) ma sistematici; quelli da 999 999 in su ricadono sotto
#'   `max_valore = 1e6`, gli altri stanno in `sentinelle`. Nessun annuo lordo
#'   plausibile supera il milione di euro nei dati COB lombardi;
#' - le celle `anno x macro_tipologia x prior` separano tempo pieno e
#'   parziale, altrimenti la MAD è dominata dai part-time; nelle celle
#'   omogenee la MAD grezza in log10 scende a 0,04-0,10 e con `k = 4`
#'   segnalerebbe un quarto dei tempo determinati a tempo pieno: il
#'   pavimento `mad_min = 0.15` (finestra minima x/÷ 4 attorno alla mediana)
#'   stabilizza la regola, che con `k = 4` segnala il 9,7% dei valori validi
#'   (4,5% del tempo indeterminato a tempo pieno) e sposta la mediana di meno
#'   di 500 euro;
#' - `min_n = 200` evita MAD instabili nelle macro-tipologie piccole
#'   ripiegando sulla cella `anno x prior`;
#' - la copertura del campo è inutilizzabile per il 2009-2013, fra il 51% e
#'   il 61% nel 2014-2019 e sopra il 96% dal 2020: le serie per CCNL vanno
#'   lette con la copertura a fianco e sono affidabili dal 2020.
#'
#' I flag sono assegnati in quest'ordine, il primo che si applica vince:
#' `"mancante"` (`NA`), `"zero"` (`== 0`), `"sentinella"` (`<= min_valore`,
#' `>= max_valore` o in `sentinelle`), `"fuori_range"` (fuori dalla finestra
#' robusta), `"valida"`. Con `method = "mad"`, sui valori rimasti validi dopo
#' lo stadio delle sentinelle, per ogni cella di `by` si calcolano mediana
#' `m` e MAD `s = max(mad, mad_min)` di `log10(retribuzione)`
#' ([stats::mad()] con costante 1,4826) e si segnala `fuori_range` quando
#' `abs(log10(x) - m) > k * s`. Le celle con meno di `min_n` valori validi
#' usano le statistiche della cella `by_fallback` corrispondente; se anche
#' questa è sotto `min_n` nessun flag di finestra viene applicato alle sue
#' righe. Per le macro-tipologie a distribuzione degenere (collaborazioni,
#' tirocini, altro, domestico part-time) la regola non filtra quasi nulla e la
#' mediana non è interpretabile come annuo: vanno escluse o mascherate nelle
#' stime.
#'
#' Nessuna riga viene rimossa e `retribuzione` non viene alterata (salvo la
#' conversione da factor o character a numeric).
#'
#' @return `dt`, restituito invisibilmente, con le colonne
#'   `flag_retribuzione` e `retribuzione_pulita` aggiunte per riferimento.
#'   L'attributo `ccnlcob_retribuzione` è una lista con `params` (argomenti
#'   usati), `riepilogo` (`data.table` con `flag_retribuzione`, `n`, `quota`
#'   per ciascun livello) e `celle` (`data.table` con le colonne di `by`,
#'   `n` valori validi della cella, `mediana_log10` e `mad_log10`
#'   effettivamente usate per la finestra, dopo ripiego e pavimento, e
#'   `fallback` logico; vuoto con `method = "none"`). Viene emesso un
#'   `message()` con la quota di valori validi.
#' @family retribuzioni
#' @seealso [normalize_fte()] per la normalizzazione a tempo pieno.
#' @export
#' @examples
#' dt <- prepare_rapporti(cob_esempio)
#' clean_retribuzione(dt, min_n = 30)
#' attr(dt, "ccnlcob_retribuzione")$riepilogo
#' dt[, .(copertura = mean(flag_retribuzione == "valida")), by = anno]
#'
#' # solo soglie assolute e sentinelle
#' clean_retribuzione(dt, method = "none")
clean_retribuzione <- function(
  dt,
  min_valore = 100,
  max_valore = 1e6,
  sentinelle = c(999, 9999, 99999),
  method = c("mad", "none"),
  k = 4,
  mad_min = 0.15,
  by = c("anno", "macro_tipologia", "prior"),
  by_fallback = c("anno", "prior"),
  min_n = 200L
) {
  # 2.1 Controlli -----
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare clean_retribuzione().",
      call. = FALSE
    )
  }
  if (!"retribuzione" %in% names(dt)) {
    stop(
      "Colonna `retribuzione` assente da `dt`. ",
      "Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  method <- match.arg(method)
  .check_scalar(min_valore, "min_valore", min = 0)
  .check_scalar(max_valore, "max_valore", min = 0)
  if (min_valore >= max_valore) {
    stop("`min_valore` deve essere minore di `max_valore`.", call. = FALSE)
  }
  if (!is.numeric(sentinelle) && !is.null(sentinelle)) {
    stop("`sentinelle` deve essere NULL o un vettore numerico.", call. = FALSE)
  }
  sentinelle <- sentinelle[!is.na(sentinelle)]
  if (method == "mad") {
    .check_scalar(k, "k", min = 0, strict = TRUE)
    .check_scalar(mad_min, "mad_min", min = 0)
    .check_scalar(min_n, "min_n", min = 0)
    if (!is.character(by) || length(by) == 0L || anyNA(by)) {
      stop("`by` deve essere un vettore character non vuoto.", call. = FALSE)
    }
    by <- unique(by)
    if (!is.null(by_fallback)) {
      if (!is.character(by_fallback) || anyNA(by_fallback)) {
        stop(
          "`by_fallback` deve essere NULL o un vettore character.",
          call. = FALSE
        )
      }
      by_fallback <- unique(by_fallback)
      if (length(by_fallback) == 0L) {
        by_fallback <- NULL
      } else if (!all(by_fallback %in% by)) {
        stop(
          "`by_fallback` deve essere un sottoinsieme di `by`.",
          call. = FALSE
        )
      }
    }
    mancanti <- setdiff(c(by, by_fallback), names(dt))
    if (length(mancanti) > 0L) {
      stop(
        "Colonne di `by` assenti da `dt`: ",
        paste(mancanti, collapse = ", "),
        ". Applicare prima prepare_rapporti().",
        call. = FALSE
      )
    }
  }

  # 2.2 Conversione e stadio delle sentinelle -----
  .coerce_numeric_cols(dt, "retribuzione")
  x <- dt[["retribuzione"]]
  flag <- data.table::fcase(
    is.na(x)                                              ,
    "mancante"                                            ,
    x == 0                                                ,
    "zero"                                                ,
    x <= min_valore | x >= max_valore | x %in% sentinelle ,
    "sentinella"                                          ,
    default = "valida"
  )

  # 2.3 Finestra robusta per cella -----
  celle <- NULL
  if (method == "mad") {
    idx <- which(flag == "valida")
    work <- dt[idx, by, with = FALSE]
    data.table::set(work, j = "lr", value = log10(x[idx]))
    celle <- work[,
      list(
        n = .N,
        mediana_log10 = stats::median(lr),
        mad_log10 = stats::mad(lr)
      ),
      by = by
    ]
    celle[, fallback := n < min_n]
    if (!is.null(by_fallback)) {
      fb <- work[,
        list(
          n_fb = .N,
          mediana_fb = stats::median(lr),
          mad_fb = stats::mad(lr)
        ),
        by = by_fallback
      ]
      celle[
        fb,
        on = by_fallback,
        `:=`(n_fb = i.n_fb, mediana_fb = i.mediana_fb, mad_fb = i.mad_fb)
      ]
      usa_fb <- celle[["fallback"]] & celle[["n_fb"]] >= min_n
      celle[usa_fb, `:=`(mediana_log10 = mediana_fb, mad_log10 = mad_fb)]
      senza <- celle[["fallback"]] & !usa_fb
      celle[senza, `:=`(mediana_log10 = NA_real_, mad_log10 = NA_real_)]
      celle[, c("n_fb", "mediana_fb", "mad_fb") := NULL]
    } else {
      celle[
        fallback == TRUE,
        `:=`(mediana_log10 = NA_real_, mad_log10 = NA_real_)
      ]
    }
    celle[, mad_log10 := pmax(mad_log10, mad_min)]
    if (nrow(work) > 0L) {
      work[celle, on = by, `:=`(m = i.mediana_log10, s = i.mad_log10)]
      fuori <- !is.na(work[["m"]]) &
        abs(work[["lr"]] - work[["m"]]) > k * work[["s"]]
      flag[idx[fuori]] <- "fuori_range"
    }
    data.table::setorderv(celle, by, na.last = TRUE)
    data.table::setcolorder(
      celle,
      c(by, "n", "mediana_log10", "mad_log10", "fallback")
    )
  }

  # 2.4 Colonne, riepilogo e attributo -----
  data.table::set(dt, j = "flag_retribuzione", value = flag)
  data.table::set(
    dt,
    j = "retribuzione_pulita",
    value = data.table::fifelse(flag == "valida", as.numeric(x), NA_real_)
  )
  riepilogo <- .riepilogo_flag(
    flag,
    .flag_retribuzione_livelli,
    "flag_retribuzione"
  )
  data.table::setattr(
    dt,
    "ccnlcob_retribuzione",
    list(
      params = list(
        min_valore = min_valore,
        max_valore = max_valore,
        sentinelle = sentinelle,
        method = method,
        k = if (method == "mad") k else NULL,
        mad_min = if (method == "mad") mad_min else NULL,
        by = if (method == "mad") by else NULL,
        by_fallback = if (method == "mad") by_fallback else NULL,
        min_n = if (method == "mad") min_n else NULL
      ),
      riepilogo = riepilogo,
      celle = celle
    )
  )
  n_valide <- sum(flag == "valida")
  message(sprintf(
    "clean_retribuzione(): %d retribuzioni valide su %d (%.1f%%).",
    n_valide,
    length(flag),
    100 * n_valide / max(length(flag), 1L)
  ))
  invisible(dt[])
}

# 3. Normalizzazione a tempo pieno -----

#' Normalizza la retribuzione alle ore di riferimento
#'
#' Aggiunge per riferimento `ore_riferimento` (ore settimanali di riferimento
#' della riga), `retribuzione_fte` (retribuzione riportata alle ore di
#' riferimento) e `flag_fte` (esito della normalizzazione).
#'
#' @param dt Un `data.table` di rapporti con le colonne `prior`, `ore` e
#'   `value_col` (di norma `retribuzione_pulita` da [clean_retribuzione()]).
#'   Viene modificato per riferimento.
#' @param ore_riferimento Ore settimanali di riferimento a tempo pieno usate
#'   per tutte le righe non coperte da `ore_riferimento_tabella`.
#' @param ore_riferimento_tabella `data.table` opzionale con una colonna
#'   chiave (`ccnl_key` oppure `macro_tipologia`, rilevata automaticamente)
#'   e la colonna `ore_riferimento`; le righe di `dt` non abbinate usano il
#'   valore scalare.
#' @param ore_min Ore minime perché un part-time venga riproporzionato; sotto
#'   questa soglia (o con `ore` mancante o pari a 0) il flag è
#'   `"ore_mancanti"`.
#' @param value_col Colonna da normalizzare; `"retribuzione"` è ammessa in
#'   modo esplicito per saltare la pulizia.
#'
#' @details
#' La diagnostica del 2026-09-09
#' (`reference/ccnlcob/diagnostica_retribuzione.md`, §5-6) mostra che:
#' - la retribuzione dichiarata per il tempo parziale è già proporzionata alle
#'   ore (il rapporto mediano part-time/full-time segue `ore/40` in tutte le
#'   fasce orarie), quindi la normalizzazione moltiplica per
#'   `ore_riferimento / ore`;
#' - `ore` è compilato quasi solo per il tempo parziale (mancante nel 95%
#'   dei tempo pieno e nel 30% dei part-time); fra i tempo pieno con `ore`
#'   compilato la moda e la mediana sono 40 in tutte le macro-tipologie salvo
#'   il lavoro domestico (54): `ore_riferimento = 40` è il default
#'   empiricamente giustificato e la tabella consente l'eccezione
#'   (`macro_tipologia = "Domestico"`, `ore_riferimento = 54`) o le ore
#'   contrattuali note per `ccnl_key` (36-39 ore);
#' - `ore == 0` è incompatibile con un rapporto attivo e viene trattato come
#'   mancante; per i part-time senza ore utilizzabili (32% delle righe) non
#'   esiste un valore di default difendibile (mediana 20, ma p10 = 5 e
#'   p90 = 30): `retribuzione_fte` resta `NA`;
#' - `ore_min = 1` non esclude nulla: l'amplificazione dell'errore per ore
#'   molto basse è reale ma marginale in numerosità; l'argomento è esposto per
#'   chi vuole escluderle.
#'
#' `flag_fte` e `retribuzione_fte` sono assegnati così, nell'ordine:
#' - `"non_valida"`: `value_col` mancante, `retribuzione_fte = NA`;
#' - `"full_time"`: `prior == 1`, valore invariato;
#' - `"ore_mancanti"`: `prior == 0` e `ore` mancante, 0 o `< ore_min`,
#'   `retribuzione_fte = NA`;
#' - `"ore_oltre_riferimento"`: `prior == 0` e `ore >= ore_riferimento`,
#'   valore invariato;
#' - `"riproporzionata"`: `prior == 0` e `ore_min <= ore < ore_riferimento`,
#'   `retribuzione_fte = valore * ore_riferimento / ore`;
#' - `"orario_ignoto"`: `prior` diverso da 0 e 1, `retribuzione_fte = NA`.
#'
#' Se `ore` arriva come factor o character viene convertita come in
#' [prepare_rapporti()]; i valori della colonna non vengono altrimenti
#' alterati. Applicare [clean_retribuzione()] prima di questa funzione: la
#' regola MAD è tarata sui valori grezzi per `prior`.
#'
#' @return `dt`, restituito invisibilmente, con le colonne `ore_riferimento`
#'   (numeric), `retribuzione_fte` (numeric) e `flag_fte` (character)
#'   aggiunte per riferimento. L'attributo `ccnlcob_fte` è una lista con
#'   `params` (`ore_riferimento`, `ore_min`, `value_col`, `tabella_key`) e
#'   `riepilogo` (`data.table` con `flag_fte`, `n`, `quota`).
#' @family retribuzioni
#' @seealso [clean_retribuzione()] per la pulizia preliminare.
#' @export
#' @examples
#' dt <- prepare_rapporti(cob_esempio)
#' clean_retribuzione(dt, min_n = 30)
#' normalize_fte(dt)
#' attr(dt, "ccnlcob_fte")$riepilogo
#'
#' # ore di riferimento per macro-tipologia
#' tabella <- data.table::data.table(
#'   macro_tipologia = "Domestico",
#'   ore_riferimento = 54
#' )
#' normalize_fte(dt, ore_riferimento_tabella = tabella)
#' dt[, .N, by = .(macro_tipologia, ore_riferimento)]
normalize_fte <- function(
  dt,
  ore_riferimento = 40,
  ore_riferimento_tabella = NULL,
  ore_min = 1,
  value_col = "retribuzione_pulita"
) {
  # 3.1 Controlli -----
  if (!data.table::is.data.table(dt)) {
    stop(
      "`dt` deve essere un data.table: convertire con data.table::setDT(dt) ",
      "prima di chiamare normalize_fte().",
      call. = FALSE
    )
  }
  if (!is.character(value_col) || length(value_col) != 1L || is.na(value_col)) {
    stop("`value_col` deve essere una singola stringa.", call. = FALSE)
  }
  mancanti <- setdiff(c("prior", "ore"), names(dt))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne mancanti in `dt`: ",
      paste(mancanti, collapse = ", "),
      ". Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  if (!value_col %in% names(dt)) {
    suggerimento <- if (value_col == "retribuzione_pulita") {
      " Applicare prima clean_retribuzione()."
    } else {
      ""
    }
    stop(
      "Colonna `",
      value_col,
      "` assente da `dt`.",
      suggerimento,
      call. = FALSE
    )
  }
  .check_scalar(ore_riferimento, "ore_riferimento", min = 0, strict = TRUE)
  .check_scalar(ore_min, "ore_min", min = 0)
  tabella_key <- NULL
  if (!is.null(ore_riferimento_tabella)) {
    tabella_key <- .check_ore_tabella(ore_riferimento_tabella, dt)
  }

  # 3.2 Conversione e ore di riferimento per riga -----
  .coerce_numeric_cols(dt, c("ore", value_col))
  n <- nrow(dt)
  ore <- dt[["ore"]]
  ore[!is.na(ore) & ore == 0] <- NA_real_
  prior <- dt[["prior"]]
  valore <- as.numeric(dt[[value_col]])
  ore_rif <- rep(as.numeric(ore_riferimento), n)
  if (!is.null(tabella_key)) {
    pos <- match(
      as.character(dt[[tabella_key]]),
      as.character(ore_riferimento_tabella[[tabella_key]])
    )
    abbinate <- !is.na(pos)
    ore_rif[abbinate] <- as.numeric(
      ore_riferimento_tabella[["ore_riferimento"]][pos[abbinate]]
    )
  }

  # 3.3 Flag e valore normalizzato -----
  pt <- !is.na(prior) & prior == 0
  ft <- !is.na(prior) & prior == 1
  ore_ok <- !is.na(ore) & ore >= ore_min
  flag <- data.table::fcase(
    is.na(valore)           ,
    "non_valida"            ,
    ft                      ,
    "full_time"             ,
    pt & !ore_ok            ,
    "ore_mancanti"          ,
    pt & ore >= ore_rif     ,
    "ore_oltre_riferimento" ,
    pt                      ,
    "riproporzionata"       ,
    default = "orario_ignoto"
  )
  fte <- data.table::fcase(
    flag %in% c("full_time", "ore_oltre_riferimento") ,
    valore                                            ,
    flag == "riproporzionata"                         ,
    valore * ore_rif / ore                            ,
    default = NA_real_
  )
  data.table::set(dt, j = "ore_riferimento", value = ore_rif)
  data.table::set(dt, j = "retribuzione_fte", value = fte)
  data.table::set(dt, j = "flag_fte", value = flag)
  data.table::setattr(
    dt,
    "ccnlcob_fte",
    list(
      params = list(
        ore_riferimento = ore_riferimento,
        ore_min = ore_min,
        value_col = value_col,
        tabella_key = tabella_key
      ),
      riepilogo = .riepilogo_flag(flag, .flag_fte_livelli, "flag_fte")
    )
  )
  invisible(dt[])
}

# 4. Mediana per coorte di avviamento -----

#' Calcola la retribuzione mediana per CCNL e periodo di avviamento
#'
#' Aggrega una colonna di retribuzione (di norma `retribuzione_fte`) per
#' `ccnl_key` e periodo di avviamento, con quantili ponderati per giornate,
#' numerosità, copertura, variazione sul periodo precedente e indice a base
#' fissa. L'input non viene modificato.
#'
#' @param dt Un `data.table` di rapporti già passato da
#'   [prepare_rapporti()], [clean_retribuzione()] e [normalize_fte()], con le
#'   colonne `ccnl_key`, `periodo`, `value_col`, `giornate` (se
#'   `weights = "giornate"`) e `avviato` (se `solo_avviati = TRUE`).
#' @param periodo Periodo di avviamento: `"anno"` (default) o `"trimestre"`.
#' @param by Colonne aggiuntive di raggruppamento; `NULL` per il solo CCNL.
#' @param ccnl `NULL` per tutte le chiavi, altrimenti vettore character delle
#'   chiavi `ccnl_key` da conservare in uscita (`NA` incluso conserva i non
#'   classificati); il filtro è applicato dopo il calcolo.
#' @param weights Pesi dei quantili: `"giornate"` (default) o `"none"`.
#' @param value_col Colonna di retribuzione da aggregare.
#' @param probs Quantili da riportare, in `[0, 1]`; il valore 0.5 viene
#'   sempre incluso.
#' @param min_n Numero minimo di valori validi nella cella sotto il quale i
#'   quantili vengono mascherati con `NA` (la riga resta, con `n`,
#'   `n_valide` e `copertura`).
#' @param solo_avviati Se `TRUE` (default) considera solo i rapporti con
#'   `avviato == TRUE`.
#'
#' @details
#' La retribuzione è dichiarata all'avviamento del rapporto e non viene
#' aggiornata: la coorte di avviamento (`anno` o `trimestre` di `inizio`) è
#' quindi la dimensione temporale corretta. I rapporti avviati prima della
#' finestra di analisi appartengono a coorti più vecchie sopravvissute fino
#' alla finestra e risentono della selezione per sopravvivenza (restano in
#' vita i rapporti più stabili, in genere meglio retribuiti): con
#' `solo_avviati = TRUE` vengono esclusi.
#'
#' I quantili sono calcolati con la mediana ponderata a gradini (vedi
#' `.wquantile()`): con `weights = "giornate"` ogni rapporto pesa per i
#' giorni-contratto nella finestra, così che un contratto di un anno conti
#' più di uno di una settimana, in modo coerente con la mediana ponderata per
#' durata di `longworkR`; con pesi uniformi il risultato coincide con
#' [stats::median()]. `n` conta le righe della cella, `n_valide` quelle con
#' valore non mancante, `copertura = n_valide / n`, `giornate` è la somma
#' delle giornate delle righe valide. Le celle con `n_valide < min_n` sono
#' mascherate, non eliminate.
#'
#' `var_pct` è la variazione percentuale della mediana rispetto al periodo
#' precedente entro (`by`, `ccnl_key`), `NA` per il primo periodo o quando
#' uno dei due è mascherato; `indice` è la mediana rapportata alla prima
#' mediana non mascherata della stessa serie, per 100. Entrambe sono
#' calcolate sui periodi presenti in tabella: un periodo assente non produce
#' un salto vuoto.
#'
#' Sui dati reali la copertura del campo è affidabile solo dal 2020 (oltre il
#' 96% di valori validi), utilizzabile con `copertura` a fianco nel
#' 2014-2019 e inutilizzabile prima (vedi [clean_retribuzione()]).
#'
#' @return Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`),
#'   inclusa la classe `"Non classificati"` per `ccnl_key` mancante, con le
#'   colonne di `by`, `periodo`, `ccnl_key`, `classe`, `n`, `n_valide`,
#'   `copertura`, `giornate`, una colonna per quantile (`p25`, `mediana`,
#'   `p75` con i default; `p<int>` per gli altri), `var_pct` e `indice`;
#'   ordinato per `by`, `ccnl_key` (`NA` in coda) e periodo. L'attributo
#'   `ccnlcob_retribuzione_mediana` conserva i parametri.
#' @family retribuzioni
#' @seealso [deflate_retribuzione()] per i valori reali.
#' @export
#' @examples
#' dt <- prepare_rapporti(cob_esempio)
#' clean_retribuzione(dt, min_n = 30)
#' normalize_fte(dt)
#' ret <- median_retribuzione(dt, periodo = "anno", min_n = 10)
#' ret[ccnl_key == "A011"]
#'
#' # per orario, senza pesi
#' median_retribuzione(dt, by = "orario", weights = "none", min_n = 10)[1:6]
median_retribuzione <- function(
  dt,
  periodo = c("anno", "trimestre"),
  by = NULL,
  ccnl = NULL,
  weights = c("giornate", "none"),
  value_col = "retribuzione_fte",
  probs = c(0.25, 0.5, 0.75),
  min_n = 30L,
  solo_avviati = TRUE
) {
  # 4.1 Controlli -----
  if (!is.data.frame(dt)) {
    stop("`dt` deve essere un data.table di rapporti.", call. = FALSE)
  }
  periodo <- match.arg(periodo)
  weights <- match.arg(weights)
  if (!is.character(value_col) || length(value_col) != 1L || is.na(value_col)) {
    stop("`value_col` deve essere una singola stringa.", call. = FALSE)
  }
  if (!"ccnl_key" %in% names(dt)) {
    stop(
      "Colonna `ccnl_key` assente da `dt`. Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  grp <- .check_grouping(dt, by = by, periodo = periodo)
  by <- grp$by
  if (!value_col %in% names(dt)) {
    suggerimento <- if (value_col == "retribuzione_fte") {
      " Applicare prima clean_retribuzione() e normalize_fte()."
    } else {
      ""
    }
    stop(
      "Colonna `",
      value_col,
      "` assente da `dt`.",
      suggerimento,
      call. = FALSE
    )
  }
  if (!is.numeric(dt[[value_col]])) {
    stop("La colonna `", value_col, "` deve essere numerica.", call. = FALSE)
  }
  if (weights == "giornate" && !"giornate" %in% names(dt)) {
    stop(
      "Colonna `giornate` assente da `dt`: richiesta con ",
      "`weights = \"giornate\"`. Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  if (
    !is.logical(solo_avviati) ||
      length(solo_avviati) != 1L ||
      is.na(solo_avviati)
  ) {
    stop("`solo_avviati` deve essere TRUE o FALSE.", call. = FALSE)
  }
  if (solo_avviati && !"avviato" %in% names(dt)) {
    stop(
      "Colonna `avviato` assente da `dt`: richiesta con ",
      "`solo_avviati = TRUE`. Applicare prima prepare_rapporti().",
      call. = FALSE
    )
  }
  if (
    !is.numeric(probs) ||
      length(probs) == 0L ||
      anyNA(probs) ||
      any(probs < 0 | probs > 1)
  ) {
    stop("`probs` deve essere un vettore numerico in [0, 1].", call. = FALSE)
  }
  probs <- sort(unique(c(probs, 0.5)))
  qnames <- .nomi_quantili(probs)
  .check_scalar(min_n, "min_n", min = 0)
  if (!is.null(ccnl)) {
    if (!is.character(ccnl) && !all(is.na(ccnl))) {
      stop("`ccnl` deve essere NULL o un vettore character.", call. = FALSE)
    }
    ccnl <- unique(as.character(ccnl))
    sconosciute <- ccnl[!ccnl %in% unique(dt[["ccnl_key"]])]
    if (length(sconosciute) > 0L) {
      warning(
        "Chiavi `ccnl` assenti da `dt`: ",
        paste(sconosciute, collapse = ", "),
        ".",
        call. = FALSE
      )
    }
  }

  # 4.2 Tabella di lavoro -----
  grp_cols <- c(by, periodo, "ccnl_key")
  cols <- unique(c(
    grp_cols,
    value_col,
    if ("giornate" %in% names(dt)) "giornate",
    if (solo_avviati) "avviato"
  ))
  work <- .project_cols(dt, cols)
  if (solo_avviati) {
    work <- work[work[["avviato"]] %in% TRUE]
  }
  if (!"giornate" %in% names(work)) {
    data.table::set(work, j = "giornate", value = rep(NA_real_, nrow(work)))
  }
  peso <- if (weights == "giornate") {
    as.numeric(work[["giornate"]])
  } else {
    rep(1, nrow(work))
  }
  data.table::set(work, j = ".w", value = peso)

  # 4.3 Aggregazione per cella -----
  agg <- work[,
    {
      v <- .SD[[1L]]
      g <- as.numeric(.SD[[2L]])
      w <- .SD[[3L]]
      ok <- !is.na(v)
      c(
        list(
          n = .N,
          n_valide = sum(ok),
          giornate = sum(g[ok], na.rm = TRUE)
        ),
        stats::setNames(as.list(.wquantile(v[ok], w[ok], probs)), qnames)
      )
    },
    by = grp_cols,
    .SDcols = c(value_col, "giornate", ".w")
  ]
  data.table::set(
    agg,
    j = "copertura",
    value = .ratio(agg[["n_valide"]], agg[["n"]])
  )
  mascherate <- which(agg[["n_valide"]] < min_n)
  if (length(mascherate) > 0L) {
    for (q in qnames) {
      data.table::set(agg, i = mascherate, j = q, value = NA_real_)
    }
  }
  data.table::set(
    agg,
    j = "classe",
    value = data.table::fifelse(
      is.na(agg[["ccnl_key"]]),
      .classe_non_classificati,
      .classe_ccnl
    )
  )

  # 4.4 Evoluzione, filtro, ordinamento -----
  .add_evoluzione(
    agg,
    grp = c(by, "ccnl_key"),
    periodo_col = periodo,
    value = "mediana",
    var_col = "var_pct",
    indice_col = "indice"
  )
  if (!is.null(ccnl)) {
    agg <- agg[ccnl_key %in% ccnl]
  }
  data.table::setcolorder(
    agg,
    c(
      by,
      periodo,
      "ccnl_key",
      "classe",
      "n",
      "n_valide",
      "copertura",
      "giornate",
      qnames,
      "var_pct",
      "indice"
    )
  )
  data.table::setorderv(agg, c(by, "ccnl_key", periodo), na.last = TRUE)
  data.table::setattr(
    agg,
    "ccnlcob_retribuzione_mediana",
    list(
      params = list(
        periodo = periodo,
        by = by,
        ccnl = ccnl,
        weights = weights,
        value_col = value_col,
        probs = probs,
        min_n = min_n,
        solo_avviati = solo_avviati
      )
    )
  )
  agg[]
}

# 5. Deflazione -----

#' Deflaziona le colonne di retribuzione con un indice esterno
#'
#' Aggiunge, in una copia di `dt`, una colonna `<col>_reale` per ciascuna
#' colonna di `value_cols`, calcolata come
#' `valore * indice[base] / indice[periodo]`. Il pacchetto non scarica
#' indici: `indice` è fornito dall'utente (per esempio l'IPCA via
#' `istatlab`).
#'
#' @param dt Un `data.table` di risultati, di norma prodotto da
#'   [median_retribuzione()], con la colonna `periodo_col` e le colonne
#'   `value_cols`.
#' @param indice `data.table` con una colonna di periodo (chiamata come
#'   `periodo_col` oppure `periodo`) e la colonna numerica `indice` (> 0),
#'   senza periodi duplicati. Tutti i periodi di `dt` devono essere presenti.
#' @param base Periodo base, presente in `indice`; `NULL` (default) usa
#'   l'ultimo periodo presente in `dt`, così che i valori reali siano
#'   espressi ai prezzi del periodo più recente.
#' @param value_cols Colonne da deflazionare.
#' @param periodo_col Nome della colonna di periodo in `dt`.
#'
#' @details
#' Nel periodo base `valore_reale == valore`. Se fra le colonne prodotte
#' esiste `mediana_reale`, vengono aggiunte anche `var_pct_reale` e
#' `indice_reale`, ricalcolate come in [median_retribuzione()] entro le
#' serie (`by`, `ccnl_key`) lette dall'attributo
#' `ccnlcob_retribuzione_mediana` o, in sua assenza, dalle colonne che
#' precedono `ccnl_key` (tutta la tabella come una sola serie se `ccnl_key`
#' manca). Nessuna colonna esistente viene sovrascritta.
#'
#' @return Un nuovo `data.table` con le colonne di `dt`, le colonne
#'   `<col>_reale` e, se pertinenti, `var_pct_reale` e `indice_reale`;
#'   l'attributo `ccnlcob_deflazione` riporta `base`, `periodo_col` e
#'   `value_cols`. L'input non viene modificato.
#' @family retribuzioni
#' @seealso [median_retribuzione()] per la tabella di partenza.
#' @export
#' @examples
#' dt <- prepare_rapporti(cob_esempio)
#' clean_retribuzione(dt, min_n = 30)
#' normalize_fte(dt)
#' ret <- median_retribuzione(dt, periodo = "anno", min_n = 10)
#' ipca <- data.table::data.table(
#'   anno = 2019:2024,
#'   indice = c(100, 99.8, 101.7, 110.5, 116.9, 118.2)
#' )
#' reale <- deflate_retribuzione(ret, indice = ipca, base = 2024)
#' reale[ccnl_key == "A011", .(anno, mediana, mediana_reale, indice_reale)]
deflate_retribuzione <- function(
  dt,
  indice,
  base = NULL,
  value_cols = c("p25", "mediana", "p75"),
  periodo_col = "anno"
) {
  # 5.1 Controlli -----
  if (!is.data.frame(dt)) {
    stop("`dt` deve essere un data.table di risultati.", call. = FALSE)
  }
  if (
    !is.character(periodo_col) ||
      length(periodo_col) != 1L ||
      is.na(periodo_col)
  ) {
    stop("`periodo_col` deve essere una singola stringa.", call. = FALSE)
  }
  if (!periodo_col %in% names(dt)) {
    stop("Colonna `", periodo_col, "` assente da `dt`.", call. = FALSE)
  }
  if (
    !is.character(value_cols) || length(value_cols) == 0L || anyNA(value_cols)
  ) {
    stop(
      "`value_cols` deve essere un vettore character non vuoto.",
      call. = FALSE
    )
  }
  value_cols <- unique(value_cols)
  mancanti <- setdiff(value_cols, names(dt))
  if (length(mancanti) > 0L) {
    stop(
      "Colonne di `value_cols` assenti da `dt`: ",
      paste(mancanti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  non_num <- value_cols[
    !vapply(value_cols, function(v) is.numeric(dt[[v]]), logical(1))
  ]
  if (length(non_num) > 0L) {
    stop(
      "Colonne di `value_cols` non numeriche: ",
      paste(non_num, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  reali <- paste0(value_cols, "_reale")
  gia <- intersect(c(reali, "var_pct_reale", "indice_reale"), names(dt))
  if (length(gia) > 0L) {
    stop(
      "Colonne gi\u00e0 presenti in `dt`: ",
      paste(gia, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (!is.data.frame(indice) || !"indice" %in% names(indice)) {
    stop(
      "`indice` deve essere un data.table con una colonna di periodo e la ",
      "colonna `indice`.",
      call. = FALSE
    )
  }
  ind_periodo_col <- if (periodo_col %in% names(indice)) {
    periodo_col
  } else if ("periodo" %in% names(indice)) {
    "periodo"
  } else {
    stop(
      "`indice` deve contenere la colonna `",
      periodo_col,
      "` oppure `periodo`.",
      call. = FALSE
    )
  }
  ind_periodi <- indice[[ind_periodo_col]]
  ind_valori <- indice[["indice"]]
  if (anyNA(ind_periodi) || anyDuplicated(ind_periodi) > 0L) {
    stop("`indice` contiene periodi mancanti o duplicati.", call. = FALSE)
  }
  if (!is.numeric(ind_valori) || anyNA(ind_valori) || any(ind_valori <= 0)) {
    stop(
      "La colonna `indice` deve essere numerica, positiva e senza NA.",
      call. = FALSE
    )
  }
  periodi_dt <- dt[[periodo_col]]
  if (is.null(base)) {
    base <- max(periodi_dt, na.rm = TRUE)
  }
  if (length(base) != 1L || is.na(base)) {
    stop("`base` deve essere un singolo periodo non mancante.", call. = FALSE)
  }
  pos_base <- match(as.character(base), as.character(ind_periodi))
  if (is.na(pos_base)) {
    stop(
      "Il periodo `base` (",
      base,
      ") non \u00e8 presente in `indice`.",
      call. = FALSE
    )
  }
  pos <- match(as.character(periodi_dt), as.character(ind_periodi))
  assenti <- unique(periodi_dt[is.na(pos) & !is.na(periodi_dt)])
  if (length(assenti) > 0L) {
    stop(
      "Periodi di `dt` assenti da `indice`: ",
      paste(assenti, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  # 5.2 Valori reali -----
  out <- data.table::as.data.table(data.table::copy(dt))
  fattore <- ind_valori[pos_base] / ind_valori[pos]
  for (i in seq_along(value_cols)) {
    data.table::set(
      out,
      j = reali[i],
      value = as.numeric(out[[value_cols[i]]]) * fattore
    )
  }

  # 5.3 Evoluzione sui valori reali -----
  if ("mediana_reale" %in% reali) {
    grp <- .serie_groups(out, periodo_col)
    .add_evoluzione(
      out,
      grp = grp,
      periodo_col = periodo_col,
      value = "mediana_reale",
      var_col = "var_pct_reale",
      indice_col = "indice_reale"
    )
  }
  data.table::setattr(
    out,
    "ccnlcob_deflazione",
    list(base = base, periodo_col = periodo_col, value_cols = value_cols)
  )
  out[]
}

# 6. Helper interni -----

#' Verifica uno scalare numerico
#'
#' @param x Oggetto da verificare.
#' @param nome Nome dell'argomento per il messaggio di errore.
#' @param min Valore minimo ammesso.
#' @param strict Se `TRUE` il minimo è escluso.
#' @return `invisible(TRUE)`; errore altrimenti.
#' @keywords internal
#' @noRd
.check_scalar <- function(x, nome, min = -Inf, strict = FALSE) {
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
  if (ok) {
    ok <- if (strict) x > min else x >= min
  }
  if (!ok) {
    stop(
      "`",
      nome,
      "` deve essere un singolo numero ",
      if (strict) "maggiore di " else "non inferiore a ",
      min,
      ".",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Riepilogo dei flag con conteggi e quote
#'
#' @param flag Vettore character.
#' @param livelli Livelli attesi, nell'ordine di uscita.
#' @param nome Nome della colonna dei flag in uscita.
#' @return Un `data.table` con `nome`, `n` (integer) e `quota`.
#' @keywords internal
#' @noRd
.riepilogo_flag <- function(flag, livelli, nome) {
  conteggi <- as.integer(table(factor(flag, levels = livelli)))
  out <- data.table::data.table(
    flag = livelli,
    n = conteggi,
    quota = .share(conteggi)
  )
  data.table::setnames(out, "flag", nome)
  out[]
}

#' Verifica la tabella delle ore di riferimento e rileva la chiave
#'
#' @param tabella Oggetto passato come `ore_riferimento_tabella`.
#' @param dt Il `data.table` di rapporti.
#' @return Nome della colonna chiave (`"ccnl_key"` o `"macro_tipologia"`).
#' @keywords internal
#' @noRd
.check_ore_tabella <- function(tabella, dt) {
  if (!is.data.frame(tabella) || !"ore_riferimento" %in% names(tabella)) {
    stop(
      "`ore_riferimento_tabella` deve essere un data.table con la colonna ",
      "`ore_riferimento` e una chiave `ccnl_key` o `macro_tipologia`.",
      call. = FALSE
    )
  }
  chiavi <- intersect(c("ccnl_key", "macro_tipologia"), names(tabella))
  if (length(chiavi) != 1L) {
    stop(
      "`ore_riferimento_tabella` deve contenere esattamente una chiave fra ",
      "`ccnl_key` e `macro_tipologia`.",
      call. = FALSE
    )
  }
  if (!chiavi %in% names(dt)) {
    stop(
      "La chiave `",
      chiavi,
      "` di `ore_riferimento_tabella` \u00e8 assente da `dt`.",
      call. = FALSE
    )
  }
  if (anyDuplicated(tabella[[chiavi]]) > 0L) {
    stop("`ore_riferimento_tabella` contiene chiavi duplicate.", call. = FALSE)
  }
  ore <- tabella[["ore_riferimento"]]
  if (!is.numeric(ore) || anyNA(ore) || any(ore <= 0)) {
    stop(
      "`ore_riferimento` in `ore_riferimento_tabella` deve essere numerico, ",
      "positivo e senza NA.",
      call. = FALSE
    )
  }
  chiavi
}

#' Nomi delle colonne dei quantili
#'
#' @param probs Vettore di probabilità ordinato e senza duplicati.
#' @return Vettore character: `"mediana"` per 0.5, `"p<int>"` altrimenti.
#' @keywords internal
#' @noRd
.nomi_quantili <- function(probs) {
  nomi <- paste0("p", round(probs * 100))
  nomi[probs == 0.5] <- "mediana"
  if (anyDuplicated(nomi) > 0L) {
    stop(
      "`probs` produce nomi di colonna duplicati: usare probabilit\u00e0 ",
      "distinte al livello del punto percentuale.",
      call. = FALSE
    )
  }
  nomi
}

#' Variazione percentuale e indice a base fissa lungo i periodi
#'
#' @param m Vettore numerico dei valori (con `NA` per le celle mascherate).
#' @param p Vettore dei periodi, ordinabile, della stessa lunghezza.
#' @return Lista con `var_pct` e `indice`, nell'ordine di `m`.
#' @keywords internal
#' @noRd
.evoluzione <- function(m, p) {
  o <- order(p, method = "radix")
  ms <- as.numeric(m[o])
  prev <- data.table::shift(ms)
  var_pct <- (ms / prev - 1) * 100
  var_pct[!is.finite(var_pct)] <- NA_real_
  primo <- which(!is.na(ms))[1L]
  indice <- if (is.na(primo) || ms[primo] == 0) {
    rep(NA_real_, length(ms))
  } else {
    ms / ms[primo] * 100
  }
  inv <- order(o)
  list(var_pct = var_pct[inv], indice = indice[inv])
}

#' Aggiunge per riferimento variazione percentuale e indice a base fissa
#'
#' @param agg Un `data.table` con `value` e `periodo_col`.
#' @param grp Colonne che identificano la serie (anche vuoto).
#' @param periodo_col Colonna di periodo.
#' @param value Colonna del valore.
#' @param var_col,indice_col Nomi delle colonne di uscita.
#' @return `agg`, invisibilmente.
#' @keywords internal
#' @noRd
.add_evoluzione <- function(agg, grp, periodo_col, value, var_col, indice_col) {
  if (nrow(agg) == 0L) {
    data.table::set(agg, j = var_col, value = numeric(0))
    data.table::set(agg, j = indice_col, value = numeric(0))
    return(invisible(agg))
  }
  agg[,
    (c(var_col, indice_col)) := .evoluzione(.SD[[1L]], .SD[[2L]]),
    by = grp,
    .SDcols = c(value, periodo_col)
  ]
  invisible(agg)
}

#' Colonne che identificano le serie in una tabella di risultati
#'
#' Legge `by` dall'attributo `ccnlcob_retribuzione_mediana`; in sua assenza
#' usa le colonne che precedono `ccnl_key` diverse da `periodo_col`.
#'
#' @param dt Un `data.table` di risultati.
#' @param periodo_col Colonna di periodo.
#' @return Vettore character, eventualmente vuoto.
#' @keywords internal
#' @noRd
.serie_groups <- function(dt, periodo_col) {
  meta <- attr(dt, "ccnlcob_retribuzione_mediana")
  if (is.list(meta) && is.list(meta$params)) {
    grp <- c(meta$params$by, "ccnl_key")
  } else if ("ccnl_key" %in% names(dt)) {
    nomi <- names(dt)
    grp <- c(nomi[seq_len(match("ccnl_key", nomi) - 1L)], "ccnl_key")
  } else {
    grp <- character(0)
  }
  as.character(setdiff(intersect(grp, names(dt)), periodo_col))
}
