# FreeMilk integration manual

How to take the Safari Web Extension prepared in this repository and add it to an existing FreeMilk iOS app.

This document is the contract for the handover: what the scaffold contains, which parts travel as files, which parts are Xcode configuration that has to be recreated inside the FreeMilk project, and which iOS/Safari constraints the flowzz+ port has to respect.

Nothing in this repository implements flowzz+. `FlowzzPlus Extension/Resources` is a placeholder payload. Replacing that folder with the flowzz+ web extension is the port, and it is FreeMilk's work.

---

## 0. Architecture in one page

```
FlowzzPlus.app                         ← host application (iOS)
├── FlowzzPlus                         ← app binary, SwiftUI, no WKWebView
├── Info.plist
├── Assets.car
└── PlugIns/
    └── FlowzzPlus Extension.appex     ← Safari Web Extension (app extension)
        ├── FlowzzPlus Extension       ← extension binary (SafariWebExtensionHandler)
        ├── Info.plist                 ← NSExtensionPointIdentifier com.apple.Safari.web-extension
        ├── manifest.json              ← web extension manifest, at the bundle root
        ├── background.js
        ├── content.js  content.css
        ├── popup.html  popup.js  popup.css
        └── images/
```

Three facts drive everything else:

1. Safari does not load an extension from a folder. It loads an **app extension** whose `NSExtensionPointIdentifier` is `com.apple.Safari.web-extension`, embedded in an iOS app.
2. The web payload (`manifest.json`, scripts, styles, popup, images) is **bundle resources of that app extension**. On iOS the `.appex` is a flat bundle, so `manifest.json` sits next to the extension binary. Xcode's *Copy Bundle Resources* phase flattens files into that root; only folder references keep their directory (which is why `images/` is a folder reference here).
3. The user enables the extension in **Settings → Safari → Extensions**. An iOS app cannot enable a Safari extension programmatically, and the host app is not on the extension's code path at runtime.

The host app in this repository exists only to make the project buildable and testable on its own. FreeMilk does not need it — only the extension target and its resources move over.

---

## 1. Required Safari Web Extension target configuration

Create the target as a **Safari Extension** app extension for iOS (Xcode: *File → New → Target… → Safari Extension*) or reproduce the settings below in an existing target.

| Setting | Value | Why |
| --- | --- | --- |
| Product type | `com.apple.product-type.app-extension` | Safari web extensions are app extensions, not frameworks or standalone apps. |
| Product name | `FlowzzPlus Extension` (any name; spaces become `_` in the module name) | Determines `PRODUCT_MODULE_NAME`, which `NSExtensionPrincipalClass` references. |
| `APPLICATION_EXTENSION_API_ONLY` | `YES` | Required for every app extension; forbids `UIApplication.shared` and other unavailable APIs. |
| `SKIP_INSTALL` | `YES` | The `.appex` is embedded in the app, it is not installed on its own; archiving fails validation otherwise. |
| `GENERATE_INFOPLIST_FILE` | `NO` | This scaffold ships a real `Info.plist` so the `NSExtension` dictionary is reviewable. See section 3 for the alternative. |
| `INFOPLIST_FILE` | `FlowzzPlus Extension/Info.plist` | Path relative to the project directory. |
| `PRODUCT_BUNDLE_IDENTIFIER` | `<host bundle id>.Extension` — here `com.example.flowzzplus.Extension` | Must be prefixed with the host app's bundle identifier (section 9). |
| `IPHONEOS_DEPLOYMENT_TARGET` | `16.0` | Manifest V3 needs Safari 15.4+; the extension must not require a newer iOS than the host app. |
| `TARGETED_DEVICE_FAMILY` | `1,2` | Match the host app (iPhone/iPad). |
| `SUPPORTS_MACCATALYST` | `NO` | This target is the iOS/iPadOS Safari extension. A Mac Catalyst build needs its own macOS extension target. |
| `SWIFT_VERSION` | `5.0` | Only for the native handler. |
| `LD_RUNPATH_SEARCH_PATHS` | `$(inherited)`, `@executable_path/Frameworks`, `@executable_path/../../Frameworks` | Standard for embedded extensions. |
| `CODE_SIGN_STYLE` | `Automatic` | Simplest path; see section 10 for manual signing. |
| Entitlements | none | A basic Safari web extension needs no entitlements. App Groups only if the extension and the host app share data. |

