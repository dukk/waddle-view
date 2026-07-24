import { useState } from 'react';
import {
  Button,
  ListItemText,
  Menu,
  MenuItem,
  Typography,
} from '@mui/material';
import DesktopWindowsOutlinedIcon from '@mui/icons-material/DesktopWindowsOutlined';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import type { SavedDisplay } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';

type Props = {
  displays: SavedDisplay[];
  active: SavedDisplay | null;
  onSelect: (displayId: string) => void;
  disabled?: boolean;
};

/** Narrow display menu for live-preview pop-out header. */
export function CompactDisplayPicker({ displays, active, onSelect, disabled }: Props) {
  const [anchor, setAnchor] = useState<null | HTMLElement>(null);
  const activeLabel = active?.label ?? 'Display';
  const activeSession = active ? loadSession(active.id) : null;

  if (displays.length === 0) {
    return (
      <Typography variant="body2" sx={{
        color: "text.secondary"
      }}>No displays configured
              </Typography>
    );
  }

  return (
    <>
      <Button
        variant="outlined"
        size="small"
        disabled={disabled}
        onClick={(e) => setAnchor(e.currentTarget)}
        startIcon={<DesktopWindowsOutlinedIcon />}
        endIcon={<KeyboardArrowDownIcon />}
        sx={{ fontWeight: 600, textTransform: 'none', maxWidth: 280 }}
        aria-haspopup="true"
        aria-expanded={anchor ? 'true' : undefined}
      >
        <Typography component="span" noWrap variant="body2" sx={{
          fontWeight: 600
        }}>
          {activeLabel}
          {activeSession ? ` · ${activeSession.identifier}` : ''}
        </Typography>
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
                onSelect(d.id);
                setAnchor(null);
              }}
            >
              <ListItemText
                primary={d.label}
                secondary={hint}
                slotProps={{
                  secondary: { noWrap: true }
                }}
              />
            </MenuItem>
          );
        })}
      </Menu>
    </>
  );
}
