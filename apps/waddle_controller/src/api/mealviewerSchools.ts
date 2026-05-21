import { apiJson } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';

export type MealviewerSchoolItem = {
  school_slug: string;
  label: string;
  city?: string;
  state?: string;
  district_slug?: string;
};

export type MealviewerDistrictItem = {
  district_slug: string;
  label: string;
  state_code?: string;
};

export async function searchMealviewerSchools(
  display: SavedDisplay,
  query: string,
  limit = 25,
): Promise<MealviewerSchoolItem[]> {
  const q = encodeURIComponent(query.trim());
  const res = await apiJson<{ items: MealviewerSchoolItem[] }>(
    display,
    `/v1/mealviewer/schools/search?q=${q}&limit=${limit}`,
  );
  return res.items ?? [];
}

export async function listMealviewerDistricts(
  display: SavedDisplay,
  query?: string,
  limit = 50,
): Promise<MealviewerDistrictItem[]> {
  const params = new URLSearchParams();
  if (query?.trim()) {
    params.set('q', query.trim());
  }
  params.set('limit', String(limit));
  const res = await apiJson<{ items: MealviewerDistrictItem[] }>(
    display,
    `/v1/mealviewer/districts?${params.toString()}`,
  );
  return res.items ?? [];
}

export async function listMealviewerDistrictSchools(
  display: SavedDisplay,
  districtSlug: string,
  limit = 200,
): Promise<MealviewerSchoolItem[]> {
  const res = await apiJson<{ items: MealviewerSchoolItem[] }>(
    display,
    `/v1/mealviewer/districts/${encodeURIComponent(districtSlug)}/schools?limit=${limit}`,
  );
  return res.items ?? [];
}

export async function probeMealviewerSchool(
  display: SavedDisplay,
  schoolSlug: string,
): Promise<{ school: MealviewerSchoolItem; menu_available: boolean }> {
  return apiJson(
    display,
    `/v1/mealviewer/schools/${encodeURIComponent(schoolSlug)}/probe`,
  );
}
