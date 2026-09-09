# Distribuisce i CCNL per CPI

Calcola la tabella `ccnl_key` x CPI con il valore della misura scelta,
la quota di riga (entro CCNL), la quota di colonna (entro CPI) e il
quoziente di localizzazione, eventualmente per gruppo (`by`) e per
coorte di avviamento (`periodo`).

## Usage

``` r
ccnl_by_cpi(
  dt,
  measure = "giornate",
  ccnl = NULL,
  geo = c("sede_lavoro", "residenza"),
  lookup = NULL,
  periodo = NULL,
  by = NULL,
  min_n = 30L
)
```

## Arguments

- dt:

  Un `data.table` di rapporti già passato da
  [`prepare_rapporti()`](https://gmontaletti.github.io/ccnlcob/reference/prepare_rapporti.md)
  (colonne `ccnl_key`, `giornate`, `avviato`, `attivo`, `anno`,
  `trimestre`). Se contiene già `cpi_code` (ed eventualmente `cpi_name`)
  la colonna viene usata così com'è e `geo`, `lookup` sono ignorati;
  altrimenti il CPI viene calcolato con
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
  su una copia delle colonne necessarie. `dt` non viene modificato.

- measure:

  Misura da distribuire, una fra `"giornate"` (default),
  `"giornate_effettive"`, `"n_rapporti"`, `"n_lavoratori"`,
  `"n_datori"`, `"stock"`, con le definizioni di
  [`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md).

- ccnl:

  `NULL` (default) per tutte le chiavi, altrimenti vettore character
  delle `ccnl_key` da conservare in uscita; `NA` conserva i non
  classificati. Le chiavi assenti da `dt` producono un avviso. Il filtro
  agisce dopo il calcolo dei totali (vedi Dettagli).

- geo:

  Geografia usata da
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md):
  `"sede_lavoro"` (default) o `"residenza"`. Riportata nell'attributo
  del risultato.

- lookup:

  Lookup comune -\> CPI passato ad
  [`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md);
  `NULL` usa `longworkR`.

- periodo:

  Colonna temporale (`"anno"` o `"trimestre"`) per una distribuzione per
  coorte di avviamento; `NULL` per l'intera finestra.

- by:

  Vettore character con colonne aggiuntive di raggruppamento (es.
  `"macro_tipologia"`); `NULL` per il solo CCNL.

- min_n:

  Soglia sul totale del CPI (per gruppo) sotto la quale il quoziente di
  localizzazione è mascherato con `NA`.

## Value

Un `data.table` con una riga per (`by`, `periodo`, `ccnl_key`,
`cpi_code`) e le colonne: quelle di `by` e `periodo`, `ccnl_key`,
`classe` (`"CCNL"` o `"Non classificati"`), `cpi_code`, `cpi_name`,
`<measure>`, `quota_riga`, `quota_colonna`, `lq`; ordinato per gruppo,
`ccnl_key` (non classificati in coda) e misura decrescente. L'attributo
`ccnlcob_crosstab` riporta `measure`, `dims`, `by`, `periodo`, `min_n` e
`geo`; se `cpi_code` era già presente, `geo` è quello registrato da
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)
nell'attributo `ccnlcob_cpi` di `dt` (`NA` se assente). L'input non
viene modificato.

## Details

Per ogni gruppo `g` (combinazione di `by` e `periodo`), CCNL `c` e CPI
`d`, detto `v` il valore della misura nella cella e `T` il totale del
gruppo:

- `quota_riga = v[c,d] / T[c]`: distribuzione territoriale del CCNL,
  somma a 1 entro ogni (`g`, `ccnl_key`);

- `quota_colonna = v[c,d] / T[d]`: composizione contrattuale del CPI,
  somma a 1 entro ogni (`g`, CPI);

- `lq = quota_colonna / (T[c] / T)`: quoziente di localizzazione; valori
  maggiori di 1 indicano concentrazione del CCNL nel CPI rispetto alla
  media del gruppo. Entro ogni CCNL la media di `lq` ponderata con
  `T[d] / T` è pari a 1.