Explicitly **not** part of the target: `WKWebView`, `WKWebViewConfiguration`, `SFSafariApplication`, a custom browser, an `NSExtensionAttributes` dictionary, or a `SFSafariWebsiteAccess` entry (that one belongs to legacy Safari *app* extensions on macOS). Site access on iOS comes from the manifest's `host_permissions`, granted by the user.

---

## 2. Required host application configuration

For FreeMilk this is **the existing app**, unchanged:

- Same `SDKROOT = iphoneos`, same `TARGETED_DEVICE_FAMILY` and a deployment target **not older** than the extension's.
- Same `DEVELOPMENT_TEAM` as the extension (and the same signing identity).
- An **Embed Foundation Extensions** copy phase that embeds the `.appex` with *Code Sign On Copy* (section 6).
- A **target dependency** on the extension target (section 4).
- Nothing else. The host needs no Safari-specific `Info.plist` keys, no `SafariServices` import, no code that toggles the extension, and no launch-time setup. The extension is discoverable in Safari as soon as the app is installed and the user enables it.
- Do **not** add a `WKWebView`, an in-app browser, or a WebView-based preview of the extension. Safari is the host of the web payload.

One App Store constraint lives in the host: `CFBundleShortVersionString` and `CFBundleVersion` of the extension must match the host app's values (section 10).

---

## 3. Required Info.plist entries

### Extension — `FlowzzPlus Extension/Info.plist`

```xml
<key>CFBundleDevelopmentRegion</key>       <string>$(DEVELOPMENT_LANGUAGE)</string>
<key>CFBundleDisplayName</key>             <string>flowzz+</string>
<key>CFBundleExecutable</key>              <string>$(EXECUTABLE_NAME)</string>
<key>CFBundleIdentifier</key>              <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleInfoDictionaryVersion</key>   <string>6.0</string>
<key>CFBundleName</key>                    <string>$(PRODUCT_NAME)</string>
<key>CFBundlePackageType</key>             <string>XPC!</string>
<key>CFBundleShortVersionString</key>      <string>$(MARKETING_VERSION)</string>
<key>CFBundleVersion</key>                 <string>$(CURRENT_PROJECT_VERSION)</string>
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>    <string>com.apple.Safari.web-extension</string>
  <key>NSExtensionPrincipalClass</key>     <string>$(PRODUCT_MODULE_NAME).SafariWebExtensionHandler</string>
</dict>
```

Rules:

- `NSExtensionPointIdentifier` is **exactly** `com.apple.Safari.web-extension`. Anything else (including the legacy `com.apple.Safari.extension`) produces an extension Safari never lists.
- `NSExtensionPrincipalClass` must be **module-qualified**. `$(PRODUCT_MODULE_NAME)` expands to the target name with non-alphanumeric characters replaced by `_`, so `FlowzzPlus Extension` becomes `FlowzzPlus_Extension.SafariWebExtensionHandler`. Keep the `$(PRODUCT_MODULE_NAME).` prefix and only change the class name after the dot.
- The class must be `@objc`-visible — subclassing `NSObject` (as here) is enough.
- `CFBundlePackageType` is `XPC!` for app extensions. `APPL` belongs to the host.
- Both version keys must resolve to the same values as the host app.
- `CFBundleDisplayName` may contain `+`; bundle identifiers may not (section 9).

### Host app — `FlowzzPlus/Info.plist`

No Safari-specific keys. The scaffold contains the usual iOS app keys (`CFBundlePackageType = APPL`, `LSRequiresIPhoneOS`, scene manifest, launch screen, orientations). FreeMilk keeps its existing host plist as it is.

### If the FreeMilk project generates its Info.plist

An extension target created by Xcode 15+ often defaults to `GENERATE_INFOPLIST_FILE = YES`. Nested dictionaries are awkward through `INFOPLIST_KEY_*` build settings, so the reliable options are:

