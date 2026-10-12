// The daily login calendar: today's verse, the 28 squares, and a button
// to take today's.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/login_calendar.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

/// The name of the calendar's record in the save file.
const calendarRecord = 'calendar';

const _cream = Color(0xFFF3E5C8);

/// [state] reads the player's place; [take] takes today's square (it
/// gives false if there was nothing to take); [changes] says when the
/// place has changed.
Future<void> showLoginCalendar(
  BuildContext context, {
  required LoginCalendar calendar,
  required CalendarState Function() state,
  required bool Function() take,
  required Listenable changes,
  required Map<String, String> text,
  required String Function(PassReward reward) rewardWords,
  DateTime Function()? clock,
}) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: changes,
    builder: (context, _) {
      final now = (clock ?? DateTime.now)();
      final place = state();
      final canTake = calendarCanTake(place, now);
      final today = calendarToday(calendar, place, now);
      // The squares already taken this time round.
      final done = canTake ? place.taken % calendar.days.length : place.taken;
      final day = calendar.days[today];
      return GameDialog(
        key: const Key('calendar_popup'),
        icon: Icons.calendar_month,
        title: Text(
          text['title'] ?? '',
          style: const TextStyle(color: GamePalette.gold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  '"${day.verse}"',
                  key: const Key('calendar_verse'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _cream,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.ref,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GamePalette.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (int i = 0; i < calendar.days.length; i++)
                      _Square(
                        number: i + 1,
                        taken: i < done,
                        today: i == today,
                        // Every seventh day is a big one.
                        big: (i + 1) % 7 == 0,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${(text['day'] ?? '').replaceAll('{n}', '${today + 1}')}'
                  ' ${rewardWords(day.reward)}',
                  key: const Key('calendar_reward'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GamePalette.talents,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('calendar_close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text['close'] ?? ''),
          ),
          FilledButton(
            key: const Key('calendar_take'),
            onPressed: canTake ? take : null,
            child: Text(canTake ? text['take'] ?? '' : text['taken'] ?? ''),
          ),
        ],
      );
    },
  ),
);

class _Square extends StatelessWidget {
  const _Square({
    required this.number,
    required this.taken,
    required this.today,
    required this.big,
  });

  final int number;
  final bool taken;
  final bool today;
  final bool big;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: taken ? GamePalette.panel : GamePalette.panelLight,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: today
            ? GamePalette.gold
            : big
            ? GamePalette.talents
            : GamePalette.panelEdge,
        width: today ? 2 : 1,
      ),
    ),
    child: Center(
      child: taken
          ? const Icon(Icons.check, color: GamePalette.ready, size: 16)
          : Text(
              '$number',
              style: TextStyle(
                color: big ? GamePalette.talents : _cream,
                fontWeight: big ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
    ),
  );
}
