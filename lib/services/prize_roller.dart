// Asks the server to draw a prize when a player has staked Pearls on chance
// (a Pearl spin of the wheel, a bought Jar of Clay). The server draws from
// the same table the player is shown and keeps a record of every draw.
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger('PrizeRoller');

abstract class PrizeRoller {
  /// The id of the prize the server drew for a paid try at [kind] ('wheel'
  /// or 'jar', with [jar] the kind of jar), from the prize tables numbered
  /// [tablesVersion] (content/chance.json, "tables_version"). Null if the server could not be asked or holds
  /// other tables: the game then draws for itself, by the same odds.
  Future<String?> roll({
    required String kind,
    required int tablesVersion,
    String? jar,
  });
}

class SupabasePrizeRoller implements PrizeRoller {
  final SupabaseClient _client;

  SupabasePrizeRoller(this._client);

  @override
  Future<String?> roll({
    required String kind,
    required int tablesVersion,
    String? jar,
  }) async {
    if (_client.auth.currentUser == null) return null;
    try {
      final response = await _client.functions
          .invoke(
            'roll',
            body: {
              'kind': kind,
              'jar': ?jar,
              'paid': true,
              'tables_version': tablesVersion,
            },
          )
          // A player waiting on a spin is not kept waiting on the network.
          .timeout(const Duration(seconds: 4));
      return switch (response.data) {
        {'success': true, 'prize_id': final String id} => id,
        _ => null,
      };
    } on Object catch (e) {
      // Offline, signed out, or the server holds other tables (409).
      _log.info('The server did not draw ($kind): $e');
      return null;
    }
  }
}
