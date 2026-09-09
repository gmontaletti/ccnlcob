# Test di clean_retribuzione(), normalize_fte(), median_retribuzione() e
# deflate_retribuzione() (R/retribuzioni.R). Fase 3.

# 1. Fixture -----

fixture <- generate_cob_sintetico(
  n_persone = 40,
  n_rapporti = 200,
  n_ccnl = 6,
  seed = 2
)

indice_prezzi <- data.table::data.table(
  periodo = 2019:2024,
  indice = c(100, 99.8, 101.7, 110.0, 116.3, 117.5)
)

# Valori "normali" attorno a 20.000 euro, in scala log quasi simmetrica.
.normali <- c(
  15000,
  16000,
  17000,
  18000,
  18500,
  19000,
  19500,
  20000,
  20000,
  20500,
  21000,
  21500,
  22000,
  23000,
  24000,
  25000,
  26000,
  28000,
  30000,
  32000
)

# Tabella a mano con una categoria di flag per riga, più valori normali.
.tab_flag <- function() {
  data.table::data.table(
    id = seq_len(length(.normali) + 6L),
    anno = 2022L,
    macro_tipologia = "Tempo indeterminato",
    prior = 1L,
    retribuzione = c(NA, 0, 50, 999, 2e6, 5e5, .normali)
  )
}

# Tabella a mano per normalize_fte(): una riga per esito.
.tab_fte <- function() {
  data.table::data.table(
    id = 1:8,
    ccnl_key = c(
      "A011",
      "A011",
      "H011",
      "H011",
      "A011",
      "A011",
      "A011",
      "A011"
    ),
    macro_tipologia = c(
      "Tempo indeterminato",
      "Tempo indeterminato",
      "Domestico",
      "Domestico",
      "Tempo determinato",
      "Tempo determinato",
      "Tempo determinato",
      "Tempo determinato"
    ),
    prior = c(1L, 0L, 0L, 0L, 0L, 0L, 1L, NA_integer_),
    ore = c(NA, 20, NA, 0, 40, 20, 40, 20),
    retribuzione_pulita = c(24000, 12000, 8000, 8000, 20000, NA, NA, 15000)
  )
}

# Tabella di rapporti per median_retribuzione(): due CCNL, tre anni.
.tab_mediana <- function() {
  data.table::data.table(
    id = 1:16,
    ccnl_key = c(rep("A011", 10L), rep("B011", 3L), rep(NA_character_, 3L)),
    anno = c(
      rep(2021L, 5L),
      rep(2022L, 3L),
      rep(2023L, 2L),
      2021L,
      2022L,
      2023L,
      2021L,
      2021L,
      2022L
    ),
    giornate = c(1, 1, 1, 1, 10, 2, 1, 1, 1, 1, 5, 5, 5, 1, 1, 1),
    retribuzione_fte = c(
      10,
      20,
      30,
      40,
      50,
      20,
      25,
      NA,
      30,
      33,
      100,
      110,
      NA,
      5,
      6,
      7
    ),
    avviato = TRUE
  )
}

# 2. clean_retribuzione(): flag -----

test_that("clean_retribuzione() assegna ogni categoria di flag sulla tabella a mano", {
  dt <- .tab_flag()
  expect_message(clean_retribuzione(dt, min_n = 5L), "retribuzioni valide")
  attesi <- c(
    "mancante",
    "zero",
    "sentinella",
    "sentinella",
    "sentinella",
    "fuori_range",
    rep("valida", length(.normali))
  )
  expect_identical(dt$flag_retribuzione, attesi)
  expect_identical(
    is.na(dt$retribuzione_pulita),
    dt$flag_retribuzione != "valida"
  )
  expect_identical(
    dt[flag_retribuzione == "valida", retribuzione_pulita],
    .normali
  )
  expect_identical(dt$retribuzione, .tab_flag()$retribuzione)
  expect_true(all(c("flag_retribuzione", "retribuzione_pulita") %in% names(dt)))
  expect_type(dt$flag_retribuzione, "character")
  expect_type(dt$retribuzione_pulita, "double")
})

test_that("clean_retribuzione() con method = 'none' salta la finestra robusta", {
  dt <- .tab_flag()
  suppressMessages(clean_retribuzione(dt, method = "none"))
  expect_identical(dt$flag_retribuzione[6L], "valida")
  expect_identical(dt$retribuzione_pulita[6L], 5e5)
  expect_identical(
    dt$flag_retribuzione[1:5],
    c("mancante", "zero", "sentinella", "sentinella", "sentinella")
  )
  meta <- attr(dt, "ccnlcob_retribuzione")
  expect_identical(meta$params$method, "none")
  expect_null(meta$celle)
  expect_null(meta$params$k)
})

test_that("le soglie e le sentinelle sono argomenti espliciti", {
  dt <- .tab_flag()
  suppressMessages(clean_retribuzione(
    dt,
    method = "none",
    min_valore = 0,
    max_valore = 1e7,
    sentinelle = NULL
  ))
  # 50 e 999 diventano validi; 2e6 resta sotto max_valore
  expect_identical(dt$flag_retribuzione[3:5], c("valida", "valida", "valida"))
  dt2 <- .tab_flag()
  suppressMessages(clean_retribuzione(dt2, method = "none", sentinelle = 20000))
  expect_identical(
    dt2[retribuzione == 20000, unique(flag_retribuzione)],
    "sentinella"
  )
})

