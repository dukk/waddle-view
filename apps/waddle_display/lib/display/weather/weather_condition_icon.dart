import 'package:flutter/material.dart';

/// Material icon for weather condition using OpenWeather-style [code] and/or text.
IconData iconForWeatherCondition({String? code, String? description}) {
  final normalizedCode = (code ?? '').trim();
  if (normalizedCode.isNotEmpty) {
    if (normalizedCode.contains('01')) {
      return Icons.wb_sunny;
    }
    if (normalizedCode.contains('02') ||
        normalizedCode.contains('03') ||
        normalizedCode.contains('04')) {
      return Icons.cloud;
    }
    if (normalizedCode.contains('09') || normalizedCode.contains('10')) {
      return Icons.umbrella;
    }
    if (normalizedCode.contains('11')) {
      return Icons.thunderstorm;
    }
    if (normalizedCode.contains('13')) {
      return Icons.ac_unit;
    }
    if (normalizedCode.contains('50')) {
      return Icons.foggy;
    }
  }
  final value = (description ?? '').toLowerCase();
  if (value.contains('snow') ||
      value.contains('sleet') ||
      value.contains('ice')) {
    return Icons.ac_unit;
  }
  if (value.contains('thunder') || value.contains('storm')) {
    return Icons.thunderstorm;
  }
  if (value.contains('rain') ||
      value.contains('drizzle') ||
      value.contains('shower')) {
    return Icons.umbrella;
  }
  if (value.contains('cloud') || value.contains('overcast')) {
    return Icons.cloud;
  }
  if (value.contains('fog') ||
      value.contains('mist') ||
      value.contains('haze')) {
    return Icons.foggy;
  }
  return Icons.wb_sunny;
}
