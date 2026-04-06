import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import 'add_widget_sheet.dart';
import 'dashboard_grid.dart';
import 'dashboard_model.dart';
import 'example_streams.dart';

/// Full-screen dashboard entry point.
///
/// Manages the [ExampleStreams] lifecycle — streams start when this screen
/// is pushed and stop when it is popped, keeping the dashboard module
/// self-contained.
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
          const DashboardGrid(),
          if (editMode)
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFFF45866),
                foregroundColor: Colors.white,
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF0c0e1d),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => ChangeNotifierProvider.value(
                    value: model,
                    child: const AddWidgetSheet(),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }
}