test_that("clean_retribuzione() usa la cella di ripiego sotto min_n e nessun flag se anche il ripiego è piccolo", {
  piccola <- data.table::data.table(
    anno = 2022L,
    macro_tipologia = "Apprendistato",
    prior = 1L,
    retribuzione = c(20000, 21000, 22000, 5e5)
  )
  grande <- data.table::data.table(
    anno = 2022L,
    macro_tipologia = "Tempo indeterminato",
    prior = 1L,
    retribuzione = .normali[1:10]
  )
  dt <- data.table::rbindlist(list(piccola, grande))

  suppressMessages(clean_retribuzione(dt, min_n = 5L))
  celle <- attr(dt, "ccnlcob_retribuzione")$celle
  expect_identical(
    names(celle),
    c(
      "anno",
      "macro_tipologia",
      "prior",
      "n",
      "mediana_log10",
      "mad_log10",
      "fallback"
    )
  )
  expect_identical(celle[macro_tipologia == "Apprendistato", fallback], TRUE)
  expect_identical(
    celle[macro_tipologia == "Tempo indeterminato", fallback],
    FALSE
  )
  expect_identical(celle[macro_tipologia == "Apprendistato", n], 4L)
  # le statistiche della cella piccola sono quelle della cella anno x prior
  lr_tutti <- log10(dt$retribuzione)
  expect_equal(
    celle[macro_tipologia == "Apprendistato", mediana_log10],
    stats::median(lr_tutti),
    tolerance = 1e-12
  )
  expect_equal(
    celle[macro_tipologia == "Apprendistato", mad_log10],
    max(stats::mad(lr_tutti), 0.15),
    tolerance = 1e-12
  )
  expect_identical(dt$flag_retribuzione[4L], "fuori_range")
  expect_identical(dt$flag_retribuzione[1:3], rep("valida", 3L))

  # se anche la cella di ripiego è sotto min_n, nessun flag di finestra
  dt2 <- data.table::rbindlist(list(piccola, grande))
  suppressMessages(clean_retribuzione(dt2, min_n = 50L))
  expect_true(all(dt2$flag_retribuzione == "valida"))
  celle2 <- attr(dt2, "ccnlcob_retribuzione")$celle
  expect_true(all(celle2$fallback))
  expect_true(all(is.na(celle2$mediana_log10)))

  # senza ripiego le celle piccole non ricevono flag
  dt3 <- data.table::rbindlist(list(piccola, grande))
  suppressMessages(clean_retribuzione(dt3, min_n = 5L, by_fallback = NULL))
  expect_identical(dt3$flag_retribuzione[4L], "valida")
  expect_identical(attr(dt3, "ccnlcob_retribuzione")$params$by_fallback, NULL)
})

test_that("il pavimento sulla MAD allarga la finestra nelle celle concentrate", {
  # valori quasi identici: MAD grezza ~ 0, un valore a x2 resta dentro con
  # mad_min = 0.15 (finestra x/÷ 4) ma esce con mad_min = 0
  dt <- data.table::data.table(
    anno = 2022L,
    macro_tipologia = "Tempo determinato",
    prior = 1L,
    retribuzione = c(rep(20000, 8L), 20100, 19900, 40000)
  )
  suppressMessages(clean_retribuzione(dt, min_n = 5L))
  expect_identical(dt$flag_retribuzione[11L], "valida")
  expect_equal(
    attr(dt, "ccnlcob_retribuzione")$celle$mad_log10,
    0.15,
    tolerance = 1e-12
  )
  dt2 <- data.table::copy(dt)[,
    c("flag_retribuzione", "retribuzione_pulita") := NULL
  ]
  suppressMessages(clean_retribuzione(dt2, min_n = 5L, mad_min = 0))
  expect_identical(dt2$flag_retribuzione[11L], "fuori_range")
})

test_that("clean_retribuzione() modifica per riferimento e non rimuove righe", {
  dt <- data.table::copy(fixture)
  indirizzo <- data.table::address(dt)
  n_righe <- nrow(dt)
  retribuzione_orig <- data.table::copy(dt$retribuzione)
  out <- suppressMessages(clean_retribuzione(dt, method = "none"))
  expect_identical(data.table::address(dt), indirizzo)
  expect_identical(data.table::address(out), indirizzo)
  expect_identical(nrow(dt), n_righe)
  expect_identical(dt$retribuzione, retribuzione_orig)
  expect_false(anyNA(dt$flag_retribuzione))
  # i valori anomali sintetici non sono validi
  anomali <- c(0, 1, 12, 99, 2.5e6, 5e6)
  expect_true(all(dt[retribuzione %in% anomali, flag_retribuzione] != "valida"))
  expect_true(all(dt[retribuzione == 350, flag_retribuzione] == "valida"))
})

