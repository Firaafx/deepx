import 'package:flutter/material.dart';

// Begin custom widget code

// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async' show Timer;

import 'package:flutter/gestures.dart';

import 'package:collection/collection.dart';

import 'dart:math' as math;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

class LayerConfig {
  double x, y, scale;

  int order;

  bool isVisible;

  bool isLocked;

  final String? url;

  String name;

  // Text Properties

  bool isText;

  String? textValue;

  double fontSize;

  int fontWeightIndex;

  bool isItalic;

  double shadowBlur;

  String shadowColorHex;

  double strokeWidth;

  String strokeColorHex;

  String textColorHex;

  String fontFamily;

  // Constraints & Sensitivity

  double minScale, maxScale;

  double minX, maxX, minY, maxY;

  bool canShift, canZoom, canTilt;

  double shiftSensMult, zoomSensMult;

  // New for rectangles/bezels

  bool isRect;

  String bezelType; // 'top' or 'bottom' or ''

  LayerConfig({
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.isVisible = true,
    this.isLocked = false,
    required this.order,
    this.url,
    required this.name,
    this.isText = false,
    this.textValue = "New Text",
    this.fontSize = 40.0,
    this.fontWeightIndex = 4,
    this.isItalic = false,
    this.shadowBlur = 0.0,
    this.shadowColorHex = "#000000",
    this.strokeWidth = 0.0,
    this.strokeColorHex = "#000000",
    this.textColorHex = "#FFFFFF",
    this.fontFamily = 'Poppins',
    this.minScale = 0.1,
    this.maxScale = 5.0,
    this.minX = -3000.0,
    this.maxX = 3000.0,
    this.minY = -3000.0,
    this.maxY = 3000.0,
    this.canShift = true,
    this.canZoom = true,
    this.canTilt = true,
    this.shiftSensMult = 1.0,
    this.zoomSensMult = 1.0,
    this.isRect = false,
    this.bezelType = '',
  });

  LayerConfig copy() {
    return LayerConfig(
      x: x,
      y: y,
      scale: scale,
      order: order,
      isVisible: isVisible,
      isLocked: isLocked,
      url: url,
      name: "${name}_copy",
      isText: isText,
      textValue: textValue,
      fontSize: fontSize,
      fontWeightIndex: fontWeightIndex,
      isItalic: isItalic,
      shadowBlur: shadowBlur,
      shadowColorHex: shadowColorHex,
      strokeWidth: strokeWidth,
      strokeColorHex: strokeColorHex,
      textColorHex: textColorHex,
      fontFamily: fontFamily,
      minScale: minScale,
      maxScale: maxScale,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      canShift: canShift,
      canZoom: canZoom,
      canTilt: canTilt,
      shiftSensMult: shiftSensMult,
      zoomSensMult: zoomSensMult,
      isRect: isRect,
      bezelType: bezelType,
    );
  }

  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
        'scale': scale,
        'order': order,
        'isVisible': isVisible,
        'isLocked': isLocked,
        'isText': isText,
        'textValue': textValue,
        'fontSize': fontSize,
        'fontWeightIndex': fontWeightIndex,
        'isItalic': isItalic,
        'shadowBlur': shadowBlur,
        'shadowColorHex': shadowColorHex,
        'strokeWidth': strokeWidth,
        'strokeColorHex': strokeColorHex,
        'textColorHex': textColorHex,
        'fontFamily': fontFamily,
        'minScale': minScale,
        'maxScale': maxScale,
        'minX': minX,
        'maxX': maxX,
        'minY': minY,
        'maxY': maxY,
        'canShift': canShift,
        'canZoom': canZoom,
        'canTilt': canTilt,
        'shiftSensMult': shiftSensMult,
        'zoomSensMult': zoomSensMult,
        'url': url,
        'name': name,
        'isRect': isRect,
        'bezelType': bezelType,
      };

  factory LayerConfig.fromMap(
      Map<String, dynamic> map, String? url, String name, int defaultOrder) {
    return LayerConfig(
      x: (map['x'] ?? 0.0).toDouble(),
      y: (map['y'] ?? 0.0).toDouble(),
      scale: (map['scale'] ?? 1.0).toDouble(),
      order: map['order'] ?? defaultOrder,
      isVisible: map['isVisible'] ?? true,
      isLocked: map['isLocked'] ?? false,
      isText: map['isText'] ?? false,
      textValue: map['textValue'] ?? "New Text",
      fontSize: (map['fontSize'] ?? 40.0).toDouble(),
      fontWeightIndex: map['fontWeightIndex'] ?? 4,
      isItalic: map['isItalic'] ?? false,
      shadowBlur: (map['shadowBlur'] ?? 0.0).toDouble(),
      shadowColorHex: map['shadowColorHex'] ?? "#000000",
      strokeWidth: (map['strokeWidth'] ?? 0.0).toDouble(),
      strokeColorHex: map['strokeColorHex'] ?? "#000000",
      textColorHex: map['textColorHex'] ?? "#FFFFFF",
      fontFamily: map['fontFamily'] ?? 'Poppins',
      url: url ?? map['url'],
      name: name,
      minScale: (map['minScale'] ?? 0.1).toDouble(),
      maxScale: (map['maxScale'] ?? 5.0).toDouble(),
      minX: (map['minX'] ?? -3000.0).toDouble(),
      maxX: (map['maxX'] ?? 3000.0).toDouble(),
      minY: (map['minY'] ?? -3000.0).toDouble(),
      maxY: (map['maxY'] ?? 3000.0).toDouble(),
      canShift: map['canShift'] ?? true,
      canZoom: map['canZoom'] ?? true,
      canTilt: map['canTilt'] ?? true,
      shiftSensMult: (map['shiftSensMult'] ?? 1.0).toDouble(),
      zoomSensMult: (map['zoomSensMult'] ?? 1.0).toDouble(),
      isRect: map['isRect'] ?? false,
      bezelType: map['bezelType'] ?? '',
    );
  }
}

class LayerMode extends StatefulWidget {
  const LayerMode({super.key, this.width, this.height});

