import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/since_threshold_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/time_window_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/time_elapsed_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer_param.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer_registry.dart';

class VisualizerProviderModel extends ChangeNotifier {
  final VisualizerRegistry registry = VisualizerRegistry();

  VisualizerProviderModel() {
    registry.register(Visualizer1(
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
    ));
    registry.register(Visualizer1(
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
    ));
  }
}

ChangeNotifierProvider<VisualizerProviderModel> visualizerProvider =
    ChangeNotifierProvider(create: (_) => VisualizerProviderModel());
