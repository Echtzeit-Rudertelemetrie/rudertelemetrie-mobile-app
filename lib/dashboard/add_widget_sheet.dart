import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard_model.dart';
import 'stream_registry.dart';
import 'widget_config.dart';

/// Bottom sheet for adding a new widget to the dashboard.
///
/// Shows all registered streams. For each stream the user can add a chart
/// tile or a value tile.
class AddWidgetSheet extends StatelessWidget {
  const AddWidgetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final streams = StreamRegistry.all;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Widget',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a data source and display type.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            if (streams.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No streams available.',
                  style: TextStyle(color: Colors.white38),
                ),
              )
            else
              ...streams.map((info) => _StreamRow(info: info)),
          ],
        ),
      ),
    );
  }
}

class _StreamRow extends StatelessWidget {
  final StreamInfo info;

  const _StreamRow({required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (info.unit.isNotEmpty)
                  Text(
                    info.unit,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          ),
          _AddButton(
            icon: Icons.show_chart,
            label: 'Chart',
            onTap: () => _add(context, 'chart', 2, 3, info.key),
          ),
          const SizedBox(width: 8),
          _AddButton(
            icon: Icons.pin,
            label: 'Value',
            onTap: () => _add(context, 'value', 2, 2, info.key),
          ),
        ],
      ),
    );
  }

  void _add(BuildContext context, String type, int w, int h, String streamKey) {
    final id = 'w_${DateTime.now().millisecondsSinceEpoch}';
    context.read<DashboardModel>().addWidget(
      WidgetConfig(id: id, x: 0, y: 0, w: w, h: h, type: type, streamKey: streamKey),
    );
    Navigator.pop(context);
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF45866).withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF45866).withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFF45866)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFFF45866), fontSize: 12)),
        ],
      ),
    ),
  );
}
