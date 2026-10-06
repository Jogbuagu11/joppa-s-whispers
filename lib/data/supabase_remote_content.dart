// Newer content from the server: the `content_versions` table says what the
// latest release is, and the `content` storage bucket holds the bundle file.
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/data/content_repository.dart';

class SupabaseRemoteContent implements RemoteContent {
  final SupabaseClient _client;

  SupabaseRemoteContent(this._client);

  @override
  Future<({int version, String path})?> latest() async {
    final rows = await _client
        .from('content_versions')
        .select('version, storage_path')
        .order('version', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return (
      version: rows.first['version'] as int,
      path: rows.first['storage_path'] as String,
    );
  }

  @override
  Future<String> download(String path) async =>
      utf8.decode(await _client.storage.from('content').download(path));
}
