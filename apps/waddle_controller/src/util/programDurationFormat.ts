/** Human-readable program duration for curator sliders (stored value is seconds). */
export function formatProgramDuration(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(total / 60);
  const secs = total % 60;
  if (minutes === 0) {
    return `${secs} sec`;
  }
  if (secs === 0) {
    return `${minutes} min`;
  }
  return `${minutes} min ${secs} sec`;
}

/** Optional detail line showing total seconds for advanced users. */
export function formatProgramDurationWithSeconds(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  return `${formatProgramDuration(total)} (${total}s)`;
}
