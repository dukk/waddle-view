let authEnabled = false;

export function setDisplayProxyAuthEnabled(enabled: boolean): void {
  authEnabled = enabled;
}

export function isDisplayProxyAuthEnabled(): boolean {
  return authEnabled;
}
