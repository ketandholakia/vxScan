# vxScan — Flutter Barcode App (Android): Detailed Plan

Chosen approach: ZXing engine, local SQLite storage, as many generator
formats as possible, plus gallery scan, batch scan, export/share and smart
actions.

## 1. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Scan and decode | `flutter_zxing` (zxing-cpp via FFI) | Native speed, built-in camera reader, decodes from image files, and also encodes |
| Extra generators | `barcode` (pure Dart) | Covers formats zxing-cpp can't write (Telepen, RM4SCC, GS1-128, ITF-14 and others) |
| Rendering and save | `barcode_widget`, `RepaintBoundary` to PNG, `svg` output | Preview, export image, vector output |
| Database | `drift` (SQLite) | Typed queries, migrations, streams, full-text search |
| State management | Riverpod | Simple and testable |
| Gallery scan | `image_picker` + `flutter_zxing` image decode | No storage permission needed |
| Export and share | `csv`, `excel`, `pdf`, `share_plus`, `path_provider` | CSV, XLSX, PDF, share sheet |
| Smart actions | `url_launcher`, `flutter_contacts`, Android intents (`android_intent_plus`), `vcard_parser` | Open links, add contact, event, Wi-Fi |
| Feedback | `vibration`, `audioplayers` | Beep and haptic on scan |
| Navigation | `go_router` | Standard routing |

**Honest note on "everything":** no single library reads and writes every symbology.

- **Reading:** zxing-cpp covers the common set, including QR, Micro QR, Data
  Matrix, Aztec, PDF417, Code 39/93/128, Codabar, ITF, EAN/UPC and GS1
  DataBar. MaxiCode and some postal codes are limited or absent.
- **Writing:** zxing-cpp writes QR, Aztec, Data Matrix, PDF417, Code 39/93/
  128, Codabar, ITF and EAN/UPC. The `barcode` package fills in several
  others.
- Build a **format capability matrix** in Phase 0 by testing each format with
  real samples, then publish the supported list in the app.
  (See [FORMAT_MATRIX.md](FORMAT_MATRIX.md).)

## 2. Features

**Scanner**

- Live camera scan with an overlay, torch, pinch zoom and tap-to-focus.
- Single mode (stop at first hit) and continuous/batch mode (keep scanning,
  with a session counter).
- Duplicate policy in batch mode: ignore, count, or ask.
- Scan from a gallery image, including multiple codes in one image, and
  share-into-app from other apps.
- Try-harder, inverted and rotated decoding options for damaged or small
  codes.
- Beep and haptic on scan, and an auto-open-link option.

**Result and history**

- Detail screen with raw text, format, parsed content type, timestamp and a
  preview of the code.
- Auto-detect content type: URL, text, email, phone, SMS, Wi-Fi, vCard/
  MeCard, calendar event, geo, product code (EAN/UPC/ISBN), UPI payment
  string, and generic.
- Smart actions per type: open, call, email, add contact, add event, join
  Wi-Fi, copy, share, web search or product lookup.
- History list with search, filters (format, type, date, favorites), tags,
  notes, favorites, swipe to delete, multi-select, and undo.
- Hex/binary view of raw bytes for non-text codes.

**Generator**

- Pick a format, then a content template (text, URL, Wi-Fi, vCard, email,
  SMS, geo, event, UPI) with a live preview.
- Per-format validation (EAN-13 check digit calculation, Code 39 allowed
  characters, ITF even digits and so on) with clear error messages.
- Options: size, colors, margin, show/hide human-readable text, QR error
  correction level.
- Save as PNG, SVG or PDF, share, and keep in a "Created" history.

**Export and settings**

- Export history to CSV, XLSX or PDF, with a date or filter range.
- Backup and restore the database to a file.
- Settings: theme, default scan mode, sounds, history retention, formats
  enabled for scanning.

## 3. Architecture

Feature-first clean structure:

```
lib/
  core/        (theme, routing, utils, errors)
  data/        (drift db, DAOs, repositories)
  domain/      (entities, content parsers, validators)
  features/
    scanner/   (camera, gallery decode, batch session)
    result/    (detail, smart actions)
    history/   (list, search, filters, tags)
    generator/ (format picker, templates, preview, save)
    export/    (csv, xlsx, pdf, backup)
    settings/
```

Keep the scanning engine behind an interface (`BarcodeDecoder`). If an ML Kit
fallback is wanted later, it can be added without touching the UI.

## 4. Database schema

- `scans`: id, raw_text, raw_bytes (blob), format, content_type, parsed_json,
  source (camera, gallery, share), created_at, is_favorite, note, session_id
- `tags`: id, name. `scan_tags`: scan_id, tag_id
- `sessions`: id, name, started_at, ended_at (for batch scans)
- `generated`: id, format, content, options_json, created_at
- An FTS index on raw_text and note for fast search
- Indexes on created_at, format and favorite
- Migrations are versioned from day one

## 5. Phased roadmap (about 8 to 9 weeks solo)

**Phase 0: Setup and spike (Week 1)** — project, lint rules, CI build; spike
flutter_zxing (scan, gallery decode, encode) on 2–3 real devices; format
capability matrix and a folder of test barcodes.

**Phase 1: Core scanning and storage (Weeks 2–3)** — camera permission flow,
scanner screen, torch and zoom; drift database + repository saving every
scan; result screen and basic history list.

**Phase 2: Content parsing and smart actions (Week 4)** — parsers per content
type with unit tests; action buttons, contact/Wi-Fi/calendar intents;
optional online product lookup (Open Food Facts), off by default.

**Phase 3: Batch scan and gallery (Week 5)** — continuous mode, sessions,
duplicate policy; gallery import with multi-code results and share-into-app.

**Phase 4: Generator (Weeks 6–7)** — format picker, templates, validation,
live preview; save as PNG/SVG/PDF and share; created-history screen.

**Phase 5: Export, backup and polish (Week 8)** — CSV/XLSX/PDF export,
database backup/restore; search, filters, tags, notes, settings, theming,
accessibility; app icon, splash, empty states, localization scaffolding.

**Phase 6: Test and release (Week 9)** — device matrix testing, performance
profiling, crash reporting decision (local log), privacy policy, Play Store
listing, AAB, closed test, production.

## 6. Testing strategy

- Unit tests: parsers, validators and check-digit logic, repositories.
- Widget tests: history, generator form and result screen.
- Integration tests: scan, save, open from history, export.
- Decode benchmark: run the barcode sample set and record success rate and
  time per format, to compare against ML Kit later if needed.
- Real-device checks on low-end phones, since decode speed varies a lot.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| ZXing is slower or weaker on blurry, curved or tiny codes | Try-harder mode, higher camera resolution, tap-to-focus, optional ML Kit fallback behind the decoder interface |
| Some formats have no encoder | Capability matrix in Phase 0, with unsupported formats marked read-only in the UI |
| NDK/FFI build problems | Pin NDK and CMake versions in CI |
| Camera differences across OEMs | Test on Samsung, Xiaomi and a low-end device |
| Local-only means data loss if the phone is lost | Backup and restore file, with a reminder prompt |
| Play Store policy for camera apps | Declare permissions clearly and publish a privacy policy (no data leaves the device) |

## 8. Release checklist

- Target the current Android API level required by Play Store.
- Request only the CAMERA permission (gallery uses the system picker; saving
  uses MediaStore or the share sheet).
- ProGuard/R8 checks for the native library, and 64-bit ABI builds.
- Screenshots, short description and a privacy policy page.
