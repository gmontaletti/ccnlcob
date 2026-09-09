# Segnala le retribuzioni non valide o implausibili

Aggiunge per riferimento le colonne `flag_retribuzione` (character) e
`retribuzione_pulita` (numeric, uguale a `retribuzione` dove il flag è
`"valida"`, `NA` altrove). Nessuna riga viene eliminata: la copertura
del campo resta misurabile a valle con `n` e `copertura`.

## Usage

``` r
clean_retribuzione(
  dt,
  min_valore = 100,
  max_valore = 1e+06,
  sentinelle = c(999, 9999, 99999),
  method = c("mad", "none"),
  k = 4,
  mad_min = 0.15,
  by = c("anno", "macro_tipologia", "prior"),
  by_fallback = c("anno", "prior"),
  min_n = 200L
)
```

## Arguments

- dt:

  Un `data.table` di rapporti con la colonna `retribuzione` e, per
  `method = "mad"`, le colonne di `by` e `by_fallback` (prodotte da
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)).
  Viene modificato per riferimento.

- min_valore:

  Soglia assoluta bassa: i valori positivi `<= min_valore` sono
  segnaposto e ricevono il flag `"sentinella"`.

- max_valore:

  Soglia assoluta alta: i valori `>= max_valore` ricevono il flag
  `"sentinella"`.

- sentinelle:

  Vettore numerico di valori puntuali da trattare come sentinella anche
  se compresi fra `min_valore` e `max_valore`.

- method:

  Metodo per la finestra di plausibilità: `"mad"` (default, mediana più
  o meno `k` volte la deviazione assoluta mediana di
  `log10(retribuzione)` per cella `by`) oppure `"none"` (solo soglie
  assolute e sentinelle).

- k:

  Ampiezza della finestra in unità di MAD (per `method = "mad"`).

- mad_min:

  Pavimento della MAD in unità log10: la MAD della cella viene portata a
  `max(mad, mad_min)` prima di applicare la finestra.

- by:

  Colonne che definiscono le celle entro cui calcolare mediana e MAD.

- by_fallback:

  Sottoinsieme di `by` che definisce la cella di ripiego per le celle di
  `by` con meno di `min_n` valori validi; `NULL` disattiva il ripiego.

- min_n:

  Numero minimo di valori validi perché una cella usi le proprie
  statistiche.

## Value

`dt`, restituito invisibilmente, con le colonne `flag_retribuzione` e
`retribuzione_pulita` aggiunte per riferimento. L'attributo
`ccnlcob_retribuzione` è una lista con `params` (argomenti usati),
`riepilogo` (`data.table` con `flag_retribuzione`, `n`, `quota` per
ciascun livello) e `celle` (`data.table` con le colonne di `by`, `n`
valori validi della cella, `mediana_log10` e `mad_log10` effettivamente
usate per la finestra, dopo ripiego e pavimento, e `fallback` logico;
vuoto con `method = "none"`). Viene emesso un
[`message()`](https://rdrr.io/r/base/message.html) con la quota di
valori validi.

## Details

Il campo `retribuzione` è la retribuzione annua lorda dichiarata dal
datore di lavoro all'avviamento del rapporto. È un campo a compilazione
disomogenea (testuale in origine, zero-padded nel file della pipeline:
se arriva come factor o character viene convertito come in
[`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)).
Le regole e i default derivano dalla diagnostica condotta il 2026-09-09
su 32,2 milioni di rapporti della Lombardia
(`reference/ccnlcob/diagnostica_retribuzione.md`):

- i valori in `(0, 100]` sono il 4,5-11% dei non mancanti e sono
  segnaposto (1, 50, 100); da qui `min_valore = 100`;

- i "nove ripetuti" (999, 9 999, 99 999, 999 999, ...) sono rari (0,03%)
  ma sistematici; quelli da 999 999 in su ricadono sotto
  `max_valore = 1e6`, gli altri stanno in `sentinelle`. Nessun annuo
  lordo plausibile supera il milione di euro nei dati COB lombardi;

- le celle `anno x macro_tipologia x prior` separano tempo pieno e
  parziale, altrimenti la MAD è dominata dai part-time; nelle celle
  omogenee la MAD grezza in log10 scende a 0,04-0,10 e con `k = 4`
  segnalerebbe un quarto dei tempo determinati a tempo pieno: il
  pavimento `mad_min = 0.15` (finestra minima x/÷ 4 attorno alla
  mediana) stabilizza la regola, che con `k = 4` segnala il 9,7% dei
  valori validi (4,5% del tempo indeterminato a tempo pieno) e sposta la
  mediana di meno di 500 euro;

- `min_n = 200` evita MAD instabili nelle macro-tipologie piccole
  ripiegando sulla cella `anno x prior`;

- la copertura del campo è inutilizzabile per il 2009-2013, fra il 51% e
  il 61% nel 2014-2019 e sopra il 96% dal 2020: le serie per CCNL vanno
  lette con la copertura a fianco e sono affidabili dal 2020.

I flag sono assegnati in quest'ordine, il primo che si applica vince:
`"mancante"` (`NA`), `"zero"` (`== 0`), `"sentinella"` (`<= min_valore`,
`>= max_valore` o in `sentinelle`), `"fuori_range"` (fuori dalla
finestra robusta), `"valida"`. Con `method = "mad"`, sui valori rimasti
validi dopo lo stadio delle sentinelle, per ogni cella di `by` si
calcolano mediana `m` e MAD `s = max(mad, mad_min)` di
`log10(retribuzione)`
([`stats::mad()`](https://rdrr.io/r/stats/mad.html) con costante 1,4826)
e si segnala `fuori_range` quando `abs(log10(x) - m) > k * s`. Le celle
con meno di `min_n` valori validi usano le statistiche della cella
`by_fallback` corrispondente; se anche questa è sotto `min_n` nessun
flag di finestra viene applicato alle sue righe. Per le macro-tipologie
a distribuzione degenere (collaborazioni, tirocini, altro, domestico
part-time) la regola non filtra quasi nulla e la mediana non è
interpretabile come annuo: vanno escluse o mascherate nelle stime.

Nessuna riga viene rimossa e `retribuzione` non viene alterata (salvo la
conversione da factor o character a numeric).

## See also

[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)
per la normalizzazione a tempo pieno.

Other retribuzioni:
[`deflate_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/deflate_retribuzione.md),
[`median_retribuzione()`](https://gmontaletti.github.io/ccnlcob/reference/median_retribuzione.md),
[`normalize_fte()`](https://gmontaletti.github.io/ccnlcob/reference/normalize_fte.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
clean_retribuzione(dt, min_n = 30)
#> clean_retribuzione(): 3463 retribuzioni valide su 4746 (73.0%).
attr(dt, "ccnlcob_retribuzione")$riepilogo
#>    flag_retribuzione     n       quota
#>               <char> <int>       <num>
#> 1:          mancante  1189 0.250526759
#> 2:              zero     6 0.001264223
#> 3:        sentinella    67 0.014117151
#> 4:       fuori_range    21 0.004424779
#> 5:            valida  3463 0.729667088
dt[, .(copertura = mean(flag_retribuzione == "valida")), by = anno]
#>     anno copertura
#>    <int>     <num>
#> 1:  2024 0.7371715
#> 2:  2020 0.7296954
#> 3:  2019 0.7253886
#> 4:  2023 0.7085852
#> 5:  2021 0.7400000
#> 6:  2022 0.7382716

# solo soglie assolute e sentinelle
clean_retribuzione(dt, method = "none")
#> clean_retribuzione(): 3484 retribuzioni valide su 4746 (73.4%).
```
