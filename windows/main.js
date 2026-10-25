const { screen, net, app, BrowserWindow, ipcMain, dialog, nativeImage, safeStorage, shell, Menu } = require('electron');
const path = require('path');
const fs = require('fs');

app.setAppUserModelId('fi.teukka.JaakiekkoTilastot');
// Pidetään tallennuskansio ennallaan, vaikka sovelluksen nimi vaihtui (tähdet, asetukset ja välimuisti säilyvät)
app.setPath('userData', path.join(app.getPath('appData'), 'Jääkiekon Pistepörssi'));
const dataDir = () => { const d = path.join(app.getPath('userData')); fs.mkdirSync(d, { recursive: true }); return d; };
const settingsFile = () => path.join(dataDir(), 'settings.json');
let win;

function readSettings() { try { return JSON.parse(fs.readFileSync(settingsFile(), 'utf8')); } catch { return {}; } }
function writeSettings(o) { try { fs.writeFileSync(settingsFile(), JSON.stringify(o)); } catch {} }
function iconPath(name) { return path.join(__dirname, 'icons', 'Icon' + (/^[A-D]$/.test(name) ? name : 'A') + '.png'); }

const winStateFile = () => path.join(dataDir(), 'window.json');
function loadWinState() {
  const wa = screen.getPrimaryDisplay().workArea;
  const def = { width: Math.min(1500, wa.width), height: Math.min(1000, wa.height), maximized: false };
  try {
    const s = JSON.parse(fs.readFileSync(winStateFile(), 'utf8'));
    if (s && s.width >= 1000 && s.height >= 680) {
      // Palautetaan paikka vain, jos ikkuna osuu johonkin nykyiseen näyttöön
      const vis = typeof s.x === 'number' && typeof s.y === 'number' && screen.getAllDisplays().some(d => { const b = d.workArea; return s.x + 100 < b.x + b.width && s.x + s.width - 100 > b.x && s.y >= b.y - 10 && s.y + 100 < b.y + b.height; });
      return vis ? { x: s.x, y: s.y, width: s.width, height: s.height, maximized: !!s.maximized } : { width: s.width, height: s.height, maximized: !!s.maximized };
    }
  } catch {}
  return def;
}
function trackWindow(w) {
  let t = null;
  const save = () => {
    if (w.isDestroyed() || w.isMinimized() || w.isFullScreen()) return;
    const b = w.isMaximized() ? (w.__normal || w.getNormalBounds()) : w.getBounds();
    if (!w.isMaximized()) w.__normal = b;
    try { fs.writeFileSync(winStateFile(), JSON.stringify({ x: b.x, y: b.y, width: b.width, height: b.height, maximized: w.isMaximized() })); } catch {}
  };
  const later = () => { clearTimeout(t); t = setTimeout(save, 400); };
  ['resize', 'move', 'maximize', 'unmaximize'].forEach(e => w.on(e, later));
  w.on('close', save);
}

function createWindow() {
  const choice = readSettings().appIcon || 'A';
  const ws = loadWinState();
  win = new BrowserWindow({
    x: ws.x, y: ws.y, width: ws.width, height: ws.height, minWidth: 1000, minHeight: 680,
    backgroundColor: '#050A18', title: 'Jääkiekko Tilastot',
    icon: nativeImage.createFromPath(iconPath(choice)),
    autoHideMenuBar: true,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, webSecurity: false, backgroundThrottling: false }
  });
  Menu.setApplicationMenu(null);
  if (ws.maximized) win.maximize();
  trackWindow(win);
  win.loadFile(path.join(__dirname, 'src', 'index.html'));
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: 'deny' }; });
}

