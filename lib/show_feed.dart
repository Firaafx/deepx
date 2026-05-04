import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipable_stack/swipable_stack.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/app_user_profile.dart';
import 'models/chat_models.dart';
import 'models/collection_models.dart';
import 'models/feed_post.dart';
import 'models/notification_item.dart';
import 'models/preset_comment.dart';
import 'models/profile_stats.dart';
import 'models/render_preset.dart';
import 'models/watch_later_item.dart';
import 'rendering_support.dart';
import 'services/app_repository.dart';
import 'services/appearance_settings_service.dart';
import 'services/browser_fullscreen.dart';
import 'services/cache_service.dart';
import 'services/query_guard.dart';
import 'services/web_file_upload.dart';
import 'widgets/preset_viewer.dart';
import 'widgets/query_feedback.dart';
import 'widgets/svg_card_shell.dart';

enum _ShellTab {
  home,
  collection,
  post,
  chat,
  profile,
  settings,
}

enum _ComposerKind {
  single,
  collection,
}

enum _ComposerEditTarget {
  card,
}

String _routeIdFromShareOrUuid({
  required String shareId,
  required String uuid,
}) {
  final String trimmedShareId = shareId.trim();
  if (trimmedShareId.isNotEmpty) return trimmedShareId;
  return uuid.trim();
}

String buildPostRoutePathForPreset(RenderPreset preset) {
  final String routeId = _routeIdFromShareOrUuid(
    shareId: preset.shareId,
    uuid: preset.id,
  );
  return '/post/${Uri.encodeComponent(routeId)}';
}

String buildCollectionRoutePathForSummary(CollectionSummary summary) {
  final String routeId = _routeIdFromShareOrUuid(
    shareId: summary.shareId,
    uuid: summary.id,
  );
  return '/collection/${Uri.encodeComponent(routeId)}';
}

String _githubPagesBasePrefix() {
  final Uri base = Uri.base;
  if (!base.host.toLowerCase().endsWith('github.io')) return '';
  final List<String> segments =
      base.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.isEmpty) return '';
  return '/${segments.first}';
}

String _publicShareUrl(String routePath) {
  final String prefix = _githubPagesBasePrefix();
  return '${Uri.base.origin}$prefix$routePath';
}

String buildPostShareUrl(RenderPreset preset) {
  return _publicShareUrl(buildPostRoutePathForPreset(preset));
}

String buildCollectionShareUrl(CollectionSummary summary) {
  return _publicShareUrl(buildCollectionRoutePathForSummary(summary));
}

PageRouteBuilder<T> _buildHeroRoute<T>({
  required WidgetBuilder builder,
  String? name,
}) {
  return PageRouteBuilder<T>(
    settings: name == null ? null : RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
      final opacity = Tween<double>(begin: 0.05, end: 1.0).animate(fade);
      return FadeTransition(opacity: opacity, child: child);
    },
  );
}

Future<T?> _pushHeroRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required String name,
  bool replace = false,
}) {
  final route = _buildHeroRoute<T>(builder: builder, name: name);
  if (replace) {
    return Navigator.of(context).pushReplacement(route);
  }
  return Navigator.of(context).push(route);
}

void _openPublicProfileRoute(
  BuildContext context,
  AppUserProfile? profile,
) {
  final String? username = profile?.username?.trim();
  if (username == null || username.isEmpty) return;
  Navigator.pushNamed(
    context,
    '/@${Uri.encodeComponent(username)}',
  );
}

class _TopEdgeLoadingPane extends StatefulWidget {
  const _TopEdgeLoadingPane({
    this.label,
    this.backgroundColor,
    this.minHeight = 3,
  });

  final String? label;
  final Color? backgroundColor;
  final double minHeight;

  @override
  State<_TopEdgeLoadingPane> createState() => _TopEdgeLoadingPaneState();
}

class _TopEdgeLoadingPaneState extends State<_TopEdgeLoadingPane>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _loadingOverlayEntry;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOverlay());
  }

  @override
  void didUpdateWidget(covariant _TopEdgeLoadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadingOverlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
    _glowController.dispose();
    super.dispose();
  }

  void _ensureOverlay() {
    if (!mounted || _loadingOverlayEntry != null) return;
    if (!_glowController.isAnimating) {
      _glowController.repeat();
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _loadingOverlayEntry = OverlayEntry(
      builder: (context) {
        final double glowHeight = widget.minHeight + 10;
        return IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              height: glowHeight,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _LinearGlowPainter(
                              animationValue: _glowController.value,
                              textDirection: Directionality.of(context),
                              barHeight: widget.minHeight,
                              glowColor: Colors.white.withValues(alpha: 0.5),
                              innerGlowColor:
                                  Colors.white.withValues(alpha: 0.85),
                              outerBlurSigma: 8,
                              innerBlurSigma: 4,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_loadingOverlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color:
          widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: widget.label != null && widget.label!.trim().isNotEmpty
          ? Center(
              child: Text(
                widget.label!,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _BlurMenuEntry<T> {
  const _BlurMenuEntry.item({
    required this.value,
    required this.label,
    this.enabled = true,
  }) : isDivider = false;

  const _BlurMenuEntry.divider()
      : value = null,
        label = null,
        enabled = false,
        isDivider = true;

  final T? value;
  final String? label;
  final bool enabled;
  final bool isDivider;
}

class BlurMenuButton<T> extends StatefulWidget {
  const BlurMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    required this.icon,
    this.tooltip,
  });

  // ignore: library_private_types_in_public_api
  final List<_BlurMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final Widget icon;
  final String? tooltip;

  @override
  State<BlurMenuButton<T>> createState() => _BlurMenuButtonState<T>();
}

class _BlurMenuButtonState<T> extends State<BlurMenuButton<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _showEntry() {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeEntry,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: _BlurMenuCard<T>(
                items: widget.items,
                onSelected: (value) {
                  _removeEntry();
                  widget.onSelected(value);
                },
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    Widget trigger = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showEntry,
        child: widget.icon,
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.trim().isNotEmpty) {
      trigger = Tooltip(message: widget.tooltip!, child: trigger);
    }
    return CompositedTransformTarget(link: _link, child: trigger);
  }
}

class _BlurMenuCard<T> extends StatelessWidget {
  const _BlurMenuCard({
    required this.items,
    required this.onSelected,
  });

  final List<_BlurMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final BorderRadius outerRadius = BorderRadius.circular(30);
    final BorderRadius innerRadius = BorderRadius.circular(29.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.72),
            Colors.white.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.5),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: innerRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: Material(
                color: Colors.black.withValues(alpha: 0.46),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 200, maxWidth: 260),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((entry) {
                      if (entry.isDivider) {
                        return const Divider(
                          height: 16,
                          color: Colors.white24,
                        );
                      }
                      return InkWell(
                        onTap: entry.enabled && entry.value != null
                            ? () => onSelected(entry.value as T)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              entry.label ?? '',
                              style: TextStyle(
                                color: entry.enabled
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SvgGridLayoutSpec {
  const _SvgGridLayoutSpec({
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.sidePadding,
  });

  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double sidePadding;
}

_SvgGridLayoutSpec _svgGridLayoutSpec({
  required double viewportWidth,
  required int crossAxisCount,
}) {
  return const _SvgGridLayoutSpec(
    crossAxisSpacing: 0,
    mainAxisSpacing: 0,
    sidePadding: 0,
  );
}

class _GridWallpaperBackdrop extends StatelessWidget {
  const _GridWallpaperBackdrop();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppearanceSettings>(
      valueListenable: AppearanceSettingsService.instance.settings,
      builder: (context, settings, _) {
        final String imageUrl = settings.wallpaperImageUrl.trim();
        if (imageUrl.isEmpty) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            ColoredBox(
              color: Color(settings.wallpaperOverlayColor).withValues(
                alpha: settings.wallpaperOverlayOpacity,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridCardPreviewSurface extends StatefulWidget {
  const _GridCardPreviewSurface({
    required this.heroTag,
    required this.mode,
    required this.payload,
    required this.title,
    required this.verticalUsername,
    required this.priceText,
    required this.avatarImage,
    required this.isVerified,
    required this.accentColor,
    required this.metaText,
    required this.showCollectionCount,
    required this.collectionCountText,
    required this.menuItems,
    required this.onMenuSelected,
    this.onAvatarTap,
    this.emptyChild,
  });

  final String heroTag;
  final String mode;
  final Map<String, dynamic> payload;
  final String title;
  final String verticalUsername;
  final String priceText;
  final ImageProvider? avatarImage;
  final bool isVerified;
  final Color accentColor;
  final String metaText;
  final bool showCollectionCount;
  final String collectionCountText;
  final List<_BlurMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback? onAvatarTap;
  final Widget? emptyChild;

  @override
  State<_GridCardPreviewSurface> createState() =>
      _GridCardPreviewSurfaceState();
}

class _GridCardPreviewSurfaceState extends State<_GridCardPreviewSurface> {
  @override
  Widget build(BuildContext context) {
    final int usernameChars = widget.verticalUsername.trim().isEmpty
        ? 1
        : widget.verticalUsername
            .trim()
            .replaceAll('@', '')
            .length
            .clamp(1, 6)
            .toInt();
    final bool twoLineTitle = _cardTitleNeedsTwoLines(
      context,
      widget.title,
    );
    final double metaWidthFactor = _cardMetaWidthFactor(
      context,
      widget.metaText,
    );
    final SvgCardClipper clipper = SvgCardClipper(
      usernameCharCount: usernameChars,
      metaWidthFactor: metaWidthFactor,
      twoLineTitle: twoLineTitle,
    );
    final List<SvgCardMenuAction> menuActions = widget.menuItems.map((item) {
      if (item.isDivider) return const SvgCardMenuAction.divider();
      final String value = item.value ?? '';
      if (value.isEmpty) return const SvgCardMenuAction.divider();
      return SvgCardMenuAction(
        value: value,
        label: item.label ?? value,
        enabled: item.enabled,
      );
    }).toList();

    return SizedBox.expand(
      child: Hero(
        tag: widget.heroTag,
        createRectTween: (begin, end) =>
            _EaseInOutRectTween(begin: begin, end: end),
        child: SvgCardShell(
          baseColor: const Color(0x00000000),
          title: widget.title,
          metaText: widget.metaText,
          verticalUsername: widget.verticalUsername,
          priceLabel: widget.priceText,
          showCollectionCount: widget.showCollectionCount,
          collectionCountLabel: widget.collectionCountText,
          isVerified: widget.isVerified,
          accentColor: widget.accentColor,
          avatarImage: widget.avatarImage,
          onAvatarTap: widget.onAvatarTap,
          menuItems: menuActions,
          onMenuSelected: widget.onMenuSelected,
          child: _SharedPresetPreview(
            mode: widget.mode,
            payload: widget.payload,
            clipper: clipper,
            emptyChild: widget.emptyChild,
          ),
        ),
      ),
    );
  }
}

class _HoverActivatedPreviewRegion extends StatefulWidget {
  const _HoverActivatedPreviewRegion({required this.builder});

  final Widget Function(bool active) builder;

  @override
  State<_HoverActivatedPreviewRegion> createState() =>
      _HoverActivatedPreviewRegionState();
}

class _HoverActivatedPreviewRegionState
    extends State<_HoverActivatedPreviewRegion> {
  bool _realHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _realHover = true),
      onExit: (_) => setState(() => _realHover = false),
      child: widget.builder(_realHover),
    );
  }
}

class _EaseInOutRectTween extends RectTween {
  _EaseInOutRectTween({super.begin, super.end});

  @override
  Rect lerp(double t) {
    final double eased = Curves.easeInOut.transform(t);
    return Rect.lerp(begin, end, eased)!;
  }
}

const double _kDetailContentPadding = 0;
const double _kDetailPanelGap = 0;
const double _kDetailPrimaryRatio = 0.8;
const double _kDetailSecondaryRatio = 0.2;
const double _kDetailPreviewAspectRatio = 16 / 9;

double _detailPreviewWidth({
  required double contentWidth,
  required bool desktop,
}) {
  if (!desktop) return contentWidth;
  final double usable = math.max(0, contentWidth - _kDetailPanelGap);
  return usable * _kDetailPrimaryRatio;
}

double _detailSidePanelWidth({
  required double contentWidth,
  required bool desktop,
}) {
  if (!desktop) return contentWidth;
  final double usable = math.max(0, contentWidth - _kDetailPanelGap);
  return usable * _kDetailSecondaryRatio;
}

class _CardScopedAmbientBackdrop extends StatelessWidget {
  const _CardScopedAmbientBackdrop({
    required this.mode,
    required this.payload,
    required this.previewWidth,
    required this.leftPadding,
    required this.topPadding,
    required this.desktop,
  });

  final String mode;
  final Map<String, dynamic> payload;
  final double previewWidth;
  final double leftPadding;
  final double topPadding;
  final bool desktop;

  Widget _buildFallbackAmbientImage(String normalizedUrl) {
    return Image.network(
      normalizedUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF101213)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String normalizedUrl = (ambientImageUrlFromPayload(
              payload,
              fallbackMode: mode,
            ) ??
            '')
        .trim();
    final bool hasAmbient = previewWidth > 0 && normalizedUrl.isNotEmpty;
    final double previewHeight = previewWidth / _kDetailPreviewAspectRatio;
    return ValueListenableBuilder<AppearanceSettings>(
      valueListenable: AppearanceSettingsService.instance.settings,
      builder: (context, settings, _) {
        final double sigmaX = settings.ambientBlurSigmaX;
        final double sigmaY = settings.ambientBlurSigmaY;

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF101213)),
            if (hasAmbient)
              Positioned(
                left: leftPadding,
                top: topPadding,
                width: previewWidth,
                height: previewHeight,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildFallbackAmbientImage(normalizedUrl),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: sigmaX,
                    sigmaY: sigmaY,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: hasAmbient ? 0.12 : 0.0,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: desktop
                        ? const Alignment(-0.46, -0.78)
                        : const Alignment(0, -0.92),
                    radius: desktop ? 1.18 : 1.04,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: hasAmbient ? 0.16 : 0.0),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinearGlowPainter extends CustomPainter {
  const _LinearGlowPainter({
    required this.animationValue,
    required this.textDirection,
    required this.barHeight,
    required this.glowColor,
    required this.innerGlowColor,
    this.outerBlurSigma = 8,
    this.innerBlurSigma = 4,
  });

  final double animationValue;
  final TextDirection textDirection;
  final double barHeight;
  final Color glowColor;
  final Color innerGlowColor;
  final double outerBlurSigma;
  final double innerBlurSigma;

  static const int _kIndeterminateLinearDuration = 1800;
  static const Curve _line1Head = Interval(
    0.0,
    750.0 / _kIndeterminateLinearDuration,
    curve: Cubic(0.2, 0.0, 0.8, 1.0),
  );
  static const Curve _line1Tail = Interval(
    333.0 / _kIndeterminateLinearDuration,
    (333.0 + 750.0) / _kIndeterminateLinearDuration,
    curve: Cubic(0.4, 0.0, 1.0, 1.0),
  );
  static const Curve _line2Head = Interval(
    1000.0 / _kIndeterminateLinearDuration,
    (1000.0 + 567.0) / _kIndeterminateLinearDuration,
    curve: Cubic(0.0, 0.0, 0.65, 1.0),
  );
  static const Curve _line2Tail = Interval(
    1267.0 / _kIndeterminateLinearDuration,
    (1267.0 + 533.0) / _kIndeterminateLinearDuration,
    curve: Cubic(0.10, 0.0, 0.45, 1.0),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bool isLtr = textDirection == TextDirection.ltr;
    void drawGlow(double startFraction, double endFraction) {
      if (endFraction - startFraction <= 0) return;
      final double left =
          (isLtr ? startFraction : 1 - endFraction) * size.width;
      final double right =
          (isLtr ? endFraction : 1 - startFraction) * size.width;
      final Rect rect = Rect.fromLTRB(left, 0, right, barHeight);
      final RRect rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(barHeight / 2));
      final LinearGradient barGradient = LinearGradient(
        begin: isLtr ? Alignment.centerLeft : Alignment.centerRight,
        end: isLtr ? Alignment.centerRight : Alignment.centerLeft,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.86),
        ],
      );
      final LinearGradient shineGradient = LinearGradient(
        begin: isLtr ? Alignment.centerLeft : Alignment.centerRight,
        end: isLtr ? Alignment.centerRight : Alignment.centerLeft,
        colors: <Color>[
          innerGlowColor.withValues(alpha: 0.0),
          innerGlowColor,
        ],
      );
      final Paint barPaint = Paint()..shader = barGradient.createShader(rect);
      final Paint outerPaint = Paint()
        ..color = glowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outerBlurSigma);
      final Paint innerPaint = Paint()
        ..shader = shineGradient.createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, innerBlurSigma);
      canvas.drawRRect(rrect, barPaint);
      canvas.drawRRect(rrect, outerPaint);
      canvas.drawRRect(rrect, innerPaint);
    }

    final double firstLineHead = _line1Head.transform(animationValue);
    final double firstLineTail = _line1Tail.transform(animationValue);
    final double secondLineHead = _line2Head.transform(animationValue);
    final double secondLineTail = _line2Tail.transform(animationValue);

    if (firstLineHead - firstLineTail > 0) {
      drawGlow(firstLineTail, firstLineHead);
    }
    if (secondLineHead - secondLineTail > 0) {
      drawGlow(secondLineTail, secondLineHead);
    }
  }

  @override
  bool shouldRepaint(_LinearGlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.innerGlowColor != innerGlowColor ||
        oldDelegate.outerBlurSigma != outerBlurSigma ||
        oldDelegate.innerBlurSigma != innerBlurSigma;
  }
}

bool _cardTitleNeedsTwoLines(BuildContext context, String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return false;
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
      ),
    ),
    maxLines: 2,
    ellipsis: '...',
    textDirection: Directionality.of(context),
  )..layout(maxWidth: 240);
  return painter.computeLineMetrics().length > 1;
}

double _cardMetaWidthFactor(BuildContext context, String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return 0;
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w400,
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout(maxWidth: 9999);
  final double measured = painter.width + 14;
  return ((measured - 70) / 130).clamp(0.0, 1.0).toDouble();
}

Color _cardAccentColorFromHex(
  String? raw, {
  Color fallback = const Color(0xFFFD4687),
}) {
  final String value = (raw ?? '').trim();
  if (value.isEmpty) return fallback;
  final String normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length != 6) return fallback;
  final int? parsed = int.tryParse('FF$normalized', radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

String _cardPriceLabel({
  required bool isPaid,
  required int? priceCents,
  required bool viewerHasPaid,
}) {
  if (!isPaid || viewerHasPaid) return 'Free';
  final int cents = (priceCents ?? 0).clamp(0, 999999999);
  if (cents == 0) return 'Free';
  final String dollars =
      (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
  return '\$$dollars';
}

String _verticalUsernameForCard(AppUserProfile? profile) {
  final String username = (profile?.username ?? '').trim();
  if (username.isNotEmpty) return username;
  final String full = (profile?.fullName ?? '').trim();
  if (full.isNotEmpty) return full.replaceAll(' ', '');
  return 'U';
}

class StandalonePostRoutePage extends StatefulWidget {
  const StandalonePostRoutePage({
    super.key,
    required this.idOrShareId,
  });

  final String idOrShareId;

  @override
  State<StandalonePostRoutePage> createState() =>
      _StandalonePostRoutePageState();
}

class _StandalonePostRoutePageState extends State<StandalonePostRoutePage> {
  final AppRepository _repository = AppRepository.instance;
  bool _loading = true;
  String? _error;
  FeedPost? _post;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String routeId = widget.idOrShareId.trim();
    if (routeId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Post link is invalid.';
      });
      return;
    }
    try {
      final post = await QueryGuard.run(
        () => _repository.fetchFeedPostByRouteId(routeId),
      );
      if (!mounted) return;
      if (post == null) {
        setState(() {
          _loading = false;
          _error = 'Unable to load post.';
        });
        return;
      }
      setState(() {
        _post = post;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101213),
        body: _TopEdgeLoadingPane(label: 'Loading post...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: QueryRetryPane(
          title: _error,
          offline: _isOfflineErrorText(_error!),
          onRetry: _load,
        ),
      );
    }
    return _PresetDetailPage(initialPost: _post!);
  }
}

class StandaloneCollectionRoutePage extends StatefulWidget {
  const StandaloneCollectionRoutePage({
    super.key,
    required this.idOrShareId,
  });

  final String idOrShareId;

  @override
  State<StandaloneCollectionRoutePage> createState() =>
      _StandaloneCollectionRoutePageState();
}

class _StandaloneCollectionRoutePageState
    extends State<StandaloneCollectionRoutePage> {
  final AppRepository _repository = AppRepository.instance;
  bool _loading = true;
  String? _error;
  CollectionDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String routeId = widget.idOrShareId.trim();
    if (routeId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Collection link is invalid.';
      });
      return;
    }
    try {
      final detail = await QueryGuard.run(
        () => _repository.fetchCollectionByRouteId(routeId),
      );
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = 'Unable to load collection.';
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101213),
        body: _TopEdgeLoadingPane(label: 'Loading collection...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: QueryRetryPane(
          title: _error,
          offline: _isOfflineErrorText(_error!),
          onRetry: _load,
        ),
      );
    }
    return _CollectionDetailPage(
      collectionId: _detail!.summary.id,
      initialSummary: _detail!.summary,
    );
  }
}

enum _PublicProfileFilter { all, posts, collections }

class StandalonePublicProfileRoutePage extends StatefulWidget {
  const StandalonePublicProfileRoutePage({
    super.key,
    required this.username,
  });

  final String username;

  @override
  State<StandalonePublicProfileRoutePage> createState() =>
      _StandalonePublicProfileRoutePageState();
}

