import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

bool get eyedropperSupported => globalContext.has('EyeDropper');

Future<Color?> pickScreenColor() async {
  if (!eyedropperSupported) return null;

  final JSAny? constructorValue = globalContext['EyeDropper'];
  if (constructorValue == null) return null;
  final JSObject eyeDropper =
      (constructorValue as JSFunction).callAsConstructor<JSObject>();
  final JSPromise<JSObject?> promise =
      eyeDropper.callMethod<JSPromise<JSObject?>>('open'.toJS);
  final JSObject? result = await promise.toDart;
  final String? hex = (result?['sRGBHex'] as JSString?)?.toDart;
  if (hex == null || hex.isEmpty) return null;
  return _colorFromHex(hex);
}

Color? _colorFromHex(String value) {
  final String normalized = value.trim().toUpperCase();
  final RegExp pattern = RegExp(r'^#?[0-9A-F]{6}$');
  if (!pattern.hasMatch(normalized)) return null;
  final String withHash =
      normalized.startsWith('#') ? normalized : '#$normalized';
  final int? parsed = int.tryParse(withHash.substring(1), radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}
