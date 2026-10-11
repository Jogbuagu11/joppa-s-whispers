// Where the game's offers come from: the server's `offers` table.
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whispers_of_joppa/domain/offers.dart';

final _log = Logger('Offers');

abstract class OffersSource {
  /// The offers that are switched on. Empty if they cannot be read: no
  /// offer is ever a reason to disturb the game.
  Future<List<Offer>> fetch();
}

class SupabaseOffersSource implements OffersSource {
  final SupabaseClient _client;

  SupabaseOffersSource(this._client);

  @override
  Future<List<Offer>> fetch() async {
    try {
      // The server only lets players see offers that are switched on.
      final rows = await _client.from('offers').select();
      return [for (final row in rows) ?Offer.fromJson(row)];
    } on Exception catch (e) {
      _log.info('Could not read offers: $e');
      return const [];
    }
  }
}
