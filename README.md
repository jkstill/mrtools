
mrtools rc files
================


## FlameGraphs

Generate data for flamegraphs.

It is still a WIP, as it needs to overlay dep > 0 onto to ExecID for graphing

call-db-flamegraph.rc
call-os-flamegraph.rc
calls-flamegraph.rc

See /home/jkstill/oracle/flamegraph/sqltrace

## calls totaled

Running total of time per ExecID

calls-totaled-2.rc
calls-totaled.rc

```text
$  mrskew --rc=calls-totaled-2.rc  oracle-trace/PR121CDB1_ora_13763210.trc| head -20
          END-TIM       LINE   PARSE-ID    EXEC-ID  CALL-NAME(BOUND-VALUES)                  STATEMENT-TEXT                                                Elapsed         Total
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  12869270.682991         26          0          0  CLOSE                                    #4860492832:oracle-trace/PR121CDB1_ora_13763210.trc          0.000032
  12869270.695357         31         31          0  PARSE                                    UPDATE ft_t_ispc SET prc_valid_typ = 'IGNORE', last_chg_tms  0.002057
  12869270.712373         37         37          0  · PARSE                                  · select default$ from col$ where rowid=:1                   0.013573      0.002089
  12869270.725002         44         37         44  · EXEC(000A6257.001B.0001)               · select default$ from col$ where rowid=:1                   0.012273
  12869270.725148         45         37         44  · FETCH(000A6257.001B.0001)              · select default$ from col$ where rowid=:1                   0.000067
  12869270.725336         47         37         44  · CLOSE(000A6257.001B.0001)              · select default$ from col$ where rowid=:1                   0.000061
  12869270.725600         52         52          0  · PARSE                                  · select default$ from col$ where rowid=:1                   0.000096
  12869270.725787         59         52         59  · EXEC(000A6257.001C.0001)               · select default$ from col$ where rowid=:1                   0.000080
  12869270.725866         60         52         59  · FETCH(000A6257.001C.0001)              · select default$ from col$ where rowid=:1                   0.000011
  12869270.725930         62         52         59  · CLOSE(000A6257.001C.0001)              · select default$ from col$ where rowid=:1                   0.000026
  12869270.833598         69         69          0  · PARSE                                  · select default$ from col$ where rowid=:1                   0.000072
  12869270.833926         76         69         76  · EXEC(000A6257.001B.0001)               · select default$ from col$ where rowid=:1                   0.000125
  12869270.833999         77         69         76  · FETCH(000A6257.001B.0001)              · select default$ from col$ where rowid=:1                   0.000048
  12869270.834249         79         69         76  · CLOSE(000A6257.001B.0001)              · select default$ from col$ where rowid=:1                   0.000091
  12869270.834328         80         80          0  · PARSE                                  · select default$ from col$ where rowid=:1                   0.000010
  12869270.834436         87         80         87  · EXEC(000A6257.001C.0001)               · select default$ from col$ where rowid=:1                   0.000075
  12869270.834468         88         80         87  · FETCH(000A6257.001C.0001)              · select default$ from col$ where rowid=:1                   0.000010
  12869270.834517         89         80         87  · CLOSE(000A6257.001C.0001)              · select default$ from col$ where rowid=:1                   0.000007

```

## filter SQL*Net message from client

Shortcut to filter out snmfc >= 1


```text
$  mrskew   oracle-trace/PR121CDB1_ora_13763210.trc| head -20
CALL-NAME                      DURATION       %   CALLS      MEAN       MIN       MAX
---------------------------  ----------  ------  ------  --------  --------  --------
SQL*Net message from client   80.182221   58.4%  12,782  0.006273  0.000648  2.036439
db file sequential read       27.601162   20.1%   5,242  0.005265  0.000317  0.111130
EXEC                          18.999343   13.8%  12,553  0.001514  0.000022  5.198113
db file parallel read          2.905991    2.1%      85  0.034188  0.003904  0.069272
FETCH                          1.544917    1.1%   7,215  0.000214  0.000001  0.022617
gc cr grant 2-way              0.784706    0.6%     437  0.001796  0.000108  0.039396
reliable message               0.618710    0.5%      45  0.013749  0.001720  0.105679
db file scattered read         0.588855    0.4%      60  0.009814  0.000704  0.026136
PARSE                          0.470172    0.3%   4,274  0.000110  0.000006  0.108622
gc cr multi block request      0.447996    0.3%     128  0.003500  0.000805  0.057960
48 others                      3.268945    2.4%  20,163  0.000162  0.000000  0.081381
---------------------------  ----------  ------  ------  --------  --------  --------
TOTAL (58)                   137.413018  100.0%  62,984  0.002182  0.000000  5.198113
```

### With cull-snmfc.rc

