# Method R Recipes & Cheatsheet

This cheatsheet provides ready-to-run copy-pasteable CLI commands for AI agents and human performance analysts.

---

## 1. Response Time Profiling

### Overall Subroutine Call Profile (The Primary Starting Point)
Produces the fundamental invoice of response time across all database calls and wait events:
```bash
mrskew <tracefile>
```
*Note*: By default, this groups by `$nam`, aggregates `$af` (accounted-for duration), filters recursive SQL with `$dep==$depmin`, and prints the top 10 rows.

### Profile All Calls Across Multiple Trace Files
```bash
mrskew *.trc
```

### Breakdown of Database Calls vs Operating System Waits
```bash
mrskew --group='$is_dbcall ? "DATABASE CALL (CPU/Internal)" : "SYSTEM CALL (OS Wait)"' <tracefile>
```

### View All Profile Rows (Do Not Elide with "Others")
```bash
mrskew --top=0 <tracefile>
```

### Profile Only Operating System Calls (Wait Events)
```bash
mrskew --name=:syscall <tracefile>
```

### Instant Response Time Profile with Idle Think-Time Culled (~/.mrtools/rc)
Excludes all `SQL*Net message from client` calls $\ge 1.0\text{s}$, removing connection pool idle time in one step:
```bash
mrskew --rc=cull-snmfc.rc <tracefile>
```

### Profile with All Oracle Background & Idle System Waits Culled
Filters out over 80 Oracle idle background events (DBWR, LGWR, streams, PMON, SMON, VKTM) plus client idle waits:
```bash
mrskew --rc=cull-idle.rc <tracefile>
```

---

## 2. Scoping Connection Pools & Multi-Experience Traces

### Identify User Experience "Islands" (Think-Time Scoping)
```bash
mrskew --rc=island.rc <tracefile>
```
*Output*: Lists each distinct user experience by `$file:$island_id`, showing its active duration, call count, and percentage of active time.

### Drill Into a Specific User Experience Island
If island 3326 is the target experience:
```bash
mrskew --where='$island_id == 3326' <tracefile>
```

### Crop Trace File into Standalone User Experiences
```bash
mrcrop island -z=1.0 <tracefile>
# Cropped files are placed in <tracefile_without_ext>/<tracefile_without_ext>-<island_id>.trc
```

---

## 3. SQL Statement Identification & Ranking

### Top SQL Statements with Idle Culling & SQL Text (~/.mrtools/rc)
Ranks top SQL statements by `$sqlid:substr($sql,0,60)` while automatically culling idle client and background waits:
```bash
mrskew --rc=sqlid.rc <tracefile>
```

### Top SQL Statements by Elapsed Response Time
```bash
mrskew --group='$sqlid' --where1=1 --top=10 <tracefile>
```

### Top SQL Statements Displaying the First 60 Characters of SQL Text
```bash
mrskew --group='substr($sql,0,60)' --gl='"SQL-TEXT"' --where1=1 --top=10 <tracefile>
```

### Top SQL Statements by CPU Consumption
```bash
mrskew --group='$sqlid' --select='$cpu' --sl='"CPU-SEC"' --where1=1 --top=10 <tracefile>
```

### Top SQL Statements by Logical I/O (Buffer Cache Visits)
```bash
mrskew --group='$sqlid' --select='$lio' --sl='"LIO (cr+cu)"' --where1=1 --top=10 <tracefile>
```

### Top SQL Statements by Physical Disk Reads
```bash
mrskew --group='$sqlid' --select='$pio' --sl='"PIO (blocks)"' --where1=1 --top=10 <tracefile>
```

---

## 4. Deep-Dive Diagnostics for a Specific SQL ID

Replace `<SQL_ID>` with the target SQL ID (e.g., `4gn68gurpt1xp`):

### 1. Subroutine Profile for the Target SQL ID
Reveals how much time was spent on EXEC vs FETCH vs PARSE vs individual wait events:
```bash
mrskew --where='$sqlid eq "<SQL_ID>"' <tracefile>
```

### 2. Verify the Ten-LIO Rule of Thumb
Inspect both logical I/O and rows returned for the query:
```bash
# Check Logical I/Os:
mrskew --where='$sqlid eq "<SQL_ID>"' --select='$lio' --sl='"LIO"' <tracefile>

# Check Rows Processed:
mrskew --where='$sqlid eq "<SQL_ID>"' --select='$row' --sl='"ROWS"' <tracefile>
```
*Evaluation*: Calculate $\text{Ratio} = \text{LIO} / \text{ROWS}$. If ratio $> 10 \times (\text{tables in FROM clause})$, investigate execution plan and missing indexes.

### 3. Fetch Array Size Breakdown (~/.mrtools/rc)
Formats all executions and fetches by row count to immediately verify client fetch sizing:
```bash
mrskew --rc=fetch-rowcounts.rc <tracefile>
```

### 4. Predict Time Saved by Increasing Array Size (~/.mrtools/rc)
Mathematically simulates network round-trip savings by testing target array sizes (e.g., `ARRAYSIZE=100` or `500`):
```bash
ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc <tracefile>
```

