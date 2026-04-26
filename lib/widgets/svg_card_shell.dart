import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const double _svgCardBaseWidth = 1852;
const double _svgCardBaseHeight = 1413;

const Color _kShellColor = Color(0x992A2A2A);
const Color _kInnerColor = Color(0xFF151515);
const Color _kStrokeColor = Color(0xFFCACACA);
const Color _kMetaColor = Color(0xFFB4B4B4);

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
    this.metaWidthFactor = 0,
    this.twoLineTitle = false,
  });

  final int usernameCharCount;
  final double metaWidthFactor;
  final bool twoLineTitle;

  @override
  Path getClip(Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;

    final int usernameCount = usernameCharCount.clamp(1, 6);
    final double collapse = (6 - usernameCount) / 5;
    final double metaFactor = metaWidthFactor.clamp(0, 1);

    final double topShelfShift = lerpDouble(0, -208, metaFactor)!;
    final double topShelfStart = 1113.25 + topShelfShift;
    final double topTabStart = 1227.5 + topShelfShift;

    final double leftTailBottom = lerpDouble(844.164, 556, collapse)!;
    final double leftTailTop = leftTailBottom - lerpDouble(40, 18, collapse)!;

    final double titleExpansion = twoLineTitle ? 64 : 0;
    final double titleSpaceBottom = 1037.5 + titleExpansion;

    final Path p = Path()
      ..moveTo(447.921 * sx, 127.698 * sy)
      ..lineTo(topShelfStart * sx, 127.698 * sy)
      ..cubicTo(
        (topShelfStart + 10.84) * sx,
        127.698 * sy,
        (topShelfStart + 21.37) * sx,
        131.329 * sy,
        (topShelfStart + 29.9) * sx,
        138.011 * sy,
      )
      ..lineTo(topTabStart * sx, 204.051 * sy)
      ..cubicTo(
        (topTabStart + 9.06) * sx,
        211.147 * sy,
        (topTabStart + 20.24) * sx,
        215.002 * sy,
        (topTabStart + 31.75) * sx,
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
      ..lineTo(191.303 * sx, leftTailBottom * sy)
      ..cubicTo(
        186.409 * sx,
        (leftTailBottom - 3.47) * sy,
        183.5 * sx,
        (leftTailBottom - 9.09) * sy,
        183.5 * sx,
        (leftTailBottom - 15.09) * sy,
      )
      ..lineTo(183.5 * sx, leftTailTop * sy)
      ..lineTo(190.514 * sx, 517.413 * sy)
      ..cubicTo(
        190.835 * sx,
        504.267 * sy,
        186.115 * sx,
        491.495 * sy,
        177.322 * sx,
        481.717 * sy,
      )
      ..lineTo(130.314 * sx, 429.443 * sy)
      ..cubicTo(
        129.146 * sx,
        428.144 * sy,
        128.5 * sx,
        426.458 * sy,
        128.5 * sx,
        424.711 * sy,
      )
      ..cubicTo(
        128.5 * sx,
        422.759 * sy,
        129.307 * sx,
        420.892 * sy,
        130.729 * sx,
        419.555 * sy,
      )
      ..lineTo(148.27 * sx, 403.071 * sy)
      ..cubicTo(
        158.626 * sx,
        393.337 * sy,
        164.5 * sx,
        379.756 * sy,
        164.5 * sx,
        365.543 * sy,
      )
      ..lineTo(164.5 * sx, 258.541 * sy)
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
        oldClipper.metaWidthFactor != metaWidthFactor ||
        oldClipper.twoLineTitle != twoLineTitle;
  }
}

class SvgCardShadowPainter extends CustomPainter {
  const SvgCardShadowPainter({
    required this.accentColor,
    required this.usernameCharCount,
    required this.metaWidthFactor,
    required this.twoLineTitle,
  });

  final Color accentColor;
  final int usernameCharCount;
  final double metaWidthFactor;
  final bool twoLineTitle;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;
    final double scale = ((sx + sy) / 2).clamp(0.05, 4.0);

    final Path outer = _buildOuterPath(size);
    final Path inner = SvgCardClipper(
      usernameCharCount: usernameCharCount,
      metaWidthFactor: metaWidthFactor,
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

    final Paint innerStroke = Paint()
      ..color = _kStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    canvas.drawPath(inner, innerStroke);

    _paintAccentCorners(canvas, size, accentColor, scale);
    _paintBottomBadge(canvas, size, accentColor, scale);
  }

