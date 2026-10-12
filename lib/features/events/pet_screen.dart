// Shadow the cat: how full he is, the things on the board he can be fed,
// and the looks he can wear.
import 'package:flutter/material.dart';
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:whispers_of_joppa/app/game_palette.dart';
import 'package:whispers_of_joppa/domain/models.dart';
import 'package:whispers_of_joppa/domain/pet.dart';

/// The name of the pet's record in the save file.
const petRecord = 'pet';

const _cream = Color(0xFFF3E5C8);

/// [state] reads Shadow as he is; [food] lists what on the board he can be
/// fed, with how many of each; [feed] feeds him one and gives back what to
/// say about it ('' for nothing); [wear] puts a look on.
Future<void> showPet(
  BuildContext context, {
  required Pet pet,
  required PetState Function() state,
  required Map<ItemModel, int> Function() food,
  required String Function(ItemModel item) feed,
  required void Function(PetLook look) wear,
  required Map<String, String> text,
}) => showDialog<void>(
  context: context,
  builder: (context) => _PetDialog(
    pet: pet,
    state: state,
    food: food,
    feed: feed,
    wear: wear,
    text: text,
  ),
);

class _PetDialog extends StatefulWidget {
  const _PetDialog({
    required this.pet,
    required this.state,
    required this.food,
    required this.feed,
    required this.wear,
    required this.text,
  });

  final Pet pet;
  final PetState Function() state;
  final Map<ItemModel, int> Function() food;
  final String Function(ItemModel item) feed;
  final void Function(PetLook look) wear;
  final Map<String, String> text;

  @override
  State<_PetDialog> createState() => _PetDialogState();
}

class _PetDialogState extends State<_PetDialog> {
  String _said = '';

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final pet = widget.pet;
    final state = widget.state();
    final food = widget.food();
    final worn = petLook(pet, state);
    return GameDialog(
      key: const Key('pet_popup'),
      icon: Icons.pets,
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
              Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    const Icon(Icons.pets, size: 64, color: Color(0xFF2B2B2B)),
                    Container(
                      key: Key('pet_look_${worn.id}'),
                      width: 44,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(worn.color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _said.isEmpty ? (text['intro'] ?? '') : _said,
                key: const Key('pet_said'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _said.isEmpty ? _cream : GamePalette.talents,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (state.fed / pet.feedGoal).clamp(0, 1).toDouble(),
                minHeight: 10,
                color: GamePalette.gold,
                backgroundColor: const Color(0xFF3A2A12),
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 4),
              Text(
                (text['meter'] ?? '')
                    .replaceAll('{fed}', '${state.fed}')
                    .replaceAll('{goal}', '${pet.feedGoal}'),
                key: const Key('pet_meter'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _cream, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                food.isEmpty ? (text['nothing'] ?? '') : (text['feed'] ?? ''),
                style: const TextStyle(
                  color: GamePalette.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in food.entries)
                    ActionChip(
                      key: Key('pet_feed_${entry.key.itemId}'),
                      backgroundColor: _cream,
                      label: Text(
                        '${entry.key.name} ×${entry.value}',
                        style: const TextStyle(color: Color(0xFF1A1205)),
                      ),
                      onPressed: () =>
                          setState(() => _said = widget.feed(entry.key)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                text['looks'] ?? '',
                style: const TextStyle(
                  color: GamePalette.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final look in pet.looks)
                    ChoiceChip(
                      key: Key('pet_wear_${look.id}'),
                      avatar: CircleAvatar(backgroundColor: Color(look.color)),
                      selected: look.id == worn.id,
                      selectedColor: GamePalette.gold,
                      backgroundColor: _cream,
                      disabledColor: const Color(0xFF3A2A12),
                      label: Text(
                        petLookOpen(look, state)
                            ? look.name
                            : (text['look_locked'] ?? '').replaceAll(
                                '{gifts}',
                                '${look.gifts}',
                              ),
                        style: TextStyle(
                          color: petLookOpen(look, state)
                              ? const Color(0xFF1A1205)
                              : _cream,
                        ),
                      ),
                      onSelected: petLookOpen(look, state)
                          ? (_) => setState(() => widget.wear(look))
                          : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('pet_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text['close'] ?? ''),
        ),
      ],
    );
  }
}
