import 'dart:io';

import 'package:barcode/barcode.dart' as b;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart' show PdfColor;


import '../../core/di/providers.dart';
import '../../data/db/app_database.dart';
import '../../domain/generating/barcode_validator.dart';
import '../../domain/generating/generator_formats.dart';
import 'barcode_export.dart';
import 'content_templates.dart';

/// Barcode generator: pick a format and a content template, see a live
/// preview, then save/share as PNG, SVG or PDF.
class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  GeneratorFormat _format = generatorFormats.first;
  ContentTemplate _template = contentTemplates.first;
  final Map<String, String> _values = <String, String>{};
  final GlobalKey _previewKey = GlobalKey();

  // Options.
  double _size = 300;
  bool _drawText = true;
  int _eccIndex = 1; // medium default for QR
  static const List<Color> _fgPalette = <Color>[
    Colors.black,
    Color(0xFF00696F),
    Color(0xFF1A237E),
    Color(0xFF7B1FA2),
    Color(0xFFB71C1C),
  ];
  Color _fg = _fgPalette.first;
  Color _bg = Colors.white;

  // The ECC button states only matter for QR; keep one source of truth.
  b.Barcode get _barcode {
    if (_format.id == 'qr') {
      final BarcodeOptions options = BarcodeOptions(
        eccLow: _eccIndex == 0,
        eccMedium: _eccIndex == 1,
        eccQuartile: _eccIndex == 2,
        eccHigh: _eccIndex == 3,
      );
      return _format.barcode(options);
    }
    return _format.barcode(const BarcodeOptions());
  }

  String get _rawContent => _template.build(_values);
  String? get _validationError => validateContent(_format.id, _rawContent);
  String get _normalizedContent =>
      _validationError == null ? normalizeContent(_format.id, _rawContent) : '';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ContentTemplate> templates = contentTemplates
        .where((ContentTemplate t) => t.appliesTo(_format))
        .toList(growable: false);
    if (!templates.contains(_template)) {
      _template = templates.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Generate barcode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Format picker.
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Chip(label: Text(_format.label)),
            subtitle: _format.scanBack
                ? null
                : const Text('Not scannable back by this app’s engine'),
            trailing: const Icon(Icons.expand_more),
            onTap: _pickFormat,
          ),
          const Divider(),

          // Template picker.
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final ContentTemplate t in templates)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(t.icon, size: 18),
                      label: Text(t.label),
                      selected: _template.id == t.id,
                      onSelected: (_) => setState(() {
                        _template = t;
                        _values.clear();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Template fields.
          for (final TemplateField f in _template.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                decoration: InputDecoration(
                  labelText: f.label + (f.required ? ' *' : ''),
                  hintText: f.hint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: f.keyboardType,
                onChanged: (String v) => setState(() => _values[f.key] = v),
              ),
            ),

          // Validation feedback.
          if (_validationError != null && _rawContent.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _validationError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),

          const Divider(),

          // Options.
          _OptionsRow(
            size: _size,
            onSize: (double v) => setState(() => _size = v),
            drawText: _drawText,
            onDrawText: (bool v) => setState(() => _drawText = v),
            showTextToggle: !_format.is2D,
            fgPalette: _fgPalette,
            fg: _fg,
            bg: _bg,
            onFg: (Color c) => setState(() => _fg = c),
            onBg: (Color c) => setState(() => _bg = c),
            showEcc: _format.id == 'qr',
            eccIndex: _eccIndex,
            onEcc: (int i) => setState(() => _eccIndex = i),
          ),
          const Divider(),

          // Live preview.
          Center(
            child: Container(
              color: _bg,
              padding: const EdgeInsets.all(12),
              child: _normalizedContent.isEmpty
                  ? SizedBox(
                      key: _previewKey,
                      width: _size,
                      height: _size * (_format.is2D ? 1 : 0.4),
                      child: Center(
                        child: Text(
                          _template.label,
                          style: TextStyle(color: _fg),
                        ),
                      ),
                    )
                  : RepaintBoundary(
                      key: _previewKey,
                      child: BarcodeWidget(
                        data: _normalizedContent,
                        barcode: _barcode,
                        width: _size,
                        height: _size * (_format.is2D ? 1 : 0.4),
                        color: _fg,
                        backgroundColor: _bg,
                        drawText: _drawText,
                        errorBuilder: (BuildContext context, String? error) =>
                            Text('Cannot encode: $error',
                                style: TextStyle(color: _fg)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Exports.
          OverflowBar(
            alignment: MainAxisAlignment.spaceEvenly,
            overflowAlignment: OverflowBarAlignment.center,
            spacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _normalizedContent.isEmpty ? null : _savePng,
                icon: const Icon(Icons.image_outlined),
                label: const Text('PNG'),
              ),
              FilledButton.icon(
                onPressed: _normalizedContent.isEmpty ? null : _saveSvg,
                icon: const Icon(Icons.polyline_outlined),
                label: const Text('SVG'),
              ),
              FilledButton.icon(
                onPressed: _normalizedContent.isEmpty ? null : _savePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ],
          ),
          TextButton(
            onPressed: _normalizedContent.isEmpty ? null : _saveToHistory,
            child: const Text('Save to “Created” history'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFormat() async {
    final GeneratorFormat? picked = await showModalBottomSheet<GeneratorFormat>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final GeneratorFormat f in generatorFormats)
              ListTile(
                leading: Icon(
                  f.is2D ? Icons.grid_on : Icons.linear_scale,
                  size: 22,
                ),
                title: Text(f.label),
                subtitle: Text(f.category +
                    (f.scanBack ? '' : ' — cannot be scanned back by this app')),
                trailing:
                    f.id == _format.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(f),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _format = picked);
    }
  }

  String get _safeName =>
      _normalizedContent.length > 24
          ? _normalizedContent.substring(0, 24)
          : _normalizedContent;

  Future<void> _savePng() async {
    try {
      final File file = await capturePng(_previewKey, _safeName);
      await shareFile(file);
    } on Exception catch (e) {
      _showError('PNG export failed: $e');
    }
  }

  Future<void> _saveSvg() async {
    try {
      final File file = await exportSvg(
        _barcode,
        _normalizedContent,
        name: _safeName,
        width: _size,
        height: _size * (_format.is2D ? 1 : 0.4),
        color: _fg,
      );
      await shareFile(file);
    } on Exception catch (e) {
      _showError('SVG export failed: $e');
    }
  }

  Future<void> _savePdf() async {
    try {
      final File file = await exportPdf(
        _barcode,
        _normalizedContent,
        name: _safeName,
        caption: '${_format.label} — $_normalizedContent',
        width: _format.is2D ? 200 : _size * 0.9,
        height: _format.is2D ? 200 : _size * 0.3,
        color: PdfColor(_fg.r, _fg.g, _fg.b),
      );
      await shareFile(file);
    } on Exception catch (e) {
      _showError('PDF export failed: $e');
    }
  }

  Future<void> _saveToHistory() async {
    final GeneratedBarcodesCompanion row = GeneratedBarcodesCompanion.insert(
      format: _format.zxingFlag,
      content: _normalizedContent,
      optionsJson:
          '{"formatId":"${_format.id}","templateId":"${_template.id}","ecc":$_eccIndex}',
    );
    await ref.read(scanRepositoryProvider).insertGenerated(row);
    if (mounted) {
      context.push('/generated');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Size slider, colors, draw-text and QR ECC options, laid out compactly.
class _OptionsRow extends StatelessWidget {
  const _OptionsRow({
    required this.size,
    required this.onSize,
    required this.drawText,
    required this.onDrawText,
    required this.showTextToggle,
    required this.fgPalette,
    required this.fg,
    required this.bg,
    required this.onFg,
    required this.onBg,
    required this.showEcc,
    required this.eccIndex,
    required this.onEcc,
  });

  final double size;
  final ValueChanged<double> onSize;
  final bool drawText;
  final ValueChanged<bool> onDrawText;
  final bool showTextToggle;
  final List<Color> fgPalette;
  final Color fg;
  final Color bg;
  final ValueChanged<Color> onFg;
  final ValueChanged<Color> onBg;
  final bool showEcc;
  final int eccIndex;
  final ValueChanged<int> onEcc;

  static const List<String> _eccLabels = <String>['L', 'M', 'Q', 'H'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text('Size'),
            Expanded(
              child: Slider(
                value: size,
                min: 120,
                max: 480,
                divisions: 12,
                label: size.round().toString(),
                onChanged: onSize,
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            const Text('Ink'),
            const SizedBox(width: 8),
            for (final Color c in fgPalette)
              _ColorDot(color: c, selected: fg == c, onPick: onFg),
            const SizedBox(width: 16),
            const Text('Paper'),
            const SizedBox(width: 8),
            _ColorDot(color: Colors.white, selected: bg == Colors.white, onPick: onBg),
            _ColorDot(color: const Color(0xFFFFF8E1), selected: bg == const Color(0xFFFFF8E1), onPick: onBg),
            if (showTextToggle) ...<Widget>[
              const Spacer(),
              Switch(value: drawText, onChanged: onDrawText),
              const Text('Text'),
            ],
          ],
        ),
        if (showEcc)
          Row(
            children: <Widget>[
              const Text('QR error correction'),
              const SizedBox(width: 8),
              for (int i = 0; i < _eccLabels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_eccLabels[i]),
                    selected: eccIndex == i,
                    onSelected: (_) => onEcc(i),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onPick,
  });

  final Color color;
  final bool selected;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => onPick(color),
        customBorder: const CircleBorder(),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
