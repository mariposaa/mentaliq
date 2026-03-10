import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double tinyPhone = 360;
  static const double compactPhone = 390;
  static const double regularPhone = 430;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isTinyPhone => screenWidth <= ResponsiveBreakpoints.tinyPhone;
  bool get isCompactPhone => screenWidth <= ResponsiveBreakpoints.compactPhone;
  bool get isRegularPhone => screenWidth <= ResponsiveBreakpoints.regularPhone;

  double adaptive(double base, {double minScale = 0.88, double maxScale = 1.12}) {
    final scale = (screenWidth / ResponsiveBreakpoints.compactPhone)
        .clamp(minScale, maxScale);
    return base * scale;
  }

  /// Responsive spacing token
  double space(double base) => adaptive(base, minScale: 0.82, maxScale: 1.12);

  /// Responsive font token
  double font(double base) => adaptive(base, minScale: 0.9, maxScale: 1.1);

  /// Responsive radius token
  double radius(double base) => adaptive(base, minScale: 0.9, maxScale: 1.08);

  /// Horizontal page padding token
  double get pageHorizontalPadding => isCompactPhone ? 14 : 20;

  /// Vertical section gap token
  double get sectionGap => isCompactPhone ? 12 : 16;

  EdgeInsets insetsAll(double value) => EdgeInsets.all(space(value));

  EdgeInsets insetsSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: space(horizontal),
      vertical: space(vertical),
    );
  }

  T pick<T>({
    required T tiny,
    required T compact,
    required T regular,
    T? large,
  }) {
    if (isTinyPhone) return tiny;
    if (isCompactPhone) return compact;
    if (isRegularPhone) return regular;
    return large ?? regular;
  }
}
