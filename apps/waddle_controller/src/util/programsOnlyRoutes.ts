export type PermissionCheck = (permission: string) => boolean;

function canViewData(hasPermission: PermissionCheck): boolean {
  return (
    hasPermission('content.moderate') || hasPermission('content.catalog_read')
  );
}

function canViewInterests(hasPermission: PermissionCheck): boolean {
  return hasPermission('interests.read') || hasPermission('interests.write');
}

/** Whether a programs-only user (viewer / power_viewer) may open this pathname. */
export function isProgramsOnlyPathAllowed(
  pathname: string,
  hasPermission: PermissionCheck,
): boolean {
  if (pathname === '/programs' || pathname.startsWith('/programs/')) return true;
  if (
    (pathname === '/remote' || pathname.startsWith('/remote/')) &&
    hasPermission('navigation.control')
  ) {
    return true;
  }
  if (pathname === '/account' || pathname.startsWith('/account/')) return true;
  if ((pathname === '/data' || pathname.startsWith('/data/')) && canViewData(hasPermission)) {
    return true;
  }
  if (
    (pathname === '/interests' || pathname.startsWith('/interests/')) &&
    canViewInterests(hasPermission)
  ) {
    return true;
  }
  return false;
}

/** Whether a top-level drawer nav route is visible for programs-only users. */
export function isProgramsOnlyNavRouteAllowed(
  route: string,
  hasPermission: PermissionCheck,
): boolean {
  if (route === '/programs' || route === '/remote') return true;
  if (route === '/data' && canViewData(hasPermission)) return true;
  if (route === '/interests' && canViewInterests(hasPermission)) return true;
  return false;
}