  Path _buildOuterPath(Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;

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
      ..lineTo(100 * sx, 1175.29 * sy)
      ..cubicTo(
        100 * sx,
        1188.55 * sy,
        105.268 * sx,
        1201.27 * sy,
        114.645 * sx,
        1210.65 * sy,
      )
      ..lineTo(197.628 * sx, 1293.63 * sy)
      ..cubicTo(
        208.584 * sx,
        1304.59 * sy,
        224 * sx,
        1309.84 * sy,
        239.367 * sx,
        1307.87 * sy,
      )
      ..lineTo(520.328 * sx, 1271.7 * sy)
      ..cubicTo(
        528.96 * sx,
        1270.59 * sy,
        537.152 * sx,
        1267.24 * sy,
        544.095 * sx,
        1261.99 * sy,
      )
      ..lineTo(584.846 * sx, 1231.19 * sy)
      ..cubicTo(
        592.769 * sx,
        1225.2 * sy,
        602.296 * sx,
        1221.71 * sy,
        612.212 * sx,
        1221.15 * sy,
      )
      ..lineTo(1617.93 * sx, 1165.07 * sy)
      ..cubicTo(
        1630.21 * sx,
        1164.38 * sy,
        1641.81 * sx,
        1159.19 * sy,
        1650.5 * sx,
        1150.5 * sy,
      )
      ..lineTo(1737.36 * sx, 1063.65 * sy)
      ..cubicTo(
        1746.73 * sx,
        1054.27 * sy,
        1752 * sx,
        1041.55 * sy,
        1752 * sx,
        1028.29 * sy,
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

    final Rect bounds = badge.getBounds();
    final Paint fill = Paint()
      ..shader = LinearGradient(
        colors: <Color>[accent, _deriveAccentGradientEnd(accent)],
      ).createShader(bounds);

    final Paint glow = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 * scale);

    canvas.drawPath(badge, glow);
    canvas.drawPath(badge, fill);
  }

