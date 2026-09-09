# Caricamento dei dataset del pacchetto nei test.
#
# Usa utils::data() sul pacchetto installato o caricato con load_all(); se il
# dataset non è raggiungibile (per esempio con testthat::test_file() fuori dal
# pacchetto), legge direttamente il file .rda in data/.

.carica_dataset <- function(nome) {
  e <- new.env()
  trovato <- tryCatch(
    {
      suppressWarnings(utils::data(list = nome, package = "ccnlcob", envir = e))
      exists(nome, envir = e, inherits = FALSE)
    },
    error = function(err) FALSE
  )
  if (!trovato) {
    percorso <- testthat::test_path("..", "..", "data", paste0(nome, ".rda"))
    if (!file.exists(percorso)) {
      stop("Dataset '", nome, "' non trovato né nel pacchetto né in ", percorso)
    }
    load(percorso, envir = e)
  }
  get(nome, envir = e, inherits = FALSE)
}
