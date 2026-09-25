# Calliope Mini iOS App 

Native iOS app that connects an iPhone/iPad to the Calliope mini microcontroller board and flashes programs onto it. Programs are authored in web-based editors (MakeCode, MakeCode Arcade, Open Roberta, MicroPython, Calliope Blocks, Calliope Campus) loaded in in-app `WKWebView`s; the app extracts the compiled hex/program blob from the editor's download/postMessage flow and transfers it to the device over Bluetooth LE (Nordic DFU / partial flash) or USB.

## Build & run

- Open `Calliope App.xcworkspace`, not the `.xcodeproj` — dependencies are CocoaPods (run `pod install` after editing `Podfile`).
- Minimum deployment target: iOS 16.6.
- There is no automated test target/suite in this repo. BLE flashing requires a real device (the simulator has no Bluetooth).

## Architecture

This project follows a MVVM architecture. Whereever possible UI is written in SwiftUI. For the exceptions where no SwiftUI implementation exists, UIKit is used.

`MatrixConnectionViewModel.instance` is the app-wide source of truth for the current device connection (BLE or USB) — read/observe it rather than talking to Bluetooth/USB APIs directly.

Partial flashing (`Model/Hex/PartialFlashing.swift`) is documented in `PARTIAL_FLASH_DOCUMENTATION.md` and `MICROPYTHON_PARTIAL_FLASH_PLAN.md` — consult before changing it.

## Notes
- Generally all code should be in English. There remains some older code and comments in German.
