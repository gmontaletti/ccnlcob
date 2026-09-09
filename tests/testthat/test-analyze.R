# Test di analyze_ccnl() e del metodo print.ccnlcob_result (R/analyze.R). Fase 4.

# 1. Fixture -----

fixture <- generate_cob_sintetico(n_persone = 40, n_rapporti = 200, n_ccnl = 6, seed = 2)

# 2. Stub -----

test_that("analyze_ccnl() segnala che la funzione non è ancora implementata", {
  expect_error(analyze_ccnl(data.table::copy(fixture)), "non ancora implementata")
})

# TODO Fase 4 (analyze_ccnl):
# - ritorna una lista di classe "ccnlcob_result" con componenti meta, ranking,
#   rilevanti, cpi, tipologie, retribuzioni, qualita
# - `meta` riporta as_of, window, n_rapporti, n_lavoratori, copertura_ccnl,
#   copertura_retribuzione, versione
# - `indice = NULL` -> nessuna colonna `_reale`; con indice -> `mediana_reale`
# - `top_n` e `cum_share` propagati a select_ccnl_rilevanti()
# - lookup CPI esplicito passato via `...` o argomento dedicato (niente SHARED_DATA_DIR)
# - print.ccnlcob_result: `expect_output()` con numero di CCNL e finestra
# - smoke test su `cob_esempio` con parametri di default
