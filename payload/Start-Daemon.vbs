' ============================================================
' Start-Daemon.vbs
' Avvia in background, senza alcuna finestra, il sorvegliante del mod
' (Watcher-Daemon.ps1) che rimette la mod in Vivaldi dopo gli aggiornamenti.
' Lanciato al login dalla voce HKCU\...\Run creata da Install-Mod.ps1 e
' subito dopo l'installazione. Se il watcher e' gia' attivo, il nuovo
' processo si chiude da solo (mutex nel watcher).
' Non deve mai mostrare errori: qualunque problema viene ignorato.
' ============================================================
Option Explicit

Dim fso, shell, scriptDir, daemonPath, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
daemonPath = fso.BuildPath(scriptDir, "Watcher-Daemon.ps1")

On Error Resume Next
If fso.FileExists(daemonPath) Then
    cmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & daemonPath & """"
    ' Finestra nascosta (0), senza attendere (False).
    shell.Run cmd, 0, False
End If
On Error Goto 0
