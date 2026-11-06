import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = 10,
    this.tint,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? scheme.surface.withValues(alpha: isDark ? .76 : .74),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  borderColor ??
                  scheme.onSurface.withValues(alpha: isDark ? .12 : .1),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    required this.onPressed,
    required this.child,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.filled = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leading;
  final EdgeInsetsGeometry padding;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onPressed == null ? .48 : 1,
      child: Material(
        color: filled
            ? scheme.primary.withValues(alpha: .82)
            : scheme.surface.withValues(alpha: .54),
        shape: StadiumBorder(
          side: BorderSide(color: scheme.onSurface.withValues(alpha: .14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
