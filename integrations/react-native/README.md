# OptimServe for React Native 0.1.0

React Native 0.76+, Android API 24+, iOS/tvOS 13+. Supports existing players through
a prepared local media URL. Expo Go does not contain native modules; use a native build.
Apple integration is not released pending Apple dependency rights and qualification.

Install the prepared `optimserve-react-native-0.1.0.tgz` using npm. In Android's
existing `dependencyResolutionManagement.repositories`, keep `google()` and
`mavenCentral()` and add:

```gradle
maven { url = uri("https://p2p.optimserve.agency/sdk/maven/") }
```

The Android bridge resolves `agency.optimserve:optimserve-native:0.1.0` from this
repository. Preserve your existing network-security config and allow cleartext only
for the localhost/127.0.0.1 media proxy, as in the OptimServe Android guide.
On Apple, add the local OptimServe Apple pod from a licensed SDK installation to
your existing Podfile, then run `pod install`. Rebuild your app after installation.

```js
import {createSession} from '@optimserve/react-native';
const delivery = await createSession({
  appKey: 'YOUR_APP_KEY', appName: 'Your app', appId: 'com.company.player',
  onEvent(event) { if (event.type === 'url') setSource({uri:event.url}); }
});
const playback = await delivery.prepare('https://media.example/live.m3u8');
setSource({uri:playback.url});
// Forward your real player events; buffered/position values are milliseconds.
await delivery.updatePlayback('playing', bufferedMs, positionMs);
// On leaving the player, stop the player and release the delivery session.
await delivery.close();
```

`setSource` is your player's source setter; the SDK does not create a second player.
Use the Android app registration for Android package IDs and Apple group for Apple
bundle IDs; configure separately if the IDs differ. Optional Stream IDs are the
second argument to `prepare`. Keep signed media URLs unchanged.

AppState changes are forwarded automatically. On HTTP fallback the `url` event
returns the original media URL; update your player and retain your own HTTP media
headers/DRM handling. No traffic is inferred from a connection. `snapshot()` and
`stats` events provide SDK observations and reporting availability. One session
may own the native engine per process; do not combine this with another P2P plugin.
