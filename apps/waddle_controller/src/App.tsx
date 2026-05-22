import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { defaultHomePath } from '@/util/defaultHomePath';
import { ControllerAuthProvider, ControllerAuthGate } from '@/context/ControllerAuthContext';
import { DisplayProvider } from '@/context/DisplayContext';
import { DisplayFormatProvider } from '@/context/DisplayFormatContext';
import { LoginDialog } from '@/components/LoginDialog';
import { AppShell } from '@/layout/AppShell';
import { RemoteViewShell } from '@/layout/RemoteViewShell';
import { ProgramsOnlyOutlet } from '@/layout/ProgramsOnlyOutlet';
import { ProgramsPage } from '@/pages/ProgramsPage';
import { RemoteControlPage } from '@/pages/RemoteControlPage';
import { RemoteViewPage } from '@/pages/RemoteViewPage';
import { ScreensPage } from '@/pages/ScreensPage';
import { TickerPage } from '@/pages/TickerPage';
import { OverlaysPage } from '@/pages/OverlaysPage';
import { IntegrationsPage } from '@/pages/IntegrationsPage';
import { PluginsPage } from '@/pages/PluginsPage';
import { InterestsPage } from '@/pages/InterestsPage';
import { DataPage } from '@/pages/DataPage';
import { ActivityPage } from '@/pages/ActivityPage';
import { DisplaySettingsPage } from '@/pages/DisplaySettingsPage';
import { CuratorsPage } from '@/pages/CuratorsPage';
import { ControllerSettingsPage } from '@/pages/ControllerSettingsPage';
import { AccountPage } from '@/pages/AccountPage';
import { AboutPage } from '@/pages/AboutPage';
import { ViewerJoinPage } from '@/pages/ViewerJoinPage';
import { ControllerLoginPage } from '@/pages/ControllerLoginPage';
import { ControllerBootstrapPage } from '@/pages/ControllerBootstrapPage';
import { ControllerChangePasswordPage } from '@/pages/ControllerChangePasswordPage';

function DefaultHomeRedirect() {
  const { displays } = useDisplay();
  const { isProgramsOnlyControllerUser } = useAuth();
  return (
    <Navigate
      to={defaultHomePath(displays, isProgramsOnlyControllerUser)}
      replace
    />
  );
}

function MainAppRoutes() {
  return (
    <DisplayProvider>
      <AuthProvider>
        <DisplayFormatProvider>
        <LoginDialog />
        <Routes>
          <Route path="/join" element={<ViewerJoinPage />} />
          <Route element={<ProgramsOnlyOutlet />}>
            <Route path="/remote/view" element={<RemoteViewShell />}>
              <Route index element={<RemoteViewPage />} />
            </Route>
          </Route>
          <Route path="/" element={<AppShell />}>
            <Route element={<ProgramsOnlyOutlet />}>
              <Route index element={<DefaultHomeRedirect />} />
              <Route path="curators" element={<CuratorsPage />} />
              <Route path="programs" element={<ProgramsPage />} />
              <Route path="remote" element={<RemoteControlPage />} />
              <Route path="screens" element={<ScreensPage />} />
              <Route path="ticker-tapes" element={<TickerPage />} />
              <Route path="overlays" element={<OverlaysPage />} />
              <Route path="integrations" element={<IntegrationsPage />} />
              <Route path="plugins" element={<PluginsPage />} />
              <Route path="interests" element={<InterestsPage />} />
              <Route path="data" element={<DataPage />} />
              <Route path="activity" element={<ActivityPage />} />
              <Route path="account" element={<AccountPage />} />
              <Route path="about" element={<AboutPage />} />
              <Route path="controller-settings" element={<ControllerSettingsPage />} />
              <Route path="display-settings" element={<DisplaySettingsPage />} />
              <Route
                path="display-ops"
                element={<Navigate to="/controller-settings?tab=backup" replace />}
              />
              <Route path="displays" element={<Navigate to="/controller-settings" replace />} />
              <Route path="settings" element={<Navigate to="/display-settings" replace />} />
              <Route
                path="users"
                element={<Navigate to="/controller-settings?tab=users" replace />}
              />
            </Route>
          </Route>
        </Routes>
        </DisplayFormatProvider>
      </AuthProvider>
    </DisplayProvider>
  );
}

export default function App() {
  return (
    <ControllerAuthProvider>
      <Routes>
        <Route path="/controller-login" element={<ControllerLoginPage />} />
        <Route path="/controller-bootstrap" element={<ControllerBootstrapPage />} />
        <Route path="/controller-change-password" element={<ControllerChangePasswordPage />} />
        <Route
          path="/*"
          element={
            <ControllerAuthGate>
              <MainAppRoutes />
            </ControllerAuthGate>
          }
        />
      </Routes>
    </ControllerAuthProvider>
  );
}
