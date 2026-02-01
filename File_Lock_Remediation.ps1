Set-PSDebug -Off
#*********************************************
# Purpose: This script will "watch" an OCR processing folder for files that get "stuck" trying to OCR. These "bad"
#          files can be observed when the file count ticks up and down repeatedly very quickly. This indicates the
#          OCR tool is attempting to process the file but fails which is typically due to the size of the file or
#          simply a poor quality file that cannot be OCR'd by the OCR tool. Files that cannot get processed, will
#          be moved to the backlog folder so that processing may continue for all of the other files in the folder.
#          Once all files are processed in "watch folder", any files in the "Backlog" folder will be moved back to the
#          "watch folder" one-by-one to attempt OCR-ing again. If they fail again, they're moved to "exceptions" folder.
#
# General script processing:
#   1. Check $sourceFolder for any files...
#      1A. If files exist, then "check" each file up to $checkCountThreshold specified with 5 seconds between each check.
#          If the file still exists after $checkCountThreshold has been reached then move the file to the $backlogFolder
#          folder location specified. This is a temporary location where each file will be tried one more time.
#      1B. If files do NOT exist, then look in the $backlogFolder and move one file at a time back into the $sourceFolder
#          for the checks outlined in 1A. If the file cannot be moved then the file is moved to the $verifiedExceptionFolder
#          specified where the Business will then manually work these.
#
#*********************************************

#*** BEGIN script variables ***
$sourceFolder = "B:\Some_Folder\Your_Folder_To_Watch"
$backlogFolder = "B:\Some_Folder\Your_Backlog_Folder"
$verifiedExceptionFolder = "B:\Some_Folder\Your_Verified_Exceptions_Folder"
#*** END script variables ***

# 1. Get oldest file from OCR scan folder
# 2. Pause N seconds to check if file has been moved, pause N seconds bofore next loop
#    2a. If file cannot be processed/moved by ABBYY then move the "bad" file to backlog folder
#    2b. If file has been processed/moved... log and continue on to next file
Clear-Host

Write-Host 
$currentTime = Get-Date
Write-Host "Processs started at: $($currentTime.ToString("yyyy-MM-dd hh:mm:ss tt"))"

#Below is a dummy default value just to break into the loop to do the actual
[int]$fileCount = 1

#File variables
[string]$currentFile = ""
[string]$lastFile = ""
[int]$fileCheckCount = 0

# Threshold for number of checks before moving file to backlog
[int]$checkCountThreshold = 10

# Wait time between checks (in seconds)
[int]$checkWaitSeconds = 5

[int]$fileCount = 1

#Flag to indicate the file was already put in the Backlog folder
#If so, it's truly a problem file and should be move to 'Exceptions'
$isFromBacklog = "False"

while($fileCount -gt 0)
{
    # Since files are continuously dropped into the source folder,
    # move any files less than or equal to 1KB to exception folder immediately
    Get-ChildItem -Path $sourceFolder -File | Where-Object {$_.Length -le 1024} | Move-Item -Path $_.FullName -Destination $verifiedExceptionFolder -Force

    # Get count of files remaining in source folder
    $fileCount = (Get-ChildItem $sourceFolder -File | Measure-Object).Count

    # If files exist in $sourceFolder
    if($fileCount -gt 0)
    {
        # Get the oldest file in the source folder
        $currentFile = Get-ChildItem -Path $sourceFolder | Sort-Object Name | Select-Object -First 1

        if($currentFile -eq $lastFile)
        {
            Write-Host "   Check attempt #: $fileCheckCount"
        }
        else
        {
            # Reset variables for next file check
            $lastFile = $currentFile
            $fileCheckCount = 0

            # Re-check count of files remaining in source folder
            $fileCount = (Get-ChildItem $sourceFolder -File | Measure-Object).Count
            Write-Host "$((Get-Date).ToString("hh:mm:ss tt")) - File count in source: $($fileCount)"
            Write-Host "$((Get-Date).ToString("hh:mm:ss tt")) - Current file to check: $($currentFile)"
        }

        #If number of checks is greater than threshold... well this is a bad file, move it
        if($fileCheckCount -gt $checkCountThreshold)
        {
            $filePath = (Join-Path -Path $sourceFolder -ChildPath $currentFile)
            Write-Host "   File exceeded check attempts: $($filePath)"

            if($isFromBacklog -eq "True")
            {
                Move-Item -Path $filePath -Destination $verifiedExceptionFolder -Force
                #Write-Host $filePath
                Write-Host "   The file has been moved to the 'Verified Exceptions' folder"

                # Reset for next loop
                $isFromBacklog = "False"
            }
            else
            {
                Move-Item -Path $filePath -Destination $backlogFolder -Force
                #Write-Host $filePath
                Write-Host "   The file has been moved to the 'Exceptions' folder"
            }
        }
        
        # Increment the counter for the next iteration
        # NOTE: This also ensures > 0 for th efor-loop to continue
        $fileCheckCount++
    }

    # Else, if no files in source, check exception folder
    # It's possible other issues, like a brief network outage, caused files to not be processed
    else
    {
        Write-Host "$((Get-Date).ToString("hh:mm:ss tt")) - File count in source folder: $($fileCount)"
        $fileCount = (Get-ChildItem $backlogFolder -File | Measure-Object).Count
        Write-Host "$((Get-Date).ToString("hh:mm:ss tt")) - File count in backlog folder: $($fileCount)"

        # If there are backlog files then move one into source folder to attempt to process
        if($fileCount -gt 0)
        {
            #Get the oldest file from the Backlog folder and move back into process folder (folder to watch)
            #*NOTE: Ideally if this file still fails to be processed by the OCR tool, it's clearly
            #       a 'bad' file and should be moved to the 'Backlog" folder.
            $filePath = Get-ChildItem -File -Path $backlogFolder | Sort-Object LastWriteTime | Select-Object -First 1
        
            # Move the oldest file to the target folder
            Write-Host "   File being moved from: $($filePath.FullName.Replace($sourceFolder, '..'))"
            Move-Item -Path $filePath.FullName -Destination $sourceFolder -Force
    
            $isFromBacklog = "True"
        }
    }

    if($fileCount -eq 0)
    {
        Write-Host
        Write-Host "No files to process at this time. Buh bye!"
    }
    
    # Pause for N seconds
    Start-Sleep -Seconds $checkWaitSeconds
}

$currentTime = Get-Date
Write-Host "Processs completed at: $((Get-Date).ToString("yyyy-MM-dd hh:mm:ss tt"))"