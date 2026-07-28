import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/components/readiness_card.dart';
import 'package:rudertelemetrie_mobile_app/components/settings_section.dart';
import 'package:rudertelemetrie_mobile_app/screens/dashboard_screen.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader(title: const Text('Rudertelemetrie')),
    // Scrollable: the settings list overflows a short screen at a large system
    // font scale. The padding has to be given explicitly — a primary [ListView]
    // without any falls back to the view's safe-area inset, which [FScaffold]
    // has already applied, leaving a notch-sized hole under the header. Only
    // the bottom gets room, so the last tile clears the home indicator instead
    // of ending flush against it.
    child: ListView(
      padding: const EdgeInsets.only(bottom: 34),
      children: [
        const ReadinessCard(),
        const SizedBox(height: 20),
        _OpenDashboardButton(onPress: () => _openDashboard(context)),
        const SizedBox(height: 24),
        const SettingsSection(),
      ],
    ),
  );

  void _openDashboard(BuildContext context) => Navigator.push(
    context,
    // Opened as a fullscreen dialog to suppress iOS' edge swipe-back — it would
    // otherwise steal the drag on tile handles near the left edge. The
    // dashboard's own header button closes it.
    MaterialPageRoute(
      builder: (_) => const DashboardScreen(),
      fullscreenDialog: true,
    ),
  );
}

/// The one thing Home exists to do, sized and lit accordingly: full width, a
/// glove-friendly height, and an accent glow that marks it as the way out to
/// the water.
///
/// Named for what it does — recording is started from the dashboard's own
/// control, or automatically when rowing is detected.
class _OpenDashboardButton extends StatelessWidget {
  final VoidCallback onPress;

  const _OpenDashboardButton({required this.onPress});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open Dashboard',
    child: GestureDetector(
      onTap: onPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppPalette.accent,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          boxShadow: [
            BoxShadow(
              color: AppPalette.accent.withAlpha(90),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'Open Dashboard',
          style: TextStyle(
            color: AppPalette.label,
            fontSize: AppTypeScale.heading,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
