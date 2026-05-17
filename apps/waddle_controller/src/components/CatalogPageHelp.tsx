import { useState, type ReactNode } from 'react';
import HelpOutlineIcon from '@mui/icons-material/HelpOutline';
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Tooltip,
} from '@mui/material';

type Props = {
  title: string;
  /** Accessible name for the trigger (defaults to `${title} help`). */
  ariaLabel?: string;
  children: ReactNode;
};

export function CatalogPageHelp({ title, ariaLabel, children }: Props) {
  const [open, setOpen] = useState(false);
  const label = ariaLabel ?? `${title} help`;

  return (
    <>
      <Tooltip title="Help">
        <IconButton
          aria-label={label}
          size="small"
          onClick={() => setOpen(true)}
          sx={{ color: 'text.secondary' }}
        >
          <HelpOutlineIcon fontSize="small" />
        </IconButton>
      </Tooltip>
      <Dialog open={open} onClose={() => setOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{title}</DialogTitle>
        <DialogContent dividers>
          <Stack spacing={1.5}>{children}</Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Close</Button>
        </DialogActions>
      </Dialog>
    </>
  );
}
