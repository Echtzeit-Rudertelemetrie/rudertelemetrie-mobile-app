import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_transformer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';

import '../dashboard/add_widget_sheet.dart';
import '../components/dashboart_tiles/chart_tile.dart';
import '../dashboard/dashboard_grid.dart';
import '../dashboard/dashboard_model.dart';
import '../dashboard/stream_selector_sheet.dart';
import '../components/dashboart_tiles/value_tile.dart';
import '../dashboard/widget_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    final dataSourceKey = config.data['dataSourceKey'] as String?;
    final dataTransformerKey = config.data['dataTransformerKey'] as String?;
    final type = config.data['type'] as String?;

    DataSource? dataSource;
    DataTransformer? dataTransformer;

    if (dataSourceKey != null) {
      dataSource = context.read<DataSourceProviderModel>().registry.get(
        dataSourceKey,
      );
    }

    if (dataTransformerKey != null) {
      dataTransformer = context.read<DataTransformerProviderModel>().get(
        dataTransformerKey,
      );
    }

    final content = switch (type) {
      'chart' when dataSource != null && dataTransformer != null => ChartTile(
        dataSource: dataSource,
        dataTransformer: dataTransformer,
      ),
      'value' when dataSource != null && dataTransformer != null => ValueTile(
        dataSource: dataSource,
        dataTransformer: dataTransformer,
      ),
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
