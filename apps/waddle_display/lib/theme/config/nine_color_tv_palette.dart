import 'package:flutter/material.dart';

/// Nine-color TV palette: five neutrals (background → primary text) plus four accents.
@immutable
class NineColorTvPalette {
  const NineColorTvPalette({
    required List<Color> neutrals,
    required List<Color> accents,
  })  : assert(neutrals.length == 5),
        assert(accents.length == 4),
        _neutrals = neutrals,
        _accents = accents;

  final List<Color> _neutrals;
  final List<Color> _accents;

  Color get background => _neutrals[0];
  Color get footerBar => _neutrals[1];
  Color get primary => _neutrals[0];
  Color get primaryText => _neutrals[4];
  Color get mutedText => _neutrals[3];
  Color get iconColor => _neutrals[3];

  List<Color> get neutrals => List<Color>.unmodifiable(_neutrals);
  List<Color> get accents => List<Color>.unmodifiable(_accents);

  List<Color> get orderedPalette => [..._neutrals, ..._accents];

  LinearGradient get primaryPairGradient => LinearGradient(
        colors: [_neutrals[0], _neutrals[1]],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get secondaryPairGradient => LinearGradient(
        colors: [_neutrals[2], _neutrals[3]],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
