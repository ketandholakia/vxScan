// Tests that run on the host VM without native plugins.
//
// The scanner screen needs a camera and the database needs sqlite3, so those
// are covered by the Phase 6 integration pass on real devices; here we test
// the pure pieces. DB-backed tests arrive with the Phase 2 parsers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'package:vxscan/core/utils/hex.dart';
import 'package:vxscan/core/widgets/format_chip.dart';

void main() {
  group('toHex', () {
    test('formats bytes in pairs', () {
      expect(toHex(<int>[0x00, 0x0f, 0xff]), '00 0f ff');
    });

    test('truncates beyond the limit with a note', () {
      final String hex = toHex(List<int>.generate(100, (int i) => i % 256));
      expect(hex.contains('… (36 more bytes)'), isTrue);
    });

    test('handles empty input', () {
      expect(toHex(<int>[]), '');
    });
  });

  testWidgets('FormatChip shows the format name', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: FormatChip(format: Format.qrCode))),
      ),
    );
    expect(find.text('QR Code'), findsOneWidget);
  });
}
