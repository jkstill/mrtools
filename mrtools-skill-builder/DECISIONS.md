# Architectural & Engineering Decisions: Method R Trace Analyzer Skill

This document details the architectural choices, domain engineering rationale, and validation methodology behind the **`method-r-trace-analyzer`** skill.

---

## 1. Skill Granularity: Single Unified Skill vs. Micro-Skills

### The Decision
We designed a single, cohesive skill package—**`method-r-trace-analyzer`**—equipped with modular progressive disclosure references, rather than fragmenting capabilities into multiple independent micro-skills (such as separate "mrskew-skill", "mrcrop-skill", or "trace-collection-skill").

### Rationale
1. **The Diagnostic Lifecycle Is Continuous**:
   Analyzing an Oracle performance problem is not a sequence of disconnected tasks; it is an integrated diagnostic lifecycle:
   $$\text{Scoping/Cropping} \longrightarrow \text{Response Time Profiling} \longrightarrow \text{Bottleneck Identification} \longrightarrow \text{Drill-down} \longrightarrow \text{Remedy Prediction}$$
   If scoping tools (`mrcrop`) and profiling tools (`mrskew`) were placed into separate skills, an agent diagnosing a 50MB connection-pooled trace file might trigger the profiling skill without loading the knowledge needed to crop idle think-time oceans, leading to false-negative conclusions.
2. **Context Window Efficiency & Triggering Precision**:
   Multiple overlapping skills competing for similar triggers (e.g., "analyze this SQL trace") cause skill-routing ambiguities. A single skill with a clear, high-signal description ensures unambiguous triggering.
3. **Progressive Disclosure Pattern**:
   By keeping `SKILL.md` under 250 lines, the primary context overhead upon triggering is tiny (~2,000 tokens). The agent only reads specific reference files in `references/` when the specific diagnostic sub-task requires it.

---

## 2. Adherence to Open Agent Skill Standards & Portability

### The Decision
The skill strictly conforms to the open **Agent Skill specification** adopted by Google Gemini CLI, Claude/Anthropic agents, Cursor, and custom LLM agent harnesses.

### Implementation Details
- **Standard YAML Frontmatter**:
  - `name`: Lowercase, hyphen-separated (`method-r-trace-analyzer`).
  - `description`: Single-line, high-signal string stating both what the skill does and explicit trigger conditions.
- **Zero Proprietary Locks**:
  The instructions and reference guides use standard GitHub-flavored Markdown without vendor-specific markup or proprietary SDK dependencies.
- **Cross-Platform Shell Compatibility**:
  Because `mrskew` expressions frequently use `$` (Perl variables), shell quoting is hazardous if not explicitly handled. The documentation details exact quoting rules for POSIX shells (`'...'`), Windows CMD (`"..."`), and Windows PowerShell (`'...'`).
- **Dual Packaging**:
  Distributed as both an unpackaged directory (`method-r-trace-analyzer/`) for direct symlinking and a packaged `.skill` archive (standard zip format) for CLI skill managers.

---

## 3. Theoretical & Methodological Grounding

### The Decision
All diagnostic workflows, interpretation rules, and recommendations are grounded directly in the published works of Cary Millsap and Jeff Holt (*Mastering Oracle Trace Data, 3rd Edition* and *Tracing Oracle, 2023*).

### Encoded Core Principles
1. **The Response Time Equation**:
   $$R = \sum \text{dbcalls} + \sum \text{syscalls}$$
   The skill trains the agent to never evaluate system performance using component utilization metrics (CPU %, disk IOPS) or cache hit ratios (Axiom 1). Performance is solely evaluated through the invoice of response time.
2. **Amdahl's Law and Bottleneck Prioritization**:
   The agent is instructed to focus exclusively on the top line of the profile. Tuning an event that accounts for 2% of response time can never produce more than a 2% improvement, even if latency is cut to zero.
3. **Axiom 3: The Fastest Call Is No Call**:
   When recommending optimizations, the skill prioritizes eliminating calls entirely (e.g., increasing array size to eliminate network round trips, or adding composite indexes to eliminate table visits) rather than attempting to optimize underlying hardware.
