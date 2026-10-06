import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The admin panel is published with the website from web/public/admin, a
/// copy of admin/. This fails if the copy is stale.
void main() {
  test('the published admin panel matches admin/', () {
    const files = [
      'index.html',
      'admin.js',
      'admin_more.js',
      'event_rules.js',
      'admin.css',
      'supabase.min.js',
    ];
    for (final name in files) {
      final source = File('admin/$name');
      final published = File('web/public/admin/$name');
      expect(source.existsSync(), isTrue, reason: 'admin/$name is missing');
      expect(
        published.existsSync(),
        isTrue,
        reason: 'web/public/admin/$name is missing',
      );
      expect(
        published.readAsStringSync(),
        source.readAsStringSync(),
        reason:
            'web/public/admin/$name is out of date: '
            'cp admin/$name web/public/admin/',
      );
    }
  });
}
