import 'package:flutter/material.dart';

const double _svgCardBaseWidth = 1661;
const double _svgCardBaseHeight = 960;
const Offset _svgAvatarCenter = Offset(105, 825);
const double _svgAvatarRadius = 75;

class SvgCardClipper extends CustomClipper<Path> {
  const SvgCardClipper();

  @override
  Path getClip(Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;
    final Path path = Path()
      ..moveTo(910.603 * sx, 0)
      ..cubicTo(
        919.379 * sx,
        0,
        928.002 * sx,
        2.31 * sy,
        935.603 * sx,
        6.698 * sy,
      )
      ..lineTo(1085.61 * sx, 93.302 * sy)
      ..arcToPoint(
        Offset(1110.61 * sx, 100 * sy),
        radius: Radius.elliptical(50 * sx, 50 * sy),
        largeArc: false,
        clockwise: false,
      )
      ..lineTo(1580.46 * sx, 100 * sy)
      ..cubicTo(
        1608.09 * sx,
        100 * sy,
        1630.48 * sx,
        122.409 * sy,
        1630.46 * sx,
        150.038 * sy,
      )
      ..lineTo(1630.02 * sx, 744.312 * sy)
      ..arcToPoint(
        Offset(1615.37 * sx, 779.629 * sy),
        radius: Radius.elliptical(50 * sx, 50 * sy),
        largeArc: false,
        clockwise: true,
      )
      ..lineTo(1509.64 * sx, 885.355 * sy)
      ..arcToPoint(
        Offset(1474.29 * sx, 900 * sy),
        radius: Radius.elliptical(49.98 * sx, 49.98 * sy),
        largeArc: false,
        clockwise: true,
      )
      ..lineTo(154.765 * sx, 900 * sy)
      ..cubicTo(
        179.016 * sx,
        883.876 * sy,
        195 * sx,
        856.305 * sy,
        195 * sx,
        825 * sy,
      )
      ..cubicTo(
        195 * sx,
        775.294 * sy,
        154.706 * sx,
        735 * sy,
        105 * sx,
        735 * sy,
      )
      ..cubicTo(
        73.695 * sx,
        735 * sy,
        46.124 * sx,
        750.984 * sy,
        30 * sx,
        775.235 * sy,
      )
      ..lineTo(30 * sx, 155.78 * sy)
      ..cubicTo(
        30 * sx,
        142.52 * sy,
        35.268 * sx,
        129.732 * sy,
        44.645 * sx,
        120.355 * sy,
      )
      ..lineTo(150.355 * sx, 14.645 * sy)
      ..arcToPoint(
        Offset(185.711 * sx, 0),
        radius: Radius.elliptical(50 * sx, 50 * sy),
        largeArc: false,
        clockwise: true,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant SvgCardClipper oldClipper) => false;
}

class SvgCardShadowPainter extends CustomPainter {
  const SvgCardShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _svgCardBaseWidth;
    final double sy = size.height / _svgCardBaseHeight;
    final double blurSigma = 15 * ((sx + sy) / 2);
    final double offsetY = 30 * sy;
    final Path path = const SvgCardClipper().getClip(size);
    final Paint paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    canvas.save();
    canvas.translate(0, offsetY);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SvgCardShadowPainter oldDelegate) => false;
}

class SvgCardShell extends StatelessWidget {
  const SvgCardShell({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFF0F0F0),
    this.avatarImage,
    this.avatarFallbackColor = const Color(0xFF8E8E8E),
    this.topRightOverlay,
  });

  final Widget child;
  final Color baseColor;
  final ImageProvider? avatarImage;
  final Color avatarFallbackColor;
  final Widget? topRightOverlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double sx = size.width / _svgCardBaseWidth;
        final double sy = size.height / _svgCardBaseHeight;
        final double radius = _svgAvatarRadius * ((sx + sy) / 2);
        final Offset avatarCenter = Offset(
          _svgAvatarCenter.dx * sx,
          _svgAvatarCenter.dy * sy,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: size,
              painter: const SvgCardShadowPainter(),
            ),
            ClipPath(
              clipper: const SvgCardClipper(),
              child: ColoredBox(
                color: baseColor,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: const SvgCardClipper(),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
            Positioned(
              left: avatarCenter.dx - radius,
              top: avatarCenter.dy - radius,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarFallbackColor,
                  image: avatarImage == null
                      ? null
                      : DecorationImage(
                          image: avatarImage!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            if (topRightOverlay != null)
              Positioned(
                top: 12 * sy,
                right: 16 * sx,
                child: topRightOverlay!,
              ),
          ],
        );
      },
    );
  }
}
