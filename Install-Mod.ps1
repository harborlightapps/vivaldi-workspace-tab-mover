#requires -Version 5.1
<#
.SYNOPSIS
    Installer unico per il mod "Sposta nel Workspace" di Vivaldi.
.DESCRIPTION
    Modulo 3. Punto di ingresso a click singolo:
      - Se il mod non e' presente/funzionante nella versione Vivaldi corrente, lo installa.
      - Distribuisce sempre payload + Watcher-Core.ps1 + Vivaldi-Launch.vbs in
        %LocalAppData%\VivaldiWSMod\ (posizione stabile, sopravvive agli aggiornamenti Vivaldi).
      - Avvia (e registra al login, voce HKCU\...\Run, senza amministratore) il
        sorvegliante in background Watcher-Daemon.ps1, che dopo ogni
        aggiornamento di Vivaldi rimette la mod da solo (RICHIESTA-004).
      - Riscrive gli shortcut Vivaldi esistenti (Desktop utente/tutti gli utenti,
        Start Menu utente/tutti gli utenti) associati a QUESTA installazione, in
        modo che puntino al launcher (controllo automatico ad ogni avvio).
      - Salva lo stato originale di ogni shortcut modificato in un manifest JSON,
        per poter disinstallare in modo pulito con Uninstall-Mod.ps1.
      - Idempotente: puo' essere rieseguito senza duplicare backup o ri-wrappare
        shortcut gia' aggiornati.
    Richiede in <cartella dello script>\payload\ i file sorgente:
      move-workspace-panel.js, Mod-Common.ps1, Watcher-Core.ps1,
      Watcher-Daemon.ps1, Start-Daemon.vbs, Vivaldi-Launch.vbs
.PARAMETER VivaldiAppRoot
    Percorso della cartella "Application" dell'installazione Vivaldi da modificare,
    es. "H:\Vivaldi Standalone\Application" oppure
        "C:\Users\<utente>\AppData\Local\Vivaldi\Application".
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Install-Mod.ps1 -VivaldiAppRoot "H:\Vivaldi Standalone\Application"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$VivaldiAppRoot,

    # Solo per i test automatici: non registra l'avvio al login e non avvia il watcher.
    [switch]$NoAutostart
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'payload\Mod-Common.ps1')

function Write-Step {
    param([string]$Message)
    Write-Host "[Install-Mod] $Message"
}

function Get-LatestVersionFolder {
    param([string]$AppRoot)
    Get-ChildItem -Path $AppRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
}

function Get-CandidateShortcutFolders {
    $folders = New-Object System.Collections.Generic.List[string]
    $paths = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs')
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path $p)) { $folders.Add($p) }
    }
    return $folders
}

