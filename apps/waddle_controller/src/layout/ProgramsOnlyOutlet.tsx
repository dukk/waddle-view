import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { isProgramsOnlyPathAllowed } from '@/util/programsOnlyRoutes';

/**
 * Restricts signed-in viewers and power viewers (and admins previewing those roles) to allowed routes:
 * **Programs**, **Remote** (when **`navigation.control`** is granted), **Account**, **Data** when the session
 * includes **`content.catalog_read`** or **`content.moderate`**, and **Interests** when **`interests.read`**
 * or **`interests.write`** is granted. Plain viewers only have Programs + Account. Other paths redirect to
 * `/programs`.
 */
export function ProgramsOnlyOutlet() {
  const { isProgramsOnlyControllerUser, hasPermission } = useAuth();
  const location = useLocation();

  if (!isProgramsOnlyControllerUser) {
    return <Outlet />;
  }

  if (isProgramsOnlyPathAllowed(location.pathname, hasPermission)) {
    return <Outlet />;
  }

  return <Navigate to="/programs" replace />;
}
