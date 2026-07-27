import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Asks before an irreversible action. [detail] must name what is at stake —
/// which session, which preset — so the user can tell they picked the right one.
///
/// Cancel is the primary (focused) action; confirming is deliberate.
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String detail,
  required String confirmLabel,
}) async {
  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (dialogContext, style, animation) => FDialog.adaptive(
      title: Text(title),
      body: Text(detail),
      actions: [
        FButton(
          variant: FButtonVariant.outline,
          autofocus: true,
          onPress: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FButton(
          variant: FButtonVariant.destructive,
          onPress: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
