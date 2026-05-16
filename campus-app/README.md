# Calliope Campus — iOS wrapper

Capacitor shell that loads [calliope-campus](https://github.com/calliope-edu/calliope-campus) from Cloudflare and routes BLE through iOS CoreBluetooth via [`@capacitor-community/bluetooth-le`](https://github.com/capacitor-community/bluetooth-le).

WKWebView has **no Web Bluetooth at all** — this plugin path is the only way to talk to a Calliope on iPhone/iPad. The native side owns the OS-level bond; system pair prompts fire reliably, bonds persist across launches.

## Layout

| Path | What |
| --- | --- |
| `capacitor.config.ts` | Wrapper config — `server.url` points at rc05 by default |
| `ios/` | Auto-generated Xcode project (Capacitor) |
| `www/` | Offline fallback page |
| `package.json` | Node side: Capacitor CLI + the BLE plugin |

The repo's existing native flash app remains at the root and is unaffected by this directory.

## Build / run

Prerequisites (macOS only): Node 22+, pnpm 10+, Xcode 16+, CocoaPods (`brew install cocoapods`).

```bash
cd campus-app
pnpm install
pnpm sync
pnpm open                                    # opens Xcode — hit Run
# or
pnpm run                                     # builds + installs on a connected device / simulator
```

After first `cap sync`, run `cd ios/App && pod install` if Xcode complains about missing pods.

To point at a different campus build:

```bash
CAPACITOR_SERVER_URL=https://campus.calliope.cc pnpm sync
```

## Bundle ID

`cc.calliope.ios.campus` while we're testing — doesn't collide with `cc.calliope.ios.flash` (existing App Store install). Strip the `.campus` suffix when we're ready to replace the existing listing.
