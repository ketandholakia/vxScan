import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/db/app_database.dart';
import '../../data/repositories/scan_repository.dart';

/// Turns history rows into CSV / XLSX / PDF files, and produces/consumes
/// JSON database backups. All files go through the share sheet or the
/// system file picker — no storage permissions.
class ExportService {
  ExportService(this._repo);

  final ScanRepository _repo;

  static const List<String> _columns = <String>[
    'Id',
    'Raw text',
    'Format',
    'Content type',
    'Source',
    'Created at',
    'Favorite',
    'Note',
  ];

  List<List<Object?>> _rows(List<Scan> scans) => <List<Object?>>[
        for (final Scan s in scans)
          <Object?>[
            s.id,
            s.rawText,
            s.format.name,
            s.contentType,
            s.source,
            s.createdAt.toLocal().toIso8601String(),
            s.isFavorite ? 'yes' : 'no',
            s.note ?? '',
          ],
      ];

  Future<File> exportCsv(List<Scan> scans) async {
    final String csv = Csv().encode(<List<Object?>>[
      _columns,
      ..._rows(scans),
    ]);
    return _writeFile('vxscan_history.csv', utf8.encode(csv));
  }

  Future<File> exportXlsx(List<Scan> scans) async {
    final Excel excel = Excel.createExcel();
    final String sheetName = excel.getDefaultSheet() ?? 'Scans';
    excel.appendRow(
      sheetName,
      <CellValue?>[for (final String c in _columns) TextCellValue(c)],
    );
    for (final List<Object?> row in _rows(scans)) {
      excel.appendRow(
        sheetName,
        <CellValue?>[
          for (final Object? v in row) TextCellValue(v?.toString() ?? ''),
        ],
      );
    }
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw StateError('XLSX encoding failed');
    }
    return _writeFile('vxscan_history.xlsx', bytes);
  }

  Future<File> exportPdf(List<Scan> scans) async {
    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => <pw.Widget>[
          pw.Header(child: pw.Text('vxScan history (${scans.length} scans)')),
          pw.TableHelper.fromTextArray(
            headers: _columns,
            data: <List<String>>[
              for (final List<Object?> row in _rows(scans))
                <String>[for (final Object? v in row) v?.toString() ?? ''],
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    return _writeFile('vxscan_history.pdf', await doc.save());
  }

  /// JSON backup of every table; saved through the SAF file picker.
  Future<bool> backup() async {
    final Map<String, Object?> data = await _repo.exportAll();
    final String json = const JsonEncoder.withIndent('  ').convert(data);
    final Uri? saved = await FilePicker.saveFile(
      dialogTitle: 'Save vxScan backup',
      fileName:
          'vxscan_backup_${DateTime.now().toIso8601String().split('T').first}.json',
      bytes: utf8.encode(json),
      mimeType: 'application/json',
    );
    return saved != null;
  }

  /// Restores a backup file picked by the user. Returns the number of
  /// restored scans, or null when the dialog was cancelled.
  Future<int?> restore() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      dialogTitle: 'Pick a vxScan backup',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (picked.isEmpty) {
      return null;
    }
    final Uint8List bytes = await picked.single.readAsBytes();
    final Map<String, Object?> data =
        jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final List<Object?> scans = data['scans'] as List<Object?>? ?? <Object?>[];
    await _repo.importAll(data);
    return scans.length;
  }

  Future<File> _writeFile(String name, List<int> bytes) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }
}
