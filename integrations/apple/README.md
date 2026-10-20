# OptimServe Apple SDK 0.1.0

Swift and Objective-C session/player adapters for iOS 13+, tvOS 13+ and macOS 10.15+.
The public API is OptimServe. Application credentials, policy checks, renewals and
usage reports use your OptimServe workspace.

This source package does not include the commercial Apple transport frameworks.
See THIRD-PARTY.md. Apple compilation/device qualification is pending; do not
advertise this package as a production-qualified Apple SDK.

## Add to Xcode

Place licensed, matching `SwarmCloudKit.xcframework` and
`datachannel_wrapper.xcframework` in `Vendor/`. Add this folder as a local Swift
package and select the OptimServe product. CocoaPods hosts can use:

```ruby
pod 'OptimServe', :path => '../optimserve-apple'
```

Use the bundle identifier registered in your OptimServe app. For each Apple target,
set the app platform group to iOS/tvOS/macOS/Flutter/React Native/UniApp. The App Key
is publishable; it does not authenticate viewers or attest an installed bundle.

```swift
import OptimServe
let playback = try OptimServePlayer(
    appKey: "YOUR_APP_KEY", appName: "Your app", appIdentifier: "com.company.player")
// Show playback.player in your AVPlayerViewController or SwiftUI VideoPlayer.
playback.play("https://media.example/live.m3u8", streamID: nil)
// On leaving the player:
playback.close()
```

For an existing player, create `OptimServeSession` with the same fields, call
`prepare(_:streamID:completion:)` and pass the returned `url` to your player.
Call `updatePlayback(_:bufferedMs:positionMs:)` with real player state. Handle
`onEvent` events of type `url` by replacing the player's source with the returned
HTTP URL; `stats` events contain measured counters. Call `close()` on teardown.
Keep controls on the main thread. One stream owns the native engine at a time.

Keep signed playlist URLs intact. The AVPlayer wrapper uses URL authentication;
if your player requires custom request headers or DRM/resource-loader handling,
retain that handling in your existing player and use the session adapter.
Permit the loopback media proxy using `NSAppTransportSecurity` →
`NSAllowsLocalNetworking`; do not globally disable transport security. macOS
sandboxed hosts need incoming/outgoing network entitlements. Handle AirPlay with
the original media URL because a receiver cannot reach the phone's loopback proxy.

Peer bytes above zero confirm media exchange. Connected peers alone do not.
If service policy requires a sponsor notice or unsupported segment filtering, the
adapter uses HTTP. Pauses, credit checks and the ten-minute capability still apply.
