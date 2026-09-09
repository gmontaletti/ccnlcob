# Costruzione del dataset di esempio `cob_esempio` con il generatore sintetico
# condiviso con i test (tests/testthat/helper-cob-sintetico.R).
#
# Eseguire dalla directory del pacchetto:
#   Rscript data-raw/cob_esempio.R
#
# Non usare usethis::use_data(): modifica DESCRIPTION.

library(data.table)

# 1. Generatore -----

source("tests/testthat/helper-cob-sintetico.R")

# 2. Dataset -----

cob_esempio <- generate_cob_sintetico()

# 3. Salvataggio -----

dir.create("data", showWarnings = FALSE)
save(cob_esempio, file = "data/cob_esempio.rda", compress = "xz")

# 4. Riepilogo -----

message("Salvato data/cob_esempio.rda: ", nrow(cob_esempio), " righe, ", ncol(cob_esempio), " colonne")
message("Persone: ", uniqueN(cob_esempio$cf), "; CCNL con codice CNEL: ",
  uniqueN(na.omit(cob_esempio$codice_cnel)))
message("Quota NA retribuzione: ", round(mean(is.na(cob_esempio$retribuzione)), 3),
  "; quota NA codice_cnel: ", round(mean(is.na(cob_esempio$codice_cnel)), 3))
message("Sentinelle fine = 9999-12-31: ", sum(cob_esempio$fine == as.Date("9999-12-31")),
  "; fine = 1900-01-01: ", sum(cob_esempio$fine == as.Date("1900-01-01")))
