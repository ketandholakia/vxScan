import 'dart:typed_data';

import 'package:flutter_zxing/flutter_zxing.dart' as zxing;

import '../../domain/decoding/barcode_decoder.dart';

/// [BarcodeDecoder] backed by flutter_zxing (zxing-cpp via FFI).
class ZxingBarcodeDecoder implements BarcodeDecoder {
  ZxingBarcodeDecoder({zxing.Zxing? engine}) : _engine = engine ?? zxing.zx;

  final zxing.Zxing _engine;

  @override
  Future<List<BarcodeRead>> decodeImageFile(
    String path, {
    bool tryHarder = true,
    bool tryInverted = false,
  }) async {
    final zxing.Codes result = await _engine.readBarcodesImagePathString(
      path,
      zxing.DecodeParams(
        tryHarder: tryHarder,
        tryInverted: tryInverted,
        maxNumberOfSymbols: 10,
      ),
    );

    if (result.error != null && result.codes.isEmpty) {
      // A failed read (unreadable file, unsupported format) is reported as
      // "no codes found"; the caller decides how to surface that.
      return const <BarcodeRead>[];
    }

    return result.codes
        .where((zxing.Code code) => code.isValid && code.text != null)
        .map(_toRead)
        .toList(growable: false);
  }

  BarcodeRead _toRead(zxing.Code code) => BarcodeRead(
        text: code.text ?? '',
        format: code.format ?? zxing.Format.none,
        formatName: (code.format ?? zxing.Format.none).name,
        rawBytes: code.rawBytes,
        isInverted: code.isInverted,
        isMirrored: code.isMirrored,
        durationMs: code.duration,
      );

  @override
  EncodeOutput encodeToPng(
    String contents, {
    required int format,
    int width = 240,
    int height = 240,
    int margin = 0,
    BarcodeEcc ecc = BarcodeEcc.low,
  }) {
    final zxing.Encode encode = _engine.encodeBarcode(
      contents: contents,
      params: zxing.EncodeParams(
        format: format,
        width: width,
        height: height,
        margin: margin,
        eccLevel: _toZxingEcc(ecc),
      ),
    );

    if (!encode.isValid ||
        encode.data == null ||
        encode.width == null ||
        encode.height == null) {
      return EncodeOutput(error: encode.error ?? 'Encoding failed');
    }

    final Uint8List png = zxing.pngFromBytes(
      encode.data!,
      encode.width!,
      encode.height!,
    );
    return EncodeOutput(
      image: BarcodeImage(
        pngBytes: png,
        width: encode.width!,
        height: encode.height!,
      ),
    );
  }

  zxing.EccLevel _toZxingEcc(BarcodeEcc ecc) => switch (ecc) {
        BarcodeEcc.low => zxing.EccLevel.low,
        BarcodeEcc.medium => zxing.EccLevel.medium,
        BarcodeEcc.quartile => zxing.EccLevel.quartile,
        BarcodeEcc.high => zxing.EccLevel.high,
      };
}
