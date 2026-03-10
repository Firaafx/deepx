class PresetPayloadV2 {
  PresetPayloadV2({
    required this.mode,
    required this.scene,
    required this.controls,
    required this.meta,
  });

  static const int schemaVersion = 2;

  final String mode;
  final Map<String, dynamic> scene;
  final Map<String, dynamic> controls;
  final Map<String, dynamic> meta;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'mode': mode,
      'scene': scene,
      'controls': controls,
      'meta': meta,
    };
  }

  static bool isV2(Map<String, dynamic> payload) {
    return payload['schemaVersion'] == schemaVersion &&
        payload['scene'] is Map;
  }

  static PresetPayloadV2 fromLegacy({
    required String mode,
    required Map<String, dynamic> legacyScene,
    Map<String, dynamic>? controls,
    Map<String, dynamic>? meta,
  }) {
    return PresetPayloadV2(
      mode: mode,
      scene: legacyScene,
      controls: controls ?? <String, dynamic>{},
      meta: meta ?? <String, dynamic>{'upgradedFromLegacy': true},
    );
  }

  factory PresetPayloadV2.fromMap(Map<String, dynamic> payload,
      {required String fallbackMode}) {
    if (isV2(payload)) {
      return PresetPayloadV2(
        mode: (payload['mode']?.toString().toLowerCase() ?? fallbackMode),
        scene: Map<String, dynamic>.from(payload['scene'] as Map),
        controls: (payload['controls'] is Map)
            ? Map<String, dynamic>.from(payload['controls'] as Map)
            : <String, dynamic>{},
        meta: (payload['meta'] is Map)
            ? Map<String, dynamic>.from(payload['meta'] as Map)
            : <String, dynamic>{},
      );
    }

    return PresetPayloadV2.fromLegacy(
      mode: fallbackMode,
      legacyScene: payload,
    );
  }
}