```text
$  mrskew --rc=cull-snmfc.rc  oracle-trace/PR121CDB1_ora_13763210.trc| head -20
CALL-NAME                      DURATION       %   CALLS      MEAN       MIN       MAX
---------------------------  ----------  ------  ------  --------  --------  --------
SQL*Net message from client   73.110425   56.1%  12,777  0.005722  0.000648  0.161816
db file sequential read       27.601162   21.2%   5,242  0.005265  0.000317  0.111130
EXEC                          18.999343   14.6%  12,553  0.001514  0.000022  5.198113
db file parallel read          2.905991    2.2%      85  0.034188  0.003904  0.069272
FETCH                          1.544917    1.2%   7,215  0.000214  0.000001  0.022617
gc cr grant 2-way              0.784706    0.6%     437  0.001796  0.000108  0.039396
reliable message               0.618710    0.5%      45  0.013749  0.001720  0.105679
db file scattered read         0.588855    0.5%      60  0.009814  0.000704  0.026136
PARSE                          0.470172    0.4%   4,274  0.000110  0.000006  0.108622
gc cr multi block request      0.447996    0.3%     128  0.003500  0.000805  0.057960
48 others                      3.268945    2.5%  20,163  0.000162  0.000000  0.081381
---------------------------  ----------  ------  ------  --------  --------  --------
TOTAL (58)                   130.341222  100.0%  62,979  0.002070  0.000000  5.198113
```

## Breakdown of Fetch Sizes

fetch-rowcounts.rc

```text
$  mrskew --rc=fetch-rowcounts.rc  oracle-trace/PR121CDB1_ora_13763210.trc| head -20
  CALL:NNNN  DURATION       %   CALLS      MEAN       MIN       MAX
-----------  --------  ------  ------  --------  --------  --------
  EXEC:0001  2.897547   56.1%   4,713  0.000615  0.000052  0.155081
 FETCH:0000  0.316985    6.1%   6,520  0.000049  0.000001  0.010289
 FETCH:0100  0.316829    6.1%      20  0.015841  0.001237  0.022617
 FETCH:0075  0.184392    3.6%      42  0.004390  0.001067  0.016441
  EXEC:0002  0.144265    2.8%     169  0.000854  0.000335  0.010977
  EXEC:0005  0.113551    2.2%      32  0.003548  0.001133  0.035344
 FETCH:0001  0.092754    1.8%     303  0.000306  0.000013  0.001143
 FETCH:0025  0.088184    1.7%      41  0.002151  0.000583  0.006376
  EXEC:0004  0.060520    1.2%      34  0.001780  0.000466  0.006922
  EXEC:0025  0.059734    1.2%     124  0.000482  0.000135  0.003306
116 others   0.892174   17.3%     451  0.001978  0.000102  0.021697
-----------  --------  ------  ------  --------  --------  --------
TOTAL (126)  5.166935  100.0%  12,449  0.000415  0.000001  0.155081
```

## Gap Check

I do not remember...

gap-check.rc

## SNMFC Savings

### snmfc-savings-2.rc

Estimate how much SNMFC time will be reduced by alter array size

### snmfc-savings.rc

Estimate how much SNMFC time will be reduced by alter array size

Overly complicated.  snmfc-savings-2.rc works much better.

## Break down time by SQLID

sqlid.rc

```text
$  mrskew --rc=sqlid.rc  oracle-trace/PR121CDB1_ora_13763210.trc
$sqlid . q{:} . substr($sql,0,60)                                             DURATION       %   CALLS      MEAN       MIN       MAX
--------------------------------------------------------------------------  ----------  ------  ------  --------  --------  --------
ctq4c0u0bnn6q:select goldenpric0_.GPRC_OID as GPRC1_164_, goldenpric0_.GPR   24.405859   18.7%  13,873  0.001759  0.000001  1.029060
7qga2tfjkvws5:select goldenpric0_.GPRC_OID as GPRC1_164_0_, price1_.ISS_PR   14.189187   10.9%   1,876  0.007564  0.000003  5.198113
8nj2b2vf56j5r:insert into FT_T_MPRC (ADDNL_PRC_QUAL_TYP, MISSING_PRC_CMNT_   12.560766    9.6%   8,885  0.001414  0.000002  0.111130
1f25cuh1kyn8r:SELECT PRIM_TRD_MKT_IND FROM FT_T_MKIS WHERE MKT_OID=:1 AND    12.257196    9.4%   9,598  0.001277  0.000002  0.064212
b1x9rh1kuz5fm:insert into FT_TMP_PCST (ISS_PRC_ID) values (:1 )              11.560900    8.9%   7,245  0.001596  0.000001  0.061526
7fsmqtu9z49uf:insert into FT_T_GPRC (GPRC_GT_1_CANDIDATE_IND, DWDF_OID, EN    4.530551    3.5%   2,172  0.002086  0.000003  0.054976
24fphhhf9y5f1:select price0_.ISS_PRC_ID as ISS1_169_0_, price0_.ADDNL_PRC_    3.143737    2.4%   1,147  0.002741  0.000003  0.084325
348pkxd0rrdss:SELECT /* DS_SVC */ /*+ dynamic_sampling(0) no_sql_tune no_m    2.584528    2.0%     308  0.008391  0.000002  0.060719
frtcpz662ybtt:insert into FT_WF_WFRV (VARIABLE_ID, VARIABLE_NME, VARIABLE_    2.300572    1.8%   1,722  0.001336  0.000001  0.052605
33hv3kf4s76pk:select price0_.ISS_PRC_ID as ISS1_169_, price0_.ADDNL_PRC_QU    2.018530    1.5%     283  0.007133  0.000004  0.957387
125 others                                                                   40.789396   31.3%  15,870  0.002570  0.000000  1.136773
--------------------------------------------------------------------------  ----------  ------  ------  --------  --------  --------
TOTAL (135)                                                                 130.341222  100.0%  62,979  0.002070  0.000000  5.198113
```

## Examples

mrskew --rc=calls-totaled.rc trace-2023-06-16/TDFPRD1_ora_61207.trc


