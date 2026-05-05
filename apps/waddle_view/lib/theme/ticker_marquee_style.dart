import 'package:flutter/material.dart';

/// Themable styles for RSS-style marquee segments (source / title / summary).
@immutable
class TickerMarqueeStyle extends ThemeExtension<TickerMarqueeStyle> {
  const TickerMarqueeStyle({
    required this.rssSourceStyle,
    required this.rssTitleStyle,
    required this.rssSummaryStyle,
  });

  /// Italic bracketed source label (`[Feed Name]`).
  final TextStyle rssSourceStyle;

  /// Article headline weight (typically bold).
  final TextStyle rssTitleStyle;

  /// Trailing summary / deck (typically regular weight).
  final TextStyle rssSummaryStyle;

  /// Defaults layered on [TextTheme.titleLarge] and [ColorScheme].
  factory TickerMarqueeStyle.fromTvTheme(
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    final base = textTheme.titleLarge ?? const TextStyle();
    return TickerMarqueeStyle(
      rssSourceStyle: base.merge(
        TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
        ),
      ),
      rssTitleStyle: base.merge(
        TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface.withValues(alpha: 0.98),
        ),
      ),
      rssSummaryStyle: base.merge(
        TextStyle(
          fontWeight: FontWeight.w400,
          color: scheme.onSurface.withValues(alpha: 0.82),
        ),
      ),
    );
  }

  /// Fixed palette for tests (lerp, etc.) without a full [ThemeData].
  const TickerMarqueeStyle.fallback()
      : rssSourceStyle = const TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          color: Color(0xFF484F58),
        ),
        rssTitleStyle = const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFFF0F6FC),
        ),
        rssSummaryStyle = const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xFFCCD6E6),
        );

  @override
  ThemeExtension<TickerMarqueeStyle> copyWith({
    TextStyle? rssSourceStyle,
    TextStyle? rssTitleStyle,
    TextStyle? rssSummaryStyle,
  }) {
    return TickerMarqueeStyle(
      rssSourceStyle: rssSourceStyle ?? this.rssSourceStyle,
      rssTitleStyle: rssTitleStyle ?? this.rssTitleStyle,
      rssSummaryStyle: rssSummaryStyle ?? this.rssSummaryStyle,
    );
  }

  @override
  ThemeExtension<TickerMarqueeStyle> lerp(
    ThemeExtension<TickerMarqueeStyle>? other,
    double t,
  ) {
    if (other is! TickerMarqueeStyle) {
      return this;
    }
    return TickerMarqueeStyle(
      rssSourceStyle: TextStyle.lerp(
            rssSourceStyle,
            other.rssSourceStyle,
            t,
          ) ??
          rssSourceStyle,
      rssTitleStyle:
          TextStyle.lerp(rssTitleStyle, other.rssTitleStyle, t) ??
          rssTitleStyle,
      rssSummaryStyle:
          TextStyle.lerp(rssSummaryStyle, other.rssSummaryStyle, t) ??
          rssSummaryStyle,
    );
  }
}

/// Registers [TickerMarqueeStyle] on [ThemeData].
ThemeData applyTickerMarqueeStyle(ThemeData theme) {
  return theme.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      TickerMarqueeStyle.fromTvTheme(theme.textTheme, theme.colorScheme),
    ],
  );
}
