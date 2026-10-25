const { app, BrowserWindow, ipcMain, dialog, nativeImage, safeStorage, shell, Menu } = require('electron');
const path = require('path');
const fs = require('fs');

app.setAppUserModelId('fi.teukka.JaakiekkoTilastot');
const dataDir = () => { const d = path.join(app.getPath('userData')); fs.mkdirSync(d, { recursive: true }); return d; };
const settingsFile = () => path.join(dataDir(), 'settings.json');
let win;

function readSettings() { try { return JSON.parse(fs.readFileSync(settingsFile(), 'utf8')); } catch { return {}; } }
function writeSettings(o) { try { fs.writeFileSync(settingsFile(), JSON.stringify(o)); } catch {} }
function iconPath(name) { return path.join(__dirname, 'icons', 'Icon' + (/^[A-D]$/.test(name) ? name : 'A') + '.png'); }

function createWindow() {
  const choice = readSettings().appIcon || 'A';
  win = new BrowserWindow({
    width: 1400, height: 900, minWidth: 1100, minHeight: 680,
    backgroundColor: '#050A18', title: 'Jääkiekon Pistepörssi',
    icon: nativeImage.createFromPath(iconPath(choice)),
    autoHideMenuBar: true,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, webSecurity: false, backgroundThrottling: false }
  });
  Menu.setApplicationMenu(null);
  win.loadFile(path.join(__dirname, 'src', 'index.html'));
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: 'deny' }; });
}

app.whenReady().then(() => {
  const gotLock = app.requestSingleInstanceLock();
  if (!gotLock) { app.quit(); return; }
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });

  ipcMain.handle('state:load', () => { try { return fs.readFileSync(path.join(dataDir(), 'state.json'), 'utf8'); } catch { return null; } });
  ipcMain.handle('state:save', (_e, text) => { try { const f = path.join(dataDir(), 'state.json'); fs.writeFileSync(f + '.tmp', text); fs.renameSync(f + '.tmp', f); return true; } catch { return false; } });
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
