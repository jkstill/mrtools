# Auxiliary Tools Reference Guide: mrkey, mrwhen, and mr1011

In addition to `mrskew` and `mrcrop`, Method R Workbench provides companion utilities that enable shell automation, timeline correlation, and legacy format migration.

---

## 1. mrkey – Extracting Grouping Keys for Automated Pipelines

### Purpose
`mrkey` reads standard `mrskew` tabular output and extracts the Column 1 values (the grouping keys) for the rows you specify. It parses the dashes on line 2 of `mrskew` output to reliably determine column boundaries.

`mrkey` allows AI agents and shell scripts to easily chain `mrskew` queries—for example, discovering the top 5 most time-consuming SQL IDs in a file and then running targeted drill-downs for each SQL ID.

### Synopsis
```bash
mrkey [options] [file]
# Or via pipeline:
mrskew [options] file.trc | mrkey [options]
```

### Options
| Option | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--rows=range_list` | `-r range_list` | Specifies which rows to print. Ranges can be comma-separated or hyphenated (e.g., `1`, `1-5`, `1,3,5-7`). | `1` (top row) |
| `--delimiter=string`| `-d string` | Delimiter string between keys when multiple keys are printed. | `\n` (newline) |
| `--newline` | `-n` | Terminate output with a trailing newline. | Enabled |

### Common Pipeline Patterns

#### Extract the Top Time-Consuming SQL ID
```bash
TOP_SQL=$(mrskew --group='$sqlid' --where1=1 app.trc | mrkey -r 1)
echo "Top SQL ID is: $TOP_SQL"
```

#### Loop Through the Top 5 SQL Statements
```bash
for sqlid in $(mrskew --group='$sqlid' --where1=1 app.trc | mrkey -r 1-5); do
    echo "==================== SQL ID: $sqlid ===================="
    mrskew --where='$sqlid eq "'"$sqlid"'"' --group='$name' app.trc
done
```

#### Extract SQL IDs as a Comma-Separated List
```bash
mrskew --group='$sqlid' --where1=1 app.trc | mrkey -r 1-5 -d ","
```

---

## 2. mrwhen – Correlating Timestamps and Wall-Clock Time

### Purpose
Oracle extended SQL trace files record timing concluding timestamps as microsecond integer timer values (`tim=4021068636418`). These raw numbers cannot be easily interpreted by humans or matched with system alert logs.

`mrwhen` translates raw `tim` values into easy-to-read ISO 8601 timestamps (e.g., `2023-05-16T07:57:55.594136`) in the shell's local time zone, using the wall-clock synchronizations embedded in the trace file header. It also calculates both the **start time** and **end time** for each call.

### Synopsis
```bash
mrwhen [options] file.trc
```

### Options
| Option | Description |
| :--- | :--- |
| `--lines=range_list` | Process only the specified line numbers (e.g., `--lines=50-100` or `--lines=141280-141300`). |
| `--tim=tim_value` | Convert a single raw `tim` integer into an ISO 8601 timestamp using correlation data from `file.trc`. |
| `--start` | Print only the starting timestamp of each call. |
| `--drift` | Display estimated timer drift over the course of the trace file. |
| `--drift-only` | Report only clock drift metrics, then exit. |

### Output Anatomy
```text
START TIME                  END TIME                    RAW TRACE LINE
--------------------------  --------------------------  -------------------------------------------------------------
2023-05-16T07:57:55.592852  2023-05-16T07:57:55.592866  PARSE #47891473136032:c=14,e=14,p=0,cr=0,cu=0,mis=0,r=0...
2023-05-16T07:57:55.594136  2023-05-16T07:57:55.594150  EXEC #47891473136032:c=15,e=14,p=0,cr=0,cu=0,mis=0,r=0...
2023-05-16T07:57:55.594288  2023-05-16T07:57:55.598714  WAIT #47891473136032: nam='SQL*Net message from client' ela= 4426...
```

### Diagnostic Use Cases
1. **Correlating Database Activity with Application Log Incidents**:
   When an application log reports an error at `08:14:22`, use `mrwhen` to find the exact trace calls executing at that second.
2. **Detecting OS Scheduling Delays & Preemption**:
   Compare the end time of call $N$ and the start time of call $N+1$. If several seconds elapse with no recorded wait event, the process was either waiting on uninstrumented CPU or preempted by the OS kernel.
3. **Validating Monotonic Clock Integrity**:
   `mrwhen` automatically alerts on non-monotonically increasing timer values (backwards time jumps caused by NTP slewing or virtual machine clock bugs).

---

## 3. mr1011 – Upgrading Legacy Trace Files to Modern Format

### Purpose
Pre-Oracle 11g trace files (Oracle 8i, 9i, 10g) lack modern fields introduced in Oracle 11g (such as `sqlid` and `plh`), and older platforms sometimes recorded timing in 10-millisecond ticks or centiseconds rather than microseconds.

`mr1011` transforms older extended SQL trace files into fully compliant modern 11g/12c/19c/23c trace files by:
1. Synthesizing unique `sqlid` strings for every `PARSING IN CURSOR` statement.
2. Synthesizing plan hash value (`plh`) fields for execution calls.
3. Adjusting and scaling timing values using the `--scale` factor if necessary.

### Synopsis
```bash
mr1011 [options] old_trace.trc [modern_trace.trc]
```
If `modern_trace.trc` is omitted, output is written to `stdout`.

### Options
| Option | Description |
| :--- | :--- |
| `--scale=float` | Multiply all timing values by `float` (e.g., `--scale=1.024` or timer frequency correction). |
| `--initrc` / `--noinitrc` | Process or ignore default rc files. |
| `--listrc` | Display pathnames of rc files. |

### Diagnostic Benefit
Enables the entire modern Method R toolset (`mrskew`, `mrcrop`) to seamlessly process historic baseline trace files collected on older Oracle Database versions.
