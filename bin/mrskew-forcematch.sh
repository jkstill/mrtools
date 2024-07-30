#!/usr/bin/env bash

# mrskew-forcematch.sh

#matchID=4933735870674062813
matchID=$1;shift

[[ -z $matchID ]] && { echo force matching ID required; exit 1; }

echo matchID: $matchID

logDir=logs
[[ -d $logDir ]] || mkdir -p $logDir

forceMatchSQLIDs=$(./get-forcematch-sqlids.pl $matchID  | perl -n -e '@x=<>; chomp @x; print join(q{|},@x)')

mrskew --rc=no-snmfc.rc --where1="\$sqlid =~ /$forceMatchSQLIDs/"  $@  > logs/matchID-${matchID}.log

echo logs/matchID-${matchID}.log

