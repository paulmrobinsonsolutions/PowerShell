Clear
#*********************************************
# Description: This script will...
#  1. Determine the oldest folder given a root folder. Ex. C:\Temp\Some_Folder
#  2. Delete all contents with the "olderst" folder and folder itself
#  3. Provide runtime details like the current step its on
#  4. Provide the amount of time it took to run which you can then
#     then use to gage based on the number of files in each folder.
#*********************************************

# 1. Specify the root folder path to target
$path = "C:\Temp\Some_Folder"
Write-Host 
Write-Host "This session's processing has officially started..."
Write-Host 

# 2. Identify the folder with the oldest date
$oldestFolderDate = (Get-Date -Format g)

# Capture this lil nugget to compare and contrast when this session finishes...
$sessionStartTime = Get-Date

Write-Host "1. Getting the date of the oldest folder..."
$currTime = Get-Date
Write-Host "     Started: " $currTime.ToString("hh:mm:ss tt")

# Get oldest folder's last access date/time
$oldestFolderDate = (Get-ChildItem $path -Attributes Directory | Sort-Object -Property LastWriteTime | Select-Object -First 1).LastWriteTime

$currTime = Get-Date
Write-Host "   Completed: " $currTime.ToString("hh:mm:ss tt")
Write-Host 
Write-Host "*** Oldest Folder -> $oldestFolderDate <- ***"

# 3. Set the threshold date X days beyond the oldest folder then delete everything older
$thresholdDate = $oldestFolderDate.Date
$thresholdDate = $thresholdDate.AddDays(1)

Write-Host 
Write-Host "2. Getting count of files in the oldest folder to purge..."
$currTime = Get-Date
Write-Host "     Started: " $currTime.ToString("hh:mm:ss tt")

# 4. Get count of folders older than the $thresholdDate that will be deleted
$itemCount = (Get-ChildItem $path -Attributes Directory | Where-Object { $_.LastWriteTime -le $thresholdDate } | Measure-Object).Count

$currTime = Get-Date
Write-Host "   Completed: " $currTime.ToString("hh:mm:ss tt")
Write-Host 
Write-Host "*** No. of files to purge -> $itemCount <- ***"
Write-Host 

Write-Host "3. The purge of the files has begun..."
$currTime = Get-Date
Write-Host "     Started: " $currTime.ToString("hh:mm:ss tt")

# 5. Perform deletion of folders older than thresholdDate
#Get-ChildItem $path -Attributes Directory | Where-Object { $_.LastWriteTime -lt $thresholdDate } | Remove-Item -Recurse -Force
Get-ChildItem -Path $path -Recurse -Directory | Where-Object {
    # Exclude files that begin with "template" and check if the file is older than the cutoff date
    $_.LastWriteTime -le $thresholdDate #-and $_.Name -notlike "*template*"  -and $_.Name -notlike "*input*" -and $_.Name -notlike "*splittext*"
} | ForEach-Object {
    ## Test purposes only. Or perhaps you would like to see the current VM?
    #Write-Host $idx":" $_.Name " - " $_.LastWriteTime
    # Delete the file
    Remove-Item $_.FullName -Force -Recurse
    
    $idx++
}

$sessionEndTime = Get-Date
Write-Host "   Completed: " $sessionEndTime.ToString("hh:mm:ss tt")
Write-Host 
Write-Host "Alright we're one folder cleaner and free of!!!"
Write-Host 

$timeSpan = $sessionEndTime - $sessionStartTime

$timeHour = "{0:D2}" -f $($timeSpan.Hours)
$timeMinute = "{0:D2}" -f $($timeSpan.Minutes)
$timeSecond = "{0:D2}" -f $($timeSpan.Seconds)

Write-Host "Date of oldest folder :" $oldestFolderDate
Write-Host "# files in that folder:" $itemCount
Write-Host "Session was started at:" $sessionStartTime
Write-Host "Session completed at  :" $currTime
#NOTE: The tick ' before : ?? Well PowerShell don't like : just so ya know!
Write-Host "Total processing time : $timeHour`:$timeMinute`:$timeSecond"
Write-Host 
