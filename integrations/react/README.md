# OptimServe for React web 0.1.0

React 18+ hook for an existing HLS.js instance. This package uses the hosted
OptimServe browser SDK 0.12.0; it does not bundle a second HLS player or P2P engine.

Install the prepared `optimserve-react-0.1.0.tgz` using npm. Register your website's
HTTPS domain; React web uses the site's publishable delivery key and site ID,
not an App Key. Permit OptimServe SDK modules in your site's content policy.

```js
import {useOptimServe} from '@optimserve/react';
function PlaybackStats({hls}) {
  const stats = useOptimServe(hls, {
    site:'YOUR_SITE_ID', key:'YOUR_DELIVERY_KEY',
    stream:'https://media.example/live.m3u8',
    onError(error) { /* Show an understandable notice; ordinary HTTP remains. */ }
  });
  return <span>{stats?.peer_kib == null ? 'Waiting for playback' : `${stats.peer_kib} KiB from peers`}</span>;
}
```

The caller owns HLS.js playback. Keep the instance stable and destroy it when its
view leaves. The hook releases delivery on unmount, HLS changes, source changes and
React Strict Mode cleanup. It never creates balances or presents a connection as
media savings. For native React apps use `@optimserve/react-native` instead.
