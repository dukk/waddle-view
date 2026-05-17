import { useEffect, useMemo } from 'react';
import { Box, Paper, Stack, Tab, Tabs, Typography } from '@mui/material';
import { useSearchParams } from 'react-router-dom';
import { ControllerAccessSection } from '@/components/ControllerAccessSection';
import { DisplaysPage } from '@/pages/DisplaysPage';
import { UsersPage } from '@/pages/UsersPage';
import { useControllerAuth } from '@/context/ControllerAuthContext';

const TAB_DISPLAYS = 'displays';
const TAB_USERS = 'users';

export function ControllerSettingsPage() {
  const { status, isControllerAdmin } = useControllerAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const showUsersTab = Boolean(status?.authEnabled && isControllerAdmin);

  const tabs = useMemo(() => {
    const items = [{ id: TAB_DISPLAYS, label: 'Displays' }];
    if (showUsersTab) {
      items.push({ id: TAB_USERS, label: 'Users' });
    }
    return items;
  }, [showUsersTab]);

  const tabParam = searchParams.get('tab');
  const tab =
    tabParam === TAB_USERS && showUsersTab
      ? TAB_USERS
      : tabParam === TAB_DISPLAYS || !showUsersTab
        ? TAB_DISPLAYS
        : TAB_DISPLAYS;

  useEffect(() => {
    if (tabParam === TAB_USERS && !showUsersTab) {
      setSearchParams({ tab: TAB_DISPLAYS }, { replace: true });
    }
  }, [tabParam, showUsersTab, setSearchParams]);

  return (
    <Stack spacing={2}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Displays & operator access
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Pair and label displays in this browser, export or import your display list, and—when BFF
          authentication is enabled—turn on user management and edit operator accounts.
        </Typography>
      </Box>
      <Paper sx={{ px: 2, pt: 1 }}>
        <Tabs
          value={tab}
          onChange={(_, value) => setSearchParams({ tab: value }, { replace: true })}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: 'divider' }}
        >
          {tabs.map((t) => (
            <Tab key={t.id} label={t.label} value={t.id} />
          ))}
        </Tabs>
      </Paper>

      {tab === TAB_DISPLAYS && <DisplaysPage embedded />}
      {tab === TAB_USERS && showUsersTab && (
        <Stack spacing={3}>
          <Paper sx={{ p: 2 }}>
            <ControllerAccessSection />
          </Paper>
          <UsersPage />
        </Stack>
      )}
    </Stack>
  );
}
