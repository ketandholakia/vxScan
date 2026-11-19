# Release checklist (Play Store)

Working notes for the Phase 6 release pass. Check items off as they are
completed on real devices.

## 0. One-time setup

- [ ] Create a keystore (`keytool -genkey -v -keystore vxscan.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vxscan`) and store it **outside** the repo; add `key.properties` + signing config to `android/app/build.gradle.kts` (see Flutter docs: "Sign the app").
- [ ] Register the app in Play Console; note the application ID is `com.vxscan.vxscan`.
- [ ] Privacy policy URL (content in [PRIVACY_POLICY.md](PRIVACY_POLICY.md)) hosted somewhere public.

## 1. Build

- [ ] `flutter build appbundle --release` — the Play Store artifact.
- [ ] Confirm the bundle contains **both** `arm64-v8a` and `armeabi-v7a` native libs (`libflutter_zxing.so`), and ideally build an `arm64`-only split (`--split-per-abi`) to shrink installs.
- [ ] Bump `version:` in `pubspec.yaml` (`0.1.0+1` → next) before every upload.
- [ ] R8/minify: default Flutter rules keep zxing working; verify a release build still scans + generates (the in-app round-trip test covers both).

## 2. Device matrix (real devices, not emulators)

| Device class | Model example | What to check |
|---|---|---|
| Samsung flagship | Galaxy S series | torch, zoom, batch mode, dark codes |
| Xiaomi/POCO | Redmi Note | camera focus hunting, low-light scan |
| Low-end (Go-ish) | 2–3 GB RAM device | decode speed on EAN-13, batch memory |

On each: scan → save → search → filter → export CSV → backup → uninstall → reinstall → restore. Also: share an image with a code from WhatsApp/Gallery into vxScan.

## 3. Benchmark (decode rate)

Use the printed sample sheet (Phase 0): for each format note `found / total`
and average decode time at default settings vs. try-harder. Record in
[FORMAT_MATRIX.md](FORMAT_MATRIX.md) → Device verification log.

## 4. Store listing

- [ ] App icon (assets/icon/app_icon.png is the source), feature graphic 1024×500.
- [ ] Phone screenshots: scanner, result with actions, history, generator, export.
- [ ] Short description (≤80 chars), e.g. "Offline barcode scanner & generator — QR, EAN, Data Matrix, and more".
- [ ] Data safety form: **No data collected, no data shared** (matches PRIVACY_POLICY.md; camera is processed on-device only).
- [ ] Content rating questionnaire (utility app, no ads).
- [ ] Target API level = Play's current requirement (Flutter default is current).

## 5. Rollout

- [ ] Internal test track first; install on 2+ devices from Play.
- [ ] Then closed testing, then staged production rollout 20% → 50% → 100%.
- [ ] Keep the debug keystore's `app-debug.apk` out of all distribution.