I totali `T[c]`, `T[d]` e `T` sono calcolati su tutte le righe di `dt`,
inclusi i rapporti con `ccnl_key` mancante (classe `"Non classificati"`,
conservata in uscita) e prima dell'eventuale filtro `ccnl`: le quote dei
CCNL conservati non cambiano filtrando. Le celle dei CPI con
`T[d] < min_n` hanno `lq = NA` ma non vengono eliminate. Se un totale è
zero le quote corrispondenti sono `NA`.

I CPI seguono le convenzioni di
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md):
`"FUORI"` per i comuni fuori Lombardia e `"ND"` per i codici mancanti.
Per le misure di conteggio distinto (`n_lavoratori`, `n_datori`) la
somma delle celle di un CCNL può superare il conteggio del CCNL in
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
perché una persona può comparire in più CPI.

## See also

[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md),
[`rank_ccnl()`](https://gmontaletti.github.io/ccnlcob/reference/rank_ccnl.md),
[`ccnl_by_tipologia()`](https://gmontaletti.github.io/ccnlcob/reference/ccnl_by_tipologia.md).

Other territorio:
[`add_cpi()`](https://gmontaletti.github.io/ccnlcob/reference/add_cpi.md)

## Examples

``` r
dt <- prepare_rapporti(cob_esempio)
#> filter_perimetro(): perimetro "ccnl", esclusi 254 rapporti su 5000 (5,1%) in 4 tipologie; 0 con tipologia ignota.
cpi <- ccnl_by_cpi(dt, measure = "giornate", lookup = cpi_esempio)
cpi[ccnl_key == "A011"]
#>     ccnl_key classe    cpi_code        cpi_name giornate quota_riga
#>       <char> <char>      <char>          <char>    <int>      <num>
#>  1:     A011   CCNL F205C000169      CPI MILANO    63068 0.31266360
#>  2:     A011   CCNL L682C000600      CPI VARESE    25116 0.12451416
#>  3:     A011   CCNL B157C000683     CPI BRESCIA    23234 0.11518402
#>  4:     A011   CCNL A794C000060     CPI BERGAMO    19501 0.09667744
#>  5:     A011   CCNL F704C000581       CPI MONZA    15509 0.07688685
#>  6:     A011   CCNL       FUORI Fuori Lombardia    14757 0.07315876
#>  7:     A011   CCNL G388C000070       CPI PAVIA    10747 0.05327893
#>  8:     A011   CCNL C933C000073        CPI COMO     7948 0.03940271
#>  9:     A011   CCNL E507C000578       CPI LECCO     6388 0.03166891
#> 10:     A011   CCNL E648C000580        CPI LODI     4657 0.02308737
#> 11:     A011   CCNL I829C000043     CPI SONDRIO     3968 0.01967161
#> 12:     A011   CCNL D150C000030     CPI CREMONA     3575 0.01772329
#> 13:     A011   CCNL E897C000034     CPI MANTOVA     3244 0.01608234
#>     quota_colonna        lq
#>             <num>     <num>
#>  1:     0.1867381 0.9586261
#>  2:     0.1684823 0.8649095
#>  3:     0.2397383 1.2307044
#>  4:     0.2307674 1.1846519
#>  5:     0.1766985 0.9070872
#>  6:     0.2528356 1.2979394
#>  7:     0.2379392 1.2214685
#>  8:     0.1564783 0.8032861
#>  9:     0.1878382 0.9642732
#> 10:     0.2760031 1.4168706
#> 11:     0.1737912 0.8921625
#> 12:     0.1219762 0.6261686
#> 13:     0.1464560 0.7518365

# Concentrazioni territoriali più marcate (lq è NA sotto min_n giornate)
cpi[order(-lq)][1:5]
#>    ccnl_key classe    cpi_code        cpi_name giornate quota_riga
#>      <char> <char>      <char>          <char>    <int>      <num>
#> 1:     L011   CCNL E648C000580        CPI LODI     1296 0.08223350
#> 2:     I011   CCNL E648C000580        CPI LODI     1488 0.08044113
#> 3:     H013   CCNL       FUORI Fuori Lombardia     3378 0.26374141
#> 4:     P011   CCNL E507C000578       CPI LECCO     1983 0.14524280
#> 5:     H012   CCNL D150C000030     CPI CREMONA     2618 0.12134977
#>    quota_colonna       lq
#>            <num>    <num>
#> 1:    0.07680910 5.046665
#> 2:    0.08818823 4.936667
#> 3:    0.05787616 4.679144
#> 4:    0.05830981 4.422436
#> 5:    0.08932410 4.287321

# Rapporti avviati per CPI di residenza, solo due CCNL, per anno
ccnl_by_cpi(
  dt,
  measure = "n_rapporti", ccnl = c("A011", "H011"),
  geo = "residenza", lookup = cpi_esempio, periodo = "anno"
)[anno == 2024L]
#>      anno ccnl_key classe    cpi_code        cpi_name n_rapporti quota_riga
#>     <int>   <char> <char>      <char>          <char>      <int>      <num>
#>  1:  2024     A011   CCNL F205C000169      CPI MILANO         31 0.20529801
#>  2:  2024     A011   CCNL L682C000600      CPI VARESE         23 0.15231788
#>  3:  2024     A011   CCNL B157C000683     CPI BRESCIA         22 0.14569536
#>  4:  2024     A011   CCNL F704C000581       CPI MONZA         16 0.10596026
#>  5:  2024     A011   CCNL C933C000073        CPI COMO         10 0.06622517
#>  6:  2024     A011   CCNL E648C000580        CPI LODI          9 0.05960265
#>  7:  2024     A011   CCNL       FUORI Fuori Lombardia          9 0.05960265
#>  8:  2024     A011   CCNL A794C000060     CPI BERGAMO          7 0.04635762
#>  9:  2024     A011   CCNL D150C000030     CPI CREMONA          7 0.04635762
#> 10:  2024     A011   CCNL E897C000034     CPI MANTOVA          5 0.03311258
#> 11:  2024     A011   CCNL G388C000070       CPI PAVIA          5 0.03311258
#> 12:  2024     A011   CCNL I829C000043     CPI SONDRIO          5 0.03311258
#> 13:  2024     A011   CCNL E507C000578       CPI LECCO          2 0.01324503
#> 14:  2024     H011   CCNL F205C000169      CPI MILANO         17 0.19767442
#> 15:  2024     H011   CCNL L682C000600      CPI VARESE         10 0.11627907
#> 16:  2024     H011   CCNL A794C000060     CPI BERGAMO          9 0.10465116
#> 17:  2024     H011   CCNL C933C000073        CPI COMO          9 0.10465116
#> 18:  2024     H011   CCNL F704C000581       CPI MONZA          9 0.10465116
#> 19:  2024     H011   CCNL B157C000683     CPI BRESCIA          8 0.09302326
#> 20:  2024     H011   CCNL       FUORI Fuori Lombardia          7 0.08139535
#> 21:  2024     H011   CCNL D150C000030     CPI CREMONA          5 0.05813953
#> 22:  2024     H011   CCNL E507C000578       CPI LECCO          3 0.03488372
#> 23:  2024     H011   CCNL E648C000580        CPI LODI          3 0.03488372
#> 24:  2024     H011   CCNL E897C000034     CPI MANTOVA          3 0.03488372
#> 25:  2024     H011   CCNL G388C000070       CPI PAVIA          3 0.03488372
#>      anno ccnl_key classe    cpi_code        cpi_name n_rapporti quota_riga
#>     <int>   <char> <char>      <char>          <char>      <int>      <num>
#>     quota_colonna        lq
#>             <num>     <num>
#>  1:    0.14553991 0.7701085
#>  2:    0.19658120 1.0401879
#>  3:    0.21782178 1.1525802
#>  4:    0.22222222 1.1758646
#>  5:    0.20000000 1.0582781
#>  6:    0.26470588 1.4006623
#>  7:    0.17647059 0.9337748
#>  8:    0.13207547 0.6988629
#>  9:    0.28000000        NA
#> 10:    0.25000000        NA
#> 11:    0.20000000        NA
#> 12:    0.29411765        NA
#> 13:    0.09523810        NA
#> 14:    0.07981221 0.7415111
#> 15:    0.08547009 0.7940767
#> 16:    0.16981132 1.5776656
#> 17:    0.18000000 1.6723256
#> 18:    0.12500000 1.1613372
#> 19:    0.07920792 0.7358968
#> 20:    0.13725490 1.2751938
#> 21:    0.20000000        NA
#> 22:    0.14285714        NA
#> 23:    0.08823529 0.8197674
#> 24:    0.15000000        NA
#> 25:    0.12000000        NA
#>     quota_colonna        lq
#>             <num>     <num>
```
