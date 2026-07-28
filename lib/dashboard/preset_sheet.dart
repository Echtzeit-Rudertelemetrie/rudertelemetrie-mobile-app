import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/confirm_dialog.dart';

import 'dashboard_model.dart';
import 'dashboard_preset.dart';
import 'sheet_scaffold.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

const _accent = AppPalette.accent;

/// Preset picker: switch the visible dashboard, rename or delete a saved
/// layout, and create a new one (empty or as a copy of what is on screen).
class PresetSheet extends StatefulWidget {
  const PresetSheet({super.key});

  @override
  State<PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends State<PresetSheet> {
  final TextEditingController _name = TextEditingController();
  String? _renaming;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create(BuildContext context, {required bool copyCurrent}) {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.read<DashboardModel>().createPreset(name, copyCurrent: copyCurrent);
    _name.clear();
    Navigator.pop(context);
  }

  void _select(BuildContext context, String id) {
    context.read<DashboardModel>().selectPreset(id);
    Navigator.pop(context);
  }

  void _submitRename(String id, String value) {
    context.read<DashboardModel>().renamePreset(id, value);
    setState(() => _renaming = null);
  }

  /// An empty preset is nothing to lose; one the user has built up is.
  Future<void> _delete(
    BuildContext context,
    DashboardModel model,
    DashboardPreset preset,
  ) async {
    if (preset.layout.isNotEmpty) {
      final confirmed = await confirmDestructiveAction(
        context,
        title: 'Delete “${preset.name}”?',
        detail:
            '${preset.layout.length} tile'
            '${preset.layout.length == 1 ? '' : 's'} will be lost.',
        confirmLabel: 'Delete',
      );
      if (!confirmed) return;
    }
    model.deletePreset(preset.id);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();

    return SheetScaffold(
      title: 'Dashboard Presets',
      initialSize: 0.5,
      footer: _Footer(
        controller: _name,
        onCreateEmpty: () => _create(context, copyCurrent: false),
        onDuplicate: () => _create(context, copyCurrent: true),
      ),
      children: [
        for (final preset in model.presets)
          _PresetRow(
            key: ValueKey(preset.id),
            preset: preset,
            selected: preset.id == model.activePresetId,
            renaming: _renaming == preset.id,
            deletable: model.presets.length > 1,
            onTap: () => _select(context, preset.id),
            onRenameStart: () => setState(() => _renaming = preset.id),
            onRenameSubmit: (value) => _submitRename(preset.id, value),
            onDelete: () => _delete(context, model, preset),
          ),
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  final DashboardPreset preset;
  final bool selected;
  final bool renaming;
  final bool deletable;
  final VoidCallback onTap;
  final VoidCallback onRenameStart;
  final ValueChanged<String> onRenameSubmit;
  final VoidCallback onDelete;

  const _PresetRow({
    super.key,
    required this.preset,
    required this.selected,
    required this.renaming,
    required this.deletable,
    required this.onTap,
    required this.onRenameStart,
    required this.onRenameSubmit,
    required this.onDelete,
  });

  String get _subtitle {
    final count = preset.layout.length;
    return '$count widget${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _Radio(selected: selected),
          const SizedBox(width: 12),
          Expanded(
            child: renaming
                ? _RenameField(initial: preset.name, onSubmit: onRenameSubmit)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(
                          color: AppPalette.label,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _subtitle,
                        style: const TextStyle(
                          color: AppPalette.disabledLabel,
                          fontSize: AppTypeScale.caption,
                        ),
                      ),
                    ],
                  ),
          ),
          if (!renaming) ...[
            _IconAction(
              icon: Icons.edit_outlined,
              color: AppPalette.faintLabel,
              onTap: onRenameStart,
            ),
            if (deletable)
              _IconAction(
                icon: Icons.delete_outline,
                color: AppPalette.danger,
                onTap: onDelete,
              ),
          ],
        ],
      ),
    ),
  );
}

class _RenameField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSubmit;

  const _RenameField({required this.initial, required this.onSubmit});

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    autofocus: true,
    textInputAction: TextInputAction.done,
    style: const TextStyle(color: AppPalette.label, fontSize: 14),
    cursorColor: _accent,
    decoration: _fieldDecoration('Preset name'),
    onSubmitted: widget.onSubmit,
    onTapOutside: (_) => widget.onSubmit(_controller.text),
  );
}

class _Footer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCreateEmpty;
  final VoidCallback onDuplicate;

  const _Footer({
    required this.controller,
    required this.onCreateEmpty,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        controller: controller,
        style: const TextStyle(color: AppPalette.label, fontSize: 14),
        cursorColor: _accent,
        decoration: _fieldDecoration('New preset name'),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _SheetButton(
              icon: Icons.add,
              label: 'Create empty',
              onTap: onCreateEmpty,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SheetButton(
              icon: Icons.copy_all_outlined,
              label: 'Duplicate current',
              onTap: onDuplicate,
            ),
          ),
        ],
      ),
    ],
  );
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  isDense: true,
  hintText: hint,
  hintStyle: const TextStyle(color: AppPalette.outline, fontSize: 13),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  filled: true,
  fillColor: AppPalette.gridLine,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppPalette.outline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _accent),
  ),
);

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Icon(icon, size: 18, color: color),
    ),
  );
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accent.withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: _accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _accent, fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? _accent : AppPalette.disabledLabel,
        width: 2,
      ),
    ),
    child: selected
        ? const Center(child: CircleAvatar(radius: 5, backgroundColor: _accent))
        : null,
  );
}
