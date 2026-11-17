# Array Fetch Sizing: When It Helps, When It Does Not, and How to Set It

Increasing the client fetch array size (also called prefetch, row cache size, or fetch size) eliminates network round trips (`SQL*Net message from client`, SNMFC). It only helps when a single execution of a query needs **more than one FETCH call** to return its rows. Before recommending an array size change, confirm that this is the case and that the predicted savings are material.

---

## 1. Recognizing Single-Row Queries (No Array Size Benefit)

A query that returns at most one row per execution needs exactly one FETCH and one round trip, no matter what the array size is. Many short SNMFC waits caused by such queries come from **executing the query many times** (a loop of single-row lookups), not from row-by-row fetching. Array sizing cannot remove them; only reducing the number of executions can (for example, replacing an N+1 lookup loop with a single set-based query or a join).

### Trace evidence

For a candidate SQL ID, compare EXEC calls, FETCH calls, and rows:

```bash
mrskew --name='^(EXEC|FETCH)$' --where='$sqlid eq q{<SQL_ID>}' --group='$nam' --select='$r' --sl=ROWS <tracefile>
```

The `ROWS` column on the `FETCH` line is total rows returned; `CALLS` gives the EXEC and FETCH counts.

| Pattern | Meaning | Array size helps? |
| :--- | :--- | :--- |
| rows/EXEC <= 1 and FETCH/EXEC ~ 1 | Single-row query | No |
| FETCH/EXEC ~ 1, any rows per fetch | All rows already returned in one round trip | No |
| FETCH/EXEC >> 1 and rows/FETCH small (1 to 15) | Row-by-row or small-array fetching | Yes |

Real examples from the same trace file:

```text
bmcwhtqtb8txd:  EXEC 3,  FETCH 837, rows 834   -> ~1 row per fetch, 279 fetches per exec: candidate
6c5uqrtpfdm7r:  EXEC 80, FETCH 80,  rows 2,425 -> 1 fetch per exec: no benefit
```

To see which SQL IDs return few rows per fetch (MEAN column = rows per fetch):

```bash
mrskew --name='^FETCH$' --group='$sqlid' --select='$r' --sl=ROWS --top=20 <tracefile>
```

A SQL ID with MEAN near 1 is a candidate **only** if it also shows many FETCH calls per EXEC; check with the first command above.

Note: OCI clients such as SQL*Plus commonly issue a first FETCH of 1 row, then fetch in arraysize batches. A `FETCH:0001` line in `fetch-rowcounts.rc` output therefore does not, by itself, prove a single-row query.

### SQL text indicators

These shapes normally return at most one row per execution:

- Equality predicates on a primary key or unique key (`WHERE id = :1`).
- Aggregates without `GROUP BY` (`SELECT COUNT(*) ...`, `SELECT MAX(...) ...`).
- `WHERE ROWNUM = 1`, `FETCH FIRST 1 ROW ONLY`.
- PL/SQL `SELECT ... INTO` (raises `TOO_MANY_ROWS` otherwise).
- `SELECT ... FROM DUAL`, sequence `NEXTVAL` fetches.

Use the SQL text as a hint and the trace counts as proof.

---

## 2. Estimating Savings with snmfc-savings-2.rc

`snmfc-savings-2.rc` (from `~/.mrtools/rc`) estimates how much SNMFC time a larger array size would remove:

```bash
mrskew --rc=snmfc-savings-2.rc <tracefile>
```

Output:

```text
       real SNMFC: 210.048653
      check SNMFC: 210.048653
  optimized SNMFC: 156.666177
       time saved: 53.382476
```

- `real SNMFC`: current SNMFC time (waits >= 1 second are excluded as think time).
- `optimized SNMFC`: predicted SNMFC time at the modeled array size.
- `time saved`: the estimate to report.

How it treats single-row queries: the rc computes savings **per execution** (`$sqlid:$exec_id`), and only FETCH round trips can be saved. For each execution, the new fetch count is `ceil(rows / MRTOOLS_ARRAYSIZE)` (at least 1), and the saved round trips are the current fetch count minus that. Executions returning 0 or 1 rows save nothing, and neither do round trips not tied to a FETCH (EXEC calls, PL/SQL, LOB calls). Single-row queries are therefore excluded from the estimate, even when they account for most of the SNMFC time. In the example above, 5,766 executions returning at most one row were assigned zero savings; the 53 seconds came from multi-row executions that fetched a few rows per round trip.

### Choosing MRTOOLS_ARRAYSIZE

The modeled array size defaults to 100 and is set with the `MRTOOLS_ARRAYSIZE` environment variable (for example `MRTOOLS_ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc <tracefile>`). Returns diminish quickly; on the example trace: 10 -> 48.8 s, 100 -> 53.4 s, 500 -> 54.3 s, 1000 -> 54.4 s. The default of 100 is usually the right recommendation. Versions of this rc before 2026-11-17 computed the new round-trip count incorrectly and reported smaller savings at larger array sizes; if a run shows savings falling as the array size grows, the rc is out of date. Older versions also read unprefixed variables (`ARRAYSIZE`, `DEBUG`); current versions only read the `MRTOOLS_` names.

