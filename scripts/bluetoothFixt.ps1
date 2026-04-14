# Bluetooth Rescue Script v4.0
# Fixed version - ASCII only, no smart quotes

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Bluetooth Rescue Suite v4.0"
Clear-Host

Write-Host "======================================"
Write-Host "  BLUETOOTH RESCUE SUITE v4.0"
Write-Host ""
Write-Host "  [1] Diagnostic Mode"
Write-Host "  [2] Quick Fix Mode"
Write-Host "  [3] Nuclear Mode"
Write-Host "  [4] Exit"
Write-Host "======================================"

$choice = Read-Host "`nSelect mode [1-4]"

if ($choice -eq "1") {
    Clear-Host
    Write-Host "DIAGNOSTIC MODE" -ForegroundColor Cyan
    Write-Host "`n[1] Bluetooth Adapter Status:" -ForegroundColor Yellow
    $btAdapters = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where-Object {$_.FriendlyName -notlike "*Enumerate*"}
    if ($btAdapters) {
        $btAdapters | Format-Table Status, FriendlyName -AutoSize
    } else {
        Write-Host "No Bluetooth adapters found" -ForegroundColor Red
    }
    
    Write-Host "`n[2] Bluetooth Services Status:" -ForegroundColor Yellow
    $btServices = Get-Service -Name "*bth*" -ErrorAction SilentlyContinue
    if ($btServices) {
        $btServices | Format-Table Name, Status -AutoSize
    } else {
        Write-Host "No Bluetooth services found" -ForegroundColor Red
    }
    
    Write-Host "`nDiagnostic complete" -ForegroundColor Green
    Read-Host "Press Enter to exit"
    exit
}

if ($choice -eq "2") {
    Clear-Host
    Write-Host "QUICK FIX MODE" -ForegroundColor Green
    
    Write-Host "`n[1/4] Stopping Bluetooth services..." -ForegroundColor Cyan
    $services = @("BTAGService", "bthserv", "BthAvctpSvc", "BthHFSrv")
    foreach ($svc in $services) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped: $svc" -ForegroundColor Green
        }
    }
    
    Write-Host "`n[2/4] Removing Bluetooth adapter..." -ForegroundColor Cyan
    $btAdapters = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where-Object {$_.FriendlyName -notmatch "Enumerate"}
    if ($btAdapters) {
        foreach ($adapter in $btAdapters) {
            Write-Host "Removing: $($adapter.FriendlyName)" -ForegroundColor Yellow
            pnputil /remove-device $adapter.InstanceId 2>&1 | Out-Null
        }
    }
    
    Write-Host "`n[3/4] Clearing Bluetooth registry..." -ForegroundColor Cyan
    $regKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Bluetooth",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Bluetooth",
        "HKCU:\Software\Microsoft\Bluetooth"
    )
    foreach ($key in $regKeys) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Wiped: $key" -ForegroundColor Green
        }
    }
    
    Write-Host "`n[4/4] Scanning for hardware..." -ForegroundColor Cyan
    pnputil /scan-devices 2>&1 | Out-Null
    Write-Host "Scan complete" -ForegroundColor Green
    
    Write-Host "`nQUICK FIX COMPLETE!" -ForegroundColor Green
    Write-Host "Please reboot your computer now."
    $reboot = Read-Host "Reboot now? (Y/N)"
    if ($reboot -eq "Y" -or $reboot -eq "y") {
        Restart-Computer -Force
    }
    exit
}

if ($choice -eq "3") {
    Clear-Host
    Write-Host "NUCLEAR MODE - COMPLETE ANNIHILATION" -ForegroundColor Red
    Write-Host "This will destroy ALL Bluetooth components!" -ForegroundColor Red
    $confirm = Read-Host "Type NUKE to confirm"
    if ($confirm -ne "NUKE") {
        Write-Host "Cancelled."
        exit
    }
    
    Write-Host "`n[1/5] Stopping services..." -ForegroundColor Red
    $killServices = @("BTAGService", "bthserv", "BthAvctpSvc", "BthHFSrv", "BthEnum", "BthLEEnum", "BthMtpEnum", "bthpan", "BTHPORT", "BTHUSB")
    foreach ($svc in $killServices) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            sc.exe delete $svc 2>&1 | Out-Null
            Write-Host "Removed: $svc" -ForegroundColor Green
        }
    }
    
    Write-Host "`n[2/5] Purging devices..." -ForegroundColor Red
    $allBtDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {$_.Class -eq "Bluetooth"}
    if ($allBtDevices) {
        foreach ($dev in $allBtDevices) {
            Write-Host "Removing: $($dev.FriendlyName)" -ForegroundColor Yellow
            pnputil /remove-device $dev.InstanceId 2>&1 | Out-Null
        }
    }
    
    Write-Host "`n[3/5] Deleting driver files..." -ForegroundColor Red
    $pathsToDelete = @(
        "$env:SystemRoot\System32\DriverStore\FileRepository\*bth*",
        "$env:SystemRoot\System32\Drivers\*bth*.sys",
        "$env:SystemRoot\System32\bth*.dll"
    )
    foreach ($path in $pathsToDelete) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Drivers removed" -ForegroundColor Green
    
    Write-Host "`n[4/5] Wiping registry..." -ForegroundColor Red
    $nukeKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT",
        "HKLM:\SYSTEM\CurrentControlSet\Services\BTHUSB",
        "HKLM:\SYSTEM\CurrentControlSet\Enum\BTH",
        "HKLM:\SOFTWARE\Microsoft\Bluetooth",
        "HKCU:\SOFTWARE\Microsoft\Bluetooth"
    )
    foreach ($key in $nukeKeys) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Wiped: $key" -ForegroundColor Green
        }
    }
    
    Write-Host "`n[5/5] Disabling Fast Startup..." -ForegroundColor Red
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f 2>&1 | Out-Null
    powercfg /h off 2>&1 | Out-Null
    pnputil /scan-devices 2>&1 | Out-Null
    
    Write-Host "`nNUCLEAR PROTOCOL COMPLETE!" -ForegroundColor Red
    Write-Host "Rebooting in 10 seconds..."
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}

if ($choice -eq "4") {
    Write-Host "Exiting..."
    exit
}

if ($choice -notin @("1", "2", "3", "4")) {
    Write-Host "Invalid choice"
    exit
}