1. Set `GENERATE_INFOPLIST_FILE = NO`, add an `Info.plist` to the extension target and fill in the keys above (what this repository does), or
2. Keep generation enabled and add `INFOPLIST_KEY_NSExtension` as a dictionary literal — but verify the built plist with `plutil -p` before shipping; a typo here silently produces an extension that never appears.

Option 1 is recommended: the plist is reviewable in a diff.

---

## 4. Required target dependencies

The host target depends on the extension target, so the `.appex` is built before the app is embedded and signed.

In Xcode: select the **host** target → *Build Phases* → *Dependencies* → `+` → select the extension target. Xcode usually adds this automatically when you embed the extension; verify it.

In `project.pbxproj` this is a `PBXTargetDependency` plus a `PBXContainerItemProxy`:

```
F80000000000000000000001 /* PBXContainerItemProxy */ = {
    isa = PBXContainerItemProxy;
    containerPortal = F50000000000000000000001 /* Project object */;
    proxyType = 1;
    remoteGlobalIDString = F40000000000000000000002;   /* the extension target */
    remoteInfo = "FlowzzPlus Extension";
};
F80000000000000000000002 /* PBXTargetDependency */ = {
    isa = PBXTargetDependency;
    target = F40000000000000000000002 /* FlowzzPlus Extension */;
    targetProxy = F80000000000000000000001 /* PBXContainerItemProxy */;
};
```

and the host target lists `F80000000000000000000002` in its `dependencies` array. `remoteGlobalIDString` must be the extension target's object ID, not its product's.

If the FreeMilk app already has extensions (widgets, notification service), the array simply contains one more dependency; they do not interfere.

---

## 5. Required build phases

**Host target** — in this order:

1. `Sources` — the app's Swift files.
2. `Frameworks` — no Safari frameworks required.
3. `Resources` — `Assets.xcassets` and other app resources.
4. `Embed Foundation Extensions` — a *Copy Files* phase, destination **PlugIns**, containing the `.appex` with *Code Sign On Copy* (section 6).

**Extension target** — in this order:

1. `Sources` — `SafariWebExtensionHandler.swift`.
2. `Frameworks` — empty.
3. `Resources` — `manifest.json`, `background.js`, `content.js`, `content.css`, `popup.html`, `popup.css`, `popup.js` as individual files, and `images` as a **folder reference** (blue folder icon).

Details that break extensions when missed:

- `Info.plist` must **not** be in *Copy Bundle Resources*. `INFOPLIST_FILE` is enough; a second copy produces a duplicate-resource warning and an unpredictable plist in the bundle.
- Individual files are copied **flat** into the appex root on iOS. That is why `manifest.json` ends up next to the binary and why manifest paths are relative to the bundle root (`images/icon-48.png`, not `Resources/images/icon-48.png`).
- `images/` must be added as a folder reference. Dragging the icons in one by one flattens them and every `images/...` path in the manifest 404s — the popup then fails without an error message.
- No custom *Run Script* phase is needed. If FreeMilk adds one (asset generation, version stamping), declare input and output files, otherwise `ENABLE_USER_SCRIPT_SANDBOXING = YES` blocks it.

---

## 6. Extension embedding configuration

The `.appex` is embedded in the host app's `PlugIns/` directory. In the Xcode UI:

- Host target → *Build Phases* → *Embed Foundation Extensions* (older Xcode: *Embed App Extensions*).
- Destination: **PlugIns**, subpath empty.
- Attributes: **Code Sign On Copy** and **Remove Headers On Copy**.

In `project.pbxproj`:

```
F30000000000000000000004 /* Embed Foundation Extensions */ = {
    isa = PBXCopyFilesBuildPhase;
    buildActionMask = 2147483647;
    dstPath = "";
    dstSubfolderSpec = 13;          /* 13 = PlugIns */
    files = (
        B1000000000000000000000D /* FlowzzPlus Extension.appex in Embed Foundation Extensions */,
    );
    name = "Embed Foundation Extensions";
    runOnlyForDeploymentPostprocessing = 0;
};

B1000000000000000000000D /* ... in Embed Foundation Extensions */ = {
    isa = PBXBuildFile;
    fileRef = F10000000000000000000010 /* FlowzzPlus Extension.appex */;
    settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); };
};
```

Verification on a build:

