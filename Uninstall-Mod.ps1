#requires -Version 5.1
<#
.SYNOPSIS
    Disinstallatore del mod "Sposta nel Workspace" per Vivaldi.
.DESCRIPTION
    Modulo 4. Punto di uscita a click singolo:
      - Ferma il watcher in background (Watcher-Daemon.ps1) e rimuove la voce
        di avvio automatico HKCU\...\Run (RICHIESTA-004).
      - Ripristina window.html originale (da .bak) e rimuove
        move-workspace-panel.js in TUTTE le cartelle versione dell'installazione
        indicata e delle altre installazioni registrate in roots.json.
      - Ripristina TUTTI gli shortcut Vivaldi modificati da Install-Mod.ps1
        (Desktop/Start Menu, qualunque installazione) allo stato originale,
        leggendo il manifest 'shortcuts-backup.json'.
      - Rimuove interamente %LocalAppData%\VivaldiWSMod\ (payload, script, log).
    L'ordine e' importante: prima si ripristinano gli shortcut (cosi' non
    puntano piu' al launcher), POI si cancella la cartella del mod.
.PARAMETER VivaldiAppRoot
    Percorso della cartella "Application" dell'installazione Vivaldi da cui
    rimuovere il mod (window.html + move-workspace-panel.js). Gli shortcut di
    TUTTE le installazioni presenti nel manifest vengono comunque ripristinati,
    perche' condividono la stessa cartella VivaldiWSMod che viene rimossa.
.PARAMETER Force
    Salta la richiesta di conferma interattiva (utile per test automatici).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Uninstall-Mod.ps1 -VivaldiAppRoot "H:\Vivaldi Standalone\Application"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$VivaldiAppRoot,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'payload\Mod-Common.ps1')

function Write-Step {
    param([string]$Message)
    Write-Host "[Uninstall-Mod] $Message"
}

function Get-LatestVersionFolder {
    param([string]$AppRoot)
    if (-not (Test-Path $AppRoot)) { return $null }
    Get-ChildItem -Path $AppRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
}

