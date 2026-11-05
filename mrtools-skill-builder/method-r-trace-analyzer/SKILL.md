---
name: method-r-trace-analyzer
description: Analyzes Oracle extended SQL trace files using Method R tools (mrskew, mrcrop, mrkey, mrwhen, mr1011) and Cary Millsap's performance methodology. Use when profiling response times, diagnosing wait events and resource consumption (CPU, LIO, PIO), scoping trace files into user experiences, identifying bottlenecks, or providing SQL tuning recommendations.
---

# Method R Trace Analyzer

Analyze Oracle extended SQL trace files (`.trc`) using Method R Workbench command-line tools and Cary Millsap's performance engineering principles. This skill enables AI agents to autonomously diagnose Oracle SQL performance, interpret trace profiles, answer user inquiries about wait events and resource consumption, and provide human users with exact CLI commands and actionable tuning recommendations.

---

## Method R Performance Philosophy

Method R is named for **$R$ (Response Time)**. The framework is grounded in three foundational axioms:

1. **Axiom 1: To improve a system, measure what matters.** Measure the response time of the user's specific experience, not aggregate subsystem utilization, CPU percentages, or cache hit ratios.
2. **Axiom 2: You cannot guess where your program spends its time; you must measure it.** Intuitive guesses fail; only a high-precision profile derived from trace data provides an irrefutable invoice of time.
3. **Axiom 3: The fastest call is no call.** Eliminating calls entirely (e.g., redundant parses, row-by-row network round trips, unnecessary block visits) is vastly more effective than merely speeding them up.

**The Response Time Equation**:
$$R = \sum \text{dbcalls} + \sum \text{syscalls}$$
An application is economically optimal when: (1) it makes **no unnecessary calls**, and (2) the remaining calls run at **unconstrained hardware speed**.

For in-depth principles and mathematical derivations, see [Method R Diagnostic Methodology](references/method-r-diagnostic-methodology.md).

---

## Tool Suite Catalog

Method R Workbench provides five specialized command-line utilities:

| Tool | Primary Purpose | Key Use Cases |
| :--- | :--- | :--- |
| `mrskew` | Profile generator, aggregator, and metric analyzer. | Subroutine profiling, SQL ranking, LIO/PIO analysis, skew detection, histogram bucketing. |
| `mrcrop` | Trace cropper and experience isolator. | Extracting user experiences from connection pools (`island`), date ranges, SQL IDs, or transactions. |
| `mrkey` | Column-1 key extractor for pipelines. | Chaining `mrskew` outputs into automated drill-down loops (e.g., extracting top SQL IDs). |
| `mrwhen` | Microsecond `tim` to ISO 8601 translator. | Translating raw microsecond timestamps into wall-clock timestamps; inspecting call concurrency. |
| `mr1011`| Legacy trace file converter. | Upgrading older pre-11g trace files into modern format with synthesized `sqlid` and `plh`. |

### Advanced RC Files (~/.mrtools/rc)
Method R tools automatically search `MRTOOLS_RCPATH` (configured as `~/.mrtools/rc:/usr/share/mrtools/rc`). The repository in `~/.mrtools/rc` includes specialized diagnostic shortcuts:
- `cull-snmfc.rc`: Excludes idle client think-time ($\ge 1\text{s}$), isolating active work in one step.
- `cull-idle.rc`: Filters out 80+ Oracle background/idle wait events for database-level traces.
- `sqlid.rc`: Ranks top SQL statements (`$sqlid:substr($sql,0,60)`) with automatic idle culling.
- `fetch-rowcounts.rc`: Profiles dbcalls by row count (`EXEC:0001`, `FETCH:0025`) to audit fetch array sizing.
- `snmfc-savings-2.rc`: Interactively models time saved by increasing array size (`ARRAYSIZE=500`).
- `sequential-read-dups.rc`: Detects multiple reads of identical blocks and calculates potential I/O time saved.
- `calls-totaled-2.rc`: Emits chronological execution narrative with timestamps, SQL IDs, and subcall totals.

---

## Standard Diagnostic Workflow Decision Tree

When presented with one or more Oracle trace files, follow this 5-step diagnostic workflow:

