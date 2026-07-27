import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Holds the display awake for as long as a recording is running. The phone sits
/// mounted and untouched for a whole piece, so the OS would otherwise lock the
/// screen exactly while the live dashboard is being watched.
///
/// The lock is released as soon as the recording stops, the app is backgrounded,
/// or this widget goes away — it never outlives what it is there for.
class KeepScreenAwake extends StatefulWidget {
  final Widget child;

  const KeepScreenAwake({super.key, required this.child});

  @override
  State<KeepScreenAwake> createState() => _KeepScreenAwakeState();
}

class _KeepScreenAwakeState extends State<KeepScreenAwake>
    with WidgetsBindingObserver {
  RecordingSession? _session;
  bool _foreground = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<RecordingSession>();
    if (identical(session, _session)) return;
    _session?.removeListener(_sync);
    _session = session..addListener(_sync);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final wanted = _foreground && (_session?.isRecording ?? false);
    if (wanted == _enabled) return;
    _enabled = wanted;
    WakelockPlus.toggle(enable: wanted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.removeListener(_sync);
    if (_enabled) WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
