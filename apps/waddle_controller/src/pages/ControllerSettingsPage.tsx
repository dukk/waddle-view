import { useEffect, useMemo } from 'react';
import { Box, Paper, Stack, Tab, Tabs, Typography } from '@mui/material';
import { useSearchParams } from 'react-router-dom';
import { ControllerAccessSection } from '@/components/ControllerAccessSection';
import { DisplayBackupSection } from '@/components/DisplayBackupSection';
import { DisplaysPage } from '@/pages/DisplaysPage';
import { UsersPage } from '@/pages/UsersPage';
import { useControllerAuth } from '@/context/ControllerAuthContext';

const TAB_DISPLAYS = 'displays';
const TAB_BACKUP = 'backup';
const TAB_USERS = 'users';

export function ControllerSettingsPage() {
  const { status, isControllerAdmin } = useControllerAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const showUsersTab = Boolean(status?.authEnabled && isControllerAdmin);

  const tabs = useMemo(() => {
    const items = [
      { id: TAB_DISPLAYS, label: 'Displays' },
      { id: TAB_BACKUP, label: 'Backup & restore' },
    ];
    if (showUsersTab) {
      items.push({ id: TAB_USERS, label: 'Users' });
    }
    return items;
  }, [showUsersTab]);

  const tabParam = searchParams.get('tab');
  const tab = useMemo(() => {
    if (tabParam === TAB_USERS && showUsersTab) return TAB_USERS;
    if (tabParam === TAB_BACKUP) return TAB_BACKUP;
    return TAB_DISPLAYS;
  }, [tabParam, showUsersTab]);

  useEffect(() => {
    if (tabParam === TAB_USERS && !showUsersTab) {
      setSearchParams({ tab: TAB_DISPLAYS }, { replace: true });
    }
  }, [tabParam, showUsersTab, setSearchParams]);

  return (
    <Stack spacing={2}>
      <Box>
        <Typography variant="h6" fontWeight={600} gutterBottom>
          Controller settings
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Pair and label displays, schedule controller-side backups and restores, export or import your
          display list, and—when BFF authentication is enabled—manage operator accounts.
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
      {tab === TAB_BACKUP && <DisplayBackupSection />}
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
