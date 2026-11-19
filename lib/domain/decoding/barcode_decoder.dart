import 'dart:typed_data';

/// One successfully decoded barcode, in engine-agnostic terms.
class BarcodeRead {
  const BarcodeRead({
    required this.text,
    required this.format,
    required this.formatName,
    this.rawBytes,
    this.isInverted = false,
    this.isMirrored = false,
    this.durationMs = 0,
  });

  final String text;

  /// Engine-specific format identifier (zxing-cpp `Format` bit flag).
  /// Kept as an int so the domain layer does not depend on the engine.
  final int format;

  final String formatName;
  final Uint8List? rawBytes;
  final bool isInverted;
  final bool isMirrored;
  final int durationMs;
}

/// A rendered barcode image (one bit per pixel, luminance-encoded).
class BarcodeImage {
  const BarcodeImage({required this.pngBytes, required this.width, required this.height});

  /// PNG-encoded image, ready for `Image.memory`.
  final Uint8List pngBytes;
  final int width;
  final int height;
}

/// Error-correction level for the 2D formats that support it (QR, Aztec, PDF417).
enum BarcodeEcc { low, medium, quartile, high }

/// Abstraction over the barcode engine.
///
/// The live camera stream is handled by the engine's own reader widget
/// (`ReaderWidget`); this interface covers everything the app does with
/// barcodes outside the viewfinder: decoding image files (gallery, share-in)
/// and rendering codes. Keeping the engine behind it means a fallback engine
/// (e.g. ML Kit) can be swapped in later without touching the UI.
abstract interface class BarcodeDecoder {
  /// Decodes every barcode found in the image file at [path].
  ///
  /// Returns an empty list when the image contains no recognizable code.
  Future<List<BarcodeRead>> decodeImageFile(
    String path, {
    bool tryHarder = true,
    bool tryInverted = false,
  });

  /// Renders [contents] as a barcode in [format] (zxing-cpp `Format` flag)
  /// and returns it as a PNG. [EncodeOutput.error] carries the engine's
  /// reason when encoding failed (e.g. content too long for the format).
  EncodeOutput encodeToPng(
    String contents, {
    required int format,
    int width = 240,
    int height = 240,
    int margin = 0,
    BarcodeEcc ecc = BarcodeEcc.low,
  });
}

/// Outcome of an encode attempt: exactly one of [image] or [error] is set.
class EncodeOutput {
  const EncodeOutput({this.image, this.error});

  final BarcodeImage? image;
  final String? error;

  bool get isValid => image != null;
}