  final double? width, height;

  @override
  State<LayerMode> createState() => _LayerModeState();
}

class _LayerModeState extends State<LayerMode> {
  final List<String> availableFonts = [
    'Poppins',
    'Roboto',
    'Montserrat',
    'Open Sans',
    'Lato',
    'Oswald',
    'Raleway',
    'Playfair Display',
    'Bebas Neue',
    'Pacifico'
  ];

  final List<String> aspectRatios = [
    '16:9 (width:height)',
    '18:9 (width:height)',
    '21:9 (width:height)',
    '4:3 (width:height)',
    '1:1 (square)',
    '9:16 (height:width)',
    '3:4 (height:width)',
    '2.35:1 (width:height)',
    '1.85:1 (width:height)',
    '2.39:1 (width:height)'
  ];

  String? selectedAspect = null;

  double headX = 0, headY = 0, yaw = 0, pitch = 0, zValue = 100, zBase = 100;

  double anchorHeadX = 0, anchorHeadY = 0;

  double currentScale = 1.2,
      depthZoomSens = 0.1,
      shiftSens = 0.025,
      tiltSens = 0.0,
      tiltSensitivity = 1.0;

  double sensitivity = 1.0;

  double deadZoneX = 0.0,
      deadZoneY = 0.0,
      deadZoneZ = 0.0,
      deadZoneYaw = 0.0,
      deadZonePitch = 0.0;

  bool isEditMode = false, isLoaded = false;

  bool showLayerPanel = true, showPropPanel = true;

  bool isClearMode = false;

  Offset layerPanelPos = const Offset(20, 100);

  Offset propPanelPos = Offset.zero;

  Offset controlPanelPos = Offset.zero;

  int selectedLayerIndex = 0, imagesLoadedCount = 0;

  List<LayerConfig> layerConfigs = [];

  List<String> undoStack = [], redoStack = [];

  String? currentPresetName;

  Map<String, String> presets = {}; // name -> json string

  TextEditingController urlController = TextEditingController();

  TextEditingController presetNameController = TextEditingController();

  final String MANUAL_SAVE_JSON =
      '{"background.jpg":{"x":0,"y":0,"scale":0.4,"order":0,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/background.jpg","name":"background.jpg"},"sun_rays-min.png":{"x":269,"y":33,"scale":0.88,"order":15,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":false,"canZoom":false,"canTilt":false,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/sun_rays-min.png","name":"sun_rays-min.png"},"mountain_10-min.png":{"x":189,"y":124,"scale":0.64,"order":1,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_10-min.png","name":"mountain_10-min.png"},"mountain_9-min.png":{"x":-251,"y":283,"scale":0.76,"order":4,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_9-min.png","name":"mountain_9-min.png"},"mountain_8-min.png":{"x":-38,"y":204,"scale":0.52,"order":3,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_8-min.png","name":"mountain_8-min.png"},"mountain_7-min.png":{"x":928,"y":212,"scale":0.52,"order":5,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_7-min.png","name":"mountain_7-min.png"},"mountain_6-min.png":{"x":-867,"y":209,"scale":0.52,"order":9,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_6-min.png","name":"mountain_6-min.png"},"mountain_5-min.png":{"x":22,"y":238,"scale":0.64,"order":7,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_5-min.png","name":"mountain_5-min.png"},"mountain_4-min.png":{"x":414,"y":277,"scale":0.52,"order":8,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_4-min.png","name":"mountain_4-min.png"},"mountain_3-min.png":{"x":1330,"y":136,"scale":0.4,"order":18,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_3-min.png","name":"mountain_3-min.png"},"mountain_2-min.png":{"x":-519,"y":430,"scale":0.5270642201834863,"order":16,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_2-min.png","name":"mountain_2-min.png"},"mountain_1-min.png":{"x":-1404,"y":65,"scale":0.4,"order":20,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_1-min.png","name":"mountain_1-min.png"},"fog_7-min.png":{"x":0,"y":0,"scale":1,"order":10,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_7-min.png","name":"fog_7-min.png"},"fog_6-min.png":{"x":0,"y":0,"scale":1,"order":2,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_6-min.png","name":"fog_6-min.png"},"fog_5-min.png":{"x":556,"y":195,"scale":1,"order":11,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_5-min.png","name":"fog_5-min.png"},"fog_4-min.png":{"x":0,"y":0,"scale":1,"order":6,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_4-min.png","name":"fog_4-min.png"},"fog_3-min.png":{"x":-18,"y":88,"scale":1,"order":13,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_3-min.png","name":"fog_3-min.png"},"fog_2-min.png":{"x":0,"y":0,"scale":1,"order":19,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_2-min.png","name":"fog_2-min.png"},"fog_1-min.png":{"x":0,"y":0,"scale":1,"order":17,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_1-min.png","name":"fog_1-min.png"},"black_shadow-min.png":{"x":0,"y":0,"scale":1,"order":21,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":false,"canZoom":false,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/black_shadow-min.png","name":"black_shadow-min.png"},"Text_1766263666111_copy":{"x":400,"y":176,"scale":1.12,"order":12,"isVisible":true,"isLocked":false,"isText":true,"textValue":"Shanghai","fontSize":148.348623853211,"fontWeightIndex":3,"isItalic":false,"shadowBlur":50,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Pacifico","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":false,"canZoom":true,"canTilt":false,"shiftSensMult":1,"zoomSensMult":1,"url":null,"name":"Text_1766263666111_copy"}}';

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    _loadPrefs();

    _initLayers();

    _loadControlSettings();

    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();

    final String? presetsJson = prefs.getString('layer_presets');

    if (presetsJson != null) {
      Map<String, dynamic> map = jsonDecode(presetsJson);

      setState(() {
        presets = map.map((key, value) => MapEntry(key, value.toString()));
      });
    }
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('layer_presets', jsonEncode(presets));
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    selectedAspect = prefs.getString('parallax_aspect_v1');

