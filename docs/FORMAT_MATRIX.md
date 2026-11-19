# Format capability matrix

Which symbologies vxScan can **read** and **generate**. This is living
documentation: the round-trip test (scanner → overflow menu →
"Engine round-trip test") re-verifies the *Encode ✓* column on any connected
device. Re-run it after upgrading `flutter_zxing` and record the results here.

Source of the initial data: `flutter_zxing` 3.1.1
(`lib/src/models/format.dart`), which is zxing-cpp under the hood.

## Matrix

| Format           | Read | Generate (zxing) | Notes                                        |
| ---------------- | :--: | :--------------: | -------------------------------------------- |
| QR Code          | ✅   | ✅               | ECC levels L/M/Q/H supported                 |
| Micro QR Code    | ✅   | ➖               | writer exists in zxing-cpp but not wired in flutter_zxing 3.1.1 |
| rMQR Code        | ✅   | ➖               | same as above                                |
| Data Matrix      | ✅   | ✅               |                                              |
| Aztec            | ✅   | ✅               | ECC levels supported                         |
| PDF417           | ✅   | ❌               | not exposed by flutter_zxing 3.1.1's writer  |
| MicroPDF417      | ✅   | ❌               | explicitly read-only in flutter_zxing        |
| Code 128         | ✅   | ✅               |                                              |
| Code 39          | ✅   | ✅               |                                              |
| Code 93          | ✅   | ✅               |                                              |
| Codabar          | ✅   | ✅               |                                              |
| ITF              | ✅   | ✅               | even number of digits required               |
| EAN-13           | ✅   | ✅               | check digit required for encoding            |
| EAN-8            | ✅   | ✅               | check digit required for encoding            |
| UPC-A            | ✅   | ✅               | check digit required for encoding            |
| UPC-E            | ✅   | ✅               |                                              |
| GS1 DataBar      | ✅   | ❌               | read-only                                    |
| GS1 DataBar Exp. | ✅   | ❌               | read-only                                    |
| GS1 DataBar Ltd. | ✅   | ❌               | explicitly read-only in flutter_zxing        |
| Telepen          | ✅   | ❌               | explicitly read-only in flutter_zxing        |
| MaxiCode         | ✅   | ❌               |                                              |
| DX Film Edge     | ✅   | ❌               | explicitly read-only in flutter_zxing        |

Legend: ✅ supported · ❌ unsupported by this engine · ➖ possible in principle,
not wired up.

## Filling the gaps (Phase 4)

The pure-Dart [`barcode`](https://pub.dev/packages/barcode) package can
**generate** additional formats zxing-cpp cannot write (e.g. GS1-128,
ITF-14, RM4SCC postal codes); it is already a dependency. Where a format is
only in `barcode`, the generator UI must mark it "cannot be scanned back by
this app's engine" so users are not surprised.

## Not covered by any bundled engine

- Postal formats beyond what `barcode` writes (e.g. Intelligent Mail) on the
  read side — unlikely to be needed; revisit if a user asks.

## Device verification log

| Date | Device / Android | Round-trip result | Notes |
| ---- | ---------------- | ----------------- | ----- |
| 2026-11-19 | User's Android phone | App installed and working (user-verified) | Full install + usage check on a real device. Per-format round-trip results can be added after running the in-app "Engine round-trip test". |