  @override
  bool shouldRepaint(covariant SvgCardShadowPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.usernameCharCount != usernameCharCount ||
        oldDelegate.metaWidthFactor != metaWidthFactor ||
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
    final String resolvedHandle = (verticalUsername ?? '').replaceAll('@', '');
    final int usernameChars = resolvedHandle.isEmpty
        ? 1
        : resolvedHandle.split('').length.clamp(1, 6).toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double sx = size.width / _svgCardBaseWidth;
        final double sy = size.height / _svgCardBaseHeight;
        final double scale = ((sx + sy) / 2).clamp(0.05, 4.0);

        final double metaWidthBase = _resolveMetaWidthBase(
          context,
          resolvedMeta,
          scale,
        );
        final double metaFactor = ((metaWidthBase - 410) / (700 - 410))
            .clamp(0.0, 1.0)
            .toDouble();
        final bool twoLineTitle = _isTwoLineTitle(
          context,
          resolvedTitle,
          maxWidthBase: 1504,
          fontScale: scale,
        );

        final SvgCardClipper innerClipper = SvgCardClipper(
          usernameCharCount: usernameChars,
          metaWidthFactor: metaFactor,
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
                  accentColor: accentColor,
                  usernameCharCount: usernameChars,
                  metaWidthFactor: metaFactor,
                  twoLineTitle: twoLineTitle,
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
              child: _CardTextOverlay(
                title: resolvedTitle,
                metaText: resolvedMeta,
                verticalUsername: resolvedHandle,
                priceLabel: (priceLabel ?? '').trim(),
                collectionCountLabel: (collectionCountLabel ?? '').trim(),
                showCollectionCount: showCollectionCount,
                twoLineTitle: twoLineTitle,
              ),
            ),
            Positioned.fill(
              child: _AvatarAndMenuOverlay(
                avatarImage: avatarImage,
                avatarFallbackColor: avatarFallbackColor,
                isVerified: isVerified,
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

  double _resolveMetaWidthBase(
    BuildContext context,
    String text,
    double scale,
  ) {
    if (text.isEmpty) return 410;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          color: _kMetaColor,
          fontWeight: FontWeight.w400,
          fontSize: 55 * scale,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: 9999);
    final double measuredBase = (painter.width / scale) + 48;
    return measuredBase.clamp(260, 700).toDouble();
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
    required this.priceLabel,
    required this.collectionCountLabel,
    required this.showCollectionCount,
    required this.twoLineTitle,
  });

  final String title;
  final String metaText;
  final String verticalUsername;
  final String priceLabel;
  final String collectionCountLabel;
  final bool showCollectionCount;
  final bool twoLineTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double sx = size.width / _svgCardBaseWidth;
        final double sy = size.height / _svgCardBaseHeight;
        final double scale = ((sx + sy) / 2).clamp(0.05, 4.0);

        final List<String> chars = verticalUsername
            .trim()
            .toUpperCase()
            .split('')
            .take(6)
            .toList();
        final int charCount = chars.isEmpty ? 1 : chars.length;
        final double blueHeight = (charCount * 65).toDouble();

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
              left: 1222 * sx,
              top: 148 * sy,
              width: 535 * sx,
              height: 55 * sy,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  metaText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _kMetaColor,
                    fontWeight: FontWeight.w400,
                    fontSize: 55 * scale,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 121 * sx,
              top: 514 * sy,
              width: 55 * sx,
              height: blueHeight * sy,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  chars.isEmpty ? '' : chars.join('\n'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.gabarito(
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
              top: 1179 * sy,
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
    required this.onAvatarTap,
    required this.onMenuTap,
    required this.menuItems,
    required this.onMenuSelected,
  });

  final ImageProvider? avatarImage;
  final Color avatarFallbackColor;
  final bool isVerified;
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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 120 * sx,
              top: 900 * sy,
              width: 150 * sx,
              height: 150 * sy,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAvatarTap,
                  customBorder: _AvatarBorder(isVerified: isVerified),
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
                        border: Border.all(color: _kStrokeColor, width: 2.2),
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
            if (isVerified)
              Positioned(
                left: 218 * sx,
                top: 1008 * sy,
                width: 40 * sx,
                height: 40 * sy,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 20 * ((sx + sy) / 2),
                  ),
                ),
              ),
            Positioned(
              right: 90 * sx,
              bottom: 120 * sy,
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
          width: 80,
          height: 80,
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
      Offset(size.width * 0.32, size.height * 0.66),
      Offset(size.width * 0.70, size.height * 0.30),
      Offset(size.width * 0.52, size.height * 0.48),
    ];

    canvas.drawCircle(points[0], size.width * 0.09, bright);
    canvas.drawCircle(points[1], size.width * 0.09, bright);
    canvas.drawCircle(points[2], size.width * 0.09, dim);
  }

  @override
  bool shouldRepaint(covariant _DiagonalDotsPainter oldDelegate) => false;
}

class _AvatarClipper extends CustomClipper<Path> {
  const _AvatarClipper({required this.isVerified});

  final bool isVerified;

  @override
  Path getClip(Size size) {
    final Path path = Path();
    if (isVerified) {
      path
        ..moveTo(size.width * 0.22, size.height * 0.08)
        ..lineTo(size.width * 0.64, size.height * 0.08)
        ..lineTo(size.width * 0.90, size.height * 0.34)
        ..lineTo(size.width * 0.78, size.height * 0.83)
        ..lineTo(size.width * 0.34, size.height * 0.94)
        ..lineTo(size.width * 0.08, size.height * 0.58)
        ..close();
    } else {
      path
        ..moveTo(size.width * 0.2, size.height * 0.1)
        ..lineTo(size.width * 0.8, size.height * 0.1)
        ..lineTo(size.width * 0.92, size.height * 0.5)
        ..lineTo(size.width * 0.64, size.height * 0.92)
        ..lineTo(size.width * 0.22, size.height * 0.9)
        ..lineTo(size.width * 0.06, size.height * 0.5)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _AvatarClipper oldClipper) {
    return oldClipper.isVerified != isVerified;
  }
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
    final Path local = _AvatarClipper(isVerified: isVerified).getClip(rect.size);
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
  final double nextLightness = (hsl.lightness * 0.46).clamp(0.0, 1.0);
  return hsl.withLightness(nextLightness).toColor();
}
