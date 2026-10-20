# OptimServe for Flutter 0.1.0

Flutter plugin for Android API 24+, iOS 13+ and macOS 10.15+. Flutter 3.7+/Dart 3+.
Apple integration remains pending dependency rights and platform qualification.

Extract the source archive and add the plugin folder as a path dependency:

```yaml
dependencies:
  optimserve:
    path: ../optimserve_flutter
```

Keep Google/Maven Central and add `https://p2p.optimserve.agency/sdk/maven/` to your
Android dependency repositories. The plugin uses OptimServe Native 0.1.0. Preserve
your network-security config and allow the localhost media proxy only, following
the Android guide. On Apple, add the local OptimServe Apple pod in your existing
Podfile from a licensed Apple SDK installation. This plugin currently uses CocoaPods
for Apple dependencies; it does not provide an automatic Swift Package Manager install.

```dart
import 'package:optimserve/optimserve.dart';
final delivery = await OptimServeSession.create(
  appKey: 'YOUR_APP_KEY', appName: 'Your app', appId: 'com.company.player',
  onEvent: (event) {
    if (event['type'] == 'url') {
      // Replace your player's source with event['url']; retain playback position.
    }
  },
);
final playback = await delivery.prepare('https://media.example/live.m3u8');
final player = VideoPlayerController.networkUrl(Uri.parse(playback['url']));
await player.initialize();
await player.play();
// Forward actual player state, buffered duration and playback position.
await delivery.updatePlayback('playing', bufferedMs: bufferedMs, positionMs: positionMs);
// On leaving the view:
await player.dispose();
await delivery.close();
```

The player is your existing `video_player` dependency, not an OptimServe dependency.
Forward buffering/paused/stopped states too. Lifecycle changes are forwarded by the
plugin. Register Android package IDs under Android and Apple bundle IDs under Apple;
use separate app registrations if they differ. Optional Stream IDs are supported.
`snapshot()` returns observed traffic and report availability, without invented HTTP
bytes from an external player. One native session may run in the process at a time.
