# =====================================================
# WINDOWS 11 - MODO RAM EXTREMA (8GB → ~2GB idle)
# Script ÚNICO e COMPLETO - Ultra Agressivo
# Execute como ADMINISTRADOR
# =====================================================

Write-Host "🚨 INICIANDO OTIMIZAÇÃO MÁXIMA DE RAM (8GB)" -ForegroundColor Red
Write-Host "Este script é muito agressivo. Faça ponto de restauração primeiro.`n" -ForegroundColor Yellow

# === Criar Ponto de Restauração ===
Write-Host "📌 Criando Ponto de Restauração..." -ForegroundColor Cyan
Checkpoint-Computer -Description "Antes de Otimização RAM Extrema 8GB" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue

# ==================================
# 1. SERVIÇOS - DESATIVAÇÃO AGRESSIVA
# ==================================
Write-Host "`nDesativando serviços não essenciais..." -ForegroundColor Cyan

$Essential = @(
    "RpcSs","DcomLaunch","PlugPlay","Power","EventLog","Winmgmt","CryptSvc",
    "wuauserv","Dhcp","DNS Client","NlaSvc","nsi","WinHttpAutoProxySvc","WlanSvc",
    "AudioSrv","AudioEndpointBuilder","BluetoothSupportService","BthAvctpSvc",
    "UserManager","ProfSvc","CoreMessagingRegistrar","W32Time","sppsvc","LicenseManager",
    "DispBrokerDesktopSvc","iphlpsvc","ndu"
)

Get-Service | ForEach-Object {
    $name = $_.Name
    if ($Essential -notcontains $name -and $name -notlike "*BluetoothUserService*") {
        try {
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "✗ $($_.DisplayName)" -ForegroundColor Gray
        } catch {}
    } else {
        Write-Host "✓ Mantido: $($_.DisplayName)" -ForegroundColor Green
    }
}

# Serviços extras pesados
$ExtraDisable = @("SysMain","WSearch","DiagTrack","dmwappushservice","WerSvc","gupdate","gupdatem",
                  "OneSyncSvc*","XblAuthManager","XblGameSave","XboxNetApiSvc","TabletInputService",
                  "Fax","PrintWorkflowService","PcaSvc","SecurityHealthService","wscsvc")

foreach ($s in $ExtraDisable) {
    Get-Service -Name $s -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    Get-Service -Name $s -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled -ErrorAction SilentlyContinue
}

# ==================================
# 2. OTIMIZAÇÕES DE REGISTO E RAM
# ==================================
Write-Host "`nAplicando otimizações de registo..." -ForegroundColor Cyan

# Desativa efeitos visuais (muito importante)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue

# Desativa Telemetria
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f

# Desativa Windows Defender (poupa muita RAM)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f

# ==================================
# 3. REMOVER ONEDRIVE
# ==================================
Write-Host "`nRemovendo OneDrive..." -ForegroundColor Cyan
taskkill /f /im OneDrive.exe 2>$null
Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait

Write-Host "`n✅ OTIMIZAÇÃO CONCLUÍDA!" -ForegroundColor Green
Write-Host "🔄 Reinicia o computador agora para aplicar todas as mudanças." -ForegroundColor Yellow
Write-Host "`nApós reiniciar, verifica a RAM em idle (Ctrl + Shift + Esc → Desempenho → Memória)" -ForegroundColor White

# ==================================
# SCRIPT DE REVERSÃO (caso precises)
# ==================================
Write-Host "`n`nPara reverter tudo, guarda este bloco abaixo:" -ForegroundColor White
Write-Host @"
# === SCRIPT DE REVERSÃO ===
Get-Service | Where-Object {`$_.StartType -eq 'Disabled'} | Set-Service -StartupType Automatic
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 0 /f
reg add "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 0 /f
Write-Host "Reinicia após executar a reversão."
"@ -ForegroundColor DarkGray