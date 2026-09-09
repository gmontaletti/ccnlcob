# Costruzione del lookup di esempio `cpi_esempio`: codice Belfiore -> CPI per
# i comuni presenti in `cob_esempio`, risolto con le utilità geografiche di
# longworkR (mapping Belfiore -> ISTAT e lookup comune -> CPI in
# SHARED_DATA_DIR/maps). Nessun codice viene fabbricato: senza longworkR o
# senza i file di mapping lo script si interrompe.
#
# Eseguire dalla directory del pacchetto:
#   Rscript data-raw/cpi_esempio.R
#
# Non usare usethis::use_data(): modifica DESCRIPTION.

library(data.table)

# 1. Prerequisiti -----

if (!requireNamespace("longworkR", quietly = TRUE)) {
  stop("longworkR non installato: impossibile costruire cpi_esempio.")
}
maps_dir <- file.path(
  path.expand(Sys.getenv(
    "SHARED_DATA_DIR",
    unset = "~/Documents/funzioni/shared_data"
  )),
  "maps"
)
richiesti <- file.path(
  maps_dir,
  c("belfiore_istat_mapping.csv", "comune_cpi_lookup.rds")
)
if (!all(file.exists(richiesti))) {
  stop(
    "File di mapping assenti in ",
    maps_dir,
    ": ",
    paste(basename(richiesti[!file.exists(richiesti)]), collapse = ", ")
  )
}

# 2. Codici Belfiore usati in cob_esempio -----

load("data/cob_esempio.rda")
codici <- sort(unique(c(
  cob_esempio$comune_sede_lavoro,
  cob_esempio$comune_lavoratore
)))
codici <- codici[!is.na(codici)]

# 3. Risoluzione con longworkR -----

tmp <- data.table(belfiore = codici)
risolto <- longworkR::add_cpi_via_belfiore(
  tmp,
  belfiore_col = "belfiore",
  add_name = TRUE
)
setDT(risolto)

# 4. Lookup: solo i comuni risolti (i non lombardi restano fuori) -----

cpi_esempio <- risolto[
  !is.na(cpi_code),
  list(
    belfiore = as.character(belfiore),
    cpi_code = as.character(cpi_code),
    cpi_name = as.character(cpi_name)
  )
]
setorder(cpi_esempio, belfiore)
stopifnot(
  nrow(cpi_esempio) > 0L,
  !anyDuplicated(cpi_esempio$belfiore),
  !anyNA(cpi_esempio)
)

# 5. Salvataggio -----

dir.create("data", showWarnings = FALSE)
save(cpi_esempio, file = "data/cpi_esempio.rda", compress = "xz")

# 6. Riepilogo -----

message(
  "Salvato data/cpi_esempio.rda: ",
  nrow(cpi_esempio),
  " comuni risolti su ",
  length(codici),
  " codici Belfiore in cob_esempio"
)
message(
  "Non risolti (fuori Lombardia): ",
  paste(setdiff(codici, cpi_esempio$belfiore), collapse = ", ")
)
print(cpi_esempio)
