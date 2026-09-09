# Costruzione del dataset `tipologie_contrattuali` dalla tabella MLPS
# "ST-TIPO CONTRATTI" del workbook "Classificazioni Standard" (Rev.093,
# aggiornamento del 2026-04-26).
#
# Eseguire dalla directory del pacchetto:
#   Rscript data-raw/tipologie_contrattuali.R
#
# Il file sorgente è in formato BIFF (xls legacy nonostante l'estensione) con
# riga di intestazione a posizione variabile. La lettura usa `readxl`. Se il
# pacchetto non è installato o il file non è raggiungibile, lo script usa la
# tabella di riserva definita in §4 e lo segnala a console.
#
# Non usare usethis::use_data(): modifica DESCRIPTION.

library(data.table)

# 1. Parametri -----

nome_file <- "Rev.093-ST-Classificazioni-Standard.xls"
candidati <- c(
  Sys.getenv("CCNLCOB_MLPS_XLS", unset = ""),
  file.path(Sys.getenv("SHARED_DATA_DIR", unset = ""), "standard_cob_20260426", nome_file),
  file.path("..", "shared_data", "standard_cob_20260426", nome_file)
)
candidati <- candidati[nzchar(candidati) & !startsWith(candidati, "/standard_cob")]
sorgente <- candidati[file.exists(candidati)][1]

codici_esclusi_standard <- c("C.01.00", "B.04.00", "B.03.00", "A.04.00", "A.04.01")
macro_ammesse <- c(
  "Tempo indeterminato", "Tempo determinato", "Apprendistato", "Somministrazione",
  "Intermittente", "Collaborazioni", "Tirocinio", "Domestico", "Altro"
)

# 2. Lettura del foglio MLPS -----

# Legge il foglio "ST-TIPO CONTRATTI" individuando la riga di intestazione
# (prima riga con una cella `COD...` e una cella `DES...`) fra le prime 30.
leggi_tipo_contratti <- function(path) {
  fogli <- readxl::excel_sheets(path)
  foglio <- grep("(?i)tipo.*contr", fogli, perl = TRUE, value = TRUE)
  if (length(foglio) == 0) {
    stop("Nessun foglio con nome 'TIPO CONTRATTI' in ", path)
  }
  foglio <- foglio[1]

  testa <- readxl::read_excel(
    path, sheet = foglio, col_names = FALSE, n_max = 30,
    col_types = "text", .name_repair = "minimal"
  )
  testa <- as.matrix(testa)
  ha_cod <- apply(testa, 1, function(r) any(grepl("^COD", r, ignore.case = TRUE), na.rm = TRUE))
  ha_des <- apply(testa, 1, function(r) any(grepl("^DES", r, ignore.case = TRUE), na.rm = TRUE))
  riga_header <- which(ha_cod & ha_des)[1]
  if (is.na(riga_header)) {
    stop("Riga di intestazione (COD/DES) non trovata nelle prime 30 righe del foglio ", foglio)
  }

  tab <- readxl::read_excel(
    path, sheet = foglio, skip = riga_header - 1, col_names = TRUE,
    col_types = "text", .name_repair = "minimal"
  )
  setDT(tab)
  col_cod <- grep("^COD", names(tab), ignore.case = TRUE, value = TRUE)[1]
  col_des <- grep("^DES", names(tab), ignore.case = TRUE, value = TRUE)[1]
  tab[, list(
    cod_tipologia_contrattuale = as.character(get(col_cod)),
    des_tipologia_contrattuale = as.character(get(col_des))
  )]
}

# 3. Regole di classificazione -----

# Assegna la macro-tipologia dalla descrizione. Le regole sono applicate in
# ordine: la prima che corrisponde vince.
#   1. APPRENDISTATO                        -> Apprendistato (prima di determinato)
#   2. SOMMINISTRAZIONE / INTERINALE        -> Somministrazione (prima di det./indet.)
#   3. INTERMITTENTE                        -> Intermittente
#   4. COLLABORAZION* / CO.CO.CO /
#      LAVORO OCCASIONALE / LAVORO A PROGETTO -> Collaborazioni
#      ("LAVORO OCCASIONALE" e non "OCCASIONALE" per non catturare la
#      prestazione agricola di lavoro subordinato occasionale, H.03.00)
#   5. TIROCINIO / STAGE (parola intera)    -> Tirocinio
#   6. DOMESTICO                            -> Domestico
#   7. INDETERMINATO                        -> Tempo indeterminato
#   8. DETERMINATO                          -> Tempo determinato
#   9. altrimenti                           -> Altro
classifica_macro_tipologia <- function(des) {
  d <- toupper(des)
  fcase(
    grepl("APPRENDISTATO", d), "Apprendistato",
    grepl("SOMMINISTRAZIONE|INTERINALE", d), "Somministrazione",
    grepl("INTERMITTENTE", d), "Intermittente",
    grepl("COLLABORAZION|CO\\.CO\\.CO|LAVORO OCCASIONALE|LAVORO A PROGETTO", d), "Collaborazioni",
    grepl("TIROCINIO|\\bSTAGE\\b", d), "Tirocinio",
    grepl("DOMESTICO", d), "Domestico",
    grepl("INDETERMINATO", d), "Tempo indeterminato",
    grepl("DETERMINATO", d), "Tempo determinato",
    default = "Altro"
  )
}

# 4. Tabella di riserva -----

