# Bugtracker — Vivaldi MOD "Sposta nel Workspace"

Ultimo aggiornamento: 26/08/2026 (EEST)

Stato legenda: Aperto (non iniziato) / In corso / Risolto e verificato

---

## BUG-001 — Errore PowerShell "-replace" durante l'installazione [RISOLTO E VERIFICATO]

**Priorita**: Alta (blocca l'installazione su Vivaldi aggiornato a versione nuova)

**Sintomo**: Install.bat termina con:
```
The -ireplace operator allows only two elements to follow it, not 3.
```
riprodotto su Vivaldi Standalone 8.1.4087.62.

**Causa** (verificata, letta nel codice): in Install-Mod.ps1 e in Watcher-Core.ps1, la riga
```powershell
$htmlContent -replace '</body>', ($ScriptTag + "`r`n</body>"), 1
```
passa 3 argomenti all'operatore -replace, che ne accetta solo 2 (pattern, sostituzione). Il ", 1" finale (limite occorrenze) non e' sintassi valida per questo operatore. Il bug era latente perche' il ramo di codice non veniva eseguito finche' il tag <script> risultava gia' presente; l'aggiornamento di Vivaldi a una nuova cartella-versione ha invalidato quella condizione e fatto emergere l'errore.

**Fix applicato** (13/08/2026): rimosso ", 1" in entrambi i file (in un window.html valido </body> compare una sola volta, quindi il limite non serve ed era la parte non valida della sintassi).

**Verifica eseguita**:
- Parser PowerShell reale (v7.4.6) su entrambi i file: nessun errore di sintassi.
- Test funzionale della riga corretta su un window.html di prova: il tag `<script>` viene iniettato esattamente una volta, struttura HTML integra.

**Limite della verifica**: il sandbox di Claude non ha accesso a Windows/`%LocalAppData%`/Vivaldi reale, quindi non e' stato possibile eseguire l'installer end-to-end sulla tua macchina. La correzione e' verificata a livello di codice e logica; la conferma definitiva avviene al primo lancio di Install.bat.

---

## BUG-002 — Il menu contestuale nativo di Vivaldi non e' piu' utilizzabile [RISOLTO E VERIFICATO — con cambio di approccio]

**Priorita**: Alta (regressione funzionale, non era il comportamento richiesto)

**Sintomo**: cliccando col tasto destro su una tab nel pannello "Windows and Tabs", il menu nativo di Vivaldi (New Tab, New Window, Duplicate, Pin, Rename, Close, ecc.) non compare piu': appare solo il menu custom "Sposta nel Workspace".

**Causa** (verificata, letta nel codice): move-workspace-panel.js intercetta l'evento in fase di capture con event.preventDefault(); event.stopImmediatePropagation();, bloccando del tutto il menu nativo invece di affiancarsi ad esso.

**Fix richiesto originariamente**: la voce "Sposta nel Workspace" doveva aggiungersi al menu nativo (es. come voce extra o submenu), non sostituirlo.

**Vincolo tecnico** (confermato, non aggirabile): gli strumenti di automazione di Claude non possono interagire dentro la finestra di Vivaldi (i browser sono ristretti a sola visualizzazione per policy). Senza poter ispezionare dal vivo la struttura del menu nativo, iniettare una voce al suo interno sarebbe stato un tentativo alla cieca, col rischio concreto di romperlo a un prossimo aggiornamento Vivaldi.

**Fix applicato (13/08/2026) — approccio alternativo**: invece di modificare il menu nativo, il trigger del menu custom e' stato cambiato.
- **Tasto destro semplice** su una tab: nessuna intercettazione, lo script non chiama piu' `preventDefault()`. Il menu nativo Vivaldi (New Tab, Duplicate, Pin, Close, ecc.) funziona esattamente come senza il mod.
- **Maiusc (Shift) + tasto destro** sulla stessa tab: apre il menu custom "Sposta nel Workspace".

Questo ottiene l'obiettivo richiesto — nativo e mod pienamente funzionanti entrambi — senza dover conoscere la struttura interna del menu nativo, quindi senza il click diagnostico manuale che sarebbe stato altrimenti necessario. Contropartita: il gesto per il mod e' Shift+tasto destro invece di comparire come voce dentro al menu nativo stesso.

**Verifica eseguita**: test funzionale automatico con mock DOM (7/7 casi superati) — tasto destro semplice non intercetta mai l'evento (su tab, su riga workspace, fuori dal pannello); Shift+tasto destro sulla riga tab intercetta correttamente e crea il menu; sintassi JS validata con `node --check`.

**Limite della verifica**: confermato che la logica e' corretta in isolamento; il test visivo reale nel pannello "Windows and Tabs" di Vivaldi va fatto da te al primo utilizzo (nessun click diagnostico extra necessario, e' lo stesso click che useresti normalmente).

**Guida utente aggiornata**: `Guida-Mod-Vivaldi-IT-EN.md` riflette il nuovo gesto Shift+tasto destro (sezioni IT e EN).

---

## RICHIESTA-001 — Pacchetto anche in formato .exe, oltre a .bat [RISOLTO E VERIFICATO — con cambio di tecnica]

**Priorita**: Media (preferenza utente, non blocca funzionalita)

**Richiesta**: avere Install.exe/Uninstall.exe **in aggiunta a** (non al posto di) Install.bat/Uninstall.bat.

**Tentativo iniziale fallito**: la soluzione originariamente proposta (modulo PowerShell `ps2exe`) non ha funzionato dal sandbox Linux di Claude — il modulo, anche eseguito con PowerShell 7, richiama internamente `powershell.exe` (Windows PowerShell classica) per la compilazione, che su Linux non esiste. Nessun file generato.

**Fix applicato (13/08/2026) — tecnica alternativa**: invece di ps2exe, `Install.exe` e `Uninstall.exe` sono stati compilati come veri programmi C#/.NET 8, "self-contained" per Windows x64 (nessuna installazione di .NET richiesta sul PC di destinazione). Fanno esattamente quello che fanno i file .bat corrispondenti: stessa domanda del percorso, stessa chiamata a `Install-Mod.ps1`/`Uninstall-Mod.ps1` (motori PowerShell, invariati — nessuna logica del mod duplicata o riscritta). Il sorgente C# e' incluso in `exe-source\` per eventuali ricompilazioni future.

**Verifica eseguita**: entrambi gli eseguibili controllati byte per byte — intestazione Windows valida (firma MZ/PE), architettura x86-64, tipo "console application per MS Windows" confermato con il comando `file`. Compilazione senza errori/warning.

**Limite della verifica**: il sandbox Linux non puo' eseguire un .exe Windows, quindi il doppio click reale (avvio, prompt del percorso, chiamata riuscita allo script) non e' stato testato dal vivo — solo la validita' strutturale del file. Da confermare al primo utilizzo su Windows.