### 5. Check for Row-by-Row Fetching (Network Round Trips)
```bash
mrskew --where='$sqlid eq "<SQL_ID>" and $call =~ /FETCH|SQL\*Net message/' \
  --group='$call' <tracefile>
```
*Evaluation*: If `SQL*Net message from client` call count is large and roughly equal to row count, the client application is fetching row-by-row. Recommend increasing fetch array size.

### 6. Inspect Placeholder Bind Variable Values
```bash
mrskew --where='$sqlid eq "<SQL_ID>" and ($call =~ /EXEC|FETCH/)' \
  --group='join(",", @bind)' --gl='"BIND-VALUES"' <tracefile>
```

### 5. Inspect Execution Plan Hash Value (Plan Stability)
```bash
mrskew --where='$sqlid eq "<SQL_ID>" and $call eq "EXEC"' \
  --group='$plh' --gl='"PLAN-HASH-VALUE"' <tracefile>
```

---

## 5. Storage Latency & Wait Event Diagnostics

### Single-Block Read Latency Distribution (Power-of-10 Buckets)
Determines whether disk reads are fast (<1ms flash/SSD) or suffering high latency (>10ms-50ms mechanical/SAN):
```bash
mrskew --name='db file sequential read' --rc=p10.rc <tracefile>
```

### Single-Block Read Latency on Solid State Drives (Microsecond Buckets)
```bash
mrskew --name='db file sequential read' --rc=ssd.rc <tracefile>
```

### Identify Hot Datafiles and Blocks
Identifies which database file# ($p1) and block# ($p2) accounted for the most I/O wait duration:
```bash
mrskew --name='db file sequential read' \
  --group='sprintf("%d:%d", $p1, $p2)' --gl='"FILE:BLOCK"' --top=10 <tracefile>
```

### Identify Database Objects Experiencing Wait Contention
```bash
mrskew --name=:syscall --where='$obj > 0' \
  --group='$obj' --gl='"OBJECT-ID"' --top=10 <tracefile>
```

### Detect Duplicate Block Reads & Predict I/O Savings (~/.mrtools/rc)
Calculates the seconds that would be saved if duplicate reads of the same block were eliminated:
```bash
mrskew --rc=sequential-read-dups.rc <tracefile>
# Set MRTOOLS_VERBOSE=1 to display individual obj:file:block addresses read multiple times:
MRTOOLS_VERBOSE=1 mrskew --rc=sequential-read-dups.rc <tracefile>
```

---

## 6. Parsing Storms & Unshareable SQL Diagnostics

### Detect Unshareable SQL (Count Distinct Texts per Shared SQL ID)
```bash
mrskew --rc=distinct-texts.rc <tracefile>
```
*Evaluation*: If `DISTINCT-TEXTS` is high for an `S-SQL-ID`, the application is generating literal SQL without bind variables.

### Hard Parse vs. Soft Parse Breakdown
```bash
mrskew --name=parse --group='$mis > 0 ? "Hard Parse (Library Cache Miss)" : "Soft Parse"' <tracefile>
```

### Inspect the Literal SQL Text Variations for an S-SQL-ID
```bash
mrskew --where='$ssqlid eq "<S_SQL_ID>"' \
  --group='substr($sql, 0, 80)' --gl='"SQL-TEXT"' --top=10 <tracefile>
```

---

## 7. Timeline & Concurrency Diagnostics

### Chronological Execution Narrative with Running Subcall Totals (~/.mrtools/rc)
Renders a chronological timeline with timestamps, line numbers, parse IDs, exec IDs, bound values, SQL text, elapsed durations, and subcall totals:
```bash
mrskew --rc=calls-totaled-2.rc <tracefile> | head -50
```

### Identify Unaccounted Time Gaps & OS Scheduling Latency (~/.mrtools/rc)
Emits `$time0 | $time1 | $text` across all depths to inspect gaps between database calls:
```bash
mrskew --rc=gap-check.rc <tracefile> | head -50
```

### List Database Calls in Chronological Order
```bash
mrskew --rc=calls.rc <tracefile>
```

### Print Human-Readable ISO 8601 Timestamps for Line Range
```bash
mrwhen --lines=1-50 <tracefile>
```

### Convert a Specific Microsecond `tim` Value to Wall-Clock Time
```bash
mrwhen --tim=4021068636418 <tracefile>
```

---

## 8. Chained Automated Pipelines (mrskew + mrkey)

### Automatically Drill into the #1 Bottleneck SQL Statement
```bash
TOP_SQL=$(mrskew --group='$sqlid' --where1=1 <tracefile> | mrkey -r 1)
echo "Analyzing Top SQL ID: $TOP_SQL"
mrskew --where='$sqlid eq "'"$TOP_SQL"'"' <tracefile>
```

### Automatically Audit Top 3 SQL Statements for the 10-LIO Rule
```bash
for sqlid in $(mrskew --group='$sqlid' --where1=1 <tracefile> | mrkey -r 1-3); do
  echo "--- SQL ID: $sqlid ---"
  mrskew --where='$sqlid eq "'"$sqlid"'"' --select='$lio' --sl='"LIO"' <tracefile>
  mrskew --where='$sqlid eq "'"$sqlid"'"' --select='$row' --sl='"ROWS"' <tracefile>
done
```
