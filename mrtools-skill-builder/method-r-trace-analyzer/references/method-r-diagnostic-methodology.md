# Method R Diagnostic Methodology & Performance Principles

This document provides the foundational engineering principles and diagnostic methodology created by Cary Millsap and Jeff Holt (Method R Corporation). AI agents and human performance analysts must use these principles to interpret Oracle trace profiles, diagnose performance bottlenecks, and formulate actionable tuning recommendations.

---

## 1. The Core Principles of Method R

### The Response Time Model
Method R is named for **$R$**, which stands for **Response Time**. Every performance experience is fundamentally either a response time experience (how long a user waits for a task to complete) or a throughput experience (how many tasks complete per unit of time). Throughput is mathematically governed by response time:
$$\text{Throughput} \le \frac{\text{Concurrency}}{R}$$

In an Oracle extended SQL trace file, total response time $R$ is the sum of the durations of every database call and operating system call executed during the measured task:
$$R = \sum_{i=1}^{n} \text{duration}_i$$

Where:
- **dbcalls (database calls)**: Internal Oracle kernel calls reported as `PARSE`, `EXEC`, `FETCH`, `CLOSE`, `LOBREAD`, `XCTEND`, etc. Their duration is measured in CPU time ($c$) and elapsed time ($e$).
- **syscalls / oscalls (operating system calls)**: Operating system calls reported as `WAIT` lines (e.g., `db file sequential read`, `SQL*Net message from client`, `log file sync`). Their duration is reported as elapsed time ($ela$).

### The Three Axioms of Performance
1. **Axiom 1: To improve a system, you must measure what matters.**
   - Measure the user's response time experience directly.
   - Do **not** attempt to optimize a system by focusing on component utilization (CPU %, disk %, memory %), cache hit ratios, or system-wide average wait events. A system with a 99% buffer cache hit ratio can still deliver unacceptably slow queries.
2. **Axiom 2: You cannot guess where your program spends its time; you must measure it.**
   - Intuitive guesses by even the most experienced developers and DBAs routinely fail.
   - Only a high-precision profile derived from trace data provides an irrefutable invoice of where every microsecond was spent.
3. **Axiom 3: The fastest call is no call.**
   - While optimizing a call (e.g., speeding up a disk read from 5 ms to 1 ms) reduces latency, **eliminating** the call entirely drops its duration and CPU overhead to zero.
   - Eliminating calls is the single most powerful and durable performance optimization strategy.

### The Four Fundamental Diagnostic Questions
Every performance diagnosis iterates over four questions:
1. **How long?** What was the exact measured duration of the user experience?
2. **Why?** How was that time accounted for across dbcalls and syscalls? (The Response Time Profile).
3. **What if?** If we eliminate or alter specific calls, how will response time react? (Predicting impact).
4. **What else?** Can we further improve the experience, or has it reached unconstrained hardware speed?

### When Is a System Optimized?
An application task is economically optimal when:
1. The software makes **no unnecessary calls** (e.g., no redundant parses, no row-by-row round trips, no unnecessary block visits).
2. The calls that remain execute at **unconstrained hardware speed**.

---

## 2. Amdahl's Law and Bottleneck Focus

Amdahl's Law dictates that the maximum possible speedup of any system is limited by the fraction of time spent on the component being optimized:
$$S_{\text{overall}} = \frac{1}{(1 - f) + \frac{f}{S}}$$

Where $f$ is the fraction of total response time consumed by the target component, and $S$ is its speedup factor.

### Rule of Action
- **Always target the top line of the profile (the bottleneck) first.**
- If a query takes 100 seconds and spends 95 seconds on `FETCH` dbcalls and 2 seconds on `db file sequential read`, tuning disk I/O can never save more than 2 seconds (at most 2% improvement). Eliminating unnecessary fetch work can save up to 95 seconds (a 20x improvement).
- Never spend engineering effort tuning an event or SQL statement that accounts for a negligible percentage of the target experience.

---

## 3. The Ten-LIO Rule of Thumb

The **Ten-LIO Rule of Thumb** (formulated by Jeff Holt and Cary Millsap) is the standard heuristic for evaluating SQL execution efficiency in transactional systems:

