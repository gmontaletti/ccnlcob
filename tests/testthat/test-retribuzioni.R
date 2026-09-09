# Test di clean_retribuzione(), normalize_fte(), median_retribuzione() e
# deflate_retribuzione() (R/retribuzioni.R). Fase 3.

# 1. Fixture -----

fixture <- generate_cob_sintetico(n_persone = 40, n_rapporti = 200, n_ccnl = 6, seed = 2)
indice_prezzi <- data.table::data.table(
  periodo = 2019:2024,
  indice = c(100, 99.8, 101.7, 110.0, 116.3, 117.5)
)

# 2. Stub -----

test_that("clean_retribuzione() segnala che la funzione non è ancora implementata", {
  expect_error(clean_retribuzione(data.table::copy(fixture)), "non ancora implementata")
})

test_that("normalize_fte() segnala che la funzione non è ancora implementata", {
  expect_error(normalize_fte(data.table::copy(fixture)), "non ancora implementata")
})

test_that("median_retribuzione() segnala che la funzione non è ancora implementata", {
  expect_error(median_retribuzione(data.table::copy(fixture)), "non ancora implementata")
})

test_that("deflate_retribuzione() segnala che la funzione non è ancora implementata", {
  expect_error(
    deflate_retribuzione(data.table::copy(fixture), indice = indice_prezzi, base = 2019),
    "non ancora implementata"
  )
})

# TODO Fase 3 (clean_retribuzione):
# - i valori anomali sintetici (12, 350, 2.5e6, ...) hanno `retribuzione_valida = FALSE`
# - nessuna riga rimossa: `nrow` invariato; NA restano NA con flag FALSE
# - `method = "none"` flagga solo `retribuzione <= min_value` e NA
# - `method = "mad"`: finestra mediana ± k·MAD sul logaritmo per gruppo `by`
# - `method = "quantile"`: quantili per gruppo; errore su `method` non ammesso
#
# TODO Fase 3 (normalize_fte):
# - full-time con `ore == ore_riferimento` restano invariati
# - `ore_riferimento` per CCNL = mediana di `ore` fra i full-time (data-driven)
# - `ore` NA: full-time -> `retribuzione_fte = retribuzione`, part-time -> NA
# - `fallback_ore` usato solo per CCNL senza full-time (documentato)
# - `ore_riferimento` esplicito (tabella ccnl_key x ore) prevale sulla stima
#
# TODO Fase 3 (median_retribuzione):
# - pesi uniformi (`weights = "none"`) -> mediana classica
# - caso noto a mano con pesi `giornate` (`expect_equal(tolerance)`)
# - `n` e `copertura` sempre presenti; gruppi con `n < min_n` mascherati, non eliminati
# - `probs` produce p25/mediana/p75; `var_pct` sul periodo precedente; indice base 100
# - `periodo = "trimestre"` produce chiavi trimestrali coerenti con `prepare_rapporti()`
#
# TODO Fase 3 (deflate_retribuzione):
# - identità nel periodo base (`valore_reale == valore`)
# - `valore_reale = valore * indice[base] / indice[periodo]` su caso noto
# - errore se `base` non è in `indice` o se manca `periodo_col`
# - colonna di uscita con suffisso `_reale`; nessuna colonna sovrascritta
