' ============================================================
' Vivaldi-Launch.vbs
' Modulo 2 - wrapper silenzioso (nessuna finestra visibile).
' Esegue il controllo/ripristino del mod (Watcher-Core.ps1) e POI
' avvia Vivaldi. Pensato per sostituire il target degli shortcut
' Vivaldi (Desktop / Start Menu) al posto di vivaldi.exe diretto.
'
' Uso (impostato automaticamente da Install-Mod.ps1 nel target
' dello shortcut, come argomenti):
'   wscript.exe "Vivaldi-Launch.vbs" "<VivaldiAppRoot>" "<VivaldiExePath>"
'
' Esempio:
'   wscript.exe "...\Vivaldi-Launch.vbs" "H:\Vivaldi Standalone\Application" "H:\Vivaldi Standalone\Application\vivaldi.exe"
'
' Filosofia (coerente con Watcher-Core.ps1): non deve MAI impedire
' l'avvio di Vivaldi. Qualunque errore nel controllo/ripristino
' viene ignorato in silenzio: si passa comunque al lancio del browser.
' ============================================================

Option Explicit

Dim fso, shell, args, appRoot, exePath, scriptDir, watcherPath, psCmd

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
Set args = WScript.Arguments

' --- Validazione argomenti ---
' Senza AppRoot ed ExePath non sappiamo quale Vivaldi controllare/avviare:
' in condizioni normali Install-Mod.ps1 fornisce sempre questi due argomenti
' nel target dello shortcut, quindi questo ramo non dovrebbe mai attivarsi
' (copre solo esecuzioni manuali/errate dello script).
If args.Count < 2 Then
    WScript.Quit 0
End If

appRoot = args(0)
exePath = args(1)

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
watcherPath = fso.BuildPath(scriptDir, "Watcher-Core.ps1")

' --- Controllo/ripristino mod (sincrono, finestra nascosta) ---
' Qualunque errore qui (PowerShell assente, permessi, ecc.) viene ignorato:
' non deve bloccare l'avvio di Vivaldi.
On Error Resume Next
If fso.FileExists(watcherPath) Then
    psCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
            Quote(watcherPath) & " -VivaldiAppRoot " & Quote(appRoot)
    ' Finestra nascosta (0), esecuzione SINCRONA (waitOnReturn=True):
    ' il controllo dura pochi millisecondi, poi si procede al lancio del browser.
    shell.Run psCmd, 0, True
End If
On Error Goto 0

' --- Avvio Vivaldi (sempre, indipendentemente dall'esito del controllo) ---
On Error Resume Next
If fso.FileExists(exePath) Then
    ' Finestra normale (1), NON sincrono (waitOnReturn=False):
    ' wscript.exe termina subito dopo aver lanciato Vivaldi.
    shell.Run Quote(exePath), 1, False
End If
On Error Goto 0

Function Quote(s)
    Quote = """" & s & """"
End Function
