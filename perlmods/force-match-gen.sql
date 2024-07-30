-- force-match-gen.sql

set pause off
set echo off
set timing off
set trimspool on
set verify off

clear col
clear break
clear computes

btitle ''
ttitle ''

btitle off
ttitle off

set newpage 1
set tab off
set pagesize 0 linesize 200
set term off
set feed off
set head off

spool ForceMatch.pm

prompt
prompt package ForceMatch;;
prompt

prompt sub getHash { return \%forceMatch; };;
prompt
prompt our %forceMatch = ();;
prompt

prompt %forceMatch = (

select distinct sql_sig
from (
	select distinct
		'	' || '''' || sql_id || ''' => ' || '''' ||  force_matching_signature || ''','	 sql_sig
	from v$sqlarea
	where force_matching_signature > 0
	union
	select distinct
		'	' || '''' || t.sql_id || ''' => ' || '''' ||	 s.force_matching_signature || ''','  sql_sig
	from dba_hist_sqltext t
	join dba_hist_sqlstat s on s.sql_id = t.sql_id
		and s.dbid = t.dbid
	where force_matching_signature > 0
)
/

prompt );;
prompt 1;;
prompt

spool off


set feed on
set term on
set linesize 80
set pagesize 100
set head on


prompt

spool off


set feed on
set term on
set linesize 80
set pagesize 100
set head on
