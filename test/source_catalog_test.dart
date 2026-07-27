import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/tile_kind.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_catalog.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';

void main() {
  group('sourceInfoFor', () {
    test('strips the sensor index and device tag from an oarlock source', () {
      final info = sourceInfoFor(
        'Blade Force 1 (A3F2)',
        group: 'Force & Power (Oarlock 1 (A3F2))',
      );

      expect(info.label, 'Blade Force');
      expect(info.category, SourceCategory.oarlock);
      expect(info.description, isNotNull);
    });

    test('strips a bare device tag from a boat source', () {
      final info = sourceInfoFor('Acceleration X (A3F2)', group: 'Boat (A3F2)');

      expect(info.label, 'Acceleration X');
      expect(info.category, SourceCategory.boat);
    });

    test('keeps a name whose own parenthesis is part of the metric', () {
      expect(sourceInfoFor('Pace (/500m)').label, 'Pace (/500m)');
      expect(sourceInfoFor('Pace (/500m)').category, SourceCategory.session);
      expect(sourceInfoFor('Crew Sync (finish)').label, 'Crew Sync (finish)');
    });

    test('a whole-name match wins over the suffix-stripped one', () {
      expect(sourceInfoFor('Speed (km/h)').category, SourceCategory.session);
      expect(
        sourceInfoFor('Speed (A3F2)', group: 'Boat (A3F2)').category,
        SourceCategory.boat,
      );
    });

    test('an uncatalogued metric falls back to the group for its category', () {
      final info = sourceInfoFor('Rudder Angle 1 (A3F2)', group: 'Boat (A3F2)');

      expect(info.label, 'Rudder Angle');
      expect(info.category, SourceCategory.boat);
      expect(info.description, isNull);
    });

    test('an uncatalogued metric without a group is Other', () {
      expect(sourceInfoFor('Something New').category, SourceCategory.other);
    });
  });

  group('DataSource.info', () {
    test('a plain source reads its catalog entry', () {
      final source = PushDataSource(
        name: 'Stroke Rate',
        unit: Unit.spm,
        group: 'Stroke',
      );
      addTearDown(source.dispose);

      expect(source.info.label, 'Stroke Rate');
      expect(source.info.category, SourceCategory.stroke);
      expect(source.derived, isFalse);
    });

    test('a reducer is derived and labels itself off its base', () {
      final session = RecordingSession(registry: DataSourceRegistry());
      addTearDown(session.dispose);
      final base = PushDataSource(
        name: 'Blade Force 1 (A3F2)',
        unit: Unit.N,
        group: 'Force & Power (Oarlock 1 (A3F2))',
      );
      addTearDown(base.dispose);

      final peak = SessionPeakSource(base, session);
      addTearDown(peak.dispose);

      expect(peak.derived, isTrue);
      expect(peak.info.label, 'Peak Blade Force');
      expect(peak.info.category, SourceCategory.oarlock);
      expect(peak.info.description, describeReduction(Reduction.peak));
    });
  });

  group('TileKind', () {
    test('round-trips the keys stored in widget config data', () {
      for (final kind in TileKind.values) {
        expect(TileKind.fromKey(kind.key), kind);
      }
    });

    test('is null for an unknown or missing stored type', () {
      expect(TileKind.fromKey('sparkline'), isNull);
      expect(TileKind.fromKey(null), isNull);
    });

    test('only visualizer tiles declare shapes they can draw', () {
      for (final kind in TileKind.values) {
        expect(
          kind.shapes.isNotEmpty,
          kind.input == TileInput.visualizer,
          reason: kind.name,
        );
      }
    });
  });
}
