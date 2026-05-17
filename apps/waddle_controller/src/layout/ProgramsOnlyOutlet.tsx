import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';

/**
 * Restricts signed-in viewers and power viewers (and admins previewing those roles) to allowed routes:
 * **Programs**, **Remote** (when **`navigation.control`** is granted), **Account**, and **Data** when the session
 * includes **`content.catalog_read`** (power viewer) or **`content.moderate`**. Plain viewers only have Programs +
 * Account. Other paths redirect to `/programs`.
 */
export function ProgramsOnlyOutlet() {
  const { isProgramsOnlyControllerUser, hasPermission } = useAuth();
  const location = useLocation();

  if (!isProgramsOnlyControllerUser) {
    return <Outlet />;
  }

  const path = location.pathname;
  if (
    path === '/programs' ||
    path.startsWith('/programs/') ||
    ((path === '/remote' || path.startsWith('/remote/')) && hasPermission('navigation.control')) ||
    path === '/account' ||
    path.startsWith('/account/')
  ) {
    return <Outlet />;
  }
  if ((path === '/data' || path.startsWith('/data/')) && (hasPermission('content.moderate') || hasPermission('content.catalog_read'))) {
    return <Outlet />;
  }

  return <Navigate to="/programs" replace />;
}
