#!/bin/bash


local_backup () {
  # Backup brak data-1 and data-2 files to local data-3 storage
  rsync -auvzh --progress /data-1/ /data-3/data-1/
  rsync -auvzh --progress /data-2/ /data-3/data-2/
}

remote_data-1_backup () {
# Backup brak data-1 to zorak data-1
rsync -auvzh --progress /data-1/ mick@10.1.1.30:/data-1/
}

remote_data-2_backup () {
# Backup brak data-2 to zorak data-2
rsync -auvzh --progress /data-2/ mick@10.1.1.30:/data-2/
}


main () {
echo "===================================================================================================="
echo "Starting backup jobs..."
echo "===================================================================================================="
local_backup
remote_data-1_backup
remote_data-1_backup
echo "===================================================================================================="
echo "End backup jobs"
echo "===================================================================================================="
}

time main
