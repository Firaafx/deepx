class TrackerRuntimeConfig {
  const TrackerRuntimeConfig({
    required this.cursorMode,
    required this.sensitivityX,
    required this.sensitivityY,
    required this.smoothing,
    required this.deadZoneIrisX,
    required this.deadZoneIrisY,
    required this.deadZoneHeadYaw,
    required this.deadZoneHeadPitch,
    required this.deadZoneHandX,
    required this.deadZoneHandY,
    required this.showCursor,
  });

  final String cursorMode;
  final double sensitivityX;
  final double sensitivityY;
  final double smoothing;
  final double deadZoneIrisX;
  final double deadZoneIrisY;
  final double deadZoneHeadYaw;
  final double deadZoneHeadPitch;
  final double deadZoneHandX;
  final double deadZoneHandY;
  final bool showCursor;

  static const TrackerRuntimeConfig defaults = TrackerRuntimeConfig(
    cursorMode: 'head',
    sensitivityX: 100.0,
    sensitivityY: 100.0,
    smoothing: 85.0,
    deadZoneIrisX: 0.01,
    deadZoneIrisY: 0.01,
    deadZoneHeadYaw: 1.0,
    deadZoneHeadPitch: 1.0,
    deadZoneHandX: 0.01,
    deadZoneHandY: 0.01,
    showCursor: true,
  );

  factory TrackerRuntimeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return defaults;
    return TrackerRuntimeConfig(
      cursorMode: _mode(map['cursorMode']),
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
      showCursor: map['showCursor'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cursorMode': cursorMode,
      'sensitivityX': sensitivityX,
      'sensitivityY': sensitivityY,
      'smoothing': smoothing,
      'deadZoneIrisX': deadZoneIrisX,
      'deadZoneIrisY': deadZoneIrisY,
      'deadZoneHeadYaw': deadZoneHeadYaw,
      'deadZoneHeadPitch': deadZoneHeadPitch,
      'deadZoneHandX': deadZoneHandX,
      'deadZoneHandY': deadZoneHandY,
      'showCursor': showCursor,
    };
  }

  TrackerRuntimeConfig copyWith({
    String? cursorMode,
    double? sensitivityX,
    double? sensitivityY,
    double? smoothing,
    double? deadZoneIrisX,
    double? deadZoneIrisY,
    double? deadZoneHeadYaw,
    double? deadZoneHeadPitch,
    double? deadZoneHandX,
    double? deadZoneHandY,
    bool? showCursor,
  }) {
    return TrackerRuntimeConfig(
      cursorMode: cursorMode ?? this.cursorMode,
      sensitivityX: sensitivityX ?? this.sensitivityX,
      sensitivityY: sensitivityY ?? this.sensitivityY,
      smoothing: smoothing ?? this.smoothing,
      deadZoneIrisX: deadZoneIrisX ?? this.deadZoneIrisX,
      deadZoneIrisY: deadZoneIrisY ?? this.deadZoneIrisY,
      deadZoneHeadYaw: deadZoneHeadYaw ?? this.deadZoneHeadYaw,
      deadZoneHeadPitch: deadZoneHeadPitch ?? this.deadZoneHeadPitch,
      deadZoneHandX: deadZoneHandX ?? this.deadZoneHandX,
      deadZoneHandY: deadZoneHandY ?? this.deadZoneHandY,
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

  static double _toDouble(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}
