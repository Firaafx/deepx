import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/appearance_settings_service.dart';

const double _svgCardBaseWidth = 1852;
const double _svgCardBaseHeight = 1413;
const double _kTwoLineTitleExpansion = 102;
const double _kMetaTextLeftInsetBase = 24;

const Color _kShellColor = Color(0x992A2A2A);
const Color _kInnerColor = Color(0xFF151515);
const Color _kStrokeColor = Color(0xFFCACACA);
const Color _kMetaColor = Color(0xFFB4B4B4);

enum SvgCardMetaSize { small, medium, large }

class _UsernameNotchVariant {
  const _UsernameNotchVariant({
    required this.placeholderTop,
    required this.placeholderHeight,
    required this.sideTop,
  });

  final double placeholderTop;
  final double placeholderHeight;
  final double sideTop;

  double get sideBottom => 859.257;
}

class _MetaNotchVariant {
  const _MetaNotchVariant({
    required this.placeholderLeft,
    required this.placeholderWidth,
    required this.shelfStart,
    required this.shelfControl1,
    required this.shelfControl2,
    required this.shelfEnd,
    required this.tabStart,
    required this.tabControl1,
    required this.tabControl2,
    required this.tabEnd,
  });

  final double placeholderLeft;
  final double placeholderWidth;
  final double shelfStart;
  final double shelfControl1;
  final double shelfControl2;
  final double shelfEnd;
  final double tabStart;
  final double tabControl1;
  final double tabControl2;
  final double tabEnd;
}

_UsernameNotchVariant _usernameVariantForCount(int usernameCharCount) {
  final int count = usernameCharCount.clamp(2, 6).toInt();
  switch (count) {
    case 2:
      return const _UsernameNotchVariant(
        placeholderTop: 776,
        placeholderHeight: 114,
        sideTop: 812.423,
      );
    case 3:
      return const _UsernameNotchVariant(
        placeholderTop: 694,
        placeholderHeight: 196,
        sideTop: 735.966,
      );
    case 4:
      return const _UsernameNotchVariant(
        placeholderTop: 634,
        placeholderHeight: 256,
        sideTop: 672.675,
      );
    case 5:
      return const _UsernameNotchVariant(
        placeholderTop: 572,
        placeholderHeight: 318,
        sideTop: 611.169,
      );
    case 6:
    default:
      return const _UsernameNotchVariant(
        placeholderTop: 500,
        placeholderHeight: 390,
        sideTop: 520.597,
      );
  }
}

_MetaNotchVariant _metaVariantForSize(SvgCardMetaSize size) {
  switch (size) {
    case SvgCardMetaSize.small:
      return const _MetaNotchVariant(
        placeholderLeft: 1203,
        placeholderWidth: 441,
        shelfStart: 1110.75,
        shelfControl1: 1121.59,
        shelfControl2: 1132.12,
        shelfEnd: 1140.65,
        tabStart: 1225,
        tabControl1: 1234.06,
        tabControl2: 1245.24,
        tabEnd: 1256.75,
      );
    case SvgCardMetaSize.medium:
      return const _MetaNotchVariant(
        placeholderLeft: 1064,
        placeholderWidth: 580,
        shelfStart: 974.254,
        shelfControl1: 985.093,
        shelfControl2: 995.62,
        shelfEnd: 1004.15,
        tabStart: 1088.5,
        tabControl1: 1097.56,
        tabControl2: 1108.74,
        tabEnd: 1120.25,
      );
    case SvgCardMetaSize.large:
      return const _MetaNotchVariant(
        placeholderLeft: 978,
        placeholderWidth: 666,
        shelfStart: 902.253,
        shelfControl1: 913.092,
        shelfControl2: 923.619,
        shelfEnd: 932.153,
        tabStart: 1016.5,
        tabControl1: 1025.56,
        tabControl2: 1036.74,
        tabEnd: 1048.25,
      );
  }
}

