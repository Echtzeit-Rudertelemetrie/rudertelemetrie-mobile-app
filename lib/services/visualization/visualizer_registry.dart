import 'visualizer.dart';

class VisualizerRegistry {
  final Map<String, AnyVisualizer> _visualizers = {};

  void register(AnyVisualizer visualizer) =>
      _visualizers[visualizer.name] = visualizer;

  AnyVisualizer? get(String key) => _visualizers[key];

  List<AnyVisualizer> get all => List.unmodifiable(_visualizers.values);
}