**Nessun file rimosso**: Install.bat/Uninstall.bat restano nel pacchetto, invariati e funzionanti come prima; .exe e .bat sono due modi equivalenti di lanciare la stessa cosa.

---

## RICHIESTA-002 — Spostamento multiplo di tab in un'unica operazione [RISOLTO E VERIFICATO]

**Priorita**: Media (miglioramento funzionalita esistente, non blocca l'uso attuale)

**Richiesta**: poter selezionare piu' tab contemporaneamente (anche tutte) nel pannello "Windows and Tabs" e spostarle tutte insieme in un workspace scelto con un'unica azione "Sposta in workspace X", invece di ripetere lo spostamento una tab alla volta.

**Causa** (per design, non un bug): `move-workspace-panel.js` operava sempre su un singolo `tabId`, quello della riga su cui veniva fatto Shift+tasto destro — non leggeva mai lo stato di selezione multipla nativa del pannello.

**Verifica preliminare del DOM**: prima di implementare, ispezionato `resources/vivaldi/style/common.css` della versione Vivaldi realmente installata sulla macchina (8.1.4087.68, cartella `%LocalAppData%\Vivaldi\Application\8.1.4087.68\`) per confermare come Vivaldi marca le righe selezionate nel pannello, invece di indovinare alla cieca (stesso vincolo di BUG-002: i tool di automazione non possono interagire dentro la finestra di Vivaldi). Trovato: le righe selezionate portano l'attributo `[data-selected]` sull'elemento `.tree-row` annidato dentro `.tree-item` (pattern usato in modo identico e ripetuto in tutto il CSS del pannello "Windows and Tabs").

**Fix applicato (19/08/2026)**:
- Nuova funzione `getSelectedTabIds()` che legge tutte le righe `.tree-item[data-id]` del pannello e ne verifica lo stato selezionato (`[data-selected]` sulla riga stessa o sul suo `.tree-row` annidato — entrambi i pattern osservati nel CSS nativo, per pannelli diversi).
- All'apertura del menu (Shift+tasto destro), se la tab cliccata fa parte di una selezione multipla nativa attiva (>1 riga selezionata, inclusa quella cliccata), il menu opera su **tutte** le tab selezionate; altrimenti (nessuna selezione multipla, o click su una tab fuori dalla selezione corrente) si comporta come prima, solo sulla tab cliccata — nessuna regressione sul caso d'uso singolo.
- Intestazione del menu aggiornata dinamicamente: "Sposta nel Workspace" per una tab sola, "Sposta N tab nel Workspace" per selezione multipla.
- `moveTabToWorkspace()` (singolare) sostituita da `moveTabsToWorkspace(tabIds, workspaceId)`: itera su tutte le tab, spostandole tutte nel nuovo workspace, con un badge di riepilogo unico a operazione completata (successo totale, o parziale con conteggio errori) invece di un badge per tab.
- Il segno di spunta (✓) sul workspace corrente nel menu viene mostrato solo se **tutte** le tab selezionate condividono lo stesso workspace di partenza; con selezione mista su piu' workspace, nessun segno di spunta (ambiguo per definizione).

**Verifica eseguita**: test funzionale automatico con DOM reale via `jsdom` (piu' fedele del mock manuale usato per BUG-002, dato che qui serviva verificare selettori CSS reali) — 6/6 casi superati: tasto destro semplice non intercetta nulla; Shift+destro su tab singola non selezionata mostra menu singolare; Shift+destro su una tab dentro una selezione di 3 mostra "Sposta 3 tab nel Workspace"; Shift+destro su una tab fuori dalla selezione corrente ricade sul comportamento singolo; click sulla voce di workspace sposta correttamente tutte e 3 le tab selezionate in un solo giro. Sintassi validata con `node --check`.

**Limite della verifica**: la logica e' verificata in isolamento su DOM simulato (jsdom) costruito replicando fedelmente gli attributi/classi letti dal CSS reale installato, non sul pannello Vivaldi dal vivo (stesso vincolo di sempre: nessun accesso interattivo alla finestra del browser dal sandbox). La conferma finale del comportamento visivo (selezione con Ctrl/Shift+click seguita da Shift+tasto destro su piu' tab reali) va fatta da te al primo utilizzo.

**File coinvolti**: `payload\move-workspace-panel.js` (unico file modificato), `Guida-Mod-Vivaldi-IT-EN.md` (sezioni IT/EN aggiornate con la nuova procedura multi-tab).

---

## RICHIESTA-002-BIS — Il rilevamento della selezione multipla non funzionava dal vivo [RISOLTO E VERIFICATO — con cambio di tecnica]

**Priorita**: Alta (la funzionalita' di RICHIESTA-002 non produceva l'effetto atteso)

**Sintomo segnalato dall'utente (19/08/2026)**: selezionando piu' tab nel pannello e usando Shift+tasto destro → "Sposta in workspace X", veniva spostata solo la tab su cui si era fatto click, non l'intera selezione.

**Causa** (dedotta, non osservabile direttamente - vedi vincolo tecnico ricorrente in questo bugtracker): la v2 di RICHIESTA-002 rilevava la selezione multipla leggendo l'attributo DOM `[data-selected]`, dedotto dal CSS nativo di Vivaldi (`resources/vivaldi/style/common.css`) senza poter verificare dal vivo se quel pattern si applicasse davvero alle righe del pannello Tab. Il test reale dell'utente ha confermato che non e' cosi': quel pattern CSS riguarda altri alberi (bookmark/mail), non la selezione multipla di tab nella tab-strip, che in Chromium/Vivaldi e' rappresentata diversamente (stato "highlighted" per tab, esposto dall'API `chrome.tabs`).

**Fix applicato (19/08/2026, stesso giorno)** — cambio di tecnica di rilevamento:
- Fonte primaria ora e' `chrome.tabs.query({highlighted:true, currentWindow:true})`, la stessa API gia' usata con successo nel resto dello script (`chrome.tabs.get`/`update`) — niente piu' deduzioni sul DOM per la selezione.
- La lettura DOM `[data-selected]` resta solo come fallback secondario, nel caso l'API non restituisca risultati utili.
- Aggiunto un **badge diagnostico** visibile a schermo (in alto a sinistra, come il badge "WS-mod ok" gia' presente) ogni volta che si apre il menu con piu' di una tab coinvolta in una delle due fonti: mostra i conteggi "API:N DOM:M uso:K", cosi' un'eventuale ulteriore discrepanza e' visibile subito senza dover aprire la console del browser. Log dettagliato anche in console (`[WS-mod] selezione rilevata...`) per diagnosi piu' approfondite.
- I badge ora si impilano invece di sovrapporsi (piu' badge visibili contemporaneamente restano leggibili).

**Verifica eseguita**: suite di test funzionale automatico riscritta con DOM+API simulati via `jsdom` — 7/7 casi superati, inclusi: selezione rilevata SOLO dall'API con DOM "cieco" (il caso reale segnalato), fallback al DOM quando l'API non evidenzia nulla, click su tab fuori selezione (fallback a singola), spostamento reale di 15 tab in un click. Sintassi validata con `node --check`. Ridistribuito nella copia live via `Install-Mod.ps1`.

**Limite della verifica**: come sempre in questo progetto, il comportamento reale di `chrome.tabs.query({highlighted:true})` per la selezione del pannello Tab di Vivaldi non e' verificabile dal sandbox (nessun accesso interattivo alla finestra del browser). E' l'ipotesi piu' solida disponibile (API standard, stesso meccanismo gia' funzionante nello script per get/update), ma la conferma definitiva richiede il test dal vivo dell'utente. **Se il badge diagnostico mostra ancora "API:0" con una selezione multipla visibilmente attiva sullo schermo**, vuol dire che nemmeno l'API rispecchia quella selezione nel contesto di questo pannello: a quel punto serve che l'utente apra la console DevTools (F12, se abilitata per le pagine interne di Vivaldi) e riporti l'output di `[WS-mod] selezione rilevata...` per capire cosa succede davvero.

---

## RICHIESTA-002-TER — Le modifiche non arrivavano mai al Vivaldi realmente in uso [RISOLTO E VERIFICATO — errore di processo, non di codice]

**Priorita**: Alta (nessuna delle correzioni precedenti poteva funzionare, a prescindere da quanto fosse corretto il codice)

**Sintomo**: dopo RICHIESTA-002-BIS, l'utente conferma che il problema persiste ("purtroppo, no") e nota (giustamente) che l'intestazione del menu diceva "Sposta nel Workspace" anche con piu' tab selezionate visibilmente evidenziate in blu — segno che nessuna delle due fonti di rilevamento (API, DOM) trovava la selezione multipla, nemmeno con la nuova logica.

**Causa reale** (questa volta osservabile, non dedotta): interrogando i processi Windows realmente in esecuzione (`Get-CimInstance Win32_Process -Filter "Name='vivaldi.exe'"`), il Vivaldi che l'utente usa davvero e' l'installazione Standalone in **`H:\Vivaldi Standalone\Application\vivaldi.exe`** — non `C:\Users\<utente>\AppData\Local\Vivaldi\Application`, che e' un'installazione diversa (probabilmente creata da un aggiornamento automatico) mai usata dall'utente. In questa sessione, tutte le distribuzioni di RICHIESTA-002 e RICHIESTA-002-BIS erano state fatte con `Install-Mod.ps1 -VivaldiAppRoot "C:\Users\<utente>\AppData\Local\Vivaldi\Application"` (percorso trovato con una ricerca automatica a inizio sessione, mai confermato con l'utente) — quindi ogni redeploy aggiornava un'installazione che l'utente non apriva mai. Verificato con hash MD5: il file live in `H:\Vivaldi Standalone\Application\...\move-workspace-panel.js` era ancora quello originale del 13/08 (single-tab), invariato da tutta la sessione.

**Fix applicato (19/08/2026)**: ridistribuito con `-VivaldiAppRoot "H:\Vivaldi Standalone\Application"` (il percorso corretto, confermato dal processo realmente in esecuzione). Hash MD5 del file live ora identico al sorgente del progetto.

**Bug collaterale scoperto durante il redeploy sul percorso corretto**: il primo tentativo su `H:\Vivaldi Standalone\Application` e' fallito con `Index operation failed; the array index evaluated to null` durante la Fase 4 (riscrittura shortcut). Causa: `C:\Users\<utente>\AppData\Local\VivaldiWSMod\shortcuts-backup.json` (il manifest usato per la disinstallazione pulita) era gia' corrotto da prima di questa sessione, con una forma annidata anomala (`{"value":[...], "Count":N}` invece di un array piatto) che manda in errore il caricamento (`$e.ShortcutPath` su un oggetto che non ce l'ha). File riparato manualmente (5 voci, tutte recuperate e deduplicate dalla struttura corrotta, nessuna persa). `Install-Mod.ps1` reso auto-riparante per il futuro: il caricamento del manifest ora appiattisce e deduplica automaticamente qualunque struttura annidata di questo tipo, invece di andare in errore.

**Bug nel mio stesso fix**: il primo tentativo di correzione usava `New-Object System.Collections.Generic.List[object]` seguito da `@($listaGenerica)` per riconvertire in array — questa combinazione lancia `Argument types do not match` in questo ambiente PowerShell (riprodotto isolatamente). Sostituito con un array PowerShell semplice (`$flatEntries = @(); $flatEntries += $x`), lo stesso pattern gia' usato altrove nello stesso script — funziona correttamente.

**Verifica eseguita**: sintassi validata con il parser PowerShell (`[System.Management.Automation.Language.Parser]::ParseFile`); ri-eseguito `Install-Mod.ps1` sul percorso corretto fino a completamento pulito, nessun errore, manifest ricaricato senza il messaggio "illeggibile". Hash MD5 del file live confermato identico al sorgente.

**Lezione per le prossime sessioni**: non assumere MAI quale cartella "Application" sia quella realmente in uso solo perche' esiste sul disco - con piu' installazioni Vivaldi presenti (come in questo caso: AppData + Standalone su H:), va confermata interrogando i processi realmente in esecuzione (`Get-CimInstance Win32_Process -Filter "Name='vivaldi.exe'" | Select ExecutablePath`) o chiedendo esplicitamente all'utente, prima di eseguire `Install-Mod.ps1`.

**File coinvolti**: `Install-Mod.ps1` (fix manifest auto-riparante), `C:\Users\<utente>\AppData\Local\VivaldiWSMod\shortcuts-backup.json` (riparato manualmente, fuori dal repository del progetto).

**Conferma finale dall'utente (19/08/2026)**: dopo il redeploy sul percorso corretto, spostamento multiplo confermato funzionante ("Adesso funziona"). Diagnostica dello screenshot dell'utente confermata coerente con l'ipotesi v3: le righe realmente selezionate portano `aria-selected`/`data-selected`/`data-lead` sul `.tree-item` e classi `tree-row-selected` sul `.tree-row` figlio — l'API `chrome.tabs.query({highlighted:true})` si allinea correttamente a questo stato nel pannello Tab, come da fix v3.

**Pulizia post-fix**: rimossi dal payload sia l'overlay diagnostico grande (in alto a destra) sia il badge viola coi conteggi API/DOM, introdotti solo per la fase di debug — su richiesta esplicita dell'utente, che li trovava invasivi. Il fallback DOM resta nel codice come rete di sicurezza silenziosa (nessun output visibile), la fonte primaria via API e' quella confermata funzionante.

---

## RICHIESTA-003 — Tab NON consecutive: la selezione veniva estesa a intervallo [RISOLTA E VERIFICATA SU VIVALDI REALE (profilo di prova) — da installare/confermare da Michele]

### Causa reale e fix definitivo (23/10/2026) — questa sezione sostituisce le ipotesi qui sotto

Provato su un Vivaldi vero (8.2.4133.91, profilo temporaneo separato, collegamento DevTools, eventi mouse reali con Ctrl/Shift). Dati osservati:
- `chrome.tabs.query({highlighted:true})` **non rispecchia la selezione del pannello**: restituisce sempre e solo la tab attiva. `chrome.tabs.onHighlighted` **non scatta mai** per le selezioni del pannello. Quindi il fix a istantanee API (003) e la cattura API (003-BIS) non potevano funzionare: non vedevano mai nulla. (Le tab selezionate "bene" prima di 003 funzionavano grazie al fallback DOM.)
- La selezione del pannello esiste **solo nel DOM**: `aria-selected="true"` sulle righe `.tree-item[data-id]`.
- Ctrl+clic aggiorna il DOM ~3 ms dopo il mousedown. Shift+tasto destro allarga la selezione nel DOM a intervallo ~3 ms **dopo** il mousedown (prima di mouseup e contextmenu): al contextmenu e' gia' tutto sbagliato.
- Nei nostri listener in fase di capture (pointerdown/mousedown) il DOM e' ancora quello originale → leggibile in tempo.

**Fix**: `payload\move-workspace-panel.js` legge la selezione dal DOM in capture al pointerdown/mousedown con Shift+tasto destro (prima dell'estensione) e al contextmenu usa quella. Se la tab cliccata non fa parte della selezione (o la selezione e' di 1 tab) → solo la tab cliccata. Rete di sicurezza: piccola cronologia di istantanee DOM (MutationObserver) e ripristino della selezione originale se si fa un secondo Shift+tasto destro subito dopo un Esc (il DOM, nel frattempo, e' rimasto allargato). Rimossi: query/istantanee/onHighlighted via API (inutili), badge, **tutta la diagnostica DIAG** (003-BIS). Il gesto per Michele **non cambia** (Piano B Alt+tasto destro NON necessario; Guida invariata).

**Prove reali su Vivaldi (eventi mouse veri; spostamento verificato con `chrome.tabs.get`, workspace di destinazione)**: 8/8 OK —
- Ctrl+clic su 3 tab sparse + Shift+destro → "Sposta 3 tab", spostate esattamente quelle 3 (nel DOM la selezione sullo schermo e' stata allargata a 4-13 tab, ma e' stata ignorata);
- tab consecutive (Ctrl) → 3 tab; intervallo con Shift+clic → 4 tab;
- tab fuori selezione → solo quella (intestazione singolare); tab singola → come prima;
- 15 tab sparse (su 29) in un click → "Sposta 15 tab", spostate le 15;
- scelta di un altro workspace → ok;
- tasto destro semplice → nessun menu custom, evento non bloccato dalla mod (menu nativo intatto);
- due Shift+destro di fila con Esc in mezzo → entrambi "Sposta 3 tab".
Test jsdom aggiornati: 30/30. `node --check` OK.

**Deploy (23/10/2026)**: eseguito con Vivaldi chiuso su `H:\Vivaldi Standalone\Application` (8.2.4133.91). MD5 file live = sorgente = `E2707ECA357B2A2ABE8B04012D057627`; nessuna diagnostica nel file live. Finestra di prova chiusa.

**Limiti**: (1) la prova reale e' su un profilo di prova, con workspace/righe-destinazione simulate nel DOM (nel profilo di prova il pannello non mostrava le righe gruppo-workspace); la parte "selezione → intestazione → tab spostate" e' reale. (2) Se il pannello avesse centinaia di tab con righe fuori schermo non disegnate nel DOM, la lettura DOM potrebbe non vederle (non osservato con 45 tab). (3) Prova di Michele sul suo Vivaldi ancora da fare.

---

### Seconda parte (23/10/2026): la selezione sullo schermo NON deve piu' allargarsi

Michele non accettava che, pur spostando le tab giuste, sullo schermo la selezione si allargasse (3 → 13 tab). Michele aveva anche visto il comportamento corretto 3-4 volte di fila, poi piu' (15 minuti di prove).

**Indagine su Vivaldi reale (21 combinazioni, eventi mouse veri)**: Vivaldi ha allargato la selezione **21 volte su 21**, con qualunque ordine di Ctrl+clic, qualunque tab cliccata (prima/di mezzo/ultima/fuori selezione), pausa 30 ms–3 s, anche dopo Shift+clic precedente. L'ancora dell'intervallo e' la tab del clic semplice iniziale (il Ctrl+clic non la sposta); su quella tab la selezione collassa a 1 tab. L'allargamento avviene al **mousedown con Shift premuto** (~3 ms dopo, prima di mouseup/contextmenu).
**Spiegazione dell'intermittenza**: se Shift viene premuto **dopo** il tasto destro (tasto destro giu', poi Shift, poi rilascio) Vivaldi NON allarga nulla (provato: selezione intatta, menu "Sposta 3 tab"). Michele, a mano, non preme sempre Shift e mouse con la stessa tempistica: da qui le 3-4 volte "giuste".

**Fix**: `payload\move-workspace-panel.js` registra su **window in capture** (il primo posto possibile) i listener di pointerdown/mousedown/pointerup/mouseup/auxclick/click e il contextmenu. Per la sola pressione Shift+tasto destro su una riga tab del pannello: legge prima la selezione dal DOM, poi `stopImmediatePropagation` (nessun preventDefault) cosi' Vivaldi non vede ne' la pressione ne' il rilascio. Tasto destro senza Shift, clic normali, Ctrl+clic, Shift+clic: invariati. Non serve il Piano B (Alt+tasto destro). Verificato che nessun altro listener di Vivaldi in window/capture precede il nostro.

**Prove reali (Vivaldi di prova, eventi veri)**: stesse 21 combinazioni → **0 allargamenti su 21**; in piu' 9/9 prove E2E OK (3 tab sparse → "Sposta 3 tab", selezione sullo schermo identica a prima/dopo, tab spostate verificate con `chrome.tabs.get`; consecutive; Shift+clic intervallo; tab fuori selezione; singola; altro workspace; tasto destro semplice senza menu custom e non bloccato; 15 tab sparse su 29; due gesti di fila con Esc; Shift premuto dopo il destro). Test jsdom 33/33, `node --check` OK.

**Deploy (23/10/2026)**: installato con Vivaldi chiuso su `H:\Vivaldi Standalone\Application` (8.2.4133.91). MD5 file live = sorgente = `DA26CBCA1243C45635AE4120AFF82DE8`. Finestra di prova chiusa.

**Limite**: prova su profilo di prova (workspace di destinazione simulati nel DOM); manca la prova di Michele sul suo Vivaldi.

---

### Storico (ipotesi iniziali, ora superate)

**Priorita**: Alta

**Sintomo (Michele)**: Ctrl+clic su 3 tab sparse nel pannello "Windows and Tabs", poi Shift+tasto destro → il menu diceva "Sposta 7 tab nel Workspace" e spostava anche le tab intermedie. Doveva spostare solo le 3 scelte.

**Causa probabile (NON verificata dal vivo)**: in Vivaldi Shift+clic = selezione a intervallo; con Shift+tasto destro la selezione viene estesa prima che la mod la legga, quindi `chrome.tabs.query({highlighted:true})` restituisce gia' l'intervallo. Non si sa se l'estensione avvenga al mousedown o al contextmenu: la soluzione e' robusta a entrambi.

**Fix (`payload\move-workspace-panel.js`)**:
- Cronologia di istantanee (max 12) della selezione, prese PRIMA del gesto: da `chrome.tabs.onHighlighted` (se disponibile), da una query alla pressione di Shift e a ogni mousedown (subito e dopo 150 ms). Ordine garantito da un contatore monotono (oltre al timestamp).
- Il mousedown Shift+tasto destro e' registrato in fase di capture (appena caricato lo script): da quel momento la mod sceglie l'ultima istantanea precedente e smette di registrarne fino alla chiusura del menu (cosi' l'estensione di Vivaldi non "inquina" la cronologia). Query avviate prima del gesto ma concluse dopo vengono scartate.
- Se la tab cliccata e' nell'istantanea e questa ha piu' di 1 tab: si opera esattamente su quelle. Altrimenti: solo la tab cliccata. Se non esiste nessuna istantanea (mod caricata dopo la selezione): vecchio comportamento (API, poi fallback DOM silenzioso).
- Rimossi anche gli ultimi badge visibili ("WS-mod ok", "N tab spostate"): ora solo log in console con prefisso `[WS-mod]`. L'intestazione del menu ("Sposta N tab nel Workspace") resta la diagnostica: se N coincide con le tab scelte, funziona.

**Verifica**: `node --check` OK. Test jsdom con API chrome simulate (script in cartella temporanea, non nel repository): 37/37 superati — 9 casi x 4 varianti (Vivaldi estende al mousedown / al contextmenu; con e senza `onHighlighted`) piu' il caso senza cronologia. Casi: Ctrl+clic 1,4,7 + Shift+destro su 4 → "Sposta 3 tab", spostate solo 1,4,7; selezione consecutiva (Ctrl e Shift+clic); tab fuori selezione → solo quella; nessuna selezione multipla; 15 tab sparse in un click; tasto destro semplice non intercettato (menu nativo intatto); secondo Shift+destro dopo il primo; nuova selezione dopo il gesto.

**Limite della verifica**: nessun test dal vivo. Il comportamento reale di Vivaldi (quando estende la selezione, se `onHighlighted` e' disponibile nel contesto del pannello) e' simulato, non osservato. Se dal vivo non basta → PIANO B (non implementato): gesto alternativo (es. Alt+tasto destro, che Vivaldi non usa per l'intervallo); rischi: potrebbe essere gia' assegnato a altre azioni di Vivaldi/Windows, cambia l'uso e va aggiornata la guida. Si procede solo su via libera.

**Deploy**: eseguito con Vivaldi chiuso su `H:\Vivaldi Standalone\Application` (Vivaldi 8.2.4133.91, percorso confermato dal processo in esecuzione). MD5 del file live = sorgente = copia master = `7846A0C074E6B65A08686F306E92B791`. In attesa della prova dal vivo di Michele.

---

## RICHIESTA-003-BIS — Il fix di RICHIESTA-003 non funziona dal vivo [SUPERATA — causa trovata, vedi RICHIESTA-003; diagnostica RIMOSSA]

> Aggiornamento 23/10/2026: la diagnostica via appunti non e' servita (sostituita da un collegamento DevTools a un Vivaldi di prova). Il blocco DIAG e la cattura API sono stati **rimossi** dal payload. Resta di seguito il testo originale, solo come storico.

**Prova reale di Michele (23/10/2026)**: Ctrl+clic su 3 tab sparse, poi Shift+tasto destro sull'ultima. Risultato: la selezione sullo schermo e' stata allargata a 13 tab consecutive e il menu mostrava "Sposta nel Workspace" (singolare, con la spunta sul workspace corrente). Quindi il codice nuovo e' attivo, ma non ha trovato nessuna istantanea valida con piu' tab ed e' ricaduto sulla sola tab cliccata.

**Causa**: NON nota. Ipotesi aperte: (a) `onHighlighted` non scatta / non disponibile nel pannello; (b) il Ctrl+clic non genera nessun evento che fotografi la selezione; (c) Vivaldi allarga la selezione prima di ogni nostro evento; (d) la selezione del pannello non coincide con `chrome.tabs.query({highlighted:true})`; (e) altro.

**Cosa e' stato aggiunto (stesso deploy)**:
1. **Nuova cattura (cambio di logica, resta)**: dopo ogni `mouseup` e `click` nel pannello (solo se Shift NON premuto), dopo 0 ms e 50 ms, la mod legge la selezione (API, poi DOM) e la salva come istantanea se contiene piu' di 1 tab. Cosi' le selezioni fatte con Ctrl+clic vengono fotografate anche senza `onHighlighted`.
2. **Diagnostica TEMPORANEA (da rimuovere)**: blocco `// DIAG-START` ... `// DIAG-END` in `payload\move-workspace-panel.js` + poche righe marcate `// DIAG` + la riga `var diag = function () {};`. Registra (in memoria, ultima prova) mousedown/mouseup/click/contextmenu, tasti Shift/Ctrl/Esc, `onHighlighted` (o "NON DISPONIBILE"), mutazioni di `aria-selected`/`data-selected`/`tree-row-selected`, e dopo ogni evento nel pannello, a 0/50/200 ms, la selezione secondo API, DOM e le istantanee salvate. All'apertura del menu (e dopo 300 ms, e alla chiusura con Esc/click) il registro viene copiato negli appunti (poi `execCommand`, poi `console.log [WS-mod-DIAG]`). Si azzera alla chiusura del menu. Nessun badge/overlay.

> ⚠️ **DA RIMUOVERE a fix confermato**: il blocco DIAG e le righe `// DIAG`. Non lasciarlo nella versione finale.

**Verifica (simulata)**: `node --check` OK; suite jsdom 44/44 (le 37 precedenti + cattura senza `onHighlighted`, registro DIAG riempito e copiato, fallback appunti, azzeramento dopo Esc, nessun badge). Controllo di sensatezza: disattivando la nuova cattura, i test dedicati falliscono.

**Deploy (23/10/2026)**: eseguito con Vivaldi chiuso su `H:\Vivaldi Standalone\Application` (8.2.4133.91). MD5 file live = sorgente = `8BB4FFB7A0A7301A2C6A34CA66EF93B3`.

**Limite**: nessun test dal vivo; il vero comportamento di Vivaldi resta da capire dal registro che Michele incollera' in chat. Se emerge che nemmeno cosi' basta → PIANO B (gesto alternativo, es. Alt+tasto destro), solo su via libera.

---

## RICHIESTA-004 — Reinstallazione automatica della mod dopo gli aggiornamenti di Vivaldi [IMPLEMENTATA E VERIFICATA SU COPIA DI PROVA — in attesa di deploy e del prossimo aggiornamento reale]

### Causa reale (diagnosi in sola lettura, 23/10/2026)
Il ripristino "automatico" descritto in precedenza **non poteva scattare**, per due motivi indipendenti:
1. **Nessun innesco attivo.** `Watcher-Core.ps1` partiva SOLO se Vivaldi veniva aperto da uno shortcut modificato da `Install-Mod.ps1` (tramite `Vivaldi-Launch.vbs`). Sul PC di Michele: nessuno shortcut e' mai stato modificato (il manifest `shortcuts-backup.json` non esiste; gli shortcut sul Desktop non sono collegamenti diretti a Vivaldi), nessuna attivita' pianificata, nessuna voce di avvio, nessun processo del watcher, e **il file di log del watcher non e' mai stato creato** (= non e' mai girato).
2. **L'aggiornatore non passa dagli shortcut.** Dal log reale `%TEMP%\vivaldi_installer.log` la sequenza dell'ultimo aggiornamento (22/10/2026, 8.2.4133.89 → .91) e': `setup.exe` (da `%TEMP%\VivaldiUpdate-...`) con `--vivaldi-install-dir="H:\Vivaldi Standalone" --vivaldi-standalone` alle 22:00:50 → crea la **nuova cartella versione** con il `window.html` pulito (cartella creata 22:00:43, `Installer\setup.exe` e `vivaldi.7z` 22:00:32-33) → circa 11 minuti dopo (22:11:54) sostituisce `vivaldi.exe` (il vecchio finisce in `Temp\...\old_vivaldi.exe`) e rilancia `Installer\setup.exe --delete-old-versions`, che cancella la cartella versione vecchia (22:12:10). Vivaldi viene riavviato direttamente dall'aggiornatore: nessuno shortcut coinvolto. Stesso schema il 14/10 e il 17/10 (aggiornamenti ogni 2-5 giorni: .84 → .87 → .89 → .91).
Conferme: in `Application\` c'e' ora solo `8.2.4133.91` (la vecchia e' stata cancellata); la mod nella nuova cartella e' comparsa solo perche' reinstallata a mano alle 22:43.
**INCERTO** (non verificabile senza un aggiornamento reale osservato): chi/come lancia esattamente il riavvio finale (`vivaldi.exe` direttamente dopo lo swap, presumibile ma non osservato); se l'aggiornatore riscriva `window.html` dopo averlo creato (il watcher comunque verifica per 20 minuti).

### Soluzione implementata
Un piccolo **watcher in background** (`payload\Watcher-Daemon.ps1`, copiato in `%LocalAppData%\VivaldiWSMod\scripts\`):
- Guidato da eventi: un `FileSystemWatcher` sulla cartella `Application` (solo creazione/rinomina di cartelle) segnala la nuova cartella versione. Poi, per 20 minuti, ogni 5 secondi controlla se `window.html` esiste, non e' vuoto, non e' piu' modificato da 4 s e si apre in esclusiva (= l'aggiornatore ha finito); appena stabile ci mette il tag. Poi continua a verificare fino a fine finestra (se l'aggiornatore lo riscrive, viene rimesso). A riposo si sveglia solo ogni 30 minuti (controllo di sicurezza: copre watcher avviato dopo l'aggiornamento o unita' non pronta al login).
- Poiche' la cartella nuova compare ~11 minuti PRIMA del riavvio, la mod e' normalmente gia' presente **alla prima riapertura** di Vivaldi dopo l'aggiornamento. (Dato dal log reale; se l'aggiornatore si comportasse diversamente, al massimo sara' pronta entro ~1 minuto dalla fine della scrittura, o al peggio entro 30 minuti: vedi limiti.)
- Parte al login con la voce `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` ("VivaldiWSMod" → `wscript //B Start-Daemon.vbs`, nessuna finestra) e subito dopo l'installazione. **Nessun diritto di amministratore.** Non dipende dagli shortcut. Un solo watcher (mutex).
- Sicuro: scrive `window.html` su file temporaneo, verifica, poi sostituzione atomica (`File.Replace`); backup `window.html.bak` creato una sola volta dal file pulito; JS copiato prima del tag; mai duplica il tag; codifica/BOM preservati; tocca solo la cartella versione piu' recente (la vecchia resta com'e').
- Log breve con rotazione (100 KB + 1 file precedente): `%LocalAppData%\VivaldiWSMod\logs\ws-mod.log`. Scrive solo eventi (avvio, nuova cartella, ripristino, errori), niente a riposo.
- `Install-Mod.ps1`: copia i nuovi file, registra l'installazione in `roots.json`, imposta la voce Run, (ri)avvia il watcher; la parte di ripristino usa la stessa funzione del watcher (`Mod-Common.ps1`). `Uninstall-Mod.ps1`: ferma il watcher, toglie la voce Run, ripulisce TUTTE le cartelle versione e le installazioni di `roots.json`. Parser `Install.bat/.exe`/`Uninstall.bat/.exe` invariati (chiamano gli stessi script). Riparatore automatico del manifest shortcut mantenuto. `Watcher-Core.ps1` resta come secondo canale (shortcut) e ora usa le stesse funzioni.
- Costo misurato (copia di prova, PowerShell 5.1): CPU a riposo **~0,003%** (60 s, su 16 core), durante un aggiornamento simulato **~0,04%**; memoria privata **~72-76 MB** (working set ~93 MB), 12 thread, priorita' bassa. E' il costo base di un processo PowerShell.
- Alternative scartate: (a) attivita' pianificata all'accesso: non basta (l'aggiornamento non riavvia ne' richiede un nuovo login); (b) attivita' pianificata periodica (es. ogni minuto): riparerebbe ma con un processo che parte 1440 volte al giorno; (c) wrapper/shortcut: gia' dimostrato inefficace (l'aggiornatore non li usa); (d) programma nativo .exe sempre attivo: memoria minore (~5 MB) ma richiede ricompilare/firmare un exe nuovo (vietato toccare `exe-source\`).

### Prove (copia di prova in cartella temporanea; nessuna modifica a Vivaldi reale, ne' a Windows)
28/30 + 2 falsi errori del mio script di prova (conteggio di un elenco di un solo elemento), verificati a parte (3 avvii del watcher → 1 solo processo): tutto OK —
Install su copia (tag una volta, JS identico, .bak = originale, nessun BOM aggiunto) e reinstallazione idempotente (file non riscritto); aggiornamento simulato con cartella nuova e `window.html` scritto a quattro riprese e **bloccato** per ~11 s: nessuna modifica finche' era in scrittura, mod rimessa 2,5 s dopo la chiusura del file, tag una volta, .bak = pulito, file valido, nessun temporaneo, cartella vecchia intatta; `window.html` gia' con il tag: non riscritto; due cartelle versione nuove insieme: solo la piu' recente; file incompleto (senza `</body>`): non toccato, poi riparato dopo il completamento; watcher avviato DOPO l'aggiornamento: ripara subito all'avvio; watcher doppio: un solo processo; Uninstall: watcher fermato, tutte le cartelle ripulite, `window.html` identico all'originale, cartella mod rimossa. Parser PowerShell: 0 errori su tutti gli script. **Bug trovato e corretto durante le prove**: `File.Replace` con `$null` come backup falliva ("path not of a legal form"), ora `[NullString]::Value`.

### Deploy (23/10/2026)
Eseguito con Vivaldi chiuso su `H:\Vivaldi Standalone\Application` (8.2.4133.91). Verificato: JS live, `Mod-Common.ps1`, `Watcher-Daemon.ps1`, `Watcher-Core.ps1`, `Start-Daemon.vbs`, `Vivaldi-Launch.vbs` identici ai sorgenti (MD5); tag in `window.html` una sola volta; `roots.json` con il percorso; voce `HKCU\...\Run\VivaldiWSMod` presente; 1 solo watcher attivo (nascosto, ~73 MB), log con "Watcher avviato / Sorveglianza attiva". Piccolo bug trovato al deploy: il messaggio finale di `Install-Mod.ps1` diceva "watcher non partito" anche se era partito (un elenco di un solo elemento non veniva contato): corretto con `@(...)` e reinstallato.

### Verifica "due powershell.exe nel Task Manager" (23/10/2026, sola lettura) — NESSUN DUPLICATO
- Processi powershell.exe trovati: **PID 300** = watcher della mod (avviato 04:09:13, `...\VivaldiWSMod\scripts\Watcher-Daemon.ps1`, nascosto); **PID 37392** = terminale integrato di Claude Desktop (avviato 02:27, padre `Claude.exe`, NON della mod); PID 16636 = la shell di questa sessione di lavoro (transitoria). Nessun altro script di Michele era in esecuzione al momento del controllo.
- Un solo watcher della mod. Il log mostra due "Watcher avviato" (04:08:52 PID 36140 e 04:09:13 PID 300): il secondo e' la reinstallazione che ha fermato il primo e ne ha avviato uno nuovo, come previsto. Task Manager mostra circa 33-38 MB perche' conta la memoria "attiva privata"; la memoria privata totale misurata e' ~73 MB.
- Punti di avvio: una sola voce `HKCU\...\Run\VivaldiWSMod` (→ `Start-Daemon.vbs` in `%LocalAppData%\VivaldiWSMod\scripts\`), nessuna attivita' pianificata, nessun file nella cartella Startup collegato alla mod.
- Istanza unica: il watcher usa un Mutex con nome fisso derivato dal percorso della cartella mod (`Local\VivaldiWSMod-Daemon-<hash>`). Prova in cartella temporanea: due avvii → il secondo termina subito, resta 1 processo. Il watcher reale non e' stato toccato.
- Consumo del watcher reale (60 s, sola lettura): CPU media 0,005% (su 16 core), memoria privata 72,6 MB, working set 93,1 MB.
- Nessuna correzione necessaria.

### Limiti (non verificabili senza un vero aggiornamento di Vivaldi)
Tempi reali di creazione/riscrittura di `window.html` da parte dell'aggiornatore e il momento esatto del riavvio (INCERTO, vedi sopra); la prova definitiva sara' il prossimo aggiornamento reale. Il watcher gira solo mentre l'utente e' collegato; se il PC e' spento durante l'aggiornamento, al login successivo ripara comunque (controllo all'avvio).
**Cosa osservare dopo il prossimo aggiornamento**: aprire Vivaldi → la mod funziona (Shift+tasto destro mostra il menu "Sposta..."). Se no: aprire `%LocalAppData%\VivaldiWSMod\logs\ws-mod.log` (poche righe): dovrebbe contenere "Nuova voce in ...", "RIPRISTINO versione ..." con l'orario; eventuali errori sono marcati "ERRORE". Se il log non esiste o non ha nulla di recente, il watcher non era attivo: rilanciare `Install.exe`.

---
## RICHIESTA-005 — Installer che trova da solo il percorso di Vivaldi [CONGELATA — non iniziare]

Oggi l'installer chiede il percorso. Idea: trovarlo in automatico. Eventuale opzione secondaria, non prioritaria. Attenzione alla lezione di RICHIESTA-002-TER: con piu' installazioni Vivaldi sul PC non va mai assunto il percorso.

---

## RICHIESTA-006 — Etichette del menu in inglese o nella lingua di Vivaldi [APERTA — NON iniziata]

Il menu della mod usa etichette fisse in italiano ("Sposta nel Workspace", "Sposta N tab nel Workspace", "Nessun workspace trovato"). Per un pubblico internazionale servirebbero etichette in inglese oppure nella lingua dell'interfaccia di Vivaldi (da rilevare, ad es. dalla lingua del browser). Dichiarato come limite nel README. Anche i messaggi di `Install-Mod.ps1`/`Uninstall-Mod.ps1` e dei `.exe` sono in italiano. Non toccare il codice finche' non viene avviata questa richiesta.

---
## Stato al 13/08/2026

Tutti e tre i punti risolti e verificati, entro i limiti del sandbox (vedi note in ciascuna sezione). BUG-001 e BUG-002 confermati funzionanti dal vivo dall'utente. RICHIESTA-001 verificata solo a livello di struttura del file (nessun accesso a Windows dal sandbox per il test a doppio click).

## Stato al 19/08/2026

RICHIESTA-002 (spostamento multiplo di tab) implementata, e dopo due falsi negativi (RICHIESTA-002-BIS, RICHIESTA-002-TER — vedi sopra) **confermata funzionante dal vivo dall'utente** ("Funziona"). Nessun problema aperto al momento. Diagnostica di debug rimossa dal payload finale, su richiesta dell'utente.

**Prossimo passo per te**: nessuno per ora. Se in futuro Vivaldi si aggiorna in un modo che rompe il mod di nuovo, la manutenzione automatica (`Watcher-Core.ps1`) dovrebbe ripristinarlo da sola al lancio; altrimenti rilancia `Install.exe`/`Install.bat` — ma **assicurati che chi lo rilancia sappia qual e' l'installazione Vivaldi giusta**, vedi nota critica sotto.

## Stato al 26/08/2026

Nessuna modifica al codice del mod in questa sessione (payload/*.js, *.ps1, exe-source invariati). L'attivita' di oggi ha riguardato esclusivamente la pubblicazione e la promozione del progetto, non lo sviluppo:

- **Repository pubblicato su GitHub** (pubblico): https://github.com/<utente>83/Workspace-Move-MOD-for-Vivaldi-Standalone-Installed -- commit iniziale (19 file, inclusi i due .exe da ~35MB ciascuno) + commit README, push completati con successo.
- **Canali di promozione individuati e usati**: forum ufficiale Vivaldi (categoria Modifications) e Discord community Vivaldi (non ufficiale) -- post pubblicati su entrambi. Reddit r/vivaldibrowser: richiesta di permesso inviata ai moderatori via modmail (il subreddit vieta l'auto-promozione senza contatto preventivo, regola 5), pubblicazione del post sospesa in attesa di risposta.
- Nessun problema aperto sul mod stesso.

Dettaglio completo delle attivita' di oggi, inclusi gli intoppi tecnici incontrati durante la pubblicazione (estranei al codice del mod, riguardano solo il processo di autenticazione GitHub), in `Storico Sessione Share del Progetto Vivaldi MOD.md`.

---

## Stato al 23/10/2026

- **RICHIESTA-003** (tab non consecutive): risolta e verificata su un Vivaldi reale di prova; la selezione resta quella scelta con Ctrl+clic e vengono spostate solo quelle tab. **RICHIESTA-004** (ripristino automatico dopo gli aggiornamenti): implementata (watcher unico, nascosto, avvio al login) e verificata su copia di prova; manca l'osservazione di un aggiornamento reale di Vivaldi. RICHIESTA-005 resta congelata.
- **Repository pubblico ripulito e aggiornato** (rinominato in `vivaldi-workspace-tab-mover`; il vecchio indirizzo viene reindirizzato da GitHub; README con l'inglese per primo, immagini in `assets/`): rimossi dal repository l'esportazione di una chat privata, `CLAUDE.md` e il log interno di promozione (restano solo sul disco locale, ignorati da `.gitignore`); percorsi e username personali sostituiti da segnaposto (`C:\Users\<utente>\...`); cronologia sostituita da un unico commit pulito (force-push); aggiunti LICENSE (MIT), README e Guida aggiornati, descrizione e tag del repository, Discussions. **Release v1.1.0** pubblicata (zip con installer, script, payload, guida e SHA256 nelle note).
- **Limiti noti**: (1) gli `.exe` non sono firmati: Windows SmartScreen o l'antivirus possono mostrare un avviso (alternativa: `Install.bat`/`Uninstall.bat`, stessa funzione); (2) i vecchi commit (con i file rimossi) possono restare raggiungibili tramite il loro codice SHA finche' GitHub non li elimina; per accelerare si puo' chiedere la rimozione a GitHub Support (https://support.github.com/contact) citando il repository e gli hash dei vecchi commit; (3) il nome "Michele" (nome proprio, gia' presente come autore dei vecchi commit) resta nei documenti.

---
## Percorsi coinvolti

**⚠️ CRITICO — leggere prima di rilanciare Install-Mod.ps1/Install.exe in una sessione futura**: sul PC di Michele esistono **due installazioni Vivaldi distinte**:
- `H:\Vivaldi Standalone\Application\` — **questa e' quella realmente in uso** (confermato interrogando i processi Windows in esecuzione il 19/08/2026, ed e' quella su cui il mod e' stato verificato funzionante dal vivo).
- `C:\Users\<utente>\AppData\Local\Vivaldi\Application\` — installazione diversa (probabilmente creata da un aggiornamento automatico di Vivaldi), **non usata da Michele**. Anche questa ha il mod installato (da questa sessione, per errore iniziale — vedi RICHIESTA-002-TER), ma aggiornarla NON ha alcun effetto sul Vivaldi che Michele apre davvero.

Prima di eseguire `Install-Mod.ps1 -VivaldiAppRoot ...` in una sessione futura, **non assumere il percorso** (es. trovandone uno con una ricerca automatica) — confermalo con `Get-CimInstance Win32_Process -Filter "Name='vivaldi.exe'" | Select-Object ExecutablePath` (se Vivaldi e' aperto) o chiedendo direttamente a Michele. Questo errore ha causato tre round di correzioni apparentemente inefficaci in questa sessione (RICHIESTA-002/BIS/TER), quando il codice era gia' corretto dal primo tentativo.

- <cartella-del-progetto>\Install-Mod.ps1
- <cartella-del-progetto>\payload\Watcher-Core.ps1
- <cartella-del-progetto>\payload\move-workspace-panel.js
- <cartella-del-progetto>\Guida-Mod-Vivaldi-IT-EN.md
- <cartella-del-progetto>\Install.exe
- <cartella-del-progetto>\Uninstall.exe
- <cartella-del-progetto>\exe-source\ (sorgente C# per ricompilare Install.exe/Uninstall.exe se mai servisse — non toccato in questa sessione, non serve toccarlo per modifiche solo al payload/.ps1)
- %LocalAppData%\VivaldiWSMod\ (copia "master" distribuita da Install-Mod.ps1, comune a tutte le installazioni Vivaldi sul PC; da qui parte ogni redeploy verso la cartella resources\vivaldi\ dell'installazione target)
- %LocalAppData%\VivaldiWSMod\shortcuts-backup.json (manifest per la disinstallazione pulita; riparato il 19/08/2026 dopo una corruzione pregressa, e Install-Mod.ps1 ora si autoripara se ricapita — vedi RICHIESTA-002-TER)

**Nota**: le versioni precedenti di questo bugtracker riportavano i percorsi sorgente come `C:\Users\<utente>\Desktop\Vivaldi MOD for Workspace\...`. I file su cui si lavora sono quelli nella cartella collegata `<cartella-del-progetto>\`. Se sul Desktop esiste ancora una copia separata in `C:\Users\<utente>\Desktop\Vivaldi MOD for Workspace\`, quella copia non è collegata a questo progetto.
