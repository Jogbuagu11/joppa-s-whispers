// How the space under the top row is shared between the swipeable row of
// cards and the board. Pure arithmetic, unit tested.
import 'package:whispers_of_joppa/features/orders/orders_bar.dart';
import 'package:whispers_of_joppa/game/board/board_game.dart';

/// How the space under the bars is shared: the board is a 7 by 9 grid as
/// wide as the screen if the height allows; the order cards get the rest,
/// never less than their smallest size nor more than their largest.
({double cards, double board}) shareHeight({
  required double width,
  required double height,
}) {
  const gap = 6.0;
  final fullWidth = width * BoardGame.rows / BoardGame.cols;
  final most = height - orderCardsMinHeight - gap;
  final board = fullWidth < most ? fullWidth : (most < 0 ? 0.0 : most);
  final left = height - board - gap;
  final cards = left > orderCardsMaxHeight
      ? orderCardsMaxHeight
      : (left < orderCardsMinHeight ? orderCardsMinHeight : left);
  return (cards: cards, board: board);
}
