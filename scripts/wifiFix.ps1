# WiFi Controller Complete Removal Script for Windows 11
# Run as Administrator
# WARNING: This script will completely remove WiFi adapters and settings without reinstalling

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WiFi Controller Complete Removal Tool" -ForegroundColor Cyan
Write-Host "Windows 11 Edition" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This script will COMPLETELY REMOVE WiFi functionality" -ForegroundColor Red
Write-Host "WiFi will NOT be re-enabled automatically" -ForegroundColor Red
Write-Host ""

# Create backup timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFolder = "$env:USERPROFILE\Desktop\WiFi_Backup_$timestamp"
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

Write-Host "[1/9] Creating backup of current WiFi configuration..." -ForegroundColor Yellow
netsh wlan export profile folder="$backupFolder" key=clear | Out-Null
Write-Host "Backup saved to: $backupFolder" -ForegroundColor Green

Write-Host "[2/9] Stopping WiFi services..." -ForegroundColor Yellow
Stop-Service -Name WlanSvc -Force -ErrorAction SilentlyContinue
Stop-Service -Name WlanScan -Force -ErrorAction SilentlyContinue
Stop-Service -Name Wlansvc -Force -ErrorAction SilentlyContinue
Set-Service -Name WlanSvc -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service -Name WlanScan -StartupType Disabled -ErrorAction SilentlyContinue
Set-Service -Name Wlansvc -StartupType Disabled -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "[3/9] Removing all WiFi profiles..." -ForegroundColor Yellow
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    ($_ -split ":")[1].Trim()
}
foreach ($profile in $profiles) {
    netsh wlan delete profile name="$profile" | Out-Null
}
Write-Host "Removed $($profiles.Count) WiFi profiles" -ForegroundColor Green

Write-Host "[4/9] Disabling WiFi adapters permanently..." -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Name -like "*WiFi*" -or $_.Name -like "*Wireless*" -or $_.InterfaceDescription -like "*802.11*" }

foreach ($adapter in $adapters) {
    Write-Host "  Disabling: $($adapter.Name)" -ForegroundColor Gray
    Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
    # Disable the adapter completely (prevent re-enable)
    Set-NetAdapter -Name $adapter.Name -AdminEnabled $false -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "[5/9] Removing WiFi adapter devices..." -ForegroundColor Yellow
$wifiDevices = Get-PnpDevice | Where-Object { $_.Class -eq "Net" -and ($_.FriendlyName -like "*WiFi*" -or $_.FriendlyName -like "*Wireless*" -or $_.FriendlyName -like "*802.11*") }

foreach ($device in $wifiDevices) {
    if ($device.Status -eq "OK" -or $device.Status -eq "Error") {
        Write-Host "  Uninstalling device: $($device.FriendlyName)" -ForegroundColor Gray
        $null = & pnputil /remove-device "$($device.InstanceId)" 2>$null
        Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Write-Host "[6/9] Removing WiFi drivers from driver store..." -ForegroundColor Yellow
# Get and remove WiFi drivers (WARNING: This may affect other network devices)
$wifiDrivers = Get-WindowsDriver -Online | Where-Object { 
    $_.OriginalFileName -like "*wifi*" -or 
    $_.OriginalFileName -like "*wireless*" -or 
    $_.OriginalFileName -like "*802.11*" -or
    $_.ProviderName -like "*Intel*Wireless*" -or
    $_.ProviderName -like "*Realtek*Wireless*" -or
    $_.ProviderName -like "*Broadcom*Wireless*" -or
    $_.ProviderName -like "*Qualcomm*Wireless*"
}

foreach ($driver in $wifiDrivers) {
    Write-Host "  Removing driver: $($driver.ProviderName) - $($driver.OriginalFileName)" -ForegroundColor Gray
    Remove-WindowsDriver -Online -Driver $driver.OriginalFileName -ErrorAction SilentlyContinue
}

Write-Host "[7/9] Removing hidden WiFi adapter registry entries..." -ForegroundColor Yellow
# Remove WiFi adapter registry entries
$adapterKeys = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
    $desc = (Get-ItemProperty -Path $key.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($desc -like "*WiFi*" -or $desc -like "*Wireless*" -or $desc -like "*802.11*") {
        Write-Host "  Removing registry entry: $desc" -ForegroundColor Gray
        Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove network profile registry entries
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[8/9] Resetting TCP/IP stack and clearing network configuration..." -ForegroundColor Yellow
netsh int ip reset
netsh winsock reset
ipconfig /release
ipconfig /flushdns
nbtstat -R
nbtstat -RR

Write-Host "[9/9] Final cleanup and applying firewall rules..." -ForegroundColor Yellow
# Block WiFi-related firewall rules
netsh advfirewall firewall add rule name="Block WiFi" dir=in action=block program="%SystemRoot%\System32\svchost.exe" service="WlanSvc" enable=yes
netsh advfirewall firewall add rule name="Block WiFi Out" dir=out action=block program="%SystemRoot%\System32\svchost.exe" service="WlanSvc" enable=yes

# Disable WLAN autoconfig via registry
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WlanSvc" -Name "Start" -Value 4 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WlanSvc" -Name "DelayedAutoStart" -Value 0 -Type DWord -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "WiFi Controller Complete Removal Finished!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "A backup of your WiFi profiles has been saved to:" -ForegroundColor Yellow
Write-Host "$backupFolder" -ForegroundColor Cyan
Write-Host ""
Write-Host "WiFi has been COMPLETELY REMOVED and DISABLED" -ForegroundColor Red
Write-Host "- WiFi services are disabled" -ForegroundColor Red
Write-Host "- WiFi adapters are disabled and removed" -ForegroundColor Red
Write-Host "- WiFi drivers have been removed" -ForegroundColor Red
Write-Host "- WiFi registry entries have been deleted" -ForegroundColor Red
Write-Host ""
Write-Host "To restore WiFi functionality later:" -ForegroundColor Yellow
Write-Host "1. Run Windows Update to reinstall WiFi drivers" -ForegroundColor Gray
Write-Host "2. Or manually reinstall drivers from manufacturer website" -ForegroundColor Gray
Write-Host "3. Enable WLAN AutoConfig service" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: A system restart is REQUIRED for all changes to take effect." -ForegroundColor Red
Write-Host ""

$restart = Read-Host "Do you want to restart your computer now? (Y/N)"
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Write-Host "Restarting computer in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer
} else {
    Write-Host "Please restart your computer manually to complete the WiFi removal." -ForegroundColor Yellow
}