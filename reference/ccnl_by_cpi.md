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
cpi <- ccnl_by_cpi(dt, measure = "giornate", lookup = cpi_esempio)
cpi[ccnl_key == "A011"]
#>     ccnl_key classe    cpi_code        cpi_name giornate quota_riga
#>       <char> <char>      <char>          <char>    <int>      <num>
#>  1:     A011   CCNL F205C000169      CPI MILANO    65194 0.30878021
#>  2:     A011   CCNL L682C000600      CPI VARESE    26184 0.12401603
#>  3:     A011   CCNL B157C000683     CPI BRESCIA    24261 0.11490807
#>  4:     A011   CCNL A794C000060     CPI BERGAMO    20373 0.09649322
#>  5:     A011   CCNL F704C000581       CPI MONZA    16004 0.07580020
#>  6:     A011   CCNL       FUORI Fuori Lombardia    15168 0.07184063
#>  7:     A011   CCNL G388C000070       CPI PAVIA    11032 0.05225118
#>  8:     A011   CCNL C933C000073        CPI COMO     8772 0.04154707
#>  9:     A011   CCNL E507C000578       CPI LECCO     6464 0.03061563
#> 10:     A011   CCNL I829C000043     CPI SONDRIO     5671 0.02685972
#> 11:     A011   CCNL E648C000580        CPI LODI     5020 0.02377637
#> 12:     A011   CCNL D150C000030     CPI CREMONA     3626 0.01717393
#> 13:     A011   CCNL E897C000034     CPI MANTOVA     3365 0.01593775
#>     quota_colonna        lq
#>             <num>     <num>
#>  1:     0.1847829 0.9479999
#>  2:     0.1705021 0.8747341
#>  3:     0.2335551 1.1982178
#>  4:     0.2279394 1.1694077
#>  5:     0.1769865 0.9080013
#>  6:     0.2474671 1.2695912
#>  7:     0.2388189 1.2252230
#>  8:     0.1678563 0.8611603
#>  9:     0.1778120 0.9122367
#> 10:     0.2245051 1.1517886
#> 11:     0.2908122 1.4919665
#> 12:     0.1194571 0.6128559
#> 13:     0.1393375 0.7148491

# Concentrazioni territoriali più marcate (lq è NA sotto min_n giornate)
cpi[order(-lq)][1:5]
#>    ccnl_key classe    cpi_code        cpi_name giornate quota_riga
#>      <char> <char>      <char>          <char>    <int>      <num>
#> 1:     L011   CCNL E648C000580        CPI LODI     1296 0.08129979
#> 2:     I011   CCNL E648C000580        CPI LODI     1488 0.07611643
#> 3:     H013   CCNL       FUORI Fuori Lombardia     3378 0.24665936
#> 4:     H012   CCNL D150C000030     CPI CREMONA     2618 0.11756253
#> 5:     P011   CCNL E507C000578       CPI LECCO     1983 0.13682467
#>    quota_colonna       lq
#>            <num>    <num>
#> 1:    0.07507821 5.101560
#> 2:    0.08620090 4.776303
#> 3:    0.05511233 4.359045
#> 4:    0.08624893 4.195248
#> 5:    0.05454846 4.076888

# Rapporti avviati per CPI di residenza, solo due CCNL, per anno
ccnl_by_cpi(
  dt,
  measure = "n_rapporti", ccnl = c("A011", "H011"),
  geo = "residenza", lookup = cpi_esempio, periodo = "anno"
)[anno == 2024L]
#>      anno ccnl_key classe    cpi_code        cpi_name n_rapporti quota_riga
#>     <int>   <char> <char>      <char>          <char>      <int>      <num>
#>  1:  2024     A011   CCNL F205C000169      CPI MILANO         35 0.21084337
#>  2:  2024     A011   CCNL L682C000600      CPI VARESE         24 0.14457831
#>  3:  2024     A011   CCNL B157C000683     CPI BRESCIA         23 0.13855422
#>  4:  2024     A011   CCNL F704C000581       CPI MONZA         18 0.10843373
#>  5:  2024     A011   CCNL C933C000073        CPI COMO         13 0.07831325
#>  6:  2024     A011   CCNL       FUORI Fuori Lombardia         10 0.06024096
#>  7:  2024     A011   CCNL E648C000580        CPI LODI          9 0.05421687
#>  8:  2024     A011   CCNL A794C000060     CPI BERGAMO          8 0.04819277
#>  9:  2024     A011   CCNL D150C000030     CPI CREMONA          7 0.04216867
#> 10:  2024     A011   CCNL G388C000070       CPI PAVIA          6 0.03614458
#> 11:  2024     A011   CCNL E897C000034     CPI MANTOVA          5 0.03012048
#> 12:  2024     A011   CCNL I829C000043     CPI SONDRIO          5 0.03012048
#> 13:  2024     A011   CCNL E507C000578       CPI LECCO          3 0.01807229
#> 14:  2024     H011   CCNL F205C000169      CPI MILANO         19 0.19791667
#> 15:  2024     H011   CCNL L682C000600      CPI VARESE         13 0.13541667
#> 16:  2024     H011   CCNL A794C000060     CPI BERGAMO         10 0.10416667
#> 17:  2024     H011   CCNL C933C000073        CPI COMO         10 0.10416667
#> 18:  2024     H011   CCNL F704C000581       CPI MONZA          9 0.09375000
#> 19:  2024     H011   CCNL B157C000683     CPI BRESCIA          8 0.08333333
#> 20:  2024     H011   CCNL       FUORI Fuori Lombardia          7 0.07291667
#> 21:  2024     H011   CCNL D150C000030     CPI CREMONA          5 0.05208333
#> 22:  2024     H011   CCNL E507C000578       CPI LECCO          5 0.05208333
#> 23:  2024     H011   CCNL E648C000580        CPI LODI          3 0.03125000
#> 24:  2024     H011   CCNL E897C000034     CPI MANTOVA          3 0.03125000
#> 25:  2024     H011   CCNL G388C000070       CPI PAVIA          3 0.03125000
#> 26:  2024     H011   CCNL I829C000043     CPI SONDRIO          1 0.01041667
#>      anno ccnl_key classe    cpi_code        cpi_name n_rapporti quota_riga
#>     <int>   <char> <char>      <char>          <char>      <int>      <num>
#>     quota_colonna        lq
#>             <num>     <num>
#>  1:    0.15625000 0.7991340
#>  2:    0.18897638 0.9665117
#>  3:    0.21904762 1.1203098
#>  4:    0.22784810 1.1653195
#>  5:    0.24074074 1.2312584
#>  6:    0.19230769 0.9835496
#>  7:    0.26470588 1.3538271
#>  8:    0.13793103 0.7054425
#>  9:    0.25925926        NA
#> 10:    0.23076923        NA
#> 11:    0.25000000        NA
#> 12:    0.27777778        NA
#> 13:    0.12000000        NA
#> 14:    0.08482143 0.7501395
#> 15:    0.10236220 0.9052657
#> 16:    0.17241379 1.5247845
#> 17:    0.18518519 1.6377315
#> 18:    0.11392405 1.0075158
#> 19:    0.07619048 0.6738095
#> 20:    0.13461538 1.1905048
#> 21:    0.18518519        NA
#> 22:    0.20000000        NA
#> 23:    0.08823529 0.7803309
#> 24:    0.15000000        NA
#> 25:    0.11538462        NA
#> 26:    0.05555556        NA
#>     quota_colonna        lq
#>             <num>     <num>
```
