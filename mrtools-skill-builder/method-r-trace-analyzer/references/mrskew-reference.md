# mrskew Reference Guide

`mrskew` is the core command-line utility of the Method R Workbench. It scans one or more Oracle extended SQL trace files (`.trc`), extracts performance metrics from database calls (`dbcall`) and operating system wait events (`syscall` / `oscall`), groups the metrics by arbitrary expressions, filters rows, and prints sorted skew profiles and histograms.

---

## 1. Synopsis and Output Anatomy

### Synopsis
```bash
mrskew [options] [file ...]
```
If no input file is specified, `mrskew` reads from `stdin`. If multiple files are specified, `mrskew` concatenates and aggregates data across all files in a single pass.

### Standard Output Columns
```text
CALL-NAME                     DURATION       %  CALLS      MEAN       MIN       MAX
---------------------------  ---------  ------  -----  --------  --------  --------
SQL*Net message from client  12.810928   99.5%     17  0.753584  0.000505  6.722885
EXEC                          0.041683    0.3%      7  0.005955  0.000000  0.041581
FETCH                         0.012166    0.1%     13  0.000936  0.000000  0.011764
...
TOTAL (9)                    12.871090  100.0%    193  0.066690  0.000000  6.722885
```
- **Column 1 (Group)**: The grouping key (default: call name `$nam`). Configured by `--group=expr` and `--gl=label`.
- **Column 2 (Select / Metric)**: The aggregated metric (default: accounted-for duration `$af` in seconds). Configured by `--select=numexpr` and `--sl=label`.
- **Column 3 (%)**: Percentage of the grand total accounted for by this row.
- **Column 4 (CALLS)**: Number of calls aggregated into this row.
- **Column 5 (MEAN)**: Arithmetic mean duration or metric per call.
- **Column 6 (MIN)**: Minimum single-call duration or metric observed.
- **Column 7 (MAX)**: Maximum single-call duration or metric observed.
- **Footer**: Grand total across all displayed rows and elided rows.

---

## 2. Command-Line Options Reference

### Filtering Options
| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--name=pattern` | | Regex pattern matching Oracle call names. Case-insensitive. Special keywords: `:all`, `:call`, `:dbcall`, `:syscall` (or `:oscall`). | `.+` |
| `--where=expr` | `--w=expr`, `--w0=expr` | Primary filter expression (valid Perl). Applied to each trace line. | `1` |
| `--where1=expr` | `--w1=expr` | Secondary filter expression, evaluated in conjunction with `--where`. Standard recommendation is to use `--where1` for recursive depth filtering (`$dep==$depmin`). | `$dep==$depmin` |
| `--alldepths` | | Shorthand for `--where1=1`. Matches calls at all recursive SQL depths (0, 1, 2...). | Disabled |

> **Crucial Rule on Recursive SQL ($dep)**: By default, `--where1='$dep==$depmin'` is active. This filters calls to only the topmost recursive depth (usually `$dep == 0`), preventing double-counting of CPU and elapsed time when top-level SQL triggers internal recursive dictionary or PL/SQL calls. When analyzing total I/O or specifically targeting recursive statements, specify `--alldepths` or `--where1=1`.

### Grouping and Selection Options
| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--group=expr` | `--g=expr` | Perl expression defining grouping column 1. | `'$nam'` |
| `--group-label=expr`| `--gl=expr` | Label for column 1 header. | `CALL-NAME` |
| `--group-width=n` | `--gw=n` | Maximum character width for column 1. | `0` (unlimited) |
| `--select=numexpr` | `--s=numexpr`| Numeric expression aggregated in column 2. | `'$af'` |
| `--select-label=expr`| `--sl=expr` | Label for column 2 header. | `DURATION` |