try {
    $ModRoot             = Get-ModRoot
    $ShortcutsBackupFile = Join-Path $ModRoot 'shortcuts-backup.json'

    if (-not $Force) {
        Write-Host ""
        Write-Host "Questa operazione rimuovera' il mod 'Sposta nel Workspace' e ripristinera'" -ForegroundColor Yellow
        Write-Host "gli shortcut Vivaldi originali. Continuare? (S/N)" -ForegroundColor Yellow
        $answer = Read-Host
        if ($answer -notmatch '^[SsYy]') {
            Write-Step "Operazione annullata dall'utente."
            exit 0
        }
    }

    # ============================================================
    # FASE 0 - Ferma il watcher e rimuove l'avvio automatico
    # ============================================================
    # Va fatto per primo: altrimenti il watcher rimetterebbe subito la mod.
    $allRoots = @($VivaldiAppRoot) + @(Get-ModRoots)
    $stopped = Stop-ModDaemon
    Write-Step "Watcher in background fermato ($stopped processi)."
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        if (Get-ItemProperty -Path $runKey -Name 'VivaldiWSMod' -ErrorAction SilentlyContinue) {
            if (-not $env:VIVALDI_WSMOD_ROOT) {
                Remove-ItemProperty -Path $runKey -Name 'VivaldiWSMod' -ErrorAction Stop
                Write-Step "Voce di avvio automatico rimossa."
            } else {
                Write-Step "Voce di avvio automatico lasciata (modalita' test)."
            }
        }
    } catch {
        Write-Step ("ATTENZIONE: impossibile rimuovere la voce di avvio automatico: " + $_.Exception.Message)
    }

    # ============================================================
    # FASE 1 - Ripristino window.html e rimozione JS (tutte le cartelle versione)
    # ============================================================
    $seenRoots = @{}
    foreach ($root in $allRoots) {
        if (-not $root -or $seenRoots.ContainsKey($root.ToLowerInvariant())) { continue }
        $seenRoots[$root.ToLowerInvariant()] = $true
        Write-Step "Ripristino Vivaldi in '$root'..."

        $versionFolders = @(Get-VersionFolders -AppRoot $root)
        if ($versionFolders.Count -eq 0) {
            Write-Step "ATTENZIONE: nessuna cartella versione trovata sotto '$root'. Salto questo passo."
            continue
        }
        foreach ($versionFolder in $versionFolders) {
            $resourcesDir = Join-Path $versionFolder.FullName 'resources\vivaldi'
            $windowHtml   = Join-Path $resourcesDir 'window.html'
            $backupPath   = $windowHtml + '.bak'
            $targetJs     = Join-Path $resourcesDir 'move-workspace-panel.js'

            if (Test-Path -LiteralPath $backupPath) {
                Copy-Item -LiteralPath $backupPath -Destination $windowHtml -Force
                Remove-Item -LiteralPath $backupPath -Force
                Write-Step "window.html ripristinato dall'originale (versione $($versionFolder.Name))."
            } elseif ((Test-Path -LiteralPath $windowHtml) -and ([IO.File]::ReadAllText($windowHtml)).Contains($script:ScriptTag)) {
                Write-Step "ATTENZIONE: nessun backup 'window.html.bak' in $($versionFolder.Name), ma window.html contiene il tag: lo tolgo."
                $html = [IO.File]::ReadAllText($windowHtml)
                $html = $html.Replace($script:ScriptTag + "`r`n", '').Replace($script:ScriptTag, '')
                [IO.File]::WriteAllText($windowHtml, $html, (New-Object Text.UTF8Encoding($false)))
            }

            if (Test-Path -LiteralPath $targetJs) {
                Remove-Item -LiteralPath $targetJs -Force
                Write-Step "move-workspace-panel.js rimosso da $($versionFolder.Name)."
            }
            foreach ($tmp in @(($windowHtml + '.wsmod.tmp'), ($targetJs + '.wsmod.tmp'))) {
                if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
    }
    # ============================================================
    # FASE 2 - Ripristino di TUTTI gli shortcut dal manifest
    # ============================================================
    Write-Step "Ripristino shortcut Vivaldi originali..."

    if (-not (Test-Path -LiteralPath $ShortcutsBackupFile)) {
        Write-Step "Nessun manifest shortcut trovato: nessuno shortcut da ripristinare."
    } else {
        $backupEntries = @(Get-Content -Path $ShortcutsBackupFile -Raw | ConvertFrom-Json)
        $wshShell = New-Object -ComObject WScript.Shell
        $restoredCount = 0

        foreach ($entry in $backupEntries) {
            try {
                # -LiteralPath e' obbligatorio: i nomi shortcut possono contenere
                # caratteri come '[' e ']' che Test-Path -Path interpreta come
                # wildcard, causando falsi "file non trovato".
                if (-not (Test-Path -LiteralPath $entry.ShortcutPath)) {
                    Write-Step ("ATTENZIONE: shortcut non piu' presente, salto: '" + $entry.ShortcutPath + "'")
                    continue
                }
                $shortcut = $wshShell.CreateShortcut($entry.ShortcutPath)
                $shortcut.TargetPath       = $entry.TargetPath
                $shortcut.Arguments        = $entry.Arguments
                $shortcut.WorkingDirectory = $entry.WorkingDirectory
                $shortcut.IconLocation     = $entry.IconLocation
                $shortcut.Save()
                $restoredCount++
                Write-Step ("Shortcut ripristinato: '" + $entry.ShortcutPath + "'")
            } catch {
                Write-Step ("ATTENZIONE: impossibile ripristinare '" + $entry.ShortcutPath + "': " + $_.Exception.Message)
            }
        }

        Write-Step "OK - $restoredCount shortcut ripristinati."
    }

    # ============================================================
    # FASE 3 - Rimozione cartella mod
    # ============================================================
    Write-Step "Rimozione '$ModRoot'..."

    $modRootRemoved = $true
    if (Test-Path -LiteralPath $ModRoot) {
        # Retry: un file all'interno puo' essere temporaneamente bloccato da
        # antivirus, indicizzazione, o un editor/Explorer ancora aperto su di
        # esso. Non deve far fallire l'intera disinstallazione: le fasi 1 e 2
        # (le parti che contano davvero: mod rimosso, shortcut ripristinati)
        # sono gia' completate a questo punto.
        $maxAttempts = 3
        $lastError = $null
        for ($i = 1; $i -le $maxAttempts; $i++) {
            try {
                Remove-Item -LiteralPath $ModRoot -Recurse -Force -ErrorAction Stop
                $lastError = $null
                break
            } catch {
                $lastError = $_
                if ($i -lt $maxAttempts) { Start-Sleep -Milliseconds 700 }
            }
        }

        if ($lastError) {
            $modRootRemoved = $false
            Write-Step ("ATTENZIONE: impossibile rimuovere completamente '" + $ModRoot + "' (file in uso da un altro processo, es. un editor o Esplora File aperto su quella cartella). " +
                        "Il mod e gli shortcut sono comunque stati ripristinati correttamente. Chiudi eventuali programmi che usano quella cartella e cancellala manualmente: " + $ModRoot)
        } else {
            Write-Step "OK - cartella mod rimossa."
        }
    } else {
        Write-Step "Cartella mod gia' assente, nulla da rimuovere."
    }

    Write-Host ""
    if ($modRootRemoved) {
        Write-Host "=== Disinstallazione completata con successo ===" -ForegroundColor Green
    } else {
        Write-Host "=== Disinstallazione completata (con avviso: vedi sopra) ===" -ForegroundColor Yellow
    }
    exit 0

} catch {
    Write-Host ""
    Write-Host "=== ERRORE: disinstallazione non completata ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
