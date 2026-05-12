import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/since_threshold_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/time_window_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/time_elapsed_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer_registry.dart';

class VisualizerProviderModel extends ChangeNotifier {
  final VisualizerRegistry registry = VisualizerRegistry();

  VisualizerProviderModel() {
    registry.register(Visualizer1(
      name: 'Time Window',
      combinator: TimeElapsedCombinator(Unit.s),
      collector: TimeWindowCollector(const Duration(seconds: 20)),
    ));
    registry.register(Visualizer1(
      name: 'Since Threshold',
      combinator: TimeElapsedCombinator(Unit.s),
      collector: SinceThresholdCollector(50.0),
    ));
  }
}

ChangeNotifierProvider<VisualizerProviderModel> visualizerProvider =
    ChangeNotifierProvider(create: (_) => VisualizerProviderModel());
