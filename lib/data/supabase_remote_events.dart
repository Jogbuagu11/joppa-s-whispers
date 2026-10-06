// The server's list of events (table `events`).
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/data/events_repository.dart';

class SupabaseRemoteEvents implements RemoteEvents {
  final SupabaseClient _client;

  SupabaseRemoteEvents(this._client);

  @override
  Future<List<Object?>> fetch() async {
    final rows = await _client
        .from('events')
        .select('id, name, starts_at, ends_at, config')
        .eq('is_active', true);
    return List<Object?>.from(rows);
  }
}
