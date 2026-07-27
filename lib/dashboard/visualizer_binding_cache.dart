import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

/// Identity of a tile's binding: everything whose change must produce a fresh
/// [BoundVisualizer]. Source *instances* are included, not just their keys, so a
/// reconnected device rebinds while an unchanged one does not.
String bindingSignature({
  required String? visualizerKey,
  required List<String> sourceKeys,
  required List<DataSource> sources,
  required Map<String, double> params,
}) {
  final paramKeys = params.keys.toList()..sort();
  return [
    visualizerKey,
    sourceKeys.join(','),
    sources.map(identityHashCode).join(','),
    paramKeys.map((k) => '$k=${params[k]}').join(','),
  ].join('|');
}

/// One bound visualizer per dashboard tile, rebuilt only when that tile's
/// [bindingSignature] changes.
///
/// Rebinding recreates the stream transformers and discards the tile's
/// accumulated history, so it must not happen on unrelated dashboard
/// notifications — dragging, resizing, toggling edit mode or swapping presets.
class VisualizerBindingCache {
  final Map<String, _Entry> _entries = {};

  int get length => _entries.length;

  /// The binding for [configId], calling [build] only when the cached one no
  /// longer matches [signature].
  BoundVisualizer? bind(
    String configId,
    String signature,
    BoundVisualizer? Function() build,
  ) {
    final cached = _entries[configId];
    if (cached != null && cached.signature == signature) return cached.bound;

    // A binding holds a live subscription to its sources; dropping the
    // reference without this leaks the whole pipeline behind it.
    cached?.bound.dispose();

    final bound = build();
    if (bound == null) {
      _entries.remove(configId);
      return null;
    }
    _entries[configId] = _Entry(signature, bound);
    return bound;
  }

  /// Drops bindings of tiles that are no longer on the dashboard.
  void retainOnly(Set<String> configIds) {
    _entries.removeWhere((id, entry) {
      if (configIds.contains(id)) return false;
      entry.bound.dispose();
      return true;
    });
  }

  /// Releases every binding. For the owning screen's `dispose`.
  void clear() {
    for (final entry in _entries.values) {
      entry.bound.dispose();
    }
    _entries.clear();
  }
}

class _Entry {
  final String signature;
  final BoundVisualizer bound;
  const _Entry(this.signature, this.bound);
}
