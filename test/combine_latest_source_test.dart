import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/combine_latest_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';

void main() {
  test(
    'emits once per aligned timestamp pair, using both latest values',
    () async {
      final a = PushDataSource(name: 'A', unit: Unit.N);
      final b = PushDataSource(name: 'B', unit: Unit.deg);
      final combined = CombineLatestSource(
        name: 'A+B',
        unit: Unit.N,
        sources: [a, b],
        compute: (v) => v[0] + v[1],
      );
      addTearDown(combined.dispose);

      final out = <double>[];
      combined.data.listen((m) => out.add(m.value));

      final t1 = DateTime.fromMillisecondsSinceEpoch(1000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1010);
      a.add(Measurement(value: 3, timestamp: t1));
      b.add(Measurement(value: 4, timestamp: t1)); // aligned -> emit 7
      a.add(Measurement(value: 5, timestamp: t2));
      b.add(Measurement(value: 6, timestamp: t2)); // aligned -> emit 11
      await pumpEventQueue();

      expect(out, [7, 11]);
    },
  );

  test(
    'does not emit while a timestamp is unaligned beyond tolerance',
    () async {
      final a = PushDataSource(name: 'A', unit: Unit.N);
      final b = PushDataSource(name: 'B', unit: Unit.deg);
      final combined = CombineLatestSource(
        name: 'A+B',
        unit: Unit.N,
        sources: [a, b],
        compute: (v) => v[0] + v[1],
      );
      addTearDown(combined.dispose);

      final out = <double>[];
      combined.data.listen((m) => out.add(m.value));

      a.add(
        Measurement(
          value: 3,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      // 100 ms apart, far beyond the 5 ms alignment tolerance.
      b.add(
        Measurement(
          value: 4,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1100),
        ),
      );
      await pumpEventQueue();

      expect(out, isEmpty);
    },
  );
}