> **Rule:** If a database call motivates more than approximately **10 logical I/O (LIO) visits per row returned per table** in the `FROM` clause of the query, the SQL statement's efficiency can almost certainly be improved.
>
> $$\text{Acceptable LIO} \approx 10 \times (\text{Number of tables in FROM clause}) \times (\text{Rows returned})$$

### Rationale
- 10 LIOs is a generous upper bound for traversing an efficient B-tree index:
  - 1-3 root and branch block visits.
  - 1 leaf block visit.
  - 1 table block visit (or 2-3 in cases of row migration/chaining).
- For a single-table lookup returning 1 row: $\le 10$ LIOs.
- For a 3-table join returning 5 rows: $\le 10 \times 3 \times 5 = 150$ LIOs.

### Trace Calculation
In `mrskew`, LIO is defined as `$lio = $cr + $cu`:
- `$cr`: Buffer cache visits in consistent read mode.
- `$cu`: Buffer cache visits in current mode.

Run:
```bash
mrskew --where='$sqlid eq "<TARGET_SQLID>"' --select='$lio' --sl='"LIO"' <tracefile>
mrskew --where='$sqlid eq "<TARGET_SQLID>"' --select='$row' --sl='"ROWS"' <tracefile>
```
Compute: $\text{Ratio} = \frac{\text{LIO}}{\text{ROWS}}$.

### Legitimate Exceptions
The 10-LIO rule does **not** apply to:
1. **Aggregations**: A query like `SELECT COUNT(*) FROM large_table` legitimately scans millions of blocks to return 1 row.
2. **`DISTINCT` / `GROUP BY`**: Queries where the database must process thousands of rows before deduplicating them into a small result set.
3. **Data warehouse analytical scans**: Broad analytical queries designed for direct-path or full-table scans.

---

## 4. Key Performance Antipatterns & Diagnostic Recipes

### Antipattern 1: Row-by-Row Fetching (N+1 Network Round Trips)
- **Symptom in Trace**:
  - High proportion of total duration in `SQL*Net message from client` with very short individual durations (e.g., 0.2ms - 5ms).
  - High `FETCH` call counts approximately equal to row count ($r \approx 1$ per fetch).
  - High ratio of network round trips to rows returned.