# Codici principali, usati solo se il workbook MLPS non è leggibile.
tipologie_riserva <- data.table(
  cod_tipologia_contrattuale = c(
    "A.01.00", "A.02.00", "A.02.01", "A.03.08", "A.03.09", "A.03.10",
    "A.03.15", "A.04.00", "A.04.01", "A.04.02", "A.05.02", "A.06.00",
    "A.06.01", "A.08.02", "B.01.00", "B.02.00", "B.03.00", "B.04.00",
    "C.01.00", "C.03.00", "C.04.00", "G.03.00", "H.02.00", "H.03.00",
    "M.02.00", "N.01.00", "N.02.00", "N.03.00"
  ),
  des_tipologia_contrattuale = c(
    "LAVORO A TEMPO INDETERMINATO",
    "LAVORO A TEMPO DETERMINATO",
    "LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE",
    "APPRENDISTATO PER LA QUALIFICA E PER IL DIPLOMA PROFESSIONALE, IL DIPLOMA DI ISTRUZIONE SECONDARIA SUPERIORE E IL CERTIFICATO DI SPECIALIZZAZIONE TECNICA SUPERIORE",
    "APPRENDISTATO PROFESSIONALIZZANTE O CONTRATTO DI MESTIERE",
    "APPRENDISTATO DI ALTA FORMAZIONE E RICERCA",
    "APPRENDISTATO PA",
    "LAVORO DOMESTICO A TEMPO INDETERMINATO",
    "LAVORO DOMESTICO A TEMPO DETERMINATO",
    "LAVORO DOMESTICO",
    "LAVORO INTERMITTENTE",
    "LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO INDETERMINATO",
    "LAVORO INTERINALE (O A SCOPO DI SOMMINISTRAZIONE) A TEMPO DETERMINATO",
    "LAVORO A DOMICILIO",
    "LAVORO A PROGETTO / COLLABORAZIONE COORDINATA E CONTINUATIVA",
    "LAVORO OCCASIONALE",
    "COLLABORAZIONE COORDINATA E CONTINUATIVA",
    "COLLABORAZIONE OCCASIONALE SPORTIVA EX ART. 28 DEL D.LGS. 36/2021",
    "TIROCINIO",
    "LAVORO O ATTIVITÀ SOCIALMENTE UTILE (LSU - ASU)",
    "CONTRATTI DI BORSA LAVORO E ALTRE WORK EXPERIENCES",
    "LAVORO AUTONOMO NELLO SPETTACOLO",
    "LAVORO CONGIUNTO IN AGRICOLTURA",
    "PRESTAZIONE AGRICOLA DI LAVORO SUBORDINATO OCCASIONALE A TEMPO DETERMINATO",
    "CONTRATTO DI AGENZIA",
    "LAVORO A TEMPO INDETERMINATO CON PIATTAFORMA",
    "LAVORO A TEMPO DETERMINATO CON PIATTAFORMA",
    "LAVORO A TEMPO DETERMINATO PER SOSTITUZIONE CON PIATTAFORMA"
  )
)

# 5. Costruzione -----

usa_riserva <- FALSE
if (!requireNamespace("readxl", quietly = TRUE)) {
  message("Pacchetto 'readxl' non installato: uso la tabella di riserva.")
  usa_riserva <- TRUE
} else if (is.na(sorgente)) {
  message("Workbook MLPS non trovato (", nome_file, "): uso la tabella di riserva.")
  usa_riserva <- TRUE
}

if (usa_riserva) {
  tab <- copy(tipologie_riserva)
} else {
  tab <- tryCatch(
    leggi_tipo_contratti(sorgente),
    error = function(e) {
      message("Lettura del workbook fallita (", conditionMessage(e), "): uso la tabella di riserva.")
      usa_riserva <<- TRUE
      copy(tipologie_riserva)
    }
  )
  if (!usa_riserva) message("Letto ", nrow(tab), " righe da ", sorgente)
}

# Pulizia: codice non vuoto e nel formato MLPS `X.NN.NN`; descrizione in
# maiuscolo con spazi normalizzati; duplicati rimossi; ordinamento per codice.
tab[, cod_tipologia_contrattuale := trimws(cod_tipologia_contrattuale)]
tab <- tab[!is.na(cod_tipologia_contrattuale) & nzchar(cod_tipologia_contrattuale)]
tab <- tab[grepl("^[A-Z]\\.[0-9]{2}\\.[0-9]{2}$", cod_tipologia_contrattuale)]
tab[, des_tipologia_contrattuale := toupper(trimws(gsub("\\s+", " ", des_tipologia_contrattuale)))]
tab <- unique(tab, by = "cod_tipologia_contrattuale")
tab[, macro_tipologia := classifica_macro_tipologia(des_tipologia_contrattuale)]
tab[, esclusa_standard := cod_tipologia_contrattuale %in% codici_esclusi_standard]
setorder(tab, cod_tipologia_contrattuale)

stopifnot(
  !anyDuplicated(tab$cod_tipologia_contrattuale),
  all(tab$macro_tipologia %in% macro_ammesse),
  all(codici_esclusi_standard %in% tab$cod_tipologia_contrattuale)
)

tipologie_contrattuali <- tab[]

# 6. Salvataggio -----

dir.create("data", showWarnings = FALSE)
save(tipologie_contrattuali, file = "data/tipologie_contrattuali.rda", compress = "xz")
message("Salvato data/tipologie_contrattuali.rda (", nrow(tipologie_contrattuali), " righe)")
print(tipologie_contrattuali[, list(cod_tipologia_contrattuale, macro_tipologia, esclusa_standard,
  des = substr(des_tipologia_contrattuale, 1, 60))], nrows = Inf)
