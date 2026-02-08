// ignore_for_file: prefer_const_constructors, curly_braces_in_flow_control_structures

import 'package:collection/collection.dart';
import 'dart:js_interop_unsafe';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

@JS('eval')
external JSAny? jsEval(String code);

extension JSAnyExt on JSAny? {
  double? toDouble() => (this as JSNumber?)?.toDartDouble;
  String? toStringDart() => (this as JSString?)?.toDart;
  List<double> toDoubleList() =>
      (this as JSArray<JSNumber>?)
          ?.toDart
          .map((e) => e.toDartDouble)
          .toList() ??
      [];
  JSAny? getProp(String key) => (this as JSObject?)?.getProperty(key.toJS);
}

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

class D3Config {
  String url;
  double initTheta, initPhi;
  double centerX, centerY, centerZ;
  double sensX, sensY, sensZ;
  bool playAnimation;
  double scale;
  D3Config({
    this.url =
        "https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/3d%20models/spaceship_corridor.glb",
    this.initTheta = 0.0,
    this.initPhi = 85.0,
    this.centerX = 0.0,
    this.centerY = 0.0,
    this.centerZ = 0.0,
    this.sensX = 30.0,
    this.sensY = 30.0,
    this.sensZ = 0.05,
    this.playAnimation = true,
    this.scale = 1.0,
  });
  Map<String, dynamic> toMap() => {
        'url': url,
        'initTheta': initTheta,
        'initPhi': initPhi,
        'centerX': centerX,
        'centerY': centerY,
        'centerZ': centerZ,
        'sensX': sensX,
        'sensY': sensY,
        'sensZ': sensZ,
        'playAnimation': playAnimation,
        'scale': scale,
      };
  factory D3Config.fromMap(Map<String, dynamic> map) => D3Config(
        url: map['url'] ??
            "https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/3d%20models/spaceship_corridor.glb",
        initTheta: (map['initTheta'] as num?)?.toDouble() ?? 0.0,
        initPhi: (map['initPhi'] as num?)?.toDouble() ?? 85.0,
        centerX: (map['centerX'] as num?)?.toDouble() ?? 0.0,
        centerY: (map['centerY'] as num?)?.toDouble() ?? 0.0,
        centerZ: (map['centerZ'] as num?)?.toDouble() ?? 0.0,
        sensX: (map['sensX'] as num?)?.toDouble() ?? 30.0,
        sensY: (map['sensY'] as num?)?.toDouble() ?? 30.0,
        sensZ: (map['sensZ'] as num?)?.toDouble() ?? 0.05,
        playAnimation: map['playAnimation'] ?? true,
        scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      );
}

class ImmersiveCard extends StatefulWidget {
  const ImmersiveCard({super.key, this.width, this.height});
  final double? width, height;
  @override
  State<ImmersiveCard> createState() => _ImmersiveCardState();
}

