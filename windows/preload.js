const { contextBridge, ipcRenderer } = require('electron');
const inv = (c, ...a) => ipcRenderer.invoke(c, ...a);
contextBridge.exposeInMainWorld('native', {
  loadState: () => inv('state:load'), saveState: t => inv('state:save', t),
  getSettings: () => inv('settings:get'), setSettings: p => inv('settings:set', p),
  logoIndex: () => inv('logo:index'), storeLogo: (u, b, m) => inv('logo:store', u, b, m), forgetLogo: u => inv('logo:forget', u),
  httpText: (u, t) => inv('http:text', u, t),
  setIcon: n => inv('icon:set', n),
  getSecret: () => inv('secret:get'), setSecret: v => inv('secret:set', v),
  saveSound: (n, b) => inv('sound:save', n, b), clearSound: () => inv('sound:clear'), loadSound: () => inv('sound:load'),
  saveFile: (n, t) => inv('file:save', n, t), openFile: () => inv('file:open'), openAudio: () => inv('file:openAudio'),
});
