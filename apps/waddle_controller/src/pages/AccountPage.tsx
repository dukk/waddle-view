import {
  Box,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Typography,
} from '@mui/material';
import { Link as RouterLink } from 'react-router';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { useColorMode } from '@/context/ColorModeContext';
import type { ColorModePreference } from '@/storage/colorModePreference';

export function AccountPage() {
  const { active } = useDisplay();
  const { session } = useAuth();
  const { preference, setPreference } = useColorMode();

  const adoptionBody =
    session && active ? (
      <>
        <Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Client identifier
          </Typography>
          <Typography variant="body1" sx={{ fontFamily: 'monospace' }}>
            {session.identifier}
          </Typography>
        </Box>
        <Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Role
          </Typography>
          <Typography variant="body1">{session.role}</Typography>
        </Box>
        <Box>
          <Typography variant="subtitle2" color="text.secondary" gutterBottom>
            Permissions
          </Typography>
          <Typography variant="body2" component="div" sx={{ fontFamily: 'monospace' }}>
            {session.permissions.join(', ')}
          </Typography>
        </Box>
      </>
    ) : (
      <Typography variant="body1" color="text.secondary">
        Select a display and complete adoption to see session details.
      </Typography>
    );

  return (
    <Stack spacing={3} sx={{ maxWidth: 720 }}>
      <Typography variant="h5" fontWeight={600} gutterBottom>
        Your session & preferences
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Your adopted display session (client id, role, and permissions) and controller appearance.
        Add or re-adopt displays on{' '}
        <RouterLink to="/controller-settings">Controller settings</RouterLink>; API keys stay in
        this browser only and are not included in display-list export.
      </Typography>

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Appearance
        </Typography>
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
          Defaults to your device light/dark setting. Stored only in this browser.
        </Typography>
        <FormControl sx={{ minWidth: 240 }}>
          <InputLabel id="controller-color-mode-label">Color mode</InputLabel>
          <Select
            labelId="controller-color-mode-label"
            label="Color mode"
            value={preference}
            onChange={(e) => setPreference(e.target.value as ColorModePreference)}
          >
            <MenuItem value="system">Match device</MenuItem>
            <MenuItem value="light">Light</MenuItem>
            <MenuItem value="dark">Dark</MenuItem>
          </Select>
        </FormControl>
      </Box>

      {adoptionBody}
    </Stack>
  );
}
