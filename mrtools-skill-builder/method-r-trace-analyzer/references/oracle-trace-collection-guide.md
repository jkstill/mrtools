# Oracle Trace Collection Guide

This guide describes safe, production-grade procedures for enabling, scoping, and collecting Oracle extended SQL trace files, based on Cary Millsap and Jeff Holt's *Tracing Oracle* (2023).

---

## 1. Trace Parameters & Hygiene Preliminaries

### Crucial Parameter: MAX_DUMP_FILE_SIZE
Before enabling trace in any session, ensure `MAX_DUMP_FILE_SIZE` is set to `UNLIMITED`. If a trace file exceeds the dump limit, Oracle silently stops writing trace records mid-execution. A truncated trace file is corrupted for response time analysis because concluding dbcalls, plans, and wait events will be missing.

```sql
ALTER SESSION SET MAX_DUMP_FILE_SIZE = UNLIMITED;
```
For system-wide safety, ensure DBAs set `MAX_DUMP_FILE_SIZE = UNLIMITED` in the SPFILE or parameter file.

### Safe Trace Levels
Oracle extended SQL trace has four key attributes:
1. **Database Calls (`dbcalls`)**: Always included whenever tracing is enabled.
2. **Wait Events (`waits`)**: **Must ALWAYS be TRUE**. Without wait event timing, it is impossible to account for I/O, network, lock, or CPU wait time.
3. **Bind Values (`binds`)**: **Default to FALSE**.
   - *Why*: Tracing bind values dramatically balloons trace file size (up to 10x-50x larger), introduces severe measurement intrusion overhead on high-frequency queries, and may write unencrypted sensitive/PII data into operating system files. Only enable bind tracing when diagnosing a specific parameter value or bind peeking issue in a non-production test case.
4. **Execution Plan Statistics (`plan_stat`)**: Set to `'FIRST_EXECUTION'`.
   - *Why*: Setting `plan_stat => 'ALL_EXECUTIONS'` forces Oracle to execute kernel plan inspection code on every single execution, altering the very performance timing you are attempting to measure (measurement intrusion effect).

---

## 2. Enabling and Disabling Traces with DBMS_MONITOR

`DBMS_MONITOR` (introduced in Oracle 10g) is the only approved, modern interface for controlling trace in production. It safely tracks trace state in the data dictionary and survives connection pooling and session migration.

### 1. Tracing by Client Identifier (Best for Web Applications)
Modern web and microservice tiers use connection pools where physical sessions are shared among multiple users. Developers should set `CLIENT_IDENTIFIER` (e.g., via `DBMS_SESSION.SET_IDENTIFIER('user_123')`).

```sql
-- Enable trace for any session executing with this client ID:
BEGIN
  DBMS_MONITOR.CLIENT_ID_TRACE_ENABLE(
    client_id => 'SCOTT_REPORT',
    waits     => TRUE,
    binds     => FALSE,
    plan_stat => 'FIRST_EXECUTION'
  );
END;
/

-- Disable trace when finished:
BEGIN
  DBMS_MONITOR.CLIENT_ID_TRACE_DISABLE(
    client_id => 'SCOTT_REPORT'
  );
END;
/
```

### 2. Tracing by Service, Module, and Action (Best for Background/Batch Jobs)
When applications instrument their code with `DBMS_APPLICATION_INFO.SET_MODULE(module_name, action_name)`:

```sql
-- Enable trace for specific module and action:
BEGIN
  DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE(
    service_name => 'ERP_PROD',
    module_name  => 'PAYROLL_CALC',
    action_name  => 'MONTH_END',
    waits        => TRUE,
    binds        => FALSE,
    plan_stat    => 'FIRST_EXECUTION'
  );
END;
/

-- Disable trace:
BEGIN
  DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE(
    service_name => 'ERP_PROD',
    module_name  => 'PAYROLL_CALC',
    action_name  => 'MONTH_END'
  );
END;
/
```

### 3. Tracing a Specific Database Session
If you know the session ID (`SID`) and serial number (`SERIAL#`):

```sql
-- Query session coordinates:
SELECT SID, SERIAL#, USERNAME, PROGRAM 
FROM V$SESSION 
WHERE USERNAME = 'APP_USER';

-- Enable trace:
BEGIN
  DBMS_MONITOR.SESSION_TRACE_ENABLE(
    session_id => 142,
    serial_num => 28911,
    waits      => TRUE,
    binds      => FALSE,
    plan_stat  => 'FIRST_EXECUTION'
  );
END;
/

-- Disable trace:
BEGIN
  DBMS_MONITOR.SESSION_TRACE_DISABLE(
    session_id => 142,
    serial_num => 28911
  );
END;
/
```

---

## 3. Trace Hygiene: Verification & Cleanup

Always check for lingering enabled traces. Lingering traces fill up file systems and waste CPU overhead:

```sql
-- View all currently enabled traces across the database:
SELECT TRACE_TYPE, PRIMARY_ID, QUALIFIER_ID1, QUALIFIER_ID2, WAITS, BINDS, PLAN_STATS
FROM DBA_ENABLED_TRACES;
```

If you see orphaned traces left behind by prior troubleshooting sessions, disable them immediately using the corresponding `DBMS_MONITOR.*_TRACE_DISABLE` procedure.

---

## 4. Finding Your Trace File on Disk

To find the exact pathname of the trace file for your current session:

```sql
SELECT VALUE 
FROM V$DIAG_INFO 
WHERE NAME = 'Default Trace File';
```

To find the Automatic Diagnostic Repository (ADR) trace directory:
```sql
SELECT VALUE 
FROM V$DIAG_INFO 
WHERE NAME = 'Diag Trace';
```

### Trace File Naming Standard
Oracle names trace files according to the operating system process ID (SPID):
$$\langle\text{ORACLE\_SID}\rangle\_\text{ora}\_\langle\text{SPID}\rangle\text{.trc}$$
For example: `TDFPRD1_ora_1041.trc`.

---

## 5. Tracing Proscriptions (What NOT to Do)

Avoid the following legacy practices:
1. **Do NOT use `TRACEFILE_IDENTIFIER`**:
   Changing the trace file name mid-stream disrupts ADR tracking, confuses log sweepers, and can break automated diagnostic tools like `mrls`.
2. **Do NOT use `ALTER SESSION SET SQL_TRACE = TRUE`**:
   `SQL_TRACE` does not enable wait event tracing (`waits => FALSE`), producing useless trace files that lack timing for I/O, network, or latch delays.
3. **Do NOT use event 10046 with `ALTER SESSION` or `ALTER SYSTEM`**:
   Deprecated in favor of `DBMS_MONITOR`.
4. **Do NOT use `DBMS_SYSTEM` or `DBMS_SUPPORT`**:
   Undocumented, unsupported packages that bypass security audits and can destabilize sessions.

---

## 6. Tracing in Cloud Environments

### Amazon RDS for Oracle
Amazon RDS does not provide operating system root access to the database server. Access trace files via AWS RDS administration packages:
```sql
-- Enable trace via RDS:
EXEC rdsadmin.rdsadmin_util.alter_session('SET MAX_DUMP_FILE_SIZE = UNLIMITED');
-- Read or download trace files using RDS directory routines:
SELECT * FROM TABLE(rdsadmin.rds_file_util.read_text_file('BDUMP', 'trace_file.trc'));
```

### Oracle Autonomous Database (ADB-S / ADB-D)
On Autonomous Database, trace files are managed inside the cloud storage repository. Traces can be enabled using `DBMS_MONITOR` and retrieved via Oracle Cloud REST APIs or the Oracle Cloud Infrastructure (OCI) console object storage integration.
