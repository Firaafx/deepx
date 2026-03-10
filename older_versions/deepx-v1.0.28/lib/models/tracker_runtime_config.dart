class TrackerRuntimeConfig {
  const TrackerRuntimeConfig({
    required this.cursorMode,
    required this.inputSource,
    required this.inputMode,
    required this.perfMode,
    required this.sensitivityX,
    required this.sensitivityY,
    required this.headSensitivityX,
    required this.headSensitivityY,
    required this.handSensitivityX,
    required this.handSensitivityY,
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
    required this.mouseTracking,
    required this.sendIris,
    required this.sendNose,
    required this.sendYawPitch,
    required this.sendFingertips,
    required this.sendFullFace,
    required this.sendFullHand,
    required this.sendAll,
    required this.sendNone,
    required this.showCursor,
    required this.dartCursorEnabled,
  });

  final String cursorMode;
  final String inputSource;
  final String inputMode;
  final String perfMode;
  final double sensitivityX;
  final double sensitivityY;
  final double headSensitivityX;
  final double headSensitivityY;
  final double handSensitivityX;
  final double handSensitivityY;
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
  final bool mouseTracking;
  final bool sendIris;
  final bool sendNose;
  final bool sendYawPitch;
  final bool sendFingertips;
  final bool sendFullFace;
  final bool sendFullHand;
  final bool sendAll;
  final bool sendNone;
  final bool showCursor;
  final bool dartCursorEnabled;

  static const TrackerRuntimeConfig defaults = TrackerRuntimeConfig(
    cursorMode: 'head',
    inputSource: 'local',
    inputMode: 'mediapipe',
    perfMode: 'medium',
    sensitivityX: 100.0,
    sensitivityY: 100.0,
    headSensitivityX: 100.0,
    headSensitivityY: 100.0,
    handSensitivityX: 500.0,
    handSensitivityY: 500.0,
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
    mouseTracking: false,
    sendIris: true,
    sendNose: true,
    sendYawPitch: true,
    sendFingertips: true,
    sendFullFace: false,
    sendFullHand: false,
    sendAll: true,
    sendNone: false,
    showCursor: true,
    dartCursorEnabled: false,
  );

  factory TrackerRuntimeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return defaults;
    return TrackerRuntimeConfig(
      cursorMode: _mode(map['cursorMode']),
      inputSource: _inputSource(map['inputSource']),
      inputMode: _inputMode(map['inputMode']),
      perfMode: _perfMode(map['perfMode']),
      sensitivityX: _toDouble(map['sensitivityX'], defaults.sensitivityX),
      sensitivityY: _toDouble(map['sensitivityY'], defaults.sensitivityY),
      headSensitivityX: _toDouble(
        map['headSensitivityX'],
        _toDouble(map['sensitivityX'], defaults.headSensitivityX),
      ),
      headSensitivityY: _toDouble(
        map['headSensitivityY'],
        _toDouble(map['sensitivityY'], defaults.headSensitivityY),
      ),
      handSensitivityX: _toDouble(
        map['handSensitivityX'],
        _toDouble(map['sensitivityX'], defaults.handSensitivityX),
      ),
      handSensitivityY: _toDouble(
        map['handSensitivityY'],
        _toDouble(map['sensitivityY'], defaults.handSensitivityY),
      ),
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
      mouseTracking: map['mouseTracking'] == true,
      sendIris: map['sendIris'] != false,
      sendNose: map['sendNose'] != false,
      sendYawPitch: map['sendYawPitch'] != false,
      sendFingertips: map['sendFingertips'] != false,
      sendFullFace: map['sendFullFace'] == true,
      sendFullHand: map['sendFullHand'] == true,
      sendAll: map['sendAll'] != false,
      sendNone: map['sendNone'] == true,
      showCursor: map['showCursor'] != false,
      dartCursorEnabled: map.containsKey('dartCursorEnabled')
          ? map['dartCursorEnabled'] == true
          : defaults.dartCursorEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cursorMode': cursorMode,
      'inputSource': inputSource,
      'inputMode': inputMode,
      'perfMode': perfMode,
      'sensitivityX': sensitivityX,
      'sensitivityY': sensitivityY,
      'headSensitivityX': headSensitivityX,
      'headSensitivityY': headSensitivityY,
      'handSensitivityX': handSensitivityX,
      'handSensitivityY': handSensitivityY,
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
      'mouseTracking': mouseTracking,
      'sendIris': sendIris,
      'sendNose': sendNose,
      'sendYawPitch': sendYawPitch,
      'sendFingertips': sendFingertips,
      'sendFullFace': sendFullFace,
      'sendFullHand': sendFullHand,
      'sendAll': sendAll,
      'sendNone': sendNone,
      'showCursor': showCursor,
      'dartCursorEnabled': dartCursorEnabled,
    };
  }

  TrackerRuntimeConfig copyWith({
    String? cursorMode,
    String? inputSource,
    String? inputMode,
    String? perfMode,
    double? sensitivityX,
    double? sensitivityY,
    double? headSensitivityX,
    double? headSensitivityY,
    double? handSensitivityX,
    double? handSensitivityY,
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
    bool? mouseTracking,
    bool? sendIris,
    bool? sendNose,
    bool? sendYawPitch,
    bool? sendFingertips,
    bool? sendFullFace,
    bool? sendFullHand,
    bool? sendAll,
    bool? sendNone,
    bool? showCursor,
    bool? dartCursorEnabled,
  }) {
    return TrackerRuntimeConfig(
      cursorMode: cursorMode ?? this.cursorMode,
      inputSource: inputSource ?? this.inputSource,
      inputMode: inputMode ?? this.inputMode,
      perfMode: perfMode ?? this.perfMode,
      sensitivityX: sensitivityX ?? this.sensitivityX,
      sensitivityY: sensitivityY ?? this.sensitivityY,
      headSensitivityX: headSensitivityX ?? this.headSensitivityX,
      headSensitivityY: headSensitivityY ?? this.headSensitivityY,
      handSensitivityX: handSensitivityX ?? this.handSensitivityX,
      handSensitivityY: handSensitivityY ?? this.handSensitivityY,
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
      mouseTracking: mouseTracking ?? this.mouseTracking,
      sendIris: sendIris ?? this.sendIris,
      sendNose: sendNose ?? this.sendNose,
      sendYawPitch: sendYawPitch ?? this.sendYawPitch,
      sendFingertips: sendFingertips ?? this.sendFingertips,
      sendFullFace: sendFullFace ?? this.sendFullFace,
      sendFullHand: sendFullHand ?? this.sendFullHand,
      sendAll: sendAll ?? this.sendAll,
      sendNone: sendNone ?? this.sendNone,
      showCursor: showCursor ?? this.showCursor,
      dartCursorEnabled: dartCursorEnabled ?? this.dartCursorEnabled,
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

  static String _inputSource(dynamic raw) {
    final value = raw?.toString().toLowerCase();
    if (value == 'local' || value == 'remote') {
      return value!;
    }
    return defaults.inputSource;
  }

  static String _inputMode(dynamic raw) {
    final value = raw?.toString().toLowerCase();
    if (value == 'mediapipe' ||
        value == 'mouse_hover' ||
        value == 'accelerometer' ||
        value == 'gyro') {
      return value!;
    }
    return defaults.inputMode;
  }

  static double _toDouble(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}
