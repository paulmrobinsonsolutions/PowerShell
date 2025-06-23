Set-PSDebug -Off
#****************************
# Decription: Perform VM cleanup and gather C drive free space GB (available)
#****************************
# --- progress bar cogit@github.com:paulmrobinsonsolutions/PowerShell.gitde... have fun figuring it out
#for ($i = 1; $i -le 100; $i++ ) {
#    Write-Progress -Activity "Search in Progress" -Status "$i% Complete:" -PercentComplete $i
#    Start-Sleep -Milliseconds 400
#}

######### IMPORTANT #########
# Be sure to login to Azure!!! This does NOT need to be done every time but will need to be
# after extended periods of idle time and/or not being logged onto the NGrid network.
# To login, enter command: az login
# To logout, enter command: az logout
#############################

#########   BEGIN CONFIGURABLE / CHANGEABLE TO YOUR LIKING SECTION   #########

# The starting part of VM name up to and including (for now) the envirnment character indicator; "D" or "P"
$vmNameFormat = "AZUSE-TWD"

# Based on standard naming convention with digits at the end of Virtual Machine names, 
# you can limit the range of machines you want to target for cleanup.
[int]$startVmNumber = 01
[int]$maxVmNumber = 20

# How many days do you want to leave? Or in other words, 
# anything older than the specified number (below) will be deleted.
# What threshhold number of days for folders in C:\Temp\Some_Folder should remain?
[int]$numOfDaysPriorToLeave = 5

#########   END CONFIGURABLE / CHANGEABLE TO YOUR LIKING SECTION   #########

#########   BEGIN DYNAMIC VARIABLE INITIALIZATION SECTION   #########

# Given we know Prod VMs have "P" in their machine name, let's set the resource group accordingly.
# But lets default to dev resource group, its just safer. Less risk.
$resourceGroup = "your-dev-resource-group"

# If $vmNameFormat does NOT end with "P", it's non-prod so change to "dev" resource group
If(!$vmNameFormat.EndsWith("P")) {
    $resourceGroup = "your-prod-resource-group"
}

# *** The main azure PowerShell command that all actual PowerShell scripts get appended to. ***
$cmd = "az vm run-command invoke --command-id RunPowerShellScript --name {0} -g $resourceGroup --scripts"

# Script 1: Get C drive free disk space; 'Free (GB)' being the output column name in this script's results
$script1 = "'Get-PSDrive -Name C'"

# Script 2: Well as it says... Remove (aka Delete) all items within the specified folders.
#           The folders themselves, DO NOT get removed/deleted. Wheew.
$script2 = "'Remove-Item C:\temp\* -Recurse -Force
Remove-Item C:\Windows\ccmcache\* -Recurse -Force
Remove-Item C:\Windows\Logs\CBS\* -Recurse -Force
Remove-Item C:\Windows\SoftwareDistribution\Download\* -Recurse -Force
Remove-Item C:\ProgramData\VMware\VDM\Dumps\* -Recurse -Force'"

$sessionStartTime = Get-Date

# Set the threshhold date. Anything older will be deleted. Bu bye.
# NOTE: This setup is needed for reference in Script #3
$threshholdDate = ((Get-Date).AddDays(-$numOfDaysPriorToLeave)).ToString("MM/dd/yyyy")

