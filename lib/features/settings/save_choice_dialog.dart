// Asks the player which game to keep when two have moved on separately.
import 'package:whispers_of_joppa/app/game_dialog.dart';
import 'package:flutter/material.dart';

/// Asks which game to keep when this phone and the cloud have both moved on.
/// Returns true for the cloud game, false for this phone's, null if dismissed.
Future<bool?> showSaveChoice(
  BuildContext context, {
  required int localTasks,
  required int localOrders,
  required int cloudTasks,
  required int cloudOrders,
  required bool cloudIsFurtherOn,
}) {
  String line(int tasks, int orders) =>
      '$tasks story tasks done, $orders orders delivered';
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => GameDialog(
      key: const Key('save_choice_dialog'),
      icon: Icons.cloud_sync,
      title: const Text('Which game do you want to keep?'),
      content: Text(
        'This phone: ${line(localTasks, localOrders)}.\n\n'
        'Your account: ${line(cloudTasks, cloudOrders)}.\n\n'
        'The other one will be replaced. '
        '${cloudIsFurtherOn ? 'Your account\'s game is further on.' : 'This phone\'s game is at least as far on.'}',
        key: const Key('save_choice_text'),
      ),
      actions: [
        TextButton(
          key: const Key('save_choice_local'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep this phone'),
        ),
        FilledButton(
          key: const Key('save_choice_cloud'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Keep my account'),
        ),
      ],
    ),
  );
}
