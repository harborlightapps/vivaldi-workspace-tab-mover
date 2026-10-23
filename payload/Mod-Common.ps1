#requires -Version 5.1
<#
.SYNOPSIS
    Funzioni condivise del mod "Sposta nel Workspace" (installer, watcher, disinstallatore).
.DESCRIPTION
    File di sola libreria: va incluso con dot-sourcing (". .\Mod-Common.ps1").
    Contiene la logica unica di controllo/ripristino di UNA cartella versione
    di Vivaldi, cosi' Install-Mod.ps1, Watcher-Core.ps1 e Watcher-Daemon.ps1
    fanno tutti la stessa cosa nello stesso modo (idempotente, atomico).
#>

$script:ScriptTag = '<script src="move-workspace-panel.js"></script>'

function Get-ModRoot {
    # VIVALDI_WSMOD_ROOT serve solo ai test automatici (cartella temporanea).
    if ($env:VIVALDI_WSMOD_ROOT) { return $env:VIVALDI_WSMOD_ROOT }
    return (Join-Path $env:LOCALAPPDATA 'VivaldiWSMod')
}

# Log breve con rotazione: ws-mod.log (max ~100 KB) + ws-mod.log.1. Mai eccezioni.
function Write-ModLog {
    param([string]$Message)
    try {
        $logDir  = Join-Path (Get-ModRoot) 'logs'
        $logFile = Join-Path $logDir 'ws-mod.log'
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        if ((Test-Path -LiteralPath $logFile) -and ((Get-Item -LiteralPath $logFile).Length -gt 100KB)) {
            Move-Item -LiteralPath $logFile -Destination ($logFile + '.1') -Force
        }
        $line = '{0} | {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
        [IO.File]::AppendAllText($logFile, $line + "`r`n", (New-Object Text.UTF8Encoding($false)))
    } catch { }
}

# Cartelle versione sotto la cartella Application, dalla piu' recente.
function Get-VersionFolders {
    param([string]$AppRoot)
    if (-not (Test-Path -LiteralPath $AppRoot)) { return @() }
    @(Get-ChildItem -LiteralPath $AppRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
        Sort-Object { [version]$_.Name } -Descending)
}

# Un file e' "stabile" se esiste, non e' vuoto, non viene modificato da almeno
# MinAgeSeconds e si riesce ad aprirlo in lettura/scrittura esclusiva (cioe'
# nessun altro processo lo sta scrivendo: l'aggiornatore di Vivaldi ha finito).
function Test-FileStable {
    param([string]$Path, [int]$MinAgeSeconds = 4)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.Length -le 0) { return $false }
        if (((Get-Date) - $item.LastWriteTime).TotalSeconds -lt $MinAgeSeconds) { return $false }
        $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $fs.Close()
        return $true
    } catch { return $false }
}

