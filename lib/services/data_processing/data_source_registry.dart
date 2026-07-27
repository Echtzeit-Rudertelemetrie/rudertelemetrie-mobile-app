import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class DataSourceRegistry extends ChangeNotifier {
  final Map<String, DataSource> _sources = {};

  bool _disposed = false;
  bool _notifyScheduled = false;

  void register(DataSource source) {
    _sources[source.name] = source;
    notifyListeners();
  }

  /// Adds [source] immediately but coalesces the notification into a microtask.
  /// Use when registering during a widget build (e.g. a provider's `create`),
  /// where a synchronous notify would mark dependents dirty mid-build.
  void registerDeferred(DataSource source) {
    _sources[source.name] = source;
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  void unregister(String key) {
    if (_sources.remove(key) != null) notifyListeners();
  }

  DataSource? get(String key) => _sources[key];

  List<DataSource> get all => List.unmodifiable(_sources.values);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