- **Root Cause**: Client application loop fetching rows one at a time (e.g., default JDBC/ODBC array size of 1 or 10) instead of batch/array fetching.
- **Actionable Remedy**:
  - Increase the client-side fetch array size (`defaultRowPrefetch` in JDBC, `arraysize` in Python/cx_Oracle/oracledb, `FETCH FIRST n ROWS` or bulk arrays in C#/ODP.NET) to 100 or 500.
  - In PL/SQL, use `BULK COLLECT INTO ... LIMIT 500`.
- **Expected Impact**: Reduces network round trips and wait durations by 90-98%, slashing client latency.

### Antipattern 2: Unnecessary Full Table / Index Scans (Missing or Ineffective Index)
- **Symptom in Trace**:
  - Profile dominated by `db file scattered read` (multi-block physical reads) or high `FETCH`/`EXEC` CPU duration with massive `$lio` values.
  - Severe violation of the 10-LIO rule (thousands of LIOs per row returned).
- **Root Cause**:
  - Missing index on filtered columns.
  - Implicit data type conversion in the `WHERE` clause (e.g., `WHERE varchar_col = 1234` causing Oracle to evaluate `TO_NUMBER(varchar_col) = 1234`, disabling index usage).
  - Leading wildcard in `LIKE '%text%'`.
  - Stale optimizer statistics leading to bad cardinalities.
- **Actionable Remedy**:
  - Review execution plan in trace or via `V$SQL_PLAN`.
  - Create targeted index or composite index on filter columns.
  - Fix implicit type conversion by aligning parameter data types.

### Antipattern 3: Unshareable SQL & Hard Parse Storms
- **Symptom in Trace**:
  - `PARSE` dbcalls consume significant response time.
  - High count of hard parses (`$mis > 0`) with mean parse durations of 5ms - 100ms+.
  - Secondary symptom: waits on `latch: shared pool` or `latch: library cache`.
  - Grouping by shareable SQL ID (`$ssqlid`) reveals dozens or hundreds of distinct text variations (`distinct-texts.rc`).
- **Root Cause**: Literal values hardcoded into SQL strings instead of using bind variables (e.g., `WHERE id = 101` vs `WHERE id = :b1`).
- **Actionable Remedy**:
  - Refactor application SQL to use parameterized queries and bind variables.
  - Temporary database mitigation: Set `CURSOR_SHARING = FORCE` (with caution).

### Antipattern 4: Excessive Commit Frequency (Auto-Commit)
- **Symptom in Trace**:
  - High duration spent on `log file sync` syscalls.
  - High count of `XCTEND` dbcalls relative to rows modified.
- **Root Cause**: Application committing after every single insert/update (e.g., ORM auto-commit mode enabled).
- **Actionable Remedy**:
  - Group DML operations into business units of work and commit once per transaction.
  - Disable autocommit in application connection pools.

### Antipattern 5: Storage Latency Skew
- **Symptom in Trace**:
  - Profile shows significant time on `db file sequential read`, but the number of calls is modest while individual call durations are abnormally high (>10ms - 50ms+).
  - Skew histogram (`mrskew --rc=p10.rc` or `--rc=ssd.rc`) shows reads clustering in high millisecond buckets.
- **Root Cause**: SAN/storage bottleneck, queue depth saturation, disk head contention, or noisy neighbors.
- **Actionable Remedy**:
  - Identify specific files and blocks with skew:
    ```bash
    mrskew --name='db file sequential read' --group='sprintf("%d:%d", $p1, $p2)' --top=10 <tracefile>
    ```
  - Map file ID ($p1) to tablespace/datafile via `DBA_DATA_FILES`.
  - Investigate storage array metrics or relocate hot files to faster storage tiers.

### Antipattern 6: Connection Pool "Oceans" (Idle Time Dilution)
- **Symptom in Trace**:
  - Trace file shows 99%+ of time in `SQL*Net message from client`, with total file duration spanning hours or days.
  - Misleading total response time masks real transaction bottlenecks.
- **Root Cause**: Trace file captures a persistent database connection in a pool, including idle time between user requests.
- **Actionable Remedy**:
  - Apply the Oceans-Islands-Rivers algorithm:
    ```bash
    mrskew --rc=island.rc <tracefile>
    ```
  - Crop the trace into standalone user experiences using `mrcrop island -z=1.0 <tracefile>`.
  - Analyze the individual active islands.

### Antipattern 7: Unaccounted-For Time
- **Symptom in Trace**:
  - Significant gap between recorded elapsed time ($e$) and the sum of CPU ($c$) plus wait time ($ela$):
    $$uafwc = e - (c + ela)$$
- **Root Cause**:
  - OS CPU starvation (operating system scheduling latency / process preemption).
  - Virtual machine / hypervisor CPU steal (noisy neighbor VMs).
  - Paging / memory swapping.
- **Actionable Remedy**:
  - Check host CPU utilization (`vmstat`, `sar`, `mpstat`).
  - Verify if CPU contention or hypervisor overcommit is occurring.
  - Optimize CPU consumption of top processes to reduce queueing delay.

---

## 5. Predicting Performance Improvements

Before recommending or deploying any code change, calculate the mathematical prediction of the outcome:

$$R_{\text{predicted}} = R_{\text{current}} - \Delta R_{\text{eliminated}} - \Delta R_{\text{reduced}}$$

### Example: Tuning Row-by-Row Fetch
- **Current Measurement**:
  - 10,000 FETCH calls: 0.5s CPU.
  - 10,000 `SQL*Net message from client` calls: 15.0s (mean 1.5ms).
  - Total time: 15.5s to retrieve 10,000 rows.
- **Proposed Remedy**: Set array size to 100.
  - New FETCH call count: $\frac{10000}{100} = 100$ calls.
  - New network round trips: 100 calls.
- **Predicted Response Time**:
  - Network wait: $100 \times 1.5\text{ms} = 0.15\text{s}$.
  - CPU time: ~$0.1\text{s}$.
  - Predicted $R$: $0.25\text{s}$ (down from 15.5s, a 60x improvement!).

Always present predictions with this clear mathematical formulation so stakeholders understand the exact return on investment.
