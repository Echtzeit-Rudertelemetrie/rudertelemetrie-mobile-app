import 'package:flutter/material.dart';
import 'widget_config.dart';

typedef DashboardWidgetBuilder =
    Widget Function(BuildContext context, WidgetConfig config);

/// Maps widget type strings to builder closures.
/// Register all widget types once at app startup.
class WidgetRegistry {
  WidgetRegistry._();

  static final Map<String, DashboardWidgetBuilder> _map = {};

  static void register(String type, DashboardWidgetBuilder builder) {
    _map[type] = builder;
  }

  static Iterable<String> get registeredTypes => _map.keys;

  static Widget build(BuildContext context, WidgetConfig config) {
    final builder = _map[config.type];
    if (builder != null) return builder(context, config);
    return _Placeholder(config: config);
  }
}

class _Placeholder extends StatelessWidget {
  final WidgetConfig config;

  const _Placeholder({required this.config});

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      config.type,
      style: const TextStyle(color: Colors.white54, fontSize: 12),
    ),
  );
}
