#!/bin/bash
# Bash script to rotate MongoDB log files
# Author: Anban Malarvendan
# License: GNU GENERAL PUBLIC LICENSE Version 3 + 
#          Sectoion 7: Redistribution/Reuse of this code is permitted under the 
#          GNU v3 license, as an additional term ALL code must carry the 
#          original Author(s) credit in comment form.

# MongoDB credentials and settings
MONGODB_USERNAME="user_logrotate"
MONGODB_PASSWORD="xxxxxxxx"
MONGODB_PORT=27017

# Date settings
CURRENT_DATE=$(date +"%Y%m%d")
FORMATTED_DATE=$(date +"%y%m%d-%H%M")
OLD_DATE=$(date --date='90 days ago' +"%Y%m%d")

# Log file paths and sizes
LOG_CHOWN_PATH="/var/log"
MONGODB_LOG_PATH="/var/log/mongodb"
MONGODB_LOG_FILE="mongod.log"
BACKUP_DIR="/path_to_save_logs"
LOG_FILE_SIZE=$(du -sm "${MONGODB_LOG_PATH}/${MONGODB_LOG_FILE}" | awk '{print $1}')

# Check if log file size exceeds the threshold (2MB)
if [[ $LOG_FILE_SIZE -ge 2 ]]; then
    if [ -f "${MONGODB_LOG_PATH}/${MONGODB_LOG_FILE}" ]; then
        # Rotate MongoDB log using MongoDB command
        echo "db.runCommand({ logRotate: 1 })" | mongo -u $MONGODB_USERNAME -p $MONGODB_PASSWORD admin --quiet --port $MONGODB_PORT > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            # Send email notification if log rotation fails
            printf "ERROR: LOG ROTATION HAS FAILED\nCURRENT LOG SIZE IS ${LOG_FILE_SIZE} MB\nPLEASE CHECK" | mailx -r root@clientname.com -s "LOGROTATE FAILED IN SERVER_NAME" support_dba@domain.com
            exit
        fi
    fi

    # Compress older log files
    cd $MONGODB_LOG_PATH
    ls -lrth | grep mongod.log.* | gzip

    # Move compressed log files to backup directory
    if [ -d "$BACKUP_DIR" ]; then
        cd $BACKUP_DIR
        if [ ! -d "$CURRENT_DATE" ]; then
            mkdir $CURRENT_DATE
        fi
    fi
    cd $MONGODB_LOG_PATH
    GZ_FILES=$(ls -lrth | grep mongod.log.[0-9] | awk '{print $9}')
    mv $GZ_FILES $BACKUP_DIR/${CURRENT_DATE}

    # Delete log files older than 90 days from the backup directory
    cd ${BACKUP_DIR}
    rm -rf $OLD_DATE

    # Change ownership of MongoDB log directory and its contents
    cd $LOG_CHOWN_PATH
    chown mongodb:mongodb mongodb/ -R
fi
