// A stand-in for the server's offers table.
import 'package:whispers_of_joppa/domain/offers.dart';
import 'package:whispers_of_joppa/services/offers_source.dart';

class FakeOffersSource implements OffersSource {
  FakeOffersSource(this.offers);

  List<Offer> offers;
  int fetches = 0;

  @override
  Future<List<Offer>> fetch() async {
    fetches++;
    return [...offers];
  }
}
