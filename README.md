# flowzz-plus-ios-safari

A native iOS Safari Web Extension scaffold for [flowzz+](https://github.com/CRZX1337/flowzz-plus), prepared so FreeMilk can add the flowzz+ browser extension to an existing iOS app.

This repository contains **no flowzz+ functionality**. It is the project skeleton only: a minimal iOS host app, a real Safari Web Extension target, correct embedding, valid plists and a placeholder web extension. The port itself is FreeMilk's work.

## What is in here

```
FlowzzPlus.xcodeproj/            Xcode project (objectVersion 56, Xcode 14+ compatible)
  xcshareddata/xcschemes/        shared "FlowzzPlus" scheme, usable with xcodebuild
FlowzzPlus/                      minimal iOS host app (SwiftUI)
  FlowzzPlusApp.swift
  ContentView.swift              enable-the-extension instructions only
  Info.plist
  Assets.xcassets/               app icon + accent colour
FlowzzPlus Extension/            Safari Web Extension target (app extension)
  SafariWebExtensionHandler.swift  native message handler (echo placeholder)
  Info.plist                     NSExtension: com.apple.Safari.web-extension
  Resources/                     web extension payload, copied to the .appex root
    manifest.json                Manifest V3 placeholder
    background.js                placeholder, intentionally not wired in the manifest
    content.js / content.css     placeholder content script, matches example.com only
    popup.html / popup.js / popup.css
    images/                      extension + toolbar icons (folder reference)
tools/validate-project.py        static validation, stdlib only, runs on Linux
.github/workflows/validate.yml   runs the validation on every push
FREEMILK-INTEGRATION.md          the integration manual
```

## Requirements

- Xcode 15 or newer on macOS (the project opens with Xcode 14+, building is tested against 15+ conventions).
- iOS 16.0 or newer as deployment target; Safari 16 supports Manifest V3. Manifest V3 itself works from Safari 15.4, so lowering the target is possible — read the manifest notes in the integration doc first.
- No third-party dependencies, no CocoaPods, no Swift packages, no WKWebView.

## Open and run

```bash
open FlowzzPlus.xcodeproj
```

1. Select the `FlowzzPlus` target, *Signing & Capabilities*, pick your team. Do the same for `FlowzzPlus Extension`.
2. Run on a connected iPhone or iPad (a real device is the reliable way to exercise Safari extensions).
3. On the device: **Settings → Safari → Extensions → flowzz+ → on**.
4. Open Safari, tap the flowzz+ toolbar button. The placeholder popup appears.
5. Visit `https://example.com` and check the Web Inspector console for `[flowzz+] content script placeholder loaded`.

The native handler echoes messages sent with `browser.runtime.sendNativeMessage`.

## Validate without Xcode

```bash
python3 tools/validate-project.py
```

It parses `project.pbxproj`, walks the group tree, checks the target graph, the embed phase, the target dependency, bundle identifier prefixes, both Info.plists, the app icon wiring and every path referenced by `manifest.json`. 175 checks, no dependencies.

Build from the command line (macOS only):

```bash
xcodebuild -project FlowzzPlus.xcodeproj -scheme FlowzzPlus \
  -destination 'generic/platform=iOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

Expected product layout:

```
FlowzzPlus.app/
  FlowzzPlus
  Info.plist
  PlugIns/
    FlowzzPlus Extension.appex/
      FlowzzPlus Extension
      Info.plist
      manifest.json
      background.js  content.js  content.css
      popup.html  popup.js  popup.css
      images/
```

If `manifest.json` or the popup files are missing from that list, Safari shows nothing at all — the failure is silent. Inspect the `.appex` inside the built app or IPA, not just the build log.

## Status

Statically validated only. No macOS or Xcode was available when this repository was created, so **no iOS build, signing step or device run has been performed**. Everything else — structure, embedding, plists, manifest, icon references — is machine-checked by `tools/validate-project.py`. See *Validation* in [FREEMILK-INTEGRATION.md](FREEMILK-INTEGRATION.md).

## Integration

Start with [FREEMILK-INTEGRATION.md](FREEMILK-INTEGRATION.md). It separates the files you can copy from the Xcode settings you have to recreate, and it documents the iOS-specific constraints that matter for the flowzz+ port.

## License

MIT. The flowzz+ name and the original extension belong to their authors; this scaffold is unofficial and not affiliated with flowzz.
