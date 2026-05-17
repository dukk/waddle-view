import { useState } from 'react';
import { Link as RouterLink } from 'react-router';
import {
  Box,
  Button,
  Divider,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Typography,
} from '@mui/material';
import DesktopWindowsIcon from '@mui/icons-material/DesktopWindows';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import SettingsIcon from '@mui/icons-material/Settings';
import { useDisplay } from '@/context/DisplayContext';
import { loadSession } from '@/storage/sessions';

export function DisplaySelector() {
  const { displays, active, setActiveId } = useDisplay();
  const [anchor, setAnchor] = useState<null | HTMLElement>(null);

  if (displays.length === 0) {
    return null;
  }

  const activeLabel = active?.label ?? 'Display';
  const activeSession = active ? loadSession(active.id) : null;

  return (
    <>
      <Button
        color="inherit"
        onClick={(e) => setAnchor(e.currentTarget)}
        startIcon={<DesktopWindowsIcon />}
        endIcon={<KeyboardArrowDownIcon />}
        sx={{
          fontWeight: 600,
          textTransform: 'none',
          mr: 1,
          maxWidth: { xs: 140, sm: 220 },
          flexShrink: 0,
        }}
        aria-haspopup="true"
        aria-expanded={anchor ? 'true' : undefined}
      >
        <Box sx={{ textAlign: 'left', minWidth: 0 }}>
          <Typography component="span" noWrap variant="body2" fontWeight={600} display="block">
            {activeLabel}
          </Typography>
          {activeSession && (
            <Typography component="span" noWrap variant="caption" color="text.secondary" display="block">
              {activeSession.identifier} ({activeSession.role})
            </Typography>
          )}
        </Box>
      </Button>
      <Menu
        anchorEl={anchor}
        open={Boolean(anchor)}
        onClose={() => setAnchor(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
        transformOrigin={{ vertical: 'top', horizontal: 'left' }}
      >
        {displays.map((d) => {
          const dSession = loadSession(d.id);
          const hint = dSession
            ? `${dSession.identifier} (${dSession.role})`
            : 'Not adopted';
          return (
            <MenuItem
              key={d.id}
              selected={d.id === active?.id}
              onClick={() => {
                setActiveId(d.id);
                setAnchor(null);
              }}
            >
              <ListItemText
                primary={d.label}
                secondary={hint}
                secondaryTypographyProps={{ noWrap: true }}
              />
            </MenuItem>
          );
        })}
        <Divider />
        <MenuItem
          component={RouterLink}
          to="/displays"
          onClick={() => setAnchor(null)}
        >
          <ListItemIcon>
            <SettingsIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Manage displays…</ListItemText>
        </MenuItem>
      </Menu>
    </>
  );
}
