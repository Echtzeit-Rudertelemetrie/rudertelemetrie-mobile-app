/// Position and size of a widget on the dashboard grid, plus an app-defined
/// [data] map for any extra metadata the app needs (widget type, stream key, …).
///
/// The framework only reads [id], [x], [y], [w], [h].  Everything in [data]
/// is opaque to the framework — put whatever you like there.
class WidgetConfig {
  final String id;
  final int x;
  final int y;
  final int w;
  final int h;

  /// App-defined metadata. The dashboard framework never inspects this.
  final Map<String, dynamic> data;

  const WidgetConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.data = const {},
  });

  WidgetConfig copyWith({
    int? x,
    int? y,
    int? w,
    int? h,
    Map<String, dynamic>? data,
  }) {
    return WidgetConfig(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'data': data,
  };

  factory WidgetConfig.fromJson(Map<String, dynamic> json) => WidgetConfig(
    id: json['id'] as String,
    x: json['x'] as int,
    y: json['y'] as int,
    w: json['w'] as int,
    h: json['h'] as int,
    data: (json['data'] as Map<String, dynamic>?) ?? {},
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetConfig &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(id, x, y, w, h);

  @override
  String toString() => 'WidgetConfig($id, x:$x y:$y w:$w h:$h)';
}
