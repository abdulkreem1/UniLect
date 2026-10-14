import 'package:flutter/material.dart';

/// UniLect brand palette, sampled from the logo: deep navy field, royal blue
/// book, sky→cyan highlights and white surfaces.
abstract final class AppColors {
  static const navy950 = Color(0xFF020E3A);
  static const navy900 = Color(0xFF041A5C);
  static const navy800 = Color(0xFF0A2A7A);
  static const blue700 = Color(0xFF0B4FC4);
  static const blue600 = Color(0xFF1463E0);
  static const sky500 = Color(0xFF1E9BF0);
  static const cyan400 = Color(0xFF38C6F4);
  static const cyan200 = Color(0xFFA9E9FC);

  static const surfaceLight = Color(0xFFF4F7FD);
  static const surfaceDark = Color(0xFF040C2B);
  static const cardDark = Color(0xFF0B1A45);

  static const success = Color(0xFF12B76A);
  static const warning = Color(0xFFF79009);
  static const danger = Color(0xFFE5484D);

  /// Primary call-to-action gradient (logo "Lect" lettering).
  static const brandGradient = LinearGradient(
    colors: [sky500, blue700],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );

  /// Deep header/background gradient (logo field).
  static const heroGradient = LinearGradient(
    colors: [navy800, navy950],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Semantic colors not covered by [ColorScheme], available via
/// `Theme.of(context).extension<StatusColors>()`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color neutral;

  @override
  StatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? neutral,
  }) => StatusColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    neutral: neutral ?? this.neutral,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}
