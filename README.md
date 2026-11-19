# vxScan

Offline-first barcode scanner and generator for Android. Every scan stays on
the device — the only permission the app requests is the camera.

**Status: all feature phases implemented (Phases 0–6 of the
[roadmap](docs/PLAN.md)). Remaining work is device-matrix testing and the
Play Store release pass — see [docs/RELEASE.md](docs/RELEASE.md).**

## Features

**Scanner**
- Live camera scanning (zxing-cpp via FFI) with torch, pinch-zoom and
  tap-to-focus
- Single mode and **batch mode** with scan sessions, a session counter and a
  duplicate policy (ignore / count / ask)
- **Gallery import** that decodes *every* code in the image, not just the
  first
- **Share-into-app**: send an image from any app to vxScan to decode it
- Try-harder / try-inverted decoding for damaged or inverted codes
- Beep + haptic on scan, optional auto-open of scanned URLs
- Format filter: choose which symbologies the scanner looks for

**Results and history**
- Content-type detection with smart actions: open URLs, call/email/SMS,
  copy Wi-Fi credentials, save contacts (vCard/MeCard), add calendar events,
  open maps, UPI payment intents, product/ISBN lookups
- Structured field view (SSID, contact phones, event dates…) plus raw text
  and a hex view of the raw bytes
- History with full-text search (FTS5), filters (content type, date range,
  favorites, tags), notes, favorites, multi-select delete, swipe-to-delete
  with undo

**Generator** (18 formats — QR, Data Matrix, Aztec, PDF417, Code
39/93/128, GS1-128, ITF/ITF-14, EAN-13/8, UPC-A/E, ISBN, Telepen, Codabar,
RM4SCC)
- Content templates: text, URL, Wi-Fi, contact, email, SMS, geo, event, UPI
- Per-format validation with automatic check-digit completion (EAN/UPC/ITF-14)
- Live preview with size, ink/paper colors, human-readable text toggle and
  QR error-correction level
- Save/share as **PNG**, **SVG** (vector) or **PDF** (vector); "Created"
  history screen

**Export, backup, settings**
- Export history to CSV / XLSX / PDF with scope selection
- JSON database backup + restore through the system file picker
- Settings: theme, default scan mode, feedback, duplicate policy, scan
  formats, history retention (favorites are never purged)

## Getting started

Requires the Flutter SDK with the Android toolchain, including the
**NDK** and **CMake** (the zxing-cpp engine is built natively).

```bash
flutter pub get
dart run build_runner build   # generates drift code
flutter run                   # on a connected device or emulator
```

- `minSdk` is 23 (required by flutter_zxing), compileSdk 36.
- `dart run tool/gen_icon.dart` regenerates the launcher icon art;
  `flutter_launcher_icons` / `flutter_native_splash` apply it.

## Project layout

```
lib/
  core/        theme, routing, DI providers, settings, feedback services
  data/        drift database (+ FTS5), repositories, engine implementation
  domain/      engine-agnostic types, content parsers, generator validators
  features/
    scanner/   camera screen, batch sessions, gallery + share-in inbox
    result/    scan detail with smart actions
    history/   list, search, filters, tags, multi-select
    generator/ format catalog, templates, preview, PNG/SVG/PDF export
    export/    CSV/XLSX/PDF export, backup + restore
    settings/  preferences screen
```

The scanning engine sits behind `BarcodeDecoder`
(`lib/domain/decoding/barcode_decoder.dart`); swapping or adding an engine
(e.g. an ML Kit fallback) means changing one provider in
`lib/core/di/providers.dart`, not the UI.

## Testing

```bash
flutter test            # 50+ unit + widget tests (parsers, validators, UI)
flutter analyze
flutter test integration_test   # on a device/emulator
```

The engine round-trip test (scanner → overflow menu) re-verifies encode +
decode on the device against [docs/FORMAT_MATRIX.md](docs/FORMAT_MATRIX.md).

## Docs

- [Full plan & roadmap](docs/PLAN.md)
- [Format capability matrix](docs/FORMAT_MATRIX.md)
- [Privacy policy](docs/PRIVACY_POLICY.md)
- [Release checklist](docs/RELEASE.md)
