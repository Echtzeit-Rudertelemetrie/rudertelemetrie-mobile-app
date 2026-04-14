import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import 'add_widget_sheet.dart';
import 'chart_tile.dart';
import 'dashboard_grid.dart';
import 'dashboard_model.dart';
import 'example_streams.dart';
import 'stream_selector_sheet.dart';
import 'value_tile.dart';
import 'widget_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _streams = ExampleStreams();

  @override
  void initState() {
    super.initState();
    _streams.start();
  }

  @override
  void dispose() {
    _streams.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();
    final editMode = model.editMode;

    return FScaffold(
      header: FHeader(
        title: const Text('Dashboard'),
        suffixes: [
          FHeaderAction(
            icon: Icon(editMode ? FIcons.check : FIcons.pencil),
            onPress: model.toggleEditMode,
          ),
        ],
      ),
      childPad: false,
      child: Stack(
        children: [
          DashboardGrid(
            widgetBuilder: (context, config) => _buildTile(context, config),
          ),
          if (editMode)
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFFF45866),
                foregroundColor: Colors.white,
                onPressed: () => _showAddSheet(context, model),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, WidgetConfig config) {
    final editMode = context.watch<DashboardModel>().editMode;
    final streamKey = config.data['streamKey'] as String?;
    final type = config.data['type'] as String?;

    final content = switch (type) {
      'chart' when streamKey != null => ChartTile(streamKey: streamKey),
      'value' when streamKey != null => ValueTile(streamKey: streamKey),
      _ => const _NoStreamPlaceholder(),
    };

    if (!editMode) return content;
    return GestureDetector(
      onTap: () => _showStreamSelector(context, config),
      child: content,
    );
  }

  void _showStreamSelector(BuildContext context, WidgetConfig config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0c0e1d),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<DashboardModel>(),
        child: StreamSelectorSheet(config: config),
      ),
    );
  }

  void _showAddSheet(BuildContext context, DashboardModel model) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0c0e1d),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: model,
        child: const AddWidgetSheet(),
      ),
    );
  }
}

class _NoStreamPlaceholder extends StatelessWidget {
  const _NoStreamPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.add_chart, color: Colors.white24, size: 28),
  );
}
