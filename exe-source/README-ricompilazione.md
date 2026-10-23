# Sorgente di Install.exe e Uninstall.exe / Source of Install.exe and Uninstall.exe

**IT** — Questi due eseguibili sono *lanciatori sottili* (v1.2.0): avviano
`Install-Mod.ps1` / `Uninstall-Mod.ps1` (nella stessa cartella dell'eseguibile) con
Windows PowerShell e aspettano la fine. **Tutte le domande** (percorso della cartella
Application, lingua, conferma) le fanno gli script, in inglese e italiano; negli `.exe`
non c'è nessuna logica della mod. `Install.bat` / `Uninstall.bat` fanno la stessa cosa.

**EN** — These two executables are *thin launchers* (v1.2.0): they run
`Install-Mod.ps1` / `Uninstall-Mod.ps1` (next to the executable) with Windows PowerShell
and wait for it. **All the questions** (Application folder path, language, confirmation)
are asked by the scripts, in English and Italian; there is no mod logic in the `.exe`
files. `Install.bat` / `Uninstall.bat` do exactly the same.

## Ricompilare senza installare nulla / Rebuild without installing anything

Il codice è C# 5 apposta: si compila con il compilatore incluso in Windows
(.NET Framework 4.x, `csc.exe`), senza SDK. Le release v1.2.0 sono compilate così
(circa 5 KB ciascuna, richiedono solo .NET Framework 4.x già presente in Windows 10/11).

The code is plain C# 5 on purpose, so it builds with the compiler that ships with
Windows (.NET Framework 4.x `csc.exe`), no SDK needed. The v1.2.0 releases are built this way
(about 5 KB each; they only need .NET Framework 4.x, already part of Windows 10/11).

```
cd exe-source
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe /optimize+ /out:Install.exe Installer\Program.cs
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe /optimize+ /out:Uninstall.exe Uninstaller\Program.cs
```

Alternativa / Alternative: con il .NET SDK 8+ (`dotnet publish Installer\Installer.csproj -c Release -r win-x64 -o output`,
stessa cosa per `Uninstaller`) si ottiene un eseguibile autonomo più grande (~33 MB).
With the .NET SDK 8+ you get a larger self-contained executable (~33 MB).

Copia il risultato accanto a `Install-Mod.ps1` / `Uninstall-Mod.ps1` / Copy the result next to the scripts.