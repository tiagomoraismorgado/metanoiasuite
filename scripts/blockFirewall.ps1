<#
.SYNOPSIS
    Script de Configuração e Validação de Firewall com Bloqueio Total
.DESCRIPTION
    Configura o Firewall do Windows para bloquear todas as conexões de entrada e saída.
#>

# Forçar UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Verificar privilégios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERRO: Este script requer privilégios de Administrador!" -ForegroundColor Red
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Variáveis
$desktopPath = [Environment]::GetFolderPath("Desktop")
$validationScriptPath = Join-Path $desktopPath "validar_firewall_pos_reboot.ps1"
$logFile = Join-Path $desktopPath "firewall_config.log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    try { Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue } catch {}
    Write-Host $logMessage -ForegroundColor $Color
}

function Show-Menu {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       FIREWALL WINDOWS - BLOQUEIO TOTAL (v2.1)              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "1. Configurar Firewall com Bloqueio Total" -ForegroundColor Yellow
    Write-Host "2. Testar Configuração Atual" -ForegroundColor Yellow
    Write-Host "3. Criar Script de Validação Pós-Reboot" -ForegroundColor Yellow
    Write-Host "4. Executar Teste Completo (Configurar + Reboot)" -ForegroundColor Green
    Write-Host "5. Reverter para Configurações Padrão" -ForegroundColor Red
    Write-Host "6. Sair" -ForegroundColor White
}

function Set-FirewallBlockAll {
    Write-Log "Iniciando configuração de Bloqueio Total..." "Cyan"
    
    Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, DefaultOutboundAction | Format-Table

    $confirm = Read-Host "Deseja realmente bloquear TODAS as conexões (entrada e saída)? (S/N)"
    if ($confirm -notmatch '^S|s$') { return }

    try {
        # Bloqueio total
        foreach ($profile in "Domain", "Private", "Public") {
            Set-NetFirewallProfile -Name $profile `
                -DefaultInboundAction Block `
                -DefaultOutboundAction Block `
                -Enabled True
            Write-Host " ✓ Perfil $profile → Bloqueado (In/Out)" -ForegroundColor Green
        }

        # Regras essenciais (opcional)
        $createRules = Read-Host "Criar regras mínimas de sobrevivência (DNS + DHCP)? (S/N)"
        if ($createRules -match '^S|s$') {
            # DNS Outbound
            New-NetFirewallRule -DisplayName "Permitir DNS (Outbound)" `
                -Direction Outbound -Protocol UDP -RemotePort 53 `
                -Action Allow -Name "Permit-DNS-Out" -ErrorAction SilentlyContinue | Out-Null

            # DHCP Outbound
            New-NetFirewallRule -DisplayName "Permitir DHCP (Outbound)" `
                -Direction Outbound -Protocol UDP -LocalPort 68 -RemotePort 67 `
                -Action Allow -Name "Permit-DHCP-Out" -ErrorAction SilentlyContinue | Out-Null

            Write-Host " ✓ Regras essenciais (DNS/DHCP) criadas." -ForegroundColor Green
        }

        Write-Log "Bloqueio total aplicado com sucesso." "Green"
        Write-Host "`nAVISO: A internet ficará quase totalmente bloqueada!" -ForegroundColor Yellow
    }
    catch {
        Write-Log "Erro: $($_.Exception.Message)" "Red"
        Write-Host "Erro durante a configuração!" -ForegroundColor Red
    }
}

function Reset-FirewallDefaults {
    Write-Host "Restaurando configurações padrão do Firewall..." -ForegroundColor Cyan
    try {
        Set-NetFirewallProfile -All `
            -DefaultInboundAction Block `
            -DefaultOutboundAction Allow `
            -Enabled True

        Remove-NetFirewallRule -Name "Permit-DNS-Out" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -Name "Permit-DHCP-Out" -ErrorAction SilentlyContinue

        Write-Log "Firewall restaurado para padrão (Inbound Block | Outbound Allow)" "Green"
        Write-Host "Configurações restauradas com sucesso!" -ForegroundColor Green
    }
    catch {
        Write-Log "Erro ao restaurar: $($_.Exception.Message)" "Red"
    }
}

function New-PostRebootValidationScript {
    $content = @'
Write-Host "=== VALIDAÇÃO PÓS-REBOOT ===" -ForegroundColor Cyan
Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, DefaultOutboundAction | Format-Table

Write-Host "`nTestando conectividade (deve falhar)..." -ForegroundColor Yellow
$ping = Test-Connection 8.8.8.8 -Count 2 -Quiet

if ($ping) {
    Write-Host "FALHA: Conexão ainda está funcionando!" -ForegroundColor Red
} else {
    Write-Host "SUCESSO: Conexões bloqueadas conforme configurado." -ForegroundColor Green
}

Write-Host "`nPressione qualquer tecla para fechar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

    $content | Out-File -FilePath $validationScriptPath -Encoding utf8
    Write-Host "Script de validação pós-reboot criado em:" -ForegroundColor Green
    Write-Host $validationScriptPath -ForegroundColor White
}

function Main {
    do {
        Show-Menu
        $choice = Read-Host "`nEscolha uma opção"

        switch ($choice) {
            "1" { Set-FirewallBlockAll }
            "2" { 
                Write-Host "`nEstado atual do Firewall:" -ForegroundColor Yellow
                Get-NetFirewallProfile | Select-Object Name, DefaultInboundAction, DefaultOutboundAction | Format-Table
                
                Write-Host "`nTestando conexão (ping 8.8.8.8)..." -ForegroundColor Yellow
                $result = Test-Connection 8.8.8.8 -Count 2 -Quiet
                if ($result) {
                    Write-Host "Conexão OK" -ForegroundColor Green
                } else {
                    Write-Host "Sem conexão" -ForegroundColor Red
                }
            }
            "3" { New-PostRebootValidationScript }
            "4" { 
                Set-FirewallBlockAll
                New-PostRebootValidationScript
                $confirm = Read-Host "`nReiniciar o computador agora? (S/N)"
                if ($confirm -match '^S|s$') {
                    Restart-Computer -Confirm
                }
            }
            "5" { Reset-FirewallDefaults }
            "6" { Write-Host "Saindo..." -ForegroundColor White }
            default { Write-Host "Opção inválida!" -ForegroundColor Red }
        }

        if ($choice -ne "6") {
            Read-Host "`nPressione Enter para voltar ao menu"
        }
    } while ($choice -ne "6")
}

# Iniciar
Main