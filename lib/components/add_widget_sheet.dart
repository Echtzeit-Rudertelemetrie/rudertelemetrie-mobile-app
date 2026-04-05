import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';
import 'package:rudertelemetrie_mobile_app/models/dashboard_model.dart';

/// Metadata shown in the add-widget picker for each registered type.
class _WidgetTypeMeta {
  final String type;
  final String label;
  final IconData icon;
  final int defaultW;
  final int defaultH;

  const _WidgetTypeMeta({
    required this.type,
    required this.label,
    required this.icon,
    this.defaultW = 2,
    this.defaultH = 2,
  });
}

/// Bottom sheet that lets the user pick a widget type to add to the dashboard.
class AddWidgetSheet extends StatelessWidget {
  static final _types = <_WidgetTypeMeta>[
    _WidgetTypeMeta(
      type: 'placeholder',
      label: 'Placeholder',
      icon: FIcons.layoutDashboard,
    ),
    _WidgetTypeMeta(
      type: 'sine_wave',
      label: 'Sine Wave',
      icon: FIcons.activity,
      defaultW: 2,
      defaultH: 3,
    ),
    _WidgetTypeMeta(
      type: 'live_value',
      label: 'Live Value',
      icon: FIcons.gauge,
      defaultW: 2,
      defaultH: 2,
    ),
  ];

  const AddWidgetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Widget',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
              physics: const NeverScrollableScrollPhysics(),
              children: _types.map((meta) => _TypeCard(meta: meta)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final _WidgetTypeMeta meta;

  const _TypeCard({required this.meta});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final model = context.read<DashboardModel>();
        final id = 'w_${DateTime.now().millisecondsSinceEpoch}';
        model.addWidget(
          WidgetConfig(
            id: id,
            x: 0,
            y: 0,
            w: meta.defaultW,
            h: meta.defaultH,
            type: meta.type,
          ),
        );
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1d30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(meta.icon, color: const Color(0xFFF45866), size: 28),
            const SizedBox(height: 8),
            Text(
              meta.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