SvgCardMetaSize svgCardMetaSizeForText(BuildContext context, String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return SvgCardMetaSize.small;
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: GoogleFonts.inter(
        color: _kMetaColor,
        fontWeight: FontWeight.w400,
        fontSize: 55,
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout(maxWidth: 9999);
  final double measuredBase = painter.width + 52;
  if (measuredBase <= 441) return SvgCardMetaSize.small;
  if (measuredBase <= 580) return SvgCardMetaSize.medium;
  return SvgCardMetaSize.large;
}

void _appendLeftUsernameSegment(
  Path path,
  double sx,
  double sy,
  _UsernameNotchVariant variant,
) {
  if (variant.placeholderHeight == 390) {
    path
      ..lineTo(183.5 * sx, 520.597 * sy)
      ..cubicTo(
        183.5 * sx,
        507.93 * sy,
        178.832 * sx,
        495.707 * sy,
        170.388 * sx,
        486.266 * sy,
      )
      ..lineTo(134.058 * sx, 445.641 * sy)
      ..cubicTo(
        130.479 * sx,
        441.639 * sy,
        128.5 * sx,
        436.459 * sy,
        128.5 * sx,
        431.091 * sy,
      )
      ..cubicTo(
        128.5 * sx,
        425.067 * sy,
        130.989 * sx,
        419.311 * sy,
        135.379 * sx,
        415.186 * sy,
      )
      ..lineTo(148.27 * sx, 403.07 * sy)
      ..cubicTo(
        158.626 * sx,
        393.337 * sy,
        164.5 * sx,
        379.756 * sy,
        164.5 * sx,
        365.543 * sy,
      )
      ..lineTo(164.5 * sx, 258.541 * sy);
    return;
  }

  if (variant.placeholderHeight == 318) {
    path
      ..lineTo(183.5 * sx, 611.169 * sy)
      ..cubicTo(
        183.5 * sx,
        599.08 * sy,
        179.246 * sx,
        587.375 * sy,
        171.484 * sx,
        578.106 * sy,
      )
      ..lineTo(137.454 * sx, 537.465 * sy)
      ..cubicTo(
        130.145 * sx,
        528.736 * sy,
        126.139 * sx,
        517.713 * sy,
        126.139 * sx,
        506.328 * sy,
      )
      ..lineTo(126.139 * sx, 444.136 * sy);
  } else if (variant.placeholderHeight == 256) {
    path
      ..lineTo(183.5 * sx, 672.675 * sy)
      ..cubicTo(
        183.5 * sx,
        659.038 * sy,
        178.091 * sx,
        645.958 * sy,
        168.46 * sx,
        636.303 * sy,
      )
      ..lineTo(140.303 * sx, 608.078 * sy)
      ..cubicTo(
        131.233 * sx,
        598.986 * sy,
        126.139 * sx,
        586.667 * sy,
        126.139 * sx,
        573.825 * sy,
      )
      ..lineTo(126.139 * sx, 444.136 * sy);
  } else if (variant.placeholderHeight == 196) {
    path
      ..lineTo(183.5 * sx, 735.966 * sy)
      ..cubicTo(
        183.5 * sx,
        723.071 * sy,
        178.662 * sx,
        710.645 * sy,
        169.942 * sx,
        701.144 * sy,
      )
      ..lineTo(138.906 * sx, 667.328 * sy)
      ..cubicTo(
        130.695 * sx,
        658.38 * sy,
        126.139 * sx,
        646.678 * sy,
        126.139 * sx,
        634.534 * sy,
      )
      ..lineTo(126.139 * sx, 444.136 * sy);
  } else {
    path
      ..lineTo(183.5 * sx, 812.423 * sy)
      ..cubicTo(
        183.5 * sx,
        798.94 * sy,
        178.211 * sx,
        785.994 * sy,
        168.771 * sx,
        776.367 * sy,
      )
      ..lineTo(140.009 * sx, 747.033 * sy)
      ..cubicTo(
        131.119 * sx,
        737.966 * sy,
        126.139 * sx,
        725.775 * sy,
        126.139 * sx,
        713.077 * sy,
      )
      ..lineTo(126.139 * sx, 444.136 * sy);
  }

  path
    ..cubicTo(
      126.139 * sx,
      430.462 * sy,
      131.911 * sx,
      417.423 * sy,
      142.035 * sx,
      408.23 * sy,
    )
    ..lineTo(147.619 * sx, 403.16 * sy)
    ..cubicTo(
      158.369 * sx,
      393.398 * sy,
      164.5 * sx,
      379.552 * sy,
      164.5 * sx,
      365.032 * sy,
    )
    ..lineTo(164.5 * sx, 258.541 * sy);
}

Rect svgCardUsernameNotchBoundsForTesting({
  required int usernameCharCount,
  Size size = const Size(_svgCardBaseWidth, _svgCardBaseHeight),
}) {
  final double sx = size.width / _svgCardBaseWidth;
  final double sy = size.height / _svgCardBaseHeight;
  final _UsernameNotchVariant variant =
      _usernameVariantForCount(usernameCharCount);
  return Rect.fromLTWH(
    121 * sx,
    variant.placeholderTop * sy,
    55 * sx,
    variant.placeholderHeight * sy,
  );
}

Rect svgCardMetaNotchBoundsForTesting({
  required SvgCardMetaSize metaSize,
  Size size = const Size(_svgCardBaseWidth, _svgCardBaseHeight),
}) {
  final double sx = size.width / _svgCardBaseWidth;
  final double sy = size.height / _svgCardBaseHeight;
  final _MetaNotchVariant variant = _metaVariantForSize(metaSize);
  return Rect.fromLTWH(
    variant.placeholderLeft * sx,
    136 * sy,
    variant.placeholderWidth * sx,
    55 * sy,
  );
}

Rect svgCardMetaTextBoundsForTesting({
  required SvgCardMetaSize metaSize,
  Size size = const Size(_svgCardBaseWidth, _svgCardBaseHeight),
}) {
  final double sx = size.width / _svgCardBaseWidth;
  final double sy = size.height / _svgCardBaseHeight;
  final _MetaNotchVariant variant = _metaVariantForSize(metaSize);
  return Rect.fromLTWH(
    (variant.placeholderLeft + _kMetaTextLeftInsetBase) * sx,
    148 * sy,
    (variant.placeholderWidth - _kMetaTextLeftInsetBase) * sx,
    55 * sy,
  );
}

Path _buildOuterCardPath(Size size, {required bool twoLineTitle}) {
  final double sx = size.width / _svgCardBaseWidth;
  final double sy = size.height / _svgCardBaseHeight;
  final double titleExpansion = twoLineTitle ? _kTwoLineTitleExpansion : 0;

  return Path()
    ..moveTo(200.355 * sx, 110.645 * sy)
    ..lineTo(114.645 * sx, 196.355 * sy)
    ..cubicTo(
      105.268 * sx,
      205.732 * sy,
      100 * sx,
      218.45 * sy,
      100 * sx,
      231.711 * sy,
    )
    ..lineTo(100 * sx, (1175.29 + titleExpansion) * sy)
    ..cubicTo(
      100 * sx,
      (1188.55 + titleExpansion) * sy,
      105.268 * sx,
      (1201.27 + titleExpansion) * sy,
      114.645 * sx,
      (1210.65 + titleExpansion) * sy,
    )
    ..lineTo(197.628 * sx, (1293.63 + titleExpansion) * sy)
    ..cubicTo(
      208.584 * sx,
      (1304.59 + titleExpansion) * sy,
      224 * sx,
      (1309.84 + titleExpansion) * sy,
      239.367 * sx,
      (1307.87 + titleExpansion) * sy,
    )
    ..lineTo(520.328 * sx, (1271.7 + titleExpansion) * sy)
    ..cubicTo(
      528.96 * sx,
      (1270.59 + titleExpansion) * sy,
      537.152 * sx,
      (1267.24 + titleExpansion) * sy,
      544.095 * sx,
      (1261.99 + titleExpansion) * sy,
    )
    ..lineTo(584.846 * sx, (1231.19 + titleExpansion) * sy)
    ..cubicTo(
      592.769 * sx,
      (1225.2 + titleExpansion) * sy,
      602.296 * sx,
      (1221.71 + titleExpansion) * sy,
      612.212 * sx,
      (1221.15 + titleExpansion) * sy,
    )
    ..lineTo(1617.93 * sx, (1165.07 + titleExpansion) * sy)
    ..cubicTo(
      1630.21 * sx,
      (1164.38 + titleExpansion) * sy,
      1641.81 * sx,
      (1159.19 + titleExpansion) * sy,
      1650.5 * sx,
      (1150.5 + titleExpansion) * sy,
    )
    ..lineTo(1737.36 * sx, (1063.65 + titleExpansion) * sy)
    ..cubicTo(
      1746.73 * sx,
      (1054.27 + titleExpansion) * sy,
      1752 * sx,
      (1041.55 + titleExpansion) * sy,
      1752 * sx,
      (1028.29 + titleExpansion) * sy,
    )
    ..lineTo(1752 * sx, 231.711 * sy)
    ..cubicTo(
      1752 * sx,
      218.45 * sy,
      1746.73 * sx,
      205.732 * sy,
      1737.36 * sx,
      196.355 * sy,
    )
    ..lineTo(1651.64 * sx, 110.645 * sy)
    ..cubicTo(
      1642.27 * sx,
      101.268 * sy,
      1629.55 * sx,
      96 * sy,
      1616.29 * sx,
      96 * sy,
    )
    ..lineTo(235.711 * sx, 96 * sy)
    ..cubicTo(
      222.45 * sx,
      96 * sy,
      209.732 * sx,
      101.268 * sy,
      200.355 * sx,
      110.645 * sy,
    )
    ..close();
}

class _SvgOuterClipper extends CustomClipper<Path> {
  const _SvgOuterClipper({required this.twoLineTitle});

  final bool twoLineTitle;

  @override
  Path getClip(Size size) {
    return _buildOuterCardPath(size, twoLineTitle: twoLineTitle);
  }

  @override
  bool shouldReclip(covariant _SvgOuterClipper oldClipper) {
    return oldClipper.twoLineTitle != twoLineTitle;
  }
}

class SvgCardMenuAction {
  const SvgCardMenuAction({
    required this.value,
    required this.label,
    this.enabled = true,
    this.isDivider = false,
  });

  const SvgCardMenuAction.divider()
      : value = '',
        label = '',
        enabled = false,
        isDivider = true;

  final String value;
  final String label;
  final bool enabled;
  final bool isDivider;
}

class SvgCardClipper extends CustomClipper<Path> {
  const SvgCardClipper({
    this.usernameCharCount = 6,
    this.metaSize = SvgCardMetaSize.small,
    this.twoLineTitle = false,
  });

  final int usernameCharCount;
  final SvgCardMetaSize metaSize;
  final bool twoLineTitle;

  @override
  Path getClip(Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;

    final _UsernameNotchVariant usernameVariant =
        _usernameVariantForCount(usernameCharCount);
    final _MetaNotchVariant metaVariant = _metaVariantForSize(metaSize);

    const double titleSpaceBottom = 1037.5;

    final Path p = Path()
      ..moveTo(447.921 * sx, 127.698 * sy)
      ..lineTo(metaVariant.shelfStart * sx, 127.698 * sy)
      ..cubicTo(
        metaVariant.shelfControl1 * sx,
        127.698 * sy,
        metaVariant.shelfControl2 * sx,
        131.329 * sy,
        metaVariant.shelfEnd * sx,
        138.011 * sy,
      )
      ..lineTo(metaVariant.tabStart * sx, 204.051 * sy)
      ..cubicTo(
        metaVariant.tabControl1 * sx,
        211.147 * sy,
        metaVariant.tabControl2 * sx,
        215.002 * sy,
        metaVariant.tabEnd * sx,
        215.002 * sy,
      )
      ..lineTo(1596.33 * sx, 215.002 * sy)
      ..cubicTo(
        1606.83 * sx,
        215.002 * sy,
        1617.04 * sx,
        218.406 * sy,
        1625.43 * sx,
        224.703 * sy,
      )
      ..lineTo(1706.1 * sx, 285.203 * sy)
      ..cubicTo(
        1718.31 * sx,
        294.362 * sy,
        1725.5 * sx,
        308.737 * sy,
        1725.5 * sx,
        324.002 * sy,
      )
      ..lineTo(1725.5 * sx, 716.479 * sy)
      ..cubicTo(
        1725.5 * sx,
        726.588 * sy,
        1722.34 * sx,
        736.444 * sy,
        1716.47 * sx,
        744.669 * sy,
      )
      ..lineTo(1695.09 * sx, 774.592 * sy)
      ..cubicTo(
        1688.85 * sx,
        783.327 * sy,
        1685.5 * sx,
        793.792 * sy,
        1685.5 * sx,
        804.526 * sy,
      )
      ..lineTo(1685.5 * sx, 898.062 * sy)
      ..cubicTo(
        1685.5 * sx,
        910.77 * sy,
        1680.51 * sx,
        922.97 * sy,
        1671.61 * sx,
        932.039 * sy,
      )
      ..lineTo(1620.13 * sx, 984.479 * sy)
      ..cubicTo(
        1611.01 * sx,
        993.769 * sy,
        1598.54 * sx,
        999.002 * sy,
        1585.52 * sx,
        999.002 * sy,
      )
      ..lineTo(1487.58 * sx, 999.002 * sy)
      ..cubicTo(
        1477.45 * sx,
        999.002 * sy,
        1467.54 * sx,
        1001.99 * sy,
        1459.1 * sx,
        1007.6 * sy,
      )
      ..lineTo(1426.24 * sx, titleSpaceBottom * sy)
      ..cubicTo(
        1418.29 * sx,
        (titleSpaceBottom + 5.28) * sy,
        1408.96 * sx,
        (titleSpaceBottom + 8.1) * sy,
        1399.42 * sx,
        (titleSpaceBottom + 8.1) * sy,
      )
      ..lineTo(305.735 * sx, (titleSpaceBottom + 8.1) * sy)
      ..cubicTo(
        286.528 * sx,
        (titleSpaceBottom + 8.1) * sy,
        272.82 * sx,
        (titleSpaceBottom - 10.51) * sy,
        278.519 * sx,
        (titleSpaceBottom - 28.85) * sy,
      )
      ..lineTo(287.668 * sx, (titleSpaceBottom - 58.3) * sy)
      ..cubicTo(
        294.281 * sx,
        (titleSpaceBottom - 79.59) * sy,
        286.45 * sx,
        (titleSpaceBottom - 102.71) * sy,
        268.265 * sx,
        (titleSpaceBottom - 115.6) * sy,
      )
      ..lineTo(191.303 * sx, usernameVariant.sideBottom * sy)
      ..cubicTo(
        186.409 * sx,
        855.789 * sy,
        183.5 * sx,
        850.162 * sy,
        183.5 * sx,
        844.164 * sy,
      );
    _appendLeftUsernameSegment(p, sx, sy, usernameVariant);
    p
      ..cubicTo(
        164.5 * sx,
        245.511 * sy,
        169.742 * sx,
        233.028 * sy,
        179.047 * sx,
        223.907 * sy,
      )
      ..lineTo(223.968 * sx, 179.87 * sy)
      ..cubicTo(
        233.034 * sx,
        170.982 * sy,
        245.225 * sx,
        166.002 * sy,
        257.921 * sx,
        166.002 * sy,
      )
      ..lineTo(368.579 * sx, 166.002 * sy)
      ..cubicTo(
        382.669 * sx,
        166.002 * sy,
        396.144 * sx,
        160.23 * sy,
        405.863 * sx,
        150.03 * sy,
      )
      ..lineTo(412.809 * sx, 142.74 * sy)
      ..cubicTo(
        421.962 * sx,
        133.134 * sy,
        434.652 * sx,
        127.698 * sy,
        447.921 * sx,
        127.698 * sy,
      )
      ..close();

    return p;
  }

  @override
  bool shouldReclip(covariant SvgCardClipper oldClipper) {
    return oldClipper.usernameCharCount != usernameCharCount ||
        oldClipper.metaSize != metaSize ||
        oldClipper.twoLineTitle != twoLineTitle;
  }
}

class SvgCardShadowPainter extends CustomPainter {
  const SvgCardShadowPainter({
    required this.usernameCharCount,
    required this.metaSize,
    required this.twoLineTitle,
  });

  final int usernameCharCount;
  final SvgCardMetaSize metaSize;
  final bool twoLineTitle;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;
    final double scale = ((sx + sy) / 2).clamp(0.05, 4.0).toDouble();

    final Path outer = _buildOuterPath(size);
    final Path inner = SvgCardClipper(
      usernameCharCount: usernameCharCount,
      metaSize: metaSize,
      twoLineTitle: twoLineTitle,
    ).getClip(size);

    canvas.drawShadow(
      outer,
      Colors.black.withValues(alpha: 0.6),
      42 * scale,
      true,
    );

    final Paint shellPaint = Paint()..color = _kShellColor;
    canvas.drawPath(outer, shellPaint);

    final Paint innerFill = Paint()..color = _kInnerColor;
    canvas.drawPath(inner, innerFill);
  }

  Path _buildOuterPath(Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;
    final double titleExpansion = twoLineTitle ? _kTwoLineTitleExpansion : 0;

    return Path()
      ..moveTo(200.355 * sx, 110.645 * sy)
      ..lineTo(114.645 * sx, 196.355 * sy)
      ..cubicTo(
        105.268 * sx,
        205.732 * sy,
        100 * sx,
        218.45 * sy,
        100 * sx,
        231.711 * sy,
      )
      ..lineTo(100 * sx, (1175.29 + titleExpansion) * sy)
      ..cubicTo(
        100 * sx,
        (1188.55 + titleExpansion) * sy,
        105.268 * sx,
        (1201.27 + titleExpansion) * sy,
        114.645 * sx,
        (1210.65 + titleExpansion) * sy,
      )
      ..lineTo(197.628 * sx, (1293.63 + titleExpansion) * sy)
      ..cubicTo(
        208.584 * sx,
        (1304.59 + titleExpansion) * sy,
        224 * sx,
        (1309.84 + titleExpansion) * sy,
        239.367 * sx,
        (1307.87 + titleExpansion) * sy,
      )
      ..lineTo(520.328 * sx, (1271.7 + titleExpansion) * sy)
      ..cubicTo(
        528.96 * sx,
        (1270.59 + titleExpansion) * sy,
        537.152 * sx,
        (1267.24 + titleExpansion) * sy,
        544.095 * sx,
        (1261.99 + titleExpansion) * sy,
      )
      ..lineTo(584.846 * sx, (1231.19 + titleExpansion) * sy)
      ..cubicTo(
        592.769 * sx,
        (1225.2 + titleExpansion) * sy,
        602.296 * sx,
        (1221.71 + titleExpansion) * sy,
        612.212 * sx,
        (1221.15 + titleExpansion) * sy,
      )
      ..lineTo(1617.93 * sx, (1165.07 + titleExpansion) * sy)
      ..cubicTo(
        1630.21 * sx,
        (1164.38 + titleExpansion) * sy,
        1641.81 * sx,
        (1159.19 + titleExpansion) * sy,
        1650.5 * sx,
        (1150.5 + titleExpansion) * sy,
      )
      ..lineTo(1737.36 * sx, (1063.65 + titleExpansion) * sy)
      ..cubicTo(
        1746.73 * sx,
        (1054.27 + titleExpansion) * sy,
        1752 * sx,
        (1041.55 + titleExpansion) * sy,
        1752 * sx,
        (1028.29 + titleExpansion) * sy,
      )
      ..lineTo(1752 * sx, 231.711 * sy)
      ..cubicTo(
        1752 * sx,
        218.45 * sy,
        1746.73 * sx,
        205.732 * sy,
        1737.36 * sx,
        196.355 * sy,
      )
      ..lineTo(1651.64 * sx, 110.645 * sy)
      ..cubicTo(
        1642.27 * sx,
        101.268 * sy,
        1629.55 * sx,
        96 * sy,
        1616.29 * sx,
        96 * sy,
      )
      ..lineTo(235.711 * sx, 96 * sy)
      ..cubicTo(
        222.45 * sx,
        96 * sy,
        209.732 * sx,
        101.268 * sy,
        200.355 * sx,
        110.645 * sy,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant SvgCardShadowPainter oldDelegate) {
    return oldDelegate.usernameCharCount != usernameCharCount ||
        oldDelegate.metaSize != metaSize ||
        oldDelegate.twoLineTitle != twoLineTitle;
  }
}

class SvgCardForegroundPainter extends CustomPainter {
  const SvgCardForegroundPainter({
    required this.accentColor,
    required this.usernameCharCount,
    required this.metaSize,
    required this.twoLineTitle,
  });

  final Color accentColor;
  final int usernameCharCount;
  final SvgCardMetaSize metaSize;
  final bool twoLineTitle;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = ((size.width / _svgCardBaseWidth) +
            (size.height / _svgCardBaseHeight)) /
        2;
    final double clampedScale = scale.clamp(0.05, 4.0).toDouble();
    final Path inner = SvgCardClipper(
      usernameCharCount: usernameCharCount,
      metaSize: metaSize,
      twoLineTitle: twoLineTitle,
    ).getClip(size);

    _paintAccentCorners(canvas, size, accentColor, clampedScale);
    _paintBottomBadge(canvas, size, accentColor, clampedScale);

    final Paint innerStroke = Paint()
      ..color = _kStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * clampedScale;
    canvas.drawPath(inner, innerStroke);
  }

  void _paintAccentCorners(
    Canvas canvas,
    Size size,
    Color accent,
    double scale,
  ) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15 * scale
      ..color = accent.withValues(alpha: 0.92)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15 * scale
      ..color = accent;

    final Path topLeft = Path()
      ..moveTo(127 * sx, 380 * sy)
      ..lineTo(127 * sx, 249.853 * sy)
      ..cubicTo(
        127 * sx,
        236.887 * sy,
        132.037 * sx,
        224.427 * sy,
        141.049 * sx,
        215.104 * sy,
      )
      ..lineTo(209.535 * sx, 144.25 * sy)
      ..cubicTo(
        218.956 * sx,
        134.504 * sy,
        231.931 * sx,
        129 * sy,
        245.486 * sx,
        129 * sy,
      )
      ..lineTo(374 * sx, 129 * sy);

    final Path bottomRight = Path()
      ..moveTo(1723 * sx, 785 * sy)
      ..lineTo(1723 * sx, 914.458 * sy)
      ..cubicTo(
        1723 * sx,
        927.653 * sy,
        1717.78 * sx,
        940.313 * sy,
        1708.49 * sx,
        949.679 * sy,
      )
      ..lineTo(1637.67 * sx, 1021.04 * sy)
      ..cubicTo(
        1628.28 * sx,
        1030.5 * sy,
        1615.5 * sx,
        1035.82 * sy,
        1602.18 * sx,
        1035.82 * sy,
      )
      ..lineTo(1473 * sx, 1035.82 * sy);

    canvas.drawPath(topLeft, glow);
    canvas.drawPath(bottomRight, glow);
    canvas.drawPath(topLeft, stroke);
    canvas.drawPath(bottomRight, stroke);
  }

  void _paintBottomBadge(
    Canvas canvas,
    Size size,
    Color accent,
    double scale,
  ) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;
    final double yOffset = (twoLineTitle ? _kTwoLineTitleExpansion : 0) * sy;

    final Path badge = Path()
      ..moveTo(213.906 * sx, 1260.91 * sy)
      ..lineTo(131.966 * sx, 1178.97 * sy)
      ..cubicTo(
        121.861 * sx,
        1168.86 * sy,
        130.271 * sx,
        1151.69 * sy,
        144.449 * sx,
        1153.48 * sy,
      )
      ..lineTo(548.535 * sx, 1204.42 * sy)
      ..cubicTo(
        557.445 * sx,
        1205.54 * sy,
        560.473 * sx,
        1216.93 * sy,
        553.298 * sx,
        1222.33 * sy,
      )
      ..lineTo(526.668 * sx, 1242.37 * sy)
      ..cubicTo(
        525.248 * sx,
        1243.44 * sy,
        523.57 * sx,
        1244.11 * sy,
        521.805 * sx,
        1244.31 * sy,
      )
      ..lineTo(255.015 * sx, 1275.22 * sy)
      ..cubicTo(
        239.845 * sx,
        1276.98 * sy,
        224.704 * sx,
        1271.71 * sy,
        213.906 * sx,
        1260.91 * sy,
      )
      ..close();
    final Path shiftedBadge =
        yOffset == 0 ? badge : badge.shift(Offset(0, yOffset));

    final Rect bounds = shiftedBadge.getBounds();
    final Paint fill = Paint()
      ..shader = LinearGradient(
        colors: <Color>[accent, _deriveAccentGradientEnd(accent)],
      ).createShader(bounds);

    final Paint glow = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 * scale);

    canvas.drawPath(shiftedBadge, glow);
    canvas.drawPath(shiftedBadge, fill);
  }

  @override
  bool shouldRepaint(covariant SvgCardForegroundPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.usernameCharCount != usernameCharCount ||
        oldDelegate.metaSize != metaSize ||
        oldDelegate.twoLineTitle != twoLineTitle;
  }
}

