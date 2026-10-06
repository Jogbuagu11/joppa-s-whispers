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
      // The published page names its files from the site's root
      // (/admin/admin.js), so it works at /admin, /admin/ and
      // /admin/index.html alike; otherwise the two are identical.
      final expected = name == 'index.html'
          ? source
                .readAsStringSync()
                .replaceAll('href="admin.css"', 'href="/admin/admin.css"')
                .replaceAllMapped(
                  RegExp(r'src="([a-z_.]+\.js)"'),
                  (m) => 'src="/admin/${m[1]}"',
                )
          : source.readAsStringSync();
      expect(
        published.readAsStringSync(),
        expected,
        reason:
            'web/public/admin/$name is out of date: '
            'cp admin/$name web/public/admin/',
      );
    }
  });
}
