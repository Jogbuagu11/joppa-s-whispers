// The server's count for global goals (table `global_goals`, function
// `add_to_global_goal`).
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/domain/global_goal.dart';

class SupabaseGlobalGoals implements GlobalGoalServer {
  final SupabaseClient _client;

  SupabaseGlobalGoals(this._client);

  @override
  bool get signedIn => _client.auth.currentUser != null;

  @override
  Future<int> total(String eventId) async {
    final row = await _client
        .from('global_goals')
        .select('total')
        .eq('event_id', eventId)
        .maybeSingle();
    return switch (row?['total']) {
      final int n => n,
      _ => 0,
    };
  }

  @override
  Future<int> add(String eventId, int amount) async {
    final total = await _client.rpc<Object?>(
      'add_to_global_goal',
      params: {'p_event_id': eventId, 'p_amount': amount},
    );
    return total is int ? total : 0;
  }
}