function Get-FileSha256 {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# Sostituisce $Target con il contenuto di $TempFile in modo atomico (stesso volume).
function Move-OverTarget {
    param([string]$TempFile, [string]$Target)
    if (Test-Path -LiteralPath $Target) {
        [IO.File]::Replace($TempFile, $Target, [NullString]::Value)
    } else {
        [IO.File]::Move($TempFile, $Target)
    }
}

# Stato (sola lettura) di una cartella versione.
function Get-VersionState {
    param([System.IO.DirectoryInfo]$VersionFolder, [string]$MasterJs)
    $res = Join-Path $VersionFolder.FullName 'resources\vivaldi'
    $state = [ordered]@{
        Version = $VersionFolder.Name
        ResourcesDir = $res
        WindowHtml = Join-Path $res 'window.html'
        TargetJs = Join-Path $res 'move-workspace-panel.js'
        HasWindowHtml = $false
        TagOk = $false
        JsOk = $false
    }
    if (Test-Path -LiteralPath $state.WindowHtml) {
        $state.HasWindowHtml = $true
        try {
            $html = [IO.File]::ReadAllText($state.WindowHtml)
            $state.TagOk = $html.Contains($script:ScriptTag)
        } catch { }
    }
    if ((Test-Path -LiteralPath $state.TargetJs) -and (Test-Path -LiteralPath $MasterJs)) {
        try { $state.JsOk = ((Get-FileSha256 $state.TargetJs) -eq (Get-FileSha256 $MasterJs)) } catch { }
    }
    [PSCustomObject]$state
}

<#
  Ripristina il mod in UNA cartella versione. Idempotente.
  Ritorna una stringa:
    'ok'           gia' tutto a posto, nessuna modifica
    'repaired'     ripristinato (JS e/o tag)
    'unstable'     i file non sono ancora stabili (aggiornamento in corso): riprovare
    'nowindowhtml' window.html non ancora presente: riprovare
    'error: ...'   errore (loggato)
  Con -RequireStable non tocca nulla finche' window.html non e' stabile.
#>
function Repair-VersionFolder {
    param(
        [System.IO.DirectoryInfo]$VersionFolder,
        [string]$MasterJs,
        [switch]$RequireStable,
        [int]$StableAgeSeconds = 4
    )
    try {
        $st = Get-VersionState -VersionFolder $VersionFolder -MasterJs $MasterJs
        if (-not $st.HasWindowHtml) { return 'nowindowhtml' }
        if ($st.TagOk -and $st.JsOk) { return 'ok' }

        if ($RequireStable -and -not (Test-FileStable -Path $st.WindowHtml -MinAgeSeconds $StableAgeSeconds)) {
            return 'unstable'
        }

        $reasons = @()
        if (-not $st.JsOk)  { $reasons += 'js' }
        if (-not $st.TagOk) { $reasons += 'tag' }

        # 1) JS per primo: window.html non deve mai puntare a un file mancante.
        if (-not $st.JsOk) {
            $tmpJs = $st.TargetJs + '.wsmod.tmp'
            [IO.File]::Copy($MasterJs, $tmpJs, $true)
            Move-OverTarget -TempFile $tmpJs -Target $st.TargetJs
        }

        # 2) tag in window.html: scrittura su file temporaneo + sostituzione atomica.
        if (-not $st.TagOk) {
            $bytes = [IO.File]::ReadAllBytes($st.WindowHtml)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            $html = [IO.File]::ReadAllText($st.WindowHtml)
            $idx = $html.LastIndexOf('</body>', [StringComparison]::OrdinalIgnoreCase)
            if ($idx -lt 0) { throw "tag </body> non trovato in window.html" }

            $backup = $st.WindowHtml + '.bak'
            if (-not (Test-Path -LiteralPath $backup)) {
                [IO.File]::Copy($st.WindowHtml, $backup, $false)
            }

            $patched = $html.Insert($idx, $script:ScriptTag + "`r`n")
            $tmpHtml = $st.WindowHtml + '.wsmod.tmp'
            [IO.File]::WriteAllText($tmpHtml, $patched, (New-Object Text.UTF8Encoding($hasBom)))
            $check = [IO.File]::ReadAllText($tmpHtml)
            if (-not $check.Contains($script:ScriptTag) -or $check.Length -ne $patched.Length) {
                Remove-Item -LiteralPath $tmpHtml -Force -ErrorAction SilentlyContinue
                throw "verifica del file temporaneo fallita"
            }
            Move-OverTarget -TempFile $tmpHtml -Target $st.WindowHtml
        }

        Write-ModLog ("RIPRISTINO versione '" + $st.Version + "' (" + ($reasons -join '+') + ")")
        return 'repaired'
    } catch {
        Write-ModLog ("ERRORE ripristino versione '" + $VersionFolder.Name + "': " + $_.Exception.Message)
        return ('error: ' + $_.Exception.Message)
    }
}

# Controlla/ripristina la cartella versione PIU' RECENTE di un'installazione
# (le vecchie restano come sono: Vivaldi le cancella da solo a fine aggiornamento).
function Invoke-RepairLatest {
    param([string]$AppRoot, [string]$MasterJs, [switch]$RequireStable, [int]$StableAgeSeconds = 4)
    $latest = (Get-VersionFolders -AppRoot $AppRoot | Select-Object -First 1)
    if (-not $latest) { return 'noversion' }
    if (-not (Test-Path -LiteralPath $MasterJs)) {
        Write-ModLog ("ERRORE: payload master non trovato in '" + $MasterJs + "'")
        return 'nomaster'
    }
    Repair-VersionFolder -VersionFolder $latest -MasterJs $MasterJs -RequireStable:$RequireStable -StableAgeSeconds $StableAgeSeconds
}

# --- Elenco delle installazioni Vivaldi da sorvegliare (roots.json) ---
function Get-RootsFile { Join-Path (Get-ModRoot) 'roots.json' }

function Get-ModRoots {
    $f = Get-RootsFile
    if (-not (Test-Path -LiteralPath $f)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
        return @($raw | Where-Object { $_ -is [string] -and $_ })
    } catch { return @() }
}

function Add-ModRoot {
    param([string]$AppRoot)
    $roots = @(Get-ModRoots)
    if (-not ($roots | Where-Object { $_ -ieq $AppRoot })) { $roots += $AppRoot }
    $json = ConvertTo-Json -InputObject @($roots)
    [IO.File]::WriteAllText((Get-RootsFile), $json, (New-Object Text.UTF8Encoding($false)))
}

# --- Processo watcher in background ---
function Stop-ModDaemon {
    $stopped = 0
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'Watcher-Daemon\.ps1' -and $_.CommandLine -like ('*' + (Get-ModRoot) + '*') -and $_.ProcessId -ne $PID } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop; $stopped++ } catch { } }
    return $stopped
}

function Get-ModDaemonProcesses {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'Watcher-Daemon\.ps1' -and $_.CommandLine -like ('*' + (Get-ModRoot) + '*') -and $_.ProcessId -ne $PID })
}
