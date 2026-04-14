# ================================================
# Script: Disable-LSA-Protection.ps1
# Desativa a Proteção LSA (RunAsPPL) + abre Regedit
# ================================================

# Verifica se está a correr como Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Este script precisa de ser executado como Administrador!" -ForegroundColor Red
    Write-Host "Clique direito no PowerShell e escolha 'Executar como administrador'." -ForegroundColor Yellow
    Pause
    exit
}

Write-Host "🔄 A desativar a Proteção LSA..." -ForegroundColor Cyan

try {
    # Define as chaves do registo
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    
    # Desativa RunAsPPL
    Set-ItemProperty -Path $RegPath -Name "RunAsPPL" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $RegPath -Name "RunAsPPLBoot" -Value 0 -Type DWord -Force

    Write-Host "✅ Proteção LSA desativada com sucesso!" -ForegroundColor Green
    Write-Host "   RunAsPPL = 0" -ForegroundColor Green

} catch {
    Write-Host "❌ Erro ao alterar o registo: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# ==================== NOVO: Abre o Editor de Registo ====================
Write-Host "🔍 A abrir o Editor de Registo na chave LSA..." -ForegroundColor Cyan
Start-Process regedit.exe -ArgumentList "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa"

# =====================================================================

# Pergunta se quer reiniciar agora
$Restart = Read-Host "Deseja reiniciar o computador agora? (S/N)"
if ($Restart -eq 'S' -or $Restart -eq 's') {
    Write-Host "🔄 A reiniciar o computador em 5 segundos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host "⚠️  Lembre-se de reiniciar o computador para que as alterações tenham efeito." -ForegroundColor Yellow
}

Write-Host "`nScript concluído." -ForegroundColor Cyan