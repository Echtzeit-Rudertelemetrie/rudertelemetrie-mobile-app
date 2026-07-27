import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/drive_gated_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/per_stroke_bar_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/since_threshold_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/smoothed_xy_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/time_window_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/stroke_index_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/time_elapsed_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/value_vs_value_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer_param.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer_registry.dart';

class VisualizerProviderModel extends ChangeNotifier {
  final VisualizerRegistry registry = VisualizerRegistry();

  VisualizerProviderModel() {
    registry.register(
      Visualizer1(
        name: 'Time Window',
        combinator: TimeElapsedCombinator(Unit.s),
        params: const [
          VisualizerParam(
            key: 'windowSeconds',
            label: 'Time window',
            defaultValue: 20,
            min: 1,
            unitLabel: 's',
          ),
        ],
        buildCollector: (p) => TimeWindowCollector(
          Duration(milliseconds: (p['windowSeconds']! * 1000).round()),
        ),
      ),
    );
    registry.register(
      Visualizer1(
        name: 'Since Threshold',
        combinator: TimeElapsedCombinator(Unit.s),
        params: const [
          VisualizerParam(
            key: 'threshold',
            label: 'Threshold',
            defaultValue: 50,
          ),
        ],
        buildCollector: (p) => SinceThresholdCollector(p['threshold']!),
      ),
    );
    registry.register(
      Visualizer2(
        name: 'X vs Y (Window)',
        combinator: ValueVsValueCombinator(),
        params: const [
          VisualizerParam(
            key: 'windowSeconds',
            label: 'Freshness window',
            defaultValue: 4,
            min: 1,
            unitLabel: 's',
          ),
        ],
        buildCollector: (p) {
          final window = Duration(
            milliseconds: (p['windowSeconds']! * 1000).round(),
          );
          return SmoothedXyCollector(
            TimeWindowCollector(window),
            maxAge: window,
          );
        },
      ),
    );
    registry.register(
      Visualizer2(
        name: 'X vs Y (Stroke)',
        combinator: ValueVsValueCombinator(),
        params: const [
          VisualizerParam(
            key: 'threshold',
            label: 'Threshold',
            defaultValue: 50,
          ),
        ],
        buildCollector: (p) => SmoothedXyCollector(
          SinceThresholdCollector(p['threshold']!),
          maxAge: const Duration(days: 1),
        ),
      ),
    );
    // Force/angle curve segmented on true drive boundaries with hysteresis
    // (catch ↑ F_on, finish ↓ F_off) — bind X = Angle, Y = Force N.
    registry.register(
      Visualizer2(
        name: 'Force vs Angle (Drive)',
        combinator: ValueVsValueCombinator(),
        params: const [
          VisualizerParam(
            key: 'fOn',
            label: 'Catch force (F_on)',
            defaultValue: 40,
            unitLabel: 'N',
          ),
          VisualizerParam(
            key: 'fOff',
            label: 'Finish force (F_off)',
            defaultValue: 20,
            unitLabel: 'N',
          ),
        ],
        buildCollector: (p) => SmoothedXyCollector(
          DriveGatedCollector(fOn: p['fOn']!, fOff: p['fOff']!),
          maxAge: const Duration(days: 1),
        ),
      ),
    );
    // One bar per stroke for any per-stroke source (group "Stroke").
    registry.register(
      Visualizer1(
        name: 'Per-Stroke Bars',
        combinator: StrokeIndexCombinator(),
        params: const [
          VisualizerParam(
            key: 'strokeWindow',
            label: 'Strokes shown',
            defaultValue: 20,
            min: 1,
          ),
        ],
        buildCollector: (p) =>
            PerStrokeBarCollector(p['strokeWindow']!.round()),
      ),
    );
  }
}

ChangeNotifierProvider<VisualizerProviderModel> visualizerProvider =
    ChangeNotifierProvider(create: (_) => VisualizerProviderModel());
