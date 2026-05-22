import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { useActiveDisplayPluginsNav } from '@/hooks/useActiveDisplayPluginsNav';
import { defaultHomePath } from '@/util/defaultHomePath';
import { isProgramsOnlyPathAllowed } from '@/util/programsOnlyRoutes';

/**
 * Restricts signed-in viewers and power viewers (and admins previewing those roles) to allowed routes:
 * **Programs**, **Remote** (when **`navigation.control`** is granted), **Account**, **Data** when the session
 * includes **`content.catalog_read`** or **`content.moderate`**, and **Interests** when **`interests.read`**
 * or **`interests.write`** is granted. Plain viewers only have Programs + Account. Other paths redirect to
 * `/programs`.
 */
function isPluginsPath(pathname: string): boolean {
  return pathname === '/plugins' || pathname.startsWith('/plugins/');
}

export function ProgramsOnlyOutlet() {
  const { isProgramsOnlyControllerUser, hasPermission } = useAuth();
  const { displays } = useDisplay();
  const location = useLocation();
  const { enabled: pluginsNavEnabled, loading: pluginsNavLoading } =
    useActiveDisplayPluginsNav();

  if (isPluginsPath(location.pathname) && !pluginsNavLoading && !pluginsNavEnabled) {
    return (
      <Navigate
        to={defaultHomePath(displays, isProgramsOnlyControllerUser)}
        replace
      />
    );
  }

  if (!isProgramsOnlyControllerUser) {
    return <Outlet />;
  }

  if (isProgramsOnlyPathAllowed(location.pathname, hasPermission)) {
    return <Outlet />;
  }

  return <Navigate to="/programs" replace />;
}