    setState(() {});
  }

  Future<void> _loadControlSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final String? data = prefs.getString('parallax_control_v1');

    if (data != null) {
      Map<String, dynamic> map = jsonDecode(data);

      setState(() {
        currentScale = map['scale'] ?? 1.2;

        depthZoomSens = (map['depth'] ?? 0.1).clamp(0.0, 1.0);

        shiftSens = (map['shift'] ?? 0.025).clamp(0.0, 1.0);

        tiltSens = (map['tilt'] ?? 0.0).clamp(0.0, 1.0);

        tiltSensitivity = (map['tiltSensitivity'] ?? 1.0).clamp(0.0, 1.0);

        deadZoneX = (map['deadZoneX'] ?? 0.0).clamp(0.001, 0.1);

        deadZoneY = (map['deadZoneY'] ?? 0.0).clamp(0.001, 0.1);

        deadZoneZ = (map['deadZoneZ'] ?? 0.0).clamp(0.0, 10.0);

        deadZoneYaw = (map['deadZoneYaw'] ?? 0.0).clamp(0.0, 10.0);

        deadZonePitch = (map['deadZonePitch'] ?? 0.0).clamp(0.0, 10.0);
      });
    }
  }

  Future<void> _saveControlSettings() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> map = {
      'scale': currentScale,
      'depth': depthZoomSens,
      'shift': shiftSens,
      'tilt': tiltSens,
      'tiltSensitivity': tiltSensitivity,
      'deadZoneX': deadZoneX,
      'deadZoneY': deadZoneY,
      'deadZoneZ': deadZoneZ,
      'deadZoneYaw': deadZoneYaw,
      'deadZonePitch': deadZonePitch,
    };

    await prefs.setString('parallax_control_v1', jsonEncode(map));
  }

  void _debounceSave() {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveControlSettings();
    });
  }

  void _saveToHistory() {
    String current = jsonEncode(layerConfigs.map((e) => e.toMap()).toList());

    if (undoStack.isNotEmpty && undoStack.last == current) return;

    undoStack.add(current);

    if (undoStack.length > 50) undoStack.removeAt(0);

    redoStack.clear();
  }

  void _undo() {
    if (undoStack.isEmpty) return;

    redoStack.add(jsonEncode(layerConfigs.map((e) => e.toMap()).toList()));

    final state = jsonDecode(undoStack.removeLast()) as List;

    setState(() {
      layerConfigs = state
          .map((m) => LayerConfig.fromMap(m, m['url'], m['name'], m['order']))
          .toList();
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;

    undoStack.add(jsonEncode(layerConfigs.map((e) => e.toMap()).toList()));

    final state = jsonDecode(redoStack.removeLast()) as List;

    setState(() {
      layerConfigs = state
          .map((m) => LayerConfig.fromMap(m, m['url'], m['name'], m['order']))
          .toList();
    });
  }

  Future<void> _initLayers() async {
    final prefs = await SharedPreferences.getInstance();

    final String? localData = prefs.getString('parallax_layer_settings_v5');

    // Use local storage if exists, otherwise fallback to MANUAL_SAVE_JSON

    Map<String, dynamic> savedMap = localData != null
        ? jsonDecode(localData)
        : jsonDecode(MANUAL_SAVE_JSON);

    List<LayerConfig> loaded = [];

    final List<String> rawLayers = [
      "background.jpg",
      "sun_rays-min.png",
      "mountain_10-min.png",
      "mountain_9-min.png",
      "mountain_8-min.png",
      "mountain_7-min.png",
      "mountain_6-min.png",
      "mountain_5-min.png",
      "mountain_4-min.png",
      "mountain_3-min.png",
      "mountain_2-min.png",
      "mountain_1-min.png",
      "fog_7-min.png",
      "fog_6-min.png",
      "fog_5-min.png",
      "fog_4-min.png",
      "fog_3-min.png",
      "fog_2-min.png",
      "fog_1-min.png",
      "black_shadow-min.png"
    ];

    int defaultOrder = 0;

    for (int i = 0; i < rawLayers.length; i++) {
      String name = rawLayers[i];

      String defaultUrl =
          "https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/$name";

      if (savedMap.containsKey(name)) {
        var cfgMap = savedMap[name];

        loaded.add(LayerConfig.fromMap(
            cfgMap, cfgMap['url'] ?? defaultUrl, name, cfgMap['order'] ?? i));
      } else {
        loaded.add(LayerConfig(order: i, url: defaultUrl, name: name));
      }

      defaultOrder++;
    }

    // Add other layers from JSON (texts, bezels, etc.)

    savedMap.forEach((key, value) {
      if (!rawLayers.contains(key) && !loaded.any((l) => l.name == key)) {
        loaded.add(LayerConfig.fromMap(
            value, value['url'], key, value['order'] ?? defaultOrder));

        defaultOrder++;
      }
    });

    // Add bezel layers if not exist

    if (!loaded.any((l) => l.name == 'top_bezel')) {
      loaded.add(LayerConfig(
        name: 'top_bezel',
        order: loaded.length,
        isRect: true,
        bezelType: 'top',
        isVisible: true,
        canShift: false,
        canZoom: false,
        canTilt: false,
      ));
    }

    if (!loaded.any((l) => l.name == 'bottom_bezel')) {
      loaded.add(LayerConfig(
        name: 'bottom_bezel',
        order: loaded.length,
        isRect: true,
        bezelType: 'bottom',
        isVisible: true,
        canShift: false,
        canZoom: false,
        canTilt: false,
      ));
    }

    if (!loaded.any((l) => l.name == 'turning_point')) {
      loaded.add(LayerConfig(
        name: 'turning_point',
        order: loaded.length,
        isVisible: false,
        isLocked: true,
        canShift: false,
        canZoom: false,
        canTilt: false,
      ));
    } else {
      loaded.firstWhere((l) => l.name == 'turning_point').isLocked = true;

      loaded.firstWhere((l) => l.name == 'turning_point').isVisible = false;
    }

    // Place turning_point in the middle order if not already positioned properly

    if (loaded.any((l) => l.name == 'turning_point')) {
      var turning = loaded.firstWhere((l) => l.name == 'turning_point');

      loaded.remove(turning);

      loaded.sort((a, b) => a.order.compareTo(b.order));

      int middle = loaded.length ~/ 2;

      loaded.insert(middle, turning);

      for (int i = 0; i < loaded.length; i++) {
        loaded[i].order = i;
      }
    }

    int totalImages = 0;

    for (var config in loaded) {
      if (config.url != null) {
        totalImages++;

        precacheImage(NetworkImage(config.url!), context).then((_) {
          if (mounted) {
            setState(() {
              imagesLoadedCount++;

              if (imagesLoadedCount >= totalImages) isLoaded = true;
            });
          }
        }).catchError((e) {
          if (mounted) {
            setState(() {
              imagesLoadedCount++;

              if (imagesLoadedCount >= totalImages) isLoaded = true;
            });
          }
        });
      }
    }

    if (totalImages == 0) {
      isLoaded = true;
    }

    setState(() => layerConfigs = loaded);
  }

  Future<void> _saveAllConfigs() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> data = {for (var c in layerConfigs) c.name: c.toMap()};

    String jsonStr = jsonEncode(data);

    await prefs.setString('parallax_layer_settings_v5', jsonStr);

    await prefs.setString('parallax_aspect_v1', selectedAspect ?? '');
  }

  Future<void> _savePreset(String name) async {
    if (name.isEmpty) return;

    Map<String, dynamic> data = {for (var c in layerConfigs) c.name: c.toMap()};

    String jsonStr = jsonEncode(data);

    setState(() {
      presets[name] = jsonStr;

      currentPresetName = name;
    });

    await _savePresets();
  }

  Future<void> _loadPreset(String name) async {
    if (!presets.containsKey(name)) return;

    String jsonStr = presets[name]!;

    Map<String, dynamic> savedMap = jsonDecode(jsonStr);

    List<LayerConfig> loaded = [];

    int defaultOrder = 0;

    savedMap.forEach((key, value) {
      loaded.add(LayerConfig.fromMap(value, value['url'], key, defaultOrder++));
    });

    // Ensure bezels and turning point are present

    if (!loaded.any((l) => l.name == 'top_bezel')) {
      loaded.add(LayerConfig(
        name: 'top_bezel',
        order: loaded.length,
        isRect: true,
        bezelType: 'top',
        isVisible: true,
        canShift: false,
        canZoom: false,
        canTilt: false,
      ));
    }

    if (!loaded.any((l) => l.name == 'bottom_bezel')) {
      loaded.add(LayerConfig(
        name: 'bottom_bezel',
        order: loaded.length,
        isRect: true,
        bezelType: 'bottom',
        isVisible: true,
        canShift: false,
        canZoom: false,
        canTilt: false,
      ));
    }

    if (!loaded.any((l) => l.name == 'turning_point')) {
      loaded.add(LayerConfig(
        name: 'turning_point',
        order: loaded.length,
        isVisible: false,
        isLocked: true,
        canShift: false,
        canZoom: false,
        canTilt: false,
      ));
    }

    // Re-order

    loaded.sort((a, b) => a.order.compareTo(b.order));

    setState(() {
      layerConfigs = loaded;

      selectedLayerIndex = 0;

      showPropPanel = false;

      currentPresetName = name;
    });

    // Precache images

    imagesLoadedCount = 0;

    isLoaded = false;

    int total = 0;

    for (var config in loaded) {
      if (config.url != null) {
        total++;

        precacheImage(NetworkImage(config.url!), context).then((_) {
          setState(() {
            imagesLoadedCount++;

            if (imagesLoadedCount >= total) isLoaded = true;
          });
        }).catchError((e) {
          setState(() {
            imagesLoadedCount++;

            if (imagesLoadedCount >= total) isLoaded = true;
          });
        });
      }
    }

    if (total == 0) isLoaded = true;
  }

  void _clearLayers() {
    setState(() {
      layerConfigs.removeWhere((c) => !c.isRect && c.name != 'turning_point');

      selectedLayerIndex = 0;

      showPropPanel = false;
    });
  }

  Future<void> _addImage() async {
    String url = urlController.text.trim();

    if (url.isEmpty) return;

    String name = url.split('/').last.split('?').first;

    if (name.isEmpty) name = "Image_${DateTime.now().millisecondsSinceEpoch}";

    LayerConfig newLayer = LayerConfig(
      order: layerConfigs.length,
      url: url,
      name: name,
    );

    setState(() {
      layerConfigs.add(newLayer);

      selectedLayerIndex = layerConfigs.length - 1;

      showPropPanel = true;
    });

    urlController.clear();

    // Precache

    precacheImage(NetworkImage(url), context).then((_) {
      setState(() => isLoaded = true);
    }).catchError((e) {});
  }

  double _smooth(double current, double target, {double sensitivity = 1.0}) {
    if (isEditMode) return current;

    double alpha =
        ((target - current).abs() * 4.0 * sensitivity).clamp(0.05, 0.9);

    return (current * (1 - alpha)) + (target * alpha);
  }

  Color _fromHex(String hex) {
    hex = hex.replaceAll('#', '');

    if (hex.length == 6) hex = 'FF' + hex;

    return Color(int.parse(hex, radix: 16));
  }

  double get _aspectRatio {
    if (selectedAspect == null) return 0.0;

    String ratioStr = selectedAspect!.split(' (')[0];

    List<String> parts = ratioStr.split(':');

    return double.parse(parts[0]) / double.parse(parts[1]);
  }

  double get _barHeight {
    if (selectedAspect == null) return 0.0;

    double dw = MediaQuery.of(context).size.width;

    double dh = MediaQuery.of(context).size.height;

    double contentH = dw / _aspectRatio;

    if (contentH < dh) {
      return (dh - contentH) / 2;
    }

    return 0.0;
  }

  bool get _bezelActive {
    return layerConfigs
        .where((c) =>
            c.isRect && (c.name == 'top_bezel' || c.name == 'bottom_bezel'))
        .every((c) => c.isVisible);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded)
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent)));

    if (propPanelPos == Offset.zero)
      propPanelPos = Offset(MediaQuery.of(context).size.width - 320,
          MediaQuery.of(context).size.height / 2 - 300);

    if (controlPanelPos == Offset.zero)
      controlPanelPos = Offset(MediaQuery.of(context).size.width - 320, 100);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildLayersStack(),
          if (!isClearMode)
            Positioned(left: 20, bottom: 20, child: const SizedBox()),
          if (!isClearMode)
            Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(child: _buildBottomCenterToggle())),
          if (isEditMode && !isClearMode)
            Positioned(
                right: 20, bottom: 20, child: _buildBottomRightControls()),
          if (isEditMode && !isClearMode) ...[
            if (showLayerPanel) _buildDraggableLayerManager(),
            _buildEditHeader(),
            if (showPropPanel && layerConfigs.isNotEmpty)
              _buildDraggablePropertiesPanel(),
            _buildPanelToggles(),
            Positioned(top: 60, left: 20, child: _aspectDropdown()),
          ] else if (!isClearMode) ...[
            _buildDraggableControlPanel(),
          ],
          Positioned(right: 20, bottom: 20, child: _buildClearToggle()),
        ],
      ),
    );
  }

  Widget _aspectDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.cyanAccent)),
      child: DropdownButton<String>(
        value: selectedAspect,
        hint: const Text('Select Aspect Ratio',
            style: TextStyle(color: Colors.white, fontSize: 10)),
        dropdownColor: Colors.grey[900],
        underline: Container(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
        items: [null, ...aspectRatios]
            .map((f) => DropdownMenuItem(value: f, child: Text(f ?? 'None')))
            .toList(),
        onChanged: (v) => setState(() => selectedAspect = v),
      ),
    );
  }

  Widget _buildLayersStack() {
    List<LayerConfig> sorted = List.from(layerConfigs)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: sorted
            .where((c) => c.isVisible)
            .map((config) => _buildInteractiveLayer(config))
            .toList());
  }

  Widget _buildInteractiveLayer(LayerConfig config) {
    if (config.name == 'turning_point') return const SizedBox.shrink();

    int idx = layerConfigs.indexOf(config);

    bool isSelected = selectedLayerIndex == idx && isEditMode;

    if (config.isRect) {
      if (!config.isVisible) return const SizedBox.shrink();

      double barHeight = _barHeight;

      return Positioned(
        top: config.bezelType == 'top' ? 0 : null,
        bottom: config.bezelType == 'bottom' ? 0 : null,
        left: 0,
        right: 0,
        child: Container(
          height: barHeight,
          color: Colors.black,
        ),
      );
    }

    LayerConfig? turningPoint =
        layerConfigs.firstWhereOrNull((c) => c.name == 'turning_point');

    double bezelOrder = turningPoint != null
        ? turningPoint.order.toDouble()
        : layerConfigs
                .map((c) => c.order.toDouble())
                .fold(-double.infinity, math.max) +
            1;

    double depthFactor = config.order.toDouble() - bezelOrder;

    double shiftSign = depthFactor.sign;

    double zoomDirSign = depthFactor.sign;

    double effectiveDepth = depthFactor.abs();

    double devX = headX - anchorHeadX;

    double devY = headY - anchorHeadY;

    double tiltXcalc = yaw / 60.0;

    double tiltYcalc = pitch / 40.0;

    double shiftX = isEditMode
        ? config.x
        : (config.canShift
            ? ((-devX *
                        shiftSens *
                        effectiveDepth *
                        80.0 *
                        config.shiftSensMult *
                        sensitivity *
                        shiftSign) +
                    config.x)
                .clamp(config.minX, config.maxX)
            : config.x);

    double shiftY = isEditMode
        ? config.y
        : (config.canShift
            ? ((-devY *
                        shiftSens *
                        effectiveDepth *
                        80.0 *
                        config.shiftSensMult *
                        sensitivity *
                        shiftSign) +
                    config.y)
                .clamp(config.minY, config.maxY)
            : config.y);

    double deltaZ = (zValue / zBase) - 1.0;

    double zoomFactor = deltaZ *
        depthZoomSens *
        4.0 *
        (effectiveDepth + 0.5) *
        config.zoomSensMult *
        sensitivity;

    double scale = isEditMode
        ? config.scale
        : (config.canZoom
            ? (config.scale * currentScale * (1.0 + (zoomFactor * zoomDirSign)))
                .clamp(config.minScale, config.maxScale)
            : config.scale);

    Matrix4 tiltTransform = Matrix4.identity();

    if (!isEditMode && config.canTilt) {
      tiltTransform.setEntry(3, 2, 0.001);

      tiltTransform.rotateX(-tiltYcalc *
          tiltSens *
          sensitivity *
          effectiveDepth *
          tiltSensitivity);

      tiltTransform.rotateY(tiltXcalc *
          tiltSens *
          sensitivity *
          effectiveDepth *
          tiltSensitivity);
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: isEditMode ? !isSelected : true,
        child: Listener(
          onPointerSignal: (event) {
            if (isSelected && !config.isLocked && event is PointerScrollEvent) {
              _saveToHistory();

              setState(() => config.scale =
                  (config.scale - event.scrollDelta.dy / 1000)
                      .clamp(0.1, 10.0));
            }
          },
          child: GestureDetector(
            onPanUpdate: (details) {
              if (isSelected && !config.isLocked) {
                _saveToHistory();

                setState(() {
                  config.x += details.delta.dx;

                  config.y += details.delta.dy;
                });
              }
            },
            child: Transform(
              alignment: Alignment.center,
              transform: tiltTransform,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(shiftX, shiftY),
                  child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Container(
                          decoration: isSelected
                              ? BoxDecoration(
                                  border: Border.all(
                                      color: Colors.cyanAccent, width: 3))
                              : null,
                          child: config.isText
                              ? Stack(
                                  children: [
                                    if (config.strokeWidth > 0)
                                      Text(config.textValue!,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.getFont(
                                              config.fontFamily,
                                              fontSize: config.fontSize,
                                              fontStyle: config.isItalic
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                              fontWeight: FontWeight.values[
                                                  config.fontWeightIndex + 1],
                                              foreground: Paint()
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth =
                                                    config.strokeWidth
                                                ..color = _fromHex(
                                                    config.strokeColorHex))),
                                    Text(config.textValue!,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.getFont(
                                            config.fontFamily,
                                            color:
                                                _fromHex(config.textColorHex),
                                            fontSize: config.fontSize,
                                            fontStyle: config.isItalic
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            fontWeight: FontWeight.values[
                                                config.fontWeightIndex + 1],
                                            shadows: config.shadowBlur > 0
                                                ? [
                                                    Shadow(
                                                        color: _fromHex(config
                                                            .shadowColorHex),
                                                        blurRadius:
                                                            config.shadowBlur,
                                                        offset:
                                                            const Offset(2, 2))
                                                  ]
                                                : null)),
                                  ],
                                )
                              : Image.network(config.url!,
                                  fit: BoxFit.none,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true))),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableLayerManager() {
    return Positioned(
      left: layerPanelPos.dx,
      top: layerPanelPos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => layerPanelPos += d.delta),
        child: Container(
          width: 320,
          height: 600,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent, width: 0.5)),
          child: Column(children: [
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text("LAYER MANAGER (DRAG ME)",
                    style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2))),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: "Image URL",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addImage,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent),
                  child:
                      Text("Add Image", style: TextStyle(color: Colors.black)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: presetNameController,
                    decoration: InputDecoration(
                      hintText: "Preset Name",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    String name = presetNameController.text.trim();

                    if (name.isNotEmpty) {
                      _savePreset(name);

                      presetNameController.clear();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent),
                  child: Text("Save Preset",
                      style: TextStyle(color: Colors.black)),
                ),
              ]),
            ),
            if (presets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: currentPresetName,
                      hint: Text("Load Preset",
                          style: TextStyle(color: Colors.white)),
                      dropdownColor: Colors.grey[900],
                      style: TextStyle(color: Colors.white),
                      items: presets.keys
                          .map((name) =>
                              DropdownMenuItem(value: name, child: Text(name)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _loadPreset(v);
                      },
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _clearLayers,
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: Text("Clear Layers (Keep Bezels)",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            Expanded(
                child: ReorderableListView(
                    padding: EdgeInsets.zero,
                    onReorder: (oldIdx, newIdx) {
                      _saveToHistory();

                      setState(() {
                        List<LayerConfig> displayList = List.from(layerConfigs)
                          ..sort((a, b) => b.order.compareTo(a.order));

                        if (newIdx > oldIdx) newIdx -= 1;

                        final item = displayList.removeAt(oldIdx);

                        displayList.insert(newIdx, item);

                        for (int i = 0; i < displayList.length; i++)
                          displayList[i].order = displayList.length - 1 - i;
                      });
                    },
                    children: (List.from(layerConfigs)
                          ..sort((a, b) => b.order.compareTo(a.order)))
                        .map((c) => _layerTile(c))
                        .toList())),
          ]),
        ),
      ),
    );
  }

  Widget _layerTile(LayerConfig c) {
    int realIdx = layerConfigs.indexOf(c);

    bool isSel = selectedLayerIndex == realIdx;

    bool isTurningPoint = c.name == 'turning_point';

    return ListTile(
      key: ValueKey(c.name),
      dense: true,
      selected: isSel,
      selectedTileColor: Colors.cyanAccent.withOpacity(0.1),
      leading: Icon(
          c.isText
              ? Icons.text_fields
              : (c.isRect ? Icons.rectangle : Icons.drag_handle),
          color: isSel ? Colors.cyanAccent : Colors.white24,
          size: 14),
      title: Text(c.isText ? c.textValue! : c.name,
          style: TextStyle(
              color: isSel ? Colors.cyanAccent : Colors.white70, fontSize: 9),
          overflow: TextOverflow.ellipsis),
      trailing: isTurningPoint
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              _iconBtn(Icons.copy, () {
                _saveToHistory();

                setState(() {
                  var nc = c.copy();

                  nc.order = layerConfigs.length;

                  layerConfigs.add(nc);

                  selectedLayerIndex = layerConfigs.length - 1;

                  showPropPanel = true;
                });
              }),
              const SizedBox(width: 2),
              _iconBtn(c.isLocked ? Icons.lock : Icons.lock_open,
                  () => setState(() => c.isLocked = !c.isLocked),
                  col: c.isLocked ? Colors.redAccent : Colors.white38),
              const SizedBox(width: 2),
              _iconBtn(c.isVisible ? Icons.visibility : Icons.visibility_off,
                  () => setState(() => c.isVisible = !c.isVisible),
                  col: c.isVisible ? Colors.cyanAccent : Colors.white38),
              const SizedBox(width: 10),
              _iconBtn(Icons.delete, () {
                _saveToHistory();

                setState(() {
                  layerConfigs.remove(c);

                  selectedLayerIndex = 0;
                });
              }, col: Colors.redAccent),
            ]),
      onTap: () => setState(() {
        selectedLayerIndex = realIdx;

        if (isTurningPoint) {
          showPropPanel = false;
        } else if (selectedLayerIndex == realIdx && showPropPanel) {
          showPropPanel = false;
        } else {
          showPropPanel = true;
        }
      }),
    );
  }

  Widget _iconBtn(IconData i, VoidCallback fn, {Color? col}) => SizedBox(
      width: 24,
      child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(i, size: 14, color: col ?? Colors.white38),
          onPressed: fn));

  Widget _buildDraggablePropertiesPanel() {
    if (layerConfigs.isEmpty) return Container();

    LayerConfig config = layerConfigs[selectedLayerIndex];

    if (config.name == 'turning_point') return const SizedBox.shrink();

    return Positioned(
      left: propPanelPos.dx,
      top: propPanelPos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => propPanelPos += d.delta),
        child: Container(
          width: 300,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent, width: 1)),
          child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("PROPERTIES: ${config.name.toUpperCase()}",
                          style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                      IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                          onPressed: () =>
                              setState(() => showPropPanel = false)),
                    ]),
                const Divider(color: Colors.white24, height: 20),
                if (config.isText) ...[
                  const Text("TEXT CONTENT",
                      style: TextStyle(color: Colors.white60, fontSize: 10)),
                  TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                          filled: true, fillColor: Colors.white10),
                      onChanged: (v) {
                        _saveToHistory();

                        setState(() => config.textValue = v);
                      },
                      controller: TextEditingController(text: config.textValue)
                        ..selection = TextSelection.collapsed(
                            offset: config.textValue!.length)),
                  const SizedBox(height: 10),
                  _fontDropdown(config),
                  _enhancedSlider("Font Size", config.fontSize, 10, 300, 1.0,
                      (v) => setState(() => config.fontSize = v)),
                  _enhancedSlider(
                      "Font Weight",
                      config.fontWeightIndex.toDouble(),
                      0,
                      8,
                      1.0,
                      (v) =>
                          setState(() => config.fontWeightIndex = v.toInt())),
                  _colorRow("Text Color", config.textColorHex,
                      (c) => setState(() => config.textColorHex = c)),
                  const Divider(color: Colors.white10),
                  _enhancedSlider("Shadow Blur", config.shadowBlur, 0, 50, 1.0,
                      (v) => setState(() => config.shadowBlur = v)),
                  _colorRow("Shadow Color", config.shadowColorHex,
                      (c) => setState(() => config.shadowColorHex = c)),
                  const Divider(color: Colors.white10),
                  _enhancedSlider("Stroke Width", config.strokeWidth, 0, 20,
                      0.1, (v) => setState(() => config.strokeWidth = v)),
                  _colorRow("Stroke Color", config.strokeColorHex,
                      (c) => setState(() => config.strokeColorHex = c)),
                  _toggleRow("Italic", config.isItalic,
                      (v) => setState(() => config.isItalic = v)),
                ],
                const Divider(color: Colors.white24),
                _enhancedSlider("Pos X", config.x, -2000, 2000, 1.0,
                    (v) => setState(() => config.x = v)),
                _enhancedSlider("Pos Y", config.y, -2000, 2000, 1.0,
                    (v) => setState(() => config.y = v)),
                _enhancedSlider("Base Scale", config.scale, 0.1, 5.0, 0.1,
                    (v) => setState(() => config.scale = v)),
                _toggleRow("Shift", config.canShift,
                    (v) => setState(() => config.canShift = v)),
                _toggleRow("Zoom", config.canZoom,
                    (v) => setState(() => config.canZoom = v)),
                _toggleRow("Tilt", config.canTilt,
                    (v) => setState(() => config.canTilt = v)),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: () => _saveAllConfigs(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        minimumSize: const Size(double.infinity, 36)),
                    child: const Text("SAVE CONFIG",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10))),
              ])),
        ),
      ),
    );
  }

  Widget _colorRow(String label, String hex, ValueChanged<String> onHexChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
        const Spacer(),
        Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
                color: _fromHex(hex),
                border: Border.all(color: Colors.white24),
                shape: BoxShape.circle)),
        const SizedBox(width: 8),
        SizedBox(
            width: 80,
            height: 25,
            child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 10),
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 5),
                    filled: true,
                    fillColor: Colors.white10),
                onChanged: (v) {
                  _saveToHistory();

                  onHexChange(v);
                },
                controller: TextEditingController(text: hex))),
      ]),
    );
  }

  Widget _fontDropdown(LayerConfig config) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(4)),
      child: DropdownButton<String>(
          value: config.fontFamily,
          isExpanded: true,
          dropdownColor: Colors.grey[900],
          underline: Container(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: availableFonts
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) {
            _saveToHistory();

            setState(() => config.fontFamily = v!);
          }));

  Widget _buildDraggableControlPanel() => Positioned(
        left: controlPanelPos.dx,
        top: controlPanelPos.dy,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() => controlPanelPos += d.delta),
          child: Container(
            width: 300,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12)),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("SCENE CONTROLS",
                    style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white10),
                _enhancedSlider("Global Scale", currentScale, 0.5, 2.5, 0.1,
                    (v) {
                  setState(() => currentScale = v);

                  _debounceSave();
                }),
                _enhancedSlider("Global Depth", depthZoomSens, 0.0, 1.0, 0.001,
                    (v) {
                  setState(() => depthZoomSens = v);

                  _debounceSave();
                }),
                _enhancedSlider("Global Shift", shiftSens, 0.0, 1.0, 0.001,
                    (v) {
                  setState(() => shiftSens = v);

                  _debounceSave();
                }),
                _enhancedSlider("Global Tilt", tiltSens, 0.0, 1.0, 0.001, (v) {
                  setState(() => tiltSens = v);

                  _debounceSave();
                }),
                _enhancedSlider(
                    "Tilt Sensitivity", tiltSensitivity, 0.0, 1.0, 0.001, (v) {
                  setState(() => tiltSensitivity = v);

                  _debounceSave();
                }),
                _enhancedSlider("Dead Zone X", deadZoneX, 0.001, 0.1, 0.001,
                    (v) {
                  setState(() => deadZoneX = v);

                  _debounceSave();
                }),
                _enhancedSlider("Dead Zone Y", deadZoneY, 0.001, 0.1, 0.001,
                    (v) {
                  setState(() => deadZoneY = v);

                  _debounceSave();
                }),
                _enhancedSlider("Dead Zone Z", deadZoneZ, 0.0, 10.0, 0.1, (v) {
                  setState(() => deadZoneZ = v);

                  _debounceSave();
                }),
                _enhancedSlider("Dead Zone Yaw", deadZoneYaw, 0.0, 10.0, 0.1,
                    (v) {
                  setState(() => deadZoneYaw = v);

                  _debounceSave();
                }),
                _enhancedSlider(
                    "Dead Zone Pitch", deadZonePitch, 0.0, 10.0, 0.1, (v) {
                  setState(() => deadZonePitch = v);

                  _debounceSave();
                }),
                const Divider(color: Colors.white10),
                _enhancedSlider("Head X", headX, -1.0, 1.0, 0.001, (v) {
                  double delta = v - headX;

                  double absD = delta.abs();

                  if (absD > deadZoneX) {
                    setState(() => headX =
                        headX + (absD - deadZoneX) * (delta > 0 ? 1 : -1));
                  }
                }),
                _enhancedSlider("Head Y", headY, -1.0, 1.0, 0.001, (v) {
                  double delta = v - headY;

                  double absD = delta.abs();

                  if (absD > deadZoneY) {
                    setState(() => headY =
                        headY + (absD - deadZoneY) * (delta > 0 ? 1 : -1));
                  }
                }),
                _enhancedSlider("Z Value", zValue, 50.0, 150.0, 0.1, (v) {
                  double delta = v - zValue;

                  double absD = delta.abs();

                  if (absD > deadZoneZ) {
                    setState(() => zValue =
                        zValue + (absD - deadZoneZ) * (delta > 0 ? 1 : -1));
                  }
                }),
                _enhancedSlider("Yaw", yaw, -60.0, 60.0, 0.1, (v) {
                  double delta = v - yaw;

                  double absD = delta.abs();

                  if (absD > deadZoneYaw) {
                    setState(() => yaw =
                        yaw + (absD - deadZoneYaw) * (delta > 0 ? 1 : -1));
                  }
                }),
                _enhancedSlider("Pitch", pitch, -40.0, 40.0, 0.1, (v) {
                  double delta = v - pitch;

                  double absD = delta.abs();

                  if (absD > deadZonePitch) {
                    setState(() => pitch =
                        pitch + (absD - deadZonePitch) * (delta > 0 ? 1 : -1));
                  }
                }),
              ]),
            ),
          ),
        ),
      );

  Widget _buildBottomRightControls() => Row(children: [
        _roundBtn(Icons.undo, _undo, undoStack.isNotEmpty),
        const SizedBox(width: 10),
        _roundBtn(Icons.redo, _redo, redoStack.isNotEmpty),
      ]);

  Widget _roundBtn(IconData i, VoidCallback fn, bool act) => Container(
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black87,
          border: Border.all(color: act ? Colors.cyanAccent : Colors.white10)),
      child: IconButton(
          icon: Icon(i,
              size: 18, color: act ? Colors.cyanAccent : Colors.white24),
          onPressed: act ? fn : null));

  Widget _buildPanelToggles() => Positioned(
      top: 20,
      left: 20,
      child: Row(children: [
        _toggleBtn("LAYERS", showLayerPanel,
            () => setState(() => showLayerPanel = !showLayerPanel)),
        const SizedBox(width: 10),
        _toggleBtn("PROPS", showPropPanel,
            () => setState(() => showPropPanel = !showPropPanel)),
      ]));

  Widget _toggleBtn(String t, bool s, VoidCallback fn) => GestureDetector(
      onTap: fn,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: s ? Colors.cyanAccent : Colors.black87,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.cyanAccent)),
          child: Text(t,
              style: TextStyle(
                  color: s ? Colors.black : Colors.cyanAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold))));

  Widget _buildBottomCenterToggle() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: isEditMode ? Colors.cyanAccent : Colors.white24,
                      width: 1.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.edit, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                const Text("EDIT MODE",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Checkbox(
                    value: isEditMode,
                    activeColor: Colors.cyanAccent,
                    onChanged: (v) {
                      setState(() {
                        isEditMode = v!;

                        if (!isEditMode) {
                          _exitEditMode();
                        } else {
                          _enterEditMode();
                        }
                      });
                    })
              ])),
        ],
      );

  void _enterEditMode() {
    // Placeholder for entering edit mode
  }

  void _exitEditMode() {
    _saveAllConfigs();

    _saveControlSettings();
  }

  Widget _buildEditHeader() => Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text("EDITOR ACTIVE",
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 10)))));

  Widget _enhancedSlider(String l, double v, double min, double max,
          double step, ValueChanged<double> cb) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(l, style: const TextStyle(color: Colors.white, fontSize: 9)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: TextEditingController(text: v.toStringAsFixed(3))
                    ..selection = TextSelection.collapsed(
                        offset: v.toStringAsFixed(3).length),
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 8),
                  onSubmitted: (s) {
                    double newV = double.tryParse(s) ?? v;

                    cb(newV.clamp(min, max));
                  },
                ),
              ),
            ]),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () => cb((v - step).clamp(min, max)),
                ),
                Expanded(
                  child: SliderTheme(
                      data: const SliderThemeData(
                          trackHeight: 2,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 6)),
                      child: Slider(
                          value: v.clamp(min, max),
                          min: min,
                          max: max,
                          activeColor: Colors.cyanAccent,
                          divisions: ((max - min) / step).toInt(),
                          onChanged: (val) {
                            _saveToHistory();

                            cb(val);

                            _debounceSaveConfigs();
                          })),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => cb((v + step).clamp(min, max)),
                ),
              ],
            )
          ]));

  Widget _toggleRow(String l, bool v, ValueChanged<bool> cb) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: Colors.white, fontSize: 10)),
        Switch(
            value: v,
            activeColor: Colors.cyanAccent,
            onChanged: (val) {
              _saveToHistory();

              cb(val);

              _debounceSaveConfigs();
            })
      ]);

  Widget _buildClearToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text("CLEAR",
            style: TextStyle(color: Colors.white, fontSize: 10)),
        Switch(
            value: isClearMode,
            activeColor: Colors.cyanAccent,
            onChanged: (v) {
              setState(() {
                isClearMode = v;
              });
            })
      ]),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();

    urlController.dispose();

    presetNameController.dispose();

    super.dispose();
  }

  void _debounceSaveConfigs() {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveControlSettings();
    });
  }
}
