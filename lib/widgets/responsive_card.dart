import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.margin,
    this.radius = AppTheme.radiusMedium,
    this.color = AppTheme.warmCream,
    this.border,
    this.shadow,
  });

  final Widget child;
  final double padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color color;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final adaptiveRadius = context.radius(radius);
    return Container(
      margin: margin,
      padding: context.insetsAll(padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(adaptiveRadius),
        border: border,
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}
