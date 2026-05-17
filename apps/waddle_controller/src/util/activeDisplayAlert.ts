/** Row shape from `GET /v1/alerts` (mirrors display `_alertJson`). */
export type DisplayAlertRow = {
  id: number;
  priority: number;
  created_at_ms: number;
  expires_at_ms?: number | null;
  dismissed_at_ms?: number | null;
};

/** Mirrors `ActiveAlertSelector` on the display kiosk. */
export function pickActiveDisplayAlert(
  rows: DisplayAlertRow[],
  nowMs = Date.now(),
): DisplayAlertRow | null {
  let best: DisplayAlertRow | null = null;
  for (const row of rows) {
    if (row.dismissed_at_ms != null) continue;
    if (row.expires_at_ms != null && row.expires_at_ms <= nowMs) continue;
    if (best == null) {
      best = row;
      continue;
    }
    if (row.priority > best.priority) {
      best = row;
    } else if (row.priority === best.priority && row.created_at_ms > best.created_at_ms) {
      best = row;
    }
  }
  return best;
}