```bash
find "$APP/PlugIns" -maxdepth 2
# FlowzzPlus.app/PlugIns/FlowzzPlus Extension.appex
plutil -p "$APP/PlugIns/FlowzzPlus Extension.appex/Info.plist" | grep -A3 NSExtension
```

`dstSubfolderSpec = 16` would put the extension into `Contents/` (the macOS location) and iOS would ignore it. "Embed Without Signing" also breaks installation on device and App Store validation.

---

## 7. Required Swift files

One file is required: the native message handler. The scaffold's version is complete and can be copied as-is.

`FlowzzPlus Extension/SafariWebExtensionHandler.swift`:

```swift
import SafariServices
import os.log

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey]

        os_log("flowzz+ extension received a native message: %@", String(describing: message))

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["echo": message ?? NSNull()]]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
```

- The class name must match the value behind `NSExtensionPrincipalClass` (keep `SafariWebExtensionHandler` or update both).
- Messages arrive from JavaScript via `browser.runtime.sendNativeMessage(applicationId, payload)`; the payload is under `SFExtensionMessageKey`. `applicationId` is the identifier Safari assigns to the extension — the extension's bundle identifier plus your team identifier. Confirm it once on a real build: a wrong value only produces a rejected promise, with no hint about which part is wrong.
- Always call `context.completeRequest(...)`. An unanswered request is killed, and Safari logs nothing useful.
- Keep the handler stateless unless you need shared storage; if you do, use an App Group and add the entitlement to **both** targets.
- `SafariServices` is the only framework import. No `SafariServices` usage in the host app is required.

The rest of the Swift in this repository (`FlowzzPlusApp.swift`, `ContentView.swift`) belongs to the standalone host app and is not part of the integration.

---

## 8. Required extension resource files

```
FlowzzPlus Extension/Resources/
├── manifest.json      required — Safari's entry point
├── background.js      placeholder, not referenced by the manifest
├── content.js         required by the placeholder manifest's content_scripts
├── content.css        required by the placeholder manifest's content_scripts
├── popup.html         required by the manifest's action.default_popup
├── popup.js           loaded by popup.html
├── popup.css          loaded by popup.html
└── images/            required: manifest icons + toolbar icons
    ├── icon-48.png  icon-64.png  icon-96.png  icon-128.png  icon-256.png  icon-512.png
    └── toolbar-icon-16.png  toolbar-icon-19.png  toolbar-icon-32.png  toolbar-icon-38.png
```

Rules:

- `manifest.json` is the only truly required file. Everything it references must exist at the path written in the manifest, relative to the appex root, with matching case.
- `manifest_version: 3` (Safari 15.4+). Keep the manifest free of keys Safari ignores or does not implement; Apple's compatibility notes are the reference. The scaffold intentionally declares **no** `background` key, because background execution is the part of the port with real version constraints (section 13).
- Icons: 48, 64, 96, 128, 256, 512 px for the extension list, 16, 19, 32, 38 px for the toolbar button.
- The popup is presented as a sheet on iPhone. The scaffold's 320 px width is a reasonable starting point; layout must adapt to iPhone and iPad.
- No remote code: Manifest V3 forbids remote scripts, so all JavaScript must ship inside the bundle. `eval` and inline event handlers are unavailable.
- Optional: `_locales/<lang>/messages.json` with `__MSG_*__` placeholders in the manifest for localization.

---

## 9. Bundle identifier configuration

| | Value in this repo | Rule |
| --- | --- | --- |
| Host app | `com.example.flowzzplus` | FreeMilk's existing app bundle identifier. Do not reuse the placeholder. |
| Extension | `com.example.flowzzplus.Extension` | Must start with the host bundle identifier followed by a dot. |

- App Store validation rejects an app extension whose bundle identifier is not prefixed by the containing app's identifier, and an extension that equals it.
- Recommended FreeMilk values: `<FreeMilkAppBundleID>.SafariExtension` (or `.flowzzplus`). Keep the suffix stable after the first release — Safari and App Store Connect treat a changed identifier as a different extension.
- Allowed characters: alphanumerics, hyphen and period. **No `+`, no spaces, no underscore.** `flowzz+` belongs in `CFBundleDisplayName` and the manifest's `name`, never in an identifier.
- Both identifiers are set through `PRODUCT_BUNDLE_IDENTIFIER` and referenced from the plists as `$(PRODUCT_BUNDLE_IDENTIFIER)`. Do not hardcode them in `Info.plist`.
- The target name (and thus `PRODUCT_MODULE_NAME`) is independent of the bundle identifier. Renaming the target later changes the module name, but `$(PRODUCT_MODULE_NAME)` in the plist follows automatically.

