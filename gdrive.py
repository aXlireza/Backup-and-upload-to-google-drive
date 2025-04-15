import os
import sys
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ['https://www.googleapis.com/auth/drive.file']

from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

def authenticate():
    creds = None
    # Look for an existing token.
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    # If no (or invalid) credentials, do the OAuth flow.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=8765, open_browser=False)
        # Save the credentials for future use.
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    return creds

def get_or_create_folder(service, folder_name, parent_id=None):
    """
    Searches for a folder with the given name. If not found, creates it.
    When parent_id is provided, it ensures the folder is created under that parent.
    """
    query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'"
    if parent_id:
        query += f" and '{parent_id}' in parents"
    results = service.files().list(q=query, spaces='drive', fields="files(id, name)").execute()
    items = results.get('files', [])
    if items:
        return items[0]['id']
    file_metadata = {
        'name': folder_name,
        'mimeType': 'application/vnd.google-apps.folder'
    }
    if parent_id:
        file_metadata['parents'] = [parent_id]
    file = service.files().create(body=file_metadata, fields='id').execute()
    return file.get('id')

def upload_files(directory, primary_folder_name):
    """
    1. Authenticates and builds the Google Drive service.
    2. Creates (or finds) the primary folder (e.g., "ServerBackups").
    3. Iterates over each file in the given local directory, creates a subfolder for that project,
       and uploads the file into that subfolder.
    """
    creds = authenticate()
    service = build('drive', 'v3', credentials=creds)

    # Create or get the primary folder on Drive.
    primary_folder_id = get_or_create_folder(service, primary_folder_name)
    print(f"Primary folder '{primary_folder_name}' has ID: {primary_folder_id}")

    # Process each file from the local backup directory.
    for file_name in os.listdir(directory):
        filepath = os.path.join(directory, file_name)
        if os.path.isfile(filepath):
            # Use the file name (without extension) as the project folder name.
            project_folder_name = os.path.splitext(file_name)[0]
            # Create or get the project subfolder under the primary folder.
            project_folder_id = get_or_create_folder(service, project_folder_name, parent_id=primary_folder_id)
            print(f"\nUploading '{file_name}' into project folder '{project_folder_name}' (ID: {project_folder_id})")

            file_metadata = {
                'name': file_name,
                'parents': [project_folder_id]
            }
            media = MediaFileUpload(filepath, resumable=True)
            service.files().create(body=file_metadata, media_body=media, fields='id').execute()
            print(f"Uploaded: {file_name}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 gdrive.py <local_directory> <primary_drive_folder>")
        sys.exit(1)
    upload_files(sys.argv[1], sys.argv[2])