test_that("il riepilogo e i parametri sono coerenti con i flag", {
  dt <- .tab_flag()
  suppressMessages(clean_retribuzione(dt, min_n = 5L))
  meta <- attr(dt, "ccnlcob_retribuzione")
  expect_identical(names(meta), c("params", "riepilogo", "celle"))
  expect_identical(
    meta$riepilogo$flag_retribuzione,
    c("mancante", "zero", "sentinella", "fuori_range", "valida")
  )
  expect_identical(meta$riepilogo$n, c(1L, 1L, 3L, 1L, length(.normali)))
  expect_equal(sum(meta$riepilogo$quota), 1, tolerance = 1e-12)
  expect_identical(meta$params$by, c("anno", "macro_tipologia", "prior"))
  expect_identical(meta$params$min_n, 5L)
  expect_identical(meta$params$k, 4)
})

test_that("clean_retribuzione() accetta retribuzione factor e character", {
  dt <- .tab_flag()
  dt[, retribuzione := factor(sprintf("%09.0f", retribuzione))]
  dt[1L, retribuzione := NA]
  suppressMessages(clean_retribuzione(dt, min_n = 5L))
  expect_type(dt$retribuzione, "double")
  expect_identical(dt$flag_retribuzione[1:2], c("mancante", "zero"))
  expect_identical(dt$flag_retribuzione[6L], "fuori_range")
})

test_that("clean_retribuzione() funziona anche con celle NA e senza valori validi", {
  dt <- .tab_flag()
  dt[7:10, macro_tipologia := NA_character_]
  suppressMessages(clean_retribuzione(dt, min_n = 3L))
  expect_false(anyNA(dt$flag_retribuzione))
  celle <- attr(dt, "ccnlcob_retribuzione")$celle
  expect_true(any(is.na(celle$macro_tipologia)))

  vuoto <- .tab_flag()[, retribuzione := NA_real_]
  suppressMessages(clean_retribuzione(vuoto))
  expect_true(all(vuoto$flag_retribuzione == "mancante"))
  expect_identical(nrow(attr(vuoto, "ccnlcob_retribuzione")$celle), 0L)
})

test_that("clean_retribuzione() rifiuta input non validi", {
  expect_error(clean_retribuzione(as.data.frame(.tab_flag())), "setDT")
  expect_error(
    clean_retribuzione(.tab_flag()[, retribuzione := NULL]),
    "retribuzione"
  )
  expect_error(
    clean_retribuzione(.tab_flag()[, macro_tipologia := NULL]),
    "prepare_rapporti"
  )
  expect_error(clean_retribuzione(.tab_flag(), method = "quantile"))
  expect_error(clean_retribuzione(.tab_flag(), min_valore = 1e7), "minore")
  expect_error(clean_retribuzione(.tab_flag(), k = 0), "`k`")
  expect_error(clean_retribuzione(.tab_flag(), k = "a"), "`k`")
  expect_error(clean_retribuzione(.tab_flag(), mad_min = -1), "mad_min")
  expect_error(clean_retribuzione(.tab_flag(), min_n = NA), "min_n")
  expect_error(clean_retribuzione(.tab_flag(), by = character(0)), "`by`")
  expect_error(
    clean_retribuzione(.tab_flag(), by_fallback = "sesso"),
    "sottoinsieme"
  )
  expect_error(clean_retribuzione(.tab_flag(), sentinelle = "a"), "sentinelle")
})

# 3. normalize_fte() -----

test_that("normalize_fte() assegna flag e valori attesi sulla tabella a mano", {
  dt <- .tab_fte()
  out <- normalize_fte(dt)
  expect_identical(data.table::address(out), data.table::address(dt))
  expect_identical(
    dt$flag_fte,
    c(
      "full_time",
      "riproporzionata",
      "ore_mancanti",
      "ore_mancanti",
      "ore_oltre_riferimento",
      "non_valida",
      "non_valida",
      "orario_ignoto"
    )
  )
  expect_equal(
    dt$retribuzione_fte,
    c(24000, 24000, NA, NA, 20000, NA, NA, NA),
    tolerance = 1e-12
  )
  expect_identical(dt$ore_riferimento, rep(40, 8L))
  # la colonna ore non viene alterata (0 resta 0)
  expect_identical(dt$ore, .tab_fte()$ore)
  meta <- attr(dt, "ccnlcob_fte")
  expect_identical(names(meta), c("params", "riepilogo"))
  expect_identical(meta$params$value_col, "retribuzione_pulita")
  expect_null(meta$params$tabella_key)
  expect_identical(
    meta$riepilogo$flag_fte,
    c(
      "full_time",
      "riproporzionata",
      "ore_oltre_riferimento",
      "ore_mancanti",
      "non_valida",
      "orario_ignoto"
    )
  )
  expect_identical(meta$riepilogo$n, c(1L, 1L, 1L, 2L, 2L, 1L))
})

test_that("normalize_fte() riproporziona alle ore di riferimento scalari", {
  dt <- .tab_fte()[prior == 0L & ore == 20 & !is.na(retribuzione_pulita)]
  normalize_fte(dt, ore_riferimento = 36)
  expect_equal(
    dt$retribuzione_fte,
    dt$retribuzione_pulita * 36 / 20,
    tolerance = 1e-12
  )
  # ore_min esclude i part-time sotto soglia
  dt2 <- .tab_fte()
  dt2[2L, ore := 0.5]
  normalize_fte(dt2, ore_min = 1)
  expect_identical(dt2$flag_fte[2L], "ore_mancanti")
  normalize_fte(dt2, ore_min = 0)
  expect_identical(dt2$flag_fte[2L], "riproporzionata")
  expect_equal(dt2$retribuzione_fte[2L], 12000 * 40 / 0.5, tolerance = 1e-12)
})

