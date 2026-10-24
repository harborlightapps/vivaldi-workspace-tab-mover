**Nota / Note**

C'è **un'unica cartella/zip** che contiene sia `Install.bat`/`Install.exe` sia `Uninstall.bat`/`Uninstall.exe` fianco a fianco: sono due comandi indipendenti a un click ciascuno. Versione 1.2.1 (menu in inglese e italiano). Novità 1.2.1: il watcher parte staccato dal programma che lo avvia e un'attività pianificata nascosta dell'utente (`VivaldiWSMod-Keepalive`, all'accesso e ogni 30 minuti) lo riaccende; il ripristino dopo un aggiornamento reale di Vivaldi è stato osservato dal vivo il 23/10/2026 (8.2.4133.89 → 8.2.4133.94). Feedback: [Issues](https://github.com/harborlightapps/vivaldi-workspace-tab-mover/issues) · [Discussions](https://github.com/harborlightapps/vivaldi-workspace-tab-mover/discussions).

There is **one single folder/zip** containing both `Install.bat`/`Install.exe` and `Uninstall.bat`/`Uninstall.exe` side by side: two independent one-click commands. Version 1.2.1 (English and Italian menu). New in 1.2.1: the watcher starts detached from the program that launches it, and a hidden per-user scheduled task (`VivaldiWSMod-Keepalive`, at login and every 30 minutes) restarts it; restore after a real Vivaldi update was observed live on 23/10/2026 (8.2.4133.89 → 8.2.4133.94). Feedback: [Issues](https://github.com/harborlightapps/vivaldi-workspace-tab-mover/issues) · [Discussions](https://github.com/harborlightapps/vivaldi-workspace-tab-mover/discussions).

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
2. Si apre una finestra nera (terminale) con domande **bilingui**. Prima chiede
   `Vivaldi "Application" folder path / Percorso cartella "Application" di Vivaldi (e.g. H:\Vivaldi Standalone\Application):`
   scrivi (o incolla) il percorso della cartella **Application** della tua installazione Vivaldi e premi Invio (se il percorso è sbagliato te lo dice e puoi riprovare, fino a 3 volte).
   - Installazione Standalone/Portable: `<unità>:\Vivaldi Standalone\Application` (es. `H:\Vivaldi Standalone\Application`)
   - Installazione normale: `C:\Users\<tuo-utente>\AppData\Local\Vivaldi\Application`
   Poi chiede la lingua: `Language / Lingua: 1) English  2) Italiano`. Digita **1** o **2** e premi Invio; **Invio da solo = lingua rilevata automaticamente dall'interfaccia di Vivaldi** (inglese se non è italiano). Se la mod era già installata, viene proposta la lingua scelta l'ultima volta (Invio la conferma).
3. Attendi il messaggio verde `=== Installazione completata con successo ===` (o `=== Installation completed successfully ===` se hai scelto English).
4. Premi un tasto qualsiasi per chiudere la finestra.
5. Fatto. Apri Vivaldi dal suo shortcut abituale (Desktop o Start Menu):
   - **Tasto destro semplice** su una tab nel pannello "Windows and Tabs" → menu nativo di Vivaldi, invariato (New Tab, Duplicate, Pin, Close, ecc.).
   - **Maiusc (Shift) + tasto destro** sulla stessa tab → menu del mod **"Sposta nel Workspace"** (o **"Move to Workspace"** in inglese).

**Spostare più tab insieme (anche NON consecutive)**: nel pannello "Windows and Tabs" seleziona le tab che vuoi con **Ctrl+click** (singole, anche sparse) oppure **Shift+click** (intervallo). Poi fai **Maiusc+tasto destro su una delle tab selezionate**: il menu mostra "Sposta N tab nel Workspace" e sposta **solo le tab che hai scelto** (non quelle in mezzo), in un solo click. La selezione sullo schermo resta esattamente quella che hai fatto: Vivaldi di solito la allargherebbe a intervallo con Maiusc+tasto destro, la mod gli impedisce di farlo per quel gesto. Se invece fai Maiusc+tasto destro su una tab che non fa parte della selezione, sposta solo quella tab.

**Lingua del menu**: il menu esiste in **English** e **Italiano**. La lingua iniziale è quella scelta all'installazione (o, con Invio, quella rilevata dall'interfaccia di Vivaldi). Per cambiarla: **Maiusc + tasto destro** su una tab → l'**ultima riga** del menu dice `Lingua: English / Italiano ✓` (o `Language: English ✓ / Italiano`). Clicca una lingua per passare subito a quella (un clic altrove sulla riga passa all'altra). Cliccare la riga **non sposta nessuna tab** e **non cambia la selezione**. La scelta viene ricordata anche dopo aver chiuso e riaperto Vivaldi e dopo gli aggiornamenti di Vivaldi (il watcher non la tocca). **Precedenza**: la scelta fatta nel browser vale più di quella fatta all'installazione (che vale solo come lingua iniziale); reinstallare scegliendo una lingua *diversa* conta come nuova scelta e vale una volta.
Cosa succede dietro le quinte: i file del mod vengono copiati in `%LocalAppData%\VivaldiWSMod\`; il tag `<script>` viene iniettato in `window.html`; tutti gli shortcut Vivaldi trovati (Desktop/Start Menu, utente e tutti gli utenti) vengono riscritti per passare da un controllo automatico prima di aprire Vivaldi; inoltre parte un piccolo programma nascosto (il *watcher*) che si riavvia da solo a ogni login (voce `HKCU\...\Run`, **non servono diritti di amministratore**) e rimette la mod dopo ogni aggiornamento di Vivaldi.

## 2. Manutenzione (automatica, zero click)

Non devi fare nulla. Dopo ogni aggiornamento di Vivaldi la mod torna da sola, **senza reinstallare e senza riavviare Windows**:
- Il *watcher* (un piccolo programma nascosto, senza finestre né icone) resta in attesa. Quando l'aggiornatore di Vivaldi crea la nuova cartella versione, aspetta che `window.html` sia completo e che nessuno lo stia più scrivendo, poi rimette il tag `<script>`, il file `move-workspace-panel.js` e il suo piccolo file di configurazione della lingua (`move-workspace-panel.config.json`). Di solito succede **mentre l'aggiornamento è ancora in corso**, quindi già alla prima riapertura di Vivaldi la mod c'è.
- Costo: praticamente zero (nessun controllo continuo: si sveglia solo quando compare una cartella nuova, più un controllo di sicurezza ogni 30 minuti). Occupa circa 80 MB di memoria (misurati tra 73 e 91 MB).
- **Si auto-ripara**: il watcher parte *staccato* da qualunque programma (non si chiude se si chiude il programma che ha lanciato l'installer) e un'**attività pianificata** dell'utente (`VivaldiWSMod-Keepalive`, nessun amministratore, nessuna finestra) controlla all'accesso e ogni 30 minuti che sia acceso: se lo è non fa nulla (non avvia PowerShell), se non lo è lo riaccende e la mod viene riparata subito.
- Scrive in modo sicuro (file temporaneo + sostituzione, backup `window.html.bak`), non duplica mai il tag e lascia com'è la cartella della versione vecchia.
- Se qualcosa non funziona, c'è un piccolo log (si ruota da solo): `%LocalAppData%\VivaldiWSMod\logs\ws-mod.log`.
- In più, se apri Vivaldi da uno shortcut modificato dall'installer, `Watcher-Core.ps1` fa un controllo al volo prima dell'apertura (secondo canale).

**Da sapere**: il watcher gira solo mentre sei collegato a Windows con il tuo utente; se per qualche motivo non fosse attivo, rilanciare `Install.bat`/`Install.exe` lo riattiva (e ripara la versione corrente).

## Windows SmartScreen / antivirus, requisiti, limiti

- **SmartScreen**: gli `.exe` non sono firmati digitalmente, Windows può mostrare un avviso ("Windows ha protetto il PC"). Puoi usare `Install.bat`/`Uninstall.bat` (stessa cosa, testo leggibile) o leggere il sorgente in `exe-source\` (dalla v1.2.0 gli `.exe` sono lanciatori minuscoli, 5 KB, che avviano solo `Install-Mod.ps1`/`Uninstall-Mod.ps1`). SHA256 di `Install.exe`: `4622B661B69C4D9458B4CA5126ECDF997F0BA1F16A0D30EC8AC5697EA1BC591F`; di `Uninstall.exe`: `D246A2BFB55E3B2C9D59FD25D1BD7F839E76FCBFBBE2EF4D394B5C04BB833C96`. Lo SHA256 dello zip è nelle note della Release su GitHub.
- **Requisiti**: Windows con PowerShell 5.1 (incluso), nessun amministratore; Vivaldi Standalone/Portable o normale. Provato su Windows 11.
- **Non testato**: la rilevazione della lingua è stata verificata con Vivaldi in inglese e in italiano su un profilo di prova (l'impostazione esatta del tuo Vivaldi non è stata ispezionata); altre versioni di Vivaldi oltre 8.1.x/8.2.x, installazioni "normali" di recente e Windows 10. Il ripristino dopo un aggiornamento reale di Vivaldi è stato osservato dal vivo una volta (23/10/2026, 8.2.4133.89 → 8.2.4133.94, con la correzione della v1.2.1): è una sola osservazione, non una garanzia per ogni aggiornamento futuro.

## 3. Disinstallazione

1. Nella stessa cartella, doppio click su **Uninstall.bat** oppure **Uninstall.exe** (fanno la stessa cosa).
2. Inserisci lo stesso percorso della cartella Application usato in installazione.
3. Quando chiede `Continuare? (S/N)` (o `Continue? (Y/N)`), digita **S** (o **Y**) e premi Invio. (Se premi Invio al percorso viene usato quello registrato all'installazione.)
4. Attendi `=== Disinstallazione completata con successo ===`.
   - Se compare invece un avviso giallo su una cartella non completamente rimovibile: non è un errore bloccante. Il mod è già disinstallato e gli shortcut già ripristinati a quel punto; devi solo chiudere eventuali programmi che tengono occupata `%LocalAppData%\VivaldiWSMod` e cancellarla a mano.
5. Premi un tasto per chiudere la finestra.

Cosa succede dietro le quinte: `window.html` viene ripristinato all'originale, `move-workspace-panel.js` viene rimosso dall'installazione live, ogni shortcut modificato torna targetato/argomenti/icona originali, l'attività pianificata viene rimossa, il watcher viene fermato e la sua voce di avvio automatico rimossa, e la cartella `%LocalAppData%\VivaldiWSMod\` viene eliminata.

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
2. A black terminal window opens with **bilingual** questions. First it asks
   `Vivaldi "Application" folder path / Percorso cartella "Application" di Vivaldi (e.g. H:\Vivaldi Standalone\Application):`
   type (or paste) the path to your Vivaldi installation's **Application** folder and press Enter (a wrong path is reported and you can retry, up to 3 times).
   - Standalone/Portable install: `<drive>:\Vivaldi Standalone\Application` (e.g. `H:\Vivaldi Standalone\Application`)
   - Regular install: `C:\Users\<your-user>\AppData\Local\Vivaldi\Application`
   Then it asks the language: `Language / Lingua: 1) English  2) Italiano`. Type **1** or **2** and press Enter; **Enter alone = the language is detected automatically from Vivaldi's interface language** (English if it is not Italian). If the mod was already installed, the language you chose last time is proposed (Enter confirms it).
3. Wait for the green `=== Installation completed successfully ===` message (or `=== Installazione completata con successo ===` if you chose Italiano).
4. Press any key to close the window.
5. Done. Open Vivaldi from its usual shortcut (Desktop or Start Menu):
   - **Plain right-click** on a tab in the "Windows and Tabs" panel → Vivaldi's native menu, unchanged (New Tab, Duplicate, Pin, Close, etc.).
   - **Shift + right-click** on the same tab → the mod's **"Move to Workspace"** menu (**"Sposta nel Workspace"** in Italian).

**Moving multiple tabs at once (even NON-consecutive ones)**: in the "Windows and Tabs" panel pick the tabs you want with **Ctrl+click** (individual, even scattered) or **Shift+click** (range). Then **Shift+right-click on one of the selected tabs**: the menu shows "Move N tabs to Workspace" and moves **only the tabs you picked** (not the ones in between) in one click. The selection on screen stays exactly as you made it: Vivaldi would normally extend it to a range on Shift+right-click, and the mod stops it from doing so for that gesture. Shift+right-clicking a tab that is not part of the selection moves only that tab.

**Menu language**: the menu exists in **English** and **Italiano**. The initial language is the one chosen at install time (or, with Enter, the one detected from Vivaldi's interface language). To change it: **Shift+right-click** a tab → the **last row** of the menu reads `Language: English ✓ / Italiano` (or `Lingua: English / Italiano ✓`). Click a language to switch to it immediately (clicking elsewhere on the row switches to the other one). Clicking the row **does not move any tab** and **does not change the selection**. The choice is remembered after closing and reopening Vivaldi and after Vivaldi updates (the watcher never touches it). **Precedence**: the choice made in the browser wins over the one made at install time (which only sets the initial language); reinstalling and picking a *different* language counts as a new choice and applies once.
Under the hood: mod files are copied to `%LocalAppData%\VivaldiWSMod\`; the `<script>` tag is injected into `window.html`; every Vivaldi shortcut found (Desktop/Start Menu, current user and all users) is rewritten to run through an automatic check before Vivaldi opens; a small hidden program (the *watcher*) is also started, restarts itself at every login (`HKCU\...\Run` entry, **no administrator rights needed**) and puts the mod back after every Vivaldi update.

## 2. Maintenance (automatic, zero clicks)

Nothing to do. After every Vivaldi update the mod comes back by itself, **without reinstalling and without restarting Windows**:
- The *watcher* (a small hidden program, no windows or tray icon) waits quietly. When Vivaldi's updater creates the new version folder, it waits until `window.html` is complete and nobody is writing to it any more, then puts the `<script>` tag, `move-workspace-panel.js` and its small language-config file (`move-workspace-panel.config.json`) back. This usually happens **while the update is still running**, so the mod is already there the first time you reopen Vivaldi.
- Cost: practically zero (no continuous polling: it only wakes up when a new folder appears, plus a safety check every 30 minutes). It uses about 80 MB of memory (measured between 73 and 91 MB).
- **Self-healing**: the watcher starts *detached* from any program (it does not close when the program that launched the installer closes) and a per-user **scheduled task** (`VivaldiWSMod-Keepalive`, no administrator, no window) checks at login and every 30 minutes that it is running: if it is, it does nothing (no PowerShell is started); if it is not, it restarts it and the mod is repaired immediately.
- Writes are safe (temporary file + replace, `window.html.bak` backup), the tag is never duplicated, and the old version folder is left as is.
- If something does not work there is a small self-rotating log: `%LocalAppData%\VivaldiWSMod\logs\ws-mod.log`.
- In addition, if you open Vivaldi from a shortcut modified by the installer, `Watcher-Core.ps1` does an on-the-fly check just before it opens (second channel).

**Good to know**: the watcher only runs while you are logged in to Windows with your user; if for any reason it is not active, running `Install.bat`/`Install.exe` again restarts it (and repairs the current version).

## Windows SmartScreen / antivirus, requirements, limits

- **SmartScreen**: the `.exe` files are not code-signed, Windows may show a warning ("Windows protected your PC"). You can use `Install.bat`/`Uninstall.bat` (same thing, readable text) or read the source in `exe-source\` (since v1.2.0 the `.exe` files are tiny 5 KB thin launchers that only run `Install-Mod.ps1`/`Uninstall-Mod.ps1`). SHA256 of `Install.exe`: `4622B661B69C4D9458B4CA5126ECDF997F0BA1F16A0D30EC8AC5697EA1BC591F`; of `Uninstall.exe`: `D246A2BFB55E3B2C9D59FD25D1BD7F839E76FCBFBBE2EF4D394B5C04BB833C96`. The zip's SHA256 is in the Release notes on GitHub.
- **Requirements**: Windows with PowerShell 5.1 (built in), no administrator; Vivaldi Standalone/Portable or regular. Tested on Windows 11.
- **Not tested**: language detection was verified with Vivaldi in English and in Italian on a test profile (the exact setting of your own Vivaldi was not inspected); Vivaldi versions other than 8.1.x/8.2.x, "regular" installs recently, and Windows 10. Restore after a real Vivaldi update was observed live once (23/10/2026, 8.2.4133.89 → 8.2.4133.94, with the v1.2.1 fix): a single observation, not a guarantee for every future update.

## 3. Uninstallation

1. In the same folder, double-click **Uninstall.bat** or **Uninstall.exe** (identical).
2. Enter the same Application folder path used during installation.
3. When asked `Continue? (Y/N)` (or `Continuare? (S/N)`), type **Y** (or **S**) and press Enter. (Pressing Enter at the path prompt uses the one registered at install time.)
4. Wait for `=== Disinstallazione completata con successo ===`.
   - If a yellow warning appears instead about a folder that couldn't be fully removed: this is not a blocking error. The mod is already uninstalled and shortcuts already restored at that point; just close any program holding `%LocalAppData%\VivaldiWSMod` open and delete it manually.
5. Press any key to close the window.

Under the hood: `window.html` is restored to Vivaldi's original, `move-workspace-panel.js` is removed from the live install, every modified shortcut is restored to its original target/arguments/icon, the scheduled task is removed, the watcher is stopped and its autostart entry removed, and the `%LocalAppData%\VivaldiWSMod\` folder is deleted.
