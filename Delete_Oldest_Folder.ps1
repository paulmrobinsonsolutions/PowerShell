Clear-Host
#*********************************************
# Description: This script will...
#  1. Determine the oldest folder given a root folder. Ex. C:\Temp\Some_Folder
#  2. Delete all contents with the "olderst" folder and folder itself
#  3. Provide runtime details like the current step its on
#  4. Provide the amount of time it took to run which you can then
#     then use to gage based on the number of files in each folder.
#*********************************************

<### --- BEGIN Predefined (or Input) variables --- ###>
# 1. Specify the root folder path to target
$path = "C:\Temp\Some_Folder"

# Set batch size to diplay progress status.
# Ex. Every x files deleted show a status update.
[int]$batchSizeForMsgDisplay = 50

# This will trigger the message display counter
[int]$batchSizeCounter = $batchSizeForMsgDisplay
<### --- END Predefined (or Input) variables --- ###>

Write-Host 
Write-Host "This session's processing has officially started..."
Write-Host 

# Capture this lil nugget to compare and contrast when this session finishes...
$sessionStartTime = Get-Date

# 1. Get the oldest folder's modified date/time
Write-Host "1. Getting the date of the oldest folder..."
Write-Host "     Started: $((Get-Date).ToString("hh:mm:ss tt"))"

# Get oldest folder's last access date/time
$oldestFolderDate = (Get-ChildItem $path -Attributes Directory | Sort-Object -Property LastWriteTime | Select-Object -First 1).LastWriteTime

# 2. Set the threshold date x days beyond the oldest folder t othen delete verything before
$thresholdDate = $oldestFolderDate.Date.AddDays(1)

Write-Host "   Completed: $((Get-Date).ToString("hh:mm:ss tt"))"
Write-Host "*** Oldest Folder -> $oldestFolderDate <- ***"
Write-Host 
Write-Host "2. Getting count of oflers to purge on this date..."
Write-Host "     Started: $((Get-Date).ToString("hh:mm:ss tt"))"

# 3. Get count of folders older than the $thresholdDate that will be deleted
[int]$itemCount = (Get-ChildItem $path -Attributes Directory | Where-Object { $_.LastWriteTime -le $thresholdDate } | Measure-Object).Count

Write-Host "   Completed: $((Get-Date).ToString("hh:mm:ss tt"))"
Write-Host "*** No. of files to purge -> $itemCount <- ***"
Write-Host 

if ($itemCount -eq 0) {
    Write-Host "No folders found to purge. Exiting script..."
    exit
}

Write-Host "4. The purge of folders/files has begun..."
Write-Host "     Started: $((Get-Date).ToString("hh:mm:ss tt"))"

# 4. Perform deletion of folders older than thresholdDate
# Let's ensure this is always set to run with each run of this script.
# We wouldn't want to keep endlessly keep increment each run of this script now would we?
[int]$idx = 0

# Let's capture this start time get a sense of how long this takes.
$sessionStartTime = Get-Date

Get-ChildItem -Path $path -Recurse -Directory | Where-Object {
    # Exclude files that begin with "template" and check if the file is older than the cutoff date
    $_.LastWriteTime -le $thresholdDate #-and $_.Name -notlike "*template*"  -and $_.Name -notlike "*input*" -and $_.Name -notlike "*splittext*"
} | ForEach-Object {

    # Delete the file
    Remove-Item $_.FullName -Force -Recurse
    
    $idx++
    if ($idx -ge $batchSizeCounter) {
        $timeSpan = New-TimeSpan -Start $sessionStartTime -End (Get-Date)
        $timeElapsed_Minutes = "{0:D2}" -f $timeSpan.TotalMinutes
        $timeElapsed_Seconds = "{0:D2}" -f $timeSpan.Seconds

        Write-Host "     Files deleted: $($batchSizeCounter)"
        Write-Host "     Elapsed time " $($timeElapsed_Minutes) "minutes " $timeElapsed_Seconds "seconds"
        $batchSizeCounter += $batchSizeForMsgDisplay
    }

    if ($idx -ge $itemCount) {
        $sessionEndTime = Get-Date
        Write-Host "   Completed at: $($sessionEndTime.ToString("hh:mm:ss tt"))"
        Write-Host 
        Write-Host "Alright we're one folder cleaner and free of!!!"
        Write-Host 

        $timeSpan = New-TimeSpan -Start $sessionStartTime -End $sessionEndTime

        $timeHour = "{0:D2}" -f $($timeSpan.Hours)
        $timeMinute = "{0:D2}" -f $($timeSpan.Minutes)
        $timeSecond = "{0:D2}" -f $($timeSpan.Seconds)

        Write-Host "Date of oldest folder :" $oldestFolderDate
        Write-Host "# files in that folder:" $itemCount
        Write-Host "Session was started at:" $sessionStartTime
        Write-Host "Session completed at  :" $sessionEndTime
        Write-Host "Total processing time : $($timeHour):$($timeMinute):$($timeSecond)"
        Write-Host 

        # Break out of the ForEach-Object loop
        Exit
    }
}