test_that("normalize_fte() usa la tabella per ccnl_key e per macro_tipologia", {
  dt <- .tab_fte()
  tab_ccnl <- data.table::data.table(ccnl_key = "H011", ore_riferimento = 54)
  normalize_fte(dt, ore_riferimento_tabella = tab_ccnl)
  expect_identical(dt$ore_riferimento, c(40, 40, 54, 54, 40, 40, 40, 40))
  expect_identical(attr(dt, "ccnlcob_fte")$params$tabella_key, "ccnl_key")

  dt2 <- .tab_fte()
  dt2[3L, ore := 27]
  tab_macro <- data.table::data.table(
    macro_tipologia = c("Domestico", "Tempo determinato"),
    ore_riferimento = c(54, 38)
  )
  normalize_fte(dt2, ore_riferimento_tabella = tab_macro)
  expect_identical(dt2$ore_riferimento, c(40, 40, 54, 54, 38, 38, 38, 38))
  expect_identical(dt2$flag_fte[3L], "riproporzionata")
  expect_equal(dt2$retribuzione_fte[3L], 8000 * 54 / 27, tolerance = 1e-12)
  # 40 ore con riferimento 38: oltre riferimento, valore invariato
  expect_identical(dt2$flag_fte[5L], "ore_oltre_riferimento")
  expect_identical(
    attr(dt2, "ccnlcob_fte")$params$tabella_key,
    "macro_tipologia"
  )
})

test_that("normalize_fte() accetta value_col = 'retribuzione' e ore factor", {
  dt <- .tab_fte()
  data.table::setnames(dt, "retribuzione_pulita", "retribuzione")
  dt[, ore := factor(ifelse(is.na(ore), NA, sprintf("%02.0f", ore)))]
  normalize_fte(dt, value_col = "retribuzione")
  expect_type(dt$ore, "double")
  expect_identical(dt$flag_fte[2L], "riproporzionata")
  expect_equal(dt$retribuzione_fte[2L], 24000, tolerance = 1e-12)
})

test_that("normalize_fte() rifiuta input non validi", {
  expect_error(normalize_fte(as.data.frame(.tab_fte())), "setDT")
  expect_error(normalize_fte(.tab_fte()[, ore := NULL]), "prepare_rapporti")
  expect_error(
    normalize_fte(.tab_fte()[, retribuzione_pulita := NULL]),
    "clean_retribuzione"
  )
  expect_error(normalize_fte(.tab_fte(), value_col = "altro"), "altro")
  expect_error(
    normalize_fte(.tab_fte(), ore_riferimento = 0),
    "ore_riferimento"
  )
  expect_error(normalize_fte(.tab_fte(), ore_min = -1), "ore_min")
  expect_error(
    normalize_fte(.tab_fte(), ore_riferimento_tabella = data.frame(x = 1)),
    "ore_riferimento_tabella"
  )
  expect_error(
    normalize_fte(
      .tab_fte(),
      ore_riferimento_tabella = data.frame(
        ccnl_key = "A",
        macro_tipologia = "B",
        ore_riferimento = 40
      )
    ),
    "esattamente una chiave"
  )
  expect_error(
    normalize_fte(
      .tab_fte(),
      ore_riferimento_tabella = data.frame(
        ccnl_key = c("A", "A"),
        ore_riferimento = c(40, 38)
      )
    ),
    "duplicate"
  )
  expect_error(
    normalize_fte(
      .tab_fte(),
      ore_riferimento_tabella = data.frame(ccnl_key = "A", ore_riferimento = NA)
    ),
    "positivo"
  )
  expect_error(
    normalize_fte(
      .tab_fte()[, macro_tipologia := NULL],
      ore_riferimento_tabella = data.frame(
        macro_tipologia = "A",
        ore_riferimento = 40
      )
    ),
    "assente da `dt`"
  )
})

# 4. median_retribuzione() -----

test_that("median_retribuzione() con pesi uniformi coincide con stats::median()", {
  dt <- .tab_mediana()
  out <- median_retribuzione(dt, weights = "none", min_n = 1L)
  expect_identical(
    names(out),
    c(
      "anno",
      "ccnl_key",
      "classe",
      "n",
      "n_valide",
      "copertura",
      "giornate",
      "p25",
      "mediana",
      "p75",
      "var_pct",
      "indice"
    )
  )
  attese <- dt[
    !is.na(retribuzione_fte),
    list(mediana_attesa = stats::median(retribuzione_fte)),
    by = list(ccnl_key, anno)
  ]
  confronto <- merge(out, attese, by = c("ccnl_key", "anno"))
  expect_equal(confronto$mediana, confronto$mediana_attesa, tolerance = 1e-12)
  expect_identical(out[ccnl_key == "A011" & anno == 2021L, n], 5L)
  expect_identical(out[ccnl_key == "A011" & anno == 2022L, n_valide], 2L)
  expect_equal(
    out[ccnl_key == "A011" & anno == 2022L, copertura],
    2 / 3,
    tolerance = 1e-12
  )
  expect_identical(out[ccnl_key == "A011" & anno == 2021L, p25], 20)
  expect_identical(out[ccnl_key == "A011" & anno == 2021L, p75], 40)
})

