#requires -Version 5.1
<#
.SYNOPSIS
    Uninstaller / Disinstallatore - Vivaldi Workspace Tab Mover (v1.2.0).
.DESCRIPTION
    Punto di uscita a click singolo (domande bilingui):
      - Ferma il watcher in background (Watcher-Daemon.ps1) e rimuove la voce
        di avvio automatico HKCU\...\Run (RICHIESTA-004).
      - Ripristina window.html originale (da .bak) e rimuove move-workspace-panel.js
        e il file di configurazione della lingua (move-workspace-panel.config.json)
        in TUTTE le cartelle versione dell'installazione indicata e delle altre
        installazioni registrate in roots.json.
      - Ripristina TUTTI gli shortcut Vivaldi modificati da Install-Mod.ps1
        (Desktop/Start Menu, qualunque installazione) allo stato originale,
        leggendo il manifest 'shortcuts-backup.json'.
      - Rimuove interamente %LocalAppData%\VivaldiWSMod\ (payload, script, log, lingua).
    L'ordine e' importante: prima si ripristinano gli shortcut (cosi' non
    puntano piu' al launcher), POI si cancella la cartella del mod.
    Nota: la scelta della lingua fatta dal menu nel browser sta nel profilo di
    Vivaldi (chrome.storage.local) e non e' cancellabile dall'esterno; senza la
    mod non ha alcun effetto.
.PARAMETER VivaldiAppRoot
    Percorso della cartella "Application" dell'installazione Vivaldi da cui
    rimuovere il mod. Se omesso, lo chiede lo script (Invio = quella registrata).
.PARAMETER Force
    Salta la richiesta di conferma interattiva (utile per test automatici).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Uninstall-Mod.ps1
#>

param(
    [string]$VivaldiAppRoot = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'payload\Mod-Common.ps1')

# Lingua dei messaggi: lingua scelta all'installazione se esplicita, altrimenti lingua di Windows.
$script:UiLang = if ([Globalization.CultureInfo]::CurrentUICulture.Name -match '^it') { 'it' } else { 'en' }
try {
    $cfgFile = Join-Path (Join-Path (Get-ModRoot) 'payload') $script:ConfigName
    if (Test-Path -LiteralPath $cfgFile) {
        $cfgLang = [string](Get-Content -LiteralPath $cfgFile -Raw | ConvertFrom-Json).lang
        if ($cfgLang -in @('en', 'it')) { $script:UiLang = $cfgLang }
    }
} catch { }
function L {
    param([string]$En, [string]$It)
    if ($script:UiLang -eq 'it') { return $It } else { return $En }
}

function Write-Step {
    param([string]$Message)
    Write-Host "[Uninstall-Mod] $Message"
}

function Read-Line {
    param([string]$Prompt)
    Write-Host -NoNewline $Prompt
    try { $r = [Console]::ReadLine(); if ($null -eq $r) { return '' } else { return $r } } catch { return '' }
}

try {
    $ModRoot             = Get-ModRoot
    $ShortcutsBackupFile = Join-Path $ModRoot 'shortcuts-backup.json'
    $canPrompt = $true   # anche con input rediretto: a fine input ReadLine ritorna vuoto

    Write-Host ''
    Write-Host '============================================================'
    Write-Host '  Vivaldi Workspace Tab Mover - Uninstaller / Disinstallatore'
    Write-Host '============================================================'
    Write-Host ''

    # Percorso: parametro, altrimenti domanda (Invio = installazione registrata)
    $registered = @(Get-ModRoots)
    if (-not $VivaldiAppRoot) {
        if ($registered.Count -ge 1 -and $canPrompt) {
            $ans = (Read-Line "Vivaldi ""Application"" folder path / Percorso cartella ""Application"" di Vivaldi [Enter = $($registered[0])]: ").Trim().Trim('"')
            $VivaldiAppRoot = if ($ans) { $ans } else { $registered[0] }
        } elseif ($registered.Count -ge 1) {
            $VivaldiAppRoot = $registered[0]
        } elseif ($canPrompt) {
            $VivaldiAppRoot = (Read-Line 'Vivaldi "Application" folder path / Percorso cartella "Application" di Vivaldi (e.g. H:\Vivaldi Standalone\Application): ').Trim().Trim('"')
        }
    }
    if (-not $VivaldiAppRoot) { throw (L 'No path entered. Uninstall cancelled.' 'Nessun percorso inserito. Disinstallazione annullata.') }
    if (-not (Test-Path -LiteralPath $VivaldiAppRoot -PathType Container)) {
        throw (L "Folder not found: '$VivaldiAppRoot'. Check the path (it must be the ""Application"" folder)." "Cartella non trovata: '$VivaldiAppRoot'. Controlla il percorso (deve essere la cartella ""Application"").")
    }

    if (-not $Force) {
        Write-Host ''
        Write-Host (L "This will remove the Vivaldi Workspace Tab Mover mod and restore the original Vivaldi shortcuts. Continue? (Y/N)" "Questa operazione rimuovera' il mod e ripristinera' gli shortcut Vivaldi originali. Continuare? (S/N)") -ForegroundColor Yellow
        $answer = Read-Line '> '
        if ($answer -notmatch '^[SsYy]') {
            Write-Step (L 'Cancelled by the user.' "Operazione annullata dall'utente.")
            exit 0
        }
    }

    # ============================================================
    # FASE 0 - Ferma il watcher e rimuove l'avvio automatico
    # ============================================================
    # Va fatto per primo: altrimenti il watcher rimetterebbe subito la mod.
    $allRoots = @($VivaldiAppRoot) + @($registered)
    $stopped = Stop-ModDaemon
    Write-Step (L "Background watcher stopped ($stopped process(es))." "Watcher in background fermato ($stopped processi).")
    try {
        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        if (Get-ItemProperty -Path $runKey -Name 'VivaldiWSMod' -ErrorAction SilentlyContinue) {
            if (-not $env:VIVALDI_WSMOD_ROOT) {
                Remove-ItemProperty -Path $runKey -Name 'VivaldiWSMod' -ErrorAction Stop
                Write-Step (L 'Autostart entry removed.' 'Voce di avvio automatico rimossa.')
            } else {
                Write-Step (L 'Autostart entry left in place (test mode).' "Voce di avvio automatico lasciata (modalita' test).")
            }
        }
    } catch {
        Write-Step ((L 'WARNING: could not remove the autostart entry: ' "ATTENZIONE: impossibile rimuovere la voce di avvio automatico: ") + $_.Exception.Message)
    }

    # ============================================================
    # FASE 1 - Ripristino window.html e rimozione JS/config (tutte le cartelle versione)
    # ============================================================
    $seenRoots = @{}
    foreach ($root in $allRoots) {
        if (-not $root -or $seenRoots.ContainsKey($root.ToLowerInvariant())) { continue }
        $seenRoots[$root.ToLowerInvariant()] = $true
        Write-Step (L "Restoring Vivaldi in '$root'..." "Ripristino Vivaldi in '$root'...")

        $versionFolders = @(Get-VersionFolders -AppRoot $root)
        if ($versionFolders.Count -eq 0) {
            Write-Step (L "WARNING: no version folder found under '$root'. Skipping." "ATTENZIONE: nessuna cartella versione trovata sotto '$root'. Salto questo passo.")
            continue
        }
        foreach ($versionFolder in $versionFolders) {
            $resourcesDir = Join-Path $versionFolder.FullName 'resources\vivaldi'
            $windowHtml   = Join-Path $resourcesDir 'window.html'
            $backupPath   = $windowHtml + '.bak'
            $targetJs     = Join-Path $resourcesDir 'move-workspace-panel.js'
            $targetCfg    = Join-Path $resourcesDir $script:ConfigName

            if (Test-Path -LiteralPath $backupPath) {
                Copy-Item -LiteralPath $backupPath -Destination $windowHtml -Force
                Remove-Item -LiteralPath $backupPath -Force
                Write-Step (L "window.html restored from the original (version $($versionFolder.Name))." "window.html ripristinato dall'originale (versione $($versionFolder.Name)).")
            } elseif ((Test-Path -LiteralPath $windowHtml) -and ([IO.File]::ReadAllText($windowHtml)).Contains($script:ScriptTag)) {
                Write-Step (L "WARNING: no 'window.html.bak' in $($versionFolder.Name), but window.html has the tag: removing it." "ATTENZIONE: nessun backup 'window.html.bak' in $($versionFolder.Name), ma window.html contiene il tag: lo tolgo.")
                $html = [IO.File]::ReadAllText($windowHtml)
                $html = $html.Replace($script:ScriptTag + "`r`n", '').Replace($script:ScriptTag, '')
                [IO.File]::WriteAllText($windowHtml, $html, (New-Object Text.UTF8Encoding($false)))
            }

            foreach ($f in @($targetJs, $targetCfg)) {
                if (Test-Path -LiteralPath $f) {
                    Remove-Item -LiteralPath $f -Force
                    Write-Step (L "Removed $(Split-Path $f -Leaf) from $($versionFolder.Name)." "Rimosso $(Split-Path $f -Leaf) da $($versionFolder.Name).")
                }
            }
            foreach ($tmp in @(($windowHtml + '.wsmod.tmp'), ($targetJs + '.wsmod.tmp'), ($targetCfg + '.wsmod.tmp'))) {
                if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    # ============================================================
    # FASE 2 - Ripristino di TUTTI gli shortcut dal manifest
    # ============================================================
    Write-Step (L 'Restoring original Vivaldi shortcuts...' 'Ripristino shortcut Vivaldi originali...')

    if (-not (Test-Path -LiteralPath $ShortcutsBackupFile)) {
        Write-Step (L 'No shortcut manifest found: no shortcuts to restore.' 'Nessun manifest shortcut trovato: nessuno shortcut da ripristinare.')
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
                    Write-Step ((L "WARNING: shortcut no longer present, skipping: '" "ATTENZIONE: shortcut non piu' presente, salto: '") + $entry.ShortcutPath + "'")
                    continue
                }
                $shortcut = $wshShell.CreateShortcut($entry.ShortcutPath)
                $shortcut.TargetPath       = $entry.TargetPath
                $shortcut.Arguments        = $entry.Arguments
                $shortcut.WorkingDirectory = $entry.WorkingDirectory
                $shortcut.IconLocation     = $entry.IconLocation
                $shortcut.Save()
                $restoredCount++
                Write-Step ((L "Shortcut restored: '" "Shortcut ripristinato: '") + $entry.ShortcutPath + "'")
            } catch {
                Write-Step ((L "WARNING: cannot restore '" "ATTENZIONE: impossibile ripristinare '") + $entry.ShortcutPath + "': " + $_.Exception.Message)
            }
        }

        Write-Step (L "OK - $restoredCount shortcut(s) restored." "OK - $restoredCount shortcut ripristinati.")
    }

    # ============================================================
    # FASE 3 - Rimozione cartella mod
    # ============================================================
    Write-Step (L "Removing '$ModRoot'..." "Rimozione '$ModRoot'...")

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
            Write-Step (L ("WARNING: could not fully remove '" + $ModRoot + "' (a file is in use by another process, e.g. an editor or Explorer open on that folder). The mod and shortcuts were restored correctly. Close programs using that folder and delete it manually: " + $ModRoot) ("ATTENZIONE: impossibile rimuovere completamente '" + $ModRoot + "' (file in uso da un altro processo, es. un editor o Esplora File aperto su quella cartella). Il mod e gli shortcut sono comunque stati ripristinati correttamente. Chiudi eventuali programmi che usano quella cartella e cancellala manualmente: " + $ModRoot))
        } else {
            Write-Step (L 'OK - mod folder removed.' 'OK - cartella mod rimossa.')
        }
    } else {
        Write-Step (L 'Mod folder already absent, nothing to remove.' "Cartella mod gia' assente, nulla da rimuovere.")
    }

    Write-Host ''
    if ($modRootRemoved) {
        Write-Host (L '=== Uninstall completed successfully ===' '=== Disinstallazione completata con successo ===') -ForegroundColor Green
    } else {
        Write-Host (L '=== Uninstall completed (with a warning: see above) ===' '=== Disinstallazione completata (con avviso: vedi sopra) ===') -ForegroundColor Yellow
    }
    exit 0

} catch {
    Write-Host ''
    Write-Host (L '=== ERROR: uninstall not completed ===' '=== ERRORE: disinstallazione non completata ===') -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
