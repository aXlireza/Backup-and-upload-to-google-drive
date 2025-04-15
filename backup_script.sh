#!/bin/bash

WWW_DIR="/var/www"
BACKUP_DIR="/var/backupscript/project_backups"
LOG_FILE="/var/backupscript/backup_log.txt"
FAILED_LIST="/var/backupscript/failed_backups.txt"
PYTHON_SCRIPT="/var/backupscript/gdrive.py"
DB_USER="root"
GDRIVE_FOLDER_NAME="ServerBackups"
RETRY_MODE=false

mkdir -p "$BACKUP_DIR"
> "$LOG_FILE"
> "$FAILED_LIST"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get database names
DB_NAMES=$(mysql -u "$DB_USER" -e "SHOW DATABASES;" | tail -n +2 | grep -Ev "^(mysql|information_schema|performance_schema|sys)$")
echo "$DB_NAMES" > "$BACKUP_DIR/db_list.txt"

# Load retry list if in retry mode
if [[ "$1" == "--retry" ]]; then
    log "🔄 Retry mode activated!"
    RETRY_MODE=true
    mapfile -t RETRY_PROJECTS < "$FAILED_LIST"
fi

process_project() {
    local DIR=$1
    local PROJECT_NAME=$(basename "$DIR")
    local ZIP_NAME="${PROJECT_NAME}.zip"
    local SQL_NAME="${PROJECT_NAME}.sql"
    local STATUS_MSG=""

    log "📁 Processing: $PROJECT_NAME"

    # Fuzzy match DB
    MATCHED_DB=$(python3 -c "
from fuzzywuzzy import process
with open('$BACKUP_DIR/db_list.txt') as f:
    dbs = [line.strip() for line in f.readlines()]
match, score = process.extractOne('$PROJECT_NAME', dbs)
print(match if score > 60 else '')
")

    # Zip Codebase
    if ! zip -r "$BACKUP_DIR/$ZIP_NAME" "$DIR" > /dev/null; then
        log "❌ Failed to zip $PROJECT_NAME"
        echo "$PROJECT_NAME" >> "$FAILED_LIST"
        return
    fi

    # Dump DB if matched
    if [ -n "$MATCHED_DB" ]; then
        if ! mysqldump -u "$DB_USER" "$MATCHED_DB" > "$BACKUP_DIR/$SQL_NAME"; then
            log "❌ Failed to dump DB: $MATCHED_DB"
            echo "$PROJECT_NAME" >> "$FAILED_LIST"
            return
        fi
        log "✅ DB dumped: $MATCHED_DB"
    else
        log "⚠️  No matching DB for $PROJECT_NAME"
    fi

    log "✅ Codebase zipped: $ZIP_NAME"
}

# Loop through all projects
for DIR in "$WWW_DIR"/*; do
    if [ -d "$DIR" ]; then
        PROJECT_NAME=$(basename "$DIR")

        # Skip if in retry mode and not in failed list
        if $RETRY_MODE && [[ ! " ${RETRY_PROJECTS[*]} " =~ " $PROJECT_NAME " ]]; then
            continue
        fi

        process_project "$DIR"
    fi
done

# Upload to Drive
log "🚀 Uploading to Google Drive..."
if ! python3 "$PYTHON_SCRIPT" "$BACKUP_DIR" "$GDRIVE_FOLDER_NAME"; then
    log "❌ Upload to Google Drive failed."
else
    log "✅ Upload completed."
fi

log "📦 Backup process finished."
if [ -s "$FAILED_LIST" ]; then
    log "❗ Failed projects are listed in: $FAILED_LIST"
else
    log "🎉 All backups succeeded!"
    rm "$FAILED_LIST"
fi