class SvgCardShell extends StatelessWidget {
  const SvgCardShell({
    super.key,
    required this.child,
    this.baseColor = const Color(0x00000000),
    this.avatarImage,
    this.avatarFallbackColor = const Color(0xFF8E8E8E),
    this.topRightOverlay,
    this.topRightOverlayBuilder,
    this.accentColor = const Color(0xFFFD4687),
    this.title,
    this.metaText,
    this.metaSize,
    this.verticalUsername,
    this.priceLabel,
    this.collectionCountLabel,
    this.showCollectionCount = false,
    this.isVerified = false,
    this.onAvatarTap,
    this.onMenuTap,
    this.onMenuSelected,
    this.menuItems = const <SvgCardMenuAction>[],
  });

  final Widget child;
  final Color baseColor;
  final ImageProvider? avatarImage;
  final Color avatarFallbackColor;
  final Widget? topRightOverlay;
  final Widget Function(BuildContext context, Size size)?
      topRightOverlayBuilder;

  final Color accentColor;
  final String? title;
  final String? metaText;
  final SvgCardMetaSize? metaSize;
  final String? verticalUsername;
  final String? priceLabel;
  final String? collectionCountLabel;
  final bool showCollectionCount;
  final bool isVerified;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMenuTap;
  final ValueChanged<String>? onMenuSelected;
  final List<SvgCardMenuAction> menuItems;

