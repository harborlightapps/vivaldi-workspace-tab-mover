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
'   - l'installer (tramite Windows/WMI, cosi' il watcher non e' figlio del programma
'     che lancia l'installer e non si chiude con esso).
'
' Controllo leggero: una sola interrogazione dell'elenco processi e nient'altro.
' Non deve mai mostrare errori: qualunque problema viene ignorato (in dubbio, avvia:
' un secondo watcher si chiude subito da solo grazie al lock di istanza unica).
' ============================================================
Option Explicit

Dim fso, shell, scriptDir, modRoot, daemonPath, wmi, procs, p, running, cmd

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
modRoot = fso.GetParentFolderName(scriptDir)
daemonPath = fso.BuildPath(scriptDir, "Watcher-Daemon.ps1")

running = False
On Error Resume Next
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

If (Not running) And fso.FileExists(daemonPath) Then
    cmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & daemonPath & """ -ModRoot """ & modRoot & """"
    ' Finestra nascosta (0), senza attendere (False).
    shell.Run cmd, 0, False
End If
On Error Goto 0
