#!/bin/bash

# trim oracle logs and traces (ok to do it weekly); XE edition

# env: alt is ~oracle/env_db.sh
. /etc/profile.d/oracle.sh

LOG=$HOME/log_trim.log

# files to trim; clusterware rotates its logs somehow so skip them
FILES_TO_TRIM="$ORACLE_BASE/diag/rdbms/xe/XE/trace/alert_XE.log
               $ORACLE_BASE/diag/tnslsnr/$HOSTNAME/listener/trace/listener.log"

echo "$(date +'%Y.%m.%d %H:%M:%S'): trimming started" >> $LOG

# save previous version
echo "$FILES_TO_TRIM" | while read file; do
  if [ -r $file ]; then
    echo "trimming log $file" >>$LOG
    # ls -l $file               >>$LOG
    rm -f $file.prev >/dev/null 2>&1
    cp $file $file.prev
    echo -n > $file
  else
    echo "log $file is missed here"
  fi
done

# no "adrci" here to trim xml logs and traces

echo "$(date +'%Y.%m.%d %H:%M:%S'): trimming ended" >> $LOG