If `mrskew` runs inside a container wrapper (for example `podman run ...`), environment variables such as `MRTOOLS_ARRAYSIZE` and `MRTOOLS_DEBUG` are only seen if the wrapper passes them in (for example `-e MRTOOLS_ARRAYSIZE`). Otherwise the default is used silently. If a changed `MRTOOLS_ARRAYSIZE` does not change the estimate, check the wrapper.

`MRTOOLS_DEBUG=1` prints per-execution detail on STDERR (row count, fetch count, SNMFC count and time, saved fetches), which is useful to show the user which executions drive the savings.

---

## 3. Deciding Whether to Recommend an Array Size Change

Compare `time saved` with the response time of the experience being analyzed, not with total SNMFC time. Get R with idle client time culled:

```bash
mrskew --rc=cull-snmfc.rc <tracefile> | tail -1
```

Default decision rule (adjust if the user gives a different threshold):

| Savings as % of culled R | Recommendation |
| :--- | :--- |
| < 5%, or less than about 1 second absolute | Do **not** recommend an array size change. State that SNMFC time is dominated by single-row or already-batched executions, and point to the real lever (fewer executions, or a different bottleneck). |
| 5% to 10% | Mention as a low-priority, low-risk option. |
| >= 10% | Recommend an array size change, with the predicted savings. |

Worked examples (same application, two sessions):

| Trace | Culled R | Real SNMFC | Time saved | % of R | Verdict |
| :--- | ---: | ---: | ---: | ---: | :--- |
| ora_1019 | 228.0 s | 210.0 s | 53.4 s | 23.4% | Recommend |
| ora_10001 | 27.7 s | 24.0 s | 3.1 s | 11.2% | Recommend (small absolute gain) |

In both, most SNMFC time came from single-row executions. The tuning conversation for that portion is about the number of executions, not about array size.

---

## 4. How to Set the Array Size

### In the application

| Client | Setting |
| :--- | :--- |
| SQL*Plus | `SET ARRAYSIZE n` (default 15) |
| JDBC | `Statement.setFetchSize(n)`, or connection property `defaultRowPrefetch` (default 10) |
| Python python-oracledb / cx_Oracle | `cursor.arraysize`, `cursor.prefetchrows`, or `oracledb.defaults.arraysize` |
| Perl DBD::Oracle | `$dbh->{RowCacheSize} = n` |
| ODP.NET | `OracleCommand.FetchSize` / `OracleDataReader.FetchSize` (bytes, often set via `RowSize * n`) |
| PL/SQL | `BULK COLLECT INTO ... LIMIT n` |

### Without changing code: oraaccess.xml

When the application source cannot be changed, Oracle client libraries read a default prefetch row count from `oraaccess.xml`:

```xml
<?xml version="1.0" encoding="ASCII" ?>
 <oraaccess xmlns="http://xmlns.oracle.com/oci/oraaccess"
  xmlns:oci="http://xmlns.oracle.com/oci/oraaccess"
  schemaLocation="http://xmlns.oracle.com/oci/oraaccess
  http://xmlns.oracle.com/oci/oraaccess.xsd">
  <default_parameters>
    <prefetch>
      <rows>100</rows>
    </prefetch>
  </default_parameters>
</oraaccess>
```

- Location: `$ORACLE_HOME/network/admin`, or the directory named by `TNS_ADMIN`. Pointing `TNS_ADMIN` at a directory containing a different `oraaccess.xml` changes the setting for just the processes started with that environment, which is a convenient way to test.
- Works for applications that use the Oracle client libraries (OCI): SQL*Plus, Perl DBD::Oracle, Python cx_Oracle and python-oracledb in Thick mode, the JDBC OCI (thick) driver, and C, C++, COBOL, Fortran, Pro*C programs linked with Oracle libraries.
- Does **not** work for clients that do not use the Oracle client libraries, such as the JDBC Thin driver or python-oracledb in Thin mode. Use the application settings above instead.
- An array size set explicitly by the application may take precedence over the `oraaccess.xml` default, so always verify the effect with a new trace.

### Verifying the change

Trace the same workload before and after, and compare FETCH row counts and SNMFC counts:

```bash
mrskew --rc=fetch-snmfc.rc before.trc
mrskew --rc=fetch-snmfc.rc after.trc
```

If the traces contain idle client think time, add `--where='$af < 1'` to exclude SNMFC waits of 1 second or more.

Example from a 100,000-row SQL*Plus query (reference: https://github.com/jkstill/oraaccess-xml):

| Prefetch rows | SNMFC calls | SNMFC time |
| ---: | ---: | ---: |
| default (arraysize 15) | 6,671 | 2.646 s |
| 100 | 956 | 1.663 s |
| 500 | 200 | 1.525 s |
| 1000 | 103 | 1.486 s |

Gains diminish quickly beyond about 100 rows; larger values matter mainly for very large result sets.
