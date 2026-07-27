import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

/// What still has to be chosen once a tile kind is picked.
enum TileInput {
  /// A visualizer, plus however many sources that visualizer declares.
  visualizer,

  /// Exactly one data source, bound directly.
  source,

  /// Nothing — the tile reads what it needs from the registry itself.
  none,
}

/// The kinds of tile a dashboard can hold: what each is called, what it looks
/// like, and what it has to be told before it can be placed.
///
/// [key] is the persistence key stored in `WidgetConfig.data['type']` and must
/// not change; everything else is presentation.
enum TileKind {
  chart(
    key: 'chart',
    label: 'Chart',
    icon: Icons.show_chart,
    description: 'A value traced over time, or against another value.',
    input: TileInput.visualizer,
    shapes: {
      VisualizerShape.series,
      VisualizerShape.xy,
      VisualizerShape.perStroke,
    },
  ),
  value(
    key: 'value',
    label: 'Value',
    icon: Icons.pin,
    description: 'The latest reading, as one large number.',
    input: TileInput.visualizer,
    shapes: {VisualizerShape.series, VisualizerShape.perStroke},
  ),
  bar(
    key: 'bar',
    label: 'Bar',
    icon: Icons.bar_chart,
    description: 'One bar per stroke, with the newest highlighted.',
    input: TileInput.visualizer,
    shapes: {VisualizerShape.perStroke},
  ),
  gauge(
    key: 'gauge',
    label: 'Gauge',
    icon: Icons.speed,
    description: 'A dial showing one oar angle live, with catch and finish.',
    input: TileInput.source,
  ),
  level(
    key: 'level',
    label: 'Level',
    icon: Icons.explore,
    description: 'Spirit level for boat roll and pitch, plus a surge arrow.',
    input: TileInput.none,
  ),
  schematic(
    key: 'schematic',
    label: 'Boat',
    icon: Icons.rowing,
    description: 'The boat from above, with every oar at its live angle.',
    input: TileInput.none,
  ),
  track(
    key: 'track',
    label: 'Map',
    icon: Icons.map,
    description: 'Map of the boat position and the track rowed so far.',
    input: TileInput.none,
  );

  final String key;
  final String label;
  final IconData icon;
  final String description;
  final TileInput input;

  /// Visualizer shapes this tile can draw. Empty for tiles that take no
  /// visualizer at all.
  final Set<VisualizerShape> shapes;

  const TileKind({
    required this.key,
    required this.label,
    required this.icon,
    required this.description,
    required this.input,
    this.shapes = const {},
  });

  static TileKind? fromKey(String? key) =>
      values.where((kind) => kind.key == key).firstOrNull;

  bool suits(AnyVisualizer visualizer) => shapes.contains(visualizer.shape);
}