test_that("median_retribuzione() calcola la mediana ponderata per giornate sul caso a mano", {
  dt <- .tab_mediana()
  out <- median_retribuzione(dt, min_n = 1L)
  # cella A011/2021: valori 10..50, pesi 1,1,1,1,10 -> mediana 50, p25 40
  cella <- out[ccnl_key == "A011" & anno == 2021L]
  expect_equal(cella$mediana, 50, tolerance = 1e-12)
  expect_equal(cella$p25, 40, tolerance = 1e-12)
  expect_equal(cella$p75, 50, tolerance = 1e-12)
  expect_equal(cella$giornate, 14, tolerance = 1e-12)
  # cella A011/2022: valori 20 (peso 2), 25 (peso 1): target 1.5 cade nel
  # blocco di 20 -> mediana 20; p75 (target 2.25) -> 25
  cella22 <- out[ccnl_key == "A011" & anno == 2022L]
  expect_equal(cella22$mediana, 20, tolerance = 1e-12)
  expect_equal(cella22$p75, 25, tolerance = 1e-12)
  expect_equal(cella22$giornate, 3, tolerance = 1e-12)
  # confine esatto: pesi 2,1,1,1,1 su 10..50 -> media fra 20 e 30
  expect_equal(
    .wquantile(c(10, 20, 30, 40, 50), c(2, 1, 1, 1, 1), 0.5),
    25,
    tolerance = 1e-12
  )
  # coincide con .wquantile()
  expect_equal(
    cella$mediana,
    .wquantile(c(10, 20, 30, 40, 50), c(1, 1, 1, 1, 10), 0.5),
    tolerance = 1e-12
  )
})

test_that("median_retribuzione() maschera le celle sotto min_n senza eliminarle", {
  dt <- .tab_mediana()
  out <- median_retribuzione(dt, min_n = 3L, weights = "none")
  expect_identical(nrow(out), 8L)
  mascherate <- out[n_valide < 3L]
  expect_gt(nrow(mascherate), 0L)
  expect_true(all(is.na(mascherate$mediana)))
  expect_true(all(is.na(mascherate$p25)))
  expect_false(anyNA(mascherate$n))
  expect_false(anyNA(mascherate$copertura))
  expect_false(anyNA(out[n_valide >= 3L, mediana]))
  # la classe dei non classificati resta, con NA in coda
  expect_identical(out[is.na(ccnl_key), unique(classe)], "Non classificati")
  expect_identical(out[!is.na(ccnl_key), unique(classe)], "CCNL")
  expect_identical(which(is.na(out$ccnl_key)), 7:8)
})

test_that("var_pct e indice seguono i periodi entro la serie", {
  dt <- .tab_mediana()
  out <- median_retribuzione(dt, weights = "none", min_n = 1L)
  a <- out[ccnl_key == "A011"]
  expect_identical(a$anno, c(2021L, 2022L, 2023L))
  m <- a$mediana
  expect_true(is.na(a$var_pct[1L]))
  expect_equal(a$var_pct[2L], (m[2L] / m[1L] - 1) * 100, tolerance = 1e-12)
  expect_equal(a$var_pct[3L], (m[3L] / m[2L] - 1) * 100, tolerance = 1e-12)
  expect_equal(a$indice, m / m[1L] * 100, tolerance = 1e-12)

  # con mascheratura: var_pct NA ai lati della cella mascherata, indice sulla
  # prima mediana non mascherata
  out2 <- median_retribuzione(dt, weights = "none", min_n = 3L)
  a2 <- out2[ccnl_key == "A011"]
  expect_identical(a2$n_valide, c(5L, 2L, 2L))
  expect_true(all(is.na(a2$var_pct)))
  expect_equal(a2$indice, c(100, NA, NA), tolerance = 1e-12)
  b2 <- out2[ccnl_key == "B011"]
  expect_true(all(is.na(b2$mediana)))
  expect_true(all(is.na(b2$indice)))
  expect_true(all(is.na(b2$var_pct)))

  # serie che parte mascherata: indice = 100 sulla prima non mascherata
  dt3 <- .tab_mediana()
  dt3[ccnl_key == "A011" & anno == 2021L & id > 1L, retribuzione_fte := NA]
  out3 <- median_retribuzione(dt3, weights = "none", min_n = 2L)
  a3 <- out3[ccnl_key == "A011"]
  expect_true(is.na(a3$mediana[1L]))
  expect_equal(a3$indice[2L], 100, tolerance = 1e-12)
  expect_equal(
    a3$indice[3L],
    a3$mediana[3L] / a3$mediana[2L] * 100,
    tolerance = 1e-12
  )
})

