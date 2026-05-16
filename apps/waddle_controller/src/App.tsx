import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { DisplayProvider } from '@/context/DisplayContext';
import { LoginDialog } from '@/components/LoginDialog';
import { AppShell } from '@/layout/AppShell';
import { ProgramsOnlyOutlet } from '@/layout/ProgramsOnlyOutlet';
import { FirstRunDialog } from '@/components/FirstRunDialog';
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
import { ViewerJoinPage } from '@/pages/ViewerJoinPage';

function DefaultHomeRedirect() {
  const { isProgramsOnlyControllerUser } = useAuth();
  return <Navigate to={isProgramsOnlyControllerUser ? '/programs' : '/curators'} replace />;
}

export default function App() {
  return (
    <DisplayProvider>
      <AuthProvider>
        <FirstRunDialog />
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
            <Route path="settings" element={<SettingsPage />} />
          </Route>
        </Route>
        </Routes>
      </AuthProvider>
    </DisplayProvider>
  );
}