try {
    # --- Percorsi principali ---
    $ModRoot              = Get-ModRoot
    $PayloadDir            = Join-Path $ModRoot 'payload'
    $ScriptsDir            = Join-Path $ModRoot 'scripts'
    $LogDir                = Join-Path $ModRoot 'logs'
    $ShortcutsBackupFile   = Join-Path $ModRoot 'shortcuts-backup.json'

    $SourcePayloadDir = Join-Path $PSScriptRoot 'payload'
    $SourceJs         = Join-Path $SourcePayloadDir 'move-workspace-panel.js'
    $SourceWatcher    = Join-Path $SourcePayloadDir 'Watcher-Core.ps1'
    $SourceLauncher   = Join-Path $SourcePayloadDir 'Vivaldi-Launch.vbs'
    $SourceCommon     = Join-Path $SourcePayloadDir 'Mod-Common.ps1'
    $SourceDaemon     = Join-Path $SourcePayloadDir 'Watcher-Daemon.ps1'
    $SourceDaemonVbs  = Join-Path $SourcePayloadDir 'Start-Daemon.vbs'

    $ScriptTag = '<script src="move-workspace-panel.js"></script>'

    # ============================================================
    # FASE 1 - Validazione input
    # ============================================================
    Write-Step "Verifica installazione Vivaldi in '$VivaldiAppRoot'..."

    if (-not (Test-Path $VivaldiAppRoot)) {
        throw "Cartella Application non trovata: '$VivaldiAppRoot'"
    }

    $vivaldiExe = Join-Path $VivaldiAppRoot 'vivaldi.exe'
    if (-not (Test-Path $vivaldiExe)) {
        throw "vivaldi.exe non trovato in '$VivaldiAppRoot'. Percorso non valido."
    }

    $versionFolder = Get-LatestVersionFolder -AppRoot $VivaldiAppRoot
    if (-not $versionFolder) {
        throw "Nessuna cartella versione trovata sotto '$VivaldiAppRoot'."
    }

    $resourcesDir = Join-Path $versionFolder.FullName 'resources\vivaldi'
    $windowHtml   = Join-Path $resourcesDir 'window.html'
    $targetJs     = Join-Path $resourcesDir 'move-workspace-panel.js'

    if (-not (Test-Path $windowHtml)) {
        throw "window.html non trovato in '$resourcesDir'. Struttura Vivaldi inattesa."
    }

    foreach ($f in @($SourceJs, $SourceWatcher, $SourceLauncher, $SourceCommon, $SourceDaemon, $SourceDaemonVbs)) {
        if (-not (Test-Path $f)) {
            throw "File sorgente mancante: '$f'. Esegui Install-Mod.ps1 dalla cartella del pacchetto completo (con la sottocartella 'payload')."
        }
    }

    Write-Step "OK - versione Vivaldi rilevata: $($versionFolder.Name)"

    # ============================================================
    # FASE 2 - Distribuzione file in %LocalAppData%\VivaldiWSMod\
    # ============================================================
    Write-Step "Distribuzione file mod in '$ModRoot'..."

    foreach ($dir in @($ModRoot, $PayloadDir, $ScriptsDir, $LogDir)) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }

    Copy-Item -Path $SourceJs -Destination (Join-Path $PayloadDir 'move-workspace-panel.js') -Force
    Copy-Item -Path $SourceWatcher -Destination (Join-Path $ScriptsDir 'Watcher-Core.ps1') -Force
    Copy-Item -Path $SourceLauncher -Destination (Join-Path $ScriptsDir 'Vivaldi-Launch.vbs') -Force
    Copy-Item -Path $SourceCommon -Destination (Join-Path $ScriptsDir 'Mod-Common.ps1') -Force
    Copy-Item -Path $SourceDaemon -Destination (Join-Path $ScriptsDir 'Watcher-Daemon.ps1') -Force
    Copy-Item -Path $SourceDaemonVbs -Destination (Join-Path $ScriptsDir 'Start-Daemon.vbs') -Force

    Write-Step "OK - payload e script distribuiti in '$ModRoot'."

    # ============================================================
    # FASE 3 - Installazione/verifica immediata del mod nella versione corrente
    # ============================================================
    Write-Step "Verifica/installazione mod nella versione corrente di Vivaldi..."

    $masterJs = Join-Path $PayloadDir 'move-workspace-panel.js'

    # Stessa funzione usata dal watcher in background: idempotente, scrittura
    # atomica, backup window.html.bak creato una sola volta.
    $repairResult = Repair-VersionFolder -VersionFolder $versionFolder -MasterJs $masterJs
    switch -Wildcard ($repairResult) {
        'repaired' { Write-Step "Mod installato/ripristinato in '$resourcesDir'." }
        'ok'       { Write-Step "Mod gia' presente e aggiornato: nessuna modifica necessaria alla versione corrente." }
        default    { throw "Installazione del mod nella versione corrente non riuscita: $repairResult" }
    }

    # ============================================================
    # FASE 4 - Riscrittura shortcut Vivaldi (Desktop / Start Menu)
    # ============================================================
    Write-Step "Ricerca shortcut Vivaldi da aggiornare..."

    $wshShell     = New-Object -ComObject WScript.Shell
    $launcherPath = Join-Path $ScriptsDir 'Vivaldi-Launch.vbs'
    $wscriptExe   = Join-Path $env:WINDIR 'System32\wscript.exe'
    $appRootFull  = (Resolve-Path $VivaldiAppRoot).Path

    # Carica manifest esistente (idempotenza fra piu' esecuzioni)
    $backupEntries = @()
    if (Test-Path $ShortcutsBackupFile) {
        try {
            $rawEntries = @(Get-Content -Path $ShortcutsBackupFile -Raw | ConvertFrom-Json)

            # Difesa: normalizza eventuali oggetti annidati anomali del tipo
            # {"value":[...], "Count":N} che ConvertTo-Json puo' produrre in
            # certe condizioni (osservato in produzione il 19/08/2026 - un
            # manifest con questa forma manda in errore ogni esecuzione
            # successiva con "the array index evaluated to null" e blocca la
            # Fase 4 per intero). Appiattisce e deduplica per ShortcutPath
            # cosi' un manifest gia' corrotto si autoripara invece di
            # ripetere l'errore ad ogni run.
            $flatEntries = @()
            $seenPaths = @{}
            foreach ($item in $rawEntries) {
                $candidates = if ($item -and ($item.PSObject.Properties.Name -contains 'value')) { @($item.value) } else { @($item) }
                foreach ($sub in $candidates) {
                    if ($sub -and $sub.ShortcutPath -and -not $seenPaths.ContainsKey($sub.ShortcutPath)) {
                        $seenPaths[$sub.ShortcutPath] = $true
                        $flatEntries += $sub
                    }
                }
            }
            $backupEntries = @($flatEntries)
        } catch {
            Write-Step "ATTENZIONE: manifest shortcut esistente illeggibile, ne creo uno nuovo."
            $backupEntries = @()
        }
    }
    $alreadyBackedUp = @{}
    foreach ($e in $backupEntries) {
        if ($e -and $e.ShortcutPath) { $alreadyBackedUp[$e.ShortcutPath] = $true }
    }

    $updatedCount = 0

    foreach ($folder in (Get-CandidateShortcutFolders)) {
        $lnkFiles = Get-ChildItem -Path $folder -Filter '*.lnk' -File -ErrorAction SilentlyContinue
        foreach ($lnk in $lnkFiles) {
            try {
                $shortcut   = $wshShell.CreateShortcut($lnk.FullName)
                $targetPath = $shortcut.TargetPath

                # Caso A: shortcut punta direttamente a vivaldi.exe di QUESTA installazione
                $isDirectVivaldi = $targetPath -and
                    ((Split-Path $targetPath -Leaf) -ieq 'vivaldi.exe') -and
                    ((Split-Path $targetPath -Parent) -ieq $appRootFull)

                # Caso B: shortcut gia' wrappato dal nostro launcher per QUESTA installazione
                $isOurLauncher = $targetPath -and
                    ($targetPath -ieq $wscriptExe) -and
                    ($shortcut.Arguments -like "*$launcherPath*") -and
                    ($shortcut.Arguments -like "*$appRootFull*")

                if ($isOurLauncher) { continue }      # gia' installato, nulla da fare
                if (-not $isDirectVivaldi) { continue } # non e' uno shortcut di questa installazione

                if (-not $alreadyBackedUp.ContainsKey($lnk.FullName)) {
                    $backupEntries += [PSCustomObject]@{
                        ShortcutPath     = $lnk.FullName
                        TargetPath       = $shortcut.TargetPath
                        Arguments        = $shortcut.Arguments
                        WorkingDirectory = $shortcut.WorkingDirectory
                        IconLocation     = $shortcut.IconLocation
                    }
                    $alreadyBackedUp[$lnk.FullName] = $true
                }

                $originalIcon = $shortcut.IconLocation
                if ([string]::IsNullOrWhiteSpace($originalIcon)) { $originalIcon = "$vivaldiExe,0" }

                $shortcut.TargetPath       = $wscriptExe
                $shortcut.Arguments        = ('"{0}" "{1}" "{2}"' -f $launcherPath, $appRootFull, $vivaldiExe)
                $shortcut.WorkingDirectory = $VivaldiAppRoot
                $shortcut.IconLocation     = $originalIcon
                $shortcut.Save()

                $updatedCount++
                Write-Step "Shortcut aggiornato: '$($lnk.FullName)'"
            } catch {
                Write-Step ("ATTENZIONE: impossibile elaborare '" + $lnk.FullName + "': " + $_.Exception.Message)
            }
        }
    }

    $backupEntries | ConvertTo-Json -Depth 4 | Set-Content -Path $ShortcutsBackupFile -Encoding UTF8

    if ($updatedCount -eq 0) {
        Write-Step "Nessuno shortcut da aggiornare (gia' aggiornati o nessuno trovato)."
    } else {
        Write-Step "OK - $updatedCount shortcut aggiornati."
    }

    # ============================================================
    # FASE 5 - Ripristino automatico dopo gli aggiornamenti di Vivaldi
    # ============================================================
    # Un piccolo processo nascosto (Watcher-Daemon.ps1) aspetta, a costo quasi
    # zero, la comparsa di una nuova cartella versione e rimette la mod. Parte
    # al login (HKCU Run, nessun amministratore) e subito adesso.
    Add-ModRoot -AppRoot $appRootFull

    if ($NoAutostart) {
        Write-Step "Avvio automatico saltato (-NoAutostart)."
    } else {
        Write-Step "Attivazione del ripristino automatico dopo gli aggiornamenti..."
        $startVbs = Join-Path $ScriptsDir 'Start-Daemon.vbs'
        $wscriptForRun = Join-Path $env:WINDIR 'System32\wscript.exe'
        $runKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $runValue = ('"{0}" //B "{1}"' -f $wscriptForRun, $startVbs)
        Set-ItemProperty -Path $runKey -Name 'VivaldiWSMod' -Value $runValue

        # Riavvia il watcher cosi' usa subito gli script appena copiati.
        [void](Stop-ModDaemon)
        Start-Sleep -Milliseconds 500
        Start-Process -FilePath $wscriptForRun -ArgumentList @('//B', ('"{0}"' -f $startVbs)) -WindowStyle Hidden
        $up = $false
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Milliseconds 500
            if (@(Get-ModDaemonProcesses).Count -gt 0) { $up = $true; break }
        }
        if ($up) {
            Write-Step "OK - watcher in background attivo (si riavvia da solo a ogni login)."
        } else {
            Write-Step "ATTENZIONE: watcher non partito ora; partira' al prossimo login."
        }
    }
    Write-Host ""
    Write-Host "=== Installazione completata con successo ===" -ForegroundColor Green
    exit 0

} catch {
    Write-Host ""
    Write-Host "=== ERRORE: installazione non completata ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
