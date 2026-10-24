#requires -Version 5.1
<#
.SYNOPSIS
    Installer / Installatore - Vivaldi Workspace Tab Mover (v1.2.1).
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
    Le domande sono bilingui (percorso della cartella Application e lingua).
    Lingua (RICHIESTA-006): English / Italiano / auto (rilevata dall'interfaccia
    di Vivaldi, inglese se non riconosciuta). Scritta in move-workspace-panel.config.json
    accanto al file della mod; la scelta fatta dal menu nel browser vale di piu'.
.PARAMETER VivaldiAppRoot
    Percorso della cartella "Application" dell'installazione Vivaldi da modificare,
    es. "H:\Vivaldi Standalone\Application" oppure
        "C:\Users\<utente>\AppData\Local\Vivaldi\Application".
    Se omesso, lo chiede lo script.
.PARAMETER Language
    en | it | auto. Se omesso, lo chiede lo script (Invio = valore proposto).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Install-Mod.ps1
    powershell -ExecutionPolicy Bypass -File Install-Mod.ps1 -VivaldiAppRoot "H:\Vivaldi Standalone\Application" -Language en
#>

param(
    [string]$VivaldiAppRoot = '',

    [ValidateSet('', 'auto', 'en', 'it')]
    [string]$Language = '',

    # Solo per i test automatici: non registra l'avvio al login ne' l'attivita' e non avvia il watcher.
    [switch]$NoAutostart,

    # Ogni quanti minuti l'attivita' pianificata controlla che il watcher sia acceso (default 30; i test usano 1).
    [ValidateRange(1, 1440)]
    [int]$KeepaliveIntervalMinutes = 30
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'payload\Mod-Common.ps1')

# Lingua dei messaggi dell'installer: 'en' o 'it'. Prima della scelta: lingua di Windows.
$script:UiLang = if ([Globalization.CultureInfo]::CurrentUICulture.Name -match '^it') { 'it' } else { 'en' }
function L {
    param([string]$En, [string]$It)
    if ($script:UiLang -eq 'it') { return $It } else { return $En }
}

function Write-Step {
    param([string]$Message)
    Write-Host "[Install-Mod] $Message"
}

# Si chiede sempre (anche con input rediretto: a fine input ReadLine ritorna vuoto e valgono i valori proposti).
function Test-CanPrompt {
    return $true
}

function Read-Line {
    param([string]$Prompt)
    Write-Host -NoNewline $Prompt
    try { $r = [Console]::ReadLine(); if ($null -eq $r) { return '' } else { return $r } } catch { return '' }
}

