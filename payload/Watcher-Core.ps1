#requires -Version 5.1
<#
.SYNOPSIS
    Verifica e ripristina UNA VOLTA il mod "Sposta nel Workspace" per Vivaldi.
.DESCRIPTION
    Controllo "al volo" richiamato da Vivaldi-Launch.vbs (shortcut modificati)
    prima di aprire Vivaldi. Il ripristino automatico dopo gli aggiornamenti non
    dipende piu' da questo script ma dal sorvegliante in background
    Watcher-Daemon.ps1 (vedi RICHIESTA-004 nel Bugtracker): questo resta come
    secondo canale quando si apre Vivaldi dagli shortcut.
    Usa le stesse funzioni di Mod-Common.ps1 (idempotente, scrittura atomica).
    Non genera MAI un errore che impedisca l'avvio di Vivaldi: qualunque
    problema viene loggato e lo script esce comunque con codice 0.
.PARAMETER VivaldiAppRoot
    Percorso della cartella "Application" dell'installazione Vivaldi target,
    es. "H:\Vivaldi Standalone\Application".
.PARAMETER Quiet
    Mantenuto per compatibilita' (non viene piu' mostrata alcuna notifica).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Watcher-Core.ps1 -VivaldiAppRoot "H:\Vivaldi Standalone\Application"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$VivaldiAppRoot,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

try {
    . (Join-Path $PSScriptRoot 'Mod-Common.ps1')
    $masterJs = Join-Path (Get-ModRoot) 'payload\move-workspace-panel.js'
    $res = Invoke-RepairLatest -AppRoot $VivaldiAppRoot -MasterJs $masterJs
    if ($res -ne 'ok' -and $res -ne 'repaired') {
        Write-ModLog ("Watcher-Core: esito '" + $res + "' per '" + $VivaldiAppRoot + "'")
    }
    exit 0
} catch {
    try { Write-ModLog ('ERRORE IMPREVISTO (Watcher-Core): ' + $_.Exception.Message) } catch { }
    exit 0
}