app.whenReady().then(() => {
  const gotLock = app.requestSingleInstanceLock();
  if (!gotLock) { app.quit(); return; }
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });

  ipcMain.handle('state:load', () => { try { return fs.readFileSync(path.join(dataDir(), 'state.json'), 'utf8'); } catch { return null; } });
  ipcMain.handle('state:save', (_e, text) => { try { const f = path.join(dataDir(), 'state.json'); fs.writeFileSync(f + '.tmp', text); fs.renameSync(f + '.tmp', f); return true; } catch { return false; } });
  // ----- Pysyvä logovälimuisti -----
  const crypto = require('crypto');
  const logoDir = () => { const d = path.join(dataDir(), 'logos'); try { fs.mkdirSync(d, { recursive: true }); } catch {} return d; };
  const logoIndexFile = () => path.join(logoDir(), 'index.json');
  let logoIndex = null;
  const readLogoIndex = () => { if (!logoIndex) { try { logoIndex = JSON.parse(fs.readFileSync(logoIndexFile(), 'utf8')); } catch { logoIndex = {}; } } return logoIndex; };
  const logoExt = mime => /svg/.test(mime) ? 'svg' : /webp/.test(mime) ? 'webp' : /jpe?g/.test(mime) ? 'jpg' : /gif/.test(mime) ? 'gif' : 'png';
  ipcMain.handle('logo:index', () => {
    const idx = readLogoIndex(), out = {};
    for (const [url, f] of Object.entries(idx)) { const p = path.join(logoDir(), f); if (fs.existsSync(p)) out[url] = require('url').pathToFileURL(p).href; }
    return out;
  });
  ipcMain.handle('logo:store', (_e, url, buf, mime) => {
    try {
      const f = crypto.createHash('sha1').update(String(url)).digest('hex') + '.' + logoExt(String(mime || ''));
      const p = path.join(logoDir(), f); fs.writeFileSync(p, Buffer.from(buf));
      const idx = readLogoIndex(); idx[url] = f; fs.writeFileSync(logoIndexFile(), JSON.stringify(idx));
      return require('url').pathToFileURL(p).href;
    } catch { return null; }
  });
  ipcMain.handle('logo:forget', (_e, url) => { try { const idx = readLogoIndex(); delete idx[url]; fs.writeFileSync(logoIndexFile(), JSON.stringify(idx)); } catch {} return true; });
  ipcMain.handle('settings:get', () => readSettings());
  ipcMain.handle('settings:set', (_e, patch) => { const s = Object.assign(readSettings(), patch); writeSettings(s); return s; });
  ipcMain.handle('icon:set', (_e, name) => { const s = readSettings(); s.appIcon = name; writeSettings(s); if (win) win.setIcon(nativeImage.createFromPath(iconPath(name))); return true; });
  ipcMain.handle('secret:get', () => {
    try { const b = fs.readFileSync(path.join(dataDir(), 'ep.key')); return safeStorage.isEncryptionAvailable() ? safeStorage.decryptString(b) : b.toString('utf8'); } catch { return null; }
  });
  ipcMain.handle('secret:set', (_e, v) => {
    const f = path.join(dataDir(), 'ep.key');
    try { if (!v) { fs.rmSync(f, { force: true }); return true; } fs.writeFileSync(f, safeStorage.isEncryptionAvailable() ? safeStorage.encryptString(v) : Buffer.from(v, 'utf8')); return true; } catch { return false; }
  });
  ipcMain.handle('http:text', async (_e, url, timeout) => {
    try {
      const u = new URL(url); if (u.protocol !== 'https:') return null;
      const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), timeout || 30000);
      try { const r = await net.fetch(url, { signal: ctl.signal, headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html,*/*' } }); if (r.status !== 200) return { status: r.status, text: null }; return { status: 200, text: await r.text() }; }
      finally { clearTimeout(t); }
    } catch (e) { return { status: 0, text: null, err: String(e && e.message || e) }; }
  });
  ipcMain.handle('sound:save', (_e, name, buf) => {
    try { const ext = (path.extname(name) || '.wav').toLowerCase(); const f = 'goal-sound' + ext; for (const x of fs.readdirSync(dataDir())) if (x.startsWith('goal-sound')) fs.rmSync(path.join(dataDir(), x), { force: true }); fs.writeFileSync(path.join(dataDir(), f), Buffer.from(buf)); const s = readSettings(); s.soundFile = f; s.soundName = name; writeSettings(s); return true; } catch { return false; }
  });
  ipcMain.handle('sound:clear', () => { try { for (const x of fs.readdirSync(dataDir())) if (x.startsWith('goal-sound')) fs.rmSync(path.join(dataDir(), x), { force: true }); const s = readSettings(); delete s.soundFile; delete s.soundName; writeSettings(s); } catch {} return true; });
  ipcMain.handle('sound:load', () => { try { const s = readSettings(); if (!s.soundFile) return null; const b = fs.readFileSync(path.join(dataDir(), s.soundFile)); const ext = path.extname(s.soundFile).slice(1); return { name: s.soundName, mime: 'audio/' + (ext === 'mp3' ? 'mpeg' : ext === 'm4a' ? 'mp4' : ext), data: b.toString('base64') }; } catch { return null; } });
  ipcMain.handle('file:save', async (_e, defaultName, text) => {
    const r = await dialog.showSaveDialog(win, { defaultPath: defaultName, filters: [{ name: 'JSON', extensions: ['json'] }] });
    if (r.canceled || !r.filePath) return false;
    fs.writeFileSync(r.filePath, text); return true;
  });
  ipcMain.handle('file:open', async () => {
    const r = await dialog.showOpenDialog(win, { filters: [{ name: 'JSON', extensions: ['json'] }], properties: ['openFile'] });
    if (r.canceled || !r.filePaths[0]) return null;
    return fs.readFileSync(r.filePaths[0], 'utf8');
  });
  ipcMain.handle('file:openAudio', async () => {
    const r = await dialog.showOpenDialog(win, { filters: [{ name: 'Ääni', extensions: ['mp3', 'wav', 'aiff', 'm4a', 'ogg', 'flac'] }], properties: ['openFile'] });
    if (r.canceled || !r.filePaths[0]) return null;
    return { name: path.basename(r.filePaths[0]), data: fs.readFileSync(r.filePaths[0]) };
  });
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => app.quit());
