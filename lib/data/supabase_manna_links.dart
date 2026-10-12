// The server's side of free Manna links (function `claim_manna_link`).
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/domain/manna_links.dart';

class SupabaseMannaLinks implements MannaLinkServer {
  final SupabaseClient _client;

  SupabaseMannaLinks(this._client);

  @override
  bool get signedIn => _client.auth.currentUser != null;

  @override
  Future<Object?> claim(String code) =>
      _client.rpc<Object?>('claim_manna_link', params: {'p_code': code});
}