test_that("solo_avviati esclude i rapporti avviati prima della finestra", {
  dt <- .tab_mediana()
  dt[ccnl_key == "A011" & anno == 2021L & id <= 2L, avviato := FALSE]
  con <- median_retribuzione(dt, weights = "none", min_n = 1L)
  senza <- median_retribuzione(
    dt,
    weights = "none",
    min_n = 1L,
    solo_avviati = FALSE
  )
  expect_identical(con[ccnl_key == "A011" & anno == 2021L, n], 3L)
  expect_identical(senza[ccnl_key == "A011" & anno == 2021L, n], 5L)
  expect_equal(
    con[ccnl_key == "A011" & anno == 2021L, mediana],
    40,
    tolerance = 1e-12
  )
  expect_equal(
    senza[ccnl_key == "A011" & anno == 2021L, mediana],
    30,
    tolerance = 1e-12
  )
  # senza avviato la funzione richiede solo_avviati = FALSE
  dt2 <- .tab_mediana()[, avviato := NULL]
  expect_error(median_retribuzione(dt2), "avviato")
  expect_s3_class(
    median_retribuzione(dt2, solo_avviati = FALSE, min_n = 1L),
    "data.table"
  )
})

test_that("median_retribuzione() gestisce by, ccnl, probs e periodo trimestrale", {
  dt <- .tab_mediana()
  dt[, sesso := rep(c("F", "M"), length.out = .N)]
  dt[, trimestre := paste0(anno, "-Q", rep(1:2, length.out = .N))]
  out <- median_retribuzione(dt, by = "sesso", weights = "none", min_n = 1L)
  expect_identical(names(out)[1:3], c("sesso", "anno", "ccnl_key"))
  expect_identical(out[, .N, by = list(sesso, anno, ccnl_key)][, unique(N)], 1L)
  expect_identical(attr(out, "ccnlcob_retribuzione_mediana")$params$by, "sesso")

  # filtro ccnl con avviso per chiavi ignote; NA conserva i non classificati
  expect_warning(
    filtrato <- median_retribuzione(dt, ccnl = c("A011", "ZZZZ"), min_n = 1L),
    "ZZZZ"
  )
  expect_identical(unique(filtrato$ccnl_key), "A011")
  na_incluso <- median_retribuzione(dt, ccnl = c("B011", NA), min_n = 1L)
  expect_identical(unique(na_incluso$ccnl_key), c("B011", NA))

  # probs personalizzate: 0.5 sempre incluso
  out_p <- median_retribuzione(
    dt,
    probs = c(0.1, 0.9),
    weights = "none",
    min_n = 1L
  )
  expect_true(all(c("p10", "mediana", "p90") %in% names(out_p)))
  expect_identical(
    attr(out_p, "ccnlcob_retribuzione_mediana")$params$probs,
    c(0.1, 0.5, 0.9)
  )

  # periodo trimestrale
  out_q <- median_retribuzione(
    dt,
    periodo = "trimestre",
    weights = "none",
    min_n = 1L
  )
  expect_identical(names(out_q)[1L], "trimestre")
  expect_true(all(grepl("^[0-9]{4}-Q[1-4]$", out_q$trimestre)))
  q <- out_q[ccnl_key == "A011", trimestre]
  expect_identical(q, sort(q))
})

test_that("median_retribuzione() non modifica l'input", {
  dt <- .tab_mediana()
  originale <- data.table::copy(dt)
  median_retribuzione(dt, min_n = 1L)
  expect_identical(dt, originale)
})

test_that("median_retribuzione() rifiuta input non validi", {
  dt <- .tab_mediana()
  expect_error(median_retribuzione(list(a = 1)), "data.table")
  expect_error(median_retribuzione(dt[, ccnl_key := NULL]), "ccnl_key")
  expect_error(median_retribuzione(.tab_mediana(), periodo = "mese"))
  expect_error(
    median_retribuzione(.tab_mediana(), periodo = "trimestre"),
    "trimestre"
  )
  expect_error(
    median_retribuzione(.tab_mediana()[, retribuzione_fte := NULL]),
    "normalize_fte"
  )
  expect_error(
    median_retribuzione(.tab_mediana(), value_col = "altro"),
    "altro"
  )
  expect_error(
    median_retribuzione(.tab_mediana(), value_col = "ccnl_key"),
    "numerica"
  )
  expect_error(
    median_retribuzione(.tab_mediana()[, giornate := NULL]),
    "giornate"
  )
  expect_error(median_retribuzione(.tab_mediana(), by = "ccnl_key"), "ccnl_key")
  expect_error(median_retribuzione(.tab_mediana(), by = "altro"), "altro")
  expect_error(median_retribuzione(.tab_mediana(), probs = 1.5), "probs")
  expect_error(
    median_retribuzione(.tab_mediana(), probs = c(0.251, 0.252)),
    "duplicati"
  )
  expect_error(median_retribuzione(.tab_mediana(), min_n = -1), "min_n")
  expect_error(
    median_retribuzione(.tab_mediana(), solo_avviati = NA),
    "solo_avviati"
  )
  expect_error(median_retribuzione(.tab_mediana(), ccnl = 1), "ccnl")
})

# 5. deflate_retribuzione() -----

