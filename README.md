# imageDx-image-downloader
This repository contains tools for bulk downloading of imageDx images

## Windows Instructions

### Step 1
Clone the repository or download the repo

### Step 2
Open the Windows Folder and right click on the file and click "Open as an Administrator". It will launch an window like the image below.

![InitDownloaderState](https://github.com/RevealBio/imageDx-image-downloader/assets/95322264/37aca493-9d9b-4b67-8cf5-725d3cbfc3c1)

### Step 3
If the service key file `service_key_YOUR_COMPANY_NAME.txt` is already in the same folder and it will detect it and make the "Authenticate with Service Account" button green. If not, click on the "Authenticate with Service Account" button first and select the service account file sent to you privately.  Once authenticated, the "Authenticate with Service Account" button turns green.

### Step 4
The list gets prepopulated in the list of downloads file called `gcsPaths.txt` is in the same directory as the script. Copy the list of files you wish to download and paste it in the "Enter GCS Paths (one per line)" Box. Click download and it should start downloading the files.

If Gcloud SDK is not installed, it will prompt you to download it. It will eventually try to authenticate via a browser but you can close the browser session as we are going to use service keys for authorization.

## Mac Instructions

### Step 1
Clone the repository or download the repo

### Step 2
Open the MacOS folder. Click on the "gcs_bucket_download" application. It would launch a terminal and a window like the image below.

<img width="448" alt="Screenshot" src="https://github.com/RevealBio/imageDx-image-downloader/assets/95322264/7e926f0b-a45e-4c9a-8514-cfe814dd0867">

### Step 3
If the service key file `service_key_YOUR_COMPANY_NAME.txt` is already in the same folder and it will detect it and turn the "Authenticate with Service Account" button green. If not, click on the "Authenticate with Service Account" button first and select the service account file sent to you privately. Once authenticated, the "Authenticate with Service Account" button turns green.

### Step 4
Copy the list of files you wish to download from the file `gcsPaths.txt` and paste it in the "Enter GCS Paths (one per line)" Box. Click download and it should start downloading the files.
If Gcloud SDK is not installed, it will prompt you to download it. It will eventually try to authenticate via a browser but you can close the browser session as we are going to use service keys for authorization.













