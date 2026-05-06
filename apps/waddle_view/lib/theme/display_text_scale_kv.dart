/// [AppDatabase.configKeyValues] keys for semantic text scaling (screens vs ticker strip).
const String kDisplayTextScaleScreenKvKey = 'display.text_scale.screen';
const String kDisplayTextScaleTickerKvKey = 'display.text_scale.ticker';

const String kDisplayTextScaleXSmall = 'x-small';
const String kDisplayTextScaleSmaller = 'smaller';
const String kDisplayTextScaleSmall = 'small';
const String kDisplayTextScaleNormal = 'normal';
const String kDisplayTextScaleLarge = 'large';
const String kDisplayTextScaleLarger = 'larger';
const String kDisplayTextScaleXLarge = 'x-large';

const List<String> kDisplayTextScaleOptions = [
  kDisplayTextScaleXSmall,
  kDisplayTextScaleSmaller,
  kDisplayTextScaleSmall,
  kDisplayTextScaleNormal,
  kDisplayTextScaleLarge,
  kDisplayTextScaleLarger,
  kDisplayTextScaleXLarge,
];

typedef DisplayTextScaleOption = ({String id, String label});

const List<DisplayTextScaleOption> kDisplayTextScaleSelectOptions = [
  (id: kDisplayTextScaleXSmall, label: 'Extra small'),
  (id: kDisplayTextScaleSmaller, label: 'Smaller'),
  (id: kDisplayTextScaleSmall, label: 'Small'),
  (id: kDisplayTextScaleNormal, label: 'Normal (default)'),
  (id: kDisplayTextScaleLarge, label: 'Large'),
  (id: kDisplayTextScaleLarger, label: 'Larger'),
  (id: kDisplayTextScaleXLarge, label: 'Extra large'),
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
    case kDisplayTextScaleXSmall:
      return 0.85;
    case kDisplayTextScaleSmaller:
      return 0.9;
    case kDisplayTextScaleSmall:
      return 0.95;
    case kDisplayTextScaleNormal:
      return 1.0;
    case kDisplayTextScaleLarge:
      return 1.1;
    case kDisplayTextScaleLarger:
      return 1.2;
    case kDisplayTextScaleXLarge:
      return 1.35;
    default:
      return 1.0;
  }
}

double linearFactorForDisplayTextScaleKvValue(String? raw) {
  return linearFactorForDisplayTextScaleOption(
    normalizeDisplayTextScaleOption(raw),
  );
}
