# imageDx-image-downloader
This repository contains tools for bulk downloading of imageDx images

Clone the repository or download the rpo

*** Windows Instructions ***

Open the Windows Folder and right click on the file and click "Open as an Administrator". 

If Gcloud SDK is not installed, it will prompt you to download it. It will eventually try to authenticate via a browser but you can close the browser session as we are going to use service keys for authorization.

*** Mac Instructions ***

Open the MacOS folder. Click on the "gcs_bucket_download" application. It would launch a terminal and a window like the image below.

<img width="448" alt="Screenshot" src="https://github.com/RevealBio/imageDx-image-downloader/assets/95322264/7e926f0b-a45e-4c9a-8514-cfe814dd0867">

Click on the Authenticate with Service Account first and attach the service account file sent to you privately. Copy the list of files you wish to download and paste it in the "Enter GCS Paths (one per line)" Box. Click download and it should start downloading the files.