# Controlla un percorso Application. Ritorna $null se valido, altrimenti il motivo (bilingue).
function Test-VivaldiAppRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return 'No path entered. / Nessun percorso inserito.' }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return "Folder not found / Cartella non trovata: '$Path'" }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'vivaldi.exe'))) { return "vivaldi.exe not found in / non trovato in: '$Path' (is it the ""Application"" folder? / e' la cartella ""Application""?)" }
    $vf = Get-VersionFolders -AppRoot $Path | Select-Object -First 1
    if (-not $vf) { return "No Vivaldi version folder under / Nessuna cartella versione sotto: '$Path'" }
    if (-not (Test-Path -LiteralPath (Join-Path $vf.FullName 'resources\vivaldi\window.html'))) { return "window.html not found / non trovato in '$($vf.Name)\resources\vivaldi'" }
    return $null
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
    # FASE 1 - Domande (bilingui) e validazione input
    # ============================================================
    $canPrompt = Test-CanPrompt
    Write-Host ''
    Write-Host '============================================================'
    Write-Host '  Vivaldi Workspace Tab Mover - Installer / Installatore'
    Write-Host '============================================================'
    Write-Host ''

    # 1a) percorso della cartella Application
    $pathProblem = $null
    if ($VivaldiAppRoot) {
        $pathProblem = Test-VivaldiAppRoot -Path $VivaldiAppRoot
        if ($pathProblem) { throw $pathProblem }
    } else {
        if (-not $canPrompt) { throw 'No -VivaldiAppRoot given and no interactive input. / Nessun -VivaldiAppRoot e nessun input interattivo.' }
        for ($try = 1; $try -le 3; $try++) {
            $entered = (Read-Line 'Vivaldi "Application" folder path / Percorso cartella "Application" di Vivaldi (e.g. H:\Vivaldi Standalone\Application): ').Trim().Trim('"')
            $pathProblem = Test-VivaldiAppRoot -Path $entered
            if (-not $pathProblem) { $VivaldiAppRoot = $entered; break }
            Write-Host "  ! $pathProblem" -ForegroundColor Yellow
            if ($try -lt 3) { Write-Host '    Try again / Riprova.' -ForegroundColor Yellow }
        }
        if ($pathProblem) { throw "Invalid path after 3 attempts. / Percorso non valido dopo 3 tentativi. ($pathProblem)" }
    }

    # 1b) lingua: valore proposto = quello gia' scelto in una precedente installazione, altrimenti auto
    $ModRootForConfig = Get-ModRoot
    $configPath = Join-Path (Join-Path $ModRootForConfig 'payload') $script:ConfigName
    $existingCfg = $null
    if (Test-Path -LiteralPath $configPath) { try { $existingCfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json } catch { $existingCfg = $null } }
    $defaultLang = if ($existingCfg -and $existingCfg.lang -in @('en', 'it', 'auto')) { [string]$existingCfg.lang } else { 'auto' }
    $defaultLabel = switch ($defaultLang) { 'en' { 'English' } 'it' { 'Italiano' } default { 'auto-detect from Vivaldi interface / rileva dall''interfaccia di Vivaldi' } }
    $chosenLang = $Language
    if (-not $chosenLang) {
        if ($canPrompt) {
            Write-Host ''
            Write-Host 'Language / Lingua:'
            Write-Host '  1) English'
            Write-Host '  2) Italiano'
            Write-Host "  Enter = $defaultLabel"
            for ($try = 1; $try -le 3 -and -not $chosenLang; $try++) {
                $ans = (Read-Line '> ').Trim()
                switch -Regex ($ans) {
                    '^$'                         { $chosenLang = $defaultLang }
                    '^(1|en|english)$'           { $chosenLang = 'en' }
                    '^(2|it|italiano|italian)$'  { $chosenLang = 'it' }
                    default { Write-Host '  Please type 1, 2 or Enter. / Digita 1, 2 oppure Invio.' -ForegroundColor Yellow }
                }
            }
            if (-not $chosenLang) { $chosenLang = $defaultLang }
        } else {
            $chosenLang = $defaultLang
        }
    }
    # lingua dei messaggi successivi
    $script:UiLang = switch ($chosenLang) { 'en' { 'en' } 'it' { 'it' } default { $script:UiLang } }

    Write-Step (L "Checking Vivaldi installation in '$VivaldiAppRoot'..." "Verifica installazione Vivaldi in '$VivaldiAppRoot'...")

    $vivaldiExe = Join-Path $VivaldiAppRoot 'vivaldi.exe'
    $versionFolder = Get-LatestVersionFolder -AppRoot $VivaldiAppRoot
    $resourcesDir = Join-Path $versionFolder.FullName 'resources\vivaldi'
    $windowHtml   = Join-Path $resourcesDir 'window.html'
    $targetJs     = Join-Path $resourcesDir 'move-workspace-panel.js'

    foreach ($f in @($SourceJs, $SourceWatcher, $SourceLauncher, $SourceCommon, $SourceDaemon, $SourceDaemonVbs)) {
        if (-not (Test-Path $f)) {
            throw (L "Missing source file: '$f'. Run Install-Mod.ps1 from the full package folder (with the 'payload' subfolder)." "File sorgente mancante: '$f'. Esegui Install-Mod.ps1 dalla cartella del pacchetto completo (con la sottocartella 'payload').")
        }
    }

    Write-Step (L "OK - Vivaldi version detected: $($versionFolder.Name)" "OK - versione Vivaldi rilevata: $($versionFolder.Name)")
    # ============================================================
    # FASE 2 - Distribuzione file in %LocalAppData%\VivaldiWSMod\
    # ============================================================
    Write-Step (L "Copying mod files to '$ModRoot'..." "Distribuzione file mod in '$ModRoot'...")

    foreach ($dir in @($ModRoot, $PayloadDir, $ScriptsDir, $LogDir)) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }

    Copy-Item -Path $SourceJs -Destination (Join-Path $PayloadDir 'move-workspace-panel.js') -Force
    Copy-Item -Path $SourceWatcher -Destination (Join-Path $ScriptsDir 'Watcher-Core.ps1') -Force
    Copy-Item -Path $SourceLauncher -Destination (Join-Path $ScriptsDir 'Vivaldi-Launch.vbs') -Force
    Copy-Item -Path $SourceCommon -Destination (Join-Path $ScriptsDir 'Mod-Common.ps1') -Force
    Copy-Item -Path $SourceDaemon -Destination (Join-Path $ScriptsDir 'Watcher-Daemon.ps1') -Force
    Copy-Item -Path $SourceDaemonVbs -Destination (Join-Path $ScriptsDir 'Start-Daemon.vbs') -Force

    # File di configurazione della lingua (copia master): il watcher lo copia accanto al JS
    # in ogni versione di Vivaldi. "rev" cambia solo se la lingua scelta e' DIVERSA da quella
    # gia' installata (cosi' reinstallare con Invio non cancella la scelta fatta nel browser).
    $rev = 1
    if ($existingCfg -and $null -ne $existingCfg.rev) { $rev = [int]$existingCfg.rev; if ([string]$existingCfg.lang -ne $chosenLang) { $rev++ } }
    $cfgJson = (@{ lang = $chosenLang; rev = $rev } | ConvertTo-Json -Compress)
    [IO.File]::WriteAllText((Join-Path $PayloadDir $script:ConfigName), $cfgJson, (New-Object Text.UTF8Encoding($false)))

    Write-Step (L "OK - payload and scripts copied to '$ModRoot' (language: $chosenLang)." "OK - payload e script distribuiti in '$ModRoot' (lingua: $chosenLang).")

    # ============================================================
    # FASE 3 - Installazione/verifica immediata del mod nella versione corrente
    # ============================================================
    Write-Step (L "Checking/installing the mod in the current Vivaldi version..." "Verifica/installazione mod nella versione corrente di Vivaldi...")

    $masterJs = Join-Path $PayloadDir 'move-workspace-panel.js'

    # Stessa funzione usata dal watcher in background: idempotente, scrittura
    # atomica, backup window.html.bak creato una sola volta.
    $repairResult = Repair-VersionFolder -VersionFolder $versionFolder -MasterJs $masterJs
    switch -Wildcard ($repairResult) {
        'repaired' { Write-Step (L "Mod installed/restored in '$resourcesDir'." "Mod installato/ripristinato in '$resourcesDir'.") }
        'ok'       { Write-Step (L "Mod already present and up to date: no change needed in the current version." "Mod gia' presente e aggiornato: nessuna modifica necessaria alla versione corrente.") }
        default    { throw (L "Installing the mod in the current version failed: $repairResult" "Installazione del mod nella versione corrente non riuscita: $repairResult") }
    }

    # ============================================================
    # FASE 4 - Riscrittura shortcut Vivaldi (Desktop / Start Menu)
    # ============================================================
    Write-Step (L "Looking for Vivaldi shortcuts to update..." "Ricerca shortcut Vivaldi da aggiornare...")

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
            Write-Step (L "WARNING: existing shortcut manifest unreadable, creating a new one." "ATTENZIONE: manifest shortcut esistente illeggibile, ne creo uno nuovo.")
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
                Write-Step (L "Shortcut updated: '$($lnk.FullName)'" "Shortcut aggiornato: '$($lnk.FullName)'")
            } catch {
                Write-Step ((L "WARNING: cannot process '" "ATTENZIONE: impossibile elaborare '") + $lnk.FullName + "': " + $_.Exception.Message)
            }
        }
    }

    $backupEntries | ConvertTo-Json -Depth 4 | Set-Content -Path $ShortcutsBackupFile -Encoding UTF8

    if ($updatedCount -eq 0) {
        Write-Step (L "No shortcut to update (already updated or none found)." "Nessuno shortcut da aggiornare (gia' aggiornati o nessuno trovato).")
    } else {
        Write-Step (L "OK - $updatedCount shortcut(s) updated." "OK - $updatedCount shortcut aggiornati.")
    }

    # ============================================================
    # FASE 5 - Ripristino automatico dopo gli aggiornamenti di Vivaldi
    # ============================================================
    # Un piccolo processo nascosto (Watcher-Daemon.ps1) aspetta, a costo quasi
    # zero, la comparsa di una nuova cartella versione e rimette la mod. Parte
    # al login (HKCU Run, nessun amministratore) e subito adesso.
    Add-ModRoot -AppRoot $appRootFull

    # (con VIVALDI_WSMOD_ROOT impostata - solo test automatici - non si tocca mai la voce Run reale
    #  e l'attivita' pianificata ha un nome di prova)
    if ($NoAutostart) {
        Write-Step (L "Autostart skipped (-NoAutostart)." "Avvio automatico saltato (-NoAutostart).")
    } else {
        Write-Step (L "Enabling automatic restore after Vivaldi updates..." "Attivazione del ripristino automatico dopo gli aggiornamenti...")
        $startVbs = Join-Path $ScriptsDir 'Start-Daemon.vbs'
        $wscriptForRun = Join-Path $env:WINDIR 'System32\wscript.exe'
        if (-not $env:VIVALDI_WSMOD_ROOT) {
            $runKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $runValue = ('"{0}" //B "{1}"' -f $wscriptForRun, $startVbs)
            Set-ItemProperty -Path $runKey -Name 'VivaldiWSMod' -Value $runValue
        }

        # Attivita' pianificata dell'utente (nessun amministratore): all'accesso e ogni N minuti
        # riaccende il watcher se si e' spento (se e' acceso non fa nulla).
        try {
            $taskName = Register-ModKeepalive -VbsPath $startVbs -IntervalMinutes $KeepaliveIntervalMinutes
            Write-Step (L "OK - scheduled task '$taskName' created (at login and every $KeepaliveIntervalMinutes min: restarts the watcher only if it is not running)." "OK - attivita' pianificata '$taskName' creata (all'accesso e ogni $KeepaliveIntervalMinutes min: riaccende il watcher solo se e' spento).")
        } catch {
            Write-Step ((L "WARNING: scheduled task not created: " "ATTENZIONE: attivita' pianificata non creata: ") + $_.Exception.Message)
        }

        # Riavvia il watcher cosi' usa subito gli script appena copiati; parte STACCATO (tramite Windows),
        # non come figlio di questo programma.
        [void](Stop-ModDaemon)
        Start-Sleep -Milliseconds 500
        $how = Start-ModDaemonDetached -VbsPath $startVbs
        $up = $false
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Milliseconds 500
            if (@(Get-ModDaemonProcesses).Count -gt 0) { $up = $true; break }
        }
        if ($up) {
            Write-Step (L "OK - background watcher active, started detached ($how); it restarts by itself at every login and every $KeepaliveIntervalMinutes min if it ever stops." "OK - watcher in background attivo, avviato staccato ($how); si riavvia da solo a ogni accesso e ogni $KeepaliveIntervalMinutes min se si dovesse spegnere.")
        } else {
            Write-Step (L "WARNING: watcher did not start now; the scheduled task or the next login will start it." "ATTENZIONE: watcher non partito ora; lo avviera' l'attivita' pianificata o il prossimo accesso.")
        }
    }    Write-Host ""
    Write-Host (L "=== Installation completed successfully ===" "=== Installazione completata con successo ===") -ForegroundColor Green
    Write-Host (L "Language: $chosenLang. You can change it from the mod's menu (Shift+right-click on a tab) at any time." "Lingua: $chosenLang. Puoi cambiarla in qualsiasi momento dal menu della mod (Maiusc + tasto destro su una tab).")
    exit 0

} catch {
    Write-Host ""
    Write-Host (L "=== ERROR: installation not completed ===" "=== ERRORE: installazione non completata ===") -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
