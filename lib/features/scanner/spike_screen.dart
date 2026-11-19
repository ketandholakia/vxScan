import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/di/providers.dart';
import '../../domain/decoding/barcode_decoder.dart';

/// Phase 0 engine spike: encode → PNG → decode round-trip per format.
///
/// Validates that the zxing-cpp FFI layer actually encodes and decodes on
/// the connected device, and doubles as the seed of the format capability
/// matrix (docs/FORMAT_MATRIX.md). Hide this screen once the generator UI
/// (Phase 4) ships.
class SpikeScreen extends ConsumerStatefulWidget {
  const SpikeScreen({super.key});

  @override
  ConsumerState<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeCase {
  const _SpikeCase(this.label, this.format, this.content, this.ecc);

  final String label;
  final int format;
  final String content;
  final BarcodeEcc ecc;
}

class _SpikeResult {
  _SpikeResult({required this.passed, this.image, String? detail})
      : detail = detail ?? (passed ? 'OK' : 'failed');

  _SpikeResult.fail(String reason)
      : passed = false,
        image = null,
        detail = reason;

  final bool passed;
  final Uint8List? image;
  final String detail;
}

class _SpikeScreenState extends ConsumerState<SpikeScreen> {
  static const List<_SpikeCase> _cases = <_SpikeCase>[
    _SpikeCase('QR Code', Format.qrCode, 'https://vxscan.example/?spike=1', BarcodeEcc.medium),
    _SpikeCase('DataMatrix', Format.dataMatrix, 'VXSCAN-DM-1234', BarcodeEcc.low),
    _SpikeCase('Aztec', Format.aztec, 'VXSCAN-AZTEC', BarcodeEcc.low),
    _SpikeCase('Code 128', Format.code128, 'VxScan-128-Spike', BarcodeEcc.low),
    _SpikeCase('Code 39', Format.code39, 'VXSCAN39', BarcodeEcc.low),
    _SpikeCase('EAN-13', Format.ean13, '5901234123457', BarcodeEcc.low),
    _SpikeCase('EAN-8', Format.ean8, '96385074', BarcodeEcc.low),
    _SpikeCase('UPC-A', Format.upca, '036000291452', BarcodeEcc.low),
    _SpikeCase('ITF', Format.itf, '1234567890', BarcodeEcc.low),
    _SpikeCase('Codabar', Format.codabar, 'A40156B', BarcodeEcc.low),
  ];

  bool _running = false;
  final Map<String, _SpikeResult> _results = <String, _SpikeResult>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engine round-trip test')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          FilledButton(
            onPressed: _running ? null : _runAll,
            child: Text(_running ? 'Running…' : 'Run round-trip tests'),
          ),
          const SizedBox(height: 8),
          for (final _SpikeCase c in _cases)
            _caseTile(c),
        ],
      ),
    );
  }

  Widget _caseTile(_SpikeCase c) {
    final _SpikeResult? r = _results[c.label];
    final IconData status = r == null
        ? Icons.remove_circle_outline
        : (r.passed ? Icons.check_circle : Icons.cancel);
    final Color color = r == null
        ? Theme.of(context).disabledColor
        : (r.passed ? Colors.green : Theme.of(context).colorScheme.error);

    return Card(
      child: ListTile(
        leading: r?.image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(r!.image!, width: 44, height: 44),
              )
            : const SizedBox(width: 44, height: 44),
        title: Text(c.label),
        subtitle: Text(
          r == null ? c.content : r.detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(status, color: color),
      ),
    );
  }

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    final BarcodeDecoder decoder = ref.read(barcodeDecoderProvider);
    final Directory tmp = await getTemporaryDirectory();

    for (final _SpikeCase c in _cases) {
      final _SpikeResult result = await _roundTrip(decoder, tmp, c);
      if (!mounted) {
        return;
      }
      setState(() => _results[c.label] = result);
    }

    if (mounted) {
      setState(() => _running = false);
    }
  }

  Future<_SpikeResult> _roundTrip(
    BarcodeDecoder decoder,
    Directory tmp,
    _SpikeCase c,
  ) async {
    final EncodeOutput encoded = decoder.encodeToPng(
      c.content,
      format: c.format,
      ecc: c.ecc,
      width: 240,
      height: 240,
    );
    if (!encoded.isValid) {
      return _SpikeResult.fail('encode: ${encoded.error}');
    }

    final File file = File(
      '${tmp.path}/vxscan_spike_${c.format}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    try {
      await file.writeAsBytes(encoded.image!.pngBytes);

      final List<BarcodeRead> decoded = await decoder.decodeImageFile(file.path);
      if (decoded.isEmpty) {
        return _SpikeResult.fail('decode: no code found');
      }
      final BarcodeRead first = decoded.first;
      final bool passed = first.text == c.content && first.format == c.format;
      return _SpikeResult(
        passed: passed,
        image: encoded.image!.pngBytes,
        detail: passed
            ? 'round-trip OK (${first.formatName})'
            : 'mismatch: "${first.text}"',
      );
    } on Exception catch (e) {
      return _SpikeResult.fail('io: $e');
    } finally {
      file.delete().ignore();
    }
  }
}
