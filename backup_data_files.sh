#!/bin/bash

# Setup log file name with runtime date and time stamp
TIMESTAMP=`date "+%Y-%m-%d-%H%M%S"`
LOGFILE="/home/mick/logs/backup_logs-${TIMESTAMP}.txt"

local_backup () {
  # Backup brak data-1 and data-2 files to local data-3 storage
  rsync -auvzh --progress /data-1/ /data-3/data-1/ >> ${LOGFILE}
  rsync -auvzh --progress /data-2/ /data-3/data-2/ >> ${LOGFILE}
}

remote_data-1_backup () {
# Backup brak data-1 to zorak data-1
rsync -auvzh --progress /data-1/ mick@10.1.1.30:/data-1/ >> ${LOGFILE}
}

remote_data-2_backup () {
# Backup brak data-2 to zorak data-2
rsync -auvzh --progress /data-2/ mick@10.1.1.30:/data-2/ >> ${LOGFILE}
}


main () {
echo "====================================================================================================" > ${LOGFILE}
echo "Starting backup jobs -  `date +%Y-%m-%d-%H:%M:%S`" >> ${LOGFILE}
echo "====================================================================================================" >> ${LOGFILE}
time local_backup
time remote_data-1_backup
time remote_data-2_backup
echo "====================================================================================================" >> ${LOGFILE}
echo "End backup jobs  -  `date +%Y-%m-%d-%H:%M:%S`" >> ${LOGFILE}
echo "====================================================================================================" >> ${LOGFILE}
}

time main