.tab_deflazione <- function() {
  data.table::data.table(
    anno = c(2020L, 2021L, 2022L, 2020L, 2021L, 2022L),
    ccnl_key = c(rep("A011", 3L), rep("B011", 3L)),
    classe = "CCNL",
    n = 100L,
    p25 = c(90, 95, 100, 40, 42, NA),
    mediana = c(100, 110, 121, 50, 55, NA),
    p75 = c(120, 130, 140, 60, 63, NA)
  )
}

test_that("deflate_retribuzione() è l'identità nel periodo base e segue la formula", {
  dt <- .tab_deflazione()
  ind <- data.table::data.table(anno = 2020:2022, indice = c(100, 105, 110))
  out <- deflate_retribuzione(dt, indice = ind, base = 2020L)
  expect_s3_class(out, "data.table")
  expect_false(identical(data.table::address(out), data.table::address(dt)))
  expect_identical(dt, .tab_deflazione())
  expect_true(all(
    c(
      "p25_reale",
      "mediana_reale",
      "p75_reale",
      "var_pct_reale",
      "indice_reale"
    ) %in%
      names(out)
  ))
  base <- out[anno == 2020L]
  expect_equal(base$mediana_reale, base$mediana, tolerance = 1e-12)
  expect_equal(base$p25_reale, base$p25, tolerance = 1e-12)
  # caso a mano: 2021 -> 110 * 100 / 105; 2022 -> 121 * 100 / 110 = 110
  a <- out[ccnl_key == "A011"]
  expect_equal(a$mediana_reale, c(100, 110 * 100 / 105, 110), tolerance = 1e-12)
  expect_equal(
    a$p75_reale,
    c(120, 130 * 100 / 105, 140 * 100 / 110),
    tolerance = 1e-12
  )
  expect_equal(a$indice_reale, a$mediana_reale / 100 * 100, tolerance = 1e-12)
  expect_true(is.na(a$var_pct_reale[1L]))
  expect_equal(
    a$var_pct_reale[2:3],
    (a$mediana_reale[2:3] / a$mediana_reale[1:2] - 1) * 100,
    tolerance = 1e-12
  )
  b <- out[ccnl_key == "B011"]
  expect_true(is.na(b$mediana_reale[3L]))
  expect_true(is.na(b$var_pct_reale[3L]))
  expect_true(is.na(b$indice_reale[3L]))
  expect_identical(
    attr(out, "ccnlcob_deflazione"),
    list(
      base = 2020L,
      periodo_col = "anno",
      value_cols = c("p25", "mediana", "p75")
    )
  )
})

test_that("deflate_retribuzione() usa l'ultimo periodo come base di default e accetta la colonna periodo", {
  dt <- .tab_deflazione()
  ind <- data.table::data.table(
    periodo = 2019:2022,
    indice = c(98, 100, 105, 110)
  )
  out <- deflate_retribuzione(dt, indice = ind)
  expect_identical(attr(out, "ccnlcob_deflazione")$base, 2022L)
  ultimo <- out[anno == 2022L & ccnl_key == "A011"]
  expect_equal(ultimo$mediana_reale, ultimo$mediana, tolerance = 1e-12)
  expect_equal(
    out[anno == 2020L & ccnl_key == "A011", mediana_reale],
    100 * 110 / 100,
    tolerance = 1e-12
  )
  # solo una colonna e un periodo character
  dt2 <- data.table::data.table(
    trimestre = c("2023-Q1", "2023-Q2"),
    mediana = c(100, 102)
  )
  ind2 <- data.table::data.table(
    trimestre = c("2023-Q1", "2023-Q2"),
    indice = c(100, 102)
  )
  out2 <- deflate_retribuzione(
    dt2,
    indice = ind2,
    value_cols = "mediana",
    periodo_col = "trimestre"
  )
  # base di default = ultimo periodo (2023-Q2): 100 * 102 / 100 = 102
  expect_identical(attr(out2, "ccnlcob_deflazione")$base, "2023-Q2")
  expect_equal(out2$mediana_reale, c(102, 102), tolerance = 1e-12)
  expect_equal(out2$indice_reale, c(100, 100), tolerance = 1e-12)
  expect_equal(out2$var_pct_reale, c(NA, 0), tolerance = 1e-12)
})

test_that("deflate_retribuzione() legge le serie dall'attributo di median_retribuzione()", {
  dt <- .tab_mediana()
  ret <- median_retribuzione(dt, weights = "none", min_n = 1L)
  ind <- data.table::data.table(anno = 2021:2023, indice = c(100, 100, 100))
  out <- deflate_retribuzione(ret, indice = ind, base = 2021L)
  expect_equal(out$mediana_reale, out$mediana, tolerance = 1e-12)
  expect_equal(out$var_pct_reale, out$var_pct, tolerance = 1e-12)
  expect_equal(out$indice_reale, out$indice, tolerance = 1e-12)
})

