import 'package:flutter/material.dart';

import 'nine_color_display_theme_builder.dart';
import 'palettes/mood_palettes.dart';

ThemeData buildMorningCoffeeDisplayTheme() =>
    buildNineColorDisplayTheme(MoodPalettes.morningCoffee);

ThemeData buildDarkNightDisplayTheme() =>
    buildNineColorDisplayTheme(MoodPalettes.darkNight);

ThemeData buildSunnyDayDisplayTheme() =>
    buildNineColorDisplayTheme(MoodPalettes.sunnyDay);
