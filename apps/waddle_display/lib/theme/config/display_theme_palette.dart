import 'package:flutter/material.dart';

import 'display_background_fill.dart';

/// TV display palette: neutrals, accents, container roles, and background fills.
@immutable
class DisplayThemePalette {
  DisplayThemePalette({
    required List<Color> neutrals,
    required List<Color> accents,
    Color? displayBackground,
    DisplayBackgroundFill? displayBackgroundFill,
    Color? primaryContainerBackground,
    Color? primaryContainerForeground,
    DisplayBackgroundFill? primaryContainerFill,
    Color? secondaryContainerBackground,
    Color? secondaryContainerForeground,
    DisplayBackgroundFill? secondaryContainerFill,
  })  : assert(neutrals.length == 5),
        assert(accents.length == 4),
        _neutrals = neutrals,
        _accents = accents,
        displayBackground = displayBackground ?? neutrals[0],
        displayBackgroundFill = displayBackgroundFill ??
            DisplayBackgroundFill(
              solidColor: displayBackground ?? neutrals[0],
              gradientColors: [neutrals[0], neutrals[1]],
            ),
        primaryContainerBackground =
            primaryContainerBackground ?? neutrals[1],
        primaryContainerForeground =
            primaryContainerForeground ?? neutrals[4],
        primaryContainerFill = primaryContainerFill ??
            DisplayBackgroundFill(
              solidColor: primaryContainerBackground ?? neutrals[1],
              gradientColors: [neutrals[1], neutrals[2]],
            ),
        secondaryContainerBackground =
            secondaryContainerBackground ?? neutrals[2],
        secondaryContainerForeground =
            secondaryContainerForeground ?? neutrals[4],
        secondaryContainerFill = secondaryContainerFill ??
            DisplayBackgroundFill(
              solidColor: secondaryContainerBackground ?? neutrals[2],
              gradientColors: [neutrals[2], neutrals[3]],
            );

  final List<Color> _neutrals;
  final List<Color> _accents;

  final Color displayBackground;
  final DisplayBackgroundFill displayBackgroundFill;
  final Color primaryContainerBackground;
  final Color primaryContainerForeground;
  final DisplayBackgroundFill primaryContainerFill;
  final Color secondaryContainerBackground;
  final Color secondaryContainerForeground;
  final DisplayBackgroundFill secondaryContainerFill;

  Color get background => displayBackground;
  Color get footerBar => _neutrals[1];
  Color get primary => displayBackground;
  Color get primaryText => _neutrals[4];
  Color get mutedText => _neutrals[3];
  Color get iconColor => _neutrals[3];

  List<Color> get neutrals => List<Color>.unmodifiable(_neutrals);
  List<Color> get accents => List<Color>.unmodifiable(_accents);

  List<Color> get orderedPalette => [..._neutrals, ..._accents];

  LinearGradient get primaryPairGradient =>
      primaryContainerFill.toLinearGradient() ??
      LinearGradient(colors: [displayBackground, primaryContainerBackground]);

  LinearGradient get secondaryPairGradient =>
      secondaryContainerFill.toLinearGradient() ??
      LinearGradient(
        colors: [secondaryContainerBackground, _neutrals[3]],
      );

  /// Derives container fills from neutrals + accents (Coolors presets).
  factory DisplayThemePalette.fromNeutralsAndAccents({
    required List<Color> neutrals,
    required List<Color> accents,
  }) {
    assert(neutrals.length == 5);
    assert(accents.length == 4);
    return DisplayThemePalette(
      neutrals: neutrals,
      accents: accents,
      displayBackgroundFill: DisplayBackgroundFill(
        solidColor: neutrals[0],
        gradientColors: [neutrals[0], neutrals[1]],
      ),
      primaryContainerFill: DisplayBackgroundFill(
        solidColor: neutrals[1],
        gradientColors: [neutrals[1], neutrals[2]],
      ),
      secondaryContainerFill: DisplayBackgroundFill(
        solidColor: neutrals[2],
        gradientColors: [neutrals[2], neutrals[3], accents[0]],
      ),
    );
  }
}

/// @deprecated Use [DisplayThemePalette].
typedef NineColorTvPalette = DisplayThemePalette;
