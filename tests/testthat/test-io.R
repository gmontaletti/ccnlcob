# Test di read_rapporti() e write_results() (R/io.R). Fase 4 e Fase 5.

# 1. Fixture -----

percorso_fst <- tempfile(fileext = ".fst")
risultato_minimo <- structure(list(meta = list(versione = "0.0.0.9000")), class = "ccnlcob_result")

# 2. Stub -----

test_that("read_rapporti() segnala che la funzione non è ancora implementata", {
  expect_error(read_rapporti(percorso_fst), "non ancora implementata")
})

test_that("write_results() segnala che la funzione non è ancora implementata", {
  expect_error(write_results(risultato_minimo, dir = tempdir()), "non ancora implementata")
})

# TODO Fase 4 (write_results):
# - crea `dir` se assente; scrive meta/ranking/rilevanti/retribuzioni/qualita in RDS
#   e cpi/tipologie in FST (compress = 85) secondo il contratto di uscita (§5.3)
# - `formats` personalizzato rispettato; errore su formato non ammesso
# - i file riletti coincidono con i componenti del risultato (`expect_equal`)
# - errore se `result` non ha classe "ccnlcob_result"
#
# TODO Fase 5 (read_rapporti):
# - da `.fst` e `.rds`: restituisce data.table con tipi normalizzati
#   (factor -> character, integer64 -> integer, IDate su inizio/fine)
# - `columns` limita le colonne lette; colonne mancanti -> errore esplicito
# - da connessione DBI (DuckDB in memoria): `skip_if_not_installed("duckdb")`,
#   tabella temporanea con `table`; niente connessioni a PostgreSQL nei test
# - errore su `source` di tipo non supportato o file inesistente
