# OptimServe UniApp adapters 0.1.0

Contains a classic UniApp native module and a UniApp X UTS plugin. Both wrap the
same OptimServe native session cores; they do not initialize the vendor service.
Android minimum API 24; Apple minimum iOS 13. HBuilderX packaging and device
qualification remain outstanding. Apple dependencies have separate commercial terms.

## UniApp X / UTS

Copy `uni_modules/optimserve` into your project's `uni_modules`. Android repository
and dependency declarations are in `utssdk/app-android/config.json`. Preserve your
app's network-security rules and permit the localhost media proxy. For Apple, supply
the licensed OptimServe Apple module and its required frameworks in the plugin's
Frameworks folder; no Apple binaries are included here.

```ts
import {configure, prepare, updatePlayback, setBackground, close} from '@/uni_modules/optimserve';
configure({appKey:'YOUR_APP_KEY',appName:'Your app',appId:'com.company.player',onEvent:(event:UTSJSONObject)=>{
  // A url event changes your player's source to its HTTP fallback URL.
}}, (result:UTSJSONObject)=>{
  if (result['error'] != null) return;
  prepare('https://media.example/live.m3u8',null,(playback:UTSJSONObject)=>{
    if (playback['error'] == null) videoSource = playback['url'] as string;
  });
});
// Forward real state and app lifecycle; release on page teardown.
updatePlayback('playing',bufferedMs,positionMs);
setBackground(true);
close();
```

## Classic UniApp

Build the Android class under `android/` into your native plugin using the DCloud
SDK and `agency.optimserve:optimserve-native:0.1.0`; register it as `OptimServe-Native`.
On iOS build the `ios/` module against the OptimServe Apple module and DCloud headers.
The package contains source, not a prebuilt DCloud SDK or a cloud marketplace plugin.

Import `createSession` from `index.js`, pass App Key/name/package or bundle App ID,
then `await delivery.prepare(stream)` and pass its `url` to your existing player.
Forward `updatePlayback(state, bufferedMs, positionMs)` and handle `url` events for
HTTP fallback. `close()` unregisters listeners and releases the native session.
Register Android IDs under Android and Apple bundle IDs under the Apple group.
