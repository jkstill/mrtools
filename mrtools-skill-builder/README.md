# Method R Trace Analyzer Skill (`method-r-trace-analyzer`)

An open, portable AI Agent Skill for analyzing Oracle extended SQL trace files (`.trc`) using **Method R Workbench** command-line tools (`mrskew`, `mrcrop`, `mrkey`, `mrwhen`, `mr1011`) and Cary Millsap's performance engineering methodology.

This skill equips AI agents (and human engineers) to autonomously profile response times, identify performance bottlenecks per Amdahl's Law, diagnose wait events and resource consumption (CPU, LIO, PIO), audit queries against the Ten-LIO Rule of Thumb, simulate array fetch tuning savings, and formulate actionable SQL tuning recommendations.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Skill Installation](#skill-installation)
   - [Gemini CLI](#1-gemini-cli)
   - [Claude / Anthropic Agents](#2-claude--anthropic-agents)
   - [Cursor & Agent IDEs](#3-cursor--agent-ides)
   - [Manual File-Based Setup](#4-manual-file-based-setup)
3. [How to Use the Skill](#how-to-use-the-skill)
   - [Triggering Scenarios for AI Agents](#triggering-scenarios-for-ai-agents)
   - [Interactive Usage for Human Analysts](#interactive-usage-for-human-analysts)
4. [Standard 5-Step Diagnostic Workflow](#standard-5-step-diagnostic-workflow)
5. [Essential Command Quick Reference](#essential-command-quick-reference)
6. [Skill File Structure](#skill-file-structure)

---

## Prerequisites

1. **Method R Workbench CLI Tools**:
   Ensure the core tools are installed and present in your `$PATH`:
   ```bash
   which mrskew mrcrop mrkey mrwhen mr1011
   ```
2. **Method R RC Files Path (`MRTOOLS_RCPATH`)**:
   Set `MRTOOLS_RCPATH` to search your personal and shared `.rc` directories:
   ```bash
   export MRTOOLS_RCPATH="$HOME/.mrtools/rc:/usr/share/mrtools/rc"
   ```
   *(Add this line to your `~/.bashrc`, `~/.zshrc`, or shell profile).*

---

## Skill Installation

The skill is distributed both as an unpackaged portable directory (`./method-r-trace-analyzer/`) and as a self-contained archive (`./method-r-trace-analyzer.skill`).

### 1. Gemini CLI

#### Workspace Scope (Active only in this directory)
```bash
gemini skills install ./method-r-trace-analyzer.skill --scope workspace
```

#### User Scope (Active globally across all your projects)
```bash
gemini skills install ./method-r-trace-analyzer.skill --scope user
```

> **Important**: After running the install command, you **must** reload skills in your active interactive Gemini CLI session by typing:
> ```text
> /skills reload
> ```
> Verify it is loaded with `/skills list`.

---

### 2. Claude / Anthropic Agents

Copy or link the skill folder into your agent skills directory:
```bash
# Global skills directory:
mkdir -p ~/.agents/skills
cp -r ./method-r-trace-analyzer ~/.agents/skills/

# Or project-scoped:
mkdir -p .claude/skills
cp -r ./method-r-trace-analyzer .claude/skills/
```

---

### 3. Cursor & Agent IDEs

In Cursor or other AI IDEs:
1. Place the `method-r-trace-analyzer` folder in your project root or `.cursor/skills/`.
2. Add a rule to `.cursorrules` or system prompt:
   ```markdown
   When analyzing Oracle trace files (.trc) or diagnosing Oracle SQL performance, follow the procedures in method-r-trace-analyzer/SKILL.md.
   ```

---

### 4. Manual File-Based Setup

Extract the `.skill` archive (which is a standard zip archive) directly into any target directory:
```bash
unzip method-r-trace-analyzer.skill -d ~/.agents/skills/method-r-trace-analyzer
```

---

## How to Use the Skill

### Triggering Scenarios for AI Agents

Once installed, the agent will automatically trigger the skill when you ask tasks such as:
- *"Analyze this Oracle trace file `trace.trc` and identify why it is slow."*
- *"Check if this SQL statement violates the Ten-LIO rule."*
- *"Why are we seeing high `SQL*Net message from client` waits in this trace?"*
- *"Isolate the user experience in this connection-pooled trace file."*
- *"Check for hard parse storms or unshareable SQL statements."*
- *"Model how much time we would save if we increase the fetch array size to 500."*
- *"Give me the mrskew commands to profile CPU vs wait time."*

---

### Interactive Usage for Human Analysts

Human engineers can use the skill's reference documentation and decision tree directly from the command line.

#### Step 1: Rapid Profile with Idle Think-Time Culled
```bash
mrskew --rc=cull-snmfc.rc my_trace.trc
```
*Eliminates the multi-hour "oceans" of connection pool idle wait, revealing the active response time invoice.*

#### Step 2: One-Step SQL Ranking with SQL Text
```bash
mrskew --rc=sqlid.rc my_trace.trc
```
*Lists the top SQL statements by elapsed duration, complete with the first 60 characters of SQL text.*

#### Step 3: Check Logical I/O and the Ten-LIO Rule
```bash
# Get LIO (buffer gets: cr + cu):
mrskew --where='$sqlid eq "TARGET_SQLID"' --select='$lio' --sl='"LIO"' my_trace.trc

# Get Rows Processed:
mrskew --where='$sqlid eq "TARGET_SQLID"' --select='$row' --sl='"ROWS"' my_trace.trc
```
*Compute: $\text{LIO} / \text{ROWS}$. If the ratio exceeds $\approx 10 \times (\text{tables in FROM clause})$, the query has an inefficient access path or missing index.*

#### Step 4: Model Time Saved by Fetch Array Sizing
```bash
ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc my_trace.trc
```
*Output prints real network wait time, predicted optimized wait time, and net seconds saved.*

#### Step 5: Check Storage Latency Distribution
```bash
mrskew --name='db file sequential read' --rc=p10.rc my_trace.trc
```
*Shows whether single-block reads complete in microseconds (SSD/flash) or exhibit latency skew.*

---

## Standard 5-Step Diagnostic Workflow

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

## Essential Command Quick Reference

| Diagnostic Objective | CLI Command |
| :--- | :--- |
| **Response Time Profile** | `mrskew <file.trc>` |
| **Profile with Idle Culled** | `mrskew --rc=cull-snmfc.rc <file.trc>` |
| **Top SQL Statements with Text** | `mrskew --rc=sqlid.rc <file.trc>` |
| **Top SQL Statements by CPU** | `mrskew --group='$sqlid' --select='$cpu' --sl='"CPU"' --where1=1 <file.trc>` |
| **Top SQL Statements by LIO** | `mrskew --group='$sqlid' --select='$lio' --sl='"LIO"' --where1=1 <file.trc>` |
| **Fetch Row Count Distribution** | `mrskew --rc=fetch-rowcounts.rc <file.trc>` |
| **Simulate Array Size Tuning** | `ARRAYSIZE=500 mrskew --rc=snmfc-savings-2.rc <file.trc>` |
| **I/O Latency Power-of-10 Buckets** | `mrskew --name='db file sequential read' --rc=p10.rc <file.trc>` |
| **Detect Duplicate Block Reads** | `mrskew --rc=sequential-read-dups.rc <file.trc>` |
| **Detect Literal Parsing Storms** | `mrskew --rc=distinct-texts.rc <file.trc>` |
| **Hard vs Soft Parse Breakdown** | `mrskew --name=parse --group='$mis > 0 ? "Hard" : "Soft"' <file.trc>` |
| **Chronological Execution Narrative** | `mrskew --rc=calls-totaled-2.rc <file.trc> \| head -50` |
| **Crop Connection Pool Islands** | `mrcrop island -z=1.0 <file.trc>` |
| **Convert Timestamps to ISO 8601** | `mrwhen --lines=1-50 <file.trc>` |
| **Extract Top SQL ID in Pipeline** | `TOP=$(mrskew --group='$sqlid' --where1=1 <file.trc> \| mrkey -r 1)` |

---

## Skill File Structure

```text
method-r-trace-analyzer/
├── SKILL.md                                  # Main guide (<250 lines): decision tree, tool catalog, core recipes
└── references/
    ├── method-r-diagnostic-methodology.md    # Response time model, 3 Axioms, Amdahl's Law, 10-LIO rule, antipatterns
    ├── mrskew-reference.md                   # Full syntax, all 50+ variables, expressions, sort orders, .rc files
    ├── mrcrop-reference.md                   # All 6 cropping subcommands (island, datetime, sqlid, experience, etc.)
    ├── auxiliary-tools-reference.md          # mrkey (pipeline chaining), mrwhen (timestamps), mr1011 (format upgrade)
    ├── oracle-trace-collection-guide.md      # Safe collection with DBMS_MONITOR, parameters, cloud environments
    └── recipes-and-cheatsheet.md             # Copy-pasteable recipes for humans and agents
```
