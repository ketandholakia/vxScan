import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/parsing/content_type.dart';
import '../../domain/parsing/parsed_content.dart';

/// One tappable, type-appropriate action on the result screen.
class SmartAction {
  const SmartAction({required this.icon, required this.label, required this.run});

  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext context) run;
}

/// Builds the action row for a parsed payload. Order = prominence.
List<SmartAction> actionsFor(ParsedContent parsed) {
  switch (parsed.type) {
    case ContentType.url:
      final String? url = _normalizeUrl(parsed.first('url') ?? '');
      return <SmartAction>[
        if (url != null)
          SmartAction(
            icon: Icons.open_in_new,
            label: 'Open',
            run: (_) => _launch(url),
          ),
        _copy(parsed.first('url') ?? ''),
        _share('url', parsed.first('url') ?? ''),
      ];
    case ContentType.email:
      final String to = parsed.first('to') ?? '';
      return <SmartAction>[
        SmartAction(
          icon: Icons.mail_outline,
          label: 'Email',
          run: (_) => _launch(_mailto(parsed)),
        ),
        _copy(to),
        _share('email', to),
      ];
    case ContentType.phone:
      final String tel = parsed.first('tel') ?? '';
      return <SmartAction>[
        SmartAction(
          icon: Icons.call,
          label: 'Call',
          run: (_) => _launch('tel:$tel'),
        ),
        SmartAction(
          icon: Icons.sms_outlined,
          label: 'SMS',
          run: (_) => _launch('sms:$tel'),
        ),
        _copy(tel),
      ];
    case ContentType.sms:
      final String tel = parsed.first('tel') ?? '';
      final String body = parsed.first('body') ?? '';
      return <SmartAction>[
        SmartAction(
          icon: Icons.sms_outlined,
          label: 'Send SMS',
          run: (_) => _launch(
            body.isEmpty ? 'sms:$tel' : 'sms:$tel?body=${Uri.encodeComponent(body)}',
          ),
        ),
        _copy(tel),
        _share('sms', '$tel: $body'),
      ];
    case ContentType.wifi:
      final String ssid = parsed.first('ssid') ?? '';
      final String password = parsed.first('password') ?? '';
      return <SmartAction>[
        if (password.isNotEmpty)
          SmartAction(
            icon: Icons.password,
            label: 'Copy password',
            run: (BuildContext context) async {
              await Clipboard.setData(ClipboardData(text: password));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password copied')),
                );
              }
            },
          ),
        SmartAction(
          icon: Icons.wifi,
          label: 'Wi-Fi settings',
          run: (_) async {
            // Android no longer lets normal apps join networks directly;
            // hand off to the system Wi-Fi page with the SSID on the clipboard.
            await Clipboard.setData(ClipboardData(text: ssid));
            const AndroidIntent(
              action: 'android.settings.WIFI_SETTINGS',
            ).launch();
          },
        ),
        _copy(ssid, 'SSID copied'),
      ];
    case ContentType.vcard:
    case ContentType.mecard:
      return <SmartAction>[
        SmartAction(
          icon: Icons.person_add_alt,
          label: 'Save contact',
          run: (_) => _insertContact(parsed),
        ),
        _copy(parsed.title ?? ''),
        _share('contact', _payloadSummary(parsed)),
      ];
    case ContentType.event:
      return <SmartAction>[
        SmartAction(
          icon: Icons.event_available,
          label: 'Add to calendar',
          run: (_) => _insertEvent(parsed),
        ),
        _copy(parsed.title ?? ''),
        _share('event', _payloadSummary(parsed)),
      ];
    case ContentType.geo:
      final String lat = parsed.first('lat') ?? '';
      final String lng = parsed.first('lng') ?? '';
      return <SmartAction>[
        SmartAction(
          icon: Icons.map_outlined,
          label: 'Open maps',
          run: (_) => _launch('geo:$lat,$lng'),
        ),
        _copy('$lat,$lng'),
      ];
    case ContentType.product:
      final String? isbn = parsed.first('isbn');
      final String code = parsed.first('code') ?? isbn ?? '';
      return <SmartAction>[
        SmartAction(
          icon: Icons.travel_explore,
          label: 'Search web',
          run: (_) => _launch(
            'https://www.google.com/search?q=${Uri.encodeComponent(code)}',
          ),
        ),
        if (isbn != null)
          SmartAction(
            icon: Icons.menu_book,
            label: 'Find book',
            run: (_) => _launch(
              'https://www.google.com/search?tbm=b&q=${Uri.encodeComponent(isbn)}',
            ),
          )
        else
          SmartAction(
            icon: Icons.local_mall_outlined,
            label: 'Food facts',
            run: (_) => _launch(
              'https://world.openfoodfacts.org/product/$code',
            ),
          ),
        _copy(code),
      ];
    case ContentType.upi:
      final String vpa = parsed.first('vpa') ?? '';
      return <SmartAction>[
        SmartAction(
          icon: Icons.currency_rupee,
          label: 'Pay',
          run: (_) => _launch(
            'upi://pay?pa=${Uri.encodeComponent(vpa)}',
          ),
        ),
        _copy(vpa),
      ];
    case ContentType.text:
      return <SmartAction>[
        _copy(parsed.title ?? ''),
        _share('text', parsed.title ?? ''),
        SmartAction(
          icon: Icons.travel_explore,
          label: 'Search web',
          run: (_) => _launch(
            'https://www.google.com/search?q=${Uri.encodeComponent(parsed.title ?? '')}',
          ),
        ),
      ];
  }
}