```text
[Input Trace File]
       │
       ▼
[Step 1: Check Scoping & Connection Pooling]
  ├─► Check user experiences: mrskew --rc=island.rc <file>
  ├─► Instant idle cull:      mrskew --rc=cull-snmfc.rc <file>
  └─► Crop physical files:    mrcrop island -z=1.0 <file>
       │
       ▼
[Step 2: Generate Response Time Profile]
  └─► Run: mrskew <file> (or mrskew --rc=cull-snmfc.rc <file>)
      Identify Top Line (The Bottleneck) per Amdahl's Law:
      ├─► Dominant event is SQL*Net message from client?
      │     └─► Short durations (<10ms)? ──► Row-by-Row Fetch Antipattern (Step 4A)
      │     └─► Long durations (>1s)?    ──► Idle Think Time / Unscoped Trace (Step 1)
      ├─► Dominant event is FETCH / EXEC CPU?
      │     └─► High LIO count?          ──► Inefficient Index / Full Scan (Step 4B)
      ├─► Dominant event is PARSE?       ──► Unshareable Literal SQL Storm (Step 4C)
      ├─► Dominant event is db file seq/scat read?
      │     └─► High single-block latency ─► Storage Latency Skew (Step 4D)
      └─► Dominant event is log file sync? ─► Commit Frequency / Auto-Commit (Step 4E)
       │
       ▼
[Step 3: Identify & Rank SQL Statements]
  ├─► Ranked with SQL text & idle cull: mrskew --rc=sqlid.rc <file>
  └─► Ranked by duration:               mrskew --group='$sqlid' --where1=1 --top=5 <file>
       │
       ▼
[Step 4: Deep-Dive Root Cause Analysis for Target SQL ID]
  ├─► Check Ten-LIO Rule:      mrskew --where='$sqlid eq "<ID>"' --select='$lio' / --select='$row'
  ├─► Check Array Sizing:      mrskew --rc=fetch-rowcounts.rc <file>
  ├─► Model Array Size Savings:ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc <file>
  ├─► Check Binds:             mrskew --where='$sqlid eq "<ID>"' --group='join(",",@bind)'
  ├─► Check Duplicate Reads:   mrskew --rc=sequential-read-dups.rc <file>
  └─► Check Parse Skew:        mrskew --rc=distinct-texts.rc <file>
       │
       ▼
[Step 5: Formulate Remedies & Predict Performance Improvement]
  └─► Calculate: R_new = R_old - (eliminated call durations)
```

---

## Core Diagnostic Recipes

### 1. Response Time Profiling
Generate the overall response time profile (dbcalls and wait events at `$dep==$depmin`):
```bash
mrskew <tracefile>
```
Break down time between Database Calls (CPU/internal) and Operating System Waits:
```bash
mrskew --group='$is_dbcall ? "DATABASE CALL (CPU)" : "SYSTEM CALL (OS Wait)"' <tracefile>
```
Profile only operating system wait events:
```bash
mrskew --name=:syscall <tracefile>
```

### 2. Scoping Connection Pools (Oceans & Islands)
Identify individual user experiences separated by client think-time ($\ge 1.0\text{s}$):
```bash
mrskew --rc=island.rc <tracefile>
```
Isolate a specific user experience (e.g., island starting at line 3326):
```bash
# Option A: In-place filter
mrskew --where='$island_id == 3326' <tracefile>

# Option B: Physical cropping into standalone trace files
mrcrop island -z=1.0 <tracefile>
```
For complete cropping options, see [mrcrop Reference Guide](references/mrcrop-reference.md).

### 3. Identifying Bottleneck SQL Statements
Rank SQL statements by accounted-for duration (elapsed time):
```bash
mrskew --group='$sqlid' --where1=1 --top=10 <tracefile>
```
Rank SQL statements by first 60 characters of SQL text:
```bash
mrskew --group='substr($sql,0,60)' --gl='"SQL-TEXT"' --where1=1 --top=10 <tracefile>
```
Rank by resource consumption:
```bash
# By CPU seconds:
mrskew --group='$sqlid' --select='$cpu' --sl='"CPU"' --where1=1 <tracefile>

# By Logical I/O (buffer gets: $cr + $cu):
mrskew --group='$sqlid' --select='$lio' --sl='"LIO"' --where1=1 <tracefile>

# By Physical Disk Blocks Read:
mrskew --group='$sqlid' --select='$pio' --sl='"PIO"' --where1=1 <tracefile>
```

### 4. Evaluating the Ten-LIO Rule of Thumb
The Ten-LIO rule states that an efficient query in an OLTP/transactional system should not require more than **~10 buffer visits ($lio) per row returned per table** in the `FROM` clause:
$$\text{LIO Ratio} = \frac{\$lio}{\$row} \le 10 \times (\text{tables in FROM clause})$$

Run:
```bash
mrskew --where='$sqlid eq "<SQL_ID>"' --select='$lio' --sl='"LIO"' <tracefile>
mrskew --where='$sqlid eq "<SQL_ID>"' --select='$row' --sl='"ROWS"' <tracefile>
```
- If $\text{Ratio} \le 10$: Efficient access path.
- If $\text{Ratio} \gg 10$ (e.g., hundreds or thousands): Inefficient index, missing index, full table scan, or unselective predicate.
*(Exceptions: Aggregations like `COUNT(*)` or `SUM()`, `DISTINCT`, or bulk data warehouse scans).*

