# OptimServe for Electron 0.1.0

Windows, Linux and macOS desktop applications using Electron 30+ and an HLS.js
player. This is an Electron integration, not a bare Win32/Linux C SDK.

Install the prepared `optimserve-electron-0.1.0.tgz` using npm. Register the app
under the Electron/Windows/Linux platform group. Keep context isolation, sandboxing
and web security enabled and Node integration disabled in the renderer.

```js
// Main process: use your existing BrowserWindow and its exact local player URL.
import {createDesktopBridge} from '@optimserve/electron';
const bridge = createDesktopBridge(window, {
  appKey:'YOUR_APP_KEY', appName:'Your app', appId:'com.company.player',
  pageURL:playerPageURL
});
const filter = {urls:[
  'https://p2p.optimserve.agency/api/native/*',
  'wss://p2p.optimserve.agency/api/native/*'
]};
window.webContents.session.webRequest.onBeforeSendHeaders(filter, (details,done) => done(bridge.requestHeaders(details)));
window.webContents.session.webRequest.onHeadersReceived(filter, (details,done) => done(bridge.responseHeaders(details)));
```

Point your window's preload at `@optimserve/electron/preload`. If you already use
preload, include its narrow `contextBridge` export there. Compose the two callbacks
into existing request handlers: Electron retains only the last listener of each type.
The callbacks only apply to issued OptimServe capabilities in the registered main
frame. They do not alter your media server requests or expose generic network/IPC access.

```js
// Renderer, with your existing HLS.js instance:
import {attach} from '@optimserve/electron/renderer';
const delivery = await attach(hls, {stream:'https://media.example/live.m3u8'});
hls.loadSource('https://media.example/live.m3u8');
hls.attachMedia(video);
// Before destroying the player or changing the view:
await delivery.destroy();
```

Your existing content policy must permit the OptimServe SDK, HTTPS API and WSS
signaling. `snapshot()` and events use the ordinary browser adapter's measured
traffic. Optional `streamId` matches other viewers of identical media. The bridge
is removed on window closure; `bridge.close()` can close it earlier.
