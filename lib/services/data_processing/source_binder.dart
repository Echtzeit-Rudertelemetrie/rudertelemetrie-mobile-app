import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';

/// Matches the first [DataSource] whose name starts with [prefix].
SourceMatcher byNamePrefix(String prefix) =>
    (source) => source.name.startsWith(prefix);

/// Matches the first [DataSource] of [group] whose name starts with [prefix].
SourceMatcher byGroupAndPrefix(String group, String prefix) =>
    (source) => source.group == group && source.name.startsWith(prefix);

typedef SourceMatcher = bool Function(DataSource source);

/// Keeps subscriptions in sync with a [DataSourceRegistry] whose contents change
/// at runtime. A source that appears late is picked up, one that is replaced
/// (device reconnect) is resubscribed, and one that disappears is dropped —
/// consumers only declare *what* they want, never *when* it exists.
class SourceBinder {
  final DataSourceRegistry registry;

  /// Called after a registry change altered which sources are bound.
  final VoidCallback? onChanged;

  final Map<String, _Binding> _bindings = {};

  SourceBinder(this.registry, {this.onChanged}) {
    registry.addListener(_resolveAll);
  }

  /// Declares that [key] follows the first source satisfying [matches],
  /// delivering its measurements to [onData]. Rebinding an existing key
  /// replaces the previous declaration.
  void bind(
    String key, {
    required SourceMatcher matches,
    required void Function(Measurement) onData,
  }) {
    _bindings.remove(key)?.cancel();
    final binding = _Binding(matches, onData);
    _bindings[key] = binding;
    _resolve(binding);
  }

  void unbind(String key) => _bindings.remove(key)?.cancel();

  /// Whether [key] currently has a live source behind it.
  bool isBound(String key) => _bindings[key]?.source != null;

  bool get hasAnyBound => _bindings.values.any((b) => b.source != null);

  void _resolveAll() {
    var changed = false;
    for (final binding in _bindings.values) {
      if (_resolve(binding)) changed = true;
    }
    if (changed) onChanged?.call();
  }

  bool _resolve(_Binding binding) {
    final match = _firstMatch(binding.matches);
    if (identical(match, binding.source)) return false;
    binding.cancel();
    binding.source = match;
    binding.subscription = match?.data.listen(binding.onData);
    return true;
  }

  DataSource? _firstMatch(SourceMatcher matches) {
    for (final source in registry.all) {
      if (matches(source)) return source;
    }
    return null;
  }

  void dispose() {
    registry.removeListener(_resolveAll);
    for (final binding in _bindings.values) {
      binding.cancel();
    }
    _bindings.clear();
  }
}

class _Binding {
  final SourceMatcher matches;
  final void Function(Measurement) onData;

  DataSource? source;
  StreamSubscription<Measurement>? subscription;

  _Binding(this.matches, this.onData);

  void cancel() {
    subscription?.cancel();
    subscription = null;
    source = null;
  }
}
