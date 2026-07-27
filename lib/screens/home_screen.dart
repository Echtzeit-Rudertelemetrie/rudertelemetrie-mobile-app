import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/components/settings_section.dart';
import 'package:rudertelemetrie_mobile_app/screens/dashboard_screen.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader(title: const Text('Rudertelemetrie')),
    // Scrollable: the settings list overflows a short screen at a large system
    // font scale. The explicit zero padding matters — a primary [ListView] with
    // none falls back to the view's safe-area inset, which [FScaffold] has
    // already applied, leaving a notch-sized hole under the header.
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const SettingsSection(),
        const SizedBox(height: 16),
        FButton(
          onPress: () => Navigator.push(
            context,
            // Opened as a fullscreen dialog to suppress iOS' edge swipe-back —
            // it would otherwise steal the drag on tile handles near the left
            // edge. The dashboard's own header button closes it.
            MaterialPageRoute(
              builder: (_) => const DashboardScreen(),
              fullscreenDialog: true,
            ),
          ),
          // Named for what it does: recording is started from the dashboard's
          // own control, or automatically when rowing is detected.
          child: const Text('Open Dashboard'),
        ),
      ],
    ),
  );
}