# Script 3: Remove folders (and all content) within/under the C:\PSTranscript\ folder that were created more than x days ago (see code on previous line plz)
# ***NOTE the special ticks -> ` <- to escape certaion special character like $ as an example
$script3 = "'Get-ChildItem `"C:\Temp\Some_Folder`" -Attributes Directory | Where-Object { `$_.LastWriteTime -lt (Get-Date `"$threshholdDate`") } | Remove-Item -Recurse -Force'"

# Just some variables to help with a fun lil timer function to see how long things take to run,
# at whichever point we choose...
[int]$timeElapsed_Minutes = 0
[int]$timeElapsed_Seconds = 0

# Temporary variable to dynamically concatenate the VM's name as it loops until complete
$vmName = ""

#########   END DYNAMIC VARIABLE INITIALIZATION SECTION   #########

#########   THE REAL WORK BEGINS... SECTION   #########
Clear

# And let's start that timer ticking
$timer = [System.Diagnostics.Stopwatch]::New()

# VM machine number to start with
[int]$idx = $startVmNumber
Write-Host "The C:\PSTranscript Threshhold date is: " $threshholdDate
Write-Host "This session processing has begun... " (Get-Date).ToString("hh:mm:ss tt")
Write-Host ""
do 
{
    # Exclude VMs with the following in their number... there must be a better way
    # ?? TWD --> 32-36, 39-41
    If($idx -In (3))
    {
       #do nothing, move on with your life
    }
    else
    {
        # Let's kick off the 'ol ticker
        $timer.Start()

        #reset to baseline image name
        $vmName = $vmNameFormat
        If($idx -lt 10)
        {
            # If $idx is single char/digit, add a zero for proper VM Name format. Ex. "05"
            $vmName += "0"
        }

        $vmName += $idx
        $cmdScript = $cmd.Replace("{0}", $vmName)

        Write-Host "Clean up has started on VM: $vmName"
    
        # Below concatenates the Azure command and script to run
        Write-Host "   Starting C drive free space check... "
        $result = Invoke-Expression "$cmdScript $script1"
        
        # If the result is null then there's an error. Check out the error details to
        # determine the problem and well there's no need to try anything else on the
        # respective VM because it won't work so let's just move on and call it a day.
        if ($null -eq $result) {
            # Uncomment the below if you really are interested in full error details.
            #Write-Host "Error: $Error[0]"
        } else {

            #To extract 'Free (GB)' value... substring "FileSystem" text - 10, trim whitespace
            $searchIdx = $result[6].IndexOf("FileSystem")
            $freeGB = $result[6].Substring($searchIdx - 10, 9).Trim()
            Write-Host "     Free GB: $freeGB"
        
            Write-Host "   Starting C:\Windows folder purge... "
            Invoke-Expression "$cmdScript $script2" | Out-Null
        
            Write-Host "   Starting C:\PSTranscript folder purge... "
            $result = Invoke-Expression "$cmdScript $script3"
        
            if( ($result | ConvertFrom-Json).value.message[1].Length -eq 0 ) {
                Write-Host "     The purge was successful."
            }
            else {
                Write-Host "     Fatal Error bruh..."
                Write-Host "     Error: $result"
            }

            Write-Host "   Starting C drive free space check... "
            $result = Invoke-Expression "$cmdScript $script1"
        
            #To extract 'Free (GB)' value... substring "FileSystem" text - 10, trim whitespace
            $searchIdx = $result[6].IndexOf("FileSystem")
            $freeGB = $result[6].Substring($searchIdx - 10, 9).Trim()
            Write-Host "     Free GB: $freeGB"
        }

        # Stop the timer, work is done in these here parts
        $timer.Stop()
        #get timespan -> seconds elapsed
        [float]$secondsElapsed = $timer.Elapsed.TotalSeconds.ToString("###.#")
        # Round down (Floor) to remove any decimal values, we only want whole numbers
        $timeElapsed_Minutes = [math]::Floor($secondsElapsed / 60)
        $timeElapsed_Seconds = [math]::Round($secondsElapsed - ($timeElapsed_Minutes * 60), 0)
        
        #Write-Host "Total seconds: $secondsElapsed"
        Write-Host "Done. Elapsed Time: $timeElapsed_Minutes minutes, $timeElapsed_Seconds seconds
        "
    }

    $idx++
    $freeGB = $null
    $timer.Reset()

} until ($idx -gt $maxVmNumber)

$sessionEndTime = Get-Date
Write-Host "Processing has completed at " ($sessionEndTime).ToString("hh:mm:ss tt")
$timeSpan = $sessionEndTime - $sessionStartTime

$timeHour = "{0:D2}" -f $($timeSpan.Hours)
$timeMinute = "{0:D2}" -f $($timeSpan.Minutes)
$timeSecond = "{0:D2}" -f $($timeSpan.Seconds)
#NOTE: The tick ' before : ?? Well PowerShell don't like : just so ya know!
Write-Host "Session run time: $timeHour`:$timeMinute`:$timeSecond"