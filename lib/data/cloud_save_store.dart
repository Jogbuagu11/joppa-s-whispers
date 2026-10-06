// Reads and writes the player's save in the cloud (Supabase `saves` table).
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/domain/save_state.dart';

/// A save as stored in the cloud, with the time the cloud last changed it.
class CloudSave {
  final SaveState state;
  final DateTime updatedAt;

  const CloudSave({required this.state, required this.updatedAt});
}

abstract class CloudSaveStore {
  /// The account's cloud save, or null if it has none. Throws if the cloud
  /// cannot be reached or the stored save cannot be read.
  Future<CloudSave?> fetch(String userId);

  /// Stores [state] for the account and returns the cloud's new timestamp.
  Future<DateTime> upload(String userId, SaveState state);

  /// Stores [state] only if the cloud save is still the one this phone last
  /// saw ([expectedUpdatedAt]). Returns the new timestamp, or null, changing
  /// nothing, if another phone has saved since.
  Future<DateTime?> uploadIfUnchanged(
    String userId,
    SaveState state,
    DateTime expectedUpdatedAt,
  );
}

class SupabaseCloudSaveStore implements CloudSaveStore {
  final SupabaseClient _client;

  SupabaseCloudSaveStore(this._client);

  @override
  Future<CloudSave?> fetch(String userId) async {
    final row = await _client
        .from('saves')
        .select('save_data, updated_at')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return CloudSave(
      state: SaveState.fromJson(row['save_data'] as Map<String, dynamic>),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  @override
  Future<DateTime> upload(String userId, SaveState state) async {
    final row = await _client
        .from('saves')
        .upsert({
          'user_id': userId,
          'save_data': state.toJson(),
          'save_version': currentSaveVersion,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id')
        .select('updated_at')
        .single();
    return DateTime.parse(row['updated_at'] as String);
  }

  @override
  Future<DateTime?> uploadIfUnchanged(
    String userId,
    SaveState state,
    DateTime expectedUpdatedAt,
  ) async {
    final rows = await _client
        .from('saves')
        .update({
          'save_data': state.toJson(),
          'save_version': currentSaveVersion,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('updated_at', expectedUpdatedAt.toUtc().toIso8601String())
        .select('updated_at');
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['updated_at'] as String);
  }
}
