import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart' show Format;

import 'package:vxscan/domain/parsing/content_parser.dart';

void main() {
  group('structured payloads', () {
    test('Wi-Fi with WPA password', () {
      final ParsedContent p = parseScanContent(
        'WIFI:T:WPA;S:HomeNet;P:secret\\;pass;H:false;;',
        Format.none,
      );
      expect(p.type, ContentType.wifi);
      expect(p.first('ssid'), 'HomeNet');
      expect(p.first('password'), 'secret;pass');
      expect(p.first('authtype'), 'WPA');
      expect(p.first('hidden'), 'no');
    });

    test('Wi-Fi quoted SSID and open network', () {
      final ParsedContent p =
          parseScanContent('WIFI:T:nopass;S:"My Guest";P:;;', Format.none);
      expect(p.type, ContentType.wifi);
      expect(p.first('ssid'), 'My Guest');
      expect(p.first('authtype'), 'nopass');
    });

    test('geo with query', () {
      final ParsedContent p =
          parseScanContent('geo:52.52,13.405?z=14', Format.none);
      expect(p.type, ContentType.geo);
      expect(p.first('lat'), '52.52');
      expect(p.first('lng'), '13.405');
      expect(p.first('zoom'), '14');
    });

    test('UPI payment string', () {
      final ParsedContent p = parseScanContent(
        'upi://pay?pa=shop@icici&pn=My%20Shop&am=250.00&cu=INR&tn=invoice%201',
        Format.none,
      );
      expect(p.type, ContentType.upi);
      expect(p.first('vpa'), 'shop@icici');
      expect(p.first('payeename'), 'My Shop');
      expect(p.first('amount'), '250.00');
      expect(p.first('note'), 'invoice 1');
    });

    test('mailto with subject and body', () {
      final ParsedContent p = parseScanContent(
        'mailto:hi@example.com?subject=Hello&body=Line%20one',
        Format.none,
      );
      expect(p.type, ContentType.email);
      expect(p.first('to'), 'hi@example.com');
      expect(p.first('subject'), 'Hello');
      expect(p.first('body'), 'Line one');
    });

    test('tel', () {
      final ParsedContent p = parseScanContent('tel:+49 30 123456', Format.none);
      expect(p.type, ContentType.phone);
      expect(p.first('tel'), '+49 30 123456');
    });

    test('sms with body param', () {
      final ParsedContent p =
          parseScanContent('sms:+49123?body=Hi%20there', Format.none);
      expect(p.type, ContentType.sms);
      expect(p.first('tel'), '+49123');
      expect(p.first('body'), 'Hi there');
    });

    test('smsto legacy variant', () {
      final ParsedContent p =
          parseScanContent('smsto:+49123:Hello world', Format.none);
      expect(p.type, ContentType.sms);
      expect(p.first('tel'), '+49123');
      expect(p.first('body'), 'Hello world');
    });
  });

  group('vCard', () {
    const String vcard = 'BEGIN:VCARD\r\n'
        'VERSION:3.0\r\n'
        'N:Doe;Jane;;;\r\n'
        'FN:Jane Doe\r\n'
        'ORG:Acme\r\n'
        'TITLE:Engineer\r\n'
        'TEL;TYPE=CELL:+49 111\r\n'
        'TEL;TYPE=WORK:+49 222\r\n'
        'EMAIL:jane@example.com\r\n'
        'ADR:;;Main St 1;Berlin;;10115;Germany\r\n'
        'URL:https://jane.example\r\n'
        'BDAY:1990-05-01\r\n'
        'END:VCARD';

    test('parses all fields', () {
      final ParsedContent p = parseScanContent(vcard, Format.none);
      expect(p.type, ContentType.vcard);
      expect(p.title, 'Jane Doe');
      expect(p.first('name'), 'Jane Doe');
      expect(p.all('tel'), <String>['+49 111', '+49 222']);
      expect(p.first('email'), 'jane@example.com');
      expect(p.first('org'), 'Acme');
      expect(p.first('address'), 'Main St 1, Berlin, 10115, Germany');
      expect(p.first('birthday'), '1990-05-01');
    });

    test('unfolds continuation lines', () {
      // RFC folding: CRLF + one space is removed on unfold, so a realistic
      // fold keeps its separating space at the end of the first line.
      const String folded = 'BEGIN:VCARD\n'
          'VERSION:2.1\n'
          'FN:Very Long \n'
          ' Contact Name\n'
          'TEL:+49123\n'
          'END:VCARD';
      final ParsedContent p = parseScanContent(folded, Format.none);
      expect(p.type, ContentType.vcard);
      expect(p.first('name'), 'Very Long Contact Name');
    });
  });

  group('MeCard', () {
    test('parses MECARD payload', () {
      final ParsedContent p = parseScanContent(
        'MECARD:N:Doe,Jane;TEL:5550100;TEL:5550101;EMAIL:j@x.io;ADR:Somewhere 1;URL:https://x.io;;',
        Format.none,
      );
      expect(p.type, ContentType.mecard);
      expect(p.title, 'Jane Doe');
      expect(p.all('tel'), <String>['5550100', '5550101']);
      expect(p.first('email'), 'j@x.io');
    });
  });

  group('calendar event', () {
    test('VEVENT with dates', () {
      final ParsedContent p = parseScanContent(
        'BEGIN:VEVENT\n'
        'SUMMARY:Team offsite\n'
        'DTSTART:20260301T090000Z\n'
        'DTEND:20260301T170000Z\n'
        'LOCATION:Berlin\n'
        'END:VEVENT',
        Format.none,
      );
      expect(p.type, ContentType.event);
      expect(p.title, 'Team offsite');
      expect(p.first('start'), '2026-03-01T09:00:00.000Z');
      expect(p.first('end'), '2026-03-01T17:00:00.000Z');
      expect(p.first('location'), 'Berlin');
    });

    test('all-day date form', () {
      final ParsedContent p = parseScanContent(
        'BEGIN:VEVENT\nSUMMARY:Holiday\nDTSTART;VALUE=DATE:20261224\nEND:VEVENT',
        Format.none,
      );
      expect(p.type, ContentType.event);
      expect(p.first('start'), '2026-12-24');
    });
  });

  group('URLs', () {
    test('https', () {
      final ParsedContent p =
          parseScanContent('https://example.com/page?x=1', Format.none);
      expect(p.type, ContentType.url);
      expect(p.title, 'example.com');
    });

    test('www shorthand', () {
      expect(parseScanContent('www.example.com', Format.none).type,
          ContentType.url);
    });

    test('bare domain', () {
      expect(parseScanContent('example.com/path', Format.none).type,
          ContentType.url);
    });

    test('plain text with a dot is not a URL', () {
      expect(parseScanContent('this is version 1.2 of the doc', Format.none)
          .type, ContentType.text);
    });
  });

  group('products', () {
    test('EAN-13 by format', () {
      final ParsedContent p = parseScanContent('5901234123457', Format.ean13);
      expect(p.type, ContentType.product);
      expect(p.title, 'EAN 5901234123457');
    });

    test('ISBN via 978 prefix', () {
      final ParsedContent p =
          parseScanContent('9783161484100', Format.ean13);
      expect(p.type, ContentType.product);
      expect(p.title, 'ISBN 9783161484100');
      expect(p.first('isbn'), '9783161484100');
    });

    test('UPC-A by format', () {
      expect(parseScanContent('036000291452', Format.upca).type,
          ContentType.product);
    });

    test('13 digits in a QR code is text, not a product', () {
      expect(parseScanContent('5901234123457', Format.qrCode).type,
          ContentType.text);
    });
  });

  group('bare heuristics', () {
    test('bare email', () {
      final ParsedContent p =
          parseScanContent('jane.doe+tag@example.co.uk', Format.none);
      expect(p.type, ContentType.email);
    });

    test('bare phone in a QR code', () {
      final ParsedContent p =
          parseScanContent('+49 30 1234567', Format.none);
      expect(p.type, ContentType.phone);
    });

    test('digits of wrong length stay text', () {
      expect(parseScanContent('12345', Format.none).type, ContentType.text);
    });

    test('empty payload', () {
      expect(parseScanContent('', Format.none).type, ContentType.text);
    });
  });

  group('round-trip through parsed_json', () {
    test('serialize and restore', () {
      final ParsedContent original = parseScanContent(
        'WIFI:T:WPA;S:Net;P:pw;H:false;;',
        Format.none,
      );
      final String json = original.toJson();
      final ParsedContent? restored = ParsedContent.fromJsonString(json);
      expect(restored, isNotNull);
      expect(restored!.type, ContentType.wifi);
      expect(restored.first('ssid'), 'Net');
      expect(restored.fields.keys.length, original.fields.keys.length);
    });

    test('corrupt JSON returns null', () {
      expect(ParsedContent.fromJsonString('not json'), isNull);
      expect(ParsedContent.fromJsonString(null), isNull);
    });
  });
}