4. **The Ten-LIO Rule of Thumb**:
   Jeff Holt's heuristic is formally encoded:
   $$\text{Acceptable LIO} \approx 10 \times (\text{tables in FROM clause}) \times (\text{rows returned})$$
   The skill provides exact commands to measure `$lio` and `$row`, calculate the ratio, and recognize legitimate exceptions (aggregations, `DISTINCT`, bulk scans).
5. **Recursive SQL Depth Handling ($dep)**:
   By default, `mrskew` filters calls with `$dep == $depmin` to avoid double-counting CPU and elapsed time when top-level SQL calls recursive dictionary or PL/SQL statements. The skill documents when to retain this default vs. when to use `--alldepths` (e.g., total physical I/O audits).

---

## 4. Integration of ~/.mrtools/rc Advanced RC Files

### The Decision
Rather than relying solely on default Method R distribution files, the skill integrates the custom `.rc` files authored by Jared Still (`jkstill`) located in `~/.mrtools/rc` via `MRTOOLS_RCPATH`.

### Key Tool Enhancements
1. **`cull-snmfc.rc`**:
   Solved the connection-pool "ocean" dilution problem in a single command (`mrskew --rc=cull-snmfc.rc <file>`), filtering out idle client waits $\ge 1.0\text{s}$ without requiring physical trace slicing.
2. **`cull-idle.rc`**:
   Provides an exhaustive array of over 80 Oracle background idle wait events, enabling clean profiling of database-level traces.
3. **`sqlid.rc`**:
   Combines SQL ID grouping, the first 60 characters of SQL text, and idle wait culling into an instant one-line command.
4. **`fetch-rowcounts.rc` & `snmfc-savings-2.rc`**:
   Enabled predictive performance modeling. An agent can simulate changing `ARRAYSIZE` and output exact before-and-after time savings in seconds.
5. **`sequential-read-dups.rc`**:
   Identifies duplicate block reads (`$p1:$p2`) to prove whether multiple visits to the same block are causing avoidable physical disk I/O.
6. **`calls-totaled-2.rc`**:
   Provides an indented chronological narrative with running totals whenever recursive depth transitions occur.

---

## 5. Empirical Testing and Validation Strategy

### The Decision
All commands, syntax choices, `.rc` files, and diagnostic assertions were empirically executed and validated against 72MB+ of real Oracle 19c trace files located in `./trace`.

### Empirical Test Cases & Findings
1. **Connection-Pool Think-Time Scoping**:
   - *Trace File*: `trace/orcl_ora_1041.trc` (12.87s total).
   - *Test*: Ran `mrskew --rc=cull-snmfc.rc` vs `mrskew --rc=island.rc`.
   - *Result*: Successfully isolated active user experience (0.089s) and confirmed SQL ID `4gn68gurpt1xp` accounted for 91.2% of active work while conforming to the Ten-LIO rule (1.54 LIOs/row).
2. **Unshareable Literal SQL Parsing Storms**:
   - *Trace Files*: `trace/orcl_ora_1019.trc` and `trace/orcl_ora_55807.trc` (72MB).
   - *Test*: Ran `mrskew --name=parse --group='$mis > 0 ? "Hard" : "Soft"'` and `mrskew --rc=distinct-texts.rc`.
   - *Result*: Empirically proved that 910 hard parses accounted for 98.1% of parse duration on `1019.trc`, identifying statements with up to 77 distinct text variations sharing the same syntax template (`WHERE P."Patient" = <literal>`).
   - *Performance*: `mrskew` processed 334,471 calls across 72MB in **1.3 seconds**.
3. **Row-by-Row Fetch Sizing Savings**:
   - *Trace File*: `trace/orcl_ora_1059.trc`.
   - *Test*: Ran `ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc`.
   - *Result*: Successfully modeled that increasing array size would eliminate 22.69s of `SQL*Net message from client` latency (reducing wait from 26.16s down to 3.47s).
4. **SSD Storage Latency Distribution**:
   - *Trace File*: `trace/orcl_ora_11730.trc`.
   - *Test*: Ran `mrskew --name='db file sequential read' --rc=p10.rc`.
   - *Result*: Verified that 69.3% of single-block reads completed in 100µs–1ms (mean 392µs), confirming healthy flash storage.
5. **Skill Specification Validation**:
   - Validated structure, frontmatter, line limits, and absence of unresolved TODOs using `validate_skill.cjs` (passed with 0 errors).
   - Validated packaging into `.skill` archive using `package_skill.cjs`.
