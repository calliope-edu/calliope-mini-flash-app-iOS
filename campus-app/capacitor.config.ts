import type { CapacitorConfig } from '@capacitor/cli';

/**
 * Native iOS wrapper for calliope-campus.
 *
 * WebView (WKWebView) loads campus from Cloudflare (rc05 by default).
 * BLE routes through @capacitor-community/bluetooth-le → CoreBluetooth,
 * so the OS-level bond is owned by THIS app. WKWebView has no Web
 * Bluetooth at all — the plugin path is the ONLY way to do BLE on iOS.
 *
 * To target a different campus build:
 *   CAPACITOR_SERVER_URL=https://campus.calliope.cc pnpm sync
 *
 * appId uses '.campus' suffix during development so installs don't
 * collide with the existing iOS flash app (cc.calliope.ios.flash).
 * Strip the suffix when we're ready to replace the App Store listing.
 */
const remoteUrl = process.env.CAPACITOR_SERVER_URL ?? 'https://rc05.calliope-campus.pages.dev';

const config: CapacitorConfig = {
  appId: 'cc.calliope.ios.campus',
  appName: 'Calliope Campus',
  webDir: 'www',
  server: {
    url: remoteUrl,
    cleartext: false,
    allowNavigation: [
      new URL(remoteUrl).hostname,
      'campus.calliope.cc',
      '*.calliope-campus.pages.dev',
      'makecode.calliope.cc',
      'python.calliope.cc',
    ],
  },
  plugins: {
    BluetoothLe: {
      displayStrings: {
        scanning: 'Suche Calliope mini…',
        cancel: 'Abbrechen',
        availableDevices: 'Gefundene Geräte',
        noDeviceFound: 'Kein Calliope mini gefunden',
      },
    },
  },
};

export default config;