class _StandalonePublicProfileRoutePageState
    extends State<StandalonePublicProfileRoutePage> {
  final AppRepository _repository = AppRepository.instance;
  bool _loading = true;
  String? _error;
  AppUserProfile? _profile;
  ProfileStats? _stats;
  List<RenderPreset> _posts = const <RenderPreset>[];
  List<CollectionSummary> _collections = const <CollectionSummary>[];
  _PublicProfileFilter _filter = _PublicProfileFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String username = widget.username.trim().toLowerCase();
    if (username.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Profile username is missing.';
      });
      return;
    }
    try {
      final profile = await QueryGuard.run(
        () => _repository.fetchProfileByUsername(username),
      );
      if (profile == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Unable to load profile.';
        });
        return;
      }
      final results = await QueryGuard.run(
        () => Future.wait<dynamic>([
          _repository.fetchProfileStats(profile.userId),
          _repository.fetchPublicPostsForUser(profile.userId, limit: 90),
          _repository.fetchPublicCollectionsForUser(profile.userId, limit: 60),
        ]),
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = results[0] as ProfileStats;
        _posts = results[1] as List<RenderPreset>;
        _collections = results[2] as List<CollectionSummary>;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(
        body: _TopEdgeLoadingPane(label: 'Loading profile...'),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: QueryRetryPane(
          title: _error ?? 'Profile unavailable.',
          offline: _error != null ? _isOfflineErrorText(_error!) : false,
          onRetry: _load,
        ),
      );
    }
    final profile = _profile!;
    final ImageProvider? profileAvatarImage =
        (profile.avatarUrl ?? '').trim().isNotEmpty
            ? NetworkImage(profile.avatarUrl!.trim())
            : null;
    final stats = _stats ??
        const ProfileStats(
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
        );
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    if (_filter == _PublicProfileFilter.all ||
        _filter == _PublicProfileFilter.posts) {
      for (final post in _posts) {
        entries.add(<String, dynamic>{
          'kind': 'post',
          'id': post.id,
          'title': post.title.isNotEmpty ? post.title : post.name,
          'meta':
              '${post.mode.toUpperCase()} • ${_friendlyTime(post.createdAt)}',
          'mode': post.thumbnailMode ?? post.mode,
          'payload': post.thumbnailPayload.isNotEmpty
              ? post.thumbnailPayload
              : post.payload,
          'tapPath': buildPostRoutePathForPreset(post),
          'heroTag': 'post-detail-hero-${post.id}',
          'priceText': _cardPriceLabel(
            isPaid: post.isPaid,
            priceCents: post.priceCents,
            viewerHasPaid: post.viewerHasPaid,
          ),
          'accentHex': post.accentColorHex,
          'showCollectionCount': false,
          'collectionCountText': '',
        });
      }
    }
    if (_filter == _PublicProfileFilter.all ||
        _filter == _PublicProfileFilter.collections) {
      for (final collection in _collections) {
        entries.add(<String, dynamic>{
          'kind': 'collection',
          'id': collection.id,
          'title': collection.name.isNotEmpty ? collection.name : 'Collection',
          'meta':
              '${collection.itemsCount} items • ${_friendlyTime(collection.createdAt)}',
          'mode':
              collection.thumbnailMode ?? collection.firstItem?.mode ?? '2d',
          'payload': collection.thumbnailPayload.isNotEmpty
              ? collection.thumbnailPayload
              : (collection.firstItem?.snapshot ?? const <String, dynamic>{}),
          'tapPath': buildCollectionRoutePathForSummary(collection),
          'heroTag': 'collection-detail-hero-${collection.id}-0',
          'priceText': _cardPriceLabel(
            isPaid: collection.isPaid,
            priceCents: collection.priceCents,
            viewerHasPaid: collection.viewerHasPaid,
          ),
          'accentHex': collection.accentColorHex,
          'showCollectionCount': true,
          'collectionCountText': '${collection.itemsCount}',
        });
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: Colors.white,
                          ),
                          const Spacer(),
                          Text(
                            '/@${profile.username ?? profile.displayName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundImage: (profile.avatarUrl != null &&
                                    profile.avatarUrl!.isNotEmpty)
                                ? NetworkImage(profile.avatarUrl!)
                                : null,
                            child: (profile.avatarUrl == null ||
                                    profile.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.bio.trim().isNotEmpty
                                      ? profile.bio.trim()
                                      : 'DeepX creator channel',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _profileStatTile(
                            label: 'Posts',
                            value: stats.postsCount,
                          ),
                          const SizedBox(width: 14),
                          _profileStatTile(
                            label: 'Followers',
                            value: stats.followersCount,
                          ),
                          const SizedBox(width: 14),
                          _profileStatTile(
                            label: 'Following',
                            value: stats.followingCount,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        selected: _filter == _PublicProfileFilter.all,
                        label: Text(
                          'All',
                          style: TextStyle(
                            color: _filter == _PublicProfileFilter.all
                                ? Colors.black
                                : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: Colors.white,
                        checkmarkColor: Colors.black,
                        onSelected: (_) =>
                            setState(() => _filter = _PublicProfileFilter.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _filter == _PublicProfileFilter.posts,
                        label: Text(
                          'Posts',
                          style: TextStyle(
                            color: _filter == _PublicProfileFilter.posts
                                ? Colors.black
                                : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: Colors.white,
                        checkmarkColor: Colors.black,
                        onSelected: (_) => setState(
                            () => _filter = _PublicProfileFilter.posts),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _filter == _PublicProfileFilter.collections,
                        label: Text(
                          'Collections',
                          style: TextStyle(
                            color: _filter == _PublicProfileFilter.collections
                                ? Colors.black
                                : cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: Colors.white,
                        checkmarkColor: Colors.black,
                        onSelected: (_) => setState(
                          () => _filter = _PublicProfileFilter.collections,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No public content yet.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.crossAxisExtent;
                  int crossAxisCount = 1;
                  if (width >= 1150) {
                    crossAxisCount = 3;
                  } else if (width >= 760) {
                    crossAxisCount = 2;
                  }
                  final _SvgGridLayoutSpec gridSpec = _svgGridLayoutSpec(
                    viewportWidth: width,
                    crossAxisCount: crossAxisCount,
                  );
                  return SliverPadding(
                    padding: EdgeInsets.zero,
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = entries[index];
                          final String title = entry['title']?.toString() ?? '';
                          final String meta = entry['meta']?.toString() ?? '';
                          final String path =
                              entry['tapPath']?.toString() ?? '/';
                          final String mode = entry['mode']?.toString() ?? '2d';
                          final Map<String, dynamic> payload =
                              (entry['payload'] as Map?)
                                      ?.cast<String, dynamic>() ??
                                  const <String, dynamic>{};
                          final String heroTag = entry['heroTag']?.toString() ??
                              'public-profile-card-$index';
                          final bool showCollectionCount =
                              entry['showCollectionCount'] == true;
                          final String collectionCountText =
                              entry['collectionCountText']?.toString() ?? '';
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pushNamed(context, path),
                              child: _GridCardPreviewSurface(
                                heroTag: heroTag,
                                mode: mode,
                                payload: payload,
                                title: title,
                                verticalUsername: _verticalUsernameForCard(
                                  profile,
                                ),
                                priceText:
                                    entry['priceText']?.toString() ?? 'Free',
                                avatarImage: profileAvatarImage,
                                isVerified: profile.isVerified,
                                accentColor: _cardAccentColorFromHex(
                                  entry['accentHex']?.toString(),
                                ),
                                metaText: meta,
                                showCollectionCount: showCollectionCount,
                                collectionCountText: collectionCountText,
                                menuItems: const <_BlurMenuEntry<String>>[],
                                onAvatarTap: () =>
                                    _openPublicProfileRoute(context, profile),
                                onMenuSelected: (_) {},
                                emptyChild: showCollectionCount
                                    ? Container(
                                        color: cs.surfaceContainerLow,
                                        child: Center(
                                          child: Icon(
                                            Icons.collections_bookmark_outlined,
                                            color: cs.onSurfaceVariant,
                                            size: 34,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                        childCount: entries.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: gridSpec.mainAxisSpacing,
                        crossAxisSpacing: gridSpec.crossAxisSpacing,
                        childAspectRatio: _kGridPreviewAspectRatio,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileStatTile({required String label, required int value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.tab,
    required this.icon,
    required this.label,
  });

  final _ShellTab tab;
  final IconData icon;
  final String label;
}

class ShowFeedPage extends StatefulWidget {
  const ShowFeedPage({
    super.key,
    this.themeMode = 'dark',
    this.onThemeModeChanged,
    this.initialTab = 'home',
  });

  final String themeMode;
  final ValueChanged<String>? onThemeModeChanged;
  final String initialTab;

  @override
  State<ShowFeedPage> createState() => _ShowFeedPageState();
}

class _ShowFeedPageState extends State<ShowFeedPage> {
  static const double _headerHeight = 84;
  static const double _headerTopOffset = 0;
  static const double _feedTopPadding = _headerHeight + _headerTopOffset;
  static const double _tabContentTopPadding = 48;

  static const List<_NavItem> _primaryNav = <_NavItem>[
    _NavItem(tab: _ShellTab.home, icon: Icons.home_outlined, label: 'Home'),
    _NavItem(
      tab: _ShellTab.collection,
      icon: Icons.collections_bookmark_outlined,
      label: 'Collection',
    ),
    _NavItem(tab: _ShellTab.post, icon: Icons.add_box_outlined, label: 'Post'),
    _NavItem(
        tab: _ShellTab.chat, icon: Icons.chat_bubble_outline, label: 'Chat'),
    _NavItem(
      tab: _ShellTab.profile,
      icon: Icons.account_circle_outlined,
      label: 'Profile',
    ),
  ];

  final AppRepository _repository = AppRepository.instance;
  final GlobalKey<_HomeFeedTabState> _homeKey = GlobalKey<_HomeFeedTabState>();
  final GlobalKey<_CollectionTabState> _collectionKey =
      GlobalKey<_CollectionTabState>();
  final GlobalKey<_ChatTabState> _chatKey = GlobalKey<_ChatTabState>();
  final GlobalKey<_ProfileTabState> _profileKey = GlobalKey<_ProfileTabState>();
  final GlobalKey _navRegionKey = GlobalKey();

  _ShellTab _activeTab = _ShellTab.home;
  bool _navExpanded = false;
  bool _realNavHover = false;
  AppUserProfile? _currentProfile;
  List<NotificationItem> _headerNotifications = const <NotificationItem>[];
  Map<String, AppUserProfile> _notificationActors =
      const <String, AppUserProfile>{};

  bool get _isGuest => _repository.currentUser == null;

  _ShellTab _tabFromSegment(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'home':
        return _ShellTab.home;
      case 'collection':
        return _ShellTab.collection;
      case 'post':
        return _ShellTab.post;
      case 'chat':
        return _ShellTab.chat;
      case 'profile':
        return _ShellTab.profile;
      case 'settings':
        return _ShellTab.settings;
      default:
        return _ShellTab.home;
    }
  }

  String _segmentForTab(_ShellTab tab) {
    switch (tab) {
      case _ShellTab.home:
        return 'home';
      case _ShellTab.collection:
        return 'collection';
      case _ShellTab.post:
        return 'post';
      case _ShellTab.chat:
        return 'chat';
      case _ShellTab.profile:
        return 'profile';
      case _ShellTab.settings:
        return 'settings';
    }
  }

  String _pathForTab(_ShellTab tab) => '/feed/${_segmentForTab(tab)}';

  @override
  void initState() {
    super.initState();
    _activeTab = _tabFromSegment(widget.initialTab);
    _loadProfile();
    _loadHeaderNotifications();
  }

  @override
  void dispose() {
    debugPrint('Disposing ShowFeedPage(tab=${_activeTab.name})');
    super.dispose();
  }

  Future<void> _reloadActiveTab() async {
    switch (_activeTab) {
      case _ShellTab.home:
        await _homeKey.currentState?._loadFeed();
        break;
      case _ShellTab.collection:
        await _collectionKey.currentState?._loadCollections();
        break;
      case _ShellTab.post:
        break;
      case _ShellTab.chat:
        await _chatKey.currentState?._bootstrap();
        break;
      case _ShellTab.profile:
        await _profileKey.currentState?._load();
        break;
      case _ShellTab.settings:
        await _loadProfile();
        break;
    }
  }

  Future<void> _loadProfile() async {
    if (_repository.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _currentProfile = null;
        _headerNotifications = const <NotificationItem>[];
        _notificationActors = const <String, AppUserProfile>{};
      });
      return;
    }
    try {
      final profile = await QueryGuard.run(
        () => _repository.ensureCurrentProfile(),
      );
      if (!mounted) return;
      setState(() => _currentProfile = profile);
      unawaited(_loadHeaderNotifications());
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentProfile = null);
    }
  }

  Future<void> _loadHeaderNotifications() async {
    if (_repository.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _headerNotifications = const <NotificationItem>[];
        _notificationActors = const <String, AppUserProfile>{};
      });
      return;
    }
    try {
      final notifications = await QueryGuard.run(
        () => _repository.fetchNotifications(limit: 80),
      );
      final Set<String> actorIds = notifications
          .map((n) => n.actorUserId ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final actors = await QueryGuard.run(
        () => _repository.fetchProfilesByIds(actorIds),
      );
      if (!mounted) return;
      setState(() {
        _headerNotifications = notifications;
        _notificationActors = actors;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _headerNotifications = const <NotificationItem>[];
        _notificationActors = const <String, AppUserProfile>{};
      });
    }
  }

  Future<void> _markNotificationReadLocal(NotificationItem item) async {
    if (item.read) return;
    await _repository.markNotificationRead(item.id, read: true);
    if (!mounted) return;
    setState(() {
      _headerNotifications = _headerNotifications
          .map((n) => n.id == item.id
              ? NotificationItem(
                  id: n.id,
                  userId: n.userId,
                  actorUserId: n.actorUserId,
                  kind: n.kind,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  read: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    });
  }

  Future<void> _openNotificationTarget(NotificationItem item) async {
    final String type = (item.data['type']?.toString() ?? '').toLowerCase();
    if (type == 'chat_message') {
      await _switchTab(_ShellTab.chat);
      return;
    }

    final String targetId = item.data['preset_id']?.toString() ?? '';
    if (targetId.isEmpty) return;
    try {
      final post = await QueryGuard.run(
        () => _repository.fetchFeedPostByRouteId(targetId),
      );
      if (!mounted) return;
      if (post != null) {
        await Navigator.pushNamed(
          context,
          buildPostRoutePathForPreset(post.preset),
        );
        return;
      }
      final collection = await QueryGuard.run(
        () => _repository.fetchCollectionByRouteId(targetId),
      );
      if (!mounted || collection == null) return;
      await Navigator.pushNamed(
        context,
        buildCollectionRoutePathForSummary(collection.summary),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Retry.')),
      );
    }
  }

  Future<void> _openHeaderNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        if (_headerNotifications.isEmpty) {
          return SizedBox(
            height: 260,
            child: Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }
        return SizedBox(
          height: 460,
          child: ListView.separated(
            itemCount: _headerNotifications.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
            itemBuilder: (context, index) {
              final item = _headerNotifications[index];
              final actor = item.actorUserId == null
                  ? null
                  : _notificationActors[item.actorUserId!];
              final bool isMessage =
                  (item.data['type']?.toString() ?? '') == 'chat_message';
              final String title = isMessage
                  ? (item.title.isNotEmpty
                      ? item.title
                      : 'New message from ${actor?.displayName ?? 'User'}')
                  : (item.kind == 'mention'
                      ? '${actor?.displayName ?? 'Someone'} mentioned you'
                      : item.title);
              final String body = item.body.isNotEmpty
                  ? item.body
                  : (item.data['preset_title']?.toString() ?? '');
              final String meta = _friendlyTime(item.createdAt);
              final String subtitleText = body.isEmpty ? meta : '$body\n$meta';
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      actor?.avatarUrl != null && actor!.avatarUrl!.isNotEmpty
                          ? NetworkImage(actor.avatarUrl!)
                          : null,
                  child: actor?.avatarUrl == null || actor!.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                subtitle: Text(subtitleText, maxLines: 3),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await _markNotificationReadLocal(item);
                  if (!mounted) return;
                  navigator.pop();
                  await _openNotificationTarget(item);
                  if (!mounted) return;
                  await _loadHeaderNotifications();
                },
              );
            },
          ),
        );
      },
    );
    await _repository.markNotificationsSeen();
    if (!mounted) return;
    await _loadHeaderNotifications();
  }

  void _setRealNavHover(bool value) {
    if (_realNavHover == value) return;
    _realNavHover = value;
    _syncNavExpanded();
  }

  void _syncNavExpanded() {
    final bool next = _realNavHover;
    if (_navExpanded == next) return;
    if (!mounted) return;
    setState(() => _navExpanded = next);
  }

  bool _tabNeedsAuth(_ShellTab tab) {
    return tab != _ShellTab.home && tab != _ShellTab.collection;
  }

  Future<bool> _promptSignIn() async {
    if (!mounted) return false;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return true;
  }

  Future<void> _toggleBrowserFullscreen() async {
    try {
      final bool didToggle = await toggleBrowserFullscreen();
      if (didToggle) return;
    } catch (_) {
      // Fall through to the same unavailable message below.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fullscreen is not available in this browser/device.'),
      ),
    );
  }

  Future<void> _switchTab(_ShellTab tab) async {
    if (_isGuest && _tabNeedsAuth(tab)) {
      await _promptSignIn();
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (!mounted) return;
    if (tab == _ShellTab.home) {
      await CacheService.instance.markDomainDirty(CacheDomain.feed);
    } else if (tab == _ShellTab.collection) {
      await CacheService.instance.markDomainDirty(CacheDomain.collections);
    }
    if (!mounted) return;
    final String targetPath = _pathForTab(tab);
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: targetPath),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => ShowFeedPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          initialTab: _segmentForTab(tab),
        ),
      ),
    );
  }

  void _onScrollableDirection(bool showHeader) {
    // Home and Collection keep a pinned header in v1.0.021.
  }

  String get _title {
    switch (_activeTab) {
      case _ShellTab.home:
        return 'DeepX';
      case _ShellTab.collection:
        return 'Collection';
      case _ShellTab.post:
        return 'Post Studio';
      case _ShellTab.chat:
        return 'Chat';
      case _ShellTab.profile:
        return 'Profile';
      case _ShellTab.settings:
        return 'Settings';
    }
  }

  double _topInsetForTab(_ShellTab tab) {
    switch (tab) {
      case _ShellTab.home:
      case _ShellTab.collection:
        return _feedTopPadding;
      case _ShellTab.post:
      case _ShellTab.chat:
      case _ShellTab.profile:
      case _ShellTab.settings:
        return _tabContentTopPadding;
    }
  }

  Widget _buildActiveTab() {
    final topInset = _topInsetForTab(_activeTab);
    switch (_activeTab) {
      case _ShellTab.home:
        return _HomeFeedTab(
          key: _homeKey,
          topInset: topInset,
          onScrollDirection: _onScrollableDirection,
        );
      case _ShellTab.collection:
        return _CollectionTab(
          key: _collectionKey,
          topInset: topInset,
          onScrollDirection: _onScrollableDirection,
        );
      case _ShellTab.post:
        return _PostStudioTab(topInset: topInset);
      case _ShellTab.chat:
        return _ChatTab(key: _chatKey, topInset: topInset);
      case _ShellTab.profile:
        return _ProfileTab(
          key: _profileKey,
          onProfileChanged: _loadProfile,
          topInset: topInset,
        );
      case _ShellTab.settings:
        return _SettingsTab(
          currentThemeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color headerTitleColor = isDark ? Colors.white : cs.onSurface;
    final bool swapHomeTitle = _activeTab == _ShellTab.home && _navExpanded;
    final String headerTitle = _activeTab == _ShellTab.home
        ? (swapHomeTitle ? 'Home' : 'DeepX')
        : _title;
    final int unreadNotifications =
        _headerNotifications.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          MouseRegion(
            key: _navRegionKey,
            onEnter: (_) => _setRealNavHover(true),
            onExit: (_) => _setRealNavHover(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: _navExpanded ? 224 : 78,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border(
                  right: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _switchTab(_ShellTab.home),
                        child: Row(
                          children: [
                            Icon(Icons.blur_on, color: headerTitleColor),
                            const SizedBox(width: 10),
                            if (_navExpanded)
                              Text(
                                'DeepX',
                                style: GoogleFonts.orbitron(
                                  color: headerTitleColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    for (final _NavItem item in _primaryNav)
                      _NavButton(
                        expanded: _navExpanded,
                        active: _activeTab == item.tab,
                        colorScheme: cs,
                        icon: item.icon,
                        label: item.label,
                        onTap: () => _switchTab(item.tab),
                      ),
                    const Spacer(),
                    _NavButton(
                      expanded: _navExpanded,
                      active: _activeTab == _ShellTab.settings,
                      colorScheme: cs,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => _switchTab(_ShellTab.settings),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: KeyedSubtree(
                      key: ValueKey<String>('active-tab-${_activeTab.name}'),
                      child: _buildActiveTab(),
                    ),
                  ),
                  Positioned(
                    top: _headerTopOffset,
                    left: 0,
                    right: 0,
                    child: ClipRect(
                      child: SizedBox(
                        height: _headerHeight,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                      stops: const [0, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 10, 10),
                              child: Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: Text(
                                      headerTitle,
                                      key: ValueKey<String>(headerTitle),
                                      style: (_activeTab == _ShellTab.home
                                                  ? GoogleFonts.orbitron(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    )
                                                  : null)
                                              ?.copyWith(
                                            color: headerTitleColor,
                                            fontSize: 28,
                                          ) ??
                                          TextStyle(
                                            color: headerTitleColor,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_currentProfile != null)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () =>
                                          _switchTab(_ShellTab.profile),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundImage:
                                                  (_currentProfile!.avatarUrl !=
                                                              null &&
                                                          _currentProfile!
                                                              .avatarUrl!
                                                              .isNotEmpty)
                                                      ? NetworkImage(
                                                          _currentProfile!
                                                              .avatarUrl!)
                                                      : null,
                                              backgroundColor:
                                                  cs.surfaceContainerHighest,
                                              child: (_currentProfile!
                                                              .avatarUrl ==
                                                          null ||
                                                      _currentProfile!
                                                          .avatarUrl!.isEmpty)
                                                  ? Icon(Icons.person,
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      size: 15)
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              _currentProfile!.displayName,
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    FilledButton.tonal(
                                      onPressed: () => _promptSignIn(),
                                      child: const Text('Sign In'),
                                    ),
                                  if (_currentProfile != null)
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        IconButton(
                                          tooltip: 'Notifications',
                                          onPressed: _openHeaderNotifications,
                                          icon: Icon(
                                            Icons.notifications_outlined,
                                            color: headerTitleColor,
                                          ),
                                        ),
                                        if (unreadNotifications > 0)
                                          Positioned(
                                            right: 2,
                                            top: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                unreadNotifications > 99
                                                    ? '99+'
                                                    : '$unreadNotifications',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  IconButton(
                                    tooltip: 'Browser Fullscreen',
                                    onPressed: _toggleBrowserFullscreen,
                                    icon: Icon(
                                      Icons.fullscreen,
                                      color: headerTitleColor,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Reload',
                                    onPressed: _reloadActiveTab,
                                    icon: Icon(Icons.refresh,
                                        color: headerTitleColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.expanded,
    required this.active,
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final bool active;
  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        widget.active ? Colors.black : widget.colorScheme.onSurface;
    Color bg = Colors.transparent;
    if (widget.active) {
      bg = Colors.white;
    } else if (_hovered) {
      bg = widget.colorScheme.onSurface.withValues(alpha: 0.12);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: fg, size: 24),
                if (widget.expanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeFeedTab extends StatefulWidget {
  const _HomeFeedTab({
    super.key,
    required this.topInset,
    required this.onScrollDirection,
  });

  final double topInset;
  final ValueChanged<bool> onScrollDirection;

  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

const double _kGridPreviewAspectRatio = 1852 / 1413;

class _HomeFeedTabState extends State<_HomeFeedTab> {
  final AppRepository _repository = AppRepository.instance;
  static const double _chipRailTop = 56;
  static const double _chipRailHeight = 38;
  static const List<String> _homeFeedChips = <String>[
    'All',
    'FYP',
    'Trending',
    'Most Used Hashtags',
    'Most Liked',
    'Most Viewed',
    'Viral',
  ];

  bool _loading = true;
  String? _error;
  final List<FeedPost> _posts = <FeedPost>[];
  String _selectedHomeChip = _homeFeedChips.first;

  double _feedGridCardAspectRatio({
    required double width,
    required int crossAxisCount,
  }) {
    return _kGridPreviewAspectRatio;
  }

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await QueryGuard.run(
        () => _repository.fetchFeedPosts(limit: 120),
      );
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _openPost(FeedPost post) async {
    await _repository.recordPresetView(post.preset.id);
    if (!mounted) return;
    await _pushHeroRoute(
      context,
      builder: (_) => _PresetDetailPage(initialPost: post),
      name: buildPostRoutePathForPreset(post.preset),
    );
    await _loadFeed();
  }

  Future<void> _openPostEditor(FeedPost post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/post/editor/card-update'),
        builder: (_) => _PostCardComposerPage.single(
          name: post.preset.name,
          mode: post.preset.mode,
          payload: post.preset.payload,
          existingPreset: post.preset,
          initialIsPaid: post.preset.isPaid,
          initialPriceCents: post.preset.priceCents,
          initialAccentColorHex: post.preset.accentColorHex,
          editTarget: _ComposerEditTarget.card,
          startBlankCard: false,
        ),
      ),
    );
    await _loadFeed();
  }

  Future<void> _toggleVisibility(FeedPost post) async {
    try {
      await _repository.setPresetVisibility(
        presetId: post.preset.id,
        isPublic: !post.preset.isPublic,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            post.preset.isPublic
                ? 'Post set to private.'
                : 'Post set to public.',
          ),
        ),
      );
      await _loadFeed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update visibility: $e')),
      );
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deletePresetPost(post.preset.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
      await _loadFeed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (_repository.currentUser != null) return true;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  Future<void> _toggleWatchLater(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    final bool watchLater = !post.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'post',
      targetId: post.preset.id,
      watchLater: watchLater,
    );
    if (!mounted) return;
    setState(() {
      final int index = _posts.indexWhere((p) => p.preset.id == post.preset.id);
      if (index < 0) return;
      final FeedPost current = _posts[index];
      _posts[index] = FeedPost(
        preset: current.preset,
        author: current.author,
        likesCount: current.likesCount,
        dislikesCount: current.dislikesCount,
        commentsCount: current.commentsCount,
        savesCount: current.savesCount,
        myReaction: current.myReaction,
        isSaved: current.isSaved,
        isFollowingAuthor: current.isFollowingAuthor,
        viewsCount: current.viewsCount,
        isWatchLater: watchLater,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          watchLater ? 'Added to Watch Later.' : 'Removed from Watch Later.',
        ),
      ),
    );
  }

  Future<void> _copyPostLink(RenderPreset preset) async {
    await Clipboard.setData(ClipboardData(text: buildPostShareUrl(preset)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied.')),
    );
  }

  Future<void> _openPostShareUrl(
    String url, {
    required RenderPreset preset,
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyPostLink(preset);
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openPostShareSheet(FeedPost post) async {
    final String link = buildPostShareUrl(post.preset);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle:
                  Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _copyPostLink(post.preset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://t.me/share/url?url=$encodedLink',
                  preset: post.preset,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                  preset: post.preset,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://wa.me/?text=$encodedLink',
                  preset: post.preset,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://www.instagram.com/',
                  preset: post.preset,
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Snapchat'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openPostShareUrl(
                  'https://www.snapchat.com/',
                  preset: post.preset,
                  copyLinkFirst: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportPost(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    const List<String> reasons = <String>[
      'Spam',
      'Harassment',
      'Violence',
      'Adult content',
      'Misinformation',
    ];
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final reason in reasons)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _repository.submitReport(
      targetType: 'post',
      targetId: post.preset.id,
      reason: reason.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
  }

  Future<void> _notInterestedInPost(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'post',
      targetId: post.preset.id,
      excluded: true,
    );
    if (!mounted) return;
    setState(() => _posts.removeWhere((p) => p.preset.id == post.preset.id));
  }

  Future<void> _dontRecommendUser(FeedPost post) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'user',
      targetId: post.preset.userId,
      excluded: true,
    );
    if (!mounted) return;
    setState(
        () => _posts.removeWhere((p) => p.preset.userId == post.preset.userId));
  }

  List<FeedPost> _postsForSelectedChip() {
    final List<FeedPost> items = List<FeedPost>.from(_posts);
    switch (_selectedHomeChip) {
      case 'Most Viewed':
        items.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'Most Liked':
        items.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'Trending':
        items.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        break;
      case 'Most Used Hashtags':
        items.sort(
            (a, b) => b.preset.tags.length.compareTo(a.preset.tags.length));
        break;
      case 'Viral':
        items.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        break;
      case 'FYP':
      case 'All':
      default:
        break;
    }
    return items;
  }

  Widget _buildHomeChipRail(ColorScheme cs) {
    return SizedBox(
      height: _chipRailHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _homeFeedChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final String chip = _homeFeedChips[index];
          final bool selected = chip == _selectedHomeChip;
          return ChoiceChip(
            selected: selected,
            label: Text(
              chip,
              style: TextStyle(
                color: selected ? Colors.black : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            onSelected: (_) => setState(() => _selectedHomeChip = chip),
            selectedColor: Colors.white,
            backgroundColor: Colors.transparent,
            checkmarkColor: Colors.black,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<FeedPost> visiblePosts = _postsForSelectedChip();
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading feed...');
    }

    if (_error != null) {
      return QueryRetryPane(
        title: _error,
        offline: _isOfflineErrorText(_error!),
        onRetry: _loadFeed,
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadFeed,
          icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
          label: Text(
            'Feed is empty. Refresh',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Stack(
      children: [
        const Positioned.fill(child: _GridWallpaperBackdrop()),
        Positioned.fill(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                widget.onScrollDirection(false);
              } else if (notification.direction == ScrollDirection.forward ||
                  notification.metrics.pixels <= 1) {
                widget.onScrollDirection(true);
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                int crossAxisCount = 1;
                if (width >= 1150) {
                  crossAxisCount = 3;
                } else if (width >= 760) {
                  crossAxisCount = 2;
                }
                final _SvgGridLayoutSpec gridSpec = _svgGridLayoutSpec(
                  viewportWidth: width,
                  crossAxisCount: crossAxisCount,
                );

                return GridView.builder(
                  padding: const EdgeInsets.only(
                    top: _chipRailTop + _chipRailHeight,
                  ),
                  itemCount: visiblePosts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpec.crossAxisSpacing,
                    mainAxisSpacing: gridSpec.mainAxisSpacing,
                    childAspectRatio: _feedGridCardAspectRatio(
                      width: width,
                      crossAxisCount: crossAxisCount,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final post = visiblePosts[index];
                    final bool mine =
                        _repository.currentUser?.id == post.preset.userId;
                    return _FeedTile(
                      post: post,
                      onTap: () => _openPost(post),
                      onOpenAuthorProfile: () =>
                          _openPublicProfileRoute(context, post.author),
                      isMine: mine,
                      onEdit: mine ? () => _openPostEditor(post) : null,
                      onToggleVisibility:
                          mine ? () => _toggleVisibility(post) : null,
                      onDelete: mine ? () => _deletePost(post) : null,
                      onWatchLater: () => _toggleWatchLater(post),
                      onShare: () => _openPostShareSheet(post),
                      onReport: () => _reportPost(post),
                      onNotInterested: () => _notInterestedInPost(post),
                      onDontRecommend: () => _dontRecommendUser(post),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Positioned(
          top: _chipRailTop,
          left: 14,
          right: 14,
          child: _buildHomeChipRail(cs),
        ),
      ],
    );
  }
}

class _CollectionTab extends StatefulWidget {
  const _CollectionTab({
    super.key,
    required this.topInset,
    required this.onScrollDirection,
  });

  final double topInset;
  final ValueChanged<bool> onScrollDirection;

  @override
  State<_CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<_CollectionTab> {
  final AppRepository _repository = AppRepository.instance;
  static const double _chipRailTop = 56;
  static const double _chipRailHeight = 38;
  static const List<String> _collectionChips = <String>[
    'All',
    'FYP',
    'Trending',
    'Most Used Hashtags',
    'Most Liked',
    'Most Viewed',
    'Viral',
  ];

  bool _loading = true;
  String? _error;
  final List<CollectionSummary> _collections = <CollectionSummary>[];
  String _selectedCollectionChip = _collectionChips.first;

  double _collectionGridCardAspectRatio({
    required double width,
    required int crossAxisCount,
  }) {
    return _kGridPreviewAspectRatio;
  }

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, CollectionSummary> merged =
          <String, CollectionSummary>{};
      final published = await QueryGuard.run(
        () => _repository.fetchPublishedCollections(limit: 120),
      );
      for (final c in published) {
        merged[c.id] = c;
      }
      if (_repository.currentUser != null) {
        final mine = await QueryGuard.run(
          () => _repository.fetchCollectionsForCurrentUser(),
        );
        for (final c in mine) {
          merged[c.id] = c;
        }
      }
      final collections = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _collections
          ..clear()
          ..addAll(collections);
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _openCollection(CollectionSummary summary) async {
    await _pushHeroRoute(
      context,
      builder: (_) => _CollectionDetailPage(
        collectionId: summary.id,
        initialSummary: summary,
      ),
      name: buildCollectionRoutePathForSummary(summary),
    );
    await _loadCollections();
  }

  Future<void> _toggleCollectionVisibility(CollectionSummary summary) async {
    try {
      await _repository.setCollectionPublished(
        collectionId: summary.id,
        published: !summary.published,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary.published
                ? 'Collection set to private.'
                : 'Collection set to public.',
          ),
        ),
      );
      await _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update collection: $e')),
      );
    }
  }

  Future<void> _deleteCollection(CollectionSummary summary) async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete collection?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deleteCollection(summary.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted.')),
      );
      await _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _updateCollection(CollectionSummary summary) async {
    CollectionDetail? detail;
    try {
      detail = await QueryGuard.run(
        () => _repository.fetchCollectionById(summary.id),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Retry.')),
      );
      return;
    }
    if (!mounted || detail == null) return;
    final CollectionDetail resolvedDetail = detail;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        settings:
            const RouteSettings(name: '/post/editor/collection-card-update'),
        builder: (_) => _PostCardComposerPage.collection(
          collectionId: summary.id,
          collectionName: summary.name,
          collectionDescription: summary.description,
          tags: summary.tags,
          mentionUserIds: summary.mentionUserIds,
          published: summary.published,
          initialIsPaid: summary.isPaid,
          initialPriceCents: summary.priceCents,
          initialAccentColorHex: summary.accentColorHex,
          initialCardPayload: summary.thumbnailPayload,
          initialCardMode: summary.thumbnailMode,
          editTarget: _ComposerEditTarget.card,
          startBlankCard: false,
          items: resolvedDetail.items
              .map(
                (item) => CollectionDraftItem(
                  mode: item.mode,
                  name: item.name,
                  snapshot: item.snapshot,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (updated == true) {
      await _loadCollections();
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (_repository.currentUser != null) return true;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  Future<void> _toggleCollectionWatchLater(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    final bool watchLater = !summary.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'collection',
      targetId: summary.id,
      watchLater: watchLater,
    );
    if (!mounted) return;
    setState(() {
      final int index = _collections.indexWhere((c) => c.id == summary.id);
      if (index < 0) return;
      final CollectionSummary current = _collections[index];
      _collections[index] = CollectionSummary(
        id: current.id,
        shareId: current.shareId,
        userId: current.userId,
        name: current.name,
        description: current.description,
        tags: current.tags,
        mentionUserIds: current.mentionUserIds,
        published: current.published,
        thumbnailPayload: current.thumbnailPayload,
        thumbnailMode: current.thumbnailMode,
        itemsCount: current.itemsCount,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
        firstItem: current.firstItem,
        author: current.author,
        likesCount: current.likesCount,
        dislikesCount: current.dislikesCount,
        commentsCount: current.commentsCount,
        savesCount: current.savesCount,
        viewsCount: current.viewsCount,
        myReaction: current.myReaction,
        isSavedByCurrentUser: current.isSavedByCurrentUser,
        isWatchLater: watchLater,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          watchLater ? 'Added to Watch Later.' : 'Removed from Watch Later.',
        ),
      ),
    );
  }

  Future<void> _copyCollectionLink(CollectionSummary summary) async {
    await Clipboard.setData(
        ClipboardData(text: buildCollectionShareUrl(summary)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection link copied.')),
    );
  }

  Future<void> _openCollectionShareUrl(
    String url, {
    required CollectionSummary summary,
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyCollectionLink(summary);
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openCollectionShareSheet(CollectionSummary summary) async {
    final String link = buildCollectionShareUrl(summary);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle:
                  Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _copyCollectionLink(summary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://t.me/share/url?url=$encodedLink',
                  summary: summary,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                  summary: summary,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://wa.me/?text=$encodedLink',
                  summary: summary,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.instagram.com/',
                  summary: summary,
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Snapchat'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.snapchat.com/',
                  summary: summary,
                  copyLinkFirst: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportCollection(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    if (!mounted) return;
    const List<String> reasons = <String>[
      'Spam',
      'Harassment',
      'Violence',
      'Adult content',
      'Misinformation',
    ];
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final reason in reasons)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _repository.submitReport(
      targetType: 'collection',
      targetId: summary.id,
      reason: reason.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
  }

  Future<void> _notInterestedInCollection(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'collection',
      targetId: summary.id,
      excluded: true,
    );
    if (!mounted) return;
    setState(() => _collections.removeWhere((c) => c.id == summary.id));
  }

  Future<void> _dontRecommendCollectionUser(CollectionSummary summary) async {
    if (!await _ensureSignedIn()) return;
    await _repository.setRecommendationExclusion(
      exclusionType: 'user',
      targetId: summary.userId,
      excluded: true,
    );
    if (!mounted) return;
    setState(
      () => _collections.removeWhere((c) => c.userId == summary.userId),
    );
  }

  List<CollectionSummary> _collectionsForSelectedChip() {
    final List<CollectionSummary> items =
        List<CollectionSummary>.from(_collections);
    switch (_selectedCollectionChip) {
      case 'Most Viewed':
        items.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case 'Most Liked':
        items.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case 'Trending':
        items.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        break;
      case 'Most Used Hashtags':
        items.sort((a, b) => b.tags.length.compareTo(a.tags.length));
        break;
      case 'Viral':
        items.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        break;
      case 'FYP':
      case 'All':
      default:
        break;
    }
    return items;
  }

  Widget _buildCollectionChipRail(ColorScheme cs) {
    return SizedBox(
      height: _chipRailHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _collectionChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final String chip = _collectionChips[index];
          final bool selected = chip == _selectedCollectionChip;
          return ChoiceChip(
            selected: selected,
            label: Text(
              chip,
              style: TextStyle(
                color: selected ? Colors.black : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            onSelected: (_) => setState(() => _selectedCollectionChip = chip),
            selectedColor: Colors.white,
            backgroundColor: Colors.transparent,
            checkmarkColor: Colors.black,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<CollectionSummary> visibleCollections =
        _collectionsForSelectedChip();
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading collections...');
    }

    if (_error != null) {
      return QueryRetryPane(
        title: _error,
        offline: _isOfflineErrorText(_error!),
        onRetry: _loadCollections,
      );
    }

    if (_collections.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadCollections,
          icon: Icon(Icons.refresh, color: cs.onSurfaceVariant),
          label: Text(
            'No collections yet. Refresh',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Stack(
      children: [
        const Positioned.fill(child: _GridWallpaperBackdrop()),
        Positioned.fill(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                widget.onScrollDirection(false);
              } else if (notification.direction == ScrollDirection.forward ||
                  notification.metrics.pixels <= 1) {
                widget.onScrollDirection(true);
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount = 1;
                if (width >= 1150) {
                  crossAxisCount = 3;
                } else if (width >= 760) {
                  crossAxisCount = 2;
                }
                final _SvgGridLayoutSpec gridSpec = _svgGridLayoutSpec(
                  viewportWidth: width,
                  crossAxisCount: crossAxisCount,
                );

                return GridView.builder(
                  padding: const EdgeInsets.only(
                    top: _chipRailTop + _chipRailHeight,
                  ),
                  itemCount: visibleCollections.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: gridSpec.crossAxisSpacing,
                    mainAxisSpacing: gridSpec.mainAxisSpacing,
                    childAspectRatio: _collectionGridCardAspectRatio(
                      width: width,
                      crossAxisCount: crossAxisCount,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final summary = visibleCollections[index];
                    final bool mine =
                        _repository.currentUser?.id == summary.userId;
                    return _CollectionFeedTile(
                      summary: summary,
                      onTap: () => _openCollection(summary),
                      onOpenAuthorProfile: () =>
                          _openPublicProfileRoute(context, summary.author),
                      isMine: mine,
                      onToggleVisibility: mine
                          ? () => _toggleCollectionVisibility(summary)
                          : null,
                      onDelete: mine ? () => _deleteCollection(summary) : null,
                      onUpdate: mine ? () => _updateCollection(summary) : null,
                      onWatchLater: () => _toggleCollectionWatchLater(summary),
                      onShare: () => _openCollectionShareSheet(summary),
                      onReport: () => _reportCollection(summary),
                      onNotInterested: () =>
                          _notInterestedInCollection(summary),
                      onDontRecommend: () =>
                          _dontRecommendCollectionUser(summary),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Positioned(
          top: _chipRailTop,
          left: 14,
          right: 14,
          child: _buildCollectionChipRail(cs),
        ),
      ],
    );
  }
}

class _CollectionFeedTile extends StatelessWidget {
  const _CollectionFeedTile({
    required this.summary,
    required this.onTap,
    required this.onOpenAuthorProfile,
    required this.isMine,
    required this.onWatchLater,
    required this.onShare,
    required this.onReport,
    required this.onNotInterested,
    required this.onDontRecommend,
    this.onUpdate,
    this.onDelete,
    this.onToggleVisibility,
  });

  final CollectionSummary summary;
  final VoidCallback onTap;
  final VoidCallback onOpenAuthorProfile;
  final bool isMine;
  final VoidCallback onWatchLater;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onNotInterested;
  final VoidCallback onDontRecommend;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = summary.firstItem;
    final String previewMode = summary.thumbnailMode ?? item?.mode ?? '2d';
    final Map<String, dynamic> previewPayload =
        summary.thumbnailPayload.isNotEmpty
            ? summary.thumbnailPayload
            : (item?.snapshot ?? const <String, dynamic>{});
    final ImageProvider? avatarImage =
        (summary.author?.avatarUrl ?? '').trim().isNotEmpty
            ? NetworkImage(summary.author!.avatarUrl!.trim())
            : null;
    final String heroTag = 'collection-detail-hero-${summary.id}-0';
    final List<_BlurMenuEntry<String>> menuItems = <_BlurMenuEntry<String>>[
      _BlurMenuEntry.item(
        value: 'watch_later',
        label: summary.isWatchLater ? 'Remove from Watch Later' : 'Watch Later',
      ),
      const _BlurMenuEntry.item(value: 'share', label: 'Share'),
      const _BlurMenuEntry.item(value: 'report', label: 'Report'),
      const _BlurMenuEntry.item(
          value: 'not_interested', label: 'Not interested'),
      const _BlurMenuEntry.item(
        value: 'dont_recommend',
        label: 'Don\'t recommend channel',
      ),
    ];
    if (isMine) {
      menuItems.addAll(
        [
          const _BlurMenuEntry.divider(),
          const _BlurMenuEntry.item(value: 'update', label: 'Update'),
          _BlurMenuEntry.item(
            value: 'visibility',
            label: summary.published ? 'Make Private' : 'Make Public',
          ),
          const _BlurMenuEntry.item(value: 'delete', label: 'Delete'),
        ],
      );
    }
    final String metaText =
        '${_friendlyCount(summary.viewsCount)} views • ${_friendlyTime(summary.createdAt)} • ${summary.itemsCount} items';
    final Color accentColor = _cardAccentColorFromHex(summary.accentColorHex);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: _kGridPreviewAspectRatio,
          child: _GridCardPreviewSurface(
            heroTag: heroTag,
            mode: previewMode,
            payload: previewPayload,
            title:
                summary.name.isNotEmpty ? summary.name : 'Untitled collection',
            verticalUsername: _verticalUsernameForCard(summary.author),
            priceText: _cardPriceLabel(
              isPaid: summary.isPaid,
              priceCents: summary.priceCents,
              viewerHasPaid: summary.viewerHasPaid,
            ),
            avatarImage: avatarImage,
            isVerified: summary.author?.isVerified == true,
            accentColor: accentColor,
            metaText: metaText,
            showCollectionCount: true,
            collectionCountText: '${summary.itemsCount}',
            menuItems: menuItems,
            onAvatarTap: onOpenAuthorProfile,
            onMenuSelected: (value) {
              if (value == 'watch_later') onWatchLater();
              if (value == 'share') onShare();
              if (value == 'report') onReport();
              if (value == 'not_interested') onNotInterested();
              if (value == 'dont_recommend') onDontRecommend();
              if (value == 'update') onUpdate?.call();
              if (value == 'visibility') onToggleVisibility?.call();
              if (value == 'delete') onDelete?.call();
            },
            emptyChild: Container(
              color: cs.surfaceContainerLow,
              child: Center(
                child: Icon(
                  Icons.collections_bookmark_outlined,
                  color: cs.onSurfaceVariant,
                  size: 34,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionGridCard extends StatelessWidget {
  const _SuggestionGridCard({
    required this.heroTag,
    required this.mode,
    required this.payload,
    required this.title,
    required this.author,
    required this.metaText,
    required this.priceText,
    required this.isVerified,
    required this.accentColor,
    this.showCollectionCount = false,
    this.collectionCountText = '',
    required this.onTap,
    this.onAvatarTap,
    this.avatarImage,
  });

  final String heroTag;
  final String mode;
  final Map<String, dynamic> payload;
  final String title;
  final String author;
  final String metaText;
  final String priceText;
  final bool isVerified;
  final Color accentColor;
  final bool showCollectionCount;
  final String collectionCountText;
  final VoidCallback onTap;
  final VoidCallback? onAvatarTap;
  final ImageProvider? avatarImage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: _kGridPreviewAspectRatio,
        child: _GridCardPreviewSurface(
          heroTag: heroTag,
          mode: mode,
          payload: payload,
          title: title,
          verticalUsername: author.replaceAll('@', '').replaceAll(' ', ''),
          priceText: priceText,
          avatarImage: avatarImage,
          isVerified: isVerified,
          accentColor: accentColor,
          metaText: metaText,
          showCollectionCount: showCollectionCount,
          collectionCountText: collectionCountText,
          menuItems: const <_BlurMenuEntry<String>>[],
          onMenuSelected: (_) {},
          onAvatarTap: onAvatarTap,
        ),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.post,
    required this.onTap,
    required this.onOpenAuthorProfile,
    required this.isMine,
    required this.onWatchLater,
    required this.onShare,
    required this.onReport,
    required this.onNotInterested,
    required this.onDontRecommend,
    this.onEdit,
    this.onDelete,
    this.onToggleVisibility,
  });

  final FeedPost post;
  final VoidCallback onTap;
  final VoidCallback onOpenAuthorProfile;
  final bool isMine;
  final VoidCallback onWatchLater;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onNotInterested;
  final VoidCallback onDontRecommend;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final String previewMode = post.preset.thumbnailMode ?? post.preset.mode;
    final Map<String, dynamic> previewPayload =
        post.preset.thumbnailPayload.isNotEmpty
            ? post.preset.thumbnailPayload
            : post.preset.payload;
    final ImageProvider? avatarImage =
        (post.author?.avatarUrl ?? '').trim().isNotEmpty
            ? NetworkImage(post.author!.avatarUrl!.trim())
            : null;
    final String heroTag = 'post-detail-hero-${post.preset.id}';
    final List<_BlurMenuEntry<String>> menuItems = <_BlurMenuEntry<String>>[
      _BlurMenuEntry.item(
        value: 'watch_later',
        label: post.isWatchLater ? 'Remove from Watch Later' : 'Watch Later',
      ),
      const _BlurMenuEntry.item(value: 'share', label: 'Share'),
      const _BlurMenuEntry.item(value: 'report', label: 'Report'),
      const _BlurMenuEntry.item(
          value: 'not_interested', label: 'Not interested'),
      const _BlurMenuEntry.item(
        value: 'dont_recommend',
        label: 'Don\'t recommend channel',
      ),
    ];
    if (isMine) {
      menuItems.addAll(
        [
          const _BlurMenuEntry.divider(),
          const _BlurMenuEntry.item(value: 'edit', label: 'Update'),
          _BlurMenuEntry.item(
            value: 'visibility',
            label: post.preset.isPublic ? 'Make Private' : 'Make Public',
          ),
          const _BlurMenuEntry.item(value: 'delete', label: 'Delete'),
        ],
      );
    }
    final String metaText =
        '${_friendlyCount(post.viewsCount)} views • ${_friendlyTime(post.preset.createdAt)}';
    final Color accentColor =
        _cardAccentColorFromHex(post.preset.accentColorHex);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: _kGridPreviewAspectRatio,
          child: _GridCardPreviewSurface(
            heroTag: heroTag,
            mode: previewMode,
            payload: previewPayload,
            title: post.preset.title.isNotEmpty
                ? post.preset.title
                : post.preset.name,
            verticalUsername: _verticalUsernameForCard(post.author),
            priceText: _cardPriceLabel(
              isPaid: post.preset.isPaid,
              priceCents: post.preset.priceCents,
              viewerHasPaid: post.preset.viewerHasPaid,
            ),
            avatarImage: avatarImage,
            isVerified: post.author?.isVerified == true,
            accentColor: accentColor,
            metaText: metaText,
            showCollectionCount: false,
            collectionCountText: '',
            menuItems: menuItems,
            onAvatarTap: onOpenAuthorProfile,
            onMenuSelected: (value) {
              if (value == 'watch_later') onWatchLater();
              if (value == 'share') onShare();
              if (value == 'report') onReport();
              if (value == 'not_interested') onNotInterested();
              if (value == 'dont_recommend') onDontRecommend();
              if (value == 'edit') onEdit?.call();
              if (value == 'visibility') onToggleVisibility?.call();
              if (value == 'delete') onDelete?.call();
            },
          ),
        ),
      ),
    );
  }
}

class _SharedPresetPreview extends StatelessWidget {
  const _SharedPresetPreview({
    required this.mode,
    required this.payload,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.clipper,
    this.emptyChild,
    this.fit = BoxFit.cover,
  });

  final String mode;
  final Map<String, dynamic> payload;
  final BorderRadius borderRadius;
  final CustomClipper<Path>? clipper;
  final Widget? emptyChild;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String imageUrl =
        imageUrlFromPayload(payload, fallbackMode: mode)?.trim() ?? '';
    final Widget base = imageUrl.isEmpty
        ? (emptyChild != null
            ? SizedBox.expand(child: emptyChild!)
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                ),
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
              ))
        : PresetViewer(
            mode: mode,
            payload: payload,
            fit: fit,
          );
    if (clipper != null) {
      return ClipPath(
        clipper: clipper!,
        clipBehavior: Clip.antiAlias,
        child: base,
      );
    }
    return ClipRRect(borderRadius: borderRadius, child: base);
  }
}

Future<void> _openDetailFullscreenViewer(
  BuildContext context, {
  required String heroTag,
  required String mode,
  required Map<String, dynamic> payload,
}) async {
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/post/detail/fullscreen'),
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320 + 40),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _DetailFullscreenViewerPage(
          heroTag: heroTag,
          mode: mode,
          payload: payload,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    ),
  );
}

class _DetailFullscreenViewerPage extends StatelessWidget {
  const _DetailFullscreenViewerPage({
    required this.heroTag,
    required this.mode,
    required this.payload,
  });

  final String heroTag;
  final String mode;
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.maybePop(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyF): () {
          Navigator.maybePop(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF101213),
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => Navigator.pop(context),
                  child: Hero(
                    tag: heroTag,
                    createRectTween: (begin, end) =>
                        _EaseInOutRectTween(begin: begin, end: end),
                    child: _SharedPresetPreview(
                      mode: mode,
                      payload: payload,
                      borderRadius: BorderRadius.zero,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 14,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.fullscreen_exit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetDetailPage extends StatefulWidget {
  const _PresetDetailPage({required this.initialPost});

  final FeedPost initialPost;

  @override
  State<_PresetDetailPage> createState() => _PresetDetailPageState();
}

class _PresetDetailPageState extends State<_PresetDetailPage> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _immersiveFocusNode =
      FocusNode(debugLabel: 'detail-immersive-focus');
  final ScrollController _leftPaneScrollController = ScrollController();
  final ScrollController _rightPaneScrollController = ScrollController();
  final ScrollController _chipRailScrollController = ScrollController();
  static const List<String> _suggestionFilters = <String>[
    'All',
    'FromUser',
    'Related',
    'FYP',
    'Trending',
    'MostUsedHashtags',
    'MostLiked',
    'MostViewed',
    'Viral',
  ];

  late FeedPost _post;
  bool _loadingComments = true;
  bool _sendingComment = false;
  bool _commentsOpen = false;
  bool _loadingSuggestions = false;
  bool _descriptionExpanded = false;
  List<PresetComment> _comments = const <PresetComment>[];
  List<FeedPost> _suggestedPosts = const <FeedPost>[];
  String _suggestionFilter = _suggestionFilters.first;

  bool get _mine =>
      _repository.currentUser != null &&
      _repository.currentUser!.id == _post.preset.userId;

  Future<bool> _requireAuthAction() async {
    if (_repository.currentUser != null) return true;
    if (!mounted) return false;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loadComments();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _immersiveFocusNode.dispose();
    _commentController.dispose();
    _leftPaneScrollController.dispose();
    _rightPaneScrollController.dispose();
    _chipRailScrollController.dispose();
    super.dispose();
  }

  String get _detailHeroTag => 'post-detail-hero-${_post.preset.id}';

  Future<void> _openFullscreenViewer() async {
    await _openDetailFullscreenViewer(
      context,
      heroTag: _detailHeroTag,
      mode: _post.preset.mode,
      payload: _post.preset.payload,
    );
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await QueryGuard.run(
        () => _repository.fetchPresetComments(_post.preset.id),
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
        _post = FeedPost(
          preset: _post.preset,
          author: _post.author,
          likesCount: _post.likesCount,
          dislikesCount: _post.dislikesCount,
          commentsCount: comments.length,
          savesCount: _post.savesCount,
          myReaction: _post.myReaction,
          isSaved: _post.isSaved,
          isFollowingAuthor: _post.isFollowingAuthor,
          viewsCount: _post.viewsCount,
          isWatchLater: _post.isWatchLater,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _toggleReaction(int value) async {
    if (!await _requireAuthAction()) return;
    final int newReaction = _post.myReaction == value ? 0 : value;
    await _repository.setReaction(
        presetId: _post.preset.id, reaction: newReaction);
    if (!mounted) return;

    int likes = _post.likesCount;
    int dislikes = _post.dislikesCount;
    if (_post.myReaction == 1) likes = (likes - 1).clamp(0, 999999999);
    if (_post.myReaction == -1) dislikes = (dislikes - 1).clamp(0, 999999999);
    if (newReaction == 1) likes += 1;
    if (newReaction == -1) dislikes += 1;

    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: likes,
        dislikesCount: dislikes,
        commentsCount: _post.commentsCount,
        savesCount: _post.savesCount,
        myReaction: newReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _toggleSave() async {
    if (!await _requireAuthAction()) return;
    final bool shouldSave = !_post.isSaved;
    await _repository.toggleSavePreset(_post.preset.id, save: shouldSave);
    if (!mounted) return;
    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: _post.commentsCount,
        savesCount: shouldSave
            ? _post.savesCount + 1
            : (_post.savesCount - 1).clamp(0, 999999999),
        myReaction: _post.myReaction,
        isSaved: shouldSave,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _toggleWatchLater() async {
    if (!await _requireAuthAction()) return;
    final bool shouldWatchLater = !_post.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'post',
      targetId: _post.preset.id,
      watchLater: shouldWatchLater,
    );
    if (!mounted) return;
    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: _post.commentsCount,
        savesCount: _post.savesCount,
        myReaction: _post.myReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: _post.isFollowingAuthor,
        viewsCount: _post.viewsCount,
        isWatchLater: shouldWatchLater,
      );
    });
  }

  Future<void> _toggleFollow() async {
    if (!await _requireAuthAction()) return;
    final bool follow = !_post.isFollowingAuthor;
    await _repository.setFollow(
      targetUserId: _post.preset.userId,
      follow: follow,
    );
    if (!mounted) return;
    setState(() {
      _post = FeedPost(
        preset: _post.preset,
        author: _post.author,
        likesCount: _post.likesCount,
        dislikesCount: _post.dislikesCount,
        commentsCount: _post.commentsCount,
        savesCount: _post.savesCount,
        myReaction: _post.myReaction,
        isSaved: _post.isSaved,
        isFollowingAuthor: follow,
        viewsCount: _post.viewsCount,
        isWatchLater: _post.isWatchLater,
      );
    });
  }

  Future<void> _shareToUser() async {
    if (!await _requireAuthAction()) return;
    if (!mounted) return;
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Share Preset to User'),
    );
    if (profile == null) return;

    try {
      final chatId = await _repository.createOrGetDirectChat(profile.userId);
      await _repository.sendChatMessage(
        chatId: chatId,
        body: 'Shared a preset',
        sharedPresetId: _post.preset.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset shared successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _copyPostLinkToClipboard() async {
    final String link = buildPostShareUrl(_post.preset);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied to clipboard.')),
    );
  }

  Future<void> _openShareUrl(
    String url, {
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyPostLinkToClipboard();
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openShareSheet() async {
    final String link = buildPostShareUrl(_post.preset);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Share to user'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                subtitle:
                    Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(context);
                  _copyPostLinkToClipboard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Telegram'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl('https://t.me/share/url?url=$encodedLink');
                },
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Facebook'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                    'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl('https://wa.me/?text=$encodedLink');
                },
              ),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('X (Twitter)'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                      'https://twitter.com/intent/tweet?url=$encodedLink');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Instagram'),
                subtitle: const Text('Copies link first'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                    'https://www.instagram.com/',
                    copyLinkFirst: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_front_outlined),
                title: const Text('Snapchat'),
                subtitle: const Text('Copies link first'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                    'https://www.snapchat.com/',
                    copyLinkFirst: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reddit'),
                onTap: () {
                  Navigator.pop(context);
                  _openShareUrl(
                      'https://www.reddit.com/submit?url=$encodedLink');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendComment() async {
    if (!await _requireAuthAction()) return;
    final String text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    await _repository.addPresetComment(
        presetId: _post.preset.id, content: text);
    if (!mounted) return;
    _commentController.clear();
    setState(() => _sendingComment = false);
    await _loadComments();
  }

  String _displayFilterName(String filter) {
    if (filter == 'FromUser') {
      final username = _post.author?.username?.trim();
      if (username != null && username.isNotEmpty) {
        return 'From @$username';
      }
      return 'From creator';
    }
    switch (filter) {
      case 'MostUsedHashtags':
        return 'Most Used Hashtags';
      case 'MostLiked':
        return 'Most Liked';
      case 'MostViewed':
        return 'Most Viewed';
      default:
        return filter;
    }
  }

  Future<void> _loadSuggestions() async {
    if (_loadingSuggestions) return;
    setState(() => _loadingSuggestions = true);
    try {
      final posts = await QueryGuard.run(
        () => _repository.fetchFeedPosts(limit: 120),
      );
      if (!mounted) return;
      setState(() {
        _suggestedPosts = posts;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  List<FeedPost> _filteredSuggestions() {
    final List<FeedPost> candidates = _suggestedPosts
        .where((item) => item.preset.id != _post.preset.id)
        .toList();
    final String currentUserId = _post.preset.userId;
    final Set<String> currentTags =
        _post.preset.tags.map((e) => e.toLowerCase()).toSet();
    switch (_suggestionFilter) {
      case 'FromUser':
        return candidates
            .where((item) => item.preset.userId == currentUserId)
            .toList();
      case 'Related':
        return candidates.where((item) {
          final tags = item.preset.tags.map((e) => e.toLowerCase()).toSet();
          return tags.intersection(currentTags).isNotEmpty;
        }).toList();
      case 'Trending':
        candidates.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'MostUsedHashtags':
        candidates.sort(
            (a, b) => b.preset.tags.length.compareTo(a.preset.tags.length));
        return candidates;
      case 'MostLiked':
        candidates.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        return candidates;
      case 'MostViewed':
        candidates.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        return candidates;
      case 'Viral':
        candidates.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'FYP':
      case 'All':
      default:
        return candidates;
    }
  }

  Future<void> _openSuggestedPost(FeedPost post) async {
    await _repository.recordPresetView(post.preset.id);
    if (!mounted) return;
    await _pushHeroRoute(
      context,
      builder: (_) => _PresetDetailPage(initialPost: post),
      name: buildPostRoutePathForPreset(post.preset),
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String heroTag = _detailHeroTag;
    final String previewMode = _post.preset.mode;
    final Map<String, dynamic> previewPayload = _post.preset.payload;
    final List<FeedPost> suggestions = _filteredSuggestions();
    final String title =
        _post.preset.title.isNotEmpty ? _post.preset.title : _post.preset.name;

    void scrollChipRailBy(double delta) {
      if (!_chipRailScrollController.hasClients) return;
      final position = _chipRailScrollController.position;
      final double target = (_chipRailScrollController.offset + delta)
          .clamp(0.0, position.maxScrollExtent);
      _chipRailScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
      );
    }

    Widget buildEngagementRail() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _engagementButton(
              icon: _post.myReaction == 1
                  ? Icons.thumb_up_alt
                  : Icons.thumb_up_alt_outlined,
              active: _post.myReaction == 1,
              activeColor: cs.primary,
              label: _friendlyCount(_post.likesCount),
              onTap: () => _toggleReaction(1),
            ),
            _engagementButton(
              icon: _post.myReaction == -1
                  ? Icons.thumb_down_alt
                  : Icons.thumb_down_alt_outlined,
              active: _post.myReaction == -1,
              activeColor: Colors.redAccent,
              label: _friendlyCount(_post.dislikesCount),
              onTap: () => _toggleReaction(-1),
            ),
            _engagementButton(
              icon: Icons.send_outlined,
              active: false,
              activeColor: cs.primary,
              label: '',
              onTap: _openShareSheet,
            ),
            _engagementButton(
              icon: Icons.mode_comment_outlined,
              active: _commentsOpen,
              activeColor: cs.primary,
              label: _friendlyCount(_post.commentsCount),
              onTap: () => setState(() => _commentsOpen = true),
            ),
            _engagementButton(
              icon: _post.isSaved ? Icons.bookmark : Icons.bookmark_border,
              active: _post.isSaved,
              activeColor: Colors.amberAccent,
              label: _friendlyCount(_post.savesCount),
              onTap: _toggleSave,
            ),
            _engagementButton(
              icon: _post.isWatchLater
                  ? Icons.watch_later
                  : Icons.watch_later_outlined,
              active: _post.isWatchLater,
              activeColor: Colors.tealAccent,
              label: '',
              onTap: _toggleWatchLater,
            ),
          ],
        ),
      );
    }

    Widget buildDescriptionBox() {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            setState(() => _descriptionExpanded = !_descriptionExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _descriptionExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _post.preset.description.trim().isNotEmpty
                    ? _post.preset.description
                    : 'No description provided.',
                maxLines: _descriptionExpanded ? null : 3,
                overflow: _descriptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildBelowPreviewMeta() {
      return Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 760;
              final Widget usernameCluster = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () =>
                          _openPublicProfileRoute(context, _post.author),
                      child: Text(
                        _post.author?.displayName ?? 'Unknown creator',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (!_mine) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 28,
                      child: FilledButton.tonal(
                        onPressed: _toggleFollow,
                        child: Text(
                            _post.isFollowingAuthor ? 'Following' : 'Follow'),
                      ),
                    ),
                  ],
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_friendlyCount(_post.viewsCount)} views • ${_friendlyTime(_post.preset.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (compact) ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _openPublicProfileRoute(context, _post.author),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundImage: (_post.author?.avatarUrl != null &&
                                    _post.author!.avatarUrl!.isNotEmpty)
                                ? NetworkImage(_post.author!.avatarUrl!)
                                : null,
                            child: (_post.author?.avatarUrl == null ||
                                    _post.author!.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: usernameCluster),
                      ],
                    ),
                    const SizedBox(height: 8),
                    buildEngagementRail(),
                  ] else ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _openPublicProfileRoute(context, _post.author),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundImage: (_post.author?.avatarUrl != null &&
                                    _post.author!.avatarUrl!.isNotEmpty)
                                ? NetworkImage(_post.author!.avatarUrl!)
                                : null,
                            child: (_post.author?.avatarUrl == null ||
                                    _post.author!.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(flex: 4, child: usernameCluster),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: buildEngagementRail(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  buildDescriptionBox(),
                ],
              );
            },
          ),
        ),
      );
    }

    Widget buildPreviewCard() {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            _commentsOpen ? () => setState(() => _commentsOpen = false) : null,
        onDoubleTap: _openFullscreenViewer,
        child: Hero(
          tag: heroTag,
          createRectTween: (begin, end) =>
              _EaseInOutRectTween(begin: begin, end: end),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _SharedPresetPreview(
                  mode: previewMode,
                  payload: previewPayload,
                  borderRadius: BorderRadius.circular(16),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton.filledTonal(
                  onPressed: _openFullscreenViewer,
                  icon: const Icon(Icons.fullscreen, size: 20),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildPreviewSurface() {
      return AspectRatio(
        aspectRatio: _kDetailPreviewAspectRatio,
        child: buildPreviewCard(),
      );
    }

    Widget buildFilterRail() {
      return Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          final double delta =
              event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
                  ? event.scrollDelta.dx
                  : event.scrollDelta.dy;
          if (delta.abs() < 0.1) return;
          scrollChipRailBy(delta);
        },
        child: Row(
          children: [
            IconButton(
              tooltip: 'Scroll filters left',
              onPressed: () => scrollChipRailBy(-180),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _chipRailScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      List<Widget>.generate(_suggestionFilters.length, (index) {
                    final filter = _suggestionFilters[index];
                    final selected = filter == _suggestionFilter;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == _suggestionFilters.length - 1 ? 0 : 8,
                      ),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(
                          _displayFilterName(filter),
                          style: TextStyle(
                            color: selected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: Colors.white,
                        checkmarkColor: Colors.black,
                        side: const BorderSide(color: Colors.white24),
                        onSelected: (_) =>
                            setState(() => _suggestionFilter = filter),
                      ),
                    );
                  }),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Scroll filters right',
              onPressed: () => scrollChipRailBy(180),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
    }

    Widget buildCommentsPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close comments',
                onPressed: () => setState(() => _commentsOpen = false),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loadingComments
                ? const _TopEdgeLoadingPane(
                    label: 'Loading comments...',
                    backgroundColor: Colors.transparent,
                    minHeight: 2,
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68)),
                        ),
                      )
                    : ListView.builder(
                        controller: _rightPaneScrollController,
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${c.author?.displayName ?? 'User'}: ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: c.content),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sendingComment ? null : _sendComment,
                child: Text(_sendingComment ? '...' : 'Send'),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildSuggestionsPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox.shrink(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _loadingSuggestions
                      ? const _TopEdgeLoadingPane(
                          label: 'Loading suggestions...',
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        )
                      : ListView.builder(
                          controller: _rightPaneScrollController,
                          padding: EdgeInsets.zero,
                          itemCount: suggestions.length.clamp(0, 24),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            final String mode =
                                item.preset.thumbnailMode ?? item.preset.mode;
                            final Map<String, dynamic> payload =
                                item.preset.thumbnailPayload.isNotEmpty
                                    ? item.preset.thumbnailPayload
                                    : item.preset.payload;
                            return _SuggestionGridCard(
                              heroTag: 'post-detail-hero-${item.preset.id}',
                              mode: mode,
                              payload: payload,
                              title: item.preset.title.isNotEmpty
                                  ? item.preset.title
                                  : item.preset.name,
                              author:
                                  item.author?.displayName ?? 'Unknown creator',
                              metaText:
                                  '${_friendlyCount(item.viewsCount)} views • ${_friendlyTime(item.preset.createdAt)}',
                              priceText: _cardPriceLabel(
                                isPaid: item.preset.isPaid,
                                priceCents: item.preset.priceCents,
                                viewerHasPaid: item.preset.viewerHasPaid,
                              ),
                              isVerified: item.author?.isVerified == true,
                              accentColor: _cardAccentColorFromHex(
                                item.preset.accentColorHex,
                              ),
                              avatarImage: (item.author?.avatarUrl ?? '')
                                      .trim()
                                      .isNotEmpty
                                  ? NetworkImage(
                                      item.author!.avatarUrl!.trim(),
                                    )
                                  : null,
                              onAvatarTap: () =>
                                  _openPublicProfileRoute(context, item.author),
                              onTap: () => _openSuggestedPost(item),
                            );
                          },
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: buildFilterRail(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildRightPanel({
      required bool desktop,
      required double viewportHeight,
      required double panelWidth,
    }) {
      final Widget body =
          _commentsOpen ? buildCommentsPanel() : buildSuggestionsPanel();
      return SizedBox(
        width: desktop ? panelWidth : double.infinity,
        height: desktop ? viewportHeight : 640,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101213),
      body: KeyboardListener(
        autofocus: true,
        focusNode: _immersiveFocusNode,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.keyF) {
            _openFullscreenViewer();
          }
        },
        child: LayoutBuilder(
          key: const ValueKey<String>('compact-post-detail'),
          builder: (context, viewport) {
            final bool desktop = viewport.maxWidth >= 1140;
            final double contentWidth =
                viewport.maxWidth - (_kDetailContentPadding * 2);
            final double previewWidth = _detailPreviewWidth(
              contentWidth: contentWidth,
              desktop: desktop,
            );
            final double sideWidth = _detailSidePanelWidth(
              contentWidth: contentWidth,
              desktop: desktop,
            );
            final Widget leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildPreviewSurface(),
                buildBelowPreviewMeta(),
                const SizedBox(height: 16),
              ],
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: _CardScopedAmbientBackdrop(
                    mode: previewMode,
                    payload: previewPayload,
                    previewWidth: previewWidth,
                    leftPadding: _kDetailContentPadding,
                    topPadding: _kDetailContentPadding,
                    desktop: desktop,
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _kDetailContentPadding,
                      _kDetailContentPadding,
                      _kDetailContentPadding,
                      _kDetailContentPadding,
                    ),
                    child: desktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: previewWidth,
                                child: Scrollbar(
                                  controller: _leftPaneScrollController,
                                  child: SingleChildScrollView(
                                    controller: _leftPaneScrollController,
                                    child: leftColumn,
                                  ),
                                ),
                              ),
                              buildRightPanel(
                                desktop: true,
                                viewportHeight: viewport.maxHeight,
                                panelWidth: sideWidth,
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                leftColumn,
                                buildRightPanel(
                                  desktop: false,
                                  viewportHeight: viewport.maxHeight,
                                  panelWidth: contentWidth,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _engagementButton({
    required IconData icon,
    required bool active,
    required Color activeColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: active ? 1.08 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? activeColor : Colors.white,
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostStudioTab extends StatefulWidget {
  const _PostStudioTab({required this.topInset});

  final double topInset;

  @override
  State<_PostStudioTab> createState() => _PostStudioTabState();
}

class _PostStudioTabState extends State<_PostStudioTab> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _collectionNameController =
      TextEditingController(text: 'My Collection');

  int _postTypeIndex = 0;
  int _selectedItemIndex = -1;
  bool _uploading = false;
  bool _openingComposer = false;
  Map<String, dynamic>? _singlePayload;
  final List<CollectionDraftItem> _draftItems = <CollectionDraftItem>[];

  @override
  void dispose() {
    _collectionNameController.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    if (_uploading) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    try {
      final file = await pickDeviceFile(accept: 'image/*');
      if (file == null) return;
      final publicUrl = await _repository.uploadAssetBytes(
        bytes: file.bytes,
        fileName: file.name,
        contentType: file.contentType,
        folder: 'post-images',
      );
      final payload = simpleImagePayload(
        imageUrl: publicUrl,
        editor: 'post_studio',
        meta: <String, dynamic>{'sourceName': file.name},
      );
      if (!mounted) return;
      setState(() {
        if (_postTypeIndex == 0) {
          _singlePayload = payload;
        } else {
          final item = CollectionDraftItem(
            mode: kImageRenderMode,
            name: file.name.trim().isEmpty
                ? 'Image ${_draftItems.length + 1}'
                : file.name.trim(),
            snapshot: payload,
          );
          _draftItems.add(item);
          _selectedItemIndex = _draftItems.length - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openSingleComposer() async {
    final payload = _singlePayload;
    if (payload == null ||
        imageUrlFromPayload(payload, fallbackMode: kImageRenderMode) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload one image first.')),
      );
      return;
    }
    if (_openingComposer) return;
    setState(() => _openingComposer = true);
    final now = DateTime.now();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/post/studio/publish-single'),
        builder: (_) => _PostCardComposerPage.single(
          name:
              'Image ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          mode: kImageRenderMode,
          payload: payload,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingComposer = false);
    if (result == true) {
      setState(() => _singlePayload = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully.')),
      );
    }
  }

  Future<void> _publishCollection() async {
    if (_draftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload at least one collection image.')),
      );
      return;
    }
    if (_openingComposer) return;
    setState(() => _openingComposer = true);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/post/studio/publish-collection'),
        builder: (_) => _PostCardComposerPage.collection(
          collectionId: null,
          collectionName: _collectionNameController.text.trim(),
          collectionDescription: '',
          tags: const <String>[],
          mentionUserIds: const <String>[],
          published: true,
          items: List<CollectionDraftItem>.from(_draftItems),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _openingComposer = false);
    if (result == true) {
      setState(() {
        _draftItems.clear();
        _selectedItemIndex = -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection published successfully.')),
      );
    }
  }

  void _removeCollectionItem(int index) {
    if (index < 0 || index >= _draftItems.length) return;
    setState(() {
      _draftItems.removeAt(index);
      if (_draftItems.isEmpty) {
        _selectedItemIndex = -1;
      } else if (_selectedItemIndex >= _draftItems.length) {
        _selectedItemIndex = _draftItems.length - 1;
      }
    });
  }

  Widget _buildPreview(ColorScheme cs) {
    final Map<String, dynamic>? payload = _postTypeIndex == 0
        ? _singlePayload
        : (_selectedItemIndex >= 0 && _selectedItemIndex < _draftItems.length
            ? _draftItems[_selectedItemIndex].snapshot
            : (_draftItems.isNotEmpty ? _draftItems.first.snapshot : null));
    if (payload == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child:
              Icon(Icons.image_outlined, color: cs.onSurfaceVariant, size: 52),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _SharedPresetPreview(
        mode: kImageRenderMode,
        payload: payload,
        borderRadius: BorderRadius.circular(16),
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool collectionMode = _postTypeIndex == 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, widget.topInset + 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Post Studio',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(
                          value: 0,
                          icon: Icon(Icons.image_outlined),
                          label: Text('Single'),
                        ),
                        ButtonSegment<int>(
                          value: 1,
                          icon: Icon(Icons.collections_outlined),
                          label: Text('Collection'),
                        ),
                      ],
                      selected: <int>{_postTypeIndex},
                      onSelectionChanged: (value) {
                        setState(() => _postTypeIndex = value.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildPreview(cs)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 320 + 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  FilledButton.icon(
                    onPressed: _uploading ? null : _uploadImage,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(_uploading ? 'Uploading...' : 'Upload Image'),
                  ),
                  const SizedBox(height: 14),
                  if (collectionMode) ...[
                    TextField(
                      controller: _collectionNameController,
                      decoration: const InputDecoration(
                        labelText: 'Collection Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Images',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_draftItems.isEmpty)
                      Text(
                        'Upload images to build this collection.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    else
                      ...List<Widget>.generate(_draftItems.length, (index) {
                        final item = _draftItems[index];
                        final bool selected = index == _selectedItemIndex;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          leading: const Icon(Icons.image_outlined),
                          title: Text(item.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () =>
                              setState(() => _selectedItemIndex = index),
                          trailing: IconButton(
                            tooltip: 'Remove image',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => _removeCollectionItem(index),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openingComposer ? null : _publishCollection,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(_openingComposer ? 'Opening...' : 'Continue'),
                    ),
                  ] else ...[
                    Text(
                      _singlePayload == null
                          ? 'Upload one image to create a post.'
                          : 'Image ready for publishing.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openingComposer ? null : _openSingleComposer,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(_openingComposer ? 'Opening...' : 'Continue'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionPreviewPage extends StatefulWidget {
  const _CollectionPreviewPage({required this.items});

  final List<CollectionDraftItem> items;

  @override
  State<_CollectionPreviewPage> createState() => _CollectionPreviewPageState();
}

class _CollectionPreviewPageState extends State<_CollectionPreviewPage> {
  final SwipableStackController _stackController = SwipableStackController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _stackController.addListener(_onStackChanged);
  }

  @override
  void dispose() {
    _stackController
      ..removeListener(_onStackChanged)
      ..dispose();
    super.dispose();
  }

  void _onStackChanged() {
    if (!mounted) return;
    if (widget.items.isEmpty) return;
    final next = _stackController.currentIndex;
    if (next == _index) return;
    setState(() {
      final int max = widget.items.length - 1;
      _index = next < 0 ? 0 : (next > max ? max : next);
    });
  }

  Widget _buildCard(CollectionDraftItem item) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: PresetViewer(
            mode: item.mode,
            payload: item.snapshot,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool hasItems = widget.items.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: hasItems
                  ? SwipableStack(
                      controller: _stackController,
                      itemCount: widget.items.length,
                      allowVerticalSwipe: true,
                      onSwipeCompleted: (index, _) {
                        setState(() {
                          final int next = index + 1;
                          final int max = widget.items.length - 1;
                          _index = next < 0 ? 0 : (next > max ? max : next);
                        });
                      },
                      builder: (context, props) {
                        if (props.index >= widget.items.length) {
                          return const SizedBox.shrink();
                        }
                        return _buildCard(widget.items[props.index]);
                      },
                    )
                  : Center(
                      child: Text(
                        'No items in collection.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
            ),
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 10),
                  IgnorePointer(
                    child: Text(
                      'Collection Preview',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasItems)
                    IgnorePointer(
                      child: Text(
                        '${_index + 1}/${widget.items.length}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionDetailPage extends StatefulWidget {
  const _CollectionDetailPage({
    required this.collectionId,
    this.initialSummary,
  });

  final String collectionId;
  final CollectionSummary? initialSummary;

  @override
  State<_CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<_CollectionDetailPage> {
  final AppRepository _repository = AppRepository.instance;
  final SwipableStackController _stackController = SwipableStackController();
  final TextEditingController _collectionCommentController =
      TextEditingController();
  final FocusNode _swipeFocusNode =
      FocusNode(debugLabel: 'collection-detail-swipe-focus');
  final ScrollController _leftPaneScrollController = ScrollController();
  final ScrollController _rightPaneScrollController = ScrollController();
  final ScrollController _chipRailScrollController = ScrollController();
  static const List<String> _suggestionFilters = <String>[
    'All',
    'FromUser',
    'Related',
    'FYP',
    'Trending',
    'MostUsedHashtags',
    'MostLiked',
    'MostViewed',
    'Viral',
  ];

  bool _loading = true;
  String? _error;
  CollectionDetail? _detail;
  int _index = 0;
  bool _commentsOpen = false;
  bool _descriptionExpanded = false;
  bool _loadingSuggestions = false;
  String _suggestionFilter = _suggestionFilters.first;
  List<CollectionSummary> _suggestedCollections = const <CollectionSummary>[];
  List<PresetComment> _collectionComments = const <PresetComment>[];
  int? _swipePointer;
  Offset? _swipeStartGlobal;
  DateTime? _swipeStartAt;
  bool _swipeCaptured = false;

  @override
  void initState() {
    super.initState();
    _stackController.addListener(_onStackChanged);
    _load();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _collectionCommentController.dispose();
    _swipeFocusNode.dispose();
    _leftPaneScrollController.dispose();
    _rightPaneScrollController.dispose();
    _chipRailScrollController.dispose();
    _stackController
      ..removeListener(_onStackChanged)
      ..dispose();
    super.dispose();
  }

  void _onStackChanged() {
    if (!mounted) return;
    final next = _stackController.currentIndex;
    if (_detail == null || _detail!.items.isEmpty) return;
    if (next == _index) return;
    setState(() {
      final int max = _detail!.items.length - 1;
      _index = next < 0 ? 0 : (next > max ? max : next);
    });
  }

  Future<bool> _requireAuthAction() async {
    if (_repository.currentUser != null) return true;
    if (!mounted) return false;
    final bool shouldSignIn = await _showSignInRequiredSheet(
      context,
      message: 'This action requires sign in.',
    );
    if (!mounted || !shouldSignIn) return false;
    Navigator.pushNamed(context, '/auth');
    return false;
  }

  CollectionSummary _copySummary(
    CollectionSummary summary, {
    int? likesCount,
    int? dislikesCount,
    int? commentsCount,
    int? savesCount,
    int? viewsCount,
    int? myReaction,
    bool? isSavedByCurrentUser,
    bool? isWatchLater,
  }) {
    return CollectionSummary(
      id: summary.id,
      shareId: summary.shareId,
      userId: summary.userId,
      name: summary.name,
      description: summary.description,
      tags: summary.tags,
      mentionUserIds: summary.mentionUserIds,
      published: summary.published,
      thumbnailPayload: summary.thumbnailPayload,
      thumbnailMode: summary.thumbnailMode,
      itemsCount: summary.itemsCount,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      firstItem: summary.firstItem,
      author: summary.author,
      likesCount: likesCount ?? summary.likesCount,
      dislikesCount: dislikesCount ?? summary.dislikesCount,
      commentsCount: commentsCount ?? summary.commentsCount,
      savesCount: savesCount ?? summary.savesCount,
      viewsCount: viewsCount ?? summary.viewsCount,
      myReaction: myReaction ?? summary.myReaction,
      isSavedByCurrentUser:
          isSavedByCurrentUser ?? summary.isSavedByCurrentUser,
      isWatchLater: isWatchLater ?? summary.isWatchLater,
    );
  }

  void _updateSummary(CollectionSummary Function(CollectionSummary) map) {
    final detail = _detail;
    if (detail == null) return;
    setState(() {
      _detail =
          CollectionDetail(summary: map(detail.summary), items: detail.items);
    });
  }

  void _swipeByDirection(SwipeDirection direction) {
    final detail = _detail;
    if (detail == null || detail.items.isEmpty) return;
    _stackController.next(swipeDirection: direction);
  }

  void _rewindSwipe() {
    if (_stackController.canRewind) {
      _stackController.rewind();
    }
  }

  void _beginGlobalSwipe(PointerDownEvent event) {
    _swipePointer = event.pointer;
    _swipeStartGlobal = event.position;
    _swipeStartAt = DateTime.now();
    _swipeCaptured = false;
  }

  void _updateGlobalSwipe(PointerMoveEvent event) {
    if (_swipePointer != event.pointer) return;
    if (_swipeCaptured) return;
    final Offset? start = _swipeStartGlobal;
    final DateTime? startAt = _swipeStartAt;
    if (start == null || startAt == null) return;
    final Duration elapsed = DateTime.now().difference(startAt);
    if (elapsed.inMilliseconds > 540) return;
    final double dx = event.position.dx - start.dx;
    final double dy = event.position.dy - start.dy;
    final double absDx = dx.abs();
    final double absDy = dy.abs();
    const double threshold = 108;
    const double dominance = 1.55;
    if (absDx >= threshold && absDx > (absDy * dominance)) {
      _swipeByDirection(dx < 0 ? SwipeDirection.left : SwipeDirection.right);
      _swipeCaptured = true;
      return;
    }
    if (absDy >= threshold && absDy > (absDx * dominance)) {
      _swipeByDirection(dy < 0 ? SwipeDirection.up : SwipeDirection.down);
      _swipeCaptured = true;
    }
  }

  void _endGlobalSwipe(PointerEvent event) {
    if (_swipePointer != event.pointer) return;
    _swipePointer = null;
    _swipeStartGlobal = null;
    _swipeStartAt = null;
    _swipeCaptured = false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await QueryGuard.run(
        () => _repository.fetchCollectionById(widget.collectionId),
      );
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loading = false;
          _error = 'Unable to load collection.';
        });
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
      unawaited(_repository.recordCollectionView(detail.summary.id));
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _toggleCollectionReaction(int value) async {
    if (!await _requireAuthAction()) return;
    final summary = _detail?.summary;
    if (summary == null) return;
    final int newReaction = summary.myReaction == value ? 0 : value;
    await _repository.setCollectionReaction(
      collectionId: summary.id,
      reaction: newReaction,
    );

    int likes = summary.likesCount;
    int dislikes = summary.dislikesCount;
    if (summary.myReaction == 1) likes = (likes - 1).clamp(0, 999999999);
    if (summary.myReaction == -1) dislikes = (dislikes - 1).clamp(0, 999999999);
    if (newReaction == 1) likes += 1;
    if (newReaction == -1) dislikes += 1;
    _updateSummary(
      (current) => _copySummary(
        current,
        likesCount: likes,
        dislikesCount: dislikes,
        myReaction: newReaction,
      ),
    );
  }

  Future<void> _toggleCollectionSave() async {
    if (!await _requireAuthAction()) return;
    final summary = _detail?.summary;
    if (summary == null) return;
    final bool save = !summary.isSavedByCurrentUser;
    await _repository.toggleSaveCollection(summary.id, save: save);
    _updateSummary(
      (current) => _copySummary(
        current,
        isSavedByCurrentUser: save,
        savesCount: save
            ? current.savesCount + 1
            : (current.savesCount - 1).clamp(0, 999999999),
      ),
    );
  }

  Future<void> _toggleCollectionWatchLater() async {
    if (!await _requireAuthAction()) return;
    final summary = _detail?.summary;
    if (summary == null) return;
    final bool watchLater = !summary.isWatchLater;
    await _repository.toggleWatchLaterItem(
      targetType: 'collection',
      targetId: summary.id,
      watchLater: watchLater,
    );
    _updateSummary(
      (current) => _copySummary(
        current,
        isWatchLater: watchLater,
      ),
    );
  }

  Future<void> _loadCollectionComments() async {
    final summary = _detail?.summary;
    if (summary == null) return;
    try {
      final comments = await QueryGuard.run(
        () => _repository.fetchCollectionComments(summary.id),
      );
      if (!mounted) return;
      setState(() {
        _collectionComments = comments;
      });
      _updateSummary(
        (current) => _copySummary(current, commentsCount: comments.length),
      );
    } catch (_) {}
  }

  // ignore: unused_element
  Future<void> _openCollectionCommentsSheet() async {
    await _loadCollectionComments();
    if (!mounted) return;
    List<PresetComment> sheetComments =
        List<PresetComment>.from(_collectionComments);
    bool sending = false;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  children: [
                    Expanded(
                      child: sheetComments.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.builder(
                              itemCount: sheetComments.length,
                              itemBuilder: (context, index) {
                                final comment = sheetComments[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                      comment.author?.displayName ?? 'User'),
                                  subtitle: Text(comment.content),
                                  trailing: Text(
                                    _friendlyTime(comment.createdAt),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _collectionCommentController,
                            decoration: const InputDecoration(
                              hintText: 'Write a comment...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  if (!await _requireAuthAction()) return;
                                  final summary = _detail?.summary;
                                  if (summary == null) return;
                                  final String text =
                                      _collectionCommentController.text.trim();
                                  if (text.isEmpty) return;
                                  setModalState(() => sending = true);
                                  await _repository.addCollectionComment(
                                    collectionId: summary.id,
                                    content: text,
                                  );
                                  _collectionCommentController.clear();
                                  final comments = await _repository
                                      .fetchCollectionComments(summary.id);
                                  if (!mounted) return;
                                  setState(
                                      () => _collectionComments = comments);
                                  _updateSummary(
                                    (current) => _copySummary(
                                      current,
                                      commentsCount: comments.length,
                                    ),
                                  );
                                  setModalState(() {
                                    sending = false;
                                    sheetComments = comments;
                                  });
                                },
                          child: Text(sending ? '...' : 'Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  CollectionSummary? get _activeSummary =>
      _detail?.summary ?? widget.initialSummary;

  String _displayFilterName(String filter) {
    if (filter == 'FromUser') {
      final username = _activeSummary?.author?.username?.trim();
      if (username != null && username.isNotEmpty) {
        return 'From @$username';
      }
      return 'From creator';
    }
    switch (filter) {
      case 'MostUsedHashtags':
        return 'Most Used Hashtags';
      case 'MostLiked':
        return 'Most Liked';
      case 'MostViewed':
        return 'Most Viewed';
      default:
        return filter;
    }
  }

  Future<void> _loadSuggestions() async {
    if (_loadingSuggestions) return;
    setState(() => _loadingSuggestions = true);
    try {
      final collections = await QueryGuard.run(
        () => _repository.fetchPublishedCollections(limit: 120),
      );
      if (!mounted) return;
      setState(() {
        _suggestedCollections = collections;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  List<CollectionSummary> _filteredSuggestions() {
    final summary = _activeSummary;
    final String currentCollectionId = summary?.id ?? '';
    final String currentUserId = summary?.userId ?? '';
    final Set<String> currentTags =
        (summary?.tags ?? const <String>[]).map((e) => e.toLowerCase()).toSet();
    final List<CollectionSummary> candidates = _suggestedCollections
        .where((item) => item.id != currentCollectionId)
        .toList();
    switch (_suggestionFilter) {
      case 'FromUser':
        return candidates
            .where((item) => item.userId == currentUserId)
            .toList();
      case 'Related':
        return candidates.where((item) {
          final tags = item.tags.map((e) => e.toLowerCase()).toSet();
          return tags.intersection(currentTags).isNotEmpty;
        }).toList();
      case 'Trending':
        candidates.sort((a, b) {
          final int aScore = (a.viewsCount * 2) + a.likesCount;
          final int bScore = (b.viewsCount * 2) + b.likesCount;
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'MostUsedHashtags':
        candidates.sort((a, b) => b.tags.length.compareTo(a.tags.length));
        return candidates;
      case 'MostLiked':
        candidates.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        return candidates;
      case 'MostViewed':
        candidates.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        return candidates;
      case 'Viral':
        candidates.sort((a, b) {
          final int aScore = a.viewsCount + (a.likesCount * 3);
          final int bScore = b.viewsCount + (b.likesCount * 3);
          return bScore.compareTo(aScore);
        });
        return candidates;
      case 'FYP':
      case 'All':
      default:
        return candidates;
    }
  }

  Future<void> _shareCollectionToUser() async {
    if (!await _requireAuthAction()) return;
    final summary = _activeSummary;
    if (summary == null || !mounted) return;
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Share Collection to User'),
    );
    if (profile == null) return;
    try {
      await _repository.shareCollectionToUser(
        recipientUserId: profile.userId,
        summary: summary,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection shared successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _copyCollectionLinkToClipboard() async {
    final summary = _activeSummary;
    if (summary == null) return;
    final String link = buildCollectionShareUrl(summary);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection link copied to clipboard.')),
    );
  }

  Future<void> _openCollectionShareUrl(
    String url, {
    bool copyLinkFirst = false,
  }) async {
    if (copyLinkFirst) {
      await _copyCollectionLinkToClipboard();
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open $url')),
      );
    }
  }

  Future<void> _openCollectionShareSheet() async {
    final summary = _activeSummary;
    if (summary == null) return;
    final String link = buildCollectionShareUrl(summary);
    final String encodedLink = Uri.encodeComponent(link);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Share to user'),
              onTap: () {
                Navigator.pop(context);
                _shareCollectionToUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              subtitle:
                  Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _copyCollectionLinkToClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                    'https://t.me/share/url?url=$encodedLink');
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.facebook.com/sharer/sharer.php?u=$encodedLink',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl('https://wa.me/?text=$encodedLink');
              },
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('X (Twitter)'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://twitter.com/intent/tweet?url=$encodedLink',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.instagram.com/',
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_front_outlined),
              title: const Text('Snapchat'),
              subtitle: const Text('Copies link first'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.snapchat.com/',
                  copyLinkFirst: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Reddit'),
              onTap: () {
                Navigator.pop(context);
                _openCollectionShareUrl(
                  'https://www.reddit.com/submit?url=$encodedLink',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _collectionHeroTag(int index) =>
      'collection-detail-hero-${widget.collectionId}-$index';

  Future<void> _openCollectionFullscreen(
    CollectionItemSnapshot item,
    int index,
  ) async {
    await _openDetailFullscreenViewer(
      context,
      heroTag: _collectionHeroTag(index),
      mode: item.mode,
      payload: item.snapshot,
    );
  }

  Widget _buildCard(
    CollectionItemSnapshot item, {
    required bool active,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.transparent),
        ),
        _SharedPresetPreview(
          mode: item.mode,
          payload: item.snapshot,
          borderRadius: BorderRadius.circular(16),
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = _detail?.summary ?? widget.initialSummary;
    final detail = _detail;
    final bool hasItems = detail != null && detail.items.isNotEmpty;
    final CollectionItemSnapshot? activeItem = hasItems
        ? detail.items[_index.clamp(0, detail.items.length - 1)]
        : null;
    final List<CollectionSummary> suggestions = _filteredSuggestions();
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101213),
        body: _TopEdgeLoadingPane(label: 'Loading collection...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF101213),
        body: QueryRetryPane(
          title: _error,
          offline: _isOfflineErrorText(_error!),
          onRetry: _load,
        ),
      );
    }
    if (summary == null || detail == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF101213),
        body: Center(
          child: Text(
            'Collection unavailable.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    void scrollChipRailBy(double delta) {
      if (!_chipRailScrollController.hasClients) return;
      final position = _chipRailScrollController.position;
      final double target = (_chipRailScrollController.offset + delta)
          .clamp(0.0, position.maxScrollExtent);
      _chipRailScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
      );
    }

    Widget buildEngagementRail() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _collectionEngagementButton(
              icon: summary.myReaction == 1
                  ? Icons.thumb_up_alt
                  : Icons.thumb_up_alt_outlined,
              active: summary.myReaction == 1,
              activeColor: cs.primary,
              label: _friendlyCount(summary.likesCount),
              onTap: () => _toggleCollectionReaction(1),
            ),
            _collectionEngagementButton(
              icon: summary.myReaction == -1
                  ? Icons.thumb_down_alt
                  : Icons.thumb_down_alt_outlined,
              active: summary.myReaction == -1,
              activeColor: Colors.redAccent,
              label: _friendlyCount(summary.dislikesCount),
              onTap: () => _toggleCollectionReaction(-1),
            ),
            _collectionEngagementButton(
              icon: Icons.send_outlined,
              active: false,
              activeColor: cs.primary,
              label: '',
              onTap: _openCollectionShareSheet,
            ),
            _collectionEngagementButton(
              icon: Icons.mode_comment_outlined,
              active: _commentsOpen,
              activeColor: cs.primary,
              label: _friendlyCount(summary.commentsCount),
              onTap: () async {
                setState(() => _commentsOpen = true);
                await _loadCollectionComments();
              },
            ),
            _collectionEngagementButton(
              icon: summary.isSavedByCurrentUser
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              active: summary.isSavedByCurrentUser,
              activeColor: Colors.amberAccent,
              label: _friendlyCount(summary.savesCount),
              onTap: _toggleCollectionSave,
            ),
            _collectionEngagementButton(
              icon: summary.isWatchLater
                  ? Icons.watch_later
                  : Icons.watch_later_outlined,
              active: summary.isWatchLater,
              activeColor: Colors.tealAccent,
              label: '',
              onTap: _toggleCollectionWatchLater,
            ),
          ],
        ),
      );
    }

    Widget buildDescriptionBox() {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            setState(() => _descriptionExpanded = !_descriptionExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(
                    _descriptionExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                summary.description.trim().isNotEmpty
                    ? summary.description
                    : 'No description provided.',
                maxLines: _descriptionExpanded ? null : 3,
                overflow: _descriptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildSwipeControlRail() {
      return Row(
        children: [
          Text(
            '${_index + 1}/${detail.items.length}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous',
            onPressed: () => _swipeByDirection(SwipeDirection.left),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Up',
            onPressed: () => _swipeByDirection(SwipeDirection.up),
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Revert swipe',
            onPressed: _stackController.canRewind ? _rewindSwipe : null,
            icon: const Icon(Icons.undo_rounded, size: 18),
          ),
          IconButton(
            tooltip: 'Down',
            onPressed: () => _swipeByDirection(SwipeDirection.down),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: () => _swipeByDirection(SwipeDirection.right),
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          ),
        ],
      );
    }

    Widget buildBelowPreviewMeta() {
      return Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 760;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          summary.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_friendlyCount(summary.viewsCount)} views • ${_friendlyTime(summary.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.itemsCount} items',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (compact) ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _openPublicProfileRoute(context, summary.author),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundImage:
                                (summary.author?.avatarUrl != null &&
                                        summary.author!.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(summary.author!.avatarUrl!)
                                    : null,
                            child: (summary.author?.avatarUrl == null ||
                                    summary.author!.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openPublicProfileRoute(
                                context, summary.author),
                            child: Text(
                              summary.author?.displayName ?? 'Unknown creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    buildEngagementRail(),
                  ] else ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _openPublicProfileRoute(context, summary.author),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundImage:
                                (summary.author?.avatarUrl != null &&
                                        summary.author!.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(summary.author!.avatarUrl!)
                                    : null,
                            child: (summary.author?.avatarUrl == null ||
                                    summary.author!.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: GestureDetector(
                            onTap: () => _openPublicProfileRoute(
                                context, summary.author),
                            child: Text(
                              summary.author?.displayName ?? 'Unknown creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: buildEngagementRail(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  buildDescriptionBox(),
                ],
              );
            },
          ),
        ),
      );
    }

    Widget buildPreviewDeck() {
      if (!hasItems || activeItem == null) {
        return Center(
          child: Text(
            'Collection is empty.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        );
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:
            _commentsOpen ? () => setState(() => _commentsOpen = false) : null,
        onDoubleTap: () => _openCollectionFullscreen(activeItem, _index),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SwipableStack(
                controller: _stackController,
                itemCount: detail.items.length,
                stackClipBehaviour: Clip.none,
                allowVerticalSwipe: true,
                onSwipeCompleted: (index, _) {
                  setState(() {
                    final int next = index + 1;
                    final int max = detail.items.length - 1;
                    _index = next < 0 ? 0 : (next > max ? max : next);
                  });
                },
                builder: (context, props) {
                  if (props.index >= detail.items.length) {
                    return const SizedBox.shrink();
                  }
                  final item = detail.items[props.index];
                  final bool active = props.index == _index;
                  final Widget card = _buildCard(item, active: active);
                  if (!active) return card;
                  return Hero(
                    tag: _collectionHeroTag(props.index),
                    createRectTween: (begin, end) =>
                        _EaseInOutRectTween(begin: begin, end: end),
                    child: card,
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IconButton.filledTonal(
                onPressed: () => _openCollectionFullscreen(activeItem, _index),
                icon: const Icon(Icons.fullscreen, size: 20),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildPreviewSurface() {
      return AspectRatio(
        aspectRatio: _kDetailPreviewAspectRatio,
        child: buildPreviewDeck(),
      );
    }

    Widget buildFilterRail() {
      return Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          final double delta =
              event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
                  ? event.scrollDelta.dx
                  : event.scrollDelta.dy;
          if (delta.abs() < 0.1) return;
          scrollChipRailBy(delta);
        },
        child: Row(
          children: [
            IconButton(
              tooltip: 'Scroll filters left',
              onPressed: () => scrollChipRailBy(-180),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _chipRailScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      List<Widget>.generate(_suggestionFilters.length, (index) {
                    final filter = _suggestionFilters[index];
                    final selected = filter == _suggestionFilter;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == _suggestionFilters.length - 1 ? 0 : 8,
                      ),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(
                          _displayFilterName(filter),
                          style: TextStyle(
                            color: selected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: Colors.white,
                        checkmarkColor: Colors.black,
                        side: const BorderSide(color: Colors.white24),
                        onSelected: (_) =>
                            setState(() => _suggestionFilter = filter),
                      ),
                    );
                  }),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Scroll filters right',
              onPressed: () => scrollChipRailBy(180),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
    }

    Widget buildCommentsPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close comments',
                onPressed: () => setState(() => _commentsOpen = false),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _collectionComments.isEmpty
                ? Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68)),
                    ),
                  )
                : ListView.builder(
                    controller: _rightPaneScrollController,
                    itemCount: _collectionComments.length,
                    itemBuilder: (context, index) {
                      final comment = _collectionComments[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          comment.author?.displayName ?? 'User',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          comment.content,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        trailing: Text(
                          _friendlyTime(comment.createdAt),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.64),
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _collectionCommentController,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  if (!await _requireAuthAction()) return;
                  final summary = _detail?.summary;
                  if (summary == null) return;
                  final String text = _collectionCommentController.text.trim();
                  if (text.isEmpty) return;
                  await _repository.addCollectionComment(
                    collectionId: summary.id,
                    content: text,
                  );
                  _collectionCommentController.clear();
                  await _loadCollectionComments();
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildSuggestionsPanel() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox.shrink(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _loadingSuggestions
                      ? const _TopEdgeLoadingPane(
                          label: 'Loading suggestions...',
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        )
                      : ListView.builder(
                          controller: _rightPaneScrollController,
                          padding: EdgeInsets.zero,
                          itemCount: suggestions.length.clamp(0, 24),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            final String mode = item.thumbnailMode ??
                                item.firstItem?.mode ??
                                '2d';
                            final Map<String, dynamic> payload =
                                item.thumbnailPayload.isNotEmpty
                                    ? item.thumbnailPayload
                                    : (item.firstItem?.snapshot ??
                                        const <String, dynamic>{});
                            return _SuggestionGridCard(
                              heroTag: 'collection-detail-hero-${item.id}-0',
                              mode: mode,
                              payload: payload,
                              title: item.name,
                              author:
                                  item.author?.displayName ?? 'Unknown creator',
                              metaText:
                                  '${_friendlyCount(item.viewsCount)} views • ${_friendlyTime(item.createdAt)}',
                              priceText: _cardPriceLabel(
                                isPaid: item.isPaid,
                                priceCents: item.priceCents,
                                viewerHasPaid: item.viewerHasPaid,
                              ),
                              isVerified: item.author?.isVerified == true,
                              accentColor:
                                  _cardAccentColorFromHex(item.accentColorHex),
                              showCollectionCount: true,
                              collectionCountText: '${item.itemsCount}',
                              avatarImage: (item.author?.avatarUrl ?? '')
                                      .trim()
                                      .isNotEmpty
                                  ? NetworkImage(item.author!.avatarUrl!.trim())
                                  : null,
                              onAvatarTap: () =>
                                  _openPublicProfileRoute(context, item.author),
                              onTap: () => _pushHeroRoute(
                                context,
                                builder: (_) => _CollectionDetailPage(
                                  collectionId: item.id,
                                  initialSummary: item,
                                ),
                                name: buildCollectionRoutePathForSummary(item),
                                replace: true,
                              ),
                            );
                          },
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildSwipeControlRail(),
                        buildFilterRail(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildRightPanel({
      required bool desktop,
      required double viewportHeight,
      required double panelWidth,
    }) {
      final Widget body =
          _commentsOpen ? buildCommentsPanel() : buildSuggestionsPanel();
      return SizedBox(
        width: desktop ? panelWidth : double.infinity,
        height: desktop ? viewportHeight : 640,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101213),
      body: KeyboardListener(
        focusNode: _swipeFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.keyF &&
              activeItem != null) {
            _openCollectionFullscreen(activeItem, _index);
            return;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _swipeByDirection(SwipeDirection.left);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _swipeByDirection(SwipeDirection.right);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _swipeByDirection(SwipeDirection.up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _swipeByDirection(SwipeDirection.down);
          } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
            _rewindSwipe();
          }
        },
        child: LayoutBuilder(
          key: const ValueKey<String>('compact-collection-detail'),
          builder: (context, viewport) {
            final bool desktop = viewport.maxWidth >= 1140;
            final double contentWidth =
                viewport.maxWidth - (_kDetailContentPadding * 2);
            final double previewWidth = _detailPreviewWidth(
              contentWidth: contentWidth,
              desktop: desktop,
            );
            final double sideWidth = _detailSidePanelWidth(
              contentWidth: contentWidth,
              desktop: desktop,
            );
            final double previewHeight =
                previewWidth / _kDetailPreviewAspectRatio;
            final Widget leftScroll = Scrollbar(
              controller: _leftPaneScrollController,
              child: SingleChildScrollView(
                controller: _leftPaneScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: previewHeight),
                    buildBelowPreviewMeta(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
            final Widget desktopBody = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: sideWidth,
                  child: buildRightPanel(
                    desktop: true,
                    viewportHeight: viewport.maxHeight,
                    panelWidth: sideWidth,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: sideWidth + _kDetailPanelGap,
                  child: leftScroll,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: previewWidth,
                  child: buildPreviewSurface(),
                ),
              ],
            );
            final Widget mobileBody = Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: previewHeight),
                      buildBelowPreviewMeta(),
                      buildRightPanel(
                        desktop: false,
                        viewportHeight: viewport.maxHeight,
                        panelWidth: contentWidth,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: buildPreviewSurface(),
                ),
              ],
            );
            final Widget content = Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _CardScopedAmbientBackdrop(
                    mode: activeItem?.mode ?? '2d',
                    payload: activeItem?.snapshot ?? const <String, dynamic>{},
                    previewWidth: previewWidth,
                    leftPadding: _kDetailContentPadding,
                    topPadding: _kDetailContentPadding,
                    desktop: desktop,
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _kDetailContentPadding,
                      _kDetailContentPadding,
                      _kDetailContentPadding,
                      _kDetailContentPadding,
                    ),
                    child: desktop ? desktopBody : mobileBody,
                  ),
                ),
              ],
            );
            if (!desktop) return content;
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _beginGlobalSwipe,
              onPointerMove: _updateGlobalSwipe,
              onPointerUp: _endGlobalSwipe,
              onPointerCancel: _endGlobalSwipe,
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _collectionEngagementButton({
    required IconData icon,
    required bool active,
    required Color activeColor,
    required String label,
    required VoidCallback onTap,
  }) {
    final Color color = active ? activeColor : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    super.key,
    required this.onProfileChanged,
    required this.topInset,
  });

  final Future<void> Function() onProfileChanged;
  final double topInset;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

enum _SavedGridFilter {
  all,
  savedPosts,
  savedCollections,
  watchLater,
}

class _ProfileTabState extends State<_ProfileTab> {
  final AppRepository _repository = AppRepository.instance;

  bool _loading = true;
  String? _error;
  AppUserProfile? _profile;
  ProfileStats _stats = const ProfileStats(
    followersCount: 0,
    followingCount: 0,
    postsCount: 0,
  );
  List<RenderPreset> _saved = const <RenderPreset>[];
  List<CollectionSummary> _savedCollections = const <CollectionSummary>[];
  List<RenderPreset> _posts = const <RenderPreset>[];
  List<RenderPreset> _history = const <RenderPreset>[];
  List<WatchLaterItem> _watchLater = const <WatchLaterItem>[];
  _SavedGridFilter _savedFilter = _SavedGridFilter.all;
  Map<String, int> _presetViewsById = <String, int>{};
  Map<String, AppUserProfile> _authorById = <String, AppUserProfile>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _repository.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile =
          await QueryGuard.run(() => _repository.ensureCurrentProfile());
      final stats =
          await QueryGuard.run(() => _repository.fetchProfileStats(user.id));
      final saved = await QueryGuard.run(
          () => _repository.fetchSavedPresetsForCurrentUser());
      final savedCollections = await QueryGuard.run(
        () => _repository.fetchSavedCollectionsForCurrentUser(),
      );
      final posts =
          await QueryGuard.run(() => _repository.fetchUserPosts(user.id));
      final history = await QueryGuard.run(
        () => _repository.fetchHistoryPresetsForCurrentUser(),
      );
      final watchLater = await QueryGuard.run(
        () => _repository.fetchWatchLaterForCurrentUser(),
      );
      final Set<String> presetIds = <String>{};
      final Set<String> authorIds = <String>{};
      void addPreset(RenderPreset preset) {
        if (preset.id.isEmpty) return;
        presetIds.add(preset.id);
        if (preset.userId.isNotEmpty) {
          authorIds.add(preset.userId);
        }
      }

      for (final preset in posts) {
        addPreset(preset);
      }
      for (final preset in saved) {
        addPreset(preset);
      }
      for (final preset in history) {
        addPreset(preset);
      }
      for (final item in watchLater) {
        final preset = item.post;
        if (preset != null) addPreset(preset);
      }

      final statsByPresetId = presetIds.isEmpty
          ? <String, Map<String, dynamic>>{}
          : await QueryGuard.run(
              () => _repository.fetchPresetStatsByIds(presetIds),
            );
      final Map<String, int> viewsById = <String, int>{};
      int safeInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      statsByPresetId.forEach((id, stats) {
        viewsById[id] = safeInt(stats['views_count']);
      });
      final Map<String, AppUserProfile> authors = authorIds.isEmpty
          ? <String, AppUserProfile>{}
          : await QueryGuard.run(
              () => _repository.fetchProfilesByIds(authorIds),
            );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = stats;
        _saved = saved;
        _savedCollections = savedCollections;
        _posts = posts;
        _history = history;
        _watchLater = watchLater;
        _presetViewsById = viewsById;
        _authorById = authors;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  FeedPost _fallbackFeedPost(RenderPreset preset) {
    return FeedPost(
      preset: preset,
      author: _authorById[preset.userId],
      likesCount: 0,
      dislikesCount: 0,
      commentsCount: 0,
      savesCount: 0,
      viewsCount: _presetViewsById[preset.id] ?? 0,
      myReaction: 0,
      isSaved: false,
      isFollowingAuthor: false,
      isWatchLater: false,
    );
  }

  Future<void> _openPost(RenderPreset preset) async {
    await _repository.recordPresetView(preset.id);
    if (!mounted) return;
    FeedPost resolved = _fallbackFeedPost(preset);
    try {
      final fetched = await _repository.fetchFeedPostById(preset.id);
      if (fetched != null) {
        resolved = fetched;
      }
    } catch (_) {}
    if (!mounted) return;
    await _pushHeroRoute(
      context,
      builder: (_) => _PresetDetailPage(initialPost: resolved),
      name: buildPostRoutePathForPreset(preset),
    );
    await _load();
  }

  Future<void> _openCollection(CollectionSummary summary) async {
    await _pushHeroRoute(
      context,
      builder: (_) => _CollectionDetailPage(
        collectionId: summary.id,
        initialSummary: summary,
      ),
      name: buildCollectionRoutePathForSummary(summary),
    );
    await _load();
  }

  Future<void> _copyPostLink(RenderPreset preset) async {
    await Clipboard.setData(ClipboardData(text: buildPostShareUrl(preset)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied.')),
    );
  }

  Future<void> _copyCollectionLink(CollectionSummary? summary) async {
    if (summary == null) return;
    await Clipboard.setData(
        ClipboardData(text: buildCollectionShareUrl(summary)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection link copied.')),
    );
  }

  Future<void> _editPost(RenderPreset preset) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/post/editor/card-update'),
        builder: (_) => _PostCardComposerPage.single(
          name: preset.name,
          mode: preset.mode,
          payload: preset.payload,
          existingPreset: preset,
          initialIsPaid: preset.isPaid,
          initialPriceCents: preset.priceCents,
          initialAccentColorHex: preset.accentColorHex,
          editTarget: _ComposerEditTarget.card,
          startBlankCard: false,
        ),
      ),
    );
    await _load();
  }

  Future<void> _togglePresetVisibility(RenderPreset preset) async {
    try {
      await _repository.setPresetVisibility(
        presetId: preset.id,
        isPublic: !preset.isPublic,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preset.isPublic ? 'Post set to private.' : 'Post set to public.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update visibility: $e')),
      );
    }
  }

  Future<void> _deletePreset(RenderPreset preset) async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await _repository.deletePresetPost(preset.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _removeSavedEntry(Map<String, dynamic> entry) async {
    final String kind = entry['kind']?.toString() ?? '';
    final RenderPreset? preset = entry['preset'] as RenderPreset?;
    final CollectionSummary? collection =
        entry['collection'] as CollectionSummary?;
    try {
      if (kind == 'saved_post' && preset != null) {
        await _repository.toggleSavePreset(preset.id, save: false);
      } else if (kind == 'saved_collection' && collection != null) {
        await _repository.toggleSaveCollection(collection.id, save: false);
      } else if (kind == 'watch_later_post' && preset != null) {
        await _repository.toggleWatchLaterItem(
          targetType: 'post',
          targetId: preset.id,
          watchLater: false,
        );
      } else if (kind == 'watch_later_collection' && collection != null) {
        await _repository.toggleWatchLaterItem(
          targetType: 'collection',
          targetId: collection.id,
          watchLater: false,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$kind removed.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _editProfile() async {
    if (_profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(profile: _profile!),
      ),
    );
    await _load();
    await widget.onProfileChanged();
  }

  Future<void> _confirmSignOut() async {
    final bool shouldSignOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You can sign back in anytime.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldSignOut) return;
    await _repository.signOut();
    if (!mounted) return;
    await widget.onProfileChanged();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/feed');
  }

  List<Map<String, dynamic>> _savedEntries() {
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    final Set<String> dedupe = <String>{};

    for (final preset in _saved) {
      final key = 'saved_post:${preset.id}';
      if (!dedupe.add(key)) continue;
      entries.add(
        <String, dynamic>{
          'key': key,
          'kind': 'saved_post',
          'createdAt': preset.createdAt,
          'preset': preset,
        },
      );
    }
    for (final summary in _savedCollections) {
      final key = 'saved_collection:${summary.id}';
      if (!dedupe.add(key)) continue;
      entries.add(
        <String, dynamic>{
          'key': key,
          'kind': 'saved_collection',
          'createdAt': summary.createdAt,
          'collection': summary,
        },
      );
    }
    for (final watch in _watchLater) {
      if (watch.type == WatchLaterTargetType.collection &&
          watch.collection != null) {
        final summary = watch.collection!;
        final key = 'watch_later_collection:${summary.id}';
        if (!dedupe.add(key)) continue;
        entries.add(
          <String, dynamic>{
            'key': key,
            'kind': 'watch_later_collection',
            'createdAt': watch.createdAt,
            'collection': summary,
          },
        );
      } else if (watch.type == WatchLaterTargetType.post &&
          watch.post != null) {
        final preset = watch.post!;
        final key = 'watch_later_post:${preset.id}';
        if (!dedupe.add(key)) continue;
        entries.add(
          <String, dynamic>{
            'key': key,
            'kind': 'watch_later_post',
            'createdAt': watch.createdAt,
            'preset': preset,
          },
        );
      }
    }

    entries.sort((a, b) {
      final DateTime aTime = a['createdAt'] is DateTime
          ? a['createdAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime = b['createdAt'] is DateTime
          ? b['createdAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return entries;
  }

  List<Map<String, dynamic>> _filteredSavedEntries() {
    final entries = _savedEntries();
    switch (_savedFilter) {
      case _SavedGridFilter.savedPosts:
        return entries
            .where((e) => (e['kind']?.toString() ?? '') == 'saved_post')
            .toList();
      case _SavedGridFilter.savedCollections:
        return entries
            .where((e) => (e['kind']?.toString() ?? '') == 'saved_collection')
            .toList();
      case _SavedGridFilter.watchLater:
        return entries
            .where(
                (e) => (e['kind']?.toString() ?? '').startsWith('watch_later_'))
            .toList();
      case _SavedGridFilter.all:
        return entries;
    }
  }

  int _profileGridColumns(double width) {
    if (width >= 1020) return 3;
    if (width >= 700) return 2;
    return 1;
  }

  double _profileGridAspectRatio({
    required double width,
    required int crossAxisCount,
  }) {
    return _kGridPreviewAspectRatio;
  }

  Widget _buildPresetGridTab({
    required List<RenderPreset> presets,
    required String emptyMessage,
    bool enableOwnerActions = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (presets.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = _profileGridColumns(constraints.maxWidth);
        final _SvgGridLayoutSpec gridSpec = _svgGridLayoutSpec(
          viewportWidth: constraints.maxWidth,
          crossAxisCount: crossAxisCount,
        );
        return GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: presets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: gridSpec.crossAxisSpacing,
            mainAxisSpacing: gridSpec.mainAxisSpacing,
            childAspectRatio: _profileGridAspectRatio(
              width: constraints.maxWidth,
              crossAxisCount: crossAxisCount,
            ),
          ),
          itemBuilder: (context, index) {
            final preset = presets[index];
            final String title = preset.title.trim().isNotEmpty
                ? preset.title.trim()
                : preset.name;
            final String mode = preset.thumbnailMode ?? preset.mode;
            final Map<String, dynamic> payload =
                preset.thumbnailPayload.isNotEmpty
                    ? preset.thumbnailPayload
                    : preset.payload;
            final String heroTag = 'post-detail-hero-${preset.id}';
            final int viewsCount = _presetViewsById[preset.id] ?? 0;
            final String authorName = _authorById[preset.userId]?.displayName ??
                _profile?.displayName ??
                'Unknown creator';
            final String? avatarUrl = (_authorById[preset.userId]?.avatarUrl ??
                        _profile?.avatarUrl ??
                        '')
                    .trim()
                    .isNotEmpty
                ? (_authorById[preset.userId]?.avatarUrl ??
                        _profile?.avatarUrl ??
                        '')
                    .trim()
                : null;
            final List<_BlurMenuEntry<String>> menuItems =
                <_BlurMenuEntry<String>>[
              const _BlurMenuEntry.item(value: 'share', label: 'Share'),
              if (enableOwnerActions) const _BlurMenuEntry.divider(),
              if (enableOwnerActions)
                const _BlurMenuEntry.item(value: 'edit', label: 'Update'),
              if (enableOwnerActions)
                _BlurMenuEntry.item(
                  value: 'visibility',
                  label: preset.isPublic ? 'Make Private' : 'Make Public',
                ),
              if (enableOwnerActions)
                const _BlurMenuEntry.item(value: 'delete', label: 'Delete'),
            ];
            return InkWell(
              onTap: () => _openPost(preset),
              child: AspectRatio(
                aspectRatio: _kGridPreviewAspectRatio,
                child: _GridCardPreviewSurface(
                  heroTag: heroTag,
                  mode: mode,
                  payload: payload,
                  title: title,
                  verticalUsername: authorName,
                  priceText: _cardPriceLabel(
                    isPaid: preset.isPaid,
                    priceCents: preset.priceCents,
                    viewerHasPaid: preset.viewerHasPaid,
                  ),
                  avatarImage:
                      avatarUrl == null ? null : NetworkImage(avatarUrl),
                  isVerified: _authorById[preset.userId]?.isVerified == true,
                  accentColor: _cardAccentColorFromHex(preset.accentColorHex),
                  metaText:
                      '${_friendlyCount(viewsCount)} views • ${_friendlyTime(preset.createdAt)}',
                  showCollectionCount: false,
                  collectionCountText: '',
                  menuItems: menuItems,
                  onAvatarTap: () => _openPublicProfileRoute(
                      context, _authorById[preset.userId]),
                  onMenuSelected: (value) {
                    if (value == 'share') _copyPostLink(preset);
                    if (value == 'edit') _editPost(preset);
                    if (value == 'visibility') {
                      _togglePresetVisibility(preset);
                    }
                    if (value == 'delete') _deletePreset(preset);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedUnifiedTab() {
    final cs = Theme.of(context).colorScheme;
    final entries = _filteredSavedEntries();
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = _profileGridColumns(constraints.maxWidth);
        final _SvgGridLayoutSpec gridSpec = _svgGridLayoutSpec(
          viewportWidth: constraints.maxWidth,
          crossAxisCount: crossAxisCount,
        );
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      'All',
                      style: TextStyle(
                        color: _savedFilter == _SavedGridFilter.all
                            ? Colors.black
                            : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _savedFilter == _SavedGridFilter.all,
                    selectedColor: Colors.white,
                    checkmarkColor: Colors.black,
                    onSelected: (_) =>
                        setState(() => _savedFilter = _SavedGridFilter.all),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Saved Posts',
                      style: TextStyle(
                        color: _savedFilter == _SavedGridFilter.savedPosts
                            ? Colors.black
                            : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _savedFilter == _SavedGridFilter.savedPosts,
                    selectedColor: Colors.white,
                    checkmarkColor: Colors.black,
                    onSelected: (_) => setState(
                      () => _savedFilter = _SavedGridFilter.savedPosts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Saved Collections',
                      style: TextStyle(
                        color: _savedFilter == _SavedGridFilter.savedCollections
                            ? Colors.black
                            : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _savedFilter == _SavedGridFilter.savedCollections,
                    selectedColor: Colors.white,
                    checkmarkColor: Colors.black,
                    onSelected: (_) => setState(
                      () => _savedFilter = _SavedGridFilter.savedCollections,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Watch Later',
                      style: TextStyle(
                        color: _savedFilter == _SavedGridFilter.watchLater
                            ? Colors.black
                            : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _savedFilter == _SavedGridFilter.watchLater,
                    selectedColor: Colors.white,
                    checkmarkColor: Colors.black,
                    onSelected: (_) => setState(
                      () => _savedFilter = _SavedGridFilter.watchLater,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing saved yet.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: entries.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: gridSpec.crossAxisSpacing,
                        mainAxisSpacing: gridSpec.mainAxisSpacing,
                        childAspectRatio: _profileGridAspectRatio(
                          width: constraints.maxWidth,
                          crossAxisCount: crossAxisCount,
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final RenderPreset? preset =
                            entry['preset'] as RenderPreset?;
                        final CollectionSummary? collection =
                            entry['collection'] as CollectionSummary?;
                        final bool isCollection = collection != null;
                        final String title = isCollection
                            ? (collection.name.isEmpty
                                ? 'Collection'
                                : collection.name)
                            : ((preset?.title.trim().isNotEmpty == true)
                                ? preset!.title.trim()
                                : (preset?.name ?? 'Post'));
                        final String mode = isCollection
                            ? (collection.thumbnailMode ??
                                collection.firstItem?.mode ??
                                '2d')
                            : (preset?.thumbnailMode ?? preset?.mode ?? '2d');
                        final Map<String, dynamic> payload = isCollection
                            ? (collection.thumbnailPayload.isNotEmpty
                                ? collection.thumbnailPayload
                                : (collection.firstItem?.snapshot ??
                                    const <String, dynamic>{}))
                            : ((preset?.thumbnailPayload.isNotEmpty == true)
                                ? preset!.thumbnailPayload
                                : (preset?.payload ??
                                    const <String, dynamic>{}));
                        final String kind = entry['kind']?.toString() ?? '';
                        final String entityId = isCollection
                            ? collection.id
                            : (preset?.id ?? 'unknown');
                        final int viewsCount = isCollection
                            ? collection.viewsCount
                            : (preset == null
                                ? 0
                                : (_presetViewsById[preset.id] ?? 0));
                        final DateTime createdAt = isCollection
                            ? collection.createdAt
                            : (preset?.createdAt ??
                                (entry['createdAt'] as DateTime));
                        final String authorName = isCollection
                            ? (collection.author?.displayName ??
                                'Unknown creator')
                            : (_authorById[preset?.userId ?? '']?.displayName ??
                                'Unknown creator');
                        final String? avatarUrl = isCollection
                            ? collection.author?.avatarUrl
                            : _authorById[preset?.userId ?? '']?.avatarUrl;
                        final String heroTag = isCollection
                            ? 'collection-detail-hero-${collection.id}-0'
                            : 'post-detail-hero-${preset?.id ?? entityId}';
                        final String removeLabel =
                            kind.startsWith('watch_later')
                                ? 'Remove from Watch Later'
                                : 'Remove from Saved';
                        final List<_BlurMenuEntry<String>> menuItems =
                            <_BlurMenuEntry<String>>[
                          _BlurMenuEntry.item(
                            value: 'remove',
                            label: removeLabel,
                          ),
                          const _BlurMenuEntry.item(
                            value: 'share',
                            label: 'Share',
                          ),
                        ];
                        return InkWell(
                          onTap: () {
                            if (isCollection) {
                              _openCollection(collection);
                              return;
                            }
                            if (!isCollection && preset != null) {
                              _openPost(preset);
                            }
                          },
                          child: AspectRatio(
                            aspectRatio: _kGridPreviewAspectRatio,
                            child: _GridCardPreviewSurface(
                              heroTag: heroTag,
                              mode: mode,
                              payload: payload,
                              title: title,
                              verticalUsername: authorName,
                              priceText: _cardPriceLabel(
                                isPaid: isCollection
                                    ? collection.isPaid
                                    : (preset?.isPaid ?? false),
                                priceCents: isCollection
                                    ? collection.priceCents
                                    : preset?.priceCents,
                                viewerHasPaid: isCollection
                                    ? collection.viewerHasPaid
                                    : (preset?.viewerHasPaid ?? false),
                              ),
                              avatarImage: (avatarUrl ?? '').trim().isNotEmpty
                                  ? NetworkImage(avatarUrl!.trim())
                                  : null,
                              isVerified: isCollection
                                  ? collection.author?.isVerified == true
                                  : _authorById[preset?.userId ?? '']
                                          ?.isVerified ==
                                      true,
                              accentColor: _cardAccentColorFromHex(
                                isCollection
                                    ? collection.accentColorHex
                                    : preset?.accentColorHex,
                              ),
                              metaText:
                                  '${_friendlyCount(viewsCount)} views • ${_friendlyTime(createdAt)}',
                              showCollectionCount: isCollection,
                              collectionCountText: isCollection
                                  ? '${collection.itemsCount}'
                                  : '',
                              menuItems: menuItems,
                              onAvatarTap: () {
                                if (isCollection) {
                                  _openPublicProfileRoute(
                                    context,
                                    collection.author,
                                  );
                                } else {
                                  _openPublicProfileRoute(
                                    context,
                                    _authorById[preset?.userId ?? ''],
                                  );
                                }
                              },
                              onMenuSelected: (value) {
                                if (value == 'remove') {
                                  _removeSavedEntry(entry);
                                }
                                if (value == 'share') {
                                  if (isCollection) {
                                    _copyCollectionLink(collection);
                                  } else if (preset != null) {
                                    _copyPostLink(preset);
                                  }
                                }
                              },
                              emptyChild: isCollection
                                  ? Container(
                                      color: cs.surfaceContainerLow,
                                      child: Center(
                                        child: Icon(
                                          Icons.collections_bookmark_outlined,
                                          color: cs.onSurfaceVariant,
                                          size: 34,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color profilePanelColor =
        isDark ? const Color(0xFF1E1E1E) : cs.surface;
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading profile...');
    }
    if (_error != null) {
      return QueryRetryPane(
        title: _error,
        offline: _isOfflineErrorText(_error!),
        onRetry: _load,
      );
    }

    if (_profile == null) {
      return Center(
        child: Text(
          'Profile unavailable',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: widget.topInset),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: profilePanelColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage: (_profile!.avatarUrl != null &&
                                _profile!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(_profile!.avatarUrl!)
                            : null,
                        backgroundColor: cs.surfaceContainerHighest,
                        child: (_profile!.avatarUrl == null ||
                                _profile!.avatarUrl!.isEmpty)
                            ? Icon(Icons.person,
                                color: cs.onSurfaceVariant, size: 34)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profile!.fullName?.isNotEmpty == true
                                  ? _profile!.fullName!
                                  : 'No full name set',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _profile!.username?.isNotEmpty == true
                                  ? '@${_profile!.username}'
                                  : '@set_username',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _profile!.email,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FilledButton.tonal(
                            onPressed: _editProfile,
                            child: const Text('Edit Profile'),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _confirmSignOut,
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Logout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_profile!.bio.isNotEmpty)
                    Text(
                      _profile!.bio,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _countBlock('Followers', _stats.followersCount),
                      _countBlock('Following', _stats.followingCount),
                      _countBlock('Posts', _stats.postsCount),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              indicatorColor: cs.primary,
              labelColor: cs.onSurface,
              unselectedLabelColor: cs.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Saved'),
                Tab(text: 'My Posts'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSavedUnifiedTab(),
                  _buildPresetGridTab(
                    presets: _posts,
                    emptyMessage: 'No posts yet.',
                    enableOwnerActions: true,
                  ),
                  _buildPresetGridTab(
                    presets: _history,
                    emptyMessage: 'No history yet.',
                    enableOwnerActions: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBlock(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage({required this.profile});

  final AppUserProfile profile;

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  final AppRepository _repository = AppRepository.instance;

  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _bioController;

  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.profile.username ?? '');
    _fullNameController =
        TextEditingController(text: widget.profile.fullName ?? '');
    _bioController = TextEditingController(text: widget.profile.bio);
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final file = await pickDeviceFile(accept: 'image/*');
      if (file == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
        return;
      }
      final String url = await _repository.uploadProfileAvatar(
        bytes: file.bytes,
        fileName: file.name,
        contentType: file.contentType,
      );
      await _repository.updateCurrentProfile(avatarUrl: url);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture uploaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repository.updateCurrentProfile(
        username: _usernameController.text,
        fullName: _fullNameController.text,
        bio: _bioController.text,
        avatarUrl: _avatarUrl,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Edit Profile'),
      ),
      body: Center(
        child: SizedBox(
          width: 560,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? NetworkImage(_avatarUrl!)
                            : null,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person,
                            color: cs.onSurfaceVariant, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _uploadingAvatar ? null : _uploadAvatar,
                    child: Text(
                      _uploadingAvatar
                          ? 'Uploading...'
                          : 'Upload Profile Picture',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                controller: TextEditingController(text: widget.profile.email),
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTab extends StatefulWidget {
  const _ChatTab({super.key, required this.topInset});

  final double topInset;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<ChatSummary> _chats = const <ChatSummary>[];
  ChatSummary? _activeChat;
  List<AppUserProfile> _activeMembers = const <AppUserProfile>[];
  List<RenderPreset> _shareablePresets = const <RenderPreset>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    debugPrint('Disposing ChatTab');
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap({String? preferredChatId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await QueryGuard.run(
        () => _repository.fetchChatsForCurrentUser(),
      );
      final shareables = await QueryGuard.run(
        () => _repository.fetchRecentViewedPresetsForSharing(),
      );

      ChatSummary? active;
      List<AppUserProfile> members = const <AppUserProfile>[];
      if (chats.isNotEmpty) {
        final String? currentId = preferredChatId ?? _activeChat?.id;
        final ChatSummary selected = _chatById(chats, currentId) ?? chats.first;
        active = selected;
        members = await QueryGuard.run(
          () => _repository.fetchChatMembers(selected.id),
        );
      }

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _shareablePresets = shareables;
        _activeChat = active;
        _activeMembers = members;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    }
  }

  ChatSummary? _chatById(List<ChatSummary> chats, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final ChatSummary chat in chats) {
      if (chat.id == id) return chat;
    }
    return null;
  }

  void _touchChat(String chatId, String messagePreview) {
    final List<ChatSummary> updated = _chats
        .map((ChatSummary chat) => chat.id == chatId
            ? ChatSummary(
                id: chat.id,
                isGroup: chat.isGroup,
                name: chat.name,
                members: chat.members,
                lastMessage: messagePreview,
                lastMessageAt: DateTime.now(),
              )
            : chat)
        .toList();
    updated.sort((a, b) {
      final DateTime aTime =
          a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime =
          b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    _chats = updated;
  }

  Future<void> _selectChat(ChatSummary chat) async {
    try {
      final members = await QueryGuard.run(
        () => _repository.fetchChatMembers(chat.id),
      );
      if (!mounted) return;
      setState(() {
        _activeChat = chat;
        _activeMembers = members;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Retry.')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final chat = _activeChat;
    if (chat == null) return;

    final String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      await _repository.sendChatMessage(chatId: chat.id, body: text);
      if (!mounted) return;
      setState(() => _touchChat(chat.id, text));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  Future<void> _sharePreset(RenderPreset preset) async {
    final chat = _activeChat;
    if (chat == null) return;
    try {
      await _repository.sendChatMessage(
        chatId: chat.id,
        body: 'Shared a preset',
        sharedPresetId: preset.id,
      );
      if (!mounted) return;
      setState(() => _touchChat(chat.id, 'Shared a preset'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share preset: $e')),
      );
    }
  }

  Future<void> _openSharedPreset(String presetId) async {
    try {
      final preset = await QueryGuard.run(
        () => _repository.fetchPresetByRouteId(presetId),
      );
      if (!mounted) return;
      if (preset != null) {
        await Navigator.pushNamed(context, buildPostRoutePathForPreset(preset));
        return;
      }
      await Navigator.pushNamed(
        context,
        '/post/${Uri.encodeComponent(presetId)}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Retry.')),
      );
    }
  }

  Future<void> _newDirectChat() async {
    final profile = await showDialog<AppUserProfile>(
      context: context,
      builder: (context) =>
          const _ProfilePickerDialog(title: 'Start Direct Chat'),
    );
    if (profile == null) return;
    try {
      final chatId = await _repository.createOrGetDirectChat(profile.userId);
      await _bootstrap(preferredChatId: chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start direct chat: $e')),
      );
    }
  }

  Future<void> _newGroupChat() async {
    final result = await showDialog<_GroupChatPayload>(
      context: context,
      builder: (context) => const _GroupChatDialog(),
    );
    if (result == null) return;
    try {
      final chatId = await _repository.createGroupChat(
        name: result.name,
        memberIds: result.memberIds,
      );
      if (chatId.isEmpty) {
        throw Exception('Empty chat id returned by server.');
      }
      await _bootstrap(preferredChatId: chatId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor = isDark ? const Color(0xFF1E1E1E) : cs.surface;
    final Color messageInputColor =
        isDark ? const Color(0xFF1E1E1E) : cs.surfaceContainerHighest;
    if (_loading) {
      return const _TopEdgeLoadingPane(label: 'Loading chats...');
    }
    if (_error != null) {
      return QueryRetryPane(
        title: _error,
        offline: _isOfflineErrorText(_error!),
        onRetry: _bootstrap,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, widget.topInset, 10, 10),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: _newDirectChat,
                          child: const Text('New Direct'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _newGroupChat,
                          child: const Text('New Group'),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: cs.outline.withValues(alpha: 0.22)),
                  Expanded(
                    child: _chats.isEmpty
                        ? Center(
                            child: Text(
                              'No chats yet',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              final bool active = _activeChat?.id == chat.id;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Material(
                                  color: active
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  child: ListTile(
                                    selected: active,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    selectedTileColor: Colors.transparent,
                                    title: Text(
                                      chat.titleFor(
                                          _repository.currentUser?.id ?? ''),
                                      style: TextStyle(
                                        color: active
                                            ? Colors.black
                                            : cs.onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      chat.lastMessage ??
                                          (chat.isGroup
                                              ? 'Group chat'
                                              : 'Direct message'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: active
                                            ? Colors.black54
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                    onTap: () => _selectChat(chat),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: _activeChat == null
                  ? Center(
                      child: Text(
                        'Select a chat',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.22)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _activeChat!.titleFor(
                                  _repository.currentUser?.id ?? '',
                                ),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              PopupMenuButton<RenderPreset>(
                                tooltip: 'Share preset',
                                onSelected: _sharePreset,
                                color: cs.surfaceContainerHighest,
                                itemBuilder: (context) {
                                  if (_shareablePresets.isEmpty) {
                                    return const [
                                      PopupMenuItem<RenderPreset>(
                                        enabled: false,
                                        child: Text('No presets found'),
                                      ),
                                    ];
                                  }

                                  return _shareablePresets
                                      .take(20)
                                      .map(
                                        (preset) => PopupMenuItem<RenderPreset>(
                                          value: preset,
                                          child: Text(
                                            preset.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(Icons.share_outlined,
                                      color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<List<ChatMessageItem>>(
                            stream: _repository.streamMessagesForChat(
                              _activeChat!.id,
                            ),
                            builder: (context, snapshot) {
                              final messages =
                                  snapshot.data ?? const <ChatMessageItem>[];
                              if (messages.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No messages yet',
                                    style:
                                        TextStyle(color: cs.onSurfaceVariant),
                                  ),
                                );
                              }

                              final String? me = _repository.currentUser?.id;
                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final bool mine =
                                      me != null && msg.senderId == me;
                                  final AppUserProfile? author = _activeMembers
                                      .cast<AppUserProfile?>()
                                      .firstWhere(
                                        (p) =>
                                            p != null &&
                                            p.userId == msg.senderId,
                                        orElse: () => null,
                                      );

                                  return Align(
                                    alignment: mine
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      constraints:
                                          const BoxConstraints(maxWidth: 420),
                                      decoration: BoxDecoration(
                                        color: mine
                                            ? cs.primary.withValues(alpha: 0.18)
                                            : panelColor.withValues(
                                                alpha: 0.95),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mine
                                                ? 'You'
                                                : (author?.displayName ??
                                                    'User'),
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (msg.body.trim().isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                msg.body,
                                                style: TextStyle(
                                                    color: cs.onSurface),
                                              ),
                                            ),
                                          if (msg.sharedPresetId != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openSharedPreset(
                                                  msg.sharedPresetId!,
                                                ),
                                                icon: const Icon(
                                                    Icons.open_in_new,
                                                    size: 16),
                                                label: const Text(
                                                    'Open shared preset'),
                                              ),
                                            ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              _friendlyTime(msg.createdAt),
                                              style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    filled: true,
                                    fillColor: messageInputColor.withValues(
                                        alpha: 0.4),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _sendMessage,
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePickerDialog extends StatefulWidget {
  const _ProfilePickerDialog({required this.title});

  final String title;

  @override
  State<_ProfilePickerDialog> createState() => _ProfilePickerDialogState();
}

class _ProfilePickerDialogState extends State<_ProfilePickerDialog> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  List<AppUserProfile> _profiles = const <AppUserProfile>[];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _search();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _search);
  }

  Future<void> _search() async {
    final int token = ++_queryToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await QueryGuard.run(
        () => _repository.searchProfiles(_searchController.text),
      );
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = const <AppUserProfile>[];
        _loading = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text(widget.title, style: TextStyle(color: cs.onSurface)),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search username/full name/email',
                      filled: true,
                      fillColor: cs.surfaceContainerLow,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(
                height: 72,
                child: _TopEdgeLoadingPane(label: 'Searching users...'),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _search,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No users found.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 340,
                child: ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final p = _profiles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                ? NetworkImage(p.avatarUrl!)
                                : null,
                        child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        p.displayName,
                        style: TextStyle(color: cs.onSurface),
                      ),
                      subtitle: Text(
                        p.email,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupChatPayload {
  const _GroupChatPayload({required this.name, required this.memberIds});

  final String name;
  final List<String> memberIds;
}

class _GroupChatDialog extends StatefulWidget {
  const _GroupChatDialog();

  @override
  State<_GroupChatDialog> createState() => _GroupChatDialogState();
}

class _GroupChatDialogState extends State<_GroupChatDialog> {
  final AppRepository _repository = AppRepository.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AppUserProfile> _profiles = const <AppUserProfile>[];
  final Set<String> _selected = <String>{};
  Timer? _debounce;
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _loadProfiles);
  }

  Future<void> _loadProfiles() async {
    final int token = ++_queryToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await QueryGuard.run(
        () => _repository.searchProfiles(
          _searchController.text,
          limit: 80,
        ),
      );
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted || token != _queryToken) return;
      setState(() {
        _profiles = const <AppUserProfile>[];
        _loading = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool canCreate =
        _nameController.text.trim().isNotEmpty && _selected.isNotEmpty;
    final List<AppUserProfile> visibleProfiles = _profiles;
    return AlertDialog(
      backgroundColor: cs.surface,
      title: Text('Create Group Chat', style: TextStyle(color: cs.onSurface)),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(
                height: 72,
                child: _TopEdgeLoadingPane(label: 'Searching users...'),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _loadProfiles,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (visibleProfiles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No users found.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: visibleProfiles.length,
                  itemBuilder: (context, index) {
                    final p = visibleProfiles[index];
                    final bool checked = _selected.contains(p.userId);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(p.userId);
                          } else {
                            _selected.remove(p.userId);
                          }
                        });
                      },
                      activeColor: cs.primary,
                      checkColor: Colors.black,
                      title: Text(
                        p.displayName,
                        style: TextStyle(color: cs.onSurface),
                      ),
                      subtitle: Text(
                        p.email,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canCreate
              ? () {
                  final String name = _nameController.text.trim();
                  Navigator.pop(
                    context,
                    _GroupChatPayload(
                        name: name, memberIds: _selected.toList()),
                  );
                }
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _PostCardComposerPage extends StatefulWidget {
  const _PostCardComposerPage.single({
    required this.name,
    required this.mode,
    required this.payload,
    this.existingPreset,
    this.initialIsPaid = false,
    this.initialPriceCents,
    this.initialAccentColorHex,
    this.editTarget = _ComposerEditTarget.card,
    this.startBlankCard = true,
  })  : kind = _ComposerKind.single,
        collectionId = null,
        collectionName = '',
        collectionDescription = '',
        items = const <CollectionDraftItem>[],
        published = true,
        tags = const <String>[],
        mentionUserIds = const <String>[],
        initialCardPayload = const <String, dynamic>{},
        initialCardMode = null;

  const _PostCardComposerPage.collection({
    this.collectionId,
    required this.collectionName,
    required this.collectionDescription,
    required this.tags,
    required this.mentionUserIds,
    required this.published,
    required this.items,
    this.initialIsPaid = false,
    this.initialPriceCents,
    this.initialAccentColorHex,
    this.initialCardPayload = const <String, dynamic>{},
    this.initialCardMode,
    this.editTarget = _ComposerEditTarget.card,
    this.startBlankCard = true,
  })  : kind = _ComposerKind.collection,
        existingPreset = null,
        name = '',
        mode = kImageRenderMode,
        payload = const <String, dynamic>{};

  final _ComposerKind kind;
  final String name;
  final String mode;
  final Map<String, dynamic> payload;
  final RenderPreset? existingPreset;
  final bool initialIsPaid;
  final int? initialPriceCents;
  final String? initialAccentColorHex;
  final String? collectionId;
  final String collectionName;
  final String collectionDescription;
  final List<String> tags;
  final List<String> mentionUserIds;
  final bool published;
  final List<CollectionDraftItem> items;
  final Map<String, dynamic> initialCardPayload;
  final String? initialCardMode;
  final _ComposerEditTarget editTarget;
  final bool startBlankCard;

  bool get isEdit {
    if (kind == _ComposerKind.single) return existingPreset != null;
    return collectionId != null && collectionId!.isNotEmpty;
  }

  @override
  State<_PostCardComposerPage> createState() => _PostCardComposerPageState();
}

class _PostCardComposerPageState extends State<_PostCardComposerPage> {
  final AppRepository _repository = AppRepository.instance;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  final TextEditingController _mentionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  late final TextEditingController _accentHexController;

  final Set<String> _selectedMentionIds = <String>{};
  final Map<String, AppUserProfile> _selectedMentionProfiles =
      <String, AppUserProfile>{};
  List<AppUserProfile> _mentionResults = const <AppUserProfile>[];
  Timer? _mentionDebounce;
  int _mentionToken = 0;
  bool _mentionLoading = false;
  bool _submitting = false;
  bool _isPublic = true;
  bool _isPaidContent = false;
  String _accentColorHex = '#FD4687';
  int _thumbnailIndex = 0;
  late final List<CollectionDraftItem> _items;

  bool get _isCollection => widget.kind == _ComposerKind.collection;

  @override
  void initState() {
    super.initState();
    final RenderPreset? existing = widget.existingPreset;
    _items = widget.items
        .map(
          (item) => CollectionDraftItem(
            mode: kImageRenderMode,
            name: item.name,
            snapshot: normalizeImagePayload(
              item.snapshot,
              fallbackMode: item.mode,
              editor: 'collection_item_normalizer',
            ),
          ),
        )
        .toList();
    _titleController = TextEditingController(
      text: _isCollection
          ? widget.collectionName
          : (existing?.title.isNotEmpty == true
              ? existing!.title
              : widget.name),
    );
    _descriptionController = TextEditingController(
      text: _isCollection
          ? widget.collectionDescription
          : existing?.description ?? '',
    );
    _tagsController = TextEditingController(
      text: (_isCollection ? widget.tags : existing?.tags ?? const <String>[])
          .join(' '),
    );
    _isPublic = _isCollection ? widget.published : existing?.isPublic ?? true;
    _isPaidContent = widget.initialIsPaid;
    if (widget.initialPriceCents != null) {
      _priceController.text = (widget.initialPriceCents! / 100).toStringAsFixed(
        widget.initialPriceCents! % 100 == 0 ? 0 : 2,
      );
    }
    _accentColorHex = widget.initialAccentColorHex ?? '#FD4687';
    _accentHexController = TextEditingController(text: _accentColorHex);
    final mentions = _isCollection
        ? widget.mentionUserIds
        : existing?.mentionUserIds ?? const <String>[];
    _selectedMentionIds.addAll(mentions);
    _mentionController.addListener(_scheduleMentionSearch);
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _mentionController
      ..removeListener(_scheduleMentionSearch)
      ..dispose();
    _priceController.dispose();
    _accentHexController.dispose();
    super.dispose();
  }

  void _scheduleMentionSearch() {
    _mentionDebounce?.cancel();
    final String query = _mentionController.text.trim().replaceFirst('@', '');
    if (query.length < 2) {
      setState(() => _mentionResults = const <AppUserProfile>[]);
      return;
    }
    final int token = ++_mentionToken;
    _mentionDebounce = Timer(const Duration(milliseconds: 260), () async {
      setState(() => _mentionLoading = true);
      try {
        final results = await QueryGuard.run(
          () => _repository.searchMentionTargets(query, limit: 8),
        );
        if (!mounted || token != _mentionToken) return;
        setState(() {
          _mentionResults = results;
          _mentionLoading = false;
        });
      } catch (_) {
        if (!mounted || token != _mentionToken) return;
        setState(() => _mentionLoading = false);
      }
    });
  }

  void _addMention(AppUserProfile profile) {
    setState(() {
      _selectedMentionIds.add(profile.userId);
      _selectedMentionProfiles[profile.userId] = profile;
      _mentionController.clear();
      _mentionResults = const <AppUserProfile>[];
    });
  }

  void _removeMention(String id) {
    setState(() {
      _selectedMentionIds.remove(id);
      _selectedMentionProfiles.remove(id);
    });
  }

  List<String> _tagsFromInput() {
    return _tagsController.text
        .split(RegExp(r'[\s,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int? _priceInputToCents(String raw) {
    final String normalized = raw.trim().replaceAll(',', '');
    if (normalized.isEmpty) return null;
    final double? dollars = double.tryParse(normalized);
    if (dollars == null) return null;
    return (dollars * 100).round().clamp(0, 999999999);
  }

  void _applyAccentText(String value) {
    final String raw = value.trim();
    final String normalized = raw.startsWith('#') ? raw : '#$raw';
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
      setState(() => _accentColorHex = normalized.toUpperCase());
    }
  }

  Map<String, dynamic> _singlePayload() {
    return normalizeImagePayload(
      widget.payload,
      fallbackMode: widget.mode,
      editor: 'composer_single',
    );
  }

  Map<String, dynamic> _previewPayload() {
    if (_isCollection) {
      if (_items.isEmpty) return simpleImagePayload(imageUrl: '');
      final int index = _thumbnailIndex.clamp(0, _items.length - 1);
      return _items[index].snapshot;
    }
    return _singlePayload();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final List<String> tags = _tagsFromInput();
      final List<String> mentions = _selectedMentionIds.toList();
      final int? priceCents =
          _isPaidContent ? _priceInputToCents(_priceController.text) : null;
      final String visibility = _isPublic ? 'public' : 'private';
      if (_isCollection) {
        if (_items.isEmpty) {
          throw Exception('Collection needs at least one image.');
        }
        final int thumbIndex = _thumbnailIndex.clamp(0, _items.length - 1);
        await _repository.saveCollectionWithItems(
          collectionId: widget.collectionId,
          name: title,
          description: _descriptionController.text.trim(),
          tags: tags,
          mentionUserIds: mentions,
          thumbnailPayload: _items[thumbIndex].snapshot,
          thumbnailMode: kImageRenderMode,
          publish: _isPublic,
          items: _items,
          isPaid: _isPaidContent,
          priceCents: priceCents,
          accentColorHex: _accentColorHex,
        );
      } else {
        final payload = _singlePayload();
        if (imageUrlFromPayload(payload, fallbackMode: kImageRenderMode) ==
            null) {
          throw Exception('Post needs one image.');
        }
        final existing = widget.existingPreset;
        if (existing != null) {
          await _repository.updatePresetDetail(
            presetId: existing.id,
            title: title,
            description: _descriptionController.text.trim(),
            tags: tags,
            mentionUserIds: mentions,
            payload: payload,
            mode: kImageRenderMode,
            visibility: visibility,
            isPaid: _isPaidContent,
            priceCents: priceCents,
            accentColorHex: _accentColorHex,
          );
          await _repository.updatePresetCard(
            presetId: existing.id,
            thumbnailPayload: payload,
            thumbnailMode: kImageRenderMode,
            title: title,
            description: _descriptionController.text.trim(),
            tags: tags,
            mentionUserIds: mentions,
            visibility: visibility,
            isPaid: _isPaidContent,
            priceCents: priceCents,
            accentColorHex: _accentColorHex,
          );
        } else {
          await _repository.publishPresetPost(
            mode: kImageRenderMode,
            name: widget.name.trim().isEmpty ? title : widget.name.trim(),
            payload: payload,
            title: title,
            description: _descriptionController.text.trim(),
            tags: tags,
            mentionUserIds: mentions,
            visibility: visibility,
            thumbnailPayload: payload,
            thumbnailMode: kImageRenderMode,
            isPaid: _isPaidContent,
            priceCents: priceCents,
            accentColorHex: _accentColorHex,
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildPreview(ColorScheme cs) {
    final payload = _previewPayload();
    final int? previewPriceCents = _priceInputToCents(_priceController.text);
    return AspectRatio(
      aspectRatio: _kGridPreviewAspectRatio,
      child: SvgCardShell(
        baseColor: const Color(0xFFF0F0F0),
        accentColor: _cardAccentColorFromHex(_accentColorHex),
        title: _titleController.text.trim(),
        metaText: '0 views • now',
        verticalUsername: 'USER',
        priceLabel: _cardPriceLabel(
          isPaid: _isPaidContent,
          priceCents: previewPriceCents,
          viewerHasPaid: false,
        ),
        showCollectionCount: _isCollection,
        collectionCountLabel: '${_items.length}',
        child: _SharedPresetPreview(
          mode: kImageRenderMode,
          payload: payload,
          clipper: const SvgCardClipper(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final String composerTitle = _isCollection
        ? (widget.isEdit ? 'Update Collection' : 'Publish Collection')
        : (widget.isEdit ? 'Update Post' : 'Publish Post');
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          composerTitle,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: _buildPreview(cs),
                      ),
                    ),
                  ),
                  if (_isCollection && _items.length > 1) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(_items.length, (index) {
                        return ChoiceChip(
                          selected: index == _thumbnailIndex,
                          label: Text('${index + 1}. ${_items[index].name}'),
                          onSelected: (_) =>
                              setState(() => _thumbnailIndex = index),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: 430,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  left: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _isCollection ? 'Collection Title' : 'Title',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: '#image #fyp',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mentionController,
                    decoration: const InputDecoration(
                      labelText: 'Mention',
                      hintText: '@username',
                    ),
                  ),
                  if (_mentionLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(color: Colors.white),
                    ),
                  if (_mentionResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _mentionResults.length,
                        itemBuilder: (context, index) {
                          final user = _mentionResults[index];
                          return ListTile(
                            dense: true,
                            title: Text(user.displayName),
                            subtitle: Text(user.username == null
                                ? user.email
                                : '@${user.username}'),
                            onTap: () => _addMention(user),
                          );
                        },
                      ),
                    ),
                  if (_selectedMentionIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedMentionIds.map((id) {
                          final profile = _selectedMentionProfiles[id];
                          final label = profile == null
                              ? '@${id.substring(0, math.min(8, id.length))}'
                              : '@${profile.username ?? profile.displayName}';
                          return InputChip(
                            label: Text(label),
                            onDeleted: () => _removeMention(id),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text('Monetization',
                      style: TextStyle(
                          color: cs.onSurface, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(value: false, label: Text('Free')),
                      ButtonSegment<bool>(value: true, label: Text('Paid')),
                    ],
                    selected: <bool>{_isPaidContent},
                    onSelectionChanged: (values) {
                      setState(() {
                        _isPaidContent = values.first;
                        if (!_isPaidContent) _priceController.clear();
                      });
                    },
                  ),
                  if (_isPaidContent) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Price (USD)',
                        prefixText: '\$',
                        hintText: '4.99',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _accentHexController,
                    onChanged: _applyAccentText,
                    decoration: const InputDecoration(
                      labelText: 'Accent Hex',
                      hintText: '#FD4687',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(value: true, label: Text('Public')),
                      ButtonSegment<bool>(value: false, label: Text('Private')),
                    ],
                    selected: <bool>{_isPublic},
                    onSelectionChanged: (values) =>
                        setState(() => _isPublic = values.first),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting
                              ? 'Working...'
                              : widget.isEdit
                                  ? 'Update'
                                  : 'Publish'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  final String currentThemeMode;
  final ValueChanged<String>? onThemeModeChanged;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

enum _SettingsSection {
  appearance,
  profile,
  notifications,
  privacy,
  playback,
  about,
}

class _SettingsTabState extends State<_SettingsTab> {
  final AppRepository _repository = AppRepository.instance;

  late String _themeMode;
  _SettingsSection _selectedSection = _SettingsSection.appearance;
  AppUserProfile? _profile;
  bool _profileLoading = true;
  String? _profileError;
  bool _wallpaperUploading = false;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.currentThemeMode;
    _loadProfileSummary();
  }

  @override
  void didUpdateWidget(covariant _SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentThemeMode != widget.currentThemeMode) {
      _themeMode = widget.currentThemeMode;
    }
  }

  Future<void> _setTheme(String mode) async {
    setState(() => _themeMode = mode);
    await _repository.updateThemeModeForCurrentUser(mode);
    widget.onThemeModeChanged?.call(mode);
  }

  Future<void> _loadProfileSummary() async {
    final user = _repository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileError = 'Sign in to manage profile settings.';
      });
      return;
    }
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final profile = await QueryGuard.run(
        () => _repository.fetchCurrentUserProfile(),
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileLoading = false;
      });
    } catch (e) {
      final failure = QueryGuard.classify(e);
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileError = failure.message;
      });
    }
  }

  Future<void> _uploadWallpaper() async {
    if (_wallpaperUploading) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _wallpaperUploading = true);
    try {
      final file = await pickDeviceFile(accept: 'image/*');
      if (file == null) return;
      final publicUrl = await _repository.uploadAssetBytes(
        bytes: file.bytes,
        fileName: file.name,
        contentType: file.contentType,
        folder: 'wallpapers',
      );
      AppearanceSettingsService.instance.updateWallpaperImageUrl(publicUrl);
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Wallpaper upload failed: $e')));
    } finally {
      if (mounted) setState(() => _wallpaperUploading = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final bool shouldSignOut = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You can sign back in anytime.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldSignOut) return;
    await _repository.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/feed');
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _EditProfilePage(profile: profile)),
    );
    await _loadProfileSummary();
  }

  Widget _settingsNavItem({
    required ColorScheme cs,
    required _SettingsSection section,
    required IconData icon,
    required String label,
    String? subtitle,
  }) {
    final bool selected = _selectedSection == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          selected: selected,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          selectedTileColor: Colors.transparent,
          leading:
              Icon(icon, color: selected ? Colors.black : cs.onSurfaceVariant),
          title: Text(label,
              style: TextStyle(color: selected ? Colors.black : cs.onSurface)),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: TextStyle(
                      color: selected ? Colors.black54 : cs.onSurfaceVariant),
                ),
          onTap: () => setState(() => _selectedSection = section),
        ),
      ),
    );
  }

  Widget _buildSettingsNav(ColorScheme cs, Color panelColor) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              'Settings',
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
          _settingsNavItem(
            cs: cs,
            section: _SettingsSection.appearance,
            icon: Icons.palette_rounded,
            label: 'Appearance',
            subtitle: 'Theme, blur, wallpaper',
          ),
          _settingsNavItem(
            cs: cs,
            section: _SettingsSection.profile,
            icon: Icons.person_rounded,
            label: 'Profile',
            subtitle: 'Account settings',
          ),
          _settingsNavItem(
            cs: cs,
            section: _SettingsSection.notifications,
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            subtitle: 'Activity alerts',
          ),
          _settingsNavItem(
            cs: cs,
            section: _SettingsSection.privacy,
            icon: Icons.lock_rounded,
            label: 'Privacy & Safety',
            subtitle: 'Visibility controls',
          ),
          _settingsNavItem(
            cs: cs,
            section: _SettingsSection.playback,
            icon: Icons.storage_rounded,
            label: 'Playback & Data',
            subtitle: 'Quality & usage',
          ),
          _settingsNavItem(
            cs: cs,
            section: _SettingsSection.about,
            icon: Icons.info_outline_rounded,
            label: 'About',
            subtitle: 'Version & help',
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Choose how DeepX looks.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _themeMode,
                dropdownColor: cs.surfaceContainerHighest,
                style: TextStyle(color: cs.onSurface),
                items: const [
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'system', child: Text('System')),
                ],
                onChanged: (value) {
                  if (value != null) _setTheme(value);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: ValueListenableBuilder<AppearanceSettings>(
            valueListenable: AppearanceSettingsService.instance.settings,
            builder: (context, settings, _) {
              final Color overlayColor = Color(settings.wallpaperOverlayColor);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grid Wallpaper',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Set the image behind home and collection grids, then tint it with an overlay.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 16 / 7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (settings.wallpaperImageUrl.trim().isNotEmpty)
                            Image.network(
                              settings.wallpaperImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  ColoredBox(color: cs.surfaceContainerHighest),
                            )
                          else
                            ColoredBox(color: cs.surfaceContainerHighest),
                          ColoredBox(
                            color: overlayColor.withValues(
                                alpha: settings.wallpaperOverlayOpacity),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _wallpaperUploading ? null : _uploadWallpaper,
                          icon: _wallpaperUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded),
                          label: Text(_wallpaperUploading
                              ? 'Uploading...'
                              : 'Upload Wallpaper'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Clear wallpaper',
                        onPressed: AppearanceSettingsService
                            .instance.clearWallpaperImage,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Overlay Color'),
                      const Spacer(),
                      for (final color in const <Color>[
                        Colors.black,
                        Color(0xFF101213),
                        Color(0xFFFD4687),
                        Color(0xFF2845E1),
                        Colors.white,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            onTap: () => AppearanceSettingsService.instance
                                .updateWallpaperOverlayColor(color.toARGB32()),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.outline),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _appearanceSlider(
                    label: 'Overlay Opacity',
                    value: settings.wallpaperOverlayOpacity,
                    min: 0,
                    max: 1,
                    onChanged: AppearanceSettingsService
                        .instance.updateWallpaperOverlayOpacity,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: ValueListenableBuilder<AppearanceSettings>(
            valueListenable: AppearanceSettingsService.instance.settings,
            builder: (context, settings, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ambient Blur',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Adjust blur strength for post and collection detail backgrounds.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _appearanceSlider(
                    label: 'Blur Sigma X',
                    value: settings.ambientBlurSigmaX,
                    min: 0,
                    max: 100,
                    onChanged: AppearanceSettingsService.instance.updateSigmaX,
                  ),
                  _appearanceSlider(
                    label: 'Blur Sigma Y',
                    value: settings.ambientBlurSigmaY,
                    min: 0,
                    max: 100,
                    onChanged: AppearanceSettingsService.instance.updateSigmaY,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(ColorScheme cs) {
    final profile = _profile;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile Settings',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_profileLoading)
                const SizedBox(
                    height: 60,
                    child: _TopEdgeLoadingPane(label: 'Loading profile...'))
              else if (_profileError != null)
                SizedBox(
                  height: 160,
                  child: QueryRetryPane(
                    title: _profileError,
                    offline: _isOfflineErrorText(_profileError!),
                    onRetry: _loadProfileSummary,
                  ),
                )
              else if (profile == null)
                Text('Sign in to manage profile settings.',
                    style: TextStyle(color: cs.onSurfaceVariant))
              else ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          (profile.avatarUrl ?? '').trim().isNotEmpty
                              ? NetworkImage(profile.avatarUrl!.trim())
                              : null,
                      child: (profile.avatarUrl ?? '').trim().isEmpty
                          ? Text(profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : 'U')
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.displayName,
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            (profile.username ?? '').trim().isNotEmpty
                                ? '@${profile.username}'
                                : profile.email,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                        onPressed: _openEditProfile,
                        child: const Text('Edit Profile')),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _confirmSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderSection({
    required ColorScheme cs,
    required String title,
    required String description,
  }) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              Text('Coming soon',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor = isDark ? const Color(0xFF1E1E1E) : cs.surface;

    final Widget sectionBody = switch (_selectedSection) {
      _SettingsSection.appearance => _buildAppearanceSection(cs),
      _SettingsSection.profile => _buildProfileSection(cs),
      _SettingsSection.notifications => _buildPlaceholderSection(
          cs: cs,
          title: 'Notifications',
          description: 'Manage push and email notifications.',
        ),
      _SettingsSection.privacy => _buildPlaceholderSection(
          cs: cs,
          title: 'Privacy & Safety',
          description: 'Control visibility, moderation, and safety tools.',
        ),
      _SettingsSection.playback => _buildPlaceholderSection(
          cs: cs,
          title: 'Playback & Data',
          description: 'Adjust quality preferences and data usage.',
        ),
      _SettingsSection.about => _buildPlaceholderSection(
          cs: cs,
          title: 'About',
          description: 'Version details, policies, and support.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Row(
        children: [
          SizedBox(width: 320, child: _buildSettingsNav(cs, panelColor)),
          const SizedBox(width: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: sectionBody,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceSlider({
    required String label,
    required double value,
    double min = 0,
    double max = 100,
    required ValueChanged<double> onChanged,
  }) {
    final double clamped = value.clamp(min, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${clamped.toStringAsFixed(max <= 1 ? 2 : 0)}'),
        Slider(
          value: clamped,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

Future<bool> _showSignInRequiredSheet(
  BuildContext context, {
  required String message,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

bool _isOfflineErrorText(String value) {
  return value.toLowerCase().contains('no internet');
}

String _friendlyTime(DateTime value) {
  final DateTime now = DateTime.now();
  final Duration d = now.difference(value);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
  return '${(d.inDays / 365).floor()}y ago';
}

String _friendlyCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final double k = value / 1000;
    return k >= 10 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
  }
  if (value < 1000000000) {
    final double m = value / 1000000;
    return m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  }
  final double b = value / 1000000000;
  return b >= 10 ? '${b.toStringAsFixed(0)}B' : '${b.toStringAsFixed(1)}B';
}