---

## 10. Code signing requirements

- App and extension must be signed with the **same team**. Mismatched teams fail at install time with a generic "unable to install" error.
- With automatic signing, select the team on both targets; Xcode creates the extension's provisioning profile (`<app id>.Extension`) itself.
- With manual signing, the extension needs its own distribution profile; the certificate must match the app's. The `.appex` inside the archive must be signed — a *Code Sign On Copy* embed phase does this.
- App Store requirements:
  - `CFBundleShortVersionString` and `CFBundleVersion` of the extension must equal the host app's. Bump both together (they are `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in this project).
  - The extension is not a separate App Store record; it ships inside the app.
  - An extension that does nothing visible or requests unrelated host permissions is a common review rejection. Ship a working popup or content script.
- No entitlements are needed for the basic case. Add an App Group only when the host app and the extension exchange data, and add it to both targets.
- `CODE_SIGNING_ALLOWED=NO` is fine for compile-only checks (`xcodebuild ... build`), never for device installs or archives.

---

## 11. Integrating into an existing FreeMilk iOS project

### 11.1 Before you start

- Work on a branch. Adding an app extension touches the project file, the embed phase and signing.
- Have the flowzz+ web extension files ready (`manifest.json`, scripts, popup, icons) — either from the `dist/` output of the flowzz+ build or from this repository's `Resources/` folder as a starting point.
- Decide the extension bundle identifier now (section 9) and the minimum iOS version (section 13).

### 11.2 Option A — add the target in Xcode (recommended)

1. Open the FreeMilk project in Xcode.
2. *File → New → Target… → iOS → Safari Extension*. Name it e.g. `SafariExtension` (or `FlowzzPlus Extension`).
3. If Xcode asks for a language, choose Swift. Decline tests.
4. Set the target's *Signing & Capabilities* team to the app's team, and the bundle identifier to `<FreeMilkAppBundleID>.SafariExtension`.
5. Set the deployment target to the app's minimum (or higher, but never higher than the app's).
6. Delete the template's generated `Resources` content and drop in the flowzz+ payload. Add `images` as a **folder reference** (drag with Option held, or *Add Files…* → *Create folder references*).
7. Confirm the target's `Info.plist` matches section 3 — in particular `NSExtensionPointIdentifier` and the module-qualified principal class.
8. Select the app target → *Build Phases* → confirm *Embed Foundation Extensions* lists the new `.appex` and shows **Embed & Sign**. Add the phase if Xcode did not.
9. Confirm the app target's *Dependencies* lists the extension target.
10. Build for a device, install, then enable the extension in *Settings → Safari → Extensions*.

### 11.3 Option B — generate a reference project with Apple's packager

If the Xcode version in use does not offer the Safari Extension target, generate a throwaway project with Apple's tool and copy the target configuration out of it:

```bash
xcrun safari-web-extension-packager "path/to/Resources" \
  --project-location /tmp/flowzz-ref \
  --app-name FlowzzRef \
  --bundle-identifier com.example.flowzzref \
  --ios-only --swift --copy-resources --no-open
```

(The tool was named `safari-web-extension-converter` before Xcode 14.3; both names accept the same options.) The generated project is a working reference for every setting in sections 1–6. Do not ship the generated app — transplant the settings into the FreeMilk project.

### 11.4 Option C — recreate the target by hand

Only if a template is unavailable: duplicate the target configuration described in sections 1–6 in `project.pbxproj` (product type, plists, build phases, embed phase, dependency, build settings). Compare against this repository's `project.pbxproj` and run `python3 tools/validate-project.py` here first to see what a consistent graph looks like.

### 11.5 Merge checklist

