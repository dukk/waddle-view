/// US state / territory abbreviations in "City, ST" location names.
const Set<String> kUsStateAndTerritoryAbbreviations = {
  'AL',
  'AK',
  'AZ',
  'AR',
  'CA',
  'CO',
  'CT',
  'DE',
  'FL',
  'GA',
  'HI',
  'ID',
  'IL',
  'IN',
  'IA',
  'KS',
  'KY',
  'LA',
  'ME',
  'MD',
  'MA',
  'MI',
  'MN',
  'MS',
  'MO',
  'MT',
  'NE',
  'NV',
  'NH',
  'NJ',
  'NM',
  'NY',
  'NC',
  'ND',
  'OH',
  'OK',
  'OR',
  'PA',
  'RI',
  'SC',
  'SD',
  'TN',
  'TX',
  'UT',
  'VT',
  'VA',
  'WA',
  'WV',
  'WI',
  'WY',
  'DC',
};

/// Continental region slugs for [InterestsLocations.category].
const String kWeatherLocationRegionNorthAmerica = 'north_america';
const String kWeatherLocationRegionEurope = 'europe';
const String kWeatherLocationRegionAsia = 'asia';
const String kWeatherLocationRegionSouthAmerica = 'south_america';
const String kWeatherLocationRegionAfrica = 'africa';
const String kWeatherLocationRegionOceania = 'oceania';

const Set<String> _northAmericaCountrySlugs = {
  'canada',
  'mexico',
  'guatemala',
  'belize',
  'costa_rica',
  'el_salvador',
  'honduras',
  'nicaragua',
  'panama',
  'cuba',
  'jamaica',
  'haiti',
  'dominican_republic',
  'puerto_rico',
  'bahamas',
  'bermuda',
  'greenland',
};

const Set<String> _europeCountrySlugs = {
  'united_kingdom',
  'france',
  'germany',
  'spain',
  'italy',
  'netherlands',
  'belgium',
  'switzerland',
  'austria',
  'poland',
  'portugal',
  'greece',
  'sweden',
  'norway',
  'denmark',
  'finland',
  'ireland',
  'czech_republic',
  'hungary',
  'romania',
  'ukraine',
  'turkey',
  'croatia',
  'serbia',
  'iceland',
  'luxembourg',
  'slovakia',
  'slovenia',
  'bulgaria',
  'estonia',
  'latvia',
  'lithuania',
  'monaco',
  'malta',
  'cyprus',
};

const Set<String> _asiaCountrySlugs = {
  'japan',
  'china',
  'india',
  'south_korea',
  'singapore',
  'united_arab_emirates',
  'hong_kong',
  'thailand',
  'indonesia',
  'philippines',
  'taiwan',
  'saudi_arabia',
  'malaysia',
  'vietnam',
  'pakistan',
  'bangladesh',
  'israel',
  'qatar',
  'kuwait',
  'iraq',
  'iran',
  'nepal',
  'sri_lanka',
  'cambodia',
  'myanmar',
  'kazakhstan',
  'uzbekistan',
  'jordan',
  'lebanon',
  'oman',
  'bahrain',
};

const Set<String> _southAmericaCountrySlugs = {
  'brazil',
  'argentina',
  'chile',
  'peru',
  'colombia',
  'venezuela',
  'ecuador',
  'bolivia',
  'paraguay',
  'uruguay',
  'guyana',
  'suriname',
};

const Set<String> _africaCountrySlugs = {
  'egypt',
  'south_africa',
  'nigeria',
  'kenya',
  'morocco',
  'ethiopia',
  'ghana',
  'algeria',
  'tunisia',
  'tanzania',
  'uganda',
  'senegal',
  'cote_d_ivoire',
  'cameroon',
  'zimbabwe',
  'mozambique',
  'angola',
  'namibia',
  'botswana',
  'rwanda',
};

const Set<String> _oceaniaCountrySlugs = {
  'australia',
  'new_zealand',
  'fiji',
  'papua_new_guinea',
  'samoa',
  'tonga',
  'french_polynesia',
  'guam',
  'new_caledonia',
  'solomon_islands',
  'vanuatu',
  'micronesia',
  'palau',
};

/// Maps a country slug ([slugifyWeatherLocationCategory]) to a continental region.
String weatherLocationRegionFromCountrySlug(String countrySlug) {
  if (_northAmericaCountrySlugs.contains(countrySlug)) {
    return kWeatherLocationRegionNorthAmerica;
  }
  if (_europeCountrySlugs.contains(countrySlug)) {
    return kWeatherLocationRegionEurope;
  }
  if (_asiaCountrySlugs.contains(countrySlug)) {
    return kWeatherLocationRegionAsia;
  }
  if (_southAmericaCountrySlugs.contains(countrySlug)) {
    return kWeatherLocationRegionSouthAmerica;
  }
  if (_africaCountrySlugs.contains(countrySlug)) {
    return kWeatherLocationRegionAfrica;
  }
  if (_oceaniaCountrySlugs.contains(countrySlug)) {
    return kWeatherLocationRegionOceania;
  }
  return 'general';
}

/// Slug for [InterestsLocations.category] from a country name or "City, ST" label.
String slugifyWeatherLocationCategory(String source) {
  final normalized = source
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .replaceAll(RegExp('_+'), '_');
  if (normalized.isEmpty) return 'general';
  var slug = normalized;
  if (!RegExp(r'^[a-z]').hasMatch(slug)) {
    slug = 'i_$slug';
  }
  if (slug.length > 63) {
    slug = slug.substring(0, 63);
  }
  return slug;
}

/// Derives continental region category from operator-facing location [name].
String weatherLocationCategoryFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'general';
  final parts = trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.length < 2) return 'general';
  final last = parts.last.toUpperCase();
  if (last.length == 2 && kUsStateAndTerritoryAbbreviations.contains(last)) {
    return kWeatherLocationRegionNorthAmerica;
  }
  final countrySlug = slugifyWeatherLocationCategory(parts.last);
  return weatherLocationRegionFromCountrySlug(countrySlug);
}
