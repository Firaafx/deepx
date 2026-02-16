class TrackingFrame {
  const TrackingFrame({
    required this.headX,
    required this.headY,
    required this.headZ,
    required this.yaw,
    required this.pitch,
    required this.cursorX,
    required this.cursorY,
    required this.wink,
    required this.pinch,
    required this.hasHand,
  });

  static const TrackingFrame zero = TrackingFrame(
    headX: 0,
    headY: 0,
    headZ: 0.2,
    yaw: 0,
    pitch: 0,
    cursorX: 0,
    cursorY: 0,
    wink: false,
    pinch: false,
    hasHand: false,
  );

  final double headX;
  final double headY;
  final double headZ;
  final double yaw;
  final double pitch;
  final double cursorX;
  final double cursorY;
  final bool wink;
  final bool pinch;
  final bool hasHand;

  Map<String, double> toHeadPoseMap() {
    return <String, double>{
      'x': headX,
      'y': headY,
      'z': headZ,
      'yaw': yaw,
      'pitch': pitch,
    };
  }

  factory TrackingFrame.fromTrackerPayload(
    Map<String, dynamic> payload, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final head = _toMap(payload['head']);
    final cursor = _toMap(payload['cursor']);
    final safeWidth = viewportWidth.isFinite && viewportWidth > 0
        ? viewportWidth
        : 1.0;
    final safeHeight = viewportHeight.isFinite && viewportHeight > 0
        ? viewportHeight
        : 1.0;
    return TrackingFrame(
      headX: _finiteOr(_toDouble(head['x'], 0), 0),
      headY: _finiteOr(_toDouble(head['y'], 0), 0),
      headZ: _finiteOr(_toDouble(head['z'], 0.2), 0.2),
      yaw: _finiteOr(_toDouble(head['yaw'], 0), 0),
      pitch: _finiteOr(_toDouble(head['pitch'], 0), 0),
      cursorX:
          _finiteOr(_toDouble(cursor['x'], safeWidth / 2), safeWidth / 2)
              .clamp(0, safeWidth),
      cursorY:
          _finiteOr(_toDouble(cursor['y'], safeHeight / 2), safeHeight / 2)
              .clamp(0, safeHeight),
      wink: payload['wink'] == true,
      pinch: payload['pinch'] == true,
      hasHand: payload['hand'] != null,
    );
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _finiteOr(double value, double fallback) {
    if (value.isNaN || value.isInfinite) return fallback;
    return value;
  }
}
