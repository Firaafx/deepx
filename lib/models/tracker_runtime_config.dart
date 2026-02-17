class TrackerRuntimeConfig {
  const TrackerRuntimeConfig({
    required this.cursorMode,
    required this.perfMode,
    required this.sensitivityX,
    required this.sensitivityY,
    required this.smoothing,
    required this.deadZoneIrisX,
    required this.deadZoneIrisY,
    required this.deadZoneHeadYaw,
    required this.deadZoneHeadPitch,
    required this.deadZoneHandX,
    required this.deadZoneHandY,
    required this.leftClosedThresh,
    required this.leftOpenThresh,
    required this.rightClosedThresh,
    required this.rightOpenThresh,
    required this.pinchThresh,
    required this.headSlowX,
    required this.headFastX,
    required this.headTransX,
    required this.headSlowY,
    required this.headFastY,
    required this.headTransY,
    required this.handSlowX,
    required this.handFastX,
    required this.handTransX,
    required this.handSlowY,
    required this.handFastY,
    required this.handTransY,
    required this.handDetectionConfidence,
    required this.handTrackingConfidence,
    required this.showCursor,
  });

  final String cursorMode;
  final String perfMode;
  final double sensitivityX;
  final double sensitivityY;
  final double smoothing;
  final double deadZoneIrisX;
  final double deadZoneIrisY;
  final double deadZoneHeadYaw;
  final double deadZoneHeadPitch;
  final double deadZoneHandX;
  final double deadZoneHandY;
  final double leftClosedThresh;
  final double leftOpenThresh;
  final double rightClosedThresh;
  final double rightOpenThresh;
  final double pinchThresh;
  final double headSlowX;
  final double headFastX;
  final double headTransX;
  final double headSlowY;
  final double headFastY;
  final double headTransY;
  final double handSlowX;
  final double handFastX;
  final double handTransX;
  final double handSlowY;
  final double handFastY;
  final double handTransY;
  final double handDetectionConfidence;
  final double handTrackingConfidence;
  final bool showCursor;

  static const TrackerRuntimeConfig defaults = TrackerRuntimeConfig(
    cursorMode: 'head',
    perfMode: 'medium',
    sensitivityX: 100.0,
    sensitivityY: 100.0,
    smoothing: 85.0,
    deadZoneIrisX: 0.01,
    deadZoneIrisY: 0.01,
    deadZoneHeadYaw: 1.0,
    deadZoneHeadPitch: 1.0,
    deadZoneHandX: 0.01,
    deadZoneHandY: 0.01,
    leftClosedThresh: 0.18,
    leftOpenThresh: 0.25,
    rightClosedThresh: 0.18,
    rightOpenThresh: 0.25,
    pinchThresh: 0.05,
    headSlowX: 0.1,
    headFastX: 1.0,
    headTransX: 5.0,
    headSlowY: 0.1,
    headFastY: 1.0,
    headTransY: 5.0,
    handSlowX: 1.0,
    handFastX: 10.0,
    handTransX: 0.001,
    handSlowY: 1.0,
    handFastY: 10.0,
    handTransY: 0.001,
    handDetectionConfidence: 0.75,
    handTrackingConfidence: 0.75,
    showCursor: true,
  );

  factory TrackerRuntimeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return defaults;
    return TrackerRuntimeConfig(
      cursorMode: _mode(map['cursorMode']),
      perfMode: _perfMode(map['perfMode']),
      sensitivityX: _toDouble(map['sensitivityX'], defaults.sensitivityX),
      sensitivityY: _toDouble(map['sensitivityY'], defaults.sensitivityY),
      smoothing: _toDouble(map['smoothing'], defaults.smoothing),
      deadZoneIrisX: _toDouble(map['deadZoneIrisX'], defaults.deadZoneIrisX),
      deadZoneIrisY: _toDouble(map['deadZoneIrisY'], defaults.deadZoneIrisY),
      deadZoneHeadYaw:
          _toDouble(map['deadZoneHeadYaw'], defaults.deadZoneHeadYaw),
      deadZoneHeadPitch:
          _toDouble(map['deadZoneHeadPitch'], defaults.deadZoneHeadPitch),
      deadZoneHandX: _toDouble(map['deadZoneHandX'], defaults.deadZoneHandX),
      deadZoneHandY: _toDouble(map['deadZoneHandY'], defaults.deadZoneHandY),
      leftClosedThresh:
          _toDouble(map['leftClosedThresh'], defaults.leftClosedThresh),
      leftOpenThresh: _toDouble(map['leftOpenThresh'], defaults.leftOpenThresh),
      rightClosedThresh:
          _toDouble(map['rightClosedThresh'], defaults.rightClosedThresh),
      rightOpenThresh:
          _toDouble(map['rightOpenThresh'], defaults.rightOpenThresh),
      pinchThresh: _toDouble(map['pinchThresh'], defaults.pinchThresh),
      headSlowX: _toDouble(map['headSlowX'], defaults.headSlowX),
      headFastX: _toDouble(map['headFastX'], defaults.headFastX),
      headTransX: _toDouble(map['headTransX'], defaults.headTransX),
      headSlowY: _toDouble(map['headSlowY'], defaults.headSlowY),
      headFastY: _toDouble(map['headFastY'], defaults.headFastY),
      headTransY: _toDouble(map['headTransY'], defaults.headTransY),
      handSlowX: _toDouble(map['handSlowX'], defaults.handSlowX),
      handFastX: _toDouble(map['handFastX'], defaults.handFastX),
      handTransX: _toDouble(map['handTransX'], defaults.handTransX),
      handSlowY: _toDouble(map['handSlowY'], defaults.handSlowY),
      handFastY: _toDouble(map['handFastY'], defaults.handFastY),
      handTransY: _toDouble(map['handTransY'], defaults.handTransY),
      handDetectionConfidence: _toDouble(
        map['handDetectionConfidence'],
        defaults.handDetectionConfidence,
      ),
      handTrackingConfidence: _toDouble(
        map['handTrackingConfidence'],
        defaults.handTrackingConfidence,
      ),
      showCursor: map['showCursor'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cursorMode': cursorMode,
      'perfMode': perfMode,
      'sensitivityX': sensitivityX,
      'sensitivityY': sensitivityY,
      'smoothing': smoothing,
      'deadZoneIrisX': deadZoneIrisX,
      'deadZoneIrisY': deadZoneIrisY,
      'deadZoneHeadYaw': deadZoneHeadYaw,
      'deadZoneHeadPitch': deadZoneHeadPitch,
      'deadZoneHandX': deadZoneHandX,
      'deadZoneHandY': deadZoneHandY,
      'leftClosedThresh': leftClosedThresh,
      'leftOpenThresh': leftOpenThresh,
      'rightClosedThresh': rightClosedThresh,
      'rightOpenThresh': rightOpenThresh,
      'pinchThresh': pinchThresh,
      'headSlowX': headSlowX,
      'headFastX': headFastX,
      'headTransX': headTransX,
      'headSlowY': headSlowY,
      'headFastY': headFastY,
      'headTransY': headTransY,
      'handSlowX': handSlowX,
      'handFastX': handFastX,
      'handTransX': handTransX,
      'handSlowY': handSlowY,
      'handFastY': handFastY,
      'handTransY': handTransY,
      'handDetectionConfidence': handDetectionConfidence,
      'handTrackingConfidence': handTrackingConfidence,
      'showCursor': showCursor,
    };
  }

  TrackerRuntimeConfig copyWith({
    String? cursorMode,
    String? perfMode,
    double? sensitivityX,
    double? sensitivityY,
    double? smoothing,
    double? deadZoneIrisX,
    double? deadZoneIrisY,
    double? deadZoneHeadYaw,
    double? deadZoneHeadPitch,
    double? deadZoneHandX,
    double? deadZoneHandY,
    double? leftClosedThresh,
    double? leftOpenThresh,
    double? rightClosedThresh,
    double? rightOpenThresh,
    double? pinchThresh,
    double? headSlowX,
    double? headFastX,
    double? headTransX,
    double? headSlowY,
    double? headFastY,
    double? headTransY,
    double? handSlowX,
    double? handFastX,
    double? handTransX,
    double? handSlowY,
    double? handFastY,
    double? handTransY,
    double? handDetectionConfidence,
    double? handTrackingConfidence,
    bool? showCursor,
  }) {
    return TrackerRuntimeConfig(
      cursorMode: cursorMode ?? this.cursorMode,
      perfMode: perfMode ?? this.perfMode,
      sensitivityX: sensitivityX ?? this.sensitivityX,
      sensitivityY: sensitivityY ?? this.sensitivityY,
      smoothing: smoothing ?? this.smoothing,
      deadZoneIrisX: deadZoneIrisX ?? this.deadZoneIrisX,
      deadZoneIrisY: deadZoneIrisY ?? this.deadZoneIrisY,
      deadZoneHeadYaw: deadZoneHeadYaw ?? this.deadZoneHeadYaw,
      deadZoneHeadPitch: deadZoneHeadPitch ?? this.deadZoneHeadPitch,
      deadZoneHandX: deadZoneHandX ?? this.deadZoneHandX,
      deadZoneHandY: deadZoneHandY ?? this.deadZoneHandY,
      leftClosedThresh: leftClosedThresh ?? this.leftClosedThresh,
      leftOpenThresh: leftOpenThresh ?? this.leftOpenThresh,
      rightClosedThresh: rightClosedThresh ?? this.rightClosedThresh,
      rightOpenThresh: rightOpenThresh ?? this.rightOpenThresh,
      pinchThresh: pinchThresh ?? this.pinchThresh,
      headSlowX: headSlowX ?? this.headSlowX,
      headFastX: headFastX ?? this.headFastX,
      headTransX: headTransX ?? this.headTransX,
      headSlowY: headSlowY ?? this.headSlowY,
      headFastY: headFastY ?? this.headFastY,
      headTransY: headTransY ?? this.headTransY,
      handSlowX: handSlowX ?? this.handSlowX,
      handFastX: handFastX ?? this.handFastX,
      handTransX: handTransX ?? this.handTransX,
      handSlowY: handSlowY ?? this.handSlowY,
      handFastY: handFastY ?? this.handFastY,
      handTransY: handTransY ?? this.handTransY,
      handDetectionConfidence:
          handDetectionConfidence ?? this.handDetectionConfidence,
      handTrackingConfidence:
          handTrackingConfidence ?? this.handTrackingConfidence,
      showCursor: showCursor ?? this.showCursor,
    );
  }

  static String _mode(dynamic raw) {
    final value = raw?.toString().toLowerCase();
    if (value == 'iris' || value == 'head' || value == 'hand') {
      return value!;
    }
    return defaults.cursorMode;
  }

  static String _perfMode(dynamic raw) {
    final value = raw?.toString().toLowerCase();
    if (value == 'low' || value == 'medium' || value == 'high') {
      return value!;
    }
    return defaults.perfMode;
  }

  static double _toDouble(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}
