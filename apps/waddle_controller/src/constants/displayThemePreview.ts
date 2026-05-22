/**
 * Swatch colors for the Display theme picker. Must match runtime fills built in
 * `apps/waddle_display` (display bg gradient → primary container → secondary
 * container → four accents). Regenerate via the `controller preview hex` test in
 * `apps/waddle_display/test/display_theme_test.dart` when palette definitions change.
 */
export type DisplayThemePreviewGroups = {
  /** Display background gradient stops (viewport / letterbox). */
  display: readonly string[];
  /** Primary container on-slide (foreground then gradient stops). */
  primaryContainer: readonly string[];
  /** Secondary container / ticker (foreground then gradient stops). */
  secondaryContainer: readonly string[];
  /** Accent quartet. */
  accents: readonly string[];
};

export const displayThemePreviewById: Readonly<
  Record<string, DisplayThemePreviewGroups>
> = {
  navy_coral: {
    display: ['#0D1B2A', '#1B263B', '#415A77'],
    primaryContainer: ['#E0E1DD', '#1B263B', '#415A77'],
    secondaryContainer: ['#E0E1DD', '#415A77', '#778DA9', '#83AF84'],
    accents: ['#83AF84', '#E05C6C', '#FFE356', '#966CB3'],
  },
  graphite_amber: {
    display: ['#121214', '#3A3A3A'],
    primaryContainer: ['#F5F5F4', '#121214', '#3A3A3A'],
    secondaryContainer: ['#F5F5F4', '#3A3A3A', '#2A2A2E', '#F59E0B'],
    accents: ['#FFD37A', '#D8A93F', '#8B6C25'],
  },
  teal_gold_sunset: {
    display: ['#264653', '#091A1A'],
    primaryContainer: ['#E9C46A', '#091A1A'],
    secondaryContainer: ['#E9C46A', '#09231F', '#E76F51'],
    accents: ['#F4A261', '#2A9D8F', '#264653', '#E9C46A'],
  },
  ocean_depth: {
    display: ['#03045E', '#01438E'],
    primaryContainer: ['#CAF0F8', '#01438E'],
    secondaryContainer: ['#CAF0F8', '#001A28', '#00B4D8'],
    accents: ['#0077B6', '#90E0EF', '#03045E', '#CAF0F8'],
  },
  forest_cream: {
    display: ['#283618', '#47542A'],
    primaryContainer: ['#FEFAE0', '#47542A'],
    secondaryContainer: ['#FEFAE0', '#15180C', '#BC6C25'],
    accents: ['#DDA15E', '#606C38', '#283618', '#FEFAE0'],
  },
  heritage_coast: {
    display: ['#003049', '#421621'],
    primaryContainer: ['#FDF0D5', '#421621'],
    secondaryContainer: ['#FDF0D5', '#780000', '#C1121F'],
    accents: ['#669BBC', '#003049', '#FDF0D5'],
  },
  plum_ember: {
    display: ['#5F0F40', '#33314F'],
    primaryContainer: ['#E8E6E3', '#33314F'],
    secondaryContainer: ['#E8E6E3', '#0F4C5C', '#9A031E'],
    accents: ['#FB8B24', '#E36414', '#5F0F40', '#E8E6E3'],
  },
  slate_crimson: {
    display: ['#2B2D42', '#8B1634'],
    primaryContainer: ['#EDF2F4', '#8B1634'],
    secondaryContainer: ['#EDF2F4', '#300109', '#EF233C'],
    accents: ['#D90429', '#8D99AE', '#2B2D42', '#EDF2F4'],
  },
  wine_ember: {
    display: ['#03071E', '#20061A'],
    primaryContainer: ['#E8E6E3', '#20061A'],
    secondaryContainer: ['#E8E6E3', '#370617', '#6A040F'],
    accents: ['#D00000', '#9D0208', '#03071E', '#E8E6E3'],
  },
  dopamine_pop: {
    display: ['#1D0C34', '#2C0625'],
    primaryContainer: ['#FFBE0B', '#2C0625'],
    secondaryContainer: ['#FFBE0B', '#380018', '#3A86FF'],
    accents: ['#FF006E', '#FB5607', '#8338EC', '#1D0C34'],
  },
  sage_wellness: {
    display: ['#22271E', '#262921'],
    primaryContainer: ['#FEFEE3', '#262921'],
    secondaryContainer: ['#FEFEE3', '#292B23', '#CDD5AE'],
    accents: ['#F2E8C6', '#BBC2A0', '#9CAF88', '#22271E'],
  },
  warm_minimal: {
    display: ['#2F1B14', '#623213'],
    primaryContainer: ['#F7F1E8', '#623213'],
    secondaryContainer: ['#F7F1E8', '#8B4513', '#D2691E'],
    accents: ['#E8B577', '#2F1B14', '#F7F1E8'],
  },
  morning_coffee: {
    display: ['#2C1810', '#513625'],
    primaryContainer: ['#F0E6D2', '#513625', '#6F4E37'],
    secondaryContainer: ['#F0E6D2', '#6F4E37', '#D2691E', '#D2691E'],
    accents: ['#D2691E', '#2C1810', '#C4A882', '#6F4E37'],
  },
  dark_night: {
    display: ['#0B0C10', '#141421'],
    primaryContainer: ['#EAE7DC', '#141421', '#1B1B2F'],
    secondaryContainer: ['#EAE7DC', '#1B1B2F', '#4A4E69', '#1B1B2F'],
    accents: ['#1B1B2F', '#0B0C10', '#4A4E69', '#9A8C98'],
  },
  sunny_day: {
    display: ['#001A28', '#1F2312'],
    primaryContainer: ['#FFF8E7', '#1F2312', '#382B00'],
    secondaryContainer: ['#FFF8E7', '#382B00', '#90E0EF', '#0077B6'],
    accents: ['#0077B6', '#FFD60A', '#FFC300', '#90E0EF'],
  },
};

/** Flat deduped list for compact previews and tests. */
export function flattenDisplayThemePreview(groups: DisplayThemePreviewGroups): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const group of [
    groups.display,
    groups.primaryContainer,
    groups.secondaryContainer,
    groups.accents,
  ]) {
    for (const hex of group) {
      if (!seen.has(hex)) {
        seen.add(hex);
        out.push(hex);
      }
    }
  }
  return out;
}
