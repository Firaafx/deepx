import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceSettings {
  const AppearanceSettings({
    required this.ambientBlurSigmaX,
    required this.ambientBlurSigmaY,
  });

  final double ambientBlurSigmaX;
  final double ambientBlurSigmaY;

  AppearanceSettings copyWith({
    double? ambientBlurSigmaX,
    double? ambientBlurSigmaY,
  }) {
    return AppearanceSettings(
      ambientBlurSigmaX: ambientBlurSigmaX ?? this.ambientBlurSigmaX,
      ambientBlurSigmaY: ambientBlurSigmaY ?? this.ambientBlurSigmaY,
    );
  }
}

class AppearanceSettingsService {
  AppearanceSettingsService._();

  static final AppearanceSettingsService instance =
      AppearanceSettingsService._();

  static const double _defaultSigma = 56;
  static const String _sigmaXKey = 'appearance.blurSigmaX';
  static const String _sigmaYKey = 'appearance.blurSigmaY';

  final ValueNotifier<AppearanceSettings> settings =
      ValueNotifier<AppearanceSettings>(
    const AppearanceSettings(
      ambientBlurSigmaX: _defaultSigma,
      ambientBlurSigmaY: _defaultSigma,
    ),
  );

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final double sigmaX = _prefs?.getDouble(_sigmaXKey) ?? _defaultSigma;
    final double sigmaY = _prefs?.getDouble(_sigmaYKey) ?? _defaultSigma;
    settings.value = AppearanceSettings(
      ambientBlurSigmaX: sigmaX,
      ambientBlurSigmaY: sigmaY,
    );
  }

  void updateSigmaX(double value) {
    final double next = value.clamp(0, 100);
    settings.value = settings.value.copyWith(ambientBlurSigmaX: next);
    _prefs?.setDouble(_sigmaXKey, next);
  }

  void updateSigmaY(double value) {
    final double next = value.clamp(0, 100);
    settings.value = settings.value.copyWith(ambientBlurSigmaY: next);
    _prefs?.setDouble(_sigmaYKey, next);
  }
}
