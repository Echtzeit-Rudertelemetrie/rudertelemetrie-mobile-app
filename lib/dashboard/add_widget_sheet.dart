import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_transformer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';

import 'dashboard_model.dart';
import 'widget_config.dart';

/// Bottom sheet for adding a new widget to the dashboard.
///
/// Shows all registered streams; for each one the user can add a chart tile
/// or a value tile.  App-specific data is stored in [WidgetConfig.data].
class AddWidgetSheet extends StatefulWidget {
  const AddWidgetSheet({super.key});

  @override
  State<AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends State<AddWidgetSheet> {
  String? _transformerKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transformers = context.read<DataTransformerProviderModel>().all;
    _transformerKey ??= transformers.isNotEmpty ? transformers.first.name : null;
  }

  void _add(BuildContext context, String type, int w, int h, DataSource dataSource) {
    final id = 'w_${DateTime.now().millisecondsSinceEpoch}';
    context.read<DashboardModel>().addWidget(
      WidgetConfig(
        id: id,
        x: 0,
        y: 0,
        w: w,
        h: h,
        data: {
          'type': type,
          'dataSourceKey': dataSource.name,
          'dataTransformerKey': _transformerKey,
        },
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dataSources = context.read<DataSourceProviderModel>().registry.all;
    final transformers = context.read<DataTransformerProviderModel>().all;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Widget',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Choose a data source and display type.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),

            const Text('Transformer',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            ...transformers.map((t) => _TransformerOption(
                  transformer: t,
                  selected: _transformerKey == t.name,
                  onTap: () => setState(() => _transformerKey = t.name),
                )),
            const SizedBox(height: 16),

            const Text('Data source',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            if (dataSources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No streams available.',
                    style: TextStyle(color: Colors.white38)),
              )
            else
              ...dataSources.map((dataSource) => _DSRow(
                    dataSource: dataSource,
                    onAdd: (type, w, h) => _add(context, type, w, h, dataSource),
                  )),
          ],
        ),
      ),
    );
  }
}

class _DSRow extends StatelessWidget {
  final DataSource dataSource;
  final void Function(String type, int w, int h) onAdd;

  const _DSRow({required this.dataSource, required this.onAdd});

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
                Text(dataSource.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(dataSource.unit.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          _AddButton(
            icon: Icons.show_chart,
            label: 'Chart',
            onTap: () => onAdd('chart', 2, 3),
          ),
          const SizedBox(width: 8),
          _AddButton(
            icon: Icons.pin,
            label: 'Value',
            onTap: () => onAdd('value', 2, 2),
          ),
        ],
      ),
    );
  }
}

class _TransformerOption extends StatelessWidget {
  final DataTransformer transformer;
  final bool selected;
  final VoidCallback onTap;

  const _TransformerOption(
      {required this.transformer, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFFF45866) : Colors.white38,
                width: 2,
              ),
            ),
            child: selected
                ? const Center(
                    child: CircleAvatar(radius: 5, backgroundColor: Color(0xFFF45866)))
                : null,
          ),
          const SizedBox(width: 12),
          Text(transformer.name,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    ),
  );
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.icon, required this.label, required this.onTap});

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
          Text(label,
              style: const TextStyle(color: Color(0xFFF45866), fontSize: 12)),
        ],
      ),
    ),
  );
}
