# Sorgente di Install.exe e Uninstall.exe

Questi due eseguibili sono lanciatori nativi Windows (C#/.NET 8, compilati
"self-contained" per Windows x64: non richiedono .NET installato sul PC di
destinazione). Fanno esattamente quello che fanno `Install.bat` e
`Uninstall.bat`: chiedono il percorso della cartella `Application` di
Vivaldi e richiamano `Install-Mod.ps1` / `Uninstall-Mod.ps1` (i motori
PowerShell, invariati) trovandoli nella stessa cartella in cui si trova
l'eseguibile stesso.

Non contengono nessuna logica del mod: sono solo un "avvio a doppio click"
alternativo ai file .bat, che restano presenti e funzionanti allo stesso
modo.

## Se in futuro serve ricompilarli

Serve il .NET SDK (versione 8 o successiva) — su Windows si scarica da
`https://dotnet.microsoft.com/download`. Poi, da un terminale nella
cartella `exe-source\Installer`:

```
dotnet publish Installer.csproj -c Release -r win-x64 -o output
```

Lo stesso, nella cartella `exe-source\Uninstaller`, per l'uninstaller:

```
dotnet publish Uninstaller.csproj -c Release -r win-x64 -o output
```

Il file `Install.exe` (o `Uninstall.exe`) compare nella sottocartella
`output` appena creata: va copiato nella cartella principale del pacchetto
(accanto a `Install-Mod.ps1` / `Uninstall-Mod.ps1`), sovrascrivendo quello
esistente.
