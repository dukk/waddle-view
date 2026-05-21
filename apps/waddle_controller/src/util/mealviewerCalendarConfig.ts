export type MealviewerSchoolConfig = {
  schoolSlug: string;
  label: string;
  districtSlug?: string;
  categoryIds: string[];
};

export type MealviewerCalendarConfigState = {
  pastDays: number;
  futureDays: number;
  schools: MealviewerSchoolConfig[];
};

export function parseMealviewerCalendarConfig(
  raw: Record<string, unknown>,
): MealviewerCalendarConfigState {
  const pastDays =
    typeof raw.pastDays === 'number' && raw.pastDays > 0 ? raw.pastDays : 30;
  const futureDays =
    typeof raw.futureDays === 'number' && raw.futureDays > 0 ? raw.futureDays : 30;
  const schoolsRaw = raw.schools;
  const schools: MealviewerSchoolConfig[] = [];
  if (Array.isArray(schoolsRaw)) {
    for (const s of schoolsRaw) {
      if (!s || typeof s !== 'object') continue;
      const row = s as Record<string, unknown>;
      const slug = normalizeSchoolSlug(
        (row.schoolSlug as string) ?? (row.school_slug as string),
      );
      if (!slug) continue;
      const labelRaw = row.label;
      const label =
        typeof labelRaw === 'string' && labelRaw.trim() !== '' ? labelRaw.trim() : slug;
      const districtRaw = row.districtSlug ?? row.district_slug;
      const districtSlug =
        typeof districtRaw === 'string' && districtRaw.trim() !== ''
          ? districtRaw.trim()
          : undefined;
      const categoryIds = parseCategoryIds(row);
      schools.push({ schoolSlug: slug, label, districtSlug, categoryIds });
    }
  }
  return { pastDays, futureDays, schools };
}

export function buildMealviewerCalendarConfigJson(
  state: MealviewerCalendarConfigState,
): Record<string, unknown> {
  return {
    pastDays: state.pastDays,
    futureDays: state.futureDays,
    schools: state.schools.map((s) => ({
      schoolSlug: s.schoolSlug,
      label: s.label,
      ...(s.districtSlug ? { districtSlug: s.districtSlug } : {}),
      categoryIds: s.categoryIds,
    })),
  };
}

export function mealviewerConfigReady(state: MealviewerCalendarConfigState): boolean {
  return state.schools.length > 0;
}

function normalizeSchoolSlug(raw: string | undefined): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return trimmed.split(/\s+/).join('');
}

function parseCategoryIds(row: Record<string, unknown>): string[] {
  const ids: string[] = [];
  const multi = row.categoryIds ?? row.category_ids;
  if (Array.isArray(multi)) {
    for (const c of multi) {
      if (typeof c === 'string' && c.trim() !== '' && !ids.includes(c.trim())) {
        ids.push(c.trim());
      }
    }
  }
  const single = row.categoryId ?? row.category;
  if (typeof single === 'string' && single.trim() !== '' && !ids.includes(single.trim())) {
    ids.push(single.trim());
  }
  return ids;
}

export function schoolKey(s: MealviewerSchoolConfig): string {
  return s.schoolSlug;
}

export function mergeSchoolIntoList(
  schools: MealviewerSchoolConfig[],
  next: MealviewerSchoolConfig,
): MealviewerSchoolConfig[] {
  const key = schoolKey(next);
  const without = schools.filter((s) => schoolKey(s) !== key);
  return [...without, next];
}
