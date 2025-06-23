# Description: This script will perform the complete install upgrade for "The App"
# which includes moving the necessary install files from a file share to the local
# machine to then run the install exe and step through the wizard. Upon the completion
# of the install, the "Windows & Features" dialog will be opened, then "The App" will
# be searched and prented to then display the version. It will be updated to the latest
# version per the install exe. Yes, unfortunately this must be visually confirmed.

# NOTE: This can only be run if you're administrator on the machine...

# Get the exact time into a var to evaluate later.
$minuteStart = Get-Date -format "mm"
$scriptStartTime = Get-Date

# Remove any direct ownership
takeown /a /r /d Y /f "C:\Some_Folder\Subfolder\You_Want_Ownership_Changed"

# Apply formerly "indirect" ownership's to current logged on user
icacls.exe "C:\Some_Folder\Subfolder\You_Want_Ownership_Changed" /reset /q /c /t

# Set as administrator owner
icacls.exe "C:\Some_Folder\Subfolder\You_Want_Ownership_Changed" /setowner Administrators /q /c /t
# *** End section for commands from "The app" installer folks ***

# Copy the installer exe and supporting files. Exclude any zip files in that folder
Copy-Item -Path "\\Network_Path\Folder_That_Contains\Files_To_Perform_Install\*" -Destination "c:\temp\" -Recurse -Exclude *.zip

# Below will open the folder in Windows explorer.
# Note: This will based on subfolder from previous command (above)
# explorer C:\temp\Files_To_Perform_Install\

# Start the installer exe
Start-Process C:\temp\Files_To_Perform_Install\Some_App_SetupClient.exe

# Capture the minute the process reached this point
$minuteEnd = Get-Date -format "mm"
$installStartTime = Get-Date

"Estimated PowerShell script time to complete was... "

# Because we start with assuming the minute is going to be larger than the start time,
# is because until the time passes 12 0'Clock hand, the minutes return to zero...
# in that case, let's add 60 minutes so we always have the end date being the larger number,
# then the math is much betterer because it'll always be the same calc bruhhh
if ($minuteEnd -lt $minuteStart) {
    (($minuteEnd + 60) - $minuteStart).ToString() + " minutes"
} else {
    ($minuteEnd - $minuteStart).ToString() + " minutes"
}

# Attach to the Some_App_SetupClient.exe installer name then hit 'Enter' key 3 times
# to start the installation
Start-Sleep 1
$wshell = New-Object -ComObject wscript.shell;
$wshell.AppActivate('Some_App_SetupClient_Screen_Name')
Start-Sleep 1
$wshell.SendKeys('~')
Start-Sleep 1
$wshell.SendKeys('~')
Start-Sleep 1
$wshell.SendKeys('~')

"Script start time: " + $scriptStartTime.ToString("hh:mm tt")
"Install start time: " + $installStartTime.ToString("hh:mm tt")
"Completion end time: " + (Get-Date).ToString("hh:mm tt")

$minuteAppInstallCmpl = Get-Date -format "mm"
"Estimated app install time to complete was... "
if ($minuteAppInstallCmpl -lt $minuteStart) {
    (($minuteAppInstallCmpl + 60) - $minuteStart).ToString() + " minutes"
} else {
    ($minuteAppInstallCmpl - $minuteStart).ToString() + " minutes"
}

# Open Windows Apps & Features like a boss...
# Tab to search box then enter "tani" to see the current
# version of "The app". It should be updated ;)
Start-Process ms-settings:appsfeatures
Start-Sleep 1
$wshell = New-Object -ComObject wscript.shell;
$wshell.AppActivate('Settings')
Start-Sleep 1
$wshell.SendKeys('{tab}')
Start-Sleep 1
$wshell.SendKeys('{tab}')
Start-Sleep 1
$wshell.SendKeys('tani')
