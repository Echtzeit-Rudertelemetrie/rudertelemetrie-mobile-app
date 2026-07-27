import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

/// What the add and the configure sheet are both editing: which visualizer,
/// fed by which sources, with which settings and reduction.
///
/// Both sheets drive this one class so a widget can be reconfigured with
/// exactly the options it was created with.
class WidgetConfigDraft {
  String? visualizerKey;
  List<String?> sourceKeys;
  Map<String, double> params;
  Reduction reduction;

  WidgetConfigDraft({
    this.visualizerKey,
    List<String?>? sourceKeys,
    Map<String, double>? params,
    this.reduction = Reduction.raw,
  }) : sourceKeys = sourceKeys ?? [],
       params = params ?? {};

  /// Reads a stored widget back. A key naming a reducer resolves to the base
  /// source plus its [reduction], so the sheet shows the pick rather than the
  /// derived stream the pick produced.
  factory WidgetConfigDraft.fromData(
    Map<String, dynamic> data,
    DataSourceRegistry registry,
  ) {
    final stored =
        (data['sourceKeys'] as List<dynamic>?)?.cast<String>() ?? const [];
    final reduced = stored.length == 1
        ? _splitReduction(stored.first, registry)
        : null;

    return WidgetConfigDraft(
      visualizerKey: data['visualizerKey'] as String?,
      sourceKeys: List<String?>.from(
        reduced == null ? stored : [reduced.baseName],
      ),
      params: _readParams(data['params']),
      reduction: reduced?.reduction ?? Reduction.raw,
    );
  }

  bool get isComplete =>
      visualizerKey != null && sourceKeys.every((k) => k != null);

  bool get hasSource => sourceKeys.any((k) => k != null);

  /// Reduction only applies to a single freely chosen source — there is no
  /// meaning to averaging one axis of a two-source plot, or half an oarlock.
  bool offersReduction(AnyVisualizer? visualizer) =>
      visualizer != null &&
      visualizer.sourceCount == 1 &&
      visualizer.sourceSelectionMode != SourceSelectionMode.forceAnglePair;

  void selectVisualizer(AnyVisualizer visualizer) {
    visualizerKey = visualizer.name;
    sourceKeys = List.filled(visualizer.sourceCount, null);
    params = {for (final p in visualizer.params) p.key: p.defaultValue};
    reduction = Reduction.raw;
  }

  /// Reshapes the selection to whatever [visualizer] expects — a stored widget
  /// can name a visualizer whose source count or settings have since changed.
  void syncTo(AnyVisualizer? visualizer) {
    if (visualizer == null) return;
    for (final p in visualizer.params) {
      params.putIfAbsent(p.key, () => p.defaultValue);
    }

    final count = visualizer.sourceCount;
    if (sourceKeys.length < count) {
      sourceKeys = [...sourceKeys, ...List.filled(count - sourceKeys.length, null)];
    } else if (sourceKeys.length > count) {
      sourceKeys = sourceKeys.sublist(0, count);
    }
    if (!offersReduction(visualizer)) reduction = Reduction.raw;
  }

  /// The widget data to store, with the chosen reduction resolved into a
  /// registered reducer source.
  Map<String, dynamic> toData({
    required String type,
    required DataSourceRegistry registry,
    required RecordingSession session,
  }) => {
    'type': type,
    'visualizerKey': visualizerKey,
    'sourceKeys': _effectiveSourceKeys(registry, session),
    'params': Map<String, double>.from(params),
  };

  /// Wraps a single source in a registered reducer when the user picked an
  /// average/peak reduction, reusing the reducer that is already registered.
  List<String> _effectiveSourceKeys(
    DataSourceRegistry registry,
    RecordingSession session,
  ) {
    final keys = List<String>.from(sourceKeys.whereType<String>());
    if (reduction == Reduction.raw || keys.length != 1) return keys;

    final base = registry.get(keys.first);
    if (base == null) return keys;

    final reduced = reducedSource(base, reduction, session);
    if (reduced == null) return keys;

    final existing = registry.get(reduced.name);
    if (existing != null) {
      reduced.dispose();
      return [existing.name];
    }
    registry.register(reduced);
    return [reduced.name];
  }

  /// The reducer behind [key], read from the live source when it is still
  /// registered and from its name when it is not — a preset outlives the
  /// derived sources it refers to.
  static ({Reduction reduction, String baseName})? _splitReduction(
    String key,
    DataSourceRegistry registry,
  ) {
    final source = registry.get(key);
    if (source is SessionReducerSource) {
      return (reduction: source.reduction, baseName: source.base.name);
    }
    return source == null ? splitReducedName(key) : null;
  }

  static Map<String, double> _readParams(dynamic raw) {
    if (raw is! Map) return {};
    final params = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) params[key.toString()] = value.toDouble();
    });
    return params;
  }
}