### Output Formatting and Display Options
| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--top=n` | | Number of rows to display before aggregating remaining rows into `%d others`. Use `--top=0` or `--top=all` to see all rows. | `10` (or 20) |
| `--sort=specs` | | Sort order specification (e.g., `2nd,4nd,1sa`). Digits 1-7, `n` (numeric) or `s` (string), `d` (descending) or `a` (ascending). Use `--sort=none` for unsorted streaming. | `2nd,4nd,1sa` |
| `--csv` | | Output as CSV format (`--nocommas --nodashes --format=csv --pfact=1 --pform=%.6f --plabel=PCT --separator=,`). | Disabled |
| `--format=tab\|csv`| | Set output format (`tab` or `csv`). | `tab` |
| `--commas` / `--nocommas` | | Format large numbers with commas. | `--commas` |
| `--dashes` / `--nodashes` | | Print horizontal dividing dashes in headers/footers. | `--dashes` |
| `--head` / `--nohead` | | Print table column headers. | `--head` |
| `--foot` / `--nofoot` | | Print table summary footer. | `--foot` |
| `--histogram` / `--nohistogram` | | Print performance histogram columns (%, CALLS, MEAN, MIN, MAX). | `--histogram` |
| `--precision=n` | `--pre=n` | Decimal places to round select, MEAN, MIN, and MAX. | `6` |
| `--separator=str` | `--sep=str`| Column separator string. | `'  '` (two spaces) |
| `--thinktime=f` | `--z=f` | Think-time threshold in seconds for `$island_id` calculation. | `1.0` |

### Configuration and RC File Options
| Option | Description |
| :--- | :--- |
| `--rc=file` | Process lines in `file` as if passed on the command line. |
| `--initrc` / `--noinitrc` | Process or ignore default rc files (`~/.mrskew.rc`, `./.mrskew.rc`). Default: `--initrc`. |
| `--listrc` | Display full pathnames of rc files that would be evaluated, then exit. |
| `--scanmax=n` | Number of lines to scan at start of file for metadata and `$depmin`. Default: `250` (0 = no limit). |

---

## 3. Complete Variable Reference

Inside `--group`, `--select`, `--where`, and `--where1` expressions, the following variables and functions are available:

### Time & Duration Variables
- `$af`: Accounted-for duration in seconds. For a `dbcall`, `$af = $c` (CPU seconds). For a `syscall` (`WAIT`), `$af = $ela` (wait elapsed seconds). Used by default `--select`.
- `$dur`: Total elapsed duration in seconds. For `dbcall`, `$e`; for `syscall`, `$ela`.
- `$cpu`, `$c`: CPU time consumed by a dbcall, in seconds. (0 for syscalls).
- `$e`: Elapsed time for a dbcall, in seconds. (0 for syscalls).
- `$ela`: Elapsed wait time for a syscall (`WAIT`), in seconds. (0 for dbcalls).
- `$tim`, `$tim1`: Timestamp when call concluded, in seconds (microsecond precision).
- `$tim0`: Timestamp when call began, in seconds (`$tim1 - $af`).
- `$tim1prior`: Timestamp when prior dbcall concluded, in seconds.
- `$time0`: ISO 8601 string of `$tim0` (e.g., `2023-05-16T07:57:55.592852`).
- `$time1`: ISO 8601 string of `$tim1`.
- `mrtime($tim)`: Function converting numeric `tim` seconds to ISO 8601 string.
- `$uafwc`: Unaccounted-for duration within dbcalls: `$e - ($c + $ela)`.
- `$uafbc`: Unaccounted-for duration between dbcalls: `$tim0 - $tim1prior`.

### Call & Line Identification
- `$nam`, `$name`, `$call`: Name of the call (e.g., `PARSE`, `EXEC`, `FETCH`, `CLOSE`, or wait event name like `db file sequential read`).
- `$is_dbcall`: Boolean, true for database calls (`PARSE`, `EXEC`, `FETCH`, `CLOSE`, `BINDS`, etc.).
- `$is_oscall`, `$is_syscall`: Boolean, true for operating system calls (`WAIT`).
- `$line`, `$line_number`, `$l`, `$NR`: Line number within current trace file.
- `$text`: Full raw text of the current trace line.

### Database Cursor & SQL Variables
- `$sqlid`: Oracle SQL ID (13 characters) associated with the current cursor.
- `$sql`: Full SQL text associated with the cursor (whitespace normalized to single spaces). Use `substr($sql, 0, 60)` for concise display.
- `$ssql`: Shareable SQL text (literals replaced with bind placeholders, comments removed, IN lists normalized).
- `$ssqlid`: Synthesized SQL ID of the shareable `$ssql` statement.
- `$hv`: Oracle SQL hash value.
- `$cursor_id`: Cursor handle number (the number after `#` in trace files).
- `$parse_id`: Line number of the most recent `PARSE` call for this cursor.
- `$exec_id`: Line number of the most recent `EXEC` call for this cursor.
- `@bind`: Array of placeholder bind values for the call.
- `$bind[i]`: Value of placeholder `Bind#i` (e.g., `$bind[0]` for first bind).
- `join(",", @bind)`: Comma-separated list of all bind values in context.