test_that("deflate_retribuzione() rifiuta input non validi", {
  dt <- .tab_deflazione()
  ind <- data.table::data.table(anno = 2020:2022, indice = c(100, 105, 110))
  expect_error(deflate_retribuzione(dt, indice = ind, base = 2019L), "base")
  expect_error(deflate_retribuzione(dt, indice = ind[anno != 2021L]), "2021")
  expect_error(
    deflate_retribuzione(dt, indice = data.table::rbindlist(list(ind, ind))),
    "duplicati"
  )
  expect_error(
    deflate_retribuzione(
      dt,
      indice = data.table::data.table(anno = 2020:2022, indice = c(100, 0, 110))
    ),
    "positiva"
  )
  expect_error(
    deflate_retribuzione(
      dt,
      indice = data.table::data.table(x = 1, indice = 1)
    ),
    "periodo"
  )
  expect_error(
    deflate_retribuzione(dt, indice = data.frame(anno = 2020)),
    "indice"
  )
  expect_error(
    deflate_retribuzione(dt, indice = ind, value_cols = "altro"),
    "altro"
  )
  expect_error(
    deflate_retribuzione(dt, indice = ind, value_cols = "classe"),
    "numeriche"
  )
  expect_error(
    deflate_retribuzione(dt, indice = ind, periodo_col = "mese"),
    "mese"
  )
  expect_error(
    deflate_retribuzione(dt, indice = ind, base = c(2020L, 2021L)),
    "singolo"
  )
  gia <- data.table::copy(dt)[, mediana_reale := 1]
  expect_error(deflate_retribuzione(gia, indice = ind), "già presenti")
})

# 6. Catena completa su cob_esempio -----

test_that("la catena prepare -> clean -> normalize -> median rispetta gli invarianti", {
  cob <- .carica_dataset("cob_esempio")
  dt <- suppressMessages(prepare_rapporti(cob))
  n_righe <- nrow(dt)
  suppressMessages(clean_retribuzione(dt, min_n = 30L))
  normalize_fte(dt)
  expect_identical(nrow(dt), n_righe)
  expect_true(all(
    c(
      "flag_retribuzione",
      "retribuzione_pulita",
      "ore_riferimento",
      "retribuzione_fte",
      "flag_fte"
    ) %in%
      names(dt)
  ))

  riep <- attr(dt, "ccnlcob_retribuzione")$riepilogo
  expect_identical(sum(riep$n), n_righe)
  expect_equal(sum(riep$quota), 1, tolerance = 1e-12)
  expect_gt(riep[flag_retribuzione == "valida", quota], 0.6)
  expect_gt(riep[flag_retribuzione == "mancante", quota], 0.2)
  expect_gt(riep[flag_retribuzione == "sentinella", n], 0L)
  riep_fte <- attr(dt, "ccnlcob_fte")$riepilogo
  expect_identical(sum(riep_fte$n), n_righe)
  expect_identical(riep_fte[flag_fte == "orario_ignoto", n], 0L)
  # i part-time riproporzionati hanno fte >= valore pulito
  pt <- dt[flag_fte == "riproporzionata"]
  expect_true(all(pt$retribuzione_fte >= pt$retribuzione_pulita))
  expect_equal(
    pt$retribuzione_fte,
    pt$retribuzione_pulita * pt$ore_riferimento / pt$ore,
    tolerance = 1e-12
  )
  ft <- dt[flag_fte == "full_time"]
  expect_identical(ft$retribuzione_fte, ft$retribuzione_pulita)

  ret <- median_retribuzione(dt, periodo = "anno", min_n = 10L)
  expect_true(all(ret$copertura >= 0 & ret$copertura <= 1))
  expect_true(all(ret$n_valide <= ret$n))
  expect_true(all(is.na(ret[n_valide < 10L, mediana])))
  expect_false(anyNA(ret[n_valide >= 10L, mediana]))
  expect_true(all(ret[n_valide >= 10L, p25 <= mediana & mediana <= p75]))
  expect_identical(ret[, .N, by = list(ccnl_key, anno)][, unique(N)], 1L)
  for (k in unique(ret$ccnl_key)) {
    anni <- if (is.na(k)) {
      ret[is.na(ccnl_key), anno]
    } else {
      ret[ccnl_key == k, anno]
    }
    expect_identical(anni, sort(anni))
  }
  expect_identical(
    which(is.na(ret$ccnl_key)),
    seq(nrow(ret) - sum(is.na(ret$ccnl_key)) + 1L, nrow(ret))
  )
  # n coincide con il conteggio degli avviati per cella
  conteggi <- dt[avviato == TRUE, .N, by = list(ccnl_key, anno)]
  confronto <- merge(ret, conteggi, by = c("ccnl_key", "anno"))
  expect_identical(confronto$n, confronto$N)
  # la mediana ponderata di una cella coincide con il ricalcolo diretto
  cella <- ret[!is.na(ccnl_key) & n_valide >= 10L][1L]
  righe <- dt[
    avviato == TRUE &
      ccnl_key == cella$ccnl_key &
      anno == cella$anno &
      !is.na(retribuzione_fte)
  ]
  expect_equal(
    cella$mediana,
    .wquantile(righe$retribuzione_fte, righe$giornate, 0.5),
    tolerance = 1e-9
  )
  # deflazione sull'output reale
  ind <- data.table::data.table(anno = 2019:2024, indice = indice_prezzi$indice)
  reale <- deflate_retribuzione(ret, indice = ind, base = 2024L)
  expect_identical(nrow(reale), nrow(ret))
  ultimo <- reale[anno == 2024L]
  expect_equal(ultimo$mediana_reale, ultimo$mediana, tolerance = 1e-12)
})
