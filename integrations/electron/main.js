import {ipcMain} from 'electron';
import {createHeaderPolicy} from './policy.js';
const contexts = new Map();
let installed = false;
export function createDesktopBridge(window, {appKey, appName, appId, pageURL}) {
  if (!/^opa_[a-f\d]{32}_[a-f\d]{64}$/i.test(appKey || '') || typeof appName !== 'string' || !appName.trim() || appName.length > 80 || !/^[A-Za-z\d._-]{1,160}$/.test(appId || '')) throw new TypeError('Copy your registered App Key, app name and App ID.');
  const preferences = window.webContents.getLastWebPreferences();
  if (preferences.nodeIntegration || !preferences.contextIsolation || !preferences.sandbox || preferences.webSecurity === false) throw new Error('Use a sandboxed, isolated renderer with web security enabled.');
  const raw = appKey.slice(4,36), id = raw.replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/, '$1-$2-$3-$4-$5');
  const webContentsId = window.webContents.id, policy = createHeaderPolicy(webContentsId, pageURL);
  if (contexts.has(webContentsId)) throw new Error('This window already has an OptimServe bridge.');
  let closed = false, busy = false;
  const page = new URL(pageURL); page.hash = '';
  const context = {window, page:page.href, async authorize(input) {
    if (closed || busy) throw new Error('Playback setup is busy.');
    const url = new URL(input?.stream);
    if (url.protocol !== 'https:' || url.username || url.password || url.hash || input.stream.length > 2048 || input.stream_id !== undefined && !/^[A-Za-z\d][A-Za-z\d_.:-]{0,127}$/.test(input.stream_id) || !Number.isInteger(input.selection) || input.selection < 0 || input.selection > 99 || typeof input.metered !== 'boolean' || typeof input.p2p !== 'boolean') throw new TypeError('Invalid playback setup.');
    busy = true;
    try {
      const response = await fetch(`https://p2p.optimserve.agency/api/native/apps/${id}/sessions`, {method:'POST', redirect:'error', credentials:'omit', signal:AbortSignal.timeout(8000), headers:{'Content-Type':'application/json'}, body:JSON.stringify({key:appKey, app_name:appName, app_identifier:appId, platform:'electron', stream:input.stream, stream_id:input.stream_id, selection:input.selection, metered:input.metered, p2p:input.p2p})});
      if (!response.ok) throw new Error('OptimServe authorization is unavailable.');
      const raw = await response.text(); if (raw.length > 131072) throw new Error('Invalid native response.');
      const result = policy.learn(JSON.parse(raw));
      if (closed) {void fetch(result.stop,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(2000)}).catch(()=>{}); throw new Error('Playback setup cancelled.');}
      return result;
    } finally {busy = false;}
  }};
  if (!installed) {
    ipcMain.handle('optimserve:authorize', async (event,input) => {
      const current = contexts.get(event.sender.id), frame = event.senderFrame;
      if (!current || frame !== current.window.webContents.mainFrame) throw new Error('Untrusted playback frame.');
      const url = new URL(frame.url); url.hash = '';
      if (url.href !== current.page) throw new Error('Untrusted playback page.');
      return current.authorize(input);
    }); installed = true;
  }
  contexts.set(webContentsId,context);
  function close() {
    if (closed) return; closed = true; contexts.delete(webContentsId);
    for (const url of policy.stops) void fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(2000)}).catch(()=>{});
    policy.close();
  }
  window.once('closed',close);
  // Compose these callbacks into the app's existing webRequest listeners.
  return Object.freeze({requestHeaders:policy.request,responseHeaders:policy.response,close});
}