### Execution Statistics & Resource Consumption
- `$lio`: Logical I/O count (`$cr + $cu`). (0 for syscalls).
- `$cr`: Consistent read buffer gets.
- `$cu`: Current mode buffer gets.
- `$pio`, `$p`: Physical read blocks retrieved from OS.
- `$row`, `$r`: Rows processed/returned by the dbcall.
- `$mis`: Library cache misses (hard parse indicator on `PARSE` calls).
- `$plh`: Execution plan hash value.
- `$dep`: Recursive call depth.
- `$depmin`: Minimum recursive depth found in file (typically 0).

### Wait Event Parameters
- `$p1`, `$p2`, `$p3`: The 3 parameters emitted with each `WAIT` line. (e.g., for `db file sequential read`, `$p1` = file#, `$p2` = block#, `$p3` = blocks=1; for `SQL*Net message from client`, `$p2` = #bytes).
- `$obj`: Oracle object ID (`obj#`) referenced in the wait call.

### Session, Application & Transaction Context
- `$session_id`, `$sid`: Oracle Session ID from `SESSION ID` line.
- `$serial_number`, `$serial`: Oracle session serial number.
- `$service_name`: Oracle service name in context.
- `$module_name`: Application module name (`DBMS_APPLICATION_INFO.SET_MODULE`).
- `$action_name`: Application action name.
- `$client_id`: Oracle Client ID (`DBMS_SESSION.SET_IDENTIFIER`).
- `$client_ip`: Client IP address.
- `$client_driver`: Client driver identifier.
- `$experience_id`: Experience ID from `*** EXPERIENCE ID:(...)` markers.
- `$island_id`: First line number of the active user experience island.
- `$rd_only`: 1 if transaction was read-only, 0 if read-write (for `XCTEND`).
- `$rlbk`: 1 if transaction rolled back, 0 if committed (for `XCTEND`).

### File Information
- `$file`, `$filename`, `$f`: Filename of the input trace file.
- `$base`, `$basename`: Base name of the input file without directory.
- `$dir`, `$dirname`: Directory path containing the input file.
- `$oracle_release`: Oracle database release version (e.g., `19`).

---

## 4. Prepackaged .rc Files

`mrskew` includes standard prepackaged `.rc` files located in the Method R Workbench distribution:

| .rc File | Purpose & Behavior |
| :--- | :--- |
| `island.rc` | Groups calls by `"$file:$island_id"`, calculating the response time of each active user experience between think-time oceans. |
| `p10.rc` | Buckets call durations into power-of-10 partitions: `<1us`, `1..10us`, `10..100us`, `100us..1ms`, `1..10ms`, `10..100ms`, `100ms..1s`, `>1s`. Essential for I/O latency distribution. |
| `ssd.rc` | Partitions call durations into granular microsecond buckets optimized for Solid State Drives / Flash storage analysis. |
| `disk.rc` | Partitions call durations into millisecond buckets optimized for mechanical spinning disks. |
| `calls.rc` | Lists database calls in sequential chronological order. |
| `all.rc` | Shorthand for `--name=:all --where1=1 --top=0 --sort=1na --nohistogram`. Displays every line in trace narrative. |
| `distinct-texts.rc` | Counts distinct SQL statements that share the same `$ssqlid`. Reveals unshareable literal SQL storms. |
| `shareable-texts.rc`| Groups `PARSE` calls by the normalized shareable text `$ssql`. |
| `first-read-only.rc`| Groups single-block physical reads by block address (`$p1:$p2`), isolating the time for the first read from subsequent rereads of the same block into buffer cache. |

---

## 5. Advanced RC Files in ~/.mrtools/rc

Method R tools search for `.rc` files using the `MRTOOLS_RCPATH` environment variable:
```bash
export MRTOOLS_RCPATH="$HOME/.mrtools/rc:/usr/share/mrtools/rc"
```
The repository in `~/.mrtools/rc` contains advanced diagnostic `.rc` files authored by Jared Still (`jkstill`):

| RC File | Purpose & Practical Command |
| :--- | :--- |
| `cull-snmfc.rc` | **Culls idle client think-time**: Excludes `SQL*Net message from client` if duration $\ge 1.0\text{s}$, instantly removing connection pool noise while preserving active network round trips.<br>`mrskew --rc=cull-snmfc.rc app.trc` |
| `cull-idle.rc` | **Exhaustive idle wait culling**: Filters out 80+ Oracle background/idle wait events (DBWR, LGWR, streams, PMON, SMON, VKTM, jobq, etc.) as well as idle client waits $\ge 1\text{s}$. Essential for system/database-level traces.<br>`mrskew --rc=cull-idle.rc db.trc` |
| `sqlid.rc` | **One-step SQL ranking with idle culling**: Combines `$sqlid . q{:} . substr($sql,0,60)` grouping with automatic `--rc=cull-snmfc.rc` and `--rc=cull-idle.rc`.<br>`mrskew --rc=sqlid.rc app.trc` |
| `fetch-rowcounts.rc` | **Fetch array size breakdown**: Formats dbcalls by row count (`EXEC:0001`, `FETCH:0025`, `FETCH:0000`, etc.) to immediately inspect client fetch sizing.<br>`mrskew --rc=fetch-rowcounts.rc app.trc` |
| `snmfc-savings-2.rc` | **Predicts time saved by increasing array size**: Mathematically simulates the reduction in network round-trip latency by altering the client array fetch size (`ARRAYSIZE=n`).<br>`ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc app.trc` |
| `calls-totaled-2.rc` | **Chronological narrative with running totals**: Emits an indented execution narrative with timestamps, line numbers, parse IDs, exec IDs, bound values, SQL text, elapsed time, and subcall totals.<br>`mrskew --rc=calls-totaled-2.rc app.trc \| head -30` |
| `sequential-read-dups.rc`| **Detects duplicate block reads**: Analyzes single-block reads to find blocks (`$p1:$p2`) read multiple times into the buffer cache and calculates total seconds that would be saved if duplicate reads were eliminated.<br>`mrskew --rc=sequential-read-dups.rc app.trc`<br>*(Use `MRTOOLS_VERBOSE=1` to print specific block addresses)*. |
| `gap-check.rc` | **Identifies unaccounted time gaps**: Emits `$time0 \| $time1 \| $text` across all recursive depths to identify uninstrumented time or OS preemption delays.<br>`mrskew --rc=gap-check.rc app.trc` |
| `calls-flamegraph.rc` | **Prepares data for flamegraphs**: Normalizes call durations into microsecond count units for ingestion into `flamegraph.pl`.<br>`mrskew --rc=calls-flamegraph.rc app.trc \| flamegraph.pl > trace.svg` |

---

## 6. Shell Quoting Guidelines

Because `mrskew` expressions frequently use `$` (Perl variables), proper shell quoting is critical:

### POSIX Shells (Linux / macOS / Bash / Zsh)
- **Always use single quotes (`'...'`)** around expressions containing `$` to prevent the shell from expanding them as shell variables:
  ```bash
  # Correct POSIX quoting:
  mrskew --group='$sqlid' --where='$lio > 1000' file.trc
  mrskew --group='sprintf("%d:%d", $p1, $p2)' file.trc
  mrskew --group='"$module_name.$action_name"' file.trc
  ```
- If a string literal is needed inside single quotes, use double quotes: `--group='"$file::$line"'`.

### Windows CMD
- In DOS / CMD, use double quotes and escape internal quotes:
  ```cmd
  mrskew --group="$sqlid" --where="$lio > 1000" file.trc
  mrskew --group="""$p1.$p2""" file.trc
  ```

### Windows PowerShell
- In PowerShell, use single quotes or escape `$` with backtick:
  ```powershell
  mrskew --group='$sqlid' --where='$lio -gt 1000' file.trc
  ```
