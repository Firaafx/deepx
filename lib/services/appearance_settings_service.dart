import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceSettings {
  const AppearanceSettings({
    required this.ambientBlurSigmaX,
    required this.ambientBlurSigmaY,
    required this.svgCardBlurSigma,
    required this.wallpaperImageUrl,
    required this.wallpaperOverlayColor,
    required this.wallpaperOverlayOpacity,
  });

  final double ambientBlurSigmaX;
  final double ambientBlurSigmaY;
  final double svgCardBlurSigma;
  final String wallpaperImageUrl;
  final int wallpaperOverlayColor;
  final double wallpaperOverlayOpacity;

  AppearanceSettings copyWith({
    double? ambientBlurSigmaX,
    double? ambientBlurSigmaY,
    double? svgCardBlurSigma,
    String? wallpaperImageUrl,
    int? wallpaperOverlayColor,
    double? wallpaperOverlayOpacity,
  }) {
    return AppearanceSettings(
      ambientBlurSigmaX: ambientBlurSigmaX ?? this.ambientBlurSigmaX,
      ambientBlurSigmaY: ambientBlurSigmaY ?? this.ambientBlurSigmaY,
      svgCardBlurSigma: svgCardBlurSigma ?? this.svgCardBlurSigma,
      wallpaperImageUrl: wallpaperImageUrl ?? this.wallpaperImageUrl,
      wallpaperOverlayColor:
          wallpaperOverlayColor ?? this.wallpaperOverlayColor,
      wallpaperOverlayOpacity:
          wallpaperOverlayOpacity ?? this.wallpaperOverlayOpacity,
    );
  }
}

class AppearanceSettingsService {
  AppearanceSettingsService._();

  static final AppearanceSettingsService instance =
      AppearanceSettingsService._();

  static const double _defaultSigma = 56;
  static const double _defaultSvgCardBlurSigma = 75;
  static const String _sigmaXKey = 'appearance.blurSigmaX';
  static const String _sigmaYKey = 'appearance.blurSigmaY';
  static const String _svgCardBlurSigmaKey = 'appearance.svgCardBlurSigma';
  static const String _wallpaperUrlKey = 'appearance.wallpaperImageUrl';
  static const String _wallpaperOverlayColorKey =
      'appearance.wallpaperOverlayColor';
  static const String _wallpaperOverlayOpacityKey =
      'appearance.wallpaperOverlayOpacity';

  final ValueNotifier<AppearanceSettings> settings =
      ValueNotifier<AppearanceSettings>(
    const AppearanceSettings(
      ambientBlurSigmaX: _defaultSigma,
      ambientBlurSigmaY: _defaultSigma,
      svgCardBlurSigma: _defaultSvgCardBlurSigma,
      wallpaperImageUrl: '',
      wallpaperOverlayColor: 0xFF000000,
      wallpaperOverlayOpacity: 0.18,
    ),
  );

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final double sigmaX = _prefs?.getDouble(_sigmaXKey) ?? _defaultSigma;
    final double sigmaY = _prefs?.getDouble(_sigmaYKey) ?? _defaultSigma;
    final double svgCardBlurSigma =
        (_prefs?.getDouble(_svgCardBlurSigmaKey) ?? _defaultSvgCardBlurSigma)
            .clamp(0.0, 100.0)
            .toDouble();
    final String wallpaperUrl = _prefs?.getString(_wallpaperUrlKey) ?? '';
    final int overlayColor =
        _prefs?.getInt(_wallpaperOverlayColorKey) ?? 0xFF000000;
    final double overlayOpacity =
        (_prefs?.getDouble(_wallpaperOverlayOpacityKey) ?? 0.18)
            .clamp(0.0, 1.0)
            .toDouble();
    settings.value = AppearanceSettings(
      ambientBlurSigmaX: sigmaX,
      ambientBlurSigmaY: sigmaY,
      svgCardBlurSigma: svgCardBlurSigma,
      wallpaperImageUrl: wallpaperUrl,
      wallpaperOverlayColor: overlayColor,
      wallpaperOverlayOpacity: overlayOpacity,
    );
  }

  void updateSigmaX(double value) {
    final double next = value.clamp(0.0, 100.0).toDouble();
    settings.value = settings.value.copyWith(ambientBlurSigmaX: next);
    _prefs?.setDouble(_sigmaXKey, next);
  }

  void updateSigmaY(double value) {
    final double next = value.clamp(0.0, 100.0).toDouble();
    settings.value = settings.value.copyWith(ambientBlurSigmaY: next);
    _prefs?.setDouble(_sigmaYKey, next);
  }

  void updateSvgCardBlurSigma(double value) {
    final double next = value.clamp(0.0, 100.0).toDouble();
    settings.value = settings.value.copyWith(svgCardBlurSigma: next);
    _prefs?.setDouble(_svgCardBlurSigmaKey, next);
  }

  void updateWallpaperImageUrl(String value) {
    final String next = value.trim();
    settings.value = settings.value.copyWith(wallpaperImageUrl: next);
    _prefs?.setString(_wallpaperUrlKey, next);
  }

  void clearWallpaperImage() {
    settings.value = settings.value.copyWith(wallpaperImageUrl: '');
    _prefs?.remove(_wallpaperUrlKey);
  }

  void updateWallpaperOverlayColor(int value) {
    settings.value = settings.value.copyWith(wallpaperOverlayColor: value);
    _prefs?.setInt(_wallpaperOverlayColorKey, value);
  }

  void updateWallpaperOverlayOpacity(double value) {
    final double next = value.clamp(0.0, 1.0).toDouble();
    settings.value = settings.value.copyWith(wallpaperOverlayOpacity: next);
    _prefs?.setDouble(_wallpaperOverlayOpacityKey, next);
  }
}
