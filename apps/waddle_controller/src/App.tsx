import { Navigate, Route, Routes } from 'react-router-dom';
import { DisplayProvider } from '@/context/DisplayContext';
import { AppShell } from '@/layout/AppShell';
import { FirstRunDialog } from '@/components/FirstRunDialog';
import { CuratorsPage } from '@/pages/CuratorsPage';
import { ProgramsPage } from '@/pages/ProgramsPage';
import { ScreensPage } from '@/pages/ScreensPage';
import { TickerPage } from '@/pages/TickerPage';
import { OverlaysPage } from '@/pages/OverlaysPage';
import { ProvidersPage } from '@/pages/ProvidersPage';
import { ActivityPage } from '@/pages/ActivityPage';
import { SettingsPage } from '@/pages/SettingsPage';

export default function App() {
  return (
    <DisplayProvider>
      <FirstRunDialog />
      <Routes>
        <Route path="/" element={<AppShell />}>
          <Route index element={<Navigate to="/curators" replace />} />
          <Route path="curators" element={<CuratorsPage />} />
          <Route path="programs" element={<ProgramsPage />} />
          <Route path="screens" element={<ScreensPage />} />
          <Route path="ticker" element={<TickerPage />} />
          <Route path="overlays" element={<OverlaysPage />} />
          <Route path="providers" element={<ProvidersPage />} />
          <Route path="activity" element={<ActivityPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Routes>
    </DisplayProvider>
  );
}
