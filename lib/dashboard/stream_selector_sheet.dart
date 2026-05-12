import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

import 'dashboard_model.dart';
import 'widget_config.dart';

class StreamSelectorSheet extends StatefulWidget {
  final WidgetConfig config;

  const StreamSelectorSheet({super.key, required this.config});

  @override
  State<StreamSelectorSheet> createState() => _StreamSelectorSheetState();
}

class _StreamSelectorSheetState extends State<StreamSelectorSheet> {
  late String _type;
  late String? _streamKey;

  @override
  void initState() {
    super.initState();
    _type = widget.config.data['type'] as String? ?? 'value';
    _streamKey = widget.config.data['dataSourceKey'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final dataSources = context.read<DataSourceProviderModel>().registry.all;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configure Widget',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            const Text('Display type',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeButton(
                  label: 'Chart',
                  icon: Icons.show_chart,
                  selected: _type == 'chart',
                  onTap: () => setState(() => _type = 'chart'),
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'Value',
                  icon: Icons.pin,
                  selected: _type == 'value',
                  onTap: () => setState(() => _type = 'value'),
                ),
              ],
            ),
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
              ...dataSources.map((dataSource) => _DSOption(
                    dataSource: dataSource,
                    selected: _streamKey == dataSource.name,
                    onTap: () => setState(() => _streamKey = dataSource.name),
                  )),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF45866)),
                onPressed: () {
                  context.read<DashboardModel>().updateWidget(
                    widget.config.copyWith(
                      data: {
                    'type': _type,
                    'dataSourceKey': _streamKey,
                    'dataTransformerKey': widget.config.data['dataTransformerKey'],
                  },
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DSOption extends StatelessWidget {
  final DataSource dataSource;
  final bool selected;
  final VoidCallback onTap;

  const _DSOption({required this.dataSource, required this.selected, required this.onTap});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dataSource.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text(dataSource.unit.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF45866) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.white54, fontSize: 13)),
        ],
      ),
    ),
  );
}