- [ ] Extension target exists, product type is app extension.
- [ ] Extension bundle id is `<host bundle id>.<suffix>`, no `+`, no spaces.
- [ ] `Info.plist` has `com.apple.Safari.web-extension` and a module-qualified principal class.
- [ ] `APPLICATION_EXTENSION_API_ONLY = YES`, `SKIP_INSTALL = YES`.
- [ ] Deployment target of the extension ≤ the app's.
- [ ] Host target has the extension in *Dependencies*.
- [ ] Host target embeds the `.appex` into `PlugIns` with *Code Sign On Copy*.
- [ ] `manifest.json` sits in the appex root and every path it references exists.
- [ ] `images/` is a folder reference, icons present.
- [ ] Version numbers of app and extension match.
- [ ] Same team/signing identity on both targets.
- [ ] Extension enabled manually on the test device.

### 11.6 Verify on device

1. Install and launch the app once.
2. *Settings → Safari → Extensions → flowzz+* → enable, and grant website access.
3. Safari → tap the extension's toolbar button → the popup renders.
4. Open the target site → the content script runs (Web Inspector console or visible effect).
5. If the popup is blank or the toolbar button does nothing, first check that the files exist in the built `.appex` (section 6). A missing resource fails silently.

---

## 12. Copy vs. recreate — the short version

**Copy these files.**

| From this repository | To FreeMilk | Notes |
| --- | --- | --- |
| `FlowzzPlus Extension/Resources/**` | The extension target's `Resources` folder | The whole web payload. Keep `images/` a folder reference. |
| `FlowzzPlus Extension/SafariWebExtensionHandler.swift` | The extension target's sources | Keep the class name, or update `NSExtensionPrincipalClass`. |
| `FlowzzPlus Extension/Info.plist` | The extension target | If the target already has a plist, merge the `NSExtension` dictionary and the bundle keys instead of replacing theirs. |
| `tools/validate-project.py` | Optional | Paths are relative to this repo's root; adapt `ROOT` if you reuse it. |
| `.github/workflows/validate.yml` | Optional | Static validation only; it cannot build iOS on Linux runners. |

**Do not copy these — recreate them in the FreeMilk project.**

| Item | Why |
| --- | --- |
| `FlowzzPlus.xcodeproj` | Belongs to this standalone app. The extension has to live in the FreeMilk project, with FreeMilk's targets, identifiers and signing. |
| The extension target itself | A target is a project object, not a file. Recreate it (section 1) and set its product type, module name and build settings. |
| Bundle identifiers | Project-specific. Host = the existing app; extension = host + suffix (section 9). |
| Build settings (`APPLICATION_EXTENSION_API_ONLY`, `SKIP_INSTALL`, `INFOPLIST_FILE`, `GENERATE_INFOPLIST_FILE`, deployment target, device family, runpaths, Swift version) | Stored in `project.pbxproj` per target; copying files never carries them. |
| *Embed Foundation Extensions* phase and its *Code Sign On Copy* attribute | Belongs to the host target's build phases (section 6). |
| Target dependency and container proxy | Host target's `dependencies` (section 4). |
| *Copy Bundle Resources* membership and the folder-reference flag for `images/` | A file's build membership is project state, not part of the file. Getting the folder-reference flag wrong breaks every icon path. |
| Team, provisioning, version numbers | Per-account and per-release (section 10). |
| `FlowzzPlus/FlowzzPlusApp.swift`, `FlowzzPlus/ContentView.swift`, `FlowzzPlus/Info.plist`, `Assets.xcassets` | Scaffold host app only. FreeMilk's app already exists. |
| Scheme | The shared scheme here builds this app; FreeMilk's project has its own. |

---

## 13. iOS and Safari constraints for the flowzz+ port

Relevant when the flowzz+ web extension is moved into this target. These are Safari/iOS platform limits, not scaffold decisions.

