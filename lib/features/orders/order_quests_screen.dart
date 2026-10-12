// The order quests: each open quest with what it still needs, and a
// button to give one of a needed thing that lies on the board.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/order_quests.dart';
import 'package:whispers_of_joppa/domain/season_pass.dart';

/// The name of the quests' record in the save file.
const questsRecord = 'quests';

const _cream = Color(0xFFF3E5C8);

/// [state] reads what has been given; [open] says whether a quest is
/// open; [onBoard] counts what lies on the board; [give] gives one item
/// to a quest and returns what to say about it ('' for nothing).
Future<void> showOrderQuests(
  BuildContext context, {
  required List<OrderQuest> quests,
  required QuestsState Function() state,
  required bool Function(OrderQuest quest) open,
  required Map<String, int> Function() onBoard,
  required String Function(OrderQuest quest, String itemId) give,
  required String Function(String itemId) itemName,
  required String Function(PassReward reward) rewardWords,
  required Map<String, String> text,
}) => showDialog<void>(
  context: context,
  builder: (context) => _QuestsDialog(
    quests: quests,
    state: state,
    open: open,
    onBoard: onBoard,
    give: give,
    itemName: itemName,
    rewardWords: rewardWords,
    text: text,
  ),
);

class _QuestsDialog extends StatefulWidget {
  const _QuestsDialog({
    required this.quests,
    required this.state,
    required this.open,
    required this.onBoard,
    required this.give,
    required this.itemName,
    required this.rewardWords,
    required this.text,
  });

  final List<OrderQuest> quests;
  final QuestsState Function() state;
  final bool Function(OrderQuest quest) open;
  final Map<String, int> Function() onBoard;
  final String Function(OrderQuest quest, String itemId) give;
  final String Function(String itemId) itemName;
  final String Function(PassReward reward) rewardWords;
  final Map<String, String> text;

  @override
  State<_QuestsDialog> createState() => _QuestsDialogState();
}

class _QuestsDialogState extends State<_QuestsDialog> {
  String _said = '';

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final given = widget.state();
    final board = widget.onBoard();
    return GameDialog(
      key: const Key('quests_popup'),
      icon: Icons.assignment_turned_in,
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
                _said.isEmpty ? (text['intro'] ?? '') : _said,
                key: const Key('quests_said'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _said.isEmpty ? _cream : GamePalette.talents,
                  fontSize: 14,
                ),
              ),
              for (final quest in widget.quests)
                _QuestCard(
                  quest: quest,
                  state: given,
                  open: widget.open(quest),
                  board: board,
                  itemName: widget.itemName,
                  rewardWords: widget.rewardWords,
                  text: text,
                  onGive: (itemId) =>
                      setState(() => _said = widget.give(quest, itemId)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('quests_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text['close'] ?? ''),
        ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.state,
    required this.open,
    required this.board,
    required this.itemName,
    required this.rewardWords,
    required this.text,
    required this.onGive,
  });

  final OrderQuest quest;
  final QuestsState state;
  final bool open;
  final Map<String, int> board;
  final String Function(String itemId) itemName;
  final String Function(PassReward reward) rewardWords;
  final Map<String, String> text;
  final void Function(String itemId) onGive;

  @override
  Widget build(BuildContext context) {
    final done = questDone(quest, state);
    final left = questLeft(quest, state);
    return Container(
      key: Key('quest_${quest.id}'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? GamePalette.talents : GamePalette.gold,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle
                    : open
                    ? Icons.assignment
                    : Icons.lock,
                color: done ? GamePalette.talents : GamePalette.gold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quest.name,
                  style: const TextStyle(
                    color: GamePalette.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            done
                ? quest.done
                : open
                ? quest.text
                : (text['locked'] ?? ''),
            style: const TextStyle(color: _cream, fontSize: 13),
          ),
          if (open && !done) ...[
            for (final need in quest.needs.entries)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (text['need'] ?? '')
                          .replaceAll('{name}', itemName(need.key))
                          .replaceAll(
                            '{have}',
                            '${need.value - (left[need.key] ?? 0)}',
                          )
                          .replaceAll('{all}', '${need.value}'),
                      key: Key('quest_need_${quest.id}_${need.key}'),
                      style: const TextStyle(color: _cream, fontSize: 13),
                    ),
                  ),
                  if ((left[need.key] ?? 0) > 0)
                    TextButton(
                      key: Key('quest_give_${quest.id}_${need.key}'),
                      onPressed: (board[need.key] ?? 0) > 0
                          ? () => onGive(need.key)
                          : null,
                      child: Text(text['give'] ?? ''),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.check,
                        color: GamePalette.talents,
                        size: 18,
                      ),
                    ),
                ],
              ),
            Text(
              (text['reward'] ?? '').replaceAll(
                '{reward}',
                rewardWords(quest.reward),
              ),
              style: const TextStyle(color: GamePalette.talents, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
