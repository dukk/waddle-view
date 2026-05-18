const MONTH_NAMES = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
] as const;

export type CategorySeasonInput = {
  is_seasonal: boolean;
  start_month: string;
  start_day: string;
  end_month: string;
  end_day: string;
};

export type CategorySeasonPayload = {
  start_month: number | null;
  start_day: number | null;
  end_month: number | null;
  end_day: number | null;
};

function parseMonthDay(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const n = Number.parseInt(trimmed, 10);
  return Number.isFinite(n) ? n : null;
}

function isValidMonthDay(month: number, day: number): boolean {
  return month >= 1 && month <= 12 && day >= 1 && day <= 31;
}

export function categorySeasonPayload(input: CategorySeasonInput): CategorySeasonPayload | string {
  if (!input.is_seasonal) {
    return {
      start_month: null,
      start_day: null,
      end_month: null,
      end_day: null,
    };
  }
  const start_month = parseMonthDay(input.start_month);
  const start_day = parseMonthDay(input.start_day);
  const end_month = parseMonthDay(input.end_month);
  const end_day = parseMonthDay(input.end_day);
  if (start_month == null || start_day == null || end_month == null || end_day == null) {
    return 'Season start and end month and day are required when seasonal is enabled.';
  }
  if (!isValidMonthDay(start_month, start_day) || !isValidMonthDay(end_month, end_day)) {
    return 'Month must be 1–12 and day must be 1–31.';
  }
  return { start_month, start_day, end_month, end_day };
}

export function formatCategorySeason(row: {
  is_seasonal: boolean;
  start_month: number | null;
  start_day: number | null;
  end_month: number | null;
  end_day: number | null;
}): string {
  if (!row.is_seasonal) return '—';
  const sm = row.start_month;
  const sd = row.start_day;
  const em = row.end_month;
  const ed = row.end_day;
  if (sm == null || sd == null) return 'Seasonal';
  const start = `${MONTH_NAMES[sm - 1] ?? String(sm)} ${sd}`;
  if (em == null || ed == null) return start;
  const end = `${MONTH_NAMES[em - 1] ?? String(em)} ${ed}`;
  return `${start} – ${end}`;
}
