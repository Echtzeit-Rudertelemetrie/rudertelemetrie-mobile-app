import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/add_widget_sheet.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_grid.dart';
import 'package:rudertelemetrie_mobile_app/models/dashboard_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