class _ImmersiveCardState extends State<ImmersiveCard> {
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
  double gazeX = 0,
      gazeY = 0,
      tiltX = 0,
      tiltY = 0,
      headX = 0,
      headY = 0,
      zValue = 0,
      zBase = 100;
  double anchorHeadX = 0, anchorHeadY = 0;
  // Audio State
  bool isPlaying = false;
  double audioCurrentTime = 0.0;
  double audioTotalTime = 0.0;
  double reverbIntensity = 0.6;
  double audioPanSens = 15.0;
  double currentScale = 1.2,
      displayDepth = 0.0,
      depthZoomSens = 0.1,
      shiftSens = 0.025,
      tiltSens = 0.0,
      tiltOffset = 0.0,
      currentOffset = 0.0;
  double sensitivity = 1.0;
  bool isEditMode = false, isLoaded = false, isCalibrated = false;
  bool showLayerPanel = true, showPropPanel = true;
  bool is3DMode = false;
  bool highQualitySet = false;
  bool faceControlsTilt = false;
  bool isUIToggleOn = true;
  Offset layerPanelPos = const Offset(20, 100);
  Offset propPanelPos = Offset.zero;
  Offset controlPanelPos = Offset.zero;
  int selectedLayerIndex = 0, imagesLoadedCount = 0;
  List<LayerConfig> layerConfigs = [];
  List<String> undoStack = [], redoStack = [];
  List<String> undo3DStack = [], redo3DStack = [];
  String zControl = 'center z';
  final String MANUAL_SAVE_JSON =
      '{"background.jpg":{"x":0,"y":0,"scale":0.4,"order":0,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/background.jpg","name":"background.jpg"},"sun_rays-min.png":{"x":269,"y":33,"scale":0.88,"order":15,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":false,"canZoom":false,"canTilt":false,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/sun_rays-min.png","name":"sun_rays-min.png"},"mountain_10-min.png":{"x":189,"y":124,"scale":0.64,"order":1,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_10-min.png","name":"mountain_10-min.png"},"mountain_9-min.png":{"x":-251,"y":283,"scale":0.76,"order":4,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_9-min.png","name":"mountain_9-min.png"},"mountain_8-min.png":{"x":-38,"y":204,"scale":0.52,"order":3,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_8-min.png","name":"mountain_8-min.png"},"mountain_7-min.png":{"x":928,"y":212,"scale":0.52,"order":5,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_7-min.png","name":"mountain_7-min.png"},"mountain_6-min.png":{"x":-867,"y":209,"scale":0.52,"order":9,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_6-min.png","name":"mountain_6-min.png"},"mountain_5-min.png":{"x":22,"y":238,"scale":0.64,"order":7,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_5-min.png","name":"mountain_5-min.png"},"mountain_4-min.png":{"x":414,"y":277,"scale":0.52,"order":8,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_4-min.png","name":"mountain_4-min.png"},"mountain_3-min.png":{"x":1330,"y":136,"scale":0.4,"order":18,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_3-min.png","name":"mountain_3-min.png"},"mountain_2-min.png":{"x":-519,"y":430,"scale":0.5270642201834863,"order":16,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_2-min.png","name":"mountain_2-min.png"},"mountain_1-min.png":{"x":-1404,"y":65,"scale":0.4,"order":20,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/mountain_1-min.png","name":"mountain_1-min.png"},"fog_7-min.png":{"x":0,"y":0,"scale":1,"order":10,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_7-min.png","name":"fog_7-min.png"},"fog_6-min.png":{"x":0,"y":0,"scale":1,"order":2,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_6-min.png","name":"fog_6-min.png"},"fog_5-min.png":{"x":556,"y":195,"scale":1,"order":11,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_5-min.png","name":"fog_5-min.png"},"fog_4-min.png":{"x":0,"y":0,"scale":1,"order":6,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_4-min.png","name":"fog_4-min.png"},"fog_3-min.png":{"x":-18,"y":88,"scale":1,"order":13,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_3-min.png","name":"fog_3-min.png"},"fog_2-min.png":{"x":0,"y":0,"scale":1,"order":19,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_2-min.png","name":"fog_2-min.png"},"fog_1-min.png":{"x":0,"y":0,"scale":1,"order":17,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":true,"canZoom":true,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/fog_1-min.png","name":"fog_1-min.png"},"black_shadow-min.png":{"x":0,"y":0,"scale":1,"order":21,"isVisible":true,"isLocked":false,"isText":false,"textValue":"New> Text","fontSize":40,"fontWeightIndex":4,"isItalic":false,"shadowBlur":0,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Poppins","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":false,"canZoom":false,"canTilt":true,"shiftSensMult":1,"zoomSensMult":1,"url":"https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/compressed/img/black_shadow-min.png","name":"black_shadow-min.png"},"Text_1766263666111_copy":{"x":400,"y":176,"scale":1.12,"order":12,"isVisible":true,"isLocked":false,"isText":true,"textValue":"Shanghai","fontSize":148.348623853211,"fontWeightIndex":3,"isItalic":false,"shadowBlur":50,"shadowColorHex":"#000000","strokeWidth":0,"strokeColorHex":"#000000","textColorHex":"#FFFFFF","fontFamily":"Pacifico","minScale":0.1,"maxScale":5,"minX":-3000,"maxX":3000,"minY":-3000,"maxY":3000,"canShift":false,"canZoom":true,"canTilt":false,"shiftSensMult":1,"zoomSensMult":1,"url":null,"name":"Text_1766263666111_copy"}}';
  Timer? _facePosTimer;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  Timer? _uiPollTimer;
  D3Config d3Config = D3Config();
  int facePosInterval = 5;
  double previousScale = 1.0;
  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initLayers();
    _init3DConfig();
    _loadControlSettings();
    _initTracking();
    _initSpatialAudio();
    // Load model-viewer script dynamically
    jsEval("""
      if (!document.querySelector('script[model-viewer-script]')) {
        var script = document.createElement('script');
        script.setAttribute('model-viewer-script', '');
        script.type = 'module';
        script.src = 'https://unpkg.com/@google/model-viewer/dist/model-viewer.min.js';
        document.head.appendChild(script);
      }
      """);
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 100), _pollModelState);
    _uiPollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final bool? isVisible =
          jsEval("document.getElementById('visibility-toggle')?.checked")
              as bool?;
      if (isVisible != null && isVisible != isUIToggleOn) {
        setState(() => isUIToggleOn = isVisible);
      }
    });
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
        reverbIntensity = map['reverb'] ?? 0.6;
        audioPanSens = map['panSens'] ?? 15.0;
        currentScale = map['scale'] ?? 1.2;
        displayDepth = (map['displayDepth'] ?? 0.0).clamp(0.0, 1.0);
        depthZoomSens = displayDepth * 0.05;
        shiftSens = (map['shift'] ?? 0.025).clamp(0.0, 1.0);
        tiltSens = (map['tilt'] ?? 0.0).clamp(0.0, 1.0);
        tiltOffset = (map['tiltOffset'] ?? 0.0).clamp(0.0, 1.0);
        faceControlsTilt = map['faceTilt'] ?? false;
      });
    }
  }

  Future<void> _saveControlSettings() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> map = {
      'reverb': reverbIntensity,
      'panSens': audioPanSens,
      'scale': currentScale,
      'displayDepth': displayDepth,
      'shift': shiftSens,
      'tilt': tiltSens,
      'tiltOffset': tiltOffset,
      'faceTilt': faceControlsTilt,
    };
    await prefs.setString('parallax_control_v1', jsonEncode(map));
  }

  void _debounceSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveControlSettings();
    });
  }

  void _pollModelState(Timer t) {
    if (!mounted) return;
    if (!is3DMode) return;
    if (isEditMode) {
      JSAny? orbitRes = jsEval("""
        const mv = document.querySelector('#mainModel');
        if (mv) {
          const orbit = mv.getCameraOrbit();
          return [orbit.theta * 180 / Math.PI, orbit.phi * 180 / Math.PI];
        }
        return null;
        """);
      if (orbitRes != null) {
        List<double> orbit = orbitRes.toDoubleList();
        if (orbit[0] != d3Config.initTheta || orbit[1] != d3Config.initPhi) {
          _save3DToHistory();
          setState(() {
            d3Config.initTheta = orbit[0];
            d3Config.initPhi = orbit[1];
          });
        }
      }
      JSAny? targetRes = jsEval("""
        const mv = document.querySelector('#mainModel');
        if (mv) {
          const target = mv.getCameraTarget();
          return [target.x, target.y, target.z];
        }
        return null;
        """);
      if (targetRes != null) {
        List<double> target = targetRes.toDoubleList();
        if (target[0] != d3Config.centerX ||
            target[1] != d3Config.centerY ||
            target[2] != d3Config.centerZ) {
          _save3DToHistory();
          setState(() {
            d3Config.centerX = target[0];
            d3Config.centerY = target[1];
            d3Config.centerZ = target[2];
          });
        }
      }
      JSAny? scaleRes = jsEval("""
        const mv = document.querySelector('#mainModel');
        if (mv) {
          return mv.scale.split(' ')[0];
        }
        return null;
        """);
      if (scaleRes != null) {
        double newScale =
            double.tryParse(scaleRes.toStringDart() ?? '1.0') ?? 1.0;
        if (newScale != d3Config.scale) {
          _save3DToHistory();
          setState(() {
            d3Config.scale = newScale;
          });
        }
      }
    }
    if (!highQualitySet) {
      jsEval("""
        const mv = document.querySelector('model-viewer#mainModel');
        if (mv && mv.threeRenderer && mv.scene) {
          const renderer = mv.threeRenderer;
          renderer.setPixelRatio(window.devicePixelRatio * 2);
          renderer.shadowMap.enabled = true;
          renderer.shadowMap.type = window.THREE.PCFSoftShadowMap;
          renderer.physicallyCorrectLights = true;
          renderer.toneMapping = window.THREE.ACESFilmicToneMapping;
          renderer.outputEncoding = window.THREE.sRGBEncoding;
          renderer.antialias = true;
          const maxAnisotropy = renderer.capabilities.getMaxAnisotropy();
          if (maxAnisotropy > 0) {
            mv.scene.traverse((obj) => {
              if (obj.material) {
                const mat = obj.material;
                ['map', 'normalMap', 'emissiveMap', 'roughnessMap', 'metalnessMap'].forEach((mapType) => {
                  if (mat[mapType]) {
                    mat[mapType].anisotropy = maxAnisotropy;
                    mat[mapType].magFilter = window.THREE.LinearFilter;
                    mat[mapType].minFilter = window.THREE.LinearMipMapLinearFilter;
                    mat[mapType].needsUpdate = true;
                  }
                });
                mat.needsUpdate = true;
              }
            });
          }
          mv.shadowSoftness = 1.0;
          mv.environmentIntensity = 1.0;
          const camera = mv.scene.camera;
          if (camera) {
            camera.near = 0.001;
            camera.far = 100000;
            camera.updateProjectionMatrix();
          }
        }
        """);
      highQualitySet = true;
    }
  }

  Future<void> _init3DConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString('parallax_3d_settings_v1');
    if (localData != null) {
      Map<String, dynamic> map = jsonDecode(localData);
      d3Config = D3Config.fromMap(map);
    }
  }

  void _initSpatialAudio() {
    jsEval("""
      window.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      window.audioElement = new Audio();
      window.audioElement.crossOrigin = "anonymous";
      window.audioElement.src = 'https://wkpsdgedgtpsiqeyqbhi.supabase.co/storage/v1/object/public/users/tests/audio/Alan%20Walker%20&%20Ava%20Max%20-%20Alone,%20Pt.%20II%20(Lyrics)%20-%207clouds.mp3';
      window.audioElement.load();
      window.audioSource = audioCtx.createMediaElementSource(audioElement);
      window.panner = audioCtx.createPanner();
      panner.panningModel = 'HRTF';
      panner.distanceModel = 'linear';
      panner.refDistance = 1;
      panner.maxDistance = 1000;
      panner.rolloffFactor = 1;
      // Reverb Convolver
      window.reverbNode = audioCtx.createConvolver();
      window.dryGain = audioCtx.createGain();
      window.wetGain = audioCtx.createGain();
      // Create Forest Impulse Response
      const sampleRate = audioCtx.sampleRate;
      const length = sampleRate * 2.5;
      const impulse = audioCtx.createBuffer(2, length, sampleRate);
      for (let i = 0; i < 2; i++) {
        const data = impulse.getChannelData(i);
        for (let j = 0; j < length; j++) {
          data[j] = (Math.random() * 2 - 1) * Math.exp(-j / (sampleRate * 0.4));
        }
      }
      reverbNode.buffer = impulse;
      audioSource.connect(panner);
      panner.connect(dryGain);
      panner.connect(reverbNode);
      reverbNode.connect(wetGain);
      dryGain.connect(audioCtx.destination);
      wetGain.connect(audioCtx.destination);
      window.updateAudio = function(yaw, pitch, deltaZ, revInt, panSens) {
        if (audioCtx.state === 'suspended') return;
        let normYaw = yaw / 60;
        let normPitch = pitch / 40;
        panner.positionX.setTargetAtTime(-normYaw * panSens, audioCtx.currentTime, 0.05);
        panner.positionY.setTargetAtTime(-normPitch * (panSens * 0.66), audioCtx.currentTime, 0.05);
        panner.positionZ.setTargetAtTime(deltaZ * -0.5, audioCtx.currentTime, 0.05);
        let normalizedZ = Math.min(1.0, Math.max(0.0, (deltaZ + 100) / 200));
        dryGain.gain.setTargetAtTime(normalizedZ, audioCtx.currentTime, 0.1);
        wetGain.gain.setTargetAtTime(revInt * (1.2 - normalizedZ), audioCtx.currentTime, 0.1);
      };
    """);
  }

  void _togglePlayback() {
    jsEval("""
      if (window.audioCtx.state === 'suspended') { window.audioCtx.resume(); }
      if (window.audioElement.paused) { window.audioElement.play(); } else { window.audioElement.pause(); }
    """);
    setState(() => isPlaying = !isPlaying);
  }

  void _restartAudio() {
    jsEval("window.audioElement.currentTime = 0; window.audioElement.play();");
    setState(() => isPlaying = true);
  }

  void _saveToHistory() {
    String current = jsonEncode(layerConfigs.map((e) => e.toMap()).toList());
    if (undoStack.isNotEmpty && undoStack.last == current) return;
    undoStack.add(current);
    if (undoStack.length > 50) undoStack.removeAt(0);
    redoStack.clear();
  }

  void _save3DToHistory() {
    String current = jsonEncode(d3Config.toMap());
    if (undo3DStack.isNotEmpty && undo3DStack.last == current) return;
    undo3DStack.add(current);
    if (undo3DStack.length > 50) undo3DStack.removeAt(0);
    redo3DStack.clear();
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

  void _undo3D() {
    if (undo3DStack.isEmpty) return;
    redo3DStack.add(jsonEncode(d3Config.toMap()));
    final state = jsonDecode(undo3DStack.removeLast()) as Map<String, dynamic>;
    setState(() {
      d3Config = D3Config.fromMap(state);
      _updateModelAttributes();
    });
  }

  void _redo3D() {
    if (redo3DStack.isEmpty) return;
    undo3DStack.add(jsonEncode(d3Config.toMap()));
    final state = jsonDecode(redo3DStack.removeLast()) as Map<String, dynamic>;
    setState(() {
      d3Config = D3Config.fromMap(state);
      _updateModelAttributes();
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
      precacheImage(NetworkImage(loaded.last.url!), context).then((_) {
        if (mounted)
          setState(() {
            imagesLoadedCount++;
            if (imagesLoadedCount >= rawLayers.length) isLoaded = true;
          });
      });
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
      int middle = loaded.length ~/ 2;
      loaded.insert(
          middle,
          LayerConfig(
            name: 'turning_point',
            order: middle,
            isVisible: false,
            isLocked: true,
            canShift: false,
            canZoom: false,
            canTilt: false,
          ));
      // Reassign orders after insert
      for (int i = 0; i < loaded.length; i++) {
        loaded[i].order = i;
      }
    } else {
      // If exists from saved, ensure orders are consistent
      loaded.sort((a, b) => a.order.compareTo(b.order));
      for (int i = 0; i < loaded.length; i++) {
        loaded[i].order = i;
      }
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

  Future<void> _save3DConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'parallax_3d_settings_v1', jsonEncode(d3Config.toMap()));
  }

  Future<void> _initTracking() async {
    _updateFacePosTimer();
  }

  void _updateFacePosTimer() {
    _facePosTimer?.cancel();
    int interval = facePosInterval;
    _facePosTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (isEditMode) return;
      JSAny? res = jsEval('getFaceData()');
      if (res != null) {
        JSObject resObj = res as JSObject;
        double noseX = resObj.getProp('noseX')?.toDouble() ?? 0.0;
        double noseY = resObj.getProp('noseY')?.toDouble() ?? 0.0;
        double targetZ = resObj.getProp('z')?.toDouble() ?? 0.0;
        double yaw = resObj.getProp('yaw')?.toDouble() ?? 0.0;
        double pitch = resObj.getProp('pitch')?.toDouble() ?? 0.0;
        setState(() {
          headX = _smooth(headX, -(noseX * 2 - 1), sensitivity: 30.0);
          headY = _smooth(headY, noseY * 2 - 1, sensitivity: 30.0);
          zValue = _smooth(zValue, targetZ, sensitivity: 0.1);
          audioCurrentTime = resObj.getProp('cur')?.toDouble() ?? 0.0;
          audioTotalTime = resObj.getProp('dur')?.toDouble() ?? 0.0;
        });
        jsEval(
            'updateAudio($yaw, $pitch, ${zValue - zBase}, $reverbIntensity, $audioPanSens)');
      }
      if (is3DMode && !isEditMode) {
        double theta =
            d3Config.initTheta + (headX - anchorHeadX) * d3Config.sensX;
        double phi = d3Config.initPhi + (headY - anchorHeadY) * d3Config.sensY;
        double newCenterX = d3Config.centerX;
        double newCenterY = d3Config.centerY;
        double newCenterZ = d3Config.centerZ;
        double deltaZ = (zValue - zBase) * d3Config.sensZ;
        double newScale = d3Config.scale;
        switch (zControl) {
          case 'center x':
            newCenterX += deltaZ;
            break;
          case 'center y':
            newCenterY += deltaZ;
            break;
          case 'center z':
            newCenterZ += deltaZ;
            break;
          case 'model scale':
            newScale += deltaZ;
            break;
        }
        jsEval("""
          const mv = document.querySelector('#mainModel');
          if (mv) {
            mv.cameraOrbit = ${theta}deg ${phi}deg auto;
            mv.cameraTarget = ${newCenterX}m ${newCenterY}m ${newCenterZ}m;
            mv.scale = ${newScale} ${newScale} ${newScale};
          }
          """);
      }
    });
  }

  double _smooth(double current, double target, {double sensitivity = 1.0}) {
    if (isEditMode) return current;
    double alpha =
        ((target - current).abs() * 4.0 * sensitivity).clamp(0.2, 1.0);
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

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent)));
    }
    if (propPanelPos == Offset.zero) {
      propPanelPos = Offset(MediaQuery.of(context).size.width - 320,
          MediaQuery.of(context).size.height / 2 - 300);
    }
    if (controlPanelPos == Offset.zero) {
      controlPanelPos = Offset(MediaQuery.of(context).size.width - 320, 100);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isCalibrated) _build3DScene(),
          if (!isCalibrated) _buildInstructionOverlay(),
          if (isUIToggleOn) _buildDynamicAudioPlayer(),
          if (isUIToggleOn)
            Positioned(left: 20, bottom: 20, child: _buildBottomLeftControls()),
          if (isUIToggleOn)
            Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(child: _buildBottomCenterToggle())),
          if (isEditMode && isUIToggleOn)
            Positioned(
                right: 20, bottom: 20, child: _buildBottomRightControls()),
          if (isEditMode && isUIToggleOn) ...[
            if (showLayerPanel && !is3DMode) _buildDraggableLayerManager(),
            if (showPropPanel) ...[
              if (is3DMode) _buildDraggable3DPropertiesPanel(),
              if (!is3DMode &&
                  layerConfigs.isNotEmpty &&
                  layerConfigs[selectedLayerIndex].name != 'turning_point')
                _buildDraggablePropertiesPanel(),
            ],
            _buildPanelToggles(),
            if (!is3DMode)
              Positioned(top: 60, left: 20, child: _aspectDropdown()),
          ] else if (isCalibrated && isUIToggleOn) ...[
            _buildDraggableControlPanel(),
          ],
          Positioned.fill(child: TrackingTest()),
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

  Widget _buildDynamicAudioPlayer() {
    String formatTime(double sec) {
      if (sec.isNaN || sec.isInfinite) return "0:00";
      int m = (sec / 60).floor();
      int s = (sec % 60).floor();
      return "$m:${s.toString().padLeft(2, '0')}";
    }

    double? left, right, bottom;
    if (isEditMode) {
      left = 130;
      bottom = 20;
    } else {
      right = 20;
      bottom = 20;
    }
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
                color: Colors.cyanAccent.withOpacity(0.5), width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.cyanAccent, size: 28),
                onPressed: _togglePlayback),
            IconButton(
                icon: const Icon(Icons.replay, color: Colors.white, size: 18),
                onPressed: _restartAudio),
            const SizedBox(width: 10),
            Text(formatTime(audioCurrentTime),
                style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const Text(" / ",
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            Text(formatTime(audioTotalTime),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _build3DScene() {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!is3DMode) _buildLayersStack(),
        if (is3DMode)
          SizedBox(
            width: screenWidth * 2,
            height: screenHeight * 2,
            child: Align(
              alignment: Alignment.center,
              child: ModelViewer(
                id: 'mainModel',
                src: d3Config.url,
                cameraControls: isEditMode,
                disableZoom: false,
                disablePan: false,
                disableTap: false,
                autoRotate: false,
                autoPlay: d3Config.playAnimation,
                shadowIntensity: 1.0,
                fieldOfView: 'auto',
                backgroundColor: const Color.fromARGB(0, 0, 0, 0),
                cameraOrbit:
                    '${d3Config.initTheta}deg ${d3Config.initPhi}deg auto',
                cameraTarget:
                    '${d3Config.centerX}m ${d3Config.centerY}m ${d3Config.centerZ}m',
                scale: '${d3Config.scale} ${d3Config.scale} ${d3Config.scale}',
              ),
            ),
          ),
      ],
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
    double shiftMult = faceControlsTilt ? 0.0 : 1.0;
    double tiltMult = faceControlsTilt ? 1.0 : 0.0;
    double tiltXcalc = -devX * 2.0;
    double tiltYcalc = -devY * 2.0;
    double shiftX = isEditMode
        ? config.x
        : (config.canShift
            ? ((-devX *
                        shiftSens *
                        effectiveDepth *
                        80.0 *
                        config.shiftSensMult *
                        sensitivity *
                        shiftSign *
                        shiftMult) +
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
                        shiftSign *
                        shiftMult) +
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
      tiltTransform.setEntry(3, 2, 0.001 + effectiveDepth * tiltOffset * 0.01);
      tiltTransform
          .rotateX(tiltYcalc * tiltMult * tiltSens * sensitivity * 0.3);
      tiltTransform
          .rotateY(tiltXcalc * tiltMult * tiltSens * sensitivity * 0.3);
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
          height: 500,
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
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 14, color: Colors.black),
                    label: const Text("ADD TEXT",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        minimumSize: const Size(double.infinity, 30)),
                    onPressed: () {
                      _saveToHistory();
                      setState(() {
                        String name =
                            "Text_${DateTime.now().millisecondsSinceEpoch}";
                        layerConfigs.add(LayerConfig(
                            order: layerConfigs.length,
                            name: name,
                            isText: true));
                        selectedLayerIndex = layerConfigs.length - 1;
                        showPropPanel = true;
                      });
                    })),
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
        if (selectedLayerIndex == realIdx && showPropPanel) {
          showPropPanel = false;
        } else {
          selectedLayerIndex = realIdx;
          showPropPanel = !isTurningPoint;
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

  Widget _buildDraggable3DPropertiesPanel() {
    double sensZMax = (zControl == 'model scale') ? 0.1 : 100.0;
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
                      const Text("3D PROPERTIES",
                          style: TextStyle(
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
                const Text("MODEL URL",
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
                TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                        filled: true, fillColor: Colors.white10),
                    onChanged: (v) {
                      _save3DToHistory();
                      setState(() {
                        d3Config.url = v;
                        _updateModelAttributes();
                      });
                    },
                    controller: TextEditingController(text: d3Config.url)
                      ..selection =
                          TextSelection.collapsed(offset: d3Config.url.length)),
                const SizedBox(height: 10),
                _toggleRow(
                    "Play Animation",
                    d3Config.playAnimation,
                    (v) => setState(() {
                          d3Config.playAnimation = v;
                          _updateModelAttributes();
                        })),
                const Divider(color: Colors.white24),
                _enhancedSlider(
                    "Init Theta",
                    d3Config.initTheta.abs(),
                    0,
                    360,
                    1.0,
                    (v) => setState(() {
                          d3Config.initTheta = -v;
                          _updateModelAttributes();
                        })),
                _enhancedSlider(
                    "Init Phi",
                    d3Config.initPhi,
                    0,
                    360,
                    1.0,
                    (v) => setState(() {
                          d3Config.initPhi = v;
                          _updateModelAttributes();
                        })),
                ElevatedButton(
                    onPressed: _captureOrbit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 36)),
                    child: const Text("Capture Current Orbit",
                        style: TextStyle(color: Colors.white, fontSize: 10))),
                const SizedBox(height: 10),
                _enhancedSlider(
                    "Center X",
                    d3Config.centerX,
                    -150,
                    150,
                    1.0,
                    (v) => setState(() {
                          d3Config.centerX = v;
                          _updateModelAttributes();
                        })),
                _enhancedSlider(
                    "Center Y",
                    d3Config.centerY,
                    -150,
                    150,
                    1.0,
                    (v) => setState(() {
                          d3Config.centerY = v;
                          _updateModelAttributes();
                        })),
                _enhancedSlider(
                    "Center Z",
                    d3Config.centerZ,
                    -150,
                    150,
                    1.0,
                    (v) => setState(() {
                          d3Config.centerZ = v;
                          _updateModelAttributes();
                        })),
                ElevatedButton(
                    onPressed: _captureTarget,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 36)),
                    child: const Text("Capture Current Target",
                        style: TextStyle(color: Colors.white, fontSize: 10))),
                const SizedBox(height: 10),
                _enhancedSlider(
                    "Model Scale",
                    d3Config.scale,
                    0,
                    100,
                    0.1,
                    (v) => setState(() {
                          d3Config.scale = v;
                          _updateModelAttributes();
                        })),
                const Divider(color: Colors.white24),
                _enhancedSlider("Sens X", d3Config.sensX, 0.01, 100, 0.1,
                    (v) => setState(() => d3Config.sensX = v)),
                _enhancedSlider("Sens Y", d3Config.sensY, 0.01, 100, 0.1,
                    (v) => setState(() => d3Config.sensY = v)),
                _enhancedSlider("Sens Z (Zoom)", d3Config.sensZ, 0.01, sensZMax,
                    0.01, (v) => setState(() => d3Config.sensZ = v)),
                const Text("Face Z Control",
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
                DropdownButton<String>(
                  value: zControl,
                  isExpanded: true,
                  dropdownColor: Colors.grey[900],
                  underline: Container(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: ['center x', 'center y', 'center z', 'model scale']
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) => setState(() => zControl = v!),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: _save3DConfig,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        minimumSize: const Size(double.infinity, 36)),
                    child: const Text("SAVE 3D CONFIG",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10))),
              ])),
        ),
      ),
    );
  }

  void _updateModelAttributes() {
    jsEval("""
      const mv = document.querySelector('#mainModel');
      if (mv) {
        mv.src = '${d3Config.url}';
        mv.cameraOrbit = '${d3Config.initTheta}deg ${d3Config.initPhi}deg auto';
        mv.cameraTarget = '${d3Config.centerX}m ${d3Config.centerY}m ${d3Config.centerZ}m';
        mv.scale = '${d3Config.scale} ${d3Config.scale} ${d3Config.scale}';
        mv.autoPlay = ${d3Config.playAnimation};
      }
      """);
  }

  void _captureOrbit() {
    JSAny? res = jsEval("""
      const mv = document.querySelector('#mainModel');
      if (mv) {
        const orbit = mv.getCameraOrbit();
        return [orbit.theta * 180 / Math.PI, orbit.phi * 180 / Math.PI];
      } else {
        return [0, 85];
      }
      """);
    if (res != null) {
      List<double> vals = res.toDoubleList();
      _save3DToHistory();
      setState(() {
        d3Config.initTheta = vals[0];
        d3Config.initPhi = vals[1];
        _updateModelAttributes();
      });
    }
  }

  void _captureTarget() {
    JSAny? res = jsEval("""
      const mv = document.querySelector('#mainModel');
      if (mv) {
        const target = mv.getCameraTarget();
        return [target.x, target.y, target.z];
      } else {
        return [0, 0, 0];
      }
      """);
    if (res != null) {
      List<double> vals = res.toDoubleList();
      _save3DToHistory();
      setState(() {
        d3Config.centerX = vals[0];
        d3Config.centerY = vals[1];
        d3Config.centerZ = vals[2];
        _updateModelAttributes();
      });
    }
  }

  void _captureScale() {
    JSAny? res = jsEval("""
      const mv = document.querySelector('#mainModel');
      if (mv) {
        return mv.scale.split(' ')[0];
      }
      return null;
      """);
    if (res != null) {
      double newScale = double.tryParse(res.toStringDart() ?? '1.0') ?? 1.0;
      _save3DToHistory();
      setState(() {
        d3Config.scale = newScale;
        _updateModelAttributes();
      });
    }
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
                const Text("AUDIO & SCENE",
                    style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                _enhancedSlider("Reverb (8D)", reverbIntensity, 0.0, 1.5, 0.1,
                    (v) {
                  setState(() => reverbIntensity = v);
                  _debounceSave();
                }),
                _enhancedSlider("Pan Sens (360)", audioPanSens, 1.0, 50.0, 1.0,
                    (v) {
                  setState(() => audioPanSens = v);
                  _debounceSave();
                }),
                const Divider(color: Colors.white10),
                _enhancedSlider("Global Scale", currentScale, 0.5, 2.5, 0.1,
                    (v) {
                  setState(() => currentScale = v);
                  _debounceSave();
                }),
                _enhancedSlider("Global Depth", displayDepth, 0.0, 1.0, 0.001,
                    (v) {
                  setState(() {
                    displayDepth = v;
                    depthZoomSens = v * 0.05;
                  });
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
                _enhancedSlider("Tilt Offset", tiltOffset, 0.0, 1.0, 0.001,
                    (v) {
                  setState(() => tiltOffset = v);
                  _debounceSave();
                }),
                _toggleRow("Face XY Controls Tilt", faceControlsTilt, (v) {
                  setState(() => faceControlsTilt = v);
                  _debounceSave();
                }),
                TextButton(
                    onPressed: () => setState(() => isCalibrated = false),
                    child: const Text("RE-CALIBRATE",
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 10)))
              ]),
            ),
          ),
        ),
      );
  Widget _buildBottomRightControls() => Row(children: [
        _roundBtn(Icons.undo, is3DMode ? _undo3D : _undo,
            (is3DMode ? undo3DStack : undoStack).isNotEmpty),
        const SizedBox(width: 10),
        _roundBtn(Icons.redo, is3DMode ? _redo3D : _redo,
            (is3DMode ? redo3DStack : redoStack).isNotEmpty),
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
        if (!is3DMode)
          _toggleBtn("LAYERS", showLayerPanel,
              () => setState(() => showLayerPanel = !showLayerPanel)),
        if (!is3DMode) const SizedBox(width: 10),
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
    _updateModelAttributes();
  }

  void _exitEditMode() {
    JSAny? res = jsEval('getFaceData()');
    if (res != null) {
      JSObject resObj = res as JSObject;
      double noseX = resObj.getProp('noseX')?.toDouble() ?? 0.0;
      double noseY = resObj.getProp('noseY')?.toDouble() ?? 0.0;
      double newZ = resObj.getProp('z')?.toDouble() ?? 0.0;
      setState(() {
        headX = -(noseX * 2 - 1);
        headY = noseY * 2 - 1;
        zValue = newZ;
      });
      anchorHeadX = headX;
      anchorHeadY = headY;
      zBase = newZ;
      if (is3DMode) {
        _captureOrbit();
        _captureTarget();
        _captureScale();
      }
    }
    _saveAllConfigs();
    _save3DConfig();
    _saveControlSettings();
  }

  Widget _buildBottomLeftControls() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text("3D/LAYER MODE",
                    style: TextStyle(color: Colors.white, fontSize: 10)),
                Switch(
                    value: is3DMode,
                    activeColor: Colors.cyanAccent,
                    onChanged: (v) {
                      setState(() {
                        is3DMode = v;
                        _updateFacePosTimer();
                        if (is3DMode) {
                          _apply3DInitialsToFace();
                        }
                      });
                    })
              ])),
        ],
      );
  void _apply3DInitialsToFace() {
    JSAny? res = jsEval('getFaceData()');
    if (res != null) {
      JSObject resObj = res as JSObject;
      double noseX = resObj.getProp('noseX')?.toDouble() ?? 0.0;
      double noseY = resObj.getProp('noseY')?.toDouble() ?? 0.0;
      double targetZ = resObj.getProp('z')?.toDouble() ?? 0.0;
      double targetHeadX = -(noseX * 2 - 1);
      double targetHeadY = noseY * 2 - 1;
      double theta =
          d3Config.initTheta + (targetHeadX - anchorHeadX) * d3Config.sensX;
      double phi =
          d3Config.initPhi + (targetHeadY - anchorHeadY) * d3Config.sensY;
      double newCenterX = d3Config.centerX;
      double newCenterY = d3Config.centerY;
      double newCenterZ = d3Config.centerZ;
      double deltaZ = (targetZ - zBase) * d3Config.sensZ;
      double newScale = d3Config.scale;
      switch (zControl) {
        case 'center x':
          newCenterX += deltaZ;
          break;
        case 'center y':
          newCenterY += deltaZ;
          break;
        case 'center z':
          newCenterZ += deltaZ;
          break;
        case 'model scale':
          newScale += deltaZ;
          break;
      }
      jsEval("""
const mv = document.querySelector('#mainModel');
if (mv) {
mv.cameraOrbit = ${theta}deg ${phi}deg auto;
mv.cameraTarget = ${newCenterX}m ${newCenterY}m ${newCenterZ}m;
mv.scale = ${newScale} ${newScale} ${newScale};
}
""");
    }
  }

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
                            if (is3DMode) {
                              _save3DToHistory();
                            } else {
                              _saveToHistory();
                            }
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
              if (is3DMode) {
                _save3DToHistory();
              } else {
                _saveToHistory();
              }
              cb(val);
              _debounceSaveConfigs();
            })
      ]);
  Widget _buildInstructionOverlay() => Container(
      color: Colors.black.withOpacity(0.87),
      child: Center(
          child: Container(
              width: 320,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("STABILIZING",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text("Center face in camera.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 30),
                ElevatedButton(
                    onPressed: () => setState(() {
                          zBase = zValue > 0 ? zValue : 100.0;
                          anchorHeadX = headX;
                          anchorHeadY = headY;
                          isCalibrated = true;
                        }),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent),
                    child: const Text("START",
                        style: TextStyle(color: Colors.black)))
              ]))));
  @override
  void dispose() {
    _facePosTimer?.cancel();
    _pollTimer?.cancel();
    _uiPollTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debounceSaveConfigs() {}
}

