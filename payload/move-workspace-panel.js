// ============================================================
// move-workspace-panel.js
// Aggiunge "Sposta nel Workspace" al context menu del pannello
// laterale "Windows and Tabs" di Vivaldi.
//
// Basato su ispezione diretta del DOM/React del pannello (8.1.4087.61):
//   - Ogni riga tab e' <div class="tree-item" data-id="<tabId numerico>">
//     dentro <div id="window-panel"> ... <div class="VivaldiList" role="tree">
//   - Ogni riga workspace (header di gruppo) e':
//     <div class="tree-item group" data-id="workspace-<workspaceId>">
//     con dentro <label class="window-entry ..." title="<Nome Workspace>">
//   - La lista e' "flat" (virtualizzata): niente nesting DOM reale, quindi
//     il workspace di appartenenza di una tab NON si deduce dagli antenati,
//     ma da chrome.tabs.get(tabId).vivExtData.workspaceId.
//
// Selezione multipla (v2, 19/08/2026 - rivisto v3 stesso giorno):
//   - Vivaldi supporta nativamente Ctrl+click / Shift+click sulle righe del
//     pannello per selezionare piu' tab prima di aprire un menu.
//   - v2 leggeva la selezione dall'attributo DOM `[data-selected]` (dedotto
//     da resources/vivaldi/style/common.css della versione installata,
//     8.1.4087.68). Test dal vivo dell'utente (19/08/2026): con piu' tab
//     selezionate, veniva spostata solo la tab cliccata - quell'attributo
//     non riflette la selezione multipla reale del pannello Tab (il pattern
//     nel CSS vale per altri alberi tipo bookmark/mail, non per le tab).
//   - v3: fonte primaria ora e' `chrome.tabs.query({highlighted:true,
//     currentWindow:true})` - la stessa API standard con cui Chrome/Vivaldi
//     rappresentano le tab multi-selezionate nella tab-strip, gia' usata con
//     successo altrove in questo script (chrome.tabs.get/update). La lettura
//     DOM `[data-selected]` resta come fallback secondario nel caso l'API
//     non restituisca nulla di utile. Confermato funzionante con test dal
//     vivo dell'utente (19/08/2026).
//   - Se la tab su cui si fa Shift+tasto-destro fa parte di una selezione
//     multipla rilevata, il menu "Sposta nel Workspace" agisce su TUTTE le
//     tab selezionate in un'unica operazione, invece che una sola. Se non
//     c'e' selezione multipla (o la tab cliccata non ne fa parte), il
//     comportamento resta quello originale: solo quella tab.
//
// Selezione NON consecutiva (RICHIESTA-003): Vivaldi estende a intervallo la
//   selezione sul Shift+tasto destro (come Shift+clic), quindi la selezione
//   "corrente" letta al contextmenu e' gia' sbagliata. La mod legge la
//   selezione dal DOM (aria-selected) in fase di capture al pointerdown /
//   mousedown Shift+destro, cioe' PRIMA che Vivaldi la estenda, e usa quella
//   (dettagli e dati reali piu' sotto). Nessun badge visibile: solo log [WS-mod].
//
// Convivenza con il menu nativo di Vivaldi (fix BUG-002, 13/08/2026):
//   - Tasto destro SEMPLICE su una tab: comportamento 100% nativo Vivaldi,
//     lo script non intercetta nulla (nessun preventDefault). Il menu
//     "New Tab, Duplicate, Pin, Close..." di Vivaldi appare invariato.
//   - MAIUSC (Shift) + tasto destro su una tab: apre il menu custom
//     "Sposta nel Workspace" al posto di quello nativo.
//   Motivo della scelta: non e' stato possibile ispezionare dal vivo la
//   struttura DOM del menu contestuale nativo di Vivaldi (i tool di
//   automazione non possono interagire dentro la finestra del browser),
//   quindi non si puo' garantire di poter iniettare una voce extra dentro
//   quel menu senza rischiare di romperlo. Usare un trigger diverso
//   (Shift+tasto destro) evita del tutto il problema: il menu nativo resta
//   sempre intatto, e la funzione del mod resta sempre disponibile con un
//   gesto leggermente diverso ma affidabile e a prova di aggiornamento.
// ============================================================
(function () {
  'use strict';

  // Guardia di sicurezza: questo script e' pensato per girare SOLO dentro
  // il contesto browser di Vivaldi (caricato da window.html). Se per
  // qualunque motivo venisse eseguito fuori da un browser (es. doppio
  // click accidentale sul file in Esplora File, che Windows aprirebbe di
  // default con Windows Script Host generando un popup di errore), esce
  // subito in silenzio invece di lanciare un'eccezione non gestita.
  if (typeof document === 'undefined' || typeof chrome === 'undefined' || typeof window === 'undefined') {
    return;
  }

  var PANEL_ROOT_SELECTOR = '#window-panel';
  var TAB_ROW_SELECTOR = '.tree-item[data-id]';
  var WORKSPACE_ROW_SELECTOR = '.tree-item.group[data-id^="workspace-"]';
  var SELECTED_ROW_SELECTOR = '.tree-row[data-selected]';

  // Nessun badge/overlay visibile (rimossi su richiesta): solo log in console.
  function log() {
    try {
      var args = ['[WS-mod]'].concat(Array.prototype.slice.call(arguments));
      console.log.apply(console, args);
    } catch (e) {}
  }

  // ----------------------------------------------------------------------
  // Selezione NON consecutiva (fix RICHIESTA-003).
  //
  // Dati reali (prova con Vivaldi 8.2.4133.91, 23/10/2026, vedi Bugtracker):
  //   - chrome.tabs.query({highlighted:true}) e chrome.tabs.onHighlighted NON
  //     rispecchiano la selezione del pannello "Windows and Tabs": restituisce
  //     sempre e solo la tab attiva, e onHighlighted non scatta mai.
  //   - La selezione del pannello esiste SOLO nel DOM: attributo
  //     aria-selected="true" sulle righe .tree-item[data-id].
  //   - Ctrl+clic aggiorna il DOM subito dopo il mousedown.
  //   - Shift+tasto destro allarga la selezione nel DOM a intervallo ~3 ms
  //     DOPO il mousedown (prima del contextmenu): al contextmenu la
  //     selezione e' gia' sbagliata.
  //   - Vivaldi allarga SEMPRE la selezione se Shift e' premuto al momento
  //     del mousedown destro (21 casi su 21 provati, qualunque ordine di
  //     Ctrl+clic, tab cliccata, pausa). Se invece Shift viene premuto DOPO
  //     il tasto destro, non allarga nulla (spiega perche' a volte "andava").
  // Quindi: (1) la selezione "vera" si legge dal DOM in fase di capture, nel
  // momento del pointerdown/mousedown Shift+destro; (2) quella pressione (e
  // solo quella) non viene fatta vedere a Vivaldi (stopImmediatePropagation
  // su window in capture), cosi' la selezione sullo schermo resta quella
  // scelta con Ctrl+clic. Una piccola cronologia di istantanee DOM
  // (MutationObserver) fa da rete di sicurezza.
  // ----------------------------------------------------------------------
  var MAX_SNAPSHOTS = 12;
  var GESTURE_STALE_MS = 2000;
  var SAME_PRESS_MS = 500;
  var snapshots = [];
  var seqCounter = 0;
  var gesture = null; // Shift+tasto destro in corso: {seq, ts, ids, timer, consumed}
  var lastDone = null; // ultimo gesto concluso: {pre: selezione originale, post: selezione DOM a gesto chiuso}

  function sameIds(a, b) {
    if (!a || !b || a.length !== b.length) return false;
    var s = a.slice().sort(function (x, y) { return x - y; });
    var t = b.slice().sort(function (x, y) { return x - y; });
    return s.every(function (v, i) { return v === t[i]; });
  }

  function nextSeq() { return ++seqCounter; }

  function addSnapshot(ids, source) {
    // Mentre un Shift+tasto destro e' in corso Vivaldi estende la selezione:
    // niente nuove istantanee fino alla chiusura del menu.
    if (gesture) return;
    snapshots.push({ seq: nextSeq(), ts: Date.now(), ids: ids.slice(), source: source });
    if (snapshots.length > MAX_SNAPSHOTS) snapshots.shift();
  }

  // Ultima istantanea con seq PRECEDENTE a beforeSeq (null se non c'e').
  function latestSnapshotBefore(beforeSeq) {
    var best = null;
    snapshots.forEach(function (s) {
      if (s.seq < beforeSeq && (!best || s.seq > best.seq)) best = s;
    });
    return best;
  }

  function isInPanel(target) {
    return (target instanceof Element) && !!target.closest(PANEL_ROOT_SELECTOR);
  }

  // Inizio di un Shift+tasto destro su una riga del pannello: fotografa la
  // selezione DOM adesso, prima che Vivaldi la estenda.
  function beginGesture(e) {
    if (e.button !== 2 || !e.shiftKey || !isInPanel(e.target)) return;
    // pointerdown e mousedown della stessa pressione: vale la prima lettura.
    if (gesture && !gesture.consumed && Date.now() - gesture.ts < SAME_PRESS_MS) return;
    var seq = nextSeq();
    if (gesture && gesture.timer) clearTimeout(gesture.timer);
    var domIds = getSelectedTabIdsFromDom();
    var snap = latestSnapshotBefore(seq);
    // Fonte primaria: DOM adesso. Se non mostra una selezione multipla,
    // l'ultima istantanea precedente.
    var ids = domIds.length > 1 ? domIds : (snap ? snap.ids : domIds);
    // Secondo Shift+destro senza cambiare selezione dopo il primo (es. menu
    // chiuso con Esc): il DOM mostra ancora l'intervallo allargato da Vivaldi
    // al primo gesto, quindi si riusa la selezione originale di quel gesto.
    if (lastDone && sameIds(domIds, lastDone.post) && lastDone.pre.length > 1) ids = lastDone.pre;
    gesture = { seq: seq, ts: Date.now(), ids: ids, consumed: false, timer: null };
    lastDone = null;
    // Se il contextmenu non arriva (gesto annullato), sblocca comunque.
    gesture.timer = setTimeout(function () {
      if (gesture && !gesture.consumed) gesture = null;
    }, GESTURE_STALE_MS);
    log('Shift+tasto destro: selezione prima del gesto =', JSON.stringify(ids), '(DOM ora', JSON.stringify(domIds) + ')');
  }

  // Riga tab (id numerico) del pannello sotto un target, o null.
  function tabRowOf(target) {
    if (!(target instanceof Element) || !target.closest(PANEL_ROOT_SELECTOR)) return null;
    var row = target.closest(TAB_ROW_SELECTOR);
    if (!row || !/^\d+$/.test(row.getAttribute('data-id') || '')) return null;
    return row;
  }

  // Blocco della pressione Shift+tasto destro (RICHIESTA-003, 2a parte).
  // Dati reali: e' il mousedown con Shift che fa allargare la selezione a
  // intervallo a Vivaldi (se Shift viene premuto DOPO il tasto destro, non la
  // allarga). Quindi, per la durata di QUESTA pressione, gli eventi del
  // tasto destro con Shift sulla riga di una tab non arrivano a Vivaldi:
  // la selezione sullo schermo resta quella scelta con Ctrl+clic.
  // Registrato su window in capture: il primo posto possibile.
  var blockedPress = null; // {ts} finche' dura la pressione bloccata
  var BLOCK_STALE_MS = 5000;

  function blockEvent(e) {
    e.stopImmediatePropagation();
    // Nessun preventDefault: il contextmenu lo gestisce il suo handler.
  }

  function onPressEvent(e) {
    try {
      var type = e.type;
      if (type === 'pointerdown' || type === 'mousedown') {
        if (blockedPress && e.button === 2 && e.shiftKey && Date.now() - blockedPress.ts < SAME_PRESS_MS) {
          // mousedown della stessa pressione di cui e' gia' passato il pointerdown
          blockEvent(e);
          return;
        }
        blockedPress = null; // una nuova pressione azzera quella precedente
        if (e.button === 2 && e.shiftKey && tabRowOf(e.target)) {
          beginGesture(e);
          blockedPress = { ts: Date.now() };
          blockEvent(e);
        }
        return;
      }
      // pointerup / mouseup / auxclick / click della stessa pressione
      if (blockedPress && e.button === 2) {
        if (Date.now() - blockedPress.ts > BLOCK_STALE_MS) { blockedPress = null; return; }
        blockEvent(e);
      }
    } catch (err) {
      console.error('[WS-mod] ' + e.type + ' errore:', err);
    }
  }

  function startSelectionTracking() {
    ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'auxclick', 'click'].forEach(function (type) {
      window.addEventListener(type, onPressEvent, true);
    });
    document.addEventListener('mousedown', function (e) {
      try {
        // Click altrove con il menu aperto: il gesto e' finito, si riparte.
        if (gesture && gesture.consumed && !(activeMenu && e.target instanceof Node && activeMenu.contains(e.target))) {
          if (gesture.timer) clearTimeout(gesture.timer);
          gesture = null;
        }
      } catch (err) {
        console.error('[WS-mod] mousedown handler errore:', err);
      }
    }, true);

    // Cronologia: ogni cambio di aria-selected/data-selected nel pannello
    // produce un'istantanea DOM (raggruppate per tick).
    try {
      var pending = false;
      new MutationObserver(function (muts) {
        if (gesture || pending) return;
        var relevant = muts.some(function (m) {
          return (m.target instanceof Element) && m.target.closest(PANEL_ROOT_SELECTOR);
        });
        if (!relevant) return;
        pending = true;
        setTimeout(function () {
          pending = false;
          if (!gesture) addSnapshot(getSelectedTabIdsFromDom(), 'dom-mutation');
        }, 0);
      }).observe(document.documentElement, {
        subtree: true, attributes: true, attributeFilter: ['aria-selected', 'data-selected']
      });
    } catch (e) {
      console.error('[WS-mod] MutationObserver non disponibile:', e);
    }
  }

  startSelectionTracking();

  log('ok');

  var activeMenu = null;

  // Rimuove il menu custom senza chiudere il gesto Shift+tasto destro in corso.
  function removeMenu() {
    if (activeMenu) {
      activeMenu.remove();
      activeMenu = null;
      document.removeEventListener('click', closeMenu, true);
      document.removeEventListener('keydown', onKeyDown, true);
      window.removeEventListener('scroll', closeMenu, true);
      window.removeEventListener('blur', closeMenu, true);
    }
  }

  // Chiusura vera del menu: il gesto e' finito, si riprende a registrare istantanee.
  function closeMenu() {
    removeMenu();
    if (gesture) {
      if (gesture.consumed && gesture.ids) lastDone = { pre: gesture.ids, post: getSelectedTabIdsFromDom() };
      if (gesture.timer) clearTimeout(gesture.timer);
      gesture = null;
    }
  }

  function onKeyDown(e) {
    if (e.key === 'Escape') closeMenu();
  }

  function getAllWorkspaces() {
    var rows = document.querySelectorAll(WORKSPACE_ROW_SELECTOR);
    var out = [];
    var seen = {};
    rows.forEach(function (row) {
      var raw = row.getAttribute('data-id') || '';
      var idStr = raw.replace(/^workspace-/, '');
      var idNum = Number(idStr);
      if (!idStr || isNaN(idNum) || seen[idStr]) return;
      var label = row.querySelector('label.window-entry');
      var name = (label && (label.getAttribute('title') || label.textContent || '').trim()) || ('Workspace ' + idStr);
      seen[idStr] = true;
      out.push({ id: idNum, name: name });
    });
    return out;
  }

  // Una riga tab e' "selezionata" se porta l'attributo data-selected
  // direttamente, oppure se lo porta il suo .tree-row annidato (i due
  // pattern osservati nel CSS nativo per pannelli diversi - vedi commento
  // in testa al file).
  // Dati reali (23/10/2026): Vivaldi 8.2 marca la selezione con
  // aria-selected="true" sul .tree-item.
  function isRowSelected(row) {
    return row.getAttribute('aria-selected') === 'true' || row.hasAttribute('data-selected') ||
      !!row.querySelector(SELECTED_ROW_SELECTOR);
  }

  // Fonte primaria della selezione: il DOM del pannello (l'API chrome.tabs
  // NON rispecchia la selezione del pannello - vedi RICHIESTA-003).
  function getSelectedTabIdsFromDom() {
    var panelRoot = document.querySelector(PANEL_ROOT_SELECTOR);
    if (!panelRoot) return [];
    var rows = panelRoot.querySelectorAll(TAB_ROW_SELECTOR);
    var out = [];
    rows.forEach(function (row) {
      var dataId = row.getAttribute('data-id') || '';
      if (!/^\d+$/.test(dataId)) return; // header di gruppo/workspace/finestra, non una tab
      if (!isRowSelected(row)) return;
      out.push(parseInt(dataId, 10));
    });
    return out;
  }

  // Fonte primaria: le tab "highlighted" secondo l'API chrome.tabs, lo
  // stesso stato che Vivaldi/Chromium usano per la multi-selezione nella
  // tab-strip. callback(idsArray) - array vuoto se l'API non e' disponibile
  // o fallisce, mai un'eccezione propagata al chiamante.
  function getSelectedTabIdsFromApi(callback) {
    try {
      if (!chrome.tabs || typeof chrome.tabs.query !== 'function') { callback([]); return; }
      chrome.tabs.query({ highlighted: true, currentWindow: true }, function (tabs) {
        if (chrome.runtime && chrome.runtime.lastError) {
          console.error('[WS-mod] tabs.query(highlighted) fallita:', chrome.runtime.lastError);
          callback([]);
          return;
        }
        var ids = (tabs || [])
          .map(function (t) { return t.id; })
          .filter(function (id) { return typeof id === 'number'; });
        callback(ids);
      });
    } catch (e) {
      console.error('[WS-mod] getSelectedTabIdsFromApi errore:', e);
      callback([]);
    }
  }

  function buildMenu(x, y, tabIds, currentWorkspaceId) {
    removeMenu();

    var workspaces = getAllWorkspaces();
    var count = tabIds.length;

    var menu = document.createElement('div');
    menu.style.cssText = 'position:fixed;z-index:2147483647;min-width:220px;max-width:320px;' +
      'max-height:70vh;overflow-y:auto;background:#2b2b2b;color:#e8e8e8;' +
      'font:12px/1.4 -apple-system,Segoe UI,Arial,sans-serif;border-radius:6px;' +
      'box-shadow:0 4px 18px rgba(0,0,0,0.45);padding:4px 0;border:1px solid #444;';

    var header = document.createElement('div');
    header.textContent = count > 1 ? ('Sposta ' + count + ' tab nel Workspace') : 'Sposta nel Workspace';
    header.style.cssText = 'padding:6px 14px;font-weight:600;color:#9ab6ff;' +
      'border-bottom:1px solid #444;margin-bottom:2px;white-space:nowrap;';
    menu.appendChild(header);

    if (!workspaces.length) {
      var empty = document.createElement('div');
      empty.textContent = 'Nessun workspace trovato';
      empty.style.cssText = 'padding:8px 14px;color:#999;font-style:italic;';
      menu.appendChild(empty);
    }

    workspaces.forEach(function (ws) {
      var item = document.createElement('div');
      var isCurrent = currentWorkspaceId != null && Number(currentWorkspaceId) === ws.id;
      item.textContent = (isCurrent ? '✓ ' : '    ') + ws.name;
      item.style.cssText = 'padding:6px 14px;cursor:pointer;white-space:nowrap;' +
        'overflow:hidden;text-overflow:ellipsis;' + (isCurrent ? 'color:#9ab6ff;' : '');
      item.addEventListener('mouseenter', function () { item.style.background = '#3d3d3d'; });
      item.addEventListener('mouseleave', function () { item.style.background = 'transparent'; });
      item.addEventListener('click', function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        moveTabsToWorkspace(tabIds, ws.id);
        closeMenu();
      });
      menu.appendChild(item);
    });

    document.body.appendChild(menu);

    // Posizionamento con clamp ai bordi dello schermo
    var rect = menu.getBoundingClientRect();
    var vw = window.innerWidth, vh = window.innerHeight;
    var finalX = Math.min(x, vw - rect.width - 4);
    var finalY = Math.min(y, vh - rect.height - 4);
    menu.style.left = Math.max(4, finalX) + 'px';
    menu.style.top = Math.max(4, finalY) + 'px';

    activeMenu = menu;

    setTimeout(function () {
      document.addEventListener('click', closeMenu, true);
      document.addEventListener('keydown', onKeyDown, true);
      window.addEventListener('scroll', closeMenu, true);
      window.addEventListener('blur', closeMenu, true);
    }, 0);
  }

  // Sposta tutte le tab in tabIds nel workspace indicato con un'unica
  // operazione logica (una chiamata chrome.tabs.update per tab, ma un
  // solo giro di menu/click per l'utente). Mostra un badge di riepilogo
  // solo a operazione completata (successo totale, o parziale con errori).
  function moveTabsToWorkspace(tabIds, workspaceId) {
    var total = tabIds.length;
    var done = 0;
    var errors = 0;

    function finish(isError) {
      if (isError) errors++;
      done++;
      if (done < total) return;
      if (errors === 0) {
        log(total + (total === 1 ? ' tab spostata' : ' tab spostate'));
      } else {
        console.error('[WS-mod] ' + (total - errors) + '/' + total + ' spostate (' + errors + ' errori)');
      }
    }

    tabIds.forEach(function (tabId) {
      try {
        chrome.tabs.get(tabId, function (tab) {
          if (chrome.runtime && chrome.runtime.lastError) {
            console.error('[WS-mod] get fallito per tab', tabId, ':', chrome.runtime.lastError);
            finish(true);
            return;
          }
          var extData = {};
          try {
            if (tab && tab.vivExtData) extData = JSON.parse(tab.vivExtData);
          } catch (e) { extData = {}; }
          extData.workspaceId = workspaceId;
          chrome.tabs.update(tabId, { vivExtData: JSON.stringify(extData) }, function () {
            finish(!!(chrome.runtime && chrome.runtime.lastError));
          });
        });
      } catch (e) {
        console.error('[WS-mod] moveTabsToWorkspace errore per tab', tabId, ':', e);
        finish(true);
      }
    });
  }

  // Determina il workspace "corrente" da mostrare con il segno di spunta
  // nel menu: se tutte le tab selezionate sono gia' nello stesso workspace,
  // e' quello; se sono sparse su workspace diversi, nessun segno di spunta
  // (ambiguo per definizione con selezione multipla mista).
  function getCommonWorkspaceId(tabIds, callback) {
    var results = new Array(tabIds.length);
    var remaining = tabIds.length;
    if (remaining === 0) { callback(null); return; }

    function finalize() {
      var first = results[0];
      var allSame = results.every(function (v) { return v === first; });
      callback(allSame ? first : null);
    }

    tabIds.forEach(function (tabId, idx) {
      try {
        chrome.tabs.get(tabId, function (tab) {
          var wsId = null;
          try {
            if (tab && tab.vivExtData) {
              var parsed = JSON.parse(tab.vivExtData);
              if (parsed && parsed.workspaceId != null) wsId = parsed.workspaceId;
            }
          } catch (e) {}
          results[idx] = wsId;
          remaining--;
          if (remaining === 0) finalize();
        });
      } catch (e) {
        results[idx] = null;
        remaining--;
        if (remaining === 0) finalize();
      }
    });
  }

  function getCurrentWorkspaceIdAndOpenMenu(tabIds, x, y) {
    try {
      getCommonWorkspaceId(tabIds, function (wsId) {
        buildMenu(x, y, tabIds, wsId);
      });
    } catch (e) {
      console.error('[WS-mod] getCurrentWorkspaceIdAndOpenMenu errore:', e);
      buildMenu(x, y, tabIds, null);
    }
  }

  // Su window in capture (il piu' presto possibile), come il blocco della pressione.
  window.addEventListener('contextmenu', function (event) {
    try {
      blockedPress = null;
      var target = event.target;
      if (!(target instanceof Element)) return;

      var panelRoot = target.closest(PANEL_ROOT_SELECTOR);
      if (!panelRoot) return; // non siamo nel pannello Windows and Tabs

      var tabRow = target.closest(TAB_ROW_SELECTOR);
      if (!tabRow) return;

      var dataId = tabRow.getAttribute('data-id') || '';
      if (!/^\d+$/.test(dataId)) return; // e' un header di gruppo/workspace/finestra, non una tab

      // Trigger custom SOLO con Shift+tasto destro. Tasto destro semplice
      // esce subito senza toccare l'evento: il menu nativo di Vivaldi
      // continua a funzionare esattamente come senza il mod installato.
      if (!event.shiftKey) return;

      // Blocco SINCRONO del menu nativo e di qualunque altro handler (React incluso)
      // solo per QUESTO caso (Shift+tasto destro su una riga tab).
      event.preventDefault();
      event.stopImmediatePropagation();

      var tabId = parseInt(dataId, 10);
      var clickX = event.clientX, clickY = event.clientY;

      // Fix RICHIESTA-003: se l'inizio di questo gesto e' stato visto,
      // usa la selezione letta PRIMA che Vivaldi la estendesse a intervallo.
      var g = gesture;
      if (g && !g.consumed && Date.now() - g.ts < GESTURE_STALE_MS * 5) {
        g.consumed = true;
        if (g.timer) { clearTimeout(g.timer); g.timer = null; }
        if (g.ids) {
          var snapIds = g.ids;
          var chosen = (snapIds.length > 1 && snapIds.indexOf(tabId) !== -1) ? snapIds : [tabId];
          log('menu su', chosen.length, 'tab (selezione', JSON.stringify(snapIds) + ', cliccata', tabId + ')');
          getCurrentWorkspaceIdAndOpenMenu(chosen, clickX, clickY);
          return;
        }
      }

      // Inizio del gesto non visto (es. mod caricata a meta' gesto): meglio
      // di niente, DOM poi API; se nessuna rileva una selezione multipla che
      // include la tab cliccata: solo quella tab.
      var domIds = getSelectedTabIdsFromDom();
      getSelectedTabIdsFromApi(function (apiIds) {
        var tabIds;
        if (domIds.length > 1 && domIds.indexOf(tabId) !== -1) {
          tabIds = domIds;
        } else if (apiIds.length > 1 && apiIds.indexOf(tabId) !== -1) {
          tabIds = apiIds;
        } else {
          tabIds = [tabId];
        }

        getCurrentWorkspaceIdAndOpenMenu(tabIds, clickX, clickY);
      });
    } catch (e) {
      console.error('[WS-mod] contextmenu handler errore:', e);
      gesture = null;
    }
  }, true); // capture:true - necessario solo per intercettare il caso Shift+destro

})();
