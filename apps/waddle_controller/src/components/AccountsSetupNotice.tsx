import { Alert, Link as MuiLink, Typography } from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import {
  DISPLAY_SETTINGS_TAB_ACCOUNTS,
  displaySettingsPath,
} from '@/constants/displaySettingsTabs';

export function AccountsSetupNotice() {
  return (
    <Alert severity="info">
      <Typography variant="body2" component="span">
        Some integrations require shared accounts or API keys to be configured before they can be
        enabled. Add and manage them under{' '}
        <MuiLink component={RouterLink} to={displaySettingsPath(DISPLAY_SETTINGS_TAB_ACCOUNTS)}>
          Display settings → Accounts
        </MuiLink>
        .
      </Typography>
    </Alert>
  );
}
