# OptimServe SDK adapters

OptimServe app integration source previews. Each adapter uses the existing pinned
transport; no commercial Apple transport binaries are distributed here.

| Integration | Source | Current verification |
| --- | --- | --- |
| Swift / Objective-C: iOS, tvOS, macOS | [Apple](integrations/apple) | Cloud compilation workflow; device playback pending |
| React Native | [React Native](integrations/react-native) | Android bridge compiled; Apple/device checks pending |
| Flutter | [Flutter](integrations/flutter) | Analysis, lifecycle tests and Android host build passed; Apple/device checks pending |
| React web | [React](integrations/react) | Hook source; real React lifecycle playback pending |
| Electron: Windows, Linux, macOS | [Electron](integrations/electron) | Access-boundary and simulated-player checks passed; real playback pending |
| UniApp / UniApp X | [UniApp](integrations/uniapp) | Native/UTS source; HBuilderX builds pending |
| Android player-independent core | [Android native](integrations/android/native) | Release compilation passed; device playback pending |

These are previews, not a claim that every device/player combination is supported.
Android framework bridges depend on `agency.optimserve:optimserve-native:0.1.0`.
The source module is included; this repository is not an Android application.
Read each integration's README for installation, lifecycle and HTTP fallback handling.

## Apple compilation

Run **Native Apple compilation** manually under Actions. It runs only in a public
repository on a standard macOS runner. It downloads checksummed dependencies into
temporary storage and uploads no vendor frameworks or packaged binary artifacts.
A successful build verifies compilation, not peer-media delivery on a real device.

The Apple transport has separate commercial terms. Adapter MIT licenses do not
grant redistribution rights in that transport. See [Apple third-party notice](integrations/apple/THIRD-PARTY.md).
