import 'package:flutter/material.dart';

/// TV overscan padding as a fraction of the shorter side, with a minimum floor.
class TvOverscanInsets {
  const TvOverscanInsets({
    this.fractionOfShortestSide = 0.03,
    this.minimum = 12,
  });

  final double fractionOfShortestSide;
  final double minimum;

  EdgeInsets resolve(Size size) {
    final shortest = size.shortestSide;
    final raw = shortest * fractionOfShortestSide;
    final pad = raw < minimum ? minimum : raw;
    return EdgeInsets.all(pad);
  }
}
