import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';

/// Drains [AppNotifications] onto the enclosing [FToaster]. Must sit below an
/// `FToaster` in the tree — it is the only place in the app that turns service
/// messages into UI.
class NoticePresenter extends StatefulWidget {
  final Widget child;

  const NoticePresenter({super.key, required this.child});

  @override
  State<NoticePresenter> createState() => _NoticePresenterState();
}

class _NoticePresenterState extends State<NoticePresenter> {
  AppNotifications? _notifications;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifications = context.read<AppNotifications>();
    if (identical(notifications, _notifications)) return;
    _notifications?.removeListener(_onNotice);
    _notifications = notifications..addListener(_onNotice);
  }

  @override
  void dispose() {
    _notifications?.removeListener(_onNotice);
    super.dispose();
  }

  /// Deferred to the next frame: notices are raised from stream callbacks that
  /// can land mid-build, and showing a toast mutates the overlay.
  void _onNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final notice in _notifications?.drain() ?? const <Notice>[]) {
        _show(notice);
      }
    });
  }

  void _show(Notice notice) => showFToast(
    context: context,
    variant: notice.tone == NoticeTone.alert
        ? FToastVariant.destructive
        : FToastVariant.primary,
    title: Text(notice.message),
    description: notice.detail == null ? null : Text(notice.detail!),
    duration: const Duration(seconds: 4),
  );

  @override
  Widget build(BuildContext context) => widget.child;
}
