import { slugifyInterestSource } from '@/util/interestSlug';

const US_STATE_AND_TERRITORY_CODES = new Set([
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
]);

export const WEATHER_LOCATION_REGION_NORTH_AMERICA = 'north_america';
export const WEATHER_LOCATION_REGION_EUROPE = 'europe';
export const WEATHER_LOCATION_REGION_ASIA = 'asia';
export const WEATHER_LOCATION_REGION_SOUTH_AMERICA = 'south_america';
export const WEATHER_LOCATION_REGION_AFRICA = 'africa';
export const WEATHER_LOCATION_REGION_OCEANIA = 'oceania';

const NORTH_AMERICA_COUNTRY_SLUGS = new Set([
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
]);

const EUROPE_COUNTRY_SLUGS = new Set([
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
]);

const ASIA_COUNTRY_SLUGS = new Set([
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
]);

const SOUTH_AMERICA_COUNTRY_SLUGS = new Set([
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
]);

const AFRICA_COUNTRY_SLUGS = new Set([
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
]);

const OCEANIA_COUNTRY_SLUGS = new Set([
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
]);

export function weatherLocationRegionFromCountrySlug(countrySlug: string): string {
  if (NORTH_AMERICA_COUNTRY_SLUGS.has(countrySlug)) {
    return WEATHER_LOCATION_REGION_NORTH_AMERICA;
  }
  if (EUROPE_COUNTRY_SLUGS.has(countrySlug)) {
    return WEATHER_LOCATION_REGION_EUROPE;
  }
  if (ASIA_COUNTRY_SLUGS.has(countrySlug)) {
    return WEATHER_LOCATION_REGION_ASIA;
  }
  if (SOUTH_AMERICA_COUNTRY_SLUGS.has(countrySlug)) {
    return WEATHER_LOCATION_REGION_SOUTH_AMERICA;
  }
  if (AFRICA_COUNTRY_SLUGS.has(countrySlug)) {
    return WEATHER_LOCATION_REGION_AFRICA;
  }
  if (OCEANIA_COUNTRY_SLUGS.has(countrySlug)) {
    return WEATHER_LOCATION_REGION_OCEANIA;
  }
  return 'general';
}

/** Continental region category from a location name such as "London, United Kingdom". */
export function weatherLocationCategoryFromName(name: string): string {
  const trimmed = name.trim();
  if (!trimmed) return 'general';
  const parts = trimmed
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (parts.length < 2) return 'general';
  const last = parts[parts.length - 1]!.toUpperCase();
  if (last.length === 2 && US_STATE_AND_TERRITORY_CODES.has(last)) {
    return WEATHER_LOCATION_REGION_NORTH_AMERICA;
  }
  const countrySlug = slugifyInterestSource(parts[parts.length - 1]!);
  return weatherLocationRegionFromCountrySlug(countrySlug);
}

export function interestCategoryLabel(
  categoryId: string | null | undefined,
  curatorCategories: { id: string; label: string }[],
): string {
  const id = (categoryId ?? '').trim() || 'general';
  const hit = curatorCategories.find((c) => c.id === id);
  if (hit) return hit.label;
  return id
    .split('_')
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}