class TrackingTest extends StatefulWidget {
  const TrackingTest({
    super.key,
    this.width,
    this.height,
  });
  final double? width;
  final double? height;
  @override
  State<TrackingTest> createState() => _TrackingTestState();
}

class _TrackingTestState extends State<TrackingTest> {
  final String viewID = 'face-tracker-toggle-view';
  @override
  void initState() {
    super.initState();
    _injectMediaPipeScripts();
    // Register the view factory using the new package:web types
    ui_web.platformViewRegistry.registerViewFactory(viewID, (int viewId) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'main-container';
      container.style.width = '100%';
      container.style.height = '100%';
      container.style.backgroundColor = 'transparent';
      container.style.position = 'relative';
      container.style.pointerEvents =
          'none'; // Keep 'none' on container to not block Flutter gestures below
      // 1. Control Panel
      final controls = web.document.createElement('div') as web.HTMLDivElement;
      controls.style.position = 'absolute';
      controls.style.top = '10px';
      controls.style.right = '10px';
      controls.style.zIndex = '100';
      controls.style.display = 'flex';
      controls.style.flexDirection = 'column';
      controls.style.gap = '8px';
      controls.style.padding = '10px';
      controls.style.backgroundColor = 'rgba(0,0,0,0.6)';
      controls.style.borderRadius = '8px';
      controls.style.color = 'white';
      controls.style.fontFamily = 'sans-serif';
      controls.style.pointerEvents =
          'auto'; // Explicitly allow interaction on controls
      controls.innerHTML = '''
        <div style="display:flex; align-items:center; gap:10px;">
          <input type="checkbox" id="visibility-toggle" checked>
          <label for="visibility-toggle">Show UI</label>
        </div>
        <div style="display:flex; align-items:center; gap:10px;">
          <input type="checkbox" id="tracking-toggle" checked>
          <label for="tracking-toggle">Active Tracking</label>
        </div>
        <div style="display:flex; align-items:center; gap:10px;">
          <span>Cursor Mode:</span>
          <input type="radio" id="mode-iris" name="cursor-mode" checked>
          <label for="mode-iris">Iris</label>
          <input type="radio" id="mode-nose" name="cursor-mode">
          <label for="mode-nose">Nose</label>
        </div>
      '''
          .toJS as String;
      // 2. Video Preview Box
      final videoBox = web.document.createElement('div') as web.HTMLDivElement;
      videoBox.id = 'ui-video-box';
      videoBox.style.position = 'absolute';
      videoBox.style.top = '10px';
      videoBox.style.left = '10px';
      videoBox.style.width = '250px';
      videoBox.style.height = '250px';
      videoBox.style.overflow = 'hidden';
      videoBox.style.borderRadius = '8px';
      videoBox.style.backgroundColor = '#000';
      videoBox.style.pointerEvents = 'none';
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.id = 'webcam-small';
      video.autoplay = true;
      video.muted = true;
      video.setAttribute('playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = 'cover';
      video.style.transform = 'scaleX(-1)';
      final faceCanvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      faceCanvas.id = 'face-dots-overlay';
      faceCanvas.width = 250;
      faceCanvas.height = 250;
      faceCanvas.style.position = 'absolute';
      faceCanvas.style.top = '0';
      faceCanvas.style.left = '0';
      faceCanvas.style.width = '100%';
      faceCanvas.style.height = '100%';
      faceCanvas.style.transform = 'scaleX(-1)';
      faceCanvas.style.pointerEvents = 'none';
      // 3. Info Panel Layer
      final textCanvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      textCanvas.id = 'ui-text-canvas';
      textCanvas.style.position = 'absolute';
      textCanvas.style.top = '0';
      textCanvas.style.left = '0';
      textCanvas.style.width = '100%';
      textCanvas.style.height = '100%';
      textCanvas.style.pointerEvents = 'none';
      // Fake Cursor
      final cursor = web.document.createElement('div') as web.HTMLDivElement;
      cursor.id = 'fake-cursor';
      cursor.style.position = 'absolute';
      cursor.style.width = '10px';
      cursor.style.height = '10px';
      cursor.style.backgroundColor = 'red';
      cursor.style.borderRadius = '50%';
      cursor.style.pointerEvents = 'none';
      cursor.style.zIndex = '999';
      cursor.style.display = 'none';
      videoBox.append(video);
      videoBox.append(faceCanvas);
      container.append(videoBox);
      container.append(textCanvas);
      container.append(controls);
      container.append(cursor);
      _initTrackingLogic();
      return container;
    });
  }

