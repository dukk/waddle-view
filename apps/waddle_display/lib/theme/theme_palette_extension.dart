import 'package:flutter/material.dart';

@immutable
class PaletteTertiaryLayers extends ThemeExtension<PaletteTertiaryLayers> {
  const PaletteTertiaryLayers({
    required this.primary,
    required this.iconColor,
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required this.accent4,
    required this.colorOrder,
    required this.tertiaryLayersByColor,
    required this.primaryPairGradient,
    required this.secondaryPairGradient,
  });

  final Color primary;
  final Color iconColor;
  final Color accent1;
  final Color accent2;
  final Color accent3;
  final Color accent4;
  final List<Color> colorOrder;
  final Map<Color, List<Color>> tertiaryLayersByColor;
  final LinearGradient primaryPairGradient;
  final LinearGradient secondaryPairGradient;

  List<Color> tertiaryLayersFor(Color color) {
    final layers = tertiaryLayersByColor[color];
    if (layers == null || layers.isEmpty) {
      return const [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent];
    }
    return layers;
  }

  @override
  PaletteTertiaryLayers copyWith({
    Color? primary,
    Color? iconColor,
    Color? accent1,
    Color? accent2,
    Color? accent3,
    Color? accent4,
    List<Color>? colorOrder,
    Map<Color, List<Color>>? tertiaryLayersByColor,
    LinearGradient? primaryPairGradient,
    LinearGradient? secondaryPairGradient,
  }) {
    return PaletteTertiaryLayers(
      primary: primary ?? this.primary,
      iconColor: iconColor ?? this.iconColor,
      accent1: accent1 ?? this.accent1,
      accent2: accent2 ?? this.accent2,
      accent3: accent3 ?? this.accent3,
      accent4: accent4 ?? this.accent4,
      colorOrder: colorOrder ?? this.colorOrder,
      tertiaryLayersByColor: tertiaryLayersByColor ?? this.tertiaryLayersByColor,
      primaryPairGradient: primaryPairGradient ?? this.primaryPairGradient,
      secondaryPairGradient: secondaryPairGradient ?? this.secondaryPairGradient,
    );
  }

  @override
  PaletteTertiaryLayers lerp(
    covariant ThemeExtension<PaletteTertiaryLayers>? other,
    double t,
  ) {
    if (other is! PaletteTertiaryLayers) {
      return this;
    }
    return PaletteTertiaryLayers(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      iconColor: Color.lerp(iconColor, other.iconColor, t) ?? iconColor,
      accent1: Color.lerp(accent1, other.accent1, t) ?? accent1,
      accent2: Color.lerp(accent2, other.accent2, t) ?? accent2,
      accent3: Color.lerp(accent3, other.accent3, t) ?? accent3,
      accent4: Color.lerp(accent4, other.accent4, t) ?? accent4,
      colorOrder: t < 0.5 ? colorOrder : other.colorOrder,
      tertiaryLayersByColor: t < 0.5 ? tertiaryLayersByColor : other.tertiaryLayersByColor,
      primaryPairGradient: t < 0.5
          ? primaryPairGradient
          : other.primaryPairGradient,
      secondaryPairGradient: t < 0.5
          ? secondaryPairGradient
          : other.secondaryPairGradient,
    );
  }
}
