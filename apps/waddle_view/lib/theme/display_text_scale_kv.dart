/// [AppDatabase.configKeyValues] keys for semantic text scaling (screens vs ticker strip).
const String kDisplayTextScaleScreenKvKey = 'display.text_scale.screen';
const String kDisplayTextScaleTickerKvKey = 'display.text_scale.ticker';

const String kDisplayTextScaleXXXSmall = 'xxx-small';
const String kDisplayTextScaleXXSmall = 'xx-small';
const String kDisplayTextScaleXSmall = 'x-small';
const String kDisplayTextScaleSmaller = 'smaller';
const String kDisplayTextScaleSmall = 'small';
const String kDisplayTextScaleNormal = 'normal';
const String kDisplayTextScaleLarge = 'large';
const String kDisplayTextScaleLarger = 'larger';
const String kDisplayTextScaleXLarge = 'x-large';
const String kDisplayTextScaleXXLarge = 'xx-large';
const String kDisplayTextScaleXXXLarge = 'xxx-large';

const List<String> kDisplayTextScaleOptions = [
  kDisplayTextScaleXXXSmall,
  kDisplayTextScaleXXSmall,
  kDisplayTextScaleXSmall,
  kDisplayTextScaleSmaller,
  kDisplayTextScaleSmall,
  kDisplayTextScaleNormal,
  kDisplayTextScaleLarge,
  kDisplayTextScaleLarger,
  kDisplayTextScaleXLarge,
  kDisplayTextScaleXXLarge,
  kDisplayTextScaleXXXLarge,
];

typedef DisplayTextScaleOption = ({String id, String label});

const List<DisplayTextScaleOption> kDisplayTextScaleSelectOptions = [
  (id: kDisplayTextScaleXXXSmall, label: 'Extra extra extra small'),
  (id: kDisplayTextScaleXXSmall, label: 'Extra extra small'),
  (id: kDisplayTextScaleXSmall, label: 'Extra small'),
  (id: kDisplayTextScaleSmaller, label: 'Smaller'),
  (id: kDisplayTextScaleSmall, label: 'Small'),
  (id: kDisplayTextScaleNormal, label: 'Normal (default)'),
  (id: kDisplayTextScaleLarge, label: 'Large'),
  (id: kDisplayTextScaleLarger, label: 'Larger'),
  (id: kDisplayTextScaleXLarge, label: 'Extra large'),
  (id: kDisplayTextScaleXXLarge, label: 'Extra extra large'),
  (id: kDisplayTextScaleXXXLarge, label: 'Extra extra extra large'),
];

final Set<String> _canonicalDisplayTextScaleOptions =
    kDisplayTextScaleOptions.toSet();

/// Maps semantic size to a linear multiplier (1.0 = normal). The app composes
/// this with the global TV readability text scale in `MaterialApp` / home.
String normalizeDisplayTextScaleOption(String? raw) {
  if (raw == null) {
    return kDisplayTextScaleNormal;
  }
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) {
    return kDisplayTextScaleNormal;
  }
  s = s.replaceAll(RegExp(r'[\s]+'), '-');
  s = s.replaceAll('_', '-');
  if (_canonicalDisplayTextScaleOptions.contains(s)) {
    return s;
  }
  return kDisplayTextScaleNormal;
}

double linearFactorForDisplayTextScaleOption(String canonical) {
  switch (canonical) {
    case kDisplayTextScaleXXXSmall:
      return 0.25;
    case kDisplayTextScaleXXSmall:
      return 0.4;
    case kDisplayTextScaleXSmall:
      return 0.55;
    case kDisplayTextScaleSmaller:
      return 0.7;
    case kDisplayTextScaleSmall:
      return 0.85;
    case kDisplayTextScaleNormal:
      return 1.0;
    case kDisplayTextScaleLarge:
      return 1.15;
    case kDisplayTextScaleLarger:
      return 1.3;
    case kDisplayTextScaleXLarge:
      return 1.45;
    case kDisplayTextScaleXXLarge:
      return 1.6;
    case kDisplayTextScaleXXXLarge:
      return 1.75;
    default:
      return 1.0;
  }
}

double linearFactorForDisplayTextScaleKvValue(String? raw) {
  return linearFactorForDisplayTextScaleOption(
    normalizeDisplayTextScaleOption(raw),
  );
}