  void _injectMediaPipeScripts() {
    final scripts = [
      "https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/face_mesh.js",
      "https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js"
    ];
    for (var src in scripts) {
      if (web.document.querySelector('script[src="$src"]') == null) {
        final script =
            web.document.createElement('script') as web.HTMLScriptElement;
        script.src = src;
        script.crossOrigin = "anonymous";
        web.document.head?.append(script);
      }
    }
  }

  void _initTrackingLogic() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      const jsCode = """
      (async function() {
        // Polyfit gauss-jordan functions (unchanged from your working version)
        function gaussJordanDivide(matrix, row, col, numCols) {
          for (var i = col + 1; i < numCols; i++) {
            matrix[row][i] /= matrix[row][col];
          }
          matrix[row][col] = 1;
        }
        function gaussJordanEliminate(matrix, row, col, numRows, numCols) {
          for (var i = 0; i < numRows; i++) {
            if (i !== row && matrix[i][col] !== 0) {
              for (var j = col + 1; j < numCols; j++) {
                matrix[i][j] -= matrix[i][col] * matrix[row][j];
              }
              matrix[i][col] = 0;
            }
          }
        }
        function gaussJordanEchelonize(matrix) {
          var rows = matrix.length;
          var cols = matrix[0].length;
          var i = 0;
          var j = 0;
          var k;
          var swap;
          while (i < rows && j < cols) {
            k = i;
            while (k < rows && matrix[k][j] === 0) {
              k++;
            }
            if (k < rows) {
              if (k !== i) {
                swap = matrix[i];
                matrix[i] = matrix[k];
                matrix[k] = swap;
              }
              if (matrix[i][j] !== 1) {
                gaussJordanDivide(matrix, i, j, cols);
              }
              gaussJordanEliminate(matrix, i, j, rows, cols);
              i++;
            }
            j++;
          }
          return matrix;
        }
        function matrixTranspose(m) {
          const rows = m.length, cols = m[0].length;
          const t = Array.from({length: cols}, () => Array(rows).fill(0));
          for(let i=0; i<rows; i++) for(let j=0; j<cols; j++) t[j][i] = m[i][j];
          return t;
        }
        function matrixMul(a, b) {
          const rowsA = a.length, colsA = a[0].length, rowsB = b.length, colsB = b[0].length;
          if (colsA !== rowsB) return null;
          const res = Array.from({length: rowsA}, () => Array(colsB).fill(0));
          for(let i=0; i<rowsA; i++) for(let j=0; j<colsB; j++) for(let k=0; k<colsA; k++) res[i][j] += a[i][k] * b[k][j];
          return res;
        }
        function solveLeastSquares(X, y) {
          const Xt = matrixTranspose(X);
          const AtA = matrixMul(Xt, X);
          const ycol = y.map(v => [v]);
          const Aty = matrixMul(Xt, ycol);
          const aug = AtA.map((row, i) => [...row, Aty[i][0]]);
          gaussJordanEchelonize(aug);
          const coeffs = aug.map(row => row[row.length - 1]);
          return coeffs;
        }
        function getBasis(u, v, degree) {
          const basis = [];
          for(let i = 0; i <= degree; i++) {
            for(let j = 0; j <= degree - i; j++) {
              basis.push(Math.pow(u, i) * Math.pow(v, j));
            }
          }
          return basis;
        }
        function refitModel(mode, degree) {
          const calibs = calibrations[mode];
          const numTerms = (degree + 1) * (degree + 2) / 2;
          if (calibs.length < numTerms) {
            models[mode] = {coeffX: null, coeffY: null};
            return;
          }
          let X = [];
          let yx = [];
          let yy = [];
          for(let p of calibs) {
            X.push(getBasis(p.featX, p.featY, degree));
            yx.push(p.targetX);
            yy.push(p.targetY);
          }
          const coeffX = solveLeastSquares(X, yx);
          const coeffY = solveLeastSquares(X, yy);
          models[mode] = {coeffX, coeffY};
        }
        const video = document.getElementById('webcam-small');
        const fCanvas = document.getElementById('face-dots-overlay');
        const tCanvas = document.getElementById('ui-text-canvas');
        const main = document.getElementById('main-container');
        const vBox = document.getElementById('ui-video-box');
        const cursor = document.getElementById('fake-cursor');
        const visToggle = document.getElementById('visibility-toggle');
        const trackToggle = document.getElementById('tracking-toggle');
        const fCtx = fCanvas.getContext('2d', { alpha: true, desynchronized: true });
        const tCtx = tCanvas.getContext('2d', { alpha: true, desynchronized: true });
        let camera = null;
        let latestLM = null;
        let calibrations = JSON.parse(localStorage.getItem('eye_calibrations')) || {iris: [], nose: []};
        let models = {iris: {coeffX: null, coeffY: null}, nose: {coeffX: null, coeffY: null}};
        const degree = 2;
        refitModel('iris', degree);
        refitModel('nose', degree);
        const faceMesh = new FaceMesh({locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/\${file}`});
        faceMesh.setOptions({ maxNumFaces: 1, refineLandmarks: true, minDetectionConfidence: 0.5, minTrackingConfidence: 0.5 });
        faceMesh.onResults((results) => {
          if (!trackToggle.checked) {
            cursor.style.display = 'none';
            return;
          }
          cursor.style.display = 'block';
          const isVisible = visToggle.checked;
          vBox.style.display = isVisible ? 'block' : 'none';
          fCtx.clearRect(0, 0, 250, 250);
          tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
          if (tCanvas.width !== main.clientWidth) {
            tCanvas.width = main.clientWidth;
            tCanvas.height = main.clientHeight;
          }
          if (results.multiFaceLandmarks && results.multiFaceLandmarks[0]) {
            const lm = results.multiFaceLandmarks[0];
            latestLM = lm;
            if (isVisible) {
              const vW = video.videoWidth;
              const vH = video.videoHeight;
              const scale = 250 / Math.min(vW, vH);
              const offX = (vW * scale - 250) / 2;
              const offY = (vH * scale - 250) / 2;
              fCtx.fillStyle = 'rgba(255, 255, 255, 0.6)';
              fCtx.beginPath();
              for (let i = 0; i < lm.length; i++) {
                fCtx.rect((lm[i].x * vW * scale) - offX, (lm[i].y * vH * scale) - offY, 1, 1);
              }
              fCtx.fill();
              const p = (i) => ({ x: (lm[i].x * vW * scale)-offX, y: (lm[i].y * vH * scale)-offY });
              const n = p(1), l = p(468), r = p(473);
              const z = Math.sqrt(Math.pow((lm[473].x - lm[468].x) * vW, 2) + Math.pow((lm[473].y - lm[468].y) * vH, 2));
              const yaw = ((lm[1].x - lm[234].x) / (lm[454].x - lm[234].x) - 0.5) * -120;
              const pitch = ((lm[1].y - lm[10].y) / (lm[152].y - lm[10].y) - 0.5) * 80;
              const sX = tCanvas.width - 270, sY = tCanvas.height - 190;
              tCtx.fillStyle = 'rgba(0,0,0,0.5)';
              tCtx.fillRect(sX, sY, 250, 170);
              tCtx.fillStyle = '#0FF';
              tCtx.font = '13px monospace';
              [`nose: (\${n.x.toFixed(0)},\${n.y.toFixed(0)})`,
               `lEye: (\${l.x.toFixed(0)},\${l.y.toFixed(0)})`,
               `rEye: (\${r.x.toFixed(0)},\${r.y.toFixed(0)})`,
               `depth (z): \${z.toFixed(1)}`,
               `yaw: \${yaw.toFixed(1)}°`,
               `pitch: \${pitch.toFixed(1)}°`
              ].forEach((txt, i) => tCtx.fillText(txt, sX + 15, sY + 30 + (i * 22)));
            }
            const currentMode = document.querySelector('input[name="cursor-mode"]:checked').id === 'mode-iris' ? 'iris' : 'nose';
            let fx, fy;
            if (currentMode === 'iris') {
              const leftIris = lm[468];
              const rightIris = lm[473];
              const avgX = (leftIris.x + rightIris.x) / 2;
              const avgY = (leftIris.y + rightIris.y) / 2;
              fx = 1 - avgX;
              fy = avgY;
            } else {
              const nose = lm[1];
              fx = 1 - nose.x;
              fy = nose.y;
            }
            const calibs = calibrations[currentMode];
            const model = models[currentMode];
            if (calibs.length === 0) {
              cursor.style.display = 'none';
              return;
            }
            if (model.coeffX && model.coeffY) {
              const feat = getBasis(fx, fy, degree);
              let predX = 0;
              let predY = 0;
              for (let i = 0; i < feat.length; i++) {
                predX += feat[i] * model.coeffX[i];
                predY += feat[i] * model.coeffY[i];
              }
              predX = Math.max(0, Math.min(1, predX));
              predY = Math.max(0, Math.min(1, predY));
              cursor.style.left = (predX * main.clientWidth) + 'px';
              cursor.style.top = (predY * main.clientHeight) + 'px';
            } else {
              let sumX = 0, sumY = 0, sumW = 0;
              let exact = false;
              for (let p of calibs) {
                const dx = fx - p.featX;
                const dy = fy - p.featY;
                const distSq = dx * dx + dy * dy;
                if (distSq < 1e-6) {
                  cursor.style.left = (p.targetX * main.clientWidth) + 'px';
                  cursor.style.top = (p.targetY * main.clientHeight) + 'px';
                  exact = true;
                  break;
                }
                const w = 1 / distSq;
                sumX += p.targetX * w;
                sumY += p.targetY * w;
                sumW += w;
              }
              if (!exact) {
                const predX = sumX / sumW;
                const predY = sumY / sumW;
                cursor.style.left = (predX * main.clientWidth) + 'px';
                cursor.style.top = (predY * main.clientHeight) + 'px';
              }
            }
          }
        });
        main.addEventListener('click', (event) => {
          if (!trackToggle.checked || !latestLM) return;
          const rect = main.getBoundingClientRect();
          const mouseX = event.clientX - rect.left;
          const mouseY = event.clientY - rect.top;
          const newTargetX = mouseX / rect.width;
          const newTargetY = mouseY / rect.height;
          const lm = latestLM;
          const currentMode = document.querySelector('input[name="cursor-mode"]:checked').id === 'mode-iris' ? 'iris' : 'nose';
          let fx, fy;
          if (currentMode === 'iris') {
            const leftIris = lm[468];
            const rightIris = lm[473];
            const avgX = (leftIris.x + rightIris.x) / 2;
            const avgY = (leftIris.y + rightIris.y) / 2;
            fx = 1 - avgX;
            fy = avgY;
          } else {
            const nose = lm[1];
            fx = 1 - nose.x;
            fy = nose.y;
          }
          const calibs = calibrations[currentMode];
          let closest = null, minDist = Infinity;
          for (let p of calibs) {
            const dx = newTargetX - p.targetX;
            const dy = newTargetY - p.targetY;
            const d = dx * dx + dy * dy;
            if (d < minDist) {
              minDist = d;
              closest = p;
            }
          }
          const threshDistSq = 0.0001;
          if (minDist < threshDistSq && closest) {
            closest.targetX = (closest.targetX * closest.count + newTargetX) / (closest.count + 1);
            closest.targetY = (closest.targetY * closest.count + newTargetY) / (closest.count + 1);
            closest.featX = (closest.featX * closest.count + fx) / (closest.count + 1);
            closest.featY = (closest.featY * closest.count + fy) / (closest.count + 1);
            closest.count++;
          } else {
            calibs.push({targetX: newTargetX, targetY: newTargetY, featX: fx, featY: fy, count: 1});
          }
          localStorage.setItem('eye_calibrations', JSON.stringify(calibrations));
          refitModel(currentMode, degree);
        });
        async function startCamera() {
          if (!camera) {
            camera = new Camera(video, {
              onFrame: async () => { if(trackToggle.checked) await faceMesh.send({image: video}); },
              width: 360, height: 360
            });
          }
          await camera.start();
        }
        async function stopCamera() {
          if (camera) {
            await camera.stop();
            const stream = video.srcObject;
            if (stream) {
              stream.getTracks().forEach(track => track.stop());
            }
            video.srcObject = null;
            fCtx.clearRect(0, 0, 250, 250);
            tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
          }
          latestLM = null;
        }
        trackToggle.addEventListener('change', async () => {
          if (trackToggle.checked) {
            await startCamera();
          } else {
            await stopCamera();
          }
        });
        visToggle.addEventListener('change', () => {
          vBox.style.display = visToggle.checked ? 'block' : 'none';
          if (!visToggle.checked) {
            fCtx.clearRect(0, 0, 250, 250);
            tCtx.clearRect(0, 0, tCanvas.width, tCanvas.height);
          }
        });
        document.querySelectorAll('input[name="cursor-mode"]').forEach(radio => {
          radio.addEventListener('change', () => {
            refitModel(document.querySelector('input[name="cursor-mode"]:checked').id === 'mode-iris' ? 'iris' : 'nose', degree);
          });
        });
        await startCamera();
        window.getFaceData = function() {
          if (!latestLM) return null;
          const lm = latestLM;
          const nose = lm[1];
          const leftIris = lm[468];
          const rightIris = lm[473];
          const z = Math.sqrt(Math.pow((lm[473].x - lm[468].x) * video.videoWidth, 2) + Math.pow((lm[473].y - lm[468].y) * video.videoHeight, 2));
          const yaw = ((lm[1].x - lm[234].x) / (lm[454].x - lm[234].x) - 0.5) * -120;
          const pitch = ((lm[1].y - lm[10].y) / (lm[152].y - lm[10].y) - 0.5) * 80;
          return {
            noseX: nose.x,
            noseY: nose.y,
            leftEyeX: leftIris.x,
            leftEyeY: leftIris.y,
            rightEyeX: rightIris.x,
            rightEyeY: rightIris.y,
            z: z,
            yaw: yaw,
            pitch: pitch,
            cur: window.audioElement ? window.audioElement.currentTime : 0,
            dur: window.audioElement ? window.audioElement.duration : 0
          };
        };
      })();
      """;
      (web.window).callMethod('eval'.toJS, jsCode.toJS);
    });
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring:
            true, // Flutter ignores pointers on this widget (safe fallback)
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.height ?? double.infinity,
          child: HtmlElementView(viewType: viewID),
        ),
      );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepX',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ImmersiveCard(),
    );
  }
}
