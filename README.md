I came up with these scripts to ease and automate the process of compressing and uploading my multiple projects all in the same dir and their databases all separately to my google drive

## Requirments
```
sudo apt install zip mysql-client python3-pip -y
```
```
pip3 install google-api-python-client google-auth-httplib2 google-auth-oauthlib fuzzywuzzy python-Levenshtein
```

## Clone the repo in a dir different than the root of your projects

## Google Drive Credential
- Go to https://console.developers.google.com
- Enable Google Drive API
- Create OAuth 2.0 Client ID and download credentials.json
- Place credentials.json in the same directory as the script
- ssh into your server with ```ssh -L 8765:localhost:8765 <user>@<server_ip>```
- create a dir named ```project_backups```
- run this command to complete your authentication once and for all ```python3 </path/to/the/gdrive.py> </path/to/the/project_backups> ServerBackups```
- > ```ServerBackups```: Name of the Folder in the google drive you want the script to create and upload to
- the script will display a link from the goole drive auth, copy paste it into your browser, if it blocks you, add the same gmail as a test user in the credentials
- after completing the authentication, a file named token.json will be created in the same directory as the gdrive.py in your server
- > Give yourself some credit, you made it so far


### Google Drive Upload Script


## Primary Backup Script
> The script also looks for db names in mysql and uplaods them in the dir of the project beside the zipped version

change these vars in the backup_script.sh as per your need
```
WWW_DIR="/var/www"
BACKUP_DIR="/var/backupscript/project_backups"
LOG_FILE="/var/backupscript/backup_log.txt"
FAILED_LIST="/var/backupscript/failed_backups.txt"
PYTHON_SCRIPT="/var/backupscript/gdrive.py"
DB_USER="root"
GDRIVE_FOLDER_NAME="ServerBackups"
```
> In this case, the repo is cloned in the ```/var/backupscript``` but the projects are in ```/var/www```
