import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/decoding/zxing_barcode_decoder.dart';
import '../../data/repositories/scan_repository.dart';
import '../../domain/decoding/barcode_decoder.dart';

final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final Provider<ScanRepository> scanRepositoryProvider =
    Provider<ScanRepository>((ref) => ScanRepository(ref.watch(databaseProvider)));

/// The scanning engine. Swap the implementation here to change engines
/// (e.g. an ML Kit fallback) without touching any UI code.
final Provider<BarcodeDecoder> barcodeDecoderProvider =
    Provider<BarcodeDecoder>((ref) => ZxingBarcodeDecoder());

/// Newest scans, watched live.
final StreamProvider<List<Scan>> scansProvider = StreamProvider<List<Scan>>(
  (ref) => ref.watch(scanRepositoryProvider).watchAll(),
);
