import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/display/orientation_settings.dart';

/// Hands the user's orientation lock to the OS, and re-applies it whenever they
/// change it or the saved one finishes loading.
///
/// The setting lives in [OrientationSettings]; the system call lives here, so
/// nothing else in the app has to know about [SystemChrome].
class ScreenOrientationLock extends StatefulWidget {
  final Widget child;

  const ScreenOrientationLock({super.key, required this.child});

  @override
  State<ScreenOrientationLock> createState() => _ScreenOrientationLockState();
}

class _ScreenOrientationLockState extends State<ScreenOrientationLock> {
  OrientationSettings? _settings;
  OrientationLock? _applied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<OrientationSettings>();
    if (identical(settings, _settings)) return;
    _settings?.removeListener(_sync);
    _settings = settings..addListener(_sync);
    _sync();
  }

  void _sync() {
    final lock = _settings?.lock ?? OrientationLock.auto;
    if (lock == _applied) return;
    _applied = lock;
    SystemChrome.setPreferredOrientations(lock.allowed);
  }

  @override
  void dispose() {
    _settings?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
