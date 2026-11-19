import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as b;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Export helpers: PNG via RepaintBoundary capture, SVG via package:barcode,
/// PDF as a vector drawing. Everything goes through the system share sheet —
/// no storage permission involved.

Future<File> _tempFile(String name, String ext) async {
  final Directory dir = await getTemporaryDirectory();
  final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
  return File('${dir.path}/vxscan_${name}_$stamp.$ext');
}

/// Converts a Flutter color to the 6-digit RGB int the SVG writer expects.
int colorToInt(ui.Color c) =>
    ((c.r * 255).round() << 16) | ((c.g * 255).round() << 8) | (c.b * 255).round();

/// Captures the [boundary] (the live preview) as a PNG file.
Future<File> capturePng(GlobalKey boundary, String name) async {
  final RenderObject? ro = boundary.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary) {
    throw StateError('Preview is not ready');
  }
  final ui.Image image = await ro.toImage(pixelRatio: 3.0);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw StateError('PNG encoding failed');
  }
  final File file = await _tempFile(name, 'png');
  return file.writeAsBytes(data.buffer.asUint8List());
}

/// Builds the SVG string for [barcode] rendering [content].
Future<File> exportSvg(
  b.Barcode barcode,
  String content, {
  required String name,
  required double width,
  required double height,
  required ui.Color color,
}) async {
  final String svg = barcode.toSvg(
    content,
    width: width,
    height: height,
    fontFamily: 'Helvetica',
    color: colorToInt(color),
  );
  final File file = await _tempFile(name, 'svg');
  return file.writeAsString(svg);
}

/// Vector PDF with the barcode and a small caption.
Future<File> exportPdf(
  b.Barcode barcode,
  String content, {
  required String name,
  required String caption,
  required double width,
  required double height,
  PdfColor color = PdfColors.black,
}) async {
  final pw.Document doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: <pw.Widget>[
            pw.BarcodeWidget(
              barcode: barcode,
              data: content,
              width: width,
              height: height,
              color: color,
              drawText: true,
            ),
            pw.SizedBox(height: 16),
            pw.Text(caption, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
  final File file = await _tempFile(name, 'pdf');
  return file.writeAsBytes(await doc.save());
}

/// Shares [file] through the system sheet; the user picks where it lands.
Future<void> shareFile(File file) {
  return SharePlus.instance.share(
    ShareParams(files: <XFile>[XFile(file.path)]),
  );
}
