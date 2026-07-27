import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

/// Protects an in-flight recording against the app going away.
///
/// Leaving the foreground flushes the CSV, so an OS kill loses at most the last
/// few samples; termination stops the session properly, so it lands in History
/// instead of becoming an orphaned directory.
class RecordingLifecycleGuard extends StatefulWidget {
  final Widget child;

  const RecordingLifecycleGuard({super.key, required this.child});

  @override
  State<RecordingLifecycleGuard> createState() =>
      _RecordingLifecycleGuardState();
}

class _RecordingLifecycleGuardState extends State<RecordingLifecycleGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        context.read<SessionStore>().flush();
      case AppLifecycleState.detached:
        context.read<RecordingSession>().stop();
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