  @override
  Widget build(BuildContext context) {
    final String resolvedTitle = (title ?? '').trim();
    final String resolvedMeta = (metaText ?? '').trim();
    final String resolvedHandle =
        (verticalUsername ?? '').trim().replaceAll('@', '');
    final int usernameChars = resolvedHandle.isEmpty
        ? 2
        : resolvedHandle.split('').length.clamp(2, 6).toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double sx = size.width / _svgCardBaseWidth;
        final double sy = size.height / _svgCardBaseHeight;
        final double scale = ((sx + sy) / 2).clamp(0.05, 4.0).toDouble();

        final SvgCardMetaSize resolvedMetaSize =
            metaSize ?? svgCardMetaSizeForText(context, resolvedMeta);
        final bool twoLineTitle = _isTwoLineTitle(
          context,
          resolvedTitle,
          maxWidthBase: 1504,
          fontScale: scale,
        );

        final SvgCardClipper innerClipper = SvgCardClipper(
          usernameCharCount: usernameChars,
          metaSize: resolvedMetaSize,
          twoLineTitle: twoLineTitle,
        );

        final Widget? resolvedTopRightOverlay =
            topRightOverlayBuilder?.call(context, size) ?? topRightOverlay;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SvgCardShadowPainter(
                  usernameCharCount: usernameChars,
                  metaSize: resolvedMetaSize,
                  twoLineTitle: twoLineTitle,
                ),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: _SvgOuterClipper(twoLineTitle: twoLineTitle),
                child: ValueListenableBuilder<AppearanceSettings>(
                  valueListenable: AppearanceSettingsService.instance.settings,
                  builder: (context, settings, _) {
                    final double sigma = settings.svgCardBlurSigma;
                    return BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: const ColoredBox(
                        color: Color(0x012A2A2A),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: innerClipper,
                child: ((baseColor.a * 255.0).round().clamp(0, 255) == 0)
                    ? const SizedBox.expand()
                    : ColoredBox(color: baseColor),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: innerClipper,
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SvgCardForegroundPainter(
                  accentColor: accentColor,
                  usernameCharCount: usernameChars,
                  metaSize: resolvedMetaSize,
                  twoLineTitle: twoLineTitle,
                ),
              ),
            ),
            Positioned.fill(
              child: _CardTextOverlay(
                title: resolvedTitle,
                metaText: resolvedMeta,
                verticalUsername: resolvedHandle,
                usernameCharCount: usernameChars,
                priceLabel: (priceLabel ?? '').trim(),
                collectionCountLabel: (collectionCountLabel ?? '').trim(),
                showCollectionCount: showCollectionCount,
                metaSize: resolvedMetaSize,
                twoLineTitle: twoLineTitle,
              ),
            ),
            Positioned.fill(
              child: _AvatarAndMenuOverlay(
                avatarImage: avatarImage,
                avatarFallbackColor: avatarFallbackColor,
                isVerified: isVerified,
                twoLineTitle: twoLineTitle,
                onAvatarTap: onAvatarTap,
                onMenuTap: onMenuTap,
                menuItems: menuItems,
                onMenuSelected: onMenuSelected,
              ),
            ),
            if (resolvedTopRightOverlay != null)
              Positioned.fill(child: resolvedTopRightOverlay),
          ],
        );
      },
    );
  }

  bool _isTwoLineTitle(
    BuildContext context,
    String text, {
    required double maxWidthBase,
    required double fontScale,
  }) {
    if (text.isEmpty) return false;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w400,
          fontSize: 60 * fontScale,
          height: 1.0,
        ),
      ),
      maxLines: 2,
      textDirection: Directionality.of(context),
      ellipsis: '...',
    )..layout(maxWidth: maxWidthBase * fontScale);
    return painter.computeLineMetrics().length > 1;
  }
}

