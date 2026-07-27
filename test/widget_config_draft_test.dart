import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config_draft.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';

void main() {
  late DataSourceRegistry registry;
  late RecordingSession session;

  setUp(() {
    registry = DataSourceRegistry();
    session = RecordingSession(registry: registry);
    registry.register(PushDataSource(name: 'Force (EE01)', unit: Unit.N));
  });

  Map<String, dynamic> data({
    required List<String> sourceKeys,
    String visualizer = 'Force over time',
  }) => {
    'type': 'value',
    'visualizerKey': visualizer,
    'sourceKeys': sourceKeys,
    'params': {'window': 5.0},
  };

  test('a plain source is read back as itself, unreduced', () {
    final draft = WidgetConfigDraft.fromData(
      data(sourceKeys: ['Force (EE01)']),
      registry,
    );

    expect(draft.sourceKeys, ['Force (EE01)']);
    expect(draft.reduction, Reduction.raw);
    expect(draft.params['window'], 5.0);
    expect(draft.isComplete, isTrue);
  });

  test('a reduction survives a store/read round trip', () {
    final stored = WidgetConfigDraft(
      visualizerKey: 'Force over time',
      sourceKeys: ['Force (EE01)'],
      reduction: Reduction.peak,
    ).toData(type: 'value', registry: registry, session: session);

    final draft = WidgetConfigDraft.fromData(stored, registry);

    expect(stored['sourceKeys'], ['Peak Force (EE01)']);
    expect(draft.sourceKeys, ['Force (EE01)']);
    expect(draft.reduction, Reduction.peak);
  });

  test('reducing the same source twice reuses the registered reducer', () {
    Map<String, dynamic> store() => WidgetConfigDraft(
      visualizerKey: 'Force over time',
      sourceKeys: ['Force (EE01)'],
      reduction: Reduction.average,
    ).toData(type: 'value', registry: registry, session: session);

    store();
    final second = store();

    expect(second['sourceKeys'], ['Avg Force (EE01)']);
    expect(
      registry.all.where((s) => s.name == 'Avg Force (EE01)').length,
      1,
    );
  });

  /// A reducer is a live object, not a saved one: after a restart the preset
  /// still names it while the registry only holds the base source.
  test('a reduction is recovered from a key whose reducer is gone', () {
    final draft = WidgetConfigDraft.fromData(
      data(sourceKeys: ['Avg Force (EE01)']),
      registry,
    );

    expect(draft.sourceKeys, ['Force (EE01)']);
    expect(draft.reduction, Reduction.average);
  });

  test('raw stores the base source untouched', () {
    final stored = WidgetConfigDraft(
      visualizerKey: 'Force over time',
      sourceKeys: ['Force (EE01)'],
    ).toData(type: 'value', registry: registry, session: session);

    expect(stored['sourceKeys'], ['Force (EE01)']);
    expect(registry.get('Avg Force (EE01)'), isNull);
  });
}
