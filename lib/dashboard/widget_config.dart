class WidgetConfig {
  final String id;
  final int x;
  final int y;
  final int w;
  final int h;
  final String type;

  /// Key into [StreamRegistry] — null means no stream assigned yet.
  final String? streamKey;

  const WidgetConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.type,
    this.streamKey,
  });

  WidgetConfig copyWith({
    int? x,
    int? y,
    int? w,
    int? h,
    String? type,
    String? streamKey,
  }) {
    return WidgetConfig(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      type: type ?? this.type,
      streamKey: streamKey ?? this.streamKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'type': type,
    'streamKey': streamKey,
  };

  factory WidgetConfig.fromJson(Map<String, dynamic> json) => WidgetConfig(
    id: json['id'] as String,
    x: json['x'] as int,
    y: json['y'] as int,
    w: json['w'] as int,
    h: json['h'] as int,
    type: json['type'] as String,
    streamKey: json['streamKey'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetConfig &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.type == type &&
      other.streamKey == streamKey;

  @override
  int get hashCode => Object.hash(id, x, y, w, h, type, streamKey);

  @override
  String toString() =>
      'WidgetConfig($id, x:$x y:$y w:$w h:$h type:$type stream:$streamKey)';
}
