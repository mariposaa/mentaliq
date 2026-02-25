import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';

/// Kamp Ateşi paylaşım alanlarında kullanılan resim widget'ı.
/// Resim kırpılmadan ölçeklenir ve [maxHeight] / genişlik kutusuna sığar (BoxFit.contain).
class ForumPostImage extends StatelessWidget {
  const ForumPostImage({
    super.key,
    required this.imageUrl,
    required this.maxHeight,
    double? width,
    double borderRadius = 12,
  })  : width = width ?? double.infinity,
        borderRadius = borderRadius;

  final String imageUrl;
  final double maxHeight;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final maxW = width == double.infinity ? boundedWidth : width;
        return SizedBox(
          height: maxHeight,
          width: maxW,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            clipBehavior: Clip.hardEdge,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: maxW,
              height: maxHeight,
              placeholder: (_, __) => Container(
                color: AppTheme.softBorder,
                child: const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
              ),
              errorWidget: (_, __, e) => Container(
                color: AppTheme.softBorder,
                child: const Center(child: Icon(Icons.broken_image_outlined, color: AppTheme.mutedSage, size: 48)),
              ),
            ),
          ),
        );
      },
    );
  }
}