### 5. Detecting Row-by-Row Fetching
When an application uses default array sizes (e.g., 1 or 10 rows), it incurs a network round trip (`SQL*Net message from client`) for every batch.
```bash
mrskew --where='$sqlid eq "<SQL_ID>"' <tracefile>
```
*Indicator*: If `FETCH` count and `SQL*Net message from client` count are large and nearly identical to rows returned, array fetching is not configured.
*Remedy*: Increase client-side fetch array size (`defaultRowPrefetch`, `arraysize`, or PL/SQL `BULK COLLECT LIMIT`) to 100 or 500.

### 6. Diagnosing Hard Parsing & Unshareable SQL
Detect if literal values are preventing SQL statement sharing in the library cache:
```bash
# Count distinct SQL texts per synthesized shareable SQL ID:
mrskew --rc=distinct-texts.rc <tracefile>

# Profile hard parses ($mis > 0) vs soft parses:
mrskew --name=parse --group='$mis > 0 ? "Hard Parse (Miss)" : "Soft Parse"' <tracefile>
```
*Remedy*: Replace literal SQL strings with bind variables (`:b1`).

### 7. Storage Latency Skew
Analyze physical I/O latency distribution across power-of-10 partitions:
```bash
mrskew --name='db file sequential read' --rc=p10.rc <tracefile>
```
Identify the hot datafiles and blocks:
```bash
mrskew --name='db file sequential read' --group='sprintf("%d:%d", $p1, $p2)' --top=10 <tracefile>
```

### 8. Chained Pipelines with mrkey
Extract the top SQL ID and immediately drill into its call breakdown:
```bash
TOP_SQL=$(mrskew --group='$sqlid' --where1=1 <tracefile> | mrkey -r 1)
mrskew --where='$sqlid eq "'"$TOP_SQL"'"' <tracefile>
```
For auxiliary tool details, see [Auxiliary Tools Reference Guide](references/auxiliary-tools-reference.md).

For more copy-pasteable commands, see [Recipes & Cheatsheet](references/recipes-and-cheatsheet.md).

---

## Assisting Human Users

When interacting with a human user:
1. **Provide Clear, Copy-Pasteable Commands**: Always provide exact shell commands with correct quoting.
2. **Explain the Output Columns**: Guide the user to look at `DURATION` and `%` first to identify the dominant bottleneck before analyzing call counts or means.
3. **Avoid Jargon Surprises**: Clarify the difference between dbcalls (`PARSE`, `EXEC`, `FETCH`) and syscalls/wait events (`WAIT` lines).
4. **Predict the Return on Investment**: Provide before-and-after response time predictions using the formula:
   $$R_{\text{predicted}} = R_{\text{current}} - \Delta R_{\text{eliminated calls}}$$
5. **Collection Guidance**: If the user needs to collect new trace data, direct them to use `DBMS_MONITOR` with `waits => TRUE` and `MAX_DUMP_FILE_SIZE = UNLIMITED`. See [Oracle Trace Collection Guide](references/oracle-trace-collection-guide.md).

---

## Shell Quoting & Portability Rules

To maintain cross-platform portability:
- **POSIX Shells (Linux / macOS / Bash / Zsh)**: Always enclose expressions containing `$` in **single quotes**:
  `mrskew --group='$sqlid' --where='$lio > 1000' file.trc`
- **Windows CMD**: Use double quotes and escape internal quotes:
  `mrskew --group="$sqlid" --where="$lio > 1000" file.trc`
- **Windows PowerShell**: Use single quotes:
  `mrskew --group='$sqlid' --where='$lio > 1000' file.trc`

---

## Detailed References

- **[mrskew Reference Guide](references/mrskew-reference.md)**: Full options, all 50+ variables, expressions, and rc files.
- **[mrcrop Reference Guide](references/mrcrop-reference.md)**: Detailed manual for all 6 cropping algorithms (`island`, `datetime`, `sqlid`, `experience`, `transaction`, `linerange`).
- **[Auxiliary Tools Reference Guide](references/auxiliary-tools-reference.md)**: Pipelines with `mrkey`, timestamps with `mrwhen`, legacy conversion with `mr1011`.
- **[Method R Diagnostic Methodology](references/method-r-diagnostic-methodology.md)**: Response time theory, Three Axioms, Ten-LIO rule, Amdahl's Law, and antipattern remedies.
- **[Oracle Trace Collection Guide](references/oracle-trace-collection-guide.md)**: Safe collection using `DBMS_MONITOR`, parameters, trace hygiene, and cloud platforms.
- **[Recipes & Cheatsheet](references/recipes-and-cheatsheet.md)**: Fast copy-paste recipes for common performance questions.