SmartAction _copy(String text, [String message = 'Copied to clipboard']) =>
    SmartAction(
      icon: Icons.copy_outlined,
      label: 'Copy',
      run: (BuildContext context) async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );

SmartAction _share(String subject, String text) => SmartAction(
      icon: Icons.share_outlined,
      label: 'Share',
      run: (_) => SharePlus.instance.share(
        ShareParams(text: text, title: 'vxScan — $subject'),
      ),
    );

Future<void> _launch(String uri) async {
  final Uri target = Uri.parse(uri);
  if (await canLaunchUrl(target)) {
    await launchUrl(target, mode: LaunchMode.externalApplication);
  } else {
    await launchUrl(target); // Still try; the OS may handle it.
  }
}

Future<void> _insertContact(ParsedContent parsed) {
  // ACTION_INSERT hands off to the Contacts app — no contact permission
  // needed, and the user stays in control of what is written.
  final AndroidIntent intent = AndroidIntent(
    action: 'android.intent.action.INSERT',
    type: 'vnd.android.cursor.dir/contact',
    arguments: <String, dynamic>{
      'name': parsed.title ?? '',
      if (parsed.all('tel').isNotEmpty) 'phone': parsed.all('tel').first,
      if (parsed.all('email').isNotEmpty) 'email': parsed.all('email').first,
      if (parsed.all('org').isNotEmpty) 'company': parsed.all('org').first,
      if (parsed.all('address').isNotEmpty)
        'postal': parsed.all('address').first,
      if (parsed.all('url').isNotEmpty) 'website': parsed.all('url').first,
      if (parsed.all('note').isNotEmpty) 'notes': parsed.all('note').first,
    },
  );
  return intent.launch();
}

Future<void> _insertEvent(ParsedContent parsed) {
  DateTime? parse(String? iso) => iso == null ? null : DateTime.tryParse(iso);
  final AndroidIntent intent = AndroidIntent(
    action: 'android.intent.action.INSERT',
    type: 'vnd.android.cursor.item/event',
    arguments: <String, dynamic>{
      'title': parsed.title ?? '',
      if (parsed.all('location').isNotEmpty)
        'eventLocation': parsed.all('location').first,
      if (parsed.all('description').isNotEmpty)
        'description': parsed.all('description').first,
      if (parse(parsed.first('start')) case final DateTime begin)
        'beginTime': begin.millisecondsSinceEpoch,
      if (parse(parsed.first('end')) case final DateTime end)
        'endTime': end.millisecondsSinceEpoch,
    },
  );
  return intent.launch();
}

String? _normalizeUrl(String raw) {
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }
  if (raw.isNotEmpty) {
    return 'https://$raw'; // www.foo.com and bare domains.
  }
  return null;
}

String _mailto(ParsedContent parsed) {
  final Map<String, String> params = <String, String>{
    if (parsed.first('subject') case final String s) 'subject': s,
    if (parsed.first('body') case final String b) 'body': b,
    if (parsed.first('cc') case final String c) 'cc': c,
  };
  final String query = Uri(
    queryParameters: params.isEmpty ? null : params,
  ).query;
  return 'mailto:${parsed.first('to') ?? ''}${query.isEmpty ? '' : '?$query'}';
}

String _payloadSummary(ParsedContent parsed) {
  final List<String> lines = <String>[];
  parsed.fields.forEach((String key, List<String> values) {
    lines.add('$key: ${values.join(', ')}');
  });
  return lines.join('\n');
}
