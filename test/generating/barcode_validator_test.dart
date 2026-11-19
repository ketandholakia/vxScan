import 'package:flutter_test/flutter_test.dart';

import 'package:vxscan/domain/generating/barcode_validator.dart';
import 'package:vxscan/domain/generating/generator_formats.dart';

void main() {
  group('check digit math', () {
    test('EAN-13 check digit', () {
      // 590123412345 → check digit 7
      expect(gs1CheckDigit('590123412345'), 7);
    });

    test('EAN-8 check digit', () {
      expect(gs1CheckDigit('9638507'), 4);
    });

    test('UPC-A check digit', () {
      expect(gs1CheckDigit('03600029145'), 2);
    });
  });

  group('EAN/UPC/ITF-14 validation', () {
    test('12-digit EAN-13 is completed with check digit', () {
      expect(validateContent('ean13', '590123412345'), isNull);
      expect(normalizeContent('ean13', '590123412345'), '5901234123457');
    });

    test('wrong length rejected', () {
      expect(validateContent('ean13', '1234'), isNotNull);
      expect(validateContent('ean13', '59012341234578'), isNotNull);
    });

    test('non-digits rejected', () {
      expect(validateContent('upca', '03600A29145'), isNotNull);
    });

    test('ITF needs even digits', () {
      expect(validateContent('itf', '1234567890'), isNull);
      expect(validateContent('itf', '12345'), isNotNull);
    });

    test('ITF-14 completes check digit', () {
      // 1540014128866 → check 4
      expect(normalizeContent('itf14', '1540014128866'), '15400141288664');
      expect(validateContent('itf14', '1540014128866'), isNull);
    });
  });

  group('charset validation', () {
    test('Code 39 rejects lowercase', () {
      expect(validateContent('code39', 'ABCD-123'), isNull);
      expect(validateContent('code39', 'abc'), isNotNull);
    });

    test('Code 128 accepts printable ASCII, rejects control chars', () {
      expect(validateContent('code128', 'Hello vScan-128'), isNull);
      expect(validateContent('code128', 'a\x01b'), isNotNull);
    });

    test('GS1-128 requires a leading AI', () {
      expect(validateContent('gs1_128', '(01)95012345678903'), isNull);
      expect(validateContent('gs1_128', '95012345678903'), isNotNull);
    });

    test('RM4SCC uppercase letters and digits only', () {
      expect(validateContent('rm4scc', 'EC1A1BB'), isNull);
      expect(validateContent('rm4scc', 'ec1a'), isNotNull);
      expect(validateContent('rm4scc', 'EC 1A'), isNotNull);
    });

    test('2D formats accept anything non-empty', () {
      expect(validateContent('qr', 'any thing 你好 🎉'), isNull);
      expect(validateContent('aztec', 'ABC'), isNull);
      expect(validateContent('datamatrix', 'x'), isNull);
    });

    test('empty content is never an error (still typing)', () {
      expect(validateContent('ean13', ''), isNull);
    });
  });

  group('format catalog', () {
    test('ids are unique and every format handles its sample content', () {
      final Set<String> ids = <String>{};
      for (final GeneratorFormat f in generatorFormats) {
        expect(ids.add(f.id), isTrue, reason: 'duplicate id ${f.id}');
        expect(
          validateContent(f.id, f.sample),
          isNull,
          reason: '${f.id} rejects its own sample "${f.sample}"',
        );
      }
    });

    test('RM4SCC is marked not scannable back', () {
      final GeneratorFormat rm =
          generatorFormats.firstWhere((GeneratorFormat f) => f.id == 'rm4scc');
      expect(rm.scanBack, isFalse);
    });
  });
}
