/** User-facing text for `navigator.geolocation` failures (not a subclass of `Error`). */
export function geolocationErrorMessage(e: unknown): string {
  if (isGeolocationPositionError(e)) {
    const hint = geolocationCodeHint(e.code);
    const detail = e.message?.trim();
    return detail && !detail.startsWith('[object ') ? `${hint} (${detail})` : hint;
  }
  if (e instanceof Error && e.message) {
    return e.message;
  }
  return String(e);
}

function isGeolocationPositionError(e: unknown): e is GeolocationPositionError {
  return (
    typeof e === 'object' &&
    e !== null &&
    'code' in e &&
    typeof (e as GeolocationPositionError).code === 'number'
  );
}

function geolocationCodeHint(code: number): string {
  switch (code) {
    case 1:
      return 'Location access was denied. Allow location permission for this site in your browser settings.';
    case 2:
      return 'Your position could not be determined. Check that location services are enabled on this device.';
    case 3:
      return 'Location request timed out. Try again.';
    default:
      return 'Could not read your location.';
  }
}
