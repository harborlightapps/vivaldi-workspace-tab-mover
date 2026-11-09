' ============================================================
' Start-Daemon.vbs
' Se il watcher in background del mod (Watcher-Daemon.ps1) NON e' acceso lo avvia,
' senza alcuna finestra; se e' gia' acceso non fa NIENTE (ne' avvia PowerShell).
'
' Chi lo lancia:
'   - la voce HKCU\...\Run (a ogni accesso a Windows);
'   - l'attivita' pianificata "VivaldiWSMod-Keepalive" (all'accesso e ogni 30 minuti):
'     se il watcher si e' spento per qualunque motivo lo riaccende, e il watcher appena
'     avviato ripara subito la Mod;
'   - l'installer (tramite Windows/WMI o tramite l'attivita', cosi' il watcher non e' figlio
'     del programma che lancia l'installer e non si chiude con esso).
'
' Come riconosce che il watcher e' acceso (v1.2.2):
'   1) prova ad aprire il file watcher.lock: il watcher lo tiene aperto in esclusiva per tutta
'      la sua vita, quindi "file bloccato" = watcher vivo. Funziona con qualsiasi livello di
'      permessi (con permessi di amministratore Windows non mostra la riga di comando del
'      processo e il vecchio controllo non lo vedeva);
'   2) in piu', per i watcher vecchi (senza file di blocco) e per ogni caso dubbio, il controllo
'      "storico" sulla riga di comando dei processi powershell.exe.
'   In ogni caso un secondo watcher si chiude subito da solo (mutex + blocco): non possono mai
'   essere attivi due watcher insieme.
'
' Avvio invisibile: powershell parte dentro "conhost.exe --headless" (nessuna console, nemmeno
' per un istante); se conhost non c'e', con finestra nascosta (stile 0).
' Non deve mai mostrare errori: qualunque problema viene ignorato.
' ============================================================
Option Explicit

Dim fso, shell, scriptDir, modRoot, daemonPath, lockPath, wmi, procs, p, running, cmd, ts, psCmd, conhostPath

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
modRoot = fso.GetParentFolderName(scriptDir)
daemonPath = fso.BuildPath(scriptDir, "Watcher-Daemon.ps1")
lockPath = fso.BuildPath(modRoot, "watcher.lock")

running = False
On Error Resume Next

' 1) Blocco su file: se non si riesce ad aprirlo, il watcher e' vivo.
If fso.FileExists(lockPath) Then
    Err.Clear
    Set ts = fso.OpenTextFile(lockPath, 8, False)
    If Err.Number <> 0 Then
        running = True
    Else
        ts.Close
    End If
    Err.Clear
End If

' 2) Controllo storico sulla riga di comando (vede i watcher vecchi non elevati).
If Not running Then
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    If Err.Number = 0 Then
        Set procs = wmi.ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name = 'powershell.exe'")
        If Err.Number = 0 Then
            For Each p In procs
                If Not IsNull(p.CommandLine) Then
                    If InStr(1, p.CommandLine, "Watcher-Daemon.ps1", 1) > 0 Then
                        If InStr(1, p.CommandLine, modRoot, 1) > 0 Then
                            running = True
                            Exit For
                        End If
                    End If
                End If
            Next
        End If
    End If
    Err.Clear
End If

If (Not running) And fso.FileExists(daemonPath) Then
    psCmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & daemonPath & """ -ModRoot """ & modRoot & """"
    conhostPath = fso.BuildPath(shell.ExpandEnvironmentStrings("%WINDIR%"), "System32\conhost.exe")
    If fso.FileExists(conhostPath) Then
        cmd = """" & conhostPath & """ --headless " & psCmd
    Else
        cmd = psCmd
    End If
    ' Finestra nascosta (0), senza attendere (False).
    shell.Run cmd, 0, False
End If
On Error Goto 0
