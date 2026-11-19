import 'package:barcode/barcode.dart';

/// One generatable symbology in the generator catalog.
class GeneratorFormat {
  const GeneratorFormat({
    required this.id,
    required this.label,
    required this.barcode,
    required this.zxingFlag,
    required this.scanBack,
    required this.category,
    this.sample = '',
    this.is2D = false,
  });

  /// Stable id for persistence ('qr', 'ean13', …).
  final String id;
  final String label;

  /// Pure-Dart writer from package:barcode — used for preview, SVG, PNG.
  final Barcode Function(BarcodeOptions options) barcode;

  /// zxing-cpp bit flag used when storing the row in the database and for
  /// the "can this app scan it back" hint. Some formats reuse the zxing
  /// family flag (ITF-14 → ITF, ISBN → EAN-13, GS1-128 → Code 128); custom
  /// high bits cover formats zxing does not know.
  final int zxingFlag;

  /// Whether vxScan's own engine can read this symbol back.
  final bool scanBack;
  final String category;
  final String sample;
  final bool is2D;

  /// Custom flags beyond the zxing range for barcode-package-only formats.
  static const int flagRm4Scc = 1 << 29;
}

/// Render options shared by preview and exports.
class BarcodeOptions {
  const BarcodeOptions({
    this.eccLow = false,
    this.eccMedium = true,
    this.eccQuartile = false,
    this.eccHigh = false,
  });

  final bool eccLow;
  final bool eccMedium;
  final bool eccQuartile;
  final bool eccHigh;
}

/// The generator catalog — every format package:barcode can write.
final List<GeneratorFormat> generatorFormats = <GeneratorFormat>[
  GeneratorFormat(
    id: 'qr',
    label: 'QR Code',
    barcode: (BarcodeOptions o) => Barcode.qrCode(
      errorCorrectLevel: o.eccLow
          ? BarcodeQRCorrectionLevel.low
          : o.eccMedium
              ? BarcodeQRCorrectionLevel.medium
              : o.eccQuartile
                  ? BarcodeQRCorrectionLevel.quartile
                  : BarcodeQRCorrectionLevel.high,
    ),
    zxingFlag: 1 << 13,
    scanBack: true,
    category: '2D',
    sample: 'Hello from vxScan',
    is2D: true,
  ),
  GeneratorFormat(
    id: 'datamatrix',
    label: 'Data Matrix',
    barcode: (BarcodeOptions o) => Barcode.dataMatrix(),
    zxingFlag: 1 << 7,
    scanBack: true,
    category: '2D',
    sample: 'VXSCAN-DM',
    is2D: true,
  ),
  GeneratorFormat(
    id: 'aztec',
    label: 'Aztec',
    barcode: (BarcodeOptions o) => Barcode.aztec(),
    zxingFlag: 1 << 0,
    scanBack: true,
    category: '2D',
    sample: 'VXSCAN-AZTEC',
    is2D: true,
  ),
  GeneratorFormat(
    id: 'pdf417',
    label: 'PDF417',
    barcode: (BarcodeOptions o) => Barcode.pdf417(),
    zxingFlag: 1 << 12,
    scanBack: true,
    category: '2D',
    sample: 'VXSCAN-PDF417',
    is2D: true,
  ),
  GeneratorFormat(
    id: 'code128',
    label: 'Code 128',
    barcode: (BarcodeOptions o) => Barcode.code128(),
    zxingFlag: 1 << 4,
    scanBack: true,
    category: '1D',
    sample: 'VXSCAN-128',
  ),
  GeneratorFormat(
    id: 'gs1_128',
    label: 'GS1-128',
    barcode: (BarcodeOptions o) => Barcode.gs128(),
    zxingFlag: 1 << 4,
    scanBack: true,
    category: '1D',
    sample: '(01)95012345678903',
  ),
  GeneratorFormat(
    id: 'code39',
    label: 'Code 39',
    barcode: (BarcodeOptions o) => Barcode.code39(),
    zxingFlag: 1 << 2,
    scanBack: true,
    category: '1D',
    sample: 'VXSCAN39',
  ),
  GeneratorFormat(
    id: 'code93',
    label: 'Code 93',
    barcode: (BarcodeOptions o) => Barcode.code93(),
    zxingFlag: 1 << 3,
    scanBack: true,
    category: '1D',
    sample: 'VXSCAN93',
  ),
  GeneratorFormat(
    id: 'codabar',
    label: 'Codabar',
    barcode: (BarcodeOptions o) => Barcode.codabar(),
    zxingFlag: 1 << 1,
    scanBack: true,
    category: '1D',
    sample: '40156',
  ),
  GeneratorFormat(
    id: 'itf',
    label: 'ITF',
    barcode: (BarcodeOptions o) => Barcode.itf(),
    zxingFlag: 1 << 10,
    scanBack: true,
    category: '1D',
    sample: '1234567890',
  ),
  GeneratorFormat(
    id: 'itf14',
    label: 'ITF-14',
    barcode: (BarcodeOptions o) => Barcode.itf14(drawBorder: true),
    zxingFlag: 1 << 10,
    scanBack: true,
    category: '1D',
    sample: '15400141288663',
  ),
  GeneratorFormat(
    id: 'ean13',
    label: 'EAN-13',
    barcode: (BarcodeOptions o) => Barcode.ean13(),
    zxingFlag: 1 << 9,
    scanBack: true,
    category: 'Product',
    sample: '590123412345',
  ),
  GeneratorFormat(
    id: 'ean8',
    label: 'EAN-8',
    barcode: (BarcodeOptions o) => Barcode.ean8(),
    zxingFlag: 1 << 8,
    scanBack: true,
    category: 'Product',
    sample: '9638507',
  ),
  GeneratorFormat(
    id: 'upca',
    label: 'UPC-A',
    barcode: (BarcodeOptions o) => Barcode.upcA(),
    zxingFlag: 1 << 14,
    scanBack: true,
    category: 'Product',
    sample: '03600029145',
  ),
  GeneratorFormat(
    id: 'upce',
    label: 'UPC-E',
    barcode: (BarcodeOptions o) => Barcode.upcE(),
    zxingFlag: 1 << 15,
    scanBack: true,
    category: 'Product',
    sample: '123456',
  ),
  GeneratorFormat(
    id: 'isbn',
    label: 'ISBN-13',
    barcode: (BarcodeOptions o) => Barcode.isbn(),
    zxingFlag: 1 << 9,
    scanBack: true,
    category: 'Product',
    sample: '978316148410',
  ),
  GeneratorFormat(
    id: 'telepen',
    label: 'Telepen',
    barcode: (BarcodeOptions o) => Barcode.telepen(),
    zxingFlag: 1 << 20,
    scanBack: true,
    category: '1D',
    sample: 'VXSCAN-TELEPEN',
  ),
  GeneratorFormat(
    id: 'rm4scc',
    label: 'RM4SCC (UK post)',
    barcode: (BarcodeOptions o) => Barcode.rm4scc(),
    zxingFlag: GeneratorFormat.flagRm4Scc,
    scanBack: false,
    category: 'Postal',
    sample: 'EC1A1BB',
  ),
];

GeneratorFormat formatById(String id) => generatorFormats
    .firstWhere((GeneratorFormat f) => f.id == id, orElse: () => generatorFormats.first);
