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
    final head = (payload['head'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cursor =
        (payload['cursor'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TrackingFrame(
      headX: _toDouble(head['x'], 0),
      headY: _toDouble(head['y'], 0),
      headZ: _toDouble(head['z'], 0.2),
      yaw: _toDouble(head['yaw'], 0),
      pitch: _toDouble(head['pitch'], 0),
      cursorX: _toDouble(cursor['x'], viewportWidth / 2)
          .clamp(0, viewportWidth),
      cursorY: _toDouble(cursor['y'], viewportHeight / 2)
          .clamp(0, viewportHeight),
      wink: payload['wink'] == true,
      pinch: payload['pinch'] == true,
      hasHand: payload['hand'] != null,
    );
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