- **Manifest V3** works from Safari 15.4; V2 still works too. If the FreeMilk app supports iOS below 15.4, MV3 is off the table for those devices — and the extension cannot require a newer iOS than the app.
- **Background execution**: iOS never runs persistent background pages. Use a non-persistent background page, or a service worker where the deployment target supports it. Verify the service worker path against the minimum iOS version instead of assuming it.
- **`webRequest` is not available on iOS.** Content scripts plus `declarativeNetRequest` are the supported direction.
- **Storage**: `storage` is capped at 5 MB unless `unlimitedStorage` is granted; `storage.sync` behaves like local storage (no sync); `storage.session` requires Safari 16.4+.
- **Not supported**: `identity` (do OAuth in a tab instead), `update_url` (updates ship through the App Store), `externally_connectable.ids`, `devtools` before Safari 16, `scripting.registerContentScripts` before 16.4.
- **Manifest shape**: MV3 `web_accessible_resources` uses the object form with `resources` and `matches`; the MV2 flat string array only applies to a V2 manifest. Pick one manifest version and keep every key consistent with it.
- **`tabs`** requires host permission for the sites involved.
- **Site access** is granted per site by the user; an extension that requests broad host permissions shows a broader prompt and is reviewed more strictly.
- **No remote code** in MV3: bundle every script.
- **No `chrome.*`-only quirks** that Safari lacks (`chrome.runtime.getBackgroundPage`, `chrome.extension.getURL` in MV3). Safari exposes both `browser.*` and `chrome.*` namespaces.
- **`activeTab`** and `storage` are safe baseline permissions. flowzz+ additionally needs host access to the target site through `host_permissions` and a `content_scripts` entry for it.
- Keep the extension's own UI independent of the host app: on iOS the extension runs while the app is closed.

---

## 14. Validation

Performed on this repository (Linux, no Xcode):

| Check | Method | Result |
| --- | --- | --- |
| `project.pbxproj` syntax and object graph | OpenStep plist parser in `tools/validate-project.py`; every 24-hex object ID resolves | pass |
| Independent parser | `pbxproj` (mod-pbxproj) loads the project | pass |
| Target structure | two targets, `application` + `app-extension`, product paths `.app` / `.appex` | pass |
| Embedding | copy phase with `dstSubfolderSpec = 13`, appex present, `CodeSignOnCopy` set | pass |
| Target dependency | `PBXTargetDependency` + `PBXContainerItemProxy` point at the extension target | pass |
| Build settings | `APPLICATION_EXTENSION_API_ONLY`, `SKIP_INSTALL`, `SDKROOT`, module/runpath settings, deployment targets | pass |
| Bundle identifiers | extension prefixed by host id, valid characters, identical across configurations | pass |
| Version consistency | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` equal on both targets | pass |
| Info.plists | both parse, package types, `NSExtension` point and principal class | pass |
| Resources | all files referenced by Xcode exist on disk; manifest paths exist; icons present | pass |
| No custom browser engine | no `WKWebView` anywhere in the tree | pass |
| Negative test | deliberately broken project (wrong embed destination, wrong bundle id, missing icon) is rejected with three specific errors | pass |

Total: 172 automated checks (`python3 tools/validate-project.py`).

**Not performed**: no `xcodebuild`, no codesign, no archive, no App Store validation, no simulator or device run. No macOS or Xcode was available in the environment that produced this repository, so **an actual iOS build has not been performed**. Treat the project as statically verified, not build-verified.

To close that gap on a Mac:

```bash
xcodebuild -project FlowzzPlus.xcodeproj -scheme FlowzzPlus \
  -destination 'generic/platform=iOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build

APP=$(find ~/Library/Developer/Xcode/DerivedData -name FlowzzPlus.app -path '*Debug-iphoneos*' | head -1)
find "$APP/PlugIns" -maxdepth 3
plutil -p "$APP/PlugIns/FlowzzPlus Extension.appex/Info.plist"
```

Then set a team, install on a device and follow 11.6.

---

## 15. Known limitations

- Bundle identifiers, team and display name are placeholders; signing will fail until they are set.
- The web payload is a placeholder: one content script for `example.com`, an echo popup, no flowzz+ logic.
- iOS only. No macOS Safari extension target; a multiplatform app would need one target per platform, sharing the `Resources` folder.
- No app icon variants beyond the single 1024 px iOS icon, no localization, no tests, no App Store metadata.
- CI runs static validation only. iOS builds need a macOS runner with Xcode and a signing identity.
- The project was written against Xcode 14/15 project format (`objectVersion = 56`). Newer Xcode versions open and upgrade it, but the on-disk format then differs from this repository.
