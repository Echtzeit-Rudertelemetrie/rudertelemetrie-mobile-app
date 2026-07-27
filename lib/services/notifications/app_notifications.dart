import 'package:flutter/foundation.dart';

enum NoticeTone { info, alert }

/// One short, non-blocking message for the user.
class Notice {
  final String message;
  final String? detail;
  final NoticeTone tone;

  const Notice(this.message, {this.detail, this.tone = NoticeTone.info});
}

/// App-level message queue. Services raise notices without ever taking a
/// `BuildContext`; the UI drains the queue and presents them as toasts.
///
/// Older notices are dropped rather than queued up: on the water a stale message
/// is noise, and nothing here is worth blocking on.
class AppNotifications extends ChangeNotifier {
  static const _maxPending = 4;

  final List<Notice> _pending = [];

  List<Notice> get pending => List.unmodifiable(_pending);

  void info(String message, {String? detail}) =>
      _post(Notice(message, detail: detail));

  void alert(String message, {String? detail}) =>
      _post(Notice(message, detail: detail, tone: NoticeTone.alert));

  /// Removes and returns everything queued.
  List<Notice> drain() {
    final drained = List.of(_pending);
    _pending.clear();
    return drained;
  }

  void _post(Notice notice) {
    _pending.add(notice);
    if (_pending.length > _maxPending) _pending.removeAt(0);
    notifyListeners();
  }
}
