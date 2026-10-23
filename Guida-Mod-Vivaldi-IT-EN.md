**Nota / Note**

C'è **un'unica cartella/zip** che contiene sia `Install.bat`/`Install.exe` sia `Uninstall.bat`/`Uninstall.exe` fianco a fianco: sono due comandi indipendenti a un click ciascuno. Versione 1.1.0. Feedback: [Issues](https://github.com/milt983/vivaldi-workspace-tab-mover/issues) · [Discussions](https://github.com/milt983/vivaldi-workspace-tab-mover/discussions).

There is **one single folder/zip** containing both `Install.bat`/`Install.exe` and `Uninstall.bat`/`Uninstall.exe` side by side: two independent one-click commands. Version 1.1.0. Feedback: [Issues](https://github.com/milt983/vivaldi-workspace-tab-mover/issues) · [Discussions](https://github.com/milt983/vivaldi-workspace-tab-mover/discussions).

---
# ITALIANO

## Contenuto del pacchetto

```
Vivaldi MOD for Workspace\
├── Install.bat              ← installazione, un doppio click (finestra terminale)
├── Install.exe               ← installazione, un doppio click (eseguibile nativo, stessa cosa di Install.bat)
├── Install-Mod.ps1          ← motore, chiamato automaticamente da Install.bat/Install.exe
├── Uninstall.bat            ← disinstallazione, un doppio click (finestra terminale)
├── Uninstall.exe              ← disinstallazione, un doppio click (eseguibile nativo, stessa cosa di Uninstall.bat)
├── Uninstall-Mod.ps1        ← motore, chiamato automaticamente da Uninstall.bat/Uninstall.exe
├── exe-source\               ← sorgente C# di Install.exe/Uninstall.exe, serve solo per ricompilarli in futuro
└── payload\
    ├── move-workspace-panel.js   ← il mod vero e proprio
    ├── Mod-Common.ps1            ← funzioni condivise (controllo/ripristino sicuro)
    ├── Watcher-Daemon.ps1        ← sorvegliante in background: rimette la mod dopo ogni aggiornamento di Vivaldi
    ├── Start-Daemon.vbs          ← lo avvia senza finestre (al login e subito dopo l'installazione)
    ├── Watcher-Core.ps1          ← controllo/ripristino al volo (usato dagli shortcut)
    └── Vivaldi-Launch.vbs        ← wrapper silenzioso usato dagli shortcut
```

**Install.bat vs Install.exe (e lo stesso per Uninstall)**: fanno esattamente la stessa cosa — stesse domande, stesso risultato. `.bat` apre una finestra di terminale standard; `.exe` e' un programma vero e proprio con la sua icona. Usa quello che preferisci, sono intercambiabili e restano entrambi nel pacchetto.

## 1. Installazione

1. Doppio click su **Install.bat** oppure **Install.exe** (fanno la stessa cosa, vedi sopra).
2. Si apre una finestra nera (terminale). Quando chiede:
   `Percorso cartella Application di Vivaldi (es. H:\Vivaldi Standalone\Application):`
   scrivi (o incolla) il percorso della cartella **Application** della tua installazione Vivaldi e premi Invio.
   - Installazione Standalone/Portable: `<unità>:\Vivaldi Standalone\Application` (es. `H:\Vivaldi Standalone\Application`)
   - Installazione normale: `C:\Users\<tuo-utente>\AppData\Local\Vivaldi\Application`
3. Attendi il messaggio verde `=== Installazione completata con successo ===`.
4. Premi un tasto qualsiasi per chiudere la finestra.
5. Fatto. Apri Vivaldi dal suo shortcut abituale (Desktop o Start Menu):
   - **Tasto destro semplice** su una tab nel pannello "Windows and Tabs" → menu nativo di Vivaldi, invariato (New Tab, Duplicate, Pin, Close, ecc.).
   - **Maiusc (Shift) + tasto destro** sulla stessa tab → menu del mod **"Sposta nel Workspace"**.

**Spostare più tab insieme (anche NON consecutive)**: nel pannello "Windows and Tabs" seleziona le tab che vuoi con **Ctrl+click** (singole, anche sparse) oppure **Shift+click** (intervallo). Poi fai **Maiusc+tasto destro su una delle tab selezionate**: il menu mostra "Sposta N tab nel Workspace" e sposta **solo le tab che hai scelto** (non quelle in mezzo), in un solo click. La selezione sullo schermo resta esattamente quella che hai fatto: Vivaldi di solito la allargherebbe a intervallo con Maiusc+tasto destro, la mod gli impedisce di farlo per quel gesto. Se invece fai Maiusc+tasto destro su una tab che non fa parte della selezione, sposta solo quella tab.

Cosa succede dietro le quinte: i file del mod vengono copiati in `%LocalAppData%\VivaldiWSMod\`; il tag `<script>` viene iniettato in `window.html`; tutti gli shortcut Vivaldi trovati (Desktop/Start Menu, utente e tutti gli utenti) vengono riscritti per passare da un controllo automatico prima di aprire Vivaldi; inoltre parte un piccolo programma nascosto (il *watcher*) che si riavvia da solo a ogni login (voce `HKCU\...\Run`, **non servono diritti di amministratore**) e rimette la mod dopo ogni aggiornamento di Vivaldi.

## 2. Manutenzione (automatica, zero click)

Non devi fare nulla. Dopo ogni aggiornamento di Vivaldi la mod torna da sola, **senza reinstallare e senza riavviare Windows**:
- Il *watcher* (un piccolo programma nascosto, senza finestre né icone) resta in attesa. Quando l'aggiornatore di Vivaldi crea la nuova cartella versione, aspetta che `window.html` sia completo e che nessuno lo stia più scrivendo, poi rimette il tag `<script>` e il file `move-workspace-panel.js`. Di solito succede **mentre l'aggiornamento è ancora in corso**, quindi già alla prima riapertura di Vivaldi la mod c'è.
- Costo: praticamente zero (nessun controllo continuo: si sveglia solo quando compare una cartella nuova, più un controllo di sicurezza ogni 30 minuti). Occupa qualche decina di MB di memoria.
- Scrive in modo sicuro (file temporaneo + sostituzione, backup `window.html.bak`), non duplica mai il tag e lascia com'è la cartella della versione vecchia.
- Se qualcosa non funziona, c'è un piccolo log (si ruota da solo): `%LocalAppData%\VivaldiWSMod\logs\ws-mod.log`.
- In più, se apri Vivaldi da uno shortcut modificato dall'installer, `Watcher-Core.ps1` fa un controllo al volo prima dell'apertura (secondo canale).

**Da sapere**: il watcher gira solo mentre sei collegato a Windows con il tuo utente; se per qualche motivo non fosse attivo, rilanciare `Install.bat`/`Install.exe` lo riattiva (e ripara la versione corrente).

## Windows SmartScreen / antivirus, requisiti, limiti

- **SmartScreen**: gli `.exe` non sono firmati digitalmente, Windows può mostrare un avviso ("Windows ha protetto il PC"). Puoi usare `Install.bat`/`Uninstall.bat` (stessa cosa, testo leggibile) o leggere il sorgente in `exe-source\` (gli `.exe` avviano solo `Install-Mod.ps1`/`Uninstall-Mod.ps1`). SHA256 di `Install.exe`: `EA3C88865D059B8D48948A42EAE580E652886AFF255E303CDC9ED7819F9F1CCA`; di `Uninstall.exe`: `CFEB353B8FD94EF8BCEED5DEE1B3A6268F916D58A90A77B0964EC841DDCA4B03`. Lo SHA256 dello zip è nelle note della Release su GitHub.
- **Requisiti**: Windows con PowerShell 5.1 (incluso), nessun amministratore; Vivaldi Standalone/Portable o normale. Provato su Windows 11.
- **Non testato**: altre versioni di Vivaldi oltre 8.1.x/8.2.x, installazioni "normali" di recente, Windows 10, e un aggiornamento reale di Vivaldi osservato dal vivo (verificato solo con simulazione e sul log di un aggiornamento precedente).

## 3. Disinstallazione

1. Nella stessa cartella, doppio click su **Uninstall.bat** oppure **Uninstall.exe** (fanno la stessa cosa).
2. Inserisci lo stesso percorso della cartella Application usato in installazione.
3. Quando chiede `Continuare? (S/N)`, digita **S** e premi Invio.
4. Attendi `=== Disinstallazione completata con successo ===`.
   - Se compare invece un avviso giallo su una cartella non completamente rimovibile: non è un errore bloccante. Il mod è già disinstallato e gli shortcut già ripristinati a quel punto; devi solo chiudere eventuali programmi che tengono occupata `%LocalAppData%\VivaldiWSMod` e cancellarla a mano.
5. Premi un tasto per chiudere la finestra.

Cosa succede dietro le quinte: `window.html` viene ripristinato all'originale, `move-workspace-panel.js` viene rimosso dall'installazione live, ogni shortcut modificato torna targetato/argomenti/icona originali, il watcher viene fermato e la sua voce di avvio automatico rimossa, e la cartella `%LocalAppData%\VivaldiWSMod\` viene eliminata.

---

# ENGLISH

## Package contents

```
Vivaldi MOD for Workspace\
├── Install.bat              ← installer, one double-click (terminal window)
├── Install.exe               ← installer, one double-click (native executable, same as Install.bat)
├── Install-Mod.ps1          ← engine, called automatically by Install.bat/Install.exe
├── Uninstall.bat            ← uninstaller, one double-click (terminal window)
├── Uninstall.exe              ← uninstaller, one double-click (native executable, same as Uninstall.bat)
├── Uninstall-Mod.ps1        ← engine, called automatically by Uninstall.bat/Uninstall.exe
├── exe-source\               ← C# source for Install.exe/Uninstall.exe, only needed to rebuild them later
└── payload\
    ├── move-workspace-panel.js   ← the actual mod
    ├── Mod-Common.ps1            ← shared functions (safe check/repair)
    ├── Watcher-Daemon.ps1        ← background watcher: puts the mod back after every Vivaldi update
    ├── Start-Daemon.vbs          ← starts it with no windows (at login and right after installation)
    ├── Watcher-Core.ps1          ← on-the-fly check/repair (used by the shortcuts)
    └── Vivaldi-Launch.vbs        ← silent wrapper used by the shortcuts
```

**Install.bat vs Install.exe (same for Uninstall)**: identical behavior — same prompts, same result. `.bat` opens a plain terminal window; `.exe` is a proper program with its own icon. Use whichever you prefer, both stay in the package.

## 1. Installation

1. Double-click **Install.bat** or **Install.exe** (identical, see above).
2. A black terminal window opens. When prompted:
   `Percorso cartella Application di Vivaldi (es. H:\Vivaldi Standalone\Application):`
   type (or paste) the path to your Vivaldi installation's **Application** folder and press Enter.
   - Standalone/Portable install: `<drive>:\Vivaldi Standalone\Application` (e.g. `H:\Vivaldi Standalone\Application`)
   - Regular install: `C:\Users\<your-user>\AppData\Local\Vivaldi\Application`
3. Wait for the green `=== Installazione completata con successo ===` message.
4. Press any key to close the window.
5. Done. Open Vivaldi from its usual shortcut (Desktop or Start Menu):
   - **Plain right-click** on a tab in the "Windows and Tabs" panel → Vivaldi's native menu, unchanged (New Tab, Duplicate, Pin, Close, etc.).
   - **Shift + right-click** on the same tab → the mod's **"Sposta nel Workspace"** menu.
   - Note: the installer/uninstaller messages and the mod's menu labels are currently in Italian ("Sposta nel Workspace" = "Move to Workspace", "Sposta N tab nel Workspace" = "Move N tabs to Workspace", "Continuare? (S/N)" = "Continue? (Y/N)"). English labels are an open request.

**Moving multiple tabs at once (even NON-consecutive ones)**: in the "Windows and Tabs" panel pick the tabs you want with **Ctrl+click** (individual, even scattered) or **Shift+click** (range). Then **Shift+right-click on one of the selected tabs**: the menu shows "Sposta N tab nel Workspace" and moves **only the tabs you picked** (not the ones in between) in one click. The selection on screen stays exactly as you made it: Vivaldi would normally extend it to a range on Shift+right-click, and the mod stops it from doing so for that gesture. Shift+right-clicking a tab that is not part of the selection moves only that tab.

Under the hood: mod files are copied to `%LocalAppData%\VivaldiWSMod\`; the `<script>` tag is injected into `window.html`; every Vivaldi shortcut found (Desktop/Start Menu, current user and all users) is rewritten to run through an automatic check before Vivaldi opens; a small hidden program (the *watcher*) is also started, restarts itself at every login (`HKCU\...\Run` entry, **no administrator rights needed**) and puts the mod back after every Vivaldi update.

## 2. Maintenance (automatic, zero clicks)

Nothing to do. After every Vivaldi update the mod comes back by itself, **without reinstalling and without restarting Windows**:
- The *watcher* (a small hidden program, no windows or tray icon) waits quietly. When Vivaldi's updater creates the new version folder, it waits until `window.html` is complete and nobody is writing to it any more, then puts the `<script>` tag and `move-workspace-panel.js` back. This usually happens **while the update is still running**, so the mod is already there the first time you reopen Vivaldi.
- Cost: practically zero (no continuous polling: it only wakes up when a new folder appears, plus a safety check every 30 minutes). It uses a few tens of MB of memory.
- Writes are safe (temporary file + replace, `window.html.bak` backup), the tag is never duplicated, and the old version folder is left as is.
- If something does not work there is a small self-rotating log: `%LocalAppData%\VivaldiWSMod\logs\ws-mod.log`.
- In addition, if you open Vivaldi from a shortcut modified by the installer, `Watcher-Core.ps1` does an on-the-fly check just before it opens (second channel).

**Good to know**: the watcher only runs while you are logged in to Windows with your user; if for any reason it is not active, running `Install.bat`/`Install.exe` again restarts it (and repairs the current version).

## Windows SmartScreen / antivirus, requirements, limits

- **SmartScreen**: the `.exe` files are not code-signed, Windows may show a warning ("Windows protected your PC"). You can use `Install.bat`/`Uninstall.bat` (same thing, readable text) or read the source in `exe-source\` (the `.exe` files only run `Install-Mod.ps1`/`Uninstall-Mod.ps1`). SHA256 of `Install.exe`: `EA3C88865D059B8D48948A42EAE580E652886AFF255E303CDC9ED7819F9F1CCA`; of `Uninstall.exe`: `CFEB353B8FD94EF8BCEED5DEE1B3A6268F916D58A90A77B0964EC841DDCA4B03`. The zip's SHA256 is in the Release notes on GitHub.
- **Requirements**: Windows with PowerShell 5.1 (built in), no administrator; Vivaldi Standalone/Portable or regular. Tested on Windows 11.
- **Not tested**: Vivaldi versions other than 8.1.x/8.2.x, "regular" installs recently, Windows 10, and a real Vivaldi update observed live (verified only via simulation and against the log of a previous update).

## 3. Uninstallation

1. In the same folder, double-click **Uninstall.bat** or **Uninstall.exe** (identical).
2. Enter the same Application folder path used during installation.
3. When asked `Continuare? (S/N)`, type **S** (Yes) and press Enter.
4. Wait for `=== Disinstallazione completata con successo ===`.
   - If a yellow warning appears instead about a folder that couldn't be fully removed: this is not a blocking error. The mod is already uninstalled and shortcuts already restored at that point; just close any program holding `%LocalAppData%\VivaldiWSMod` open and delete it manually.
5. Press any key to close the window.

Under the hood: `window.html` is restored to Vivaldi's original, `move-workspace-panel.js` is removed from the live install, every modified shortcut is restored to its original target/arguments/icon, the watcher is stopped and its autostart entry removed, and the `%LocalAppData%\VivaldiWSMod\` folder is deleted.
