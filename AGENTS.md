# Calliope Mini iOS App 

Native iOS app that connects an iPhone/iPad to the Calliope mini microcontroller board and flashes programs onto it. Programs are authored in web-based editors (MakeCode, MakeCode Arcade, Open Roberta, MicroPython, Calliope Blocks, Calliope Campus) loaded in in-app `WKWebView`s; the app extracts the compiled hex/program blob from the editor's download/postMessage flow and transfers it to the device over Bluetooth LE (Nordic DFU / partial flash) or USB.

## Build & run

- Open `Calliope App.xcworkspace`, not the `.xcodeproj` — dependencies are CocoaPods (run `pod install` after editing `Podfile`).
- Minimum deployment target: iOS 16.6.
- Unit tests live in `Calliope AppTests/` (XCTest, hosted by the app, synced folder). They cover logic behind protocols with fakes (e.g. `FlashService` against a fake device and connection), not real BLE/USB behavior, which still requires a real device (the simulator has no Bluetooth). Test the events/results a type promises, not its internal calls.
- Run them with `xcodebuild test -workspace "Calliope App.xcworkspace" -scheme "Calliope App" -destination 'platform=iOS Simulator,name=<simulator>'`; add `-only-testing:"Calliope AppTests/FlashServiceTests/testDfuErrorIsReportedOnce"` for a single test.
- Run tests on the connected iPad if one is available (much quicker than the simulator): find its id with `xcrun xctrace list devices` and use `-destination 'platform=iOS,id=<device id>'`. Fall back to the simulator only when no device is connected.

## Architecture

This project follows a MVVM architecture. Whereever possible UI is written in SwiftUI. For the exceptions where no SwiftUI implementation exists, UIKit is used.

`MatrixConnectionViewModel.instance` is the app-wide source of truth for the current device connection (BLE or USB) — read/observe it rather than talking to Bluetooth/USB APIs directly.

Partial flashing (`Model/Hex/PartialFlashing.swift`) is documented in `PARTIAL_FLASH_DOCUMENTATION.md` and `MICROPYTHON_PARTIAL_FLASH_PLAN.md` — consult before changing it.

## Making changes

Every change has to be reviewable by a human in one sitting, so work in small steps:
- Before a change with several parts, list the steps briefly and get agreement on them.
- Do one step at a time (e.g. "merge the two write paths into one method"), build, summarize only that step's diff, and wait for review before starting the next one.
- Each step should build and be committable on its own, with its tests in the same step.
- Don't bundle side fixes or cleanups you notice along the way into a step; point them out and do them as their own step.

## Notes
- Generally all code should be in English. There remains some older code and comments in German.
- Any text displayed in the App should be in English in the code. There remains some older code with German text. For the English text there should be a German translation in the Localizable.xcstrings.
- Comments: one short line, only for a non-obvious reason the code itself can't convey (hidden constraint, workaround, invariant). No multi-line/doc-style comments, even to explain a complex fix — that explanation belongs in the chat response or commit message, not the code.
