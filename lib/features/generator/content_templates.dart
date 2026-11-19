import 'package:flutter/material.dart';

import '../../domain/generating/generator_formats.dart';

/// One input row in a template form.
class TemplateField {
  const TemplateField(
    this.key,
    this.label, {
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.hint,
  });

  final String key;
  final String label;
  final bool required;
  final TextInputType keyboardType;
  final String? hint;
}

/// A content pattern (Wi-Fi, contact, event…) that renders to a barcode
/// payload string. The same strings the Phase 2 parsers read back.
class ContentTemplate {
  const ContentTemplate({
    required this.id,
    required this.label,
    required this.icon,
    required this.fields,
    required this.build,
    this.appliesToAll = true,
    this.onlyFor2D = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<TemplateField> fields;
  final String Function(Map<String, String> values) build;

  /// True when the template works for every format (any 2D or Code-128-like).
  final bool appliesToAll;

  /// True when only 2D formats have room for this payload.
  final bool onlyFor2D;

  bool appliesTo(GeneratorFormat format) {
    if (appliesToAll) {
      return true;
    }
    return onlyFor2D ? format.is2D : false;
  }
}

/// Escapes ZXing payload special characters (Wi-Fi / MeCard convention).
String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll(':', r'\:');

/// vCard fields must not contain raw newlines in values.
String _flatten(String value) => value.replaceAll('\n', ' ').trim();

final List<ContentTemplate> contentTemplates = <ContentTemplate>[
  ContentTemplate(
    id: 'text',
    label: 'Text',
    icon: Icons.subject,
    fields: <TemplateField>[
      TemplateField('content', 'Content', required: true, hint: 'Anything'),
    ],
    build: (Map<String, String> v) => v['content'] ?? '',
  ),
  ContentTemplate(
    id: 'url',
    label: 'URL',
    icon: Icons.link,
    fields: <TemplateField>[
      TemplateField('url', 'URL', required: true, hint: 'https://example.com'),
    ],
    build: (Map<String, String> v) => (v['url'] ?? '').trim(),
  ),
  ContentTemplate(
    id: 'wifi',
    label: 'Wi-Fi',
    icon: Icons.wifi,
    fields: <TemplateField>[
      TemplateField('ssid', 'Network name (SSID)', required: true),
      TemplateField('password', 'Password'),
      TemplateField('authtype', 'Security', hint: 'WPA / WEP / nopass'),
    ],
    build: (Map<String, String> v) {
      final String auth = (v['authtype'] ?? 'WPA').trim().toUpperCase();
      final String type =
          auth.isEmpty || auth == 'WPA' || auth == 'WPA2' ? 'WPA' : (auth == 'WEP' ? 'WEP' : 'nopass');
      final String password = type == 'nopass' ? '' : (v['password'] ?? '');
      return 'WIFI:T:$type;S:${_escape((v['ssid'] ?? '').trim())};'
          'P:${_escape(password)};H:false;;';
    },
  ),
  ContentTemplate(
    id: 'vcard',
    label: 'Contact',
    icon: Icons.person_outline,
    fields: <TemplateField>[
      TemplateField('name', 'Full name', required: true),
      TemplateField('tel', 'Phone'),
      TemplateField('email', 'Email'),
      TemplateField('org', 'Organization'),
    ],
    build: (Map<String, String> v) {
      final String name = _flatten(v['name'] ?? '');
      final List<String> nameParts = name.split(' ');
      final String last = nameParts.length > 1 ? nameParts.last : name;
      final String first = nameParts.length > 1 ? nameParts.first : '';
      return <String>[
        'BEGIN:VCARD',
        'VERSION:3.0',
        'N:$last;$first;;;',
        'FN:$name',
        if ((v['tel'] ?? '').isNotEmpty) 'TEL;TYPE=CELL:${_flatten(v['tel']!)}',
        if ((v['email'] ?? '').isNotEmpty) 'EMAIL:${_flatten(v['email']!)}',
        if ((v['org'] ?? '').isNotEmpty) 'ORG:${_flatten(v['org']!)}',
        'END:VCARD',
      ].join('\n');
    },
  ),
  ContentTemplate(
    id: 'email',
    label: 'Email',
    icon: Icons.mail_outline,
    fields: <TemplateField>[
      TemplateField('to', 'To', required: true, keyboardType: TextInputType.emailAddress),
      TemplateField('subject', 'Subject'),
      TemplateField('body', 'Message'),
    ],
    build: (Map<String, String> v) {
      final String subject = _flatten(v['subject'] ?? '');
      final String body = _flatten(v['body'] ?? '');
      final String query = <String>[
        if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
        if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
      ].join('&');
      final String to = (v['to'] ?? '').trim();
      return 'mailto:$to${query.isEmpty ? '' : '?$query'}';
    },
  ),
  ContentTemplate(
    id: 'sms',
    label: 'SMS',
    icon: Icons.sms_outlined,
    fields: <TemplateField>[
      TemplateField('number', 'Phone number', required: true, keyboardType: TextInputType.phone),
      TemplateField('message', 'Message'),
    ],
    build: (Map<String, String> v) =>
        'SMSTO:${(v['number'] ?? '').trim()}:${_flatten(v['message'] ?? '')}',
  ),
  ContentTemplate(
    id: 'geo',
    label: 'Location',
    icon: Icons.place_outlined,
    fields: <TemplateField>[
      TemplateField('lat', 'Latitude', required: true, keyboardType: TextInputType.number),
      TemplateField('lng', 'Longitude', required: true, keyboardType: TextInputType.number),
    ],
    build: (Map<String, String> v) =>
        'geo:${(v['lat'] ?? '').trim()},${(v['lng'] ?? '').trim()}',
  ),
  ContentTemplate(
    id: 'event',
    label: 'Event',
    icon: Icons.event_outlined,
    fields: <TemplateField>[
      TemplateField('title', 'Title', required: true),
      TemplateField('start', 'Start (yyyy-MM-dd HH:mm)', required: true),
      TemplateField('end', 'End (yyyy-MM-dd HH:mm)'),
      TemplateField('location', 'Location'),
    ],
    build: (Map<String, String> v) {
      String? icsDate(String raw) {
        final DateTime? dt =
            DateTime.tryParse(raw.trim().replaceAll(' ', 'T'));
        if (dt == null) {
          return null;
        }
        return '${dt.toUtc().toIso8601String().replaceAll(RegExp(r"[-:](?=\d)"), "").split(".")[0]}Z';
      }

      final String? start = icsDate(v['start'] ?? '');
      if (start == null) {
        return (v['title'] ?? '').trim(); // Fall back to plain text on bad dates.
      }
      return <String>[
        'BEGIN:VEVENT',
        'SUMMARY:${_flatten(v['title'] ?? '')}',
        'DTSTART:$start',
        if (icsDate(v['end'] ?? '') case final String end) 'DTEND:$end',
        if ((v['location'] ?? '').isNotEmpty)
          'LOCATION:${_flatten(v['location']!)}',
        'END:VEVENT',
      ].join('\n');
    },
  ),
  ContentTemplate(
    id: 'upi',
    label: 'UPI',
    icon: Icons.currency_rupee,
    fields: <TemplateField>[
      TemplateField('vpa', 'Payee UPI ID (pa)', required: true),
      TemplateField('name', 'Payee name'),
      TemplateField('amount', 'Amount'),
      TemplateField('note', 'Note'),
    ],
    build: (Map<String, String> v) {
      final Map<String, String> params = <String, String>{
        'pa': (v['vpa'] ?? '').trim(),
        if ((v['name'] ?? '').isNotEmpty) 'pn': _flatten(v['name']!),
        if ((v['amount'] ?? '').isNotEmpty) 'am': (v['amount'] ?? '').trim(),
        'cu': 'INR',
        if ((v['note'] ?? '').isNotEmpty) 'tn': _flatten(v['note']!),
      };
      final String query = params.entries
          .map((MapEntry<String, String> e) =>
              '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      return 'upi://pay?$query';
    },
  ),
];
