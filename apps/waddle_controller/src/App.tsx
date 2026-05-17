import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { defaultHomePath } from '@/util/defaultHomePath';
import { ControllerAuthProvider, ControllerAuthGate } from '@/context/ControllerAuthContext';
import { DisplayProvider } from '@/context/DisplayContext';
import { LoginDialog } from '@/components/LoginDialog';
import { AppShell } from '@/layout/AppShell';
import { ProgramsOnlyOutlet } from '@/layout/ProgramsOnlyOutlet';
import { CuratorsPage } from '@/pages/CuratorsPage';
import { ProgramsPage } from '@/pages/ProgramsPage';
import { ScreensPage } from '@/pages/ScreensPage';
import { TickerPage } from '@/pages/TickerPage';
import { OverlaysPage } from '@/pages/OverlaysPage';
import { IntegrationsPage } from '@/pages/IntegrationsPage';
import { DataPage } from '@/pages/DataPage';
import { ActivityPage } from '@/pages/ActivityPage';
import { SettingsPage } from '@/pages/SettingsPage';
import { AccountPage } from '@/pages/AccountPage';
import { DisplaysPage } from '@/pages/DisplaysPage';
import { ViewerJoinPage } from '@/pages/ViewerJoinPage';
import { ControllerLoginPage } from '@/pages/ControllerLoginPage';
import { ControllerBootstrapPage } from '@/pages/ControllerBootstrapPage';
import { UsersPage } from '@/pages/UsersPage';

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
        <LoginDialog />
        <Routes>
          <Route path="/join" element={<ViewerJoinPage />} />
          <Route path="/" element={<AppShell />}>
            <Route element={<ProgramsOnlyOutlet />}>
              <Route index element={<DefaultHomeRedirect />} />
              <Route path="curators" element={<CuratorsPage />} />
              <Route path="programs" element={<ProgramsPage />} />
              <Route path="screens" element={<ScreensPage />} />
              <Route path="ticker-tapes" element={<TickerPage />} />
              <Route path="overlays" element={<OverlaysPage />} />
              <Route path="integrations" element={<IntegrationsPage />} />
              <Route path="data" element={<DataPage />} />
              <Route path="activity" element={<ActivityPage />} />
              <Route path="account" element={<AccountPage />} />
              <Route path="displays" element={<DisplaysPage />} />
              <Route path="settings" element={<SettingsPage />} />
              <Route path="users" element={<UsersPage />} />
            </Route>
          </Route>
        </Routes>
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
