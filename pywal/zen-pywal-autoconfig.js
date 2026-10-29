// zen-pywal live theme watcher (autoconfig). Installed into Zen's app dir by
// ~/scripts/system/zen-pywal-autoconfig-install.sh — do not edit the installed copy,
// edit this one and re-run the installer.
//
// Why this exists: userChrome.css is only read at browser STARTUP, so a pywal palette
// change would otherwise not reach a running Zen until its next launch. This runs
// privileged at startup, polls the profile's chrome/zen-pywal.css (rewritten by
// zen-pywal.py on every wallpaper change) and re-registers it as a user stylesheet
// when it changes, so the chrome re-themes live like the rest of the rice.
//
// NOTE: Firefox/Zen ALWAYS ignores the first line of an autoconfig file — the comment
// block above keeps real code off line 1.
(function () {
  const { classes: Cc, interfaces: Ci, utils: Cu } = Components;

  const POLL_MS = 1500;
  let sheetURI = null;
  let lastStamp = -1;

  function cssFile() {
    const f = Services.dirsvc.get("ProfD", Ci.nsIFile).clone();
    f.append("chrome");
    f.append("zen-pywal.css");
    return f;
  }

  function readText(file) {
    const fstream = Cc["@mozilla.org/network/file-input-stream;1"].createInstance(
      Ci.nsIFileInputStream
    );
    const cstream = Cc["@mozilla.org/intl/converter-input-stream;1"].createInstance(
      Ci.nsIConverterInputStream
    );
    fstream.init(file, 0x01 /* PR_RDONLY */, 0, 0);
    cstream.init(fstream, "UTF-8", 0, 0);
    let out = "";
    const chunk = {};
    let read = 0;
    do {
      read = cstream.readString(0xffffffff, chunk);
      out += chunk.value;
    } while (read !== 0);
    cstream.close();
    return out;
  }

  function tick() {
    try {
      const f = cssFile();
      if (!f.exists()) {
        return;
      }
      const stamp = f.lastModifiedTime;
      if (stamp === lastStamp) {
        return;
      }
      lastStamp = stamp;

      const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(
        Ci.nsIStyleSheetService
      );
      // Inline the CSS as a data: URI. A file:// URI would be served from the style
      // cache on re-register, so the palette change would not actually repaint.
      const uri = Services.io.newURI(
        "data:text/css;charset=utf-8," + encodeURIComponent(readText(f))
      );
      if (sheetURI && sss.sheetRegistered(sheetURI, sss.USER_SHEET)) {
        sss.unregisterSheet(sheetURI, sss.USER_SHEET);
      }
      sss.loadAndRegisterSheet(uri, sss.USER_SHEET);
      sheetURI = uri;
    } catch (e) {
      Cu.reportError("[zen-pywal] " + e);
    }
  }

  const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
  timer.init({ observe: tick }, POLL_MS, Ci.nsITimer.TYPE_REPEATING_SLACK);
  // Root the timer on a global the sandbox keeps alive; a bare local can be collected
  // and the poll would silently stop.
  globalThis.__zenPywalTimer = timer;
})();
