#requires -Version 5.1
<#
.SYNOPSIS
    Sorvegliante in background del mod "Sposta nel Workspace": rimette la mod
    in Vivaldi dopo ogni aggiornamento, senza reinstallare e senza riavviare Windows.
.DESCRIPTION
    Avviato nascosto al login (voce HKCU\...\Run, nessun diritto di amministratore)
    e subito dopo l'installazione. Resta in attesa di EVENTI, non fa cicli veloci:
      - un FileSystemWatcher sulla cartella "Application" segnala quando compare
        una nuova cartella versione (l'aggiornatore di Vivaldi la crea all'inizio
        dell'aggiornamento, anche una decina di minuti PRIMA di riavviare Vivaldi);
      - da quel momento, e per ActiveWindowMinutes minuti, ogni ActiveTickSeconds
        secondi controlla se window.html e' completo e stabile (nessuno lo sta
        scrivendo) e, appena lo e', ci mette il tag. Poi continua a verificare
        per sicurezza (se l'aggiornatore lo riscrive, viene rimesso);
      - a riposo si sveglia solo ogni IdleTickMinutes minuti per un controllo
        di sicurezza (copre: watcher avviato dopo l'aggiornamento, unita' non
        ancora disponibile al login, ecc.).
    Un solo watcher alla volta (mutex). Tutte le scritture sono atomiche
    (file temporaneo + sostituzione) e c'e' il backup window.html.bak.
    Le installazioni da sorvegliare sono in %LocalAppData%\VivaldiWSMod\roots.json.
    Log breve (con rotazione) in %LocalAppData%\VivaldiWSMod\logs\ws-mod.log.
#>
param(
    # Cartella del mod: passata da Start-Daemon.vbs (cosi' funziona anche se il processo e' stato creato
    # da Windows/WMI, che non eredita le variabili d'ambiente di chi lo ha richiesto).
    [string]$ModRoot = '',
    [int]$StableAgeSeconds   = 4,
    [int]$ActiveTickSeconds  = 5,
    [int]$ActiveWindowMinutes = 20,
    [int]$IdleTickMinutes    = 30
)

$ErrorActionPreference = 'Stop'
# Solo se la cartella del mod NON e' quella standard (test automatici): la imposta per questo processo.
if ($ModRoot -and ($ModRoot.TrimEnd('\') -ine (Join-Path $env:LOCALAPPDATA 'VivaldiWSMod'))) { $env:VIVALDI_WSMOD_ROOT = $ModRoot.TrimEnd('\') }
. (Join-Path $PSScriptRoot 'Mod-Common.ps1')

$ModRoot  = Get-ModRoot
$MasterJs = Join-Path $ModRoot 'payload\move-workspace-panel.js'

# --- un solo watcher per cartella mod ---
$md5 = [Security.Cryptography.MD5]::Create()
$hash = [BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($ModRoot.ToLowerInvariant()))).Replace('-', '').Substring(0, 12)
$createdNew = $false
$mutex = New-Object Threading.Mutex($true, "Local\VivaldiWSMod-Daemon-$hash", [ref]$createdNew)
if (-not $createdNew) { exit 0 }

try { (Get-Process -Id $PID).PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal } catch { }

$watchers   = @{}   # root -> FileSystemWatcher
$activeUntil = @{}  # root -> DateTime fino a cui controllare spesso
$lastState  = @{}   # root -> ultimo esito loggato (per non riempire il log)

function Ensure-Watchers {
    foreach ($root in (Get-ModRoots)) {
        if ($watchers.ContainsKey($root)) { continue }
        if (-not (Test-Path -LiteralPath $root)) { continue }   # unita' non disponibile: ci riprova al prossimo controllo
        try {
            $w = New-Object IO.FileSystemWatcher
            $w.Path = $root
            $w.IncludeSubdirectories = $false
            $w.NotifyFilter = [IO.NotifyFilters]::DirectoryName
            $w.InternalBufferSize = 8192
            $id = $watchers.Count
            Register-ObjectEvent -InputObject $w -EventName Created -SourceIdentifier "wsmod-created-$id" -MessageData $root | Out-Null
            Register-ObjectEvent -InputObject $w -EventName Renamed -SourceIdentifier "wsmod-renamed-$id" -MessageData $root | Out-Null
            $w.EnableRaisingEvents = $true
            $watchers[$root] = $w
            Write-ModLog ("Sorveglianza attiva su '" + $root + "'")
        } catch {
            Write-ModLog ("ERRORE creazione sorveglianza su '" + $root + "': " + $_.Exception.Message)
        }
    }
}

function Check-Root {
    param([string]$Root)
    $res = Invoke-RepairLatest -AppRoot $Root -MasterJs $MasterJs -RequireStable -StableAgeSeconds $StableAgeSeconds
    if ($res -ne 'ok' -and $res -ne 'repaired') {
        # 'unstable' / 'nowindowhtml': aggiornamento in corso -> restiamo in modalita' attiva
        if (-not $activeUntil.ContainsKey($Root) -or $activeUntil[$Root] -lt (Get-Date)) {
            $activeUntil[$Root] = (Get-Date).AddMinutes($ActiveWindowMinutes)
        }
    }
    if ($lastState[$Root] -ne $res -and $res -ne 'ok') {
        Write-ModLog ("Controllo '" + $Root + "': " + $res)
    }
    $lastState[$Root] = $res
    return $res
}

Write-ModLog ("Watcher avviato (PID " + $PID + ")")
Ensure-Watchers
foreach ($root in (Get-ModRoots)) { [void](Check-Root -Root $root) }   # riparazione immediata all'avvio

while ($true) {
    try {
        $now = Get-Date
        $anyActive = $false
        foreach ($k in @($activeUntil.Keys)) {
            if ($activeUntil[$k] -gt $now) { $anyActive = $true } else { $activeUntil.Remove($k) }
        }
        $timeout = if ($anyActive) { $ActiveTickSeconds } else { $IdleTickMinutes * 60 }

        $null = Wait-Event -Timeout $timeout
        $eventRoots = @{}
        foreach ($e in @(Get-Event)) {
            if ($e.MessageData) { $eventRoots[[string]$e.MessageData] = $e.SourceEventArgs.Name }
            Remove-Event -EventIdentifier $e.EventIdentifier -ErrorAction SilentlyContinue
        }
        foreach ($r in $eventRoots.Keys) {
            Write-ModLog ("Nuova voce in '" + $r + "': '" + $eventRoots[$r] + "' -> controllo aggiornamento")
            $activeUntil[$r] = (Get-Date).AddMinutes($ActiveWindowMinutes)
        }

        Ensure-Watchers
        foreach ($root in (Get-ModRoots)) { [void](Check-Root -Root $root) }
    } catch {
        # Il watcher non deve mai morire per un errore imprevisto: log e pausa lunga (niente ciclo veloce).
        Write-ModLog ("ERRORE imprevisto nel ciclo: " + $_.Exception.Message)
        Start-Sleep -Seconds 60
    }
}