class _CardTextOverlay extends StatelessWidget {
  const _CardTextOverlay({
    required this.title,
    required this.metaText,
    required this.verticalUsername,
    required this.usernameCharCount,
    required this.priceLabel,
    required this.collectionCountLabel,
    required this.showCollectionCount,
    required this.metaSize,
    required this.twoLineTitle,
  });

  final String title;
  final String metaText;
  final String verticalUsername;
  final int usernameCharCount;
  final String priceLabel;
  final String collectionCountLabel;
  final bool showCollectionCount;
  final SvgCardMetaSize metaSize;
  final bool twoLineTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double sx = size.width / _svgCardBaseWidth;
        final double sy = size.height / _svgCardBaseHeight;
        final double scale = ((sx + sy) / 2).clamp(0.05, 4.0).toDouble();
        final double titleShift = twoLineTitle ? _kTwoLineTitleExpansion : 0;
        final _MetaNotchVariant metaVariant = _metaVariantForSize(metaSize);
        final Rect usernameBounds = svgCardUsernameNotchBoundsForTesting(
          usernameCharCount: usernameCharCount,
        );

        final List<String> chars =
            verticalUsername.trim().toUpperCase().split('').take(6).toList();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 135 * sx,
              top: twoLineTitle ? 1088 * sy : 1088 * sy,
              width: 1504 * sx,
              height: (twoLineTitle ? 120 : 60) * sy,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    fontSize: 60 * scale,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              left:
                  (metaVariant.placeholderLeft + _kMetaTextLeftInsetBase) * sx,
              top: 148 * sy,
              width:
                  (metaVariant.placeholderWidth - _kMetaTextLeftInsetBase) * sx,
              height: 55 * sy,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metaText,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.inter(
                      color: _kMetaColor,
                      fontWeight: FontWeight.w400,
                      fontSize: 55 * scale,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: usernameBounds.left * sx,
              top: usernameBounds.top * sy,
              width: usernameBounds.width * sx,
              height: usernameBounds.height * sy,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  chars.isEmpty ? '' : chars.join('\n'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 55 * scale,
                    fontWeight: FontWeight.w400,
                    height: 1.02,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 202 * sx,
              top: (1179 + titleShift) * sy,
              width: 246 * sx,
              height: 96 * sy,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  priceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 96 * scale,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            if (showCollectionCount)
              Positioned(
                left: 1475 * sx,
                top: 853 * sy,
                width: 180 * sx,
                height: 128 * sy,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    collectionCountLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                      fontSize: 64 * scale,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AvatarAndMenuOverlay extends StatelessWidget {
  const _AvatarAndMenuOverlay({
    required this.avatarImage,
    required this.avatarFallbackColor,
    required this.isVerified,
    required this.twoLineTitle,
    required this.onAvatarTap,
    required this.onMenuTap,
    required this.menuItems,
    required this.onMenuSelected,
  });

  final ImageProvider? avatarImage;
  final Color avatarFallbackColor;
  final bool isVerified;
  final bool twoLineTitle;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMenuTap;
  final List<SvgCardMenuAction> menuItems;
  final ValueChanged<String>? onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double sx = constraints.maxWidth / _svgCardBaseWidth;
        final double sy = constraints.maxHeight / _svgCardBaseHeight;
        final double titleShift = twoLineTitle ? _kTwoLineTitleExpansion : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 127 * sx,
              top: 916 * sy,
              width: 134 * sx,
              height: 134 * sy,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAvatarTap,
                  customBorder: _AvatarBorder(isVerified: isVerified),
                  child: CustomPaint(
                    foregroundPainter:
                        _AvatarStrokePainter(isVerified: isVerified),
                    child: ClipPath(
                      clipper: _AvatarClipper(isVerified: isVerified),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: avatarFallbackColor,
                          image: avatarImage == null
                              ? null
                              : DecorationImage(
                                  image: avatarImage!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: avatarImage == null
                            ? const Center(
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isVerified)
              Positioned(
                left: 220 * sx,
                top: 1026 * sy,
                width: 39 * sx,
                height: 39 * sy,
                child: CustomPaint(painter: _VerifiedBadgePainter()),
              ),
            Positioned(
              left: 1653 * sx,
              top: (1018 + titleShift) * sy,
              width: 82 * sx,
              height: 72 * sy,
              child: _DiagonalMenuButton(
                onTap: () {
                  onMenuTap?.call();
                  if (menuItems.isNotEmpty && onMenuSelected != null) {
                    _openMenu(context);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null) return;
    final Offset topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final double anchorX = topLeft.dx + (box.size.width * 0.84);
    final double anchorY = topLeft.dy + (box.size.height * 0.84);
    final RelativeRect position = RelativeRect.fromLTRB(
      anchorX,
      anchorY,
      overlay.size.width - anchorX,
      overlay.size.height - anchorY,
    );
    final String? selected = await showMenu<String>(
      context: context,
      position: position,
      items: menuItems
          .where((e) => !e.isDivider)
          .map(
            (e) => PopupMenuItem<String>(
              value: e.value,
              enabled: e.enabled,
              child: Text(e.label),
            ),
          )
          .toList(),
    );
    if (selected != null) {
      onMenuSelected?.call(selected);
    }
  }
}

class _DiagonalMenuButton extends StatelessWidget {
  const _DiagonalMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 82,
          height: 72,
          child: CustomPaint(
            painter: _DiagonalDotsPainter(),
          ),
        ),
      ),
    );
  }
}

class _DiagonalDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint bright = Paint()..color = const Color(0xFFEFEFEF);
    final Paint dim = Paint()..color = const Color(0x80EFEFEF);

    final List<Offset> points = <Offset>[
      Offset(size.width * 0.125, size.height * 0.836),
      Offset(size.width * 0.734, size.height * 0.142),
      Offset(size.width * 0.430, size.height * 0.489),
    ];
    final double radius = size.shortestSide * 0.115;

    canvas.drawCircle(points[0], radius, bright);
    canvas.drawCircle(points[1], radius, bright);
    canvas.drawCircle(points[2], radius, dim);
  }

  @override
  bool shouldRepaint(covariant _DiagonalDotsPainter oldDelegate) => false;
}

class _AvatarClipper extends CustomClipper<Path> {
  const _AvatarClipper({required this.isVerified});

  final bool isVerified;

  @override
  Path getClip(Size size) {
    double vx(double x) => (x - 127) / 134 * size.width;
    double vy(double y) => (y - 916) / 134 * size.height;
    double ux(double x) => (x - 1919) / 134 * size.width;
    double uy(double y) => (y - 917) / 134 * size.height;

    if (isVerified) {
      return Path()
        ..moveTo(vx(166.291), vy(928.629))
        ..cubicTo(
          vx(182.589),
          vy(916.788),
          vx(204.657),
          vy(916.788),
          vx(220.955),
          vy(928.629),
        )
        ..lineTo(vx(239.384), vy(942.018))
        ..cubicTo(
          vx(255.681),
          vy(953.859),
          vx(262.501),
          vy(974.848),
          vx(256.275),
          vy(994.007),
        )
        ..lineTo(vx(252.728), vy(1004.92))
        ..cubicTo(
          vx(249.876),
          vy(1012.25),
          vx(243.019),
          vy(1017.24),
          vx(235.171),
          vy(1017.71),
        )
        ..lineTo(vx(227.633), vy(1018.16))
        ..cubicTo(
          vx(220.223),
          vy(1018.6),
          vx(214.188),
          vy(1024.28),
          vx(213.292),
          vy(1031.65),
        )
        ..cubicTo(
          vx(212.171),
          vy(1040.87),
          vx(204.344),
          vy(1047.8),
          vx(195.057),
          vy(1047.8),
        )
        ..lineTo(vx(182.233), vy(1047.8))
        ..cubicTo(
          vx(164.089),
          vy(1047.8),
          vx(146.235),
          vy(1034.83),
          vx(140.01),
          vy(1015.67),
        )
        ..lineTo(vx(132.971), vy(994.007))
        ..cubicTo(
          vx(126.746),
          vy(974.848),
          vx(133.565),
          vy(953.859),
          vx(149.862),
          vy(942.018),
        )
        ..lineTo(vx(166.291), vy(928.629))
        ..close();
    }

    return Path()
      ..moveTo(ux(1958.29), uy(929.629))
      ..cubicTo(
        ux(1974.59),
        uy(917.788),
        ux(1996.66),
        uy(917.788),
        ux(2012.96),
        uy(929.629),
      )
      ..lineTo(ux(2030.87), uy(942.646))
      ..cubicTo(
        ux(2047.42),
        uy(954.671),
        ux(2054.17),
        uy(976.103),
        ux(2047.49),
        uy(995.441),
      )
      ..lineTo(ux(2039.88), uy(1017.48))
      ..cubicTo(
        ux(2033.41),
        uy(1036.22),
        ux(2015.76),
        uy(1048.8),
        ux(1995.93),
        uy(1048.8),
      )
      ..lineTo(ux(1974.23), uy(1048.8))
      ..cubicTo(
        ux(1954.09),
        uy(1048.8),
        ux(1936.23),
        uy(1035.83),
        ux(1930.01),
        uy(1016.67),
      )
      ..lineTo(ux(1922.97), uy(995.007))
      ..cubicTo(
        ux(1916.75),
        uy(975.848),
        ux(1923.56),
        uy(954.859),
        ux(1939.86),
        uy(943.018),
      )
      ..lineTo(ux(1958.29), uy(929.629))
      ..close();
  }

  @override
  bool shouldReclip(covariant _AvatarClipper oldClipper) {
    return oldClipper.isVerified != isVerified;
  }
}

class _AvatarStrokePainter extends CustomPainter {
  const _AvatarStrokePainter({required this.isVerified});

  final bool isVerified;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = ((size.width / 134) + (size.height / 134)) / 2;
    final Paint stroke = Paint()
      ..color = _kStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3 * scale.clamp(0.2, 8.0).toDouble();
    canvas.drawPath(
        _AvatarClipper(isVerified: isVerified).getClip(size), stroke);
  }

  @override
  bool shouldRepaint(covariant _AvatarStrokePainter oldDelegate) {
    return oldDelegate.isVerified != isVerified;
  }
}

class _VerifiedBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double x(double value) => (value - 220) / 39 * size.width;
    double y(double value) => (value - 1026) / 39 * size.height;
    final double scale = ((size.width / 39) + (size.height / 39)) / 2;

    final Path badge = Path()
      ..moveTo(x(234.805), y(1028.34))
      ..cubicTo(x(235.998), y(1027.33), x(236.595), y(1026.82), x(237.217),
          y(1026.52))
      ..cubicTo(
          x(237.929), y(1026.18), x(238.709), y(1026), x(239.499), y(1026))
      ..cubicTo(
          x(240.289), y(1026), x(241.069), y(1026.18), x(241.781), y(1026.52))
      ..cubicTo(x(242.405), y(1026.82), x(243.002), y(1027.32), x(244.193),
          y(1028.34))
      ..cubicTo(
          x(244.669), y(1028.75), x(244.906), y(1028.95), x(245.16), y(1029.12))
      ..cubicTo(x(245.742), y(1029.51), x(246.395), y(1029.78), x(247.082),
          y(1029.91))
      ..cubicTo(
          x(247.38), y(1029.97), x(247.691), y(1030), x(248.313), y(1030.05))
      ..cubicTo(x(249.877), y(1030.17), x(250.658), y(1030.24), x(251.309),
          y(1030.47))
      ..cubicTo(
          x(252.054), y(1030.73), x(252.73), y(1031.15), x(253.288), y(1031.71))
      ..cubicTo(x(253.847), y(1032.27), x(254.273), y(1032.95), x(254.536),
          y(1033.69))
      ..cubicTo(x(254.767), y(1034.34), x(254.828), y(1035.13), x(254.953),
          y(1036.69))
      ..cubicTo(x(255.002), y(1037.31), x(255.027), y(1037.62), x(255.086),
          y(1037.92))
      ..cubicTo(x(255.222), y(1038.61), x(255.493), y(1039.26), x(255.882),
          y(1039.84))
      ..cubicTo(x(256.051), y(1040.09), x(256.254), y(1040.33), x(256.658),
          y(1040.81))
      ..cubicTo(
          x(257.674), y(1042), x(258.184), y(1042.6), x(258.482), y(1043.22))
      ..cubicTo(x(258.823), y(1043.93), x(259), y(1044.71), x(259), y(1045.5))
      ..cubicTo(
          x(259), y(1046.29), x(258.823), y(1047.07), x(258.482), y(1047.78))
      ..cubicTo(
          x(258.186), y(1048.41), x(257.676), y(1049), x(256.658), y(1050.2))
      ..cubicTo(
          x(256.381), y(1050.5), x(256.122), y(1050.82), x(255.882), y(1051.16))
      ..cubicTo(
          x(255.492), y(1051.74), x(255.222), y(1052.4), x(255.086), y(1053.08))
      ..cubicTo(x(255.027), y(1053.38), x(255.002), y(1053.69), x(254.953),
          y(1054.32))
      ..cubicTo(x(254.828), y(1055.88), x(254.767), y(1056.66), x(254.536),
          y(1057.31))
      ..cubicTo(x(254.273), y(1058.06), x(253.847), y(1058.73), x(253.288),
          y(1059.29))
      ..cubicTo(
          x(252.73), y(1059.85), x(252.054), y(1060.27), x(251.309), y(1060.54))
      ..cubicTo(x(250.658), y(1060.77), x(249.877), y(1060.83), x(248.313),
          y(1060.95))
      ..cubicTo(
          x(247.691), y(1061), x(247.382), y(1061.03), x(247.082), y(1061.09))
      ..cubicTo(
          x(246.395), y(1061.22), x(245.742), y(1061.49), x(245.16), y(1061.88))
      ..cubicTo(x(244.824), y(1062.12), x(244.502), y(1062.38), x(244.195),
          y(1062.66))
      ..cubicTo(x(243.002), y(1063.68), x(242.405), y(1064.18), x(241.783),
          y(1064.48))
      ..cubicTo(
          x(241.071), y(1064.82), x(240.291), y(1065), x(239.501), y(1065))
      ..cubicTo(
          x(238.711), y(1065), x(237.931), y(1064.82), x(237.219), y(1064.48))
      ..cubicTo(x(236.595), y(1064.19), x(235.998), y(1063.68), x(234.807),
          y(1062.66))
      ..cubicTo(
          x(234.5), y(1062.38), x(234.177), y(1062.12), x(233.84), y(1061.88))
      ..cubicTo(x(233.258), y(1061.49), x(232.605), y(1061.22), x(231.918),
          y(1061.09))
      ..cubicTo(
          x(231.511), y(1061.02), x(231.1), y(1060.97), x(230.687), y(1060.95))
      ..cubicTo(x(229.123), y(1060.83), x(228.342), y(1060.77), x(227.691),
          y(1060.54))
      ..cubicTo(
          x(226.946), y(1060.27), x(226.27), y(1059.85), x(225.712), y(1059.29))
      ..cubicTo(x(225.153), y(1058.73), x(224.727), y(1058.06), x(224.464),
          y(1057.31))
      ..cubicTo(x(224.233), y(1056.66), x(224.172), y(1055.88), x(224.047),
          y(1054.32))
      ..cubicTo(
          x(224.027), y(1053.9), x(223.982), y(1053.49), x(223.914), y(1053.08))
      ..cubicTo(
          x(223.778), y(1052.4), x(223.508), y(1051.74), x(223.118), y(1051.16))
      ..cubicTo(
          x(222.949), y(1050.91), x(222.746), y(1050.67), x(222.342), y(1050.2))
      ..cubicTo(
          x(221.326), y(1049), x(220.816), y(1048.41), x(220.518), y(1047.78))
      ..cubicTo(x(220.177), y(1047.07), x(220), y(1046.29), x(220), y(1045.5))
      ..cubicTo(
          x(220), y(1044.71), x(220.177), y(1043.93), x(220.518), y(1043.22))
      ..cubicTo(
          x(220.816), y(1042.6), x(221.324), y(1042), x(222.342), y(1040.81))
      ..cubicTo(x(222.746), y(1040.33), x(222.949), y(1040.09), x(223.118),
          y(1039.84))
      ..cubicTo(x(223.508), y(1039.26), x(223.778), y(1038.61), x(223.914),
          y(1037.92))
      ..cubicTo(x(223.973), y(1037.62), x(223.998), y(1037.31), x(224.047),
          y(1036.69))
      ..cubicTo(x(224.172), y(1035.13), x(224.233), y(1034.34), x(224.464),
          y(1033.69))
      ..cubicTo(x(224.727), y(1032.95), x(225.154), y(1032.27), x(225.713),
          y(1031.71))
      ..cubicTo(x(226.271), y(1031.15), x(226.948), y(1030.73), x(227.693),
          y(1030.47))
      ..cubicTo(x(228.345), y(1030.24), x(229.125), y(1030.17), x(230.689),
          y(1030.05))
      ..cubicTo(
          x(231.311), y(1030), x(231.62), y(1029.97), x(231.921), y(1029.91))
      ..cubicTo(
          x(232.607), y(1029.78), x(233.26), y(1029.51), x(233.842), y(1029.12))
      ..cubicTo(x(234.096), y(1028.95), x(234.331), y(1028.75), x(234.805),
          y(1028.34))
      ..close();

    final Paint badgeStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    final Paint checkStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3 * scale;

    canvas.drawPath(badge, badgeStroke);
    canvas.drawLine(Offset(x(232.095), y(1046.56)),
        Offset(x(236.327), y(1050.79)), checkStroke);
    canvas.drawLine(Offset(x(236.327), y(1050.79)),
        Offset(x(246.907), y(1040.21)), checkStroke);
  }

  @override
  bool shouldRepaint(covariant _VerifiedBadgePainter oldDelegate) => false;
}

class _AvatarBorder extends ShapeBorder {
  const _AvatarBorder({required this.isVerified});

  final bool isVerified;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final Path local =
        _AvatarClipper(isVerified: isVerified).getClip(rect.size);
    return local.shift(rect.topLeft);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}

Color _deriveAccentGradientEnd(Color accent) {
  const Map<int, int> exact = <int, int>{
    0xFFFD4687: 0xFF972A51,
    0xFFEDB506: 0xFF876703,
    0xFF6DBA65: 0xFF31542E,
    0xFF2845E1: 0xFF16267B,
    0xFFDC1D27: 0xFF761015,
    0xFFD9D1D9: 0xFF736F73,
  };
  final int value = accent.toARGB32();
  final int? exactMatch = exact[value];
  if (exactMatch != null) {
    return Color(exactMatch);
  }
  final HSLColor hsl = HSLColor.fromColor(accent);
  final double nextLightness =
      (hsl.lightness * 0.46).clamp(0.0, 1.0).toDouble();
  return hsl.withLightness(nextLightness).toColor();
}
