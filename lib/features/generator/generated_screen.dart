import 'dart:io';

import 'package:barcode/barcode.dart' as b;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/widgets/format_chip.dart';
import '../../data/db/app_database.dart';
import '../../domain/generating/barcode_validator.dart';
import '../../domain/generating/generator_formats.dart';
import 'barcode_export.dart';

/// “Created” history: barcodes generated with the generator, newest first.
class GeneratedScreen extends ConsumerWidget {
  const GeneratedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Created codes')),
      body: StreamBuilder<List<GeneratedBarcode>>(
        stream: ref.read(scanRepositoryProvider).watchGenerated(),
        builder: (BuildContext context,
            AsyncSnapshot<List<GeneratedBarcode>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<GeneratedBarcode> items =
              snapshot.data ?? const <GeneratedBarcode>[];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Nothing generated yet.\nCreate one from the Generate tab.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final GeneratedBarcode item = items[index];
              return Dismissible(
                key: ValueKey<int>(item.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) =>
                    ref.read(scanRepositoryProvider).removeGenerated(item.id),
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline),
                ),
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: Text(
                    item.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_formatLabel(item)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDetail(context, ref, item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatLabel(GeneratedBarcode item) {
    final GeneratorFormat? f = generatorFormats
        .where((GeneratorFormat f) => f.zxingFlag == item.format)
        .firstOrNull;
    return f?.label ?? 'Format ${item.format}';
  }

  void _showDetail(BuildContext context, WidgetRef ref, GeneratedBarcode item) {
    final GeneratorFormat? f = generatorFormats
        .where((GeneratorFormat f) => f.zxingFlag == item.format)
        .firstOrNull;
    if (f == null) {
      return;
    }
    final b.Barcode barcode = f.barcode(const BarcodeOptions());
    final String normalized = normalizeContent(f.id, item.content);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  FormatChip(format: f.zxingFlag),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(scanRepositoryProvider).removeGenerated(item.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: BarcodeWidget(
                    data: normalized,
                    barcode: barcode,
                    width: 260,
                    height: f.is2D ? 260 : 110,
                    errorBuilder: (BuildContext context, String? error) =>
                        Text('Cannot render: $error'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.spaceEvenly,
                spacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final File file = await exportSvg(
                        barcode,
                        normalized,
                        name: f.id,
                        width: 300,
                        height: f.is2D ? 300 : 120,
                        color: Colors.black,
                      );
                      await shareFile(file);
                    },
                    icon: const Icon(Icons.polyline_outlined),
                    label: const Text('SVG'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final File file = await exportPdf(
                        barcode,
                        normalized,
                        name: f.id,
                        caption: '${f.label} — $normalized',
                        width: f.is2D ? 200 : 260,
                        height: f.is2D ? 200 : 90,
                      );
                      await shareFile(file);
